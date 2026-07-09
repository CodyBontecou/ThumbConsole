import AppKit
import CoreGraphics
import Foundation
import Network
import SwiftUI

final class MacControllerLiveActivity: ObservableObject {
    @Published var lastHeartbeat: Date?
    @Published var lastReceivedEvent: String = "None"
    @Published var estimatedLatencyMS: Int?
    @Published var pressedButtons: Set<GameButton> = []
    @Published var missedButtonFrames = 0
    @Published var ignoredButtonEdges = 0
    @Published var recoveredButtonEdges = 0
}

final class MacControllerServer: ObservableObject {
    let liveActivity = MacControllerLiveActivity()

    @Published private(set) var statusText = "Stopped"
    @Published private(set) var isRunning = false
    @Published private(set) var isClientConnected = false
    @Published private(set) var localURLs: [String] = []
    @Published private(set) var pairingCode: String
    @Published private(set) var isPairingPending = false
    @Published private(set) var pendingPairingClientName: String?
    @Published private(set) var clientName: String = "No client"
    @Published private(set) var clientDeviceInfo: ControllerClientDeviceInfo?
    private(set) var lastHeartbeat: Date? {
        get { liveActivity.lastHeartbeat }
        set { liveActivity.lastHeartbeat = newValue }
    }
    private(set) var lastReceivedEvent: String {
        get { liveActivity.lastReceivedEvent }
        set { liveActivity.lastReceivedEvent = newValue }
    }
    private(set) var estimatedLatencyMS: Int? {
        get { liveActivity.estimatedLatencyMS }
        set { liveActivity.estimatedLatencyMS = newValue }
    }
    private(set) var pressedButtons: Set<GameButton> {
        get { liveActivity.pressedButtons }
        set { liveActivity.pressedButtons = newValue }
    }
    private(set) var missedButtonFrames: Int {
        get { liveActivity.missedButtonFrames }
        set { liveActivity.missedButtonFrames = newValue }
    }
    private(set) var ignoredButtonEdges: Int {
        get { liveActivity.ignoredButtonEdges }
        set { liveActivity.ignoredButtonEdges = newValue }
    }
    private(set) var recoveredButtonEdges: Int {
        get { liveActivity.recoveredButtonEdges }
        set { liveActivity.recoveredButtonEdges = newValue }
    }
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var keyBindings: [GameButton: MacKeyBinding]
    @Published private(set) var outputBindings: [GameButton: MacControlOutputBinding]
    @Published private(set) var gamepadCustomization: GamepadCustomization
    @Published private(set) var gamepadProfiles: [GamepadConfigurationProfile]
    @Published private(set) var activeGamepadProfileID: UUID
    @Published private(set) var defaultGamepadProfileID: UUID
    @Published private(set) var port: UInt16 = MacControllerServer.preferredPort

    var pairingPayload: String {
        let payload = PairingPayload(
            urls: localURLs,
            pairingCode: pairingCode,
            serviceName: bonjourServiceName,
            serviceType: Self.bonjourServiceEndpointType,
            serviceDomain: Self.bonjourServiceDomain,
            serverID: serverID
        )
        guard let data = try? JSONEncoder().encode(payload) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    struct EditorUndoSnapshot: Equatable {
        var keyBindings: [GameButton: MacKeyBinding]
        var outputBindings: [GameButton: MacControlOutputBinding]
        var gamepadCustomization: GamepadCustomization
        var gamepadProfiles: [GamepadConfigurationProfile]
        var activeGamepadProfileID: UUID
        var defaultGamepadProfileID: UUID
        var profileKeyBindings: [UUID: [GameButton: MacKeyBinding]]
        var profileOutputBindings: [UUID: [GameButton: MacControlOutputBinding]]
    }

    private let networkQueue = DispatchQueue(label: "PocketPad.NetworkServer", qos: .userInteractive)
    private let networkQueueKey = DispatchSpecificKey<Bool>()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let injector = KeyboardInjector()
    private let pointerInjector = PointerInjector()
    private let virtualGamepadInjector = VirtualGamepadInjector()
    private let debugLogURL = URL(fileURLWithPath: "/tmp/pocketpad-mac-events.log")
    private let captureLogURL = URL(fileURLWithPath: PocketPadMacIPC.captureLogPath)
    private let logQueue = DispatchQueue(label: "PocketPad.DebugLog", qos: .utility)
    private let captureLogQueue = DispatchQueue(label: "PocketPad.CaptureLog", qos: .utility)
    private static let preferredPort: UInt16 = 8765
    private static let keyBindingsDefaultsKey = "PocketPadMac.keyBindings.v2"
    private static let legacyKeyBindingsDefaultsKey = "PocketPadMac.keyBindings.v1"
    private static let profileKeyBindingsDefaultsKey = "PocketPadMac.profileKeyBindings.v1"
    private static let outputBindingsDefaultsKey = "PocketPadMac.outputBindings.v1"
    private static let profileOutputBindingsDefaultsKey = "PocketPadMac.profileOutputBindings.v1"
    private static let serverIdentityDefaultsKey = "PocketPadMac.serverIdentity.v1"
    private static let trustedClientsDefaultsKey = "PocketPadMac.trustedClients.v1"
    private static let bonjourServiceType = "_pocketpad._tcp."
    private static let bonjourServiceEndpointType = "_pocketpad._tcp"
    private static let bonjourServiceDomain = "local"
    private static let externalProfileStoreChangedNotificationName = Notification.Name("com.codybontecou.PocketPadMac.profileStoreChanged")
    private static let notificationProfileStateDataKey = "profileStateData"
    private static let notificationActiveCustomizationDataKey = "activeCustomizationData"
    private static let notificationKeyBindingsDataKey = "keyBindingsData"
    private static let notificationProfileKeyBindingsDataKey = "profileKeyBindingsData"
    private static let notificationOutputBindingsDataKey = "outputBindingsData"
    private static let notificationProfileOutputBindingsDataKey = "profileOutputBindingsData"
    private static let inputEventLoggingEnabled = false
    private static let inputDebugPublishIntervalNanoseconds: UInt64 = 100_000_000
    private static let clientActivityPublishIntervalNanoseconds: UInt64 = 100_000_000
    private static let runtimeStatusPublishIntervalNanoseconds: UInt64 = 250_000_000
    private static let buttonReorderDelayNanoseconds: UInt64 = 4_000_000
    // The iPhone re-sends every active touch on each heartbeat (500 ms). If a
    // button-up packet is lost, heartbeats continue but that button stops being
    // refreshed. Expire that stale hold after one missed refresh plus jitter,
    // instead of letting a direction feel stuck until the full heartbeat timeout.
    private static let physicalHoldRefreshTimeoutNanoseconds: UInt64 = 850_000_000
    private let serverID: String
    private let bonjourServiceName: String
    private var trustedClients: [String: TrustedClient]
    private var listener: NWListener?
    private var datagramListener: NWListener?
    private var bonjourService: NetService?
    private var datagramListenerPort: UInt16?
    private var datagramConnections: [ObjectIdentifier: NWConnection] = [:]
    private var authenticatedDatagramConnection: NWConnection?
    private var connection: NWConnection?
    private var realtimeConnection: NWConnection?
    private var pairedConnection: NWConnection?
    private var pendingPairingConnection: NWConnection?
    private var activePairingCode: String
    private var realtimeToken: String?
    private var backgroundActivity: NSObjectProtocol?
    private var heartbeatTimer: Timer?
    private var heartbeatTimedOut = false
    private var inputPressedButtons: Set<GameButton> = []
    private var inputPressedElementInputs: Set<KeypadElementInputID> = []
    private var profileKeyBindings: [UUID: [GameButton: MacKeyBinding]] = [:]
    private var profileOutputBindings: [UUID: [GameButton: MacControlOutputBinding]] = [:]
    private var realtimeKeyBindings: [GameButton: MacKeyBinding]
    private var realtimeOutputBindings: [GameButton: MacControlOutputBinding]
    private var realtimeGamepadCustomization: GamepadCustomization
    private var realtimeGamepadProfiles: [GamepadConfigurationProfile]
    private var realtimeActiveGamepadProfileID: UUID
    private var realtimeDefaultGamepadProfileID: UUID
    private var realtimeOutputMode: GamepadProfileOutputMode
    private var pendingLastReceivedEvent: String?
    private var pendingPressedButtons: Set<GameButton>?
    private var controllerDebugUpdateTask: Task<Void, Never>?
    private var runtimeStatusPublishTask: Task<Void, Never>?
    private var lastRuntimeStatusPublishUptime: UInt64 = 0
    private var lastInputDebugPublishUptime: UInt64 = 0
    private var lastClientActivityPublishUptime: UInt64 = 0
    private var lastAccessibilityRefresh = Date.distantPast
    private var activeBindings: [GameButton: MacKeyBinding] = [:]
    private var activeOutputBindings: [GameButton: MacControlOutputBinding] = [:]
    private var activeElementOutputBindings: [KeypadElementInputID: MacControlOutputBinding] = [:]
    private var heldBindingCounts: [MacKeyBinding: Int] = [:]
    private var heldGamepadButtonCounts: [VirtualGamepadButton: Int] = [:]
    private var captureLogSequence: UInt64 = 0
    private var lastAnalogSequenceNumberByKey: [String: UInt64] = [:]
    private var activeAnalogStickLastSeenByStick: [VirtualGamepadStick: UInt64] = [:]
    private var activeAnalogTriggerLastSeenByTrigger: [VirtualGamepadTrigger: UInt64] = [:]
    private var activePointerButtons: Set<ControllerPointerButton> = []
    private var recentPointerButtonEvents: [PointerButtonEventFingerprint: UInt64] = [:]
    private static let pointerButtonDuplicateWindowNanoseconds: UInt64 = 2_000_000_000
    private struct PointerButtonEventFingerprint: Hashable {
        let button: ControllerPointerButton
        let state: ButtonPressState
        let timestamp: Int64
    }
    private struct PendingButtonMessage {
        let message: ControllerMessage
        let button: GameButton?
        let elementInput: KeypadElementInputID?
        let state: ButtonPressState
        let source: String
    }

    private struct TrustedClient: Codable {
        var token: String
        var clientName: String
        var createdAt: Int64
        var lastSeenAt: Int64
    }

    private var activePressIdentifiersByButton: [GameButton: Set<UInt64>] = [:]
    private var activePressLastSeenByButton: [GameButton: [UInt64: UInt64]] = [:]
    private var anonymousPressCountsByButton: [GameButton: Int] = [:]
    private var anonymousPressLastSeenByButton: [GameButton: UInt64] = [:]
    private var activePressIdentifiersByElementInput: [KeypadElementInputID: Set<UInt64>] = [:]
    private var activePressLastSeenByElementInput: [KeypadElementInputID: [UInt64: UInt64]] = [:]
    private var anonymousPressCountsByElementInput: [KeypadElementInputID: Int] = [:]
    private var anonymousPressLastSeenByElementInput: [KeypadElementInputID: UInt64] = [:]
    private var buttonSequenceTracker = ButtonSequenceTracker()
    private var pendingButtonMessagesBySequence: [UInt64: PendingButtonMessage] = [:]
    private var buttonReorderFlushWorkItem: DispatchWorkItem?
    private var buttonReorderFlushGeneration = 0
    private var ignoredButtonEdgeCount = 0
    private var recoveredButtonEdgeCount = 0
    private var externalDefaultsObserver: NSObjectProtocol?
    private var cliCommandObserver: NSObjectProtocol?

    private struct ExternalStoredProfileState: Codable {
        var profiles: [GamepadConfigurationProfile]
        var activeProfileID: UUID?
        var defaultProfileID: UUID?
    }

    init() {
        serverID = Self.loadOrCreateServerID()
        bonjourServiceName = Self.defaultBonjourServiceName()
        trustedClients = Self.loadTrustedClients()

        let initialPairingCode = Self.generatePairingCode()
        pairingCode = initialPairingCode
        activePairingCode = initialPairingCode

        let loadedKeyBindings = Self.loadKeyBindings()
        var loadedProfileKeyBindings = Self.loadProfileKeyBindings()
        var loadedProfileOutputBindings = Self.loadProfileOutputBindings(fallbackProfileKeyBindings: loadedProfileKeyBindings)
        let savedGamepadCustomization = GamepadCustomizationPersistence.load()
        let loadedProfileState = GamepadConfigurationProfilePersistence.load(activeCustomization: savedGamepadCustomization)
        let startupProfile = loadedProfileState.defaultProfile ?? loadedProfileState.activeProfile ?? loadedProfileState.profiles[0]
        let startupGamepadCustomization = startupProfile.customization.normalized
        if loadedProfileKeyBindings[startupProfile.id] == nil {
            loadedProfileKeyBindings[startupProfile.id] = loadedKeyBindings
        }
        let startupKeyBindings = Self.resolvedKeyBindings(
            for: startupProfile.id,
            in: loadedProfileKeyBindings,
            fallback: loadedKeyBindings
        )
        if loadedProfileOutputBindings[startupProfile.id] == nil {
            loadedProfileOutputBindings[startupProfile.id] = Self.outputBindings(from: startupKeyBindings)
        }
        let storedStartupOutputBindings = Self.resolvedOutputBindings(
            for: startupProfile.id,
            in: loadedProfileOutputBindings,
            fallback: Self.outputBindings(from: startupKeyBindings)
        )
        let startupOutputBindings = Self.effectiveOutputBindings(
            for: startupProfile.outputMode,
            keyBindings: startupKeyBindings,
            customOutputBindings: storedStartupOutputBindings
        )
        loadedProfileOutputBindings[startupProfile.id] = startupOutputBindings

        keyBindings = startupKeyBindings
        outputBindings = startupOutputBindings
        realtimeKeyBindings = startupKeyBindings
        realtimeOutputBindings = startupOutputBindings
        gamepadCustomization = startupGamepadCustomization
        gamepadProfiles = loadedProfileState.profiles
        activeGamepadProfileID = startupProfile.id
        defaultGamepadProfileID = loadedProfileState.defaultProfileID
        profileKeyBindings = loadedProfileKeyBindings
        profileOutputBindings = loadedProfileOutputBindings
        realtimeGamepadCustomization = startupGamepadCustomization
        realtimeGamepadProfiles = loadedProfileState.profiles
        realtimeActiveGamepadProfileID = startupProfile.id
        realtimeDefaultGamepadProfileID = loadedProfileState.defaultProfileID
        realtimeOutputMode = startupProfile.outputMode
        GamepadCustomizationPersistence.save(startupGamepadCustomization)
        GamepadConfigurationProfilePersistence.save(
            loadedProfileState.profiles,
            activeProfileID: startupProfile.id,
            defaultProfileID: loadedProfileState.defaultProfileID
        )
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        networkQueue.setSpecific(key: networkQueueKey, value: true)
        refreshAccessibilityStatus()
        localURLs = Self.localIPv4Addresses().map { "ws://\($0):\(port)" }
        cliCommandObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(PocketPadMacIPC.commandNotificationName),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleCLICommandNotification(notification)
        }
        externalDefaultsObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.externalProfileStoreChangedNotificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            if !self.applyProfileStoreChangeNotification(notification, source: "cli") {
                self.reloadProfilesFromDefaults(source: "cli")
            }
        }
        refreshVirtualGamepadMaterialization(reason: "startup", publish: false)
        publishRuntimeStatus()
    }

    deinit {
        if let cliCommandObserver {
            DistributedNotificationCenter.default().removeObserver(cliCommandObserver)
        }
        if let externalDefaultsObserver {
            DistributedNotificationCenter.default().removeObserver(externalDefaultsObserver)
        }
        stop()
    }

    func start() {
        guard !isRunning else { return }
        startListening(on: Self.preferredPort, fallbackIfBusy: true)
    }

    func restart() {
        stop()
        DispatchQueue.main.async { [weak self] in
            self?.start()
        }
    }

    func stop() {
        stop(finalStatusText: "Stopped")
    }

    private func startListening(on requestedPort: UInt16?, fallbackIfBusy: Bool) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.includePeerToPeer = true
        let websocketOptions = NWProtocolWebSocket.Options()
        websocketOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(websocketOptions, at: 0)

        do {
            let listener: NWListener
            if let requestedPort {
                let nwPort = NWEndpoint.Port(rawValue: requestedPort)!
                listener = try NWListener(using: parameters, on: nwPort)
                port = requestedPort
                localURLs = Self.localIPv4Addresses().map { "ws://\($0):\(requestedPort)" }
            } else {
                listener = try NWListener(using: parameters)
            }

            self.listener = listener

            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let listener else { return }
                DispatchQueue.main.async {
                    self?.handleListenerState(
                        state,
                        listener: listener,
                        fallbackIfBusy: fallbackIfBusy,
                        usingFallbackPort: requestedPort == nil
                    )
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }

            listener.start(queue: networkQueue)
            beginBackgroundActivity()
            isRunning = true
            if let requestedPort {
                statusText = "Starting on port \(requestedPort)…"
                logDebug("server starting port=\(requestedPort)")
            } else {
                statusText = "Starting on an available port…"
                logDebug("server starting port=auto")
            }
            startHeartbeatTimer()
            refreshVirtualGamepadMaterialization(reason: "server_start", publish: false)
            publishRuntimeStatus()
        } catch {
            guard fallbackIfBusy, isPreferredPortUnavailable(error) else {
                let failureText = "Failed to start: \(error.localizedDescription)"
                stop(finalStatusText: failureText, releaseReason: "Server failed to start")
                logDebug("server failed error=\(error.localizedDescription)")
                return
            }

            statusText = "Port \(Self.preferredPort) is unavailable; trying an available port…"
            logDebug("preferred_port_unavailable port=\(Self.preferredPort) error=\(error.localizedDescription) retry=auto")
            publishRuntimeStatus()
            startListening(on: nil, fallbackIfBusy: false)
        }
    }

    private func stop(finalStatusText: String, releaseReason: String = "Server stopped") {
        releaseAll(reason: releaseReason)
        syncOnNetworkQueue {
            realtimeConnection?.cancel()
            realtimeConnection = nil
            pairedConnection = nil
            pendingPairingConnection = nil
            realtimeToken = nil
            stopDatagramListenerOnNetworkQueue()
        }
        connection?.cancel()
        listener?.cancel()
        stopBonjourService()
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        endBackgroundActivity()
        connection = nil
        listener = nil
        datagramListener = nil
        datagramListenerPort = nil
        datagramConnections.removeAll()
        authenticatedDatagramConnection = nil
        heartbeatTimedOut = false
        isRunning = false
        isClientConnected = false
        isPairingPending = false
        pendingPairingClientName = nil
        statusText = finalStatusText
        clientName = "No client"
        clientDeviceInfo = nil
        if finalStatusText == "Stopped" {
            logDebug("server stopped")
        } else {
            logDebug("server stopped status=\(finalStatusText)")
        }
        publishRuntimeStatus()
    }

    func cancelPairing() {
        syncOnNetworkQueue {
            cancelPendingPairingOnNetworkQueue(reason: "Pairing cancelled")
        }
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = syncOnNetworkQueue {
            let keyboardTrusted = injector.refreshAccessibilityStatus()
            let pointerTrusted = pointerInjector.refreshAccessibilityStatus()
            return keyboardTrusted && pointerTrusted
        }
        lastAccessibilityRefresh = Date()
        publishRuntimeStatus()
    }

    func promptForAccessibility() {
        _ = injector.promptForAccessibility()
        refreshAccessibilityStatus()
    }

    func openAccessibilitySettings() {
        injector.openAccessibilitySettings()
    }

    private func handleCLICommandNotification(_ notification: Notification) {
        guard let commandData = Self.notificationData(
            from: notification.userInfo,
            key: PocketPadMacIPC.commandDataKey
        ) else {
            lastReceivedEvent = "Ignored CLI command: missing payload"
            publishRuntimeStatus(synchronize: true)
            logDebug("cli_command_ignored reason=missing_payload")
            return
        }

        do {
            let payload = try JSONDecoder().decode(PocketPadMacCLICommandPayload.self, from: commandData)
            handleCLICommand(payload)
        } catch {
            lastReceivedEvent = "Ignored CLI command: invalid payload"
            publishRuntimeStatus(synchronize: true)
            logDebug("cli_command_ignored reason=invalid_payload error=\(error.localizedDescription)")
        }
    }

    private func handleCLICommand(_ payload: PocketPadMacCLICommandPayload) {
        defer { publishRuntimeStatus(synchronize: true) }

        switch payload.command {
        case .publishStatus:
            break

        case .start:
            start()

        case .stop:
            stop()

        case .restart:
            restart()

        case .cancelPairing:
            cancelPairing()

        case .refreshAccessibility:
            refreshAccessibilityStatus()

        case .promptAccessibility:
            promptForAccessibility()

        case .openAccessibilitySettings:
            openAccessibilitySettings()

        case .releaseAll:
            releaseAll(reason: payload.reason?.nilIfEmpty ?? "CLI release all")

        case .testDown:
            guard let button = payload.button else {
                lastReceivedEvent = "Ignored CLI test down: missing button"
                break
            }
            sendTestDown(button)
            lastReceivedEvent = "CLI test down: \(button.displayName)"

        case .testUp:
            guard let button = payload.button else {
                lastReceivedEvent = "Ignored CLI test up: missing button"
                break
            }
            sendTestUp(button)
            lastReceivedEvent = "CLI test up: \(button.displayName)"
        }
    }

    var activeGamepadOutputMode: GamepadProfileOutputMode {
        gamepadProfiles.first { $0.id == activeGamepadProfileID }?.outputMode ?? .keyboard
    }

    func editorUndoSnapshot() -> EditorUndoSnapshot {
        EditorUndoSnapshot(
            keyBindings: keyBindings,
            outputBindings: outputBindings,
            gamepadCustomization: gamepadCustomization,
            gamepadProfiles: gamepadProfiles,
            activeGamepadProfileID: activeGamepadProfileID,
            defaultGamepadProfileID: defaultGamepadProfileID,
            profileKeyBindings: profileKeyBindings,
            profileOutputBindings: profileOutputBindings
        )
    }

    func restoreEditorUndoSnapshot(_ snapshot: EditorUndoSnapshot, reason: String) {
        releaseAll(reason: reason)

        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: snapshot.gamepadProfiles,
            activeProfileID: snapshot.activeGamepadProfileID,
            defaultProfileID: snapshot.defaultGamepadProfileID,
            fallbackCustomization: snapshot.gamepadCustomization
        )
        let activeOrientation = snapshot.gamepadCustomization.deviceCanvas.editorDeviceFrame.orientation
        let restoredCustomization = (state.activeProfile?.customization(for: activeOrientation) ?? snapshot.gamepadCustomization).normalized.stampedForLocalUpdate

        keyBindings = snapshot.keyBindings
        outputBindings = snapshot.outputBindings
        gamepadProfiles = state.profiles
        activeGamepadProfileID = state.activeProfileID
        defaultGamepadProfileID = state.defaultProfileID
        gamepadCustomization = restoredCustomization
        profileKeyBindings = snapshot.profileKeyBindings
        profileOutputBindings = snapshot.profileOutputBindings
        profileKeyBindings[activeGamepadProfileID] = keyBindings
        profileOutputBindings[activeGamepadProfileID] = outputBindings
        pruneProfileKeyBindings()

        persistGamepadProfileState()
        GamepadCustomizationPersistence.save(restoredCustomization)
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = reason

        let restoredProfiles = gamepadProfiles
        let restoredOutputMode = activeGamepadOutputMode
        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeKeyBindings = snapshot.keyBindings
            self.realtimeOutputBindings = snapshot.outputBindings
            self.realtimeGamepadCustomization = restoredCustomization
            self.realtimeGamepadProfiles = restoredProfiles
            self.realtimeActiveGamepadProfileID = state.activeProfileID
            self.realtimeDefaultGamepadProfileID = state.defaultProfileID
            self.realtimeOutputMode = restoredOutputMode
            self.sendGamepadProfileStateOnNetworkQueue()
        }
        refreshVirtualGamepadMaterialization(reason: "editor_undo", publish: false)
        publishRuntimeStatus()
    }

    func keyLabel(for button: GameButton) -> String {
        guard let binding = keyBindings[button] else { return "Unmapped" }
        return binding.displayName
    }

    func outputLabel(for button: GameButton) -> String {
        outputBindings[button]?.displayName ?? keyLabel(for: button)
    }

    func gamepadButtonBinding(for button: GameButton) -> VirtualGamepadButton? {
        outputBindings[button]?.gamepadButtons.sortedForDisplay.first
    }

    func recordedShortcutLabel(for button: GameButton) -> String? {
        outputBindings[button]?.displayName ?? keyBindings[button]?.displayName
    }

    func isDefaultBinding(for button: GameButton) -> Bool {
        keyBindings[button] == DefaultKeypadKeyMap.defaultBinding(for: button)
            && outputBindings[button] == DefaultMacControlOutputMap.defaultBinding(for: button)
    }

    func setKeyBinding(_ binding: MacKeyBinding, for button: GameButton) {
        keyBindings[button] = binding
        let mode = activeGamepadOutputMode
        if mode != .controller {
            var outputBinding = outputBindings[button] ?? MacControlOutputBinding()
            outputBinding.keyboard = binding
            outputBindings[button] = outputBinding
        }
        if mode == .keyboard {
            outputBindings = Self.outputBindings(from: keyBindings)
        }
        applyElementOutputBinding(outputBindings[button], forLegacyButton: button)
        profileKeyBindings[activeGamepadProfileID] = keyBindings
        profileOutputBindings[activeGamepadProfileID] = outputBindings
        let realtimeOutputs = outputBindings
        let updatedProfiles = gamepadProfiles
        let updatedCustomization = gamepadCustomization
        syncOnNetworkQueue {
            releaseIfPressedOnNetworkQueue(button)
            realtimeKeyBindings[button] = binding
            realtimeOutputBindings = realtimeOutputs
            realtimeGamepadCustomization = updatedCustomization
            realtimeGamepadProfiles = updatedProfiles
            sendGamepadProfileStateOnNetworkQueue()
        }
        persistGamepadProfileState()
        GamepadCustomizationPersistence.save(gamepadCustomization)
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = mode == .controller ? "Saved keyboard shortcut for \(button.displayName)" : "Mapped \(button.displayName) to \(binding.displayName)"
        logDebug("key_binding profile=\(activeGamepadProfileID.uuidString) button=\(button.rawValue) binding=\(binding.displayName) mode=\(mode.rawValue) sequence=\(binding.isSequence)")
        publishRuntimeStatus()
    }

    func setKeyBinding(_ keyCode: CGKeyCode, for button: GameButton) {
        setKeyBinding(MacKeyBinding(keyCode: keyCode), for: button)
    }

    func setGamepadButtonBinding(_ gamepadButton: VirtualGamepadButton?, for button: GameButton) {
        var outputBinding = outputBindings[button] ?? MacControlOutputBinding(keyboard: keyBindings[button])
        if outputBinding.keyboard == nil, activeGamepadOutputMode == .controller {
            outputBinding.keyboard = keyBindings[button]
        }
        outputBinding.setGamepadButton(gamepadButton)
        setOutputBinding(outputBinding, for: button, reason: gamepadButton.map { "Mapped \(button.displayName) to \($0.shortName)" } ?? "Cleared gamepad output for \(button.displayName)")
    }

    func elementOutputLabel(for input: KeypadElementInputID) -> String {
        elementOutputBinding(for: input)?.displayName ?? "Unmapped"
    }

    func elementOutputBinding(for input: KeypadElementInputID) -> MacControlOutputBinding? {
        guard let element = gamepadCustomization.element(for: input.elementID) else { return nil }
        if let directOutput = element.outputBinding(for: input.part) {
            return MacControlOutputBinding(shared: directOutput)
        }
        guard let legacyButton = Self.legacyButton(for: input.part, element: element) else { return nil }
        return outputBindings[legacyButton] ?? keyBindings[legacyButton].map { MacControlOutputBinding.keyboard($0) }
    }

    func directElementOutputBinding(for input: KeypadElementInputID) -> MacControlOutputBinding? {
        guard let element = gamepadCustomization.element(for: input.elementID),
              let directOutput = element.outputBinding(for: input.part)
        else { return nil }
        return MacControlOutputBinding(shared: directOutput)
    }

    func gamepadButtonBinding(for input: KeypadElementInputID) -> VirtualGamepadButton? {
        elementOutputBinding(for: input)?.gamepadButtons.sortedForDisplay.first
    }

    func setElementKeyBinding(_ binding: MacKeyBinding, for input: KeypadElementInputID) {
        var outputBinding = elementOutputBinding(for: input) ?? MacControlOutputBinding()
        outputBinding.keyboard = binding
        setElementOutputBinding(outputBinding, for: input, reason: "Mapped element to \(binding.displayName)")
    }

    func setGamepadButtonBinding(_ gamepadButton: VirtualGamepadButton?, for input: KeypadElementInputID) {
        var outputBinding = elementOutputBinding(for: input) ?? MacControlOutputBinding()
        outputBinding.setGamepadButton(gamepadButton)
        setElementOutputBinding(outputBinding, for: input, reason: gamepadButton.map { "Mapped element to \($0.shortName)" } ?? "Cleared element gamepad output")
    }

    func clearElementOutputBinding(for input: KeypadElementInputID) {
        setElementOutputBinding(nil, for: input, reason: "Cleared element output")
    }

    func setElementOutputBinding(_ binding: MacControlOutputBinding?, for input: KeypadElementInputID, reason: String? = nil) {
        guard let activeProfileIndex = gamepadProfiles.firstIndex(where: { $0.id == activeGamepadProfileID }) else { return }
        let sharedBinding = binding?.isEmpty == true ? nil : binding?.sharedBinding

        func update(_ customization: inout GamepadCustomization) -> Bool {
            var normalizedCustomization = customization.normalized
            guard let index = normalizedCustomization.elements.firstIndex(where: { $0.id == input.elementID }) else { return false }
            normalizedCustomization.elements[index].setOutputBinding(sharedBinding, for: input.part)
            customization = normalizedCustomization.normalized
            return true
        }

        var didChange = update(&gamepadProfiles[activeProfileIndex].customization)
        if var landscapeCustomization = gamepadProfiles[activeProfileIndex].landscapeCustomization {
            didChange = update(&landscapeCustomization) || didChange
            gamepadProfiles[activeProfileIndex].landscapeCustomization = landscapeCustomization
        }
        if var portraitCustomization = gamepadProfiles[activeProfileIndex].portraitCustomization {
            didChange = update(&portraitCustomization) || didChange
            gamepadProfiles[activeProfileIndex].portraitCustomization = portraitCustomization
        }
        guard didChange else { return }

        setActiveProfileOutputMode(.custom)
        gamepadProfiles[activeProfileIndex].updatedAt = Date.currentMilliseconds
        let activeOrientation = gamepadCustomization.deviceCanvas.editorDeviceFrame.orientation
        gamepadCustomization = gamepadProfiles[activeProfileIndex].customization(for: activeOrientation).normalized.stampedForLocalUpdate
        profileOutputBindings[activeGamepadProfileID] = outputBindings
        profileKeyBindings[activeGamepadProfileID] = keyBindings

        let updatedProfiles = gamepadProfiles
        let updatedCustomization = gamepadCustomization
        syncOnNetworkQueue {
            releaseElementInputIfPressedOnNetworkQueue(input)
            realtimeOutputMode = .custom
            realtimeGamepadCustomization = updatedCustomization
            realtimeGamepadProfiles = updatedProfiles
            sendGamepadProfileStateOnNetworkQueue()
        }
        persistGamepadProfileState()
        GamepadCustomizationPersistence.save(gamepadCustomization)
        saveProfileKeyBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = reason ?? "Updated element output"
        logDebug("element_output_binding profile=\(activeGamepadProfileID.uuidString) input=\(input.storageKey) binding=\(binding?.displayName ?? "Unmapped")")
        refreshVirtualGamepadMaterialization(reason: "element_output_binding", publish: false)
        publishRuntimeStatus()
    }

    func setOutputMode(_ mode: GamepadProfileOutputMode) {
        guard let activeProfileIndex = gamepadProfiles.firstIndex(where: { $0.id == activeGamepadProfileID }) else { return }
        var profiles = gamepadProfiles
        profiles[activeProfileIndex].outputMode = mode
        profiles[activeProfileIndex].updatedAt = Date.currentMilliseconds

        let activeKeyBindings = keyBindings
        let nextOutputBindings = Self.effectiveOutputBindings(
            for: mode,
            keyBindings: activeKeyBindings,
            customOutputBindings: outputBindings
        )

        releaseAll(reason: "Switch output mode")
        gamepadProfiles = profiles
        outputBindings = nextOutputBindings
        for button in GameButton.allCases {
            applyElementOutputBinding(nextOutputBindings[button], forLegacyButton: button)
        }
        profiles = gamepadProfiles
        profileKeyBindings[activeGamepadProfileID] = keyBindings
        profileOutputBindings[activeGamepadProfileID] = nextOutputBindings
        persistGamepadProfileState()
        GamepadCustomizationPersistence.save(gamepadCustomization)
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = "Switched output to \(mode.displayName)"

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeOutputMode = mode
            self.realtimeOutputBindings = nextOutputBindings
            self.realtimeKeyBindings = activeKeyBindings
            self.realtimeGamepadCustomization = self.gamepadCustomization
            self.realtimeGamepadProfiles = profiles
            self.sendGamepadProfileStateOnNetworkQueue()
        }
        logDebug("output_mode profile=\(activeGamepadProfileID.uuidString) mode=\(mode.rawValue)")
        refreshVirtualGamepadMaterialization(reason: "output_mode", publish: false)
        publishRuntimeStatus()
    }

    func setOutputBinding(_ binding: MacControlOutputBinding, for button: GameButton, reason: String? = nil) {
        outputBindings[button] = binding.isEmpty ? nil : binding
        if let keyboard = binding.keyboard {
            keyBindings[button] = keyboard
        } else {
            keyBindings[button] = nil
        }
        setActiveProfileOutputMode(.custom)
        applyElementOutputBinding(binding.isEmpty ? nil : binding, forLegacyButton: button)
        profileKeyBindings[activeGamepadProfileID] = keyBindings
        profileOutputBindings[activeGamepadProfileID] = outputBindings
        let updatedProfiles = gamepadProfiles
        let updatedCustomization = gamepadCustomization
        syncOnNetworkQueue {
            releaseIfPressedOnNetworkQueue(button)
            realtimeOutputMode = .custom
            realtimeOutputBindings[button] = binding.isEmpty ? nil : binding
            realtimeKeyBindings = keyBindings
            realtimeGamepadCustomization = updatedCustomization
            realtimeGamepadProfiles = updatedProfiles
            sendGamepadProfileStateOnNetworkQueue()
        }
        persistGamepadProfileState()
        GamepadCustomizationPersistence.save(gamepadCustomization)
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = reason ?? "Updated output for \(button.displayName)"
        logDebug("output_binding profile=\(activeGamepadProfileID.uuidString) button=\(button.rawValue) binding=\(binding.displayName)")
        refreshVirtualGamepadMaterialization(reason: "output_binding", publish: false)
        publishRuntimeStatus()
    }

    private func setActiveProfileOutputMode(_ mode: GamepadProfileOutputMode) {
        guard let activeProfileIndex = gamepadProfiles.firstIndex(where: { $0.id == activeGamepadProfileID }) else { return }
        gamepadProfiles[activeProfileIndex].outputMode = mode
        gamepadProfiles[activeProfileIndex].updatedAt = Date.currentMilliseconds
    }

    private func applyElementOutputBinding(_ binding: MacControlOutputBinding?, forLegacyButton button: GameButton) {
        guard let activeProfileIndex = gamepadProfiles.firstIndex(where: { $0.id == activeGamepadProfileID }) else { return }
        let sharedBinding = binding?.sharedBinding

        func update(_ customization: inout GamepadCustomization) {
            var normalizedCustomization = customization.normalized
            let matchingCustomIDs = Set(normalizedCustomization.customButtons.filter { $0.mappedButton == button }.map(\.id))
            var didChange = false
            for index in normalizedCustomization.elements.indices {
                let element = normalizedCustomization.elements[index]
                guard element.builtInButton == button || element.legacySlot == button || matchingCustomIDs.contains(element.id) else { continue }
                normalizedCustomization.elements[index].setOutputBinding(sharedBinding, for: .primary)
                didChange = true
            }
            if didChange {
                customization = normalizedCustomization.normalized
            }
        }

        update(&gamepadProfiles[activeProfileIndex].customization)
        if var landscapeCustomization = gamepadProfiles[activeProfileIndex].landscapeCustomization {
            update(&landscapeCustomization)
            gamepadProfiles[activeProfileIndex].landscapeCustomization = landscapeCustomization
        }
        if var portraitCustomization = gamepadProfiles[activeProfileIndex].portraitCustomization {
            update(&portraitCustomization)
            gamepadProfiles[activeProfileIndex].portraitCustomization = portraitCustomization
        }
        gamepadProfiles[activeProfileIndex].updatedAt = Date.currentMilliseconds
        gamepadCustomization = gamepadProfiles[activeProfileIndex].customization(for: gamepadCustomization.deviceCanvas.editorDeviceFrame.orientation)
    }

    func resetKeyBinding(_ button: GameButton) {
        guard let defaultBinding = DefaultMacControlOutputMap.defaultBinding(for: button) else { return }
        setOutputBinding(defaultBinding, for: button, reason: "Reset output for \(button.displayName)")
    }

    func resetAllKeyBindings() {
        outputBindings = DefaultMacControlOutputMap.defaultBindings
        keyBindings = outputBindings.keyboardBindings
        setActiveProfileOutputMode(.keyboard)
        for button in GameButton.allCases {
            applyElementOutputBinding(outputBindings[button], forLegacyButton: button)
        }
        profileKeyBindings[activeGamepadProfileID] = keyBindings
        profileOutputBindings[activeGamepadProfileID] = outputBindings
        let updatedProfiles = gamepadProfiles
        let updatedCustomization = gamepadCustomization
        syncOnNetworkQueue {
            releaseAllOnNetworkQueue(reason: "Reset all outputs")
            realtimeOutputMode = .keyboard
            realtimeKeyBindings = keyBindings
            realtimeOutputBindings = outputBindings
            realtimeGamepadCustomization = updatedCustomization
            realtimeGamepadProfiles = updatedProfiles
            sendGamepadProfileStateOnNetworkQueue()
        }
        persistGamepadProfileState()
        GamepadCustomizationPersistence.save(gamepadCustomization)
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = "Reset all outputs"
        logDebug("output_bindings_reset_all profile=\(activeGamepadProfileID.uuidString)")
        refreshVirtualGamepadMaterialization(reason: "output_bindings_reset_all", publish: false)
        publishRuntimeStatus()
    }

    func setGamepadCustomization(_ customization: GamepadCustomization) {
        var normalizedCustomization = customization.normalized
        guard !normalizedCustomization.hasSamePresentation(as: gamepadCustomization) else { return }
        normalizedCustomization = normalizedCustomization.stampedForLocalUpdate

        gamepadCustomization = normalizedCustomization
        if let activeProfileIndex = gamepadProfiles.firstIndex(where: { $0.id == activeGamepadProfileID }) {
            gamepadProfiles[activeProfileIndex].setCustomization(
                normalizedCustomization,
                for: normalizedCustomization.deviceCanvas.editorDeviceFrame.orientation
            )
            gamepadProfiles[activeProfileIndex].updatedAt = Date.currentMilliseconds
            persistGamepadProfileState()
        }
        GamepadCustomizationPersistence.save(normalizedCustomization)
        let updatedProfiles = gamepadProfiles
        lastReceivedEvent = "Updated iPhone keypad layout"

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeGamepadCustomization = normalizedCustomization
            self.realtimeGamepadProfiles = updatedProfiles
            self.sendGamepadCustomizationOnNetworkQueue(normalizedCustomization)
        }
        logDebug("gamepad_customization_updated source=mac")
        refreshVirtualGamepadMaterialization(reason: "gamepad_customization", publish: false)
        publishRuntimeStatus()
    }

    func resetGamepadCustomization() {
        setGamepadCustomization(.defaultValue)
    }

    func setGamepadProfileState(
        profiles: [GamepadConfigurationProfile],
        activeProfileID: UUID,
        defaultProfileID: UUID
    ) {
        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: profiles,
            activeProfileID: activeProfileID,
            defaultProfileID: defaultProfileID,
            fallbackCustomization: gamepadCustomization
        )
        let activeCustomization = state.activeProfile?.customization.normalized ?? gamepadCustomization.normalized
        let shouldApplyActiveCustomization = !activeCustomization.hasSamePresentation(as: gamepadCustomization)
        let realtimeCustomization = shouldApplyActiveCustomization ? activeCustomization.stampedForLocalUpdate : gamepadCustomization
        let activeKeyBindings = Self.resolvedKeyBindings(
            for: state.activeProfileID,
            in: profileKeyBindings,
            fallback: keyBindings
        )
        let storedActiveOutputBindings = Self.resolvedOutputBindings(
            for: state.activeProfileID,
            in: profileOutputBindings,
            fallback: Self.outputBindings(from: activeKeyBindings)
        )
        let activeOutputBindings = Self.effectiveOutputBindings(
            for: state.activeProfile?.outputMode ?? .keyboard,
            keyBindings: activeKeyBindings,
            customOutputBindings: storedActiveOutputBindings
        )

        gamepadProfiles = state.profiles
        activeGamepadProfileID = state.activeProfileID
        defaultGamepadProfileID = state.defaultProfileID
        keyBindings = activeKeyBindings
        outputBindings = activeOutputBindings
        profileKeyBindings[state.activeProfileID] = activeKeyBindings
        profileOutputBindings[state.activeProfileID] = activeOutputBindings
        pruneProfileKeyBindings()

        if shouldApplyActiveCustomization {
            gamepadCustomization = realtimeCustomization
            GamepadCustomizationPersistence.save(realtimeCustomization)
        }
        persistGamepadProfileState()
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeKeyBindings = activeKeyBindings
            self.realtimeOutputBindings = activeOutputBindings
            self.realtimeGamepadCustomization = realtimeCustomization
            self.realtimeGamepadProfiles = state.profiles
            self.realtimeActiveGamepadProfileID = state.activeProfileID
            self.realtimeDefaultGamepadProfileID = state.defaultProfileID
            self.realtimeOutputMode = state.activeProfile?.outputMode ?? .keyboard
            self.sendGamepadProfileStateOnNetworkQueue()
        }
        refreshVirtualGamepadMaterialization(reason: "gamepad_profile_state", publish: false)
        publishRuntimeStatus()
    }

    func selectGamepadProfile(_ profileID: UUID, source: String = "mac") {
        guard let profile = gamepadProfiles.first(where: { $0.id == profileID }) else { return }
        let normalizedCustomization = profile.customization.stampedForLocalUpdate
        let selectedKeyBindings = Self.resolvedKeyBindings(
            for: profile.id,
            in: profileKeyBindings,
            fallback: keyBindings
        )
        let storedSelectedOutputBindings = Self.resolvedOutputBindings(
            for: profile.id,
            in: profileOutputBindings,
            fallback: Self.outputBindings(from: selectedKeyBindings)
        )
        let selectedOutputBindings = Self.effectiveOutputBindings(
            for: profile.outputMode,
            keyBindings: selectedKeyBindings,
            customOutputBindings: storedSelectedOutputBindings
        )

        releaseAll(reason: "Switch keypad setup")
        activeGamepadProfileID = profile.id
        gamepadCustomization = normalizedCustomization
        keyBindings = selectedKeyBindings
        outputBindings = selectedOutputBindings
        profileKeyBindings[profile.id] = selectedKeyBindings
        profileOutputBindings[profile.id] = selectedOutputBindings
        GamepadCustomizationPersistence.save(normalizedCustomization)
        persistGamepadProfileState()
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = "Switched keypad to \(profile.name)"

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeKeyBindings = selectedKeyBindings
            self.realtimeOutputBindings = selectedOutputBindings
            self.realtimeGamepadCustomization = normalizedCustomization
            self.realtimeActiveGamepadProfileID = profile.id
            self.realtimeOutputMode = profile.outputMode
            self.sendGamepadCustomizationOnNetworkQueue(normalizedCustomization)
        }
        logDebug("gamepad_profile_selected source=\(source) profile=\(profile.id.uuidString)")
        refreshVirtualGamepadMaterialization(reason: "gamepad_profile_selected", publish: false)
        publishRuntimeStatus()
    }

    func setDefaultGamepadProfile(_ profileID: UUID, source: String = "mac") {
        guard gamepadProfiles.contains(where: { $0.id == profileID }) else { return }
        defaultGamepadProfileID = profileID
        persistGamepadProfileState()
        lastReceivedEvent = "Updated default keypad setup"

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeDefaultGamepadProfileID = profileID
            self.sendGamepadProfileStateOnNetworkQueue()
        }
        logDebug("gamepad_default_profile_updated source=\(source) profile=\(profileID.uuidString)")
        publishRuntimeStatus()
    }

    func launchAttachedApplication(for profileID: UUID? = nil, source: String = "mac") {
        let targetProfileID = profileID ?? activeGamepadProfileID
        guard let profile = gamepadProfiles.first(where: { $0.id == targetProfileID }) else {
            lastReceivedEvent = "No keypad setup found for launch"
            publishRuntimeStatus()
            return
        }
        guard let launchTarget = profile.launchTarget else {
            lastReceivedEvent = "No application attached to \(profile.name)"
            publishRuntimeStatus()
            return
        }
        guard let applicationURL = launchTarget.resolvedApplicationURL() else {
            lastReceivedEvent = "Couldn’t find \(launchTarget.displayName)"
            publishRuntimeStatus()
            return
        }

        releaseAll(reason: "Launch attached application")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: applicationURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.lastReceivedEvent = "Couldn’t launch \(launchTarget.displayName): \(error.localizedDescription)"
                    self.logDebug("launch_application_failed source=\(source) profile=\(profile.id.uuidString) error=\(error.localizedDescription)")
                } else {
                    self.lastReceivedEvent = "Launched \(launchTarget.displayName)"
                    self.logDebug("launch_application source=\(source) profile=\(profile.id.uuidString) bundle=\(launchTarget.bundleIdentifier ?? "")")
                }
                self.publishRuntimeStatus()
            }
        }
    }

    private func persistGamepadProfileState() {
        GamepadConfigurationProfilePersistence.save(
            gamepadProfiles,
            activeProfileID: activeGamepadProfileID,
            defaultProfileID: defaultGamepadProfileID
        )
    }

    private func pruneProfileKeyBindings() {
        let validProfileIDs = Set(gamepadProfiles.map(\.id))
        profileKeyBindings = profileKeyBindings.filter { validProfileIDs.contains($0.key) }
        profileOutputBindings = profileOutputBindings.filter { validProfileIDs.contains($0.key) }
    }

    @discardableResult
    private func applyProfileStoreChangeNotification(_ notification: Notification, source: String) -> Bool {
        guard let profileStateData = Self.notificationData(from: notification.userInfo, key: Self.notificationProfileStateDataKey),
              let storedState = try? JSONDecoder().decode(ExternalStoredProfileState.self, from: profileStateData)
        else {
            return false
        }

        let fallbackCustomization: GamepadCustomization
        if let activeCustomizationData = Self.notificationData(from: notification.userInfo, key: Self.notificationActiveCustomizationDataKey),
           let decodedCustomization = try? JSONDecoder().decode(GamepadCustomization.self, from: activeCustomizationData) {
            fallbackCustomization = decodedCustomization.normalized
        } else {
            fallbackCustomization = gamepadCustomization
        }

        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: storedState.profiles,
            activeProfileID: storedState.activeProfileID,
            defaultProfileID: storedState.defaultProfileID,
            fallbackCustomization: fallbackCustomization
        )
        guard let activeProfile = state.activeProfile ?? state.defaultProfile ?? state.profiles.first else { return false }

        let activeCustomization = activeProfile.customization.normalized
        var loadedProfileKeyBindings = Self.notificationProfileKeyBindings(
            from: Self.notificationData(from: notification.userInfo, key: Self.notificationProfileKeyBindingsDataKey)
        ) ?? profileKeyBindings
        let activeKeyBindings = Self.notificationKeyBindings(
            from: Self.notificationData(from: notification.userInfo, key: Self.notificationKeyBindingsDataKey),
            fallback: Self.resolvedKeyBindings(
                for: activeProfile.id,
                in: loadedProfileKeyBindings,
                fallback: keyBindings
            )
        )
        loadedProfileKeyBindings[activeProfile.id] = activeKeyBindings
        var loadedProfileOutputBindings = Self.notificationProfileOutputBindings(
            from: Self.notificationData(from: notification.userInfo, key: Self.notificationProfileOutputBindingsDataKey),
            fallbackProfileKeyBindings: loadedProfileKeyBindings
        ) ?? profileOutputBindings
        let notifiedOutputBindings = Self.notificationOutputBindings(
            from: Self.notificationData(from: notification.userInfo, key: Self.notificationOutputBindingsDataKey),
            fallback: Self.resolvedOutputBindings(
                for: activeProfile.id,
                in: loadedProfileOutputBindings,
                fallback: Self.outputBindings(from: activeKeyBindings)
            )
        )
        let activeOutputBindings = Self.effectiveOutputBindings(
            for: activeProfile.outputMode,
            keyBindings: activeKeyBindings,
            customOutputBindings: notifiedOutputBindings
        )
        loadedProfileOutputBindings[activeProfile.id] = activeOutputBindings

        releaseAll(reason: "Apply external keypad profile update")
        gamepadProfiles = state.profiles
        activeGamepadProfileID = state.activeProfileID
        defaultGamepadProfileID = state.defaultProfileID
        gamepadCustomization = activeCustomization
        keyBindings = activeKeyBindings
        outputBindings = activeOutputBindings
        profileKeyBindings = loadedProfileKeyBindings
        profileOutputBindings = loadedProfileOutputBindings
        pruneProfileKeyBindings()
        GamepadCustomizationPersistence.save(activeCustomization)
        persistGamepadProfileState()
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = "Applied keypad profiles from \(source)"

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeKeyBindings = activeKeyBindings
            self.realtimeOutputBindings = activeOutputBindings
            self.realtimeGamepadCustomization = activeCustomization
            self.realtimeGamepadProfiles = state.profiles
            self.realtimeActiveGamepadProfileID = state.activeProfileID
            self.realtimeDefaultGamepadProfileID = state.defaultProfileID
            self.realtimeOutputMode = activeProfile.outputMode
            self.sendGamepadProfileStateOnNetworkQueue()
        }
        logDebug("gamepad_profiles_applied_from_notification source=\(source) profile=\(activeProfile.id.uuidString)")
        refreshVirtualGamepadMaterialization(reason: "profile_notification", publish: false)
        publishRuntimeStatus()
        return true
    }

    private func reloadProfilesFromDefaults(source: String) {
        UserDefaults.standard.synchronize()
        let savedGamepadCustomization = GamepadCustomizationPersistence.load()
        let loadedProfileState = GamepadConfigurationProfilePersistence.load(activeCustomization: savedGamepadCustomization)
        let activeProfile = loadedProfileState.activeProfile ?? loadedProfileState.defaultProfile ?? loadedProfileState.profiles[0]
        let activeCustomization = activeProfile.customization.normalized
        var loadedProfileKeyBindings = Self.loadProfileKeyBindings()
        var loadedProfileOutputBindings = Self.loadProfileOutputBindings(fallbackProfileKeyBindings: loadedProfileKeyBindings)
        let activeKeyBindings = Self.resolvedKeyBindings(
            for: activeProfile.id,
            in: loadedProfileKeyBindings,
            fallback: keyBindings
        )
        loadedProfileKeyBindings[activeProfile.id] = activeKeyBindings
        let storedActiveOutputBindings = Self.resolvedOutputBindings(
            for: activeProfile.id,
            in: loadedProfileOutputBindings,
            fallback: Self.outputBindings(from: activeKeyBindings)
        )
        let activeOutputBindings = Self.effectiveOutputBindings(
            for: activeProfile.outputMode,
            keyBindings: activeKeyBindings,
            customOutputBindings: storedActiveOutputBindings
        )
        loadedProfileOutputBindings[activeProfile.id] = activeOutputBindings

        releaseAll(reason: "Reload keypad profiles")
        gamepadProfiles = loadedProfileState.profiles
        activeGamepadProfileID = activeProfile.id
        defaultGamepadProfileID = loadedProfileState.defaultProfileID
        gamepadCustomization = activeCustomization
        keyBindings = activeKeyBindings
        outputBindings = activeOutputBindings
        profileKeyBindings = loadedProfileKeyBindings
        profileOutputBindings = loadedProfileOutputBindings
        pruneProfileKeyBindings()
        saveKeyBindings()
        saveProfileKeyBindings()
        saveOutputBindings()
        saveProfileOutputBindings()
        lastReceivedEvent = "Reloaded keypad profiles from \(source)"

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeKeyBindings = activeKeyBindings
            self.realtimeOutputBindings = activeOutputBindings
            self.realtimeGamepadCustomization = activeCustomization
            self.realtimeGamepadProfiles = loadedProfileState.profiles
            self.realtimeActiveGamepadProfileID = activeProfile.id
            self.realtimeDefaultGamepadProfileID = loadedProfileState.defaultProfileID
            self.realtimeOutputMode = activeProfile.outputMode
            self.sendGamepadProfileStateOnNetworkQueue()
        }
        logDebug("gamepad_profiles_reloaded source=\(source) profile=\(activeProfile.id.uuidString)")
        refreshVirtualGamepadMaterialization(reason: "profiles_reload", publish: false)
        publishRuntimeStatus()
    }

    func sendTestDown(_ button: GameButton) {
        asyncOnNetworkQueue { [weak self] in
            self?.handleButtonOnNetworkQueue(button, state: .down, source: "Local test")
        }
    }

    func sendTestUp(_ button: GameButton) {
        asyncOnNetworkQueue { [weak self] in
            self?.handleButtonOnNetworkQueue(button, state: .up, source: "Local test")
        }
    }

    func releaseAll(reason: String = "Release all") {
        syncOnNetworkQueue {
            releaseAllOnNetworkQueue(reason: reason)
        }
    }

    private func releaseAllOnNetworkQueue(reason: String) {
        resetPendingButtonMessagesOnNetworkQueue()
        resetPhysicalInputTrackingOnNetworkQueue()
        buttonSequenceTracker.resetAcceptingNextSequenceAsBaseline()
        lastAnalogSequenceNumberByKey.removeAll()
        activeAnalogStickLastSeenByStick.removeAll()
        activeAnalogTriggerLastSeenByTrigger.removeAll()
        captureSystemEventOnNetworkQueue(kind: "release_all", detail: reason)

        guard !inputPressedButtons.isEmpty || !inputPressedElementInputs.isEmpty || !heldBindingCounts.isEmpty || !heldGamepadButtonCounts.isEmpty || !activePointerButtons.isEmpty else {
            virtualGamepadInjector.reset()
            return
        }
        for binding in heldBindingCounts.keys {
            injector.keyUp(binding)
        }
        for button in activePointerButtons {
            pointerInjector.setButton(button, pressed: false)
        }
        heldBindingCounts.removeAll()
        heldGamepadButtonCounts.removeAll()
        activeBindings.removeAll()
        activeOutputBindings.removeAll()
        activeElementOutputBindings.removeAll()
        activePointerButtons.removeAll()
        inputPressedButtons.removeAll()
        inputPressedElementInputs.removeAll()
        virtualGamepadInjector.reset()
        publishControllerDebug(event: reason, pressedButtons: [], immediately: true)
        logDebug("release_all reason=\(reason) pressed=[]")
    }

    private func accept(_ newConnection: NWConnection) {
        asyncOnNetworkQueue { [weak self] in
            self?.acceptOnNetworkQueue(newConnection)
        }
    }

    private func acceptOnNetworkQueue(_ newConnection: NWConnection) {
        if let existing = realtimeConnection {
            releaseAllOnNetworkQueue(reason: "Replaced by new iPhone connection")
            existing.cancel()
        }
        resetRealtimeDatagramAuthenticationOnNetworkQueue(cancelConnections: true)
        realtimeConnection = newConnection
        pairedConnection = nil
        pendingPairingConnection = newConnection
        realtimeToken = nil
        resetButtonSequenceDiagnosticsOnNetworkQueue()
        resetPhysicalInputTrackingOnNetworkQueue()

        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let newConnection else { return }
            DispatchQueue.main.async { self?.handleConnectionState(state, connection: newConnection) }
        }

        DispatchQueue.main.async { [weak self, weak newConnection] in
            guard let self, let newConnection else { return }
            if let existing = self.connection, existing !== newConnection {
                existing.cancel()
            }
            self.connection = newConnection
            self.heartbeatTimedOut = false
            self.isClientConnected = false
            self.isPairingPending = false
            self.pendingPairingClientName = nil
            self.clientName = "Pairing not started"
            self.lastHeartbeat = nil
            self.statusText = "Waiting for pairing request"
            self.missedButtonFrames = 0
            self.ignoredButtonEdges = 0
            self.recoveredButtonEdges = 0
            self.logDebug("client socket accepted")
        }

        newConnection.start(queue: networkQueue)
    }

    private func receiveNext(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection else { return }

            if let error {
                DispatchQueue.main.async { self.handleReceiveError(error, connection: connection) }
                return
            }

            if let data, !data.isEmpty {
                self.handleReceivedDataOnNetworkQueue(data, from: connection)
            }

            if self.realtimeConnection === connection {
                self.receiveNext(on: connection)
            }
        }
    }

    private func startDatagramListenerOnNetworkQueue(on port: UInt16) {
        guard datagramListenerPort != port || datagramListener == nil else { return }

        stopDatagramListenerOnNetworkQueue()

        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let parameters = NWParameters.udp
        parameters.includePeerToPeer = true
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(using: parameters, on: nwPort)
            datagramListener = listener
            datagramListenerPort = port

            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self, let listener else { return }
                self.handleDatagramListenerStateOnNetworkQueue(state, listener: listener)
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.acceptDatagramConnectionOnNetworkQueue(connection)
            }

            listener.start(queue: networkQueue)
            logDebug("datagram_listener_starting port=\(port)")
        } catch {
            datagramListener = nil
            datagramListenerPort = nil
            logDebug("datagram_listener_failed port=\(port) error=\(error.localizedDescription)")
        }
    }

    private func stopDatagramListenerOnNetworkQueue() {
        datagramListener?.cancel()
        datagramListener = nil
        datagramListenerPort = nil
        resetRealtimeDatagramAuthenticationOnNetworkQueue(cancelConnections: true)
    }

    private func handleDatagramListenerStateOnNetworkQueue(
        _ state: NWListener.State,
        listener stateListener: NWListener
    ) {
        guard datagramListener === stateListener else { return }

        switch state {
        case .ready:
            logDebug("datagram_listener_ready port=\(datagramListenerPort ?? 0)")

        case .failed(let error):
            logDebug("datagram_listener_failed error=\(error.localizedDescription)")
            stopDatagramListenerOnNetworkQueue()

        case .cancelled:
            if datagramListener === stateListener {
                datagramListener = nil
                datagramListenerPort = nil
            }

        default:
            break
        }
    }

    private func acceptDatagramConnectionOnNetworkQueue(_ newConnection: NWConnection) {
        let id = ObjectIdentifier(newConnection)
        datagramConnections[id] = newConnection

        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let self, let newConnection else { return }
            self.handleDatagramConnectionStateOnNetworkQueue(state, connection: newConnection)
        }

        newConnection.start(queue: networkQueue)
        receiveNextDatagram(on: newConnection)
    }

    private func handleDatagramConnectionStateOnNetworkQueue(
        _ state: NWConnection.State,
        connection stateConnection: NWConnection
    ) {
        switch state {
        case .failed, .cancelled:
            removeDatagramConnectionOnNetworkQueue(stateConnection)

        default:
            break
        }
    }

    private func receiveNextDatagram(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection else { return }

            if error != nil {
                self.removeDatagramConnectionOnNetworkQueue(connection)
                return
            }

            if let data, !data.isEmpty {
                self.handleReceivedDatagramDataOnNetworkQueue(data, from: connection)
            }

            if self.datagramConnections[ObjectIdentifier(connection)] === connection {
                self.receiveNextDatagram(on: connection)
            }
        }
    }

    private func handleReceivedDatagramDataOnNetworkQueue(_ data: Data, from connection: NWConnection) {
        guard let message = try? ControllerWireCodec.decode(data, using: decoder) else {
            logInputEvent("invalid_datagram_message bytes=\(data.count)")
            return
        }

        if message.type == .hello {
            authenticateDatagramConnectionOnNetworkQueue(connection, message: message)
            return
        }

        guard authenticatedDatagramConnection === connection,
              let pairedConnection
        else {
            logInputEvent("ignored_unauthenticated_datagram type=\(message.type.rawValue)")
            return
        }

        publishClientActivity(from: pairedConnection, force: message.type != .button && message.type != .elementInput && message.type != .pointer)

        switch message.type {
        case .button:
            handleButtonMessageOnNetworkQueue(message, source: "iPhone UDP")

        case .elementInput:
            handleElementInputMessageOnNetworkQueue(message, source: "iPhone UDP")

        case .pointer:
            handlePointerMessageOnNetworkQueue(message, source: "iPhone UDP")

        case .gamepadAnalog:
            handleGamepadAnalogMessageOnNetworkQueue(message, source: "iPhone UDP")

        case .releaseAll:
            releaseAllOnNetworkQueue(reason: "release_all from iPhone UDP")

        case .heartbeat:
            if let latency = oneWayLatencyMilliseconds(from: message.timestamp) {
                publishEstimatedLatency(latency, from: pairedConnection)
            }

        default:
            break
        }
    }

    private func authenticateDatagramConnectionOnNetworkQueue(
        _ connection: NWConnection,
        message: ControllerMessage
    ) {
        guard let realtimeToken,
              pairedConnection != nil,
              message.realtimeToken == realtimeToken
        else {
            logInputEvent("ignored_datagram_hello")
            return
        }

        authenticatedDatagramConnection = connection
        logDebug("datagram_authenticated client=\(message.clientName ?? "iPhone")")
    }

    private func removeDatagramConnectionOnNetworkQueue(_ connection: NWConnection) {
        datagramConnections[ObjectIdentifier(connection)] = nil
        if authenticatedDatagramConnection === connection {
            authenticatedDatagramConnection = nil
        }
        connection.cancel()
    }

    private func resetRealtimeDatagramAuthenticationOnNetworkQueue(cancelConnections: Bool) {
        authenticatedDatagramConnection = nil

        guard cancelConnections else { return }
        for connection in datagramConnections.values {
            connection.cancel()
        }
        datagramConnections.removeAll()
    }

    private func handleReceivedDataOnNetworkQueue(_ data: Data, from connection: NWConnection) {
        guard realtimeConnection === connection else { return }
        do {
            let message = try ControllerWireCodec.decode(data, using: decoder)
            handleMessageOnNetworkQueue(message, from: connection)
        } catch {
            publishControllerDebug(event: "Invalid keypad message: \(error.localizedDescription)", immediately: true)
            logDebug("invalid_message error=\(error.localizedDescription)")
        }
    }

    private func handleMessageOnNetworkQueue(_ message: ControllerMessage, from connection: NWConnection) {
        guard realtimeConnection === connection else { return }
        let isPairedConnection = pairedConnection === connection

        if isPairedConnection {
            publishClientActivity(from: connection, force: message.type != .button && message.type != .elementInput && message.type != .pointer)
        }

        switch message.type {
        case .pairingRequest:
            handlePairingRequestOnNetworkQueue(message, from: connection)

        case .hello:
            if let authToken = normalizedAuthToken(message.authToken) {
                guard message.serverID == nil || message.serverID == serverID else {
                    rejectPairingOnNetworkQueue(connection, reason: "This iPhone is trusted for a different Mac")
                    return
                }
                guard trustedClients[authToken] != nil else {
                    rejectPairingOnNetworkQueue(connection, reason: "Trusted pairing expired. Scan the Mac QR code once to reconnect.")
                    return
                }
                acceptPairedClientOnNetworkQueue(
                    message.clientName,
                    from: connection,
                    authToken: authToken,
                    isTrustedReconnect: true,
                    clientDeviceInfo: message.clientDeviceInfo
                )
                return
            }

            guard let submittedCode = normalizedPairingCode(message.pairingCode) else {
                handlePairingRequestOnNetworkQueue(message, from: connection)
                return
            }
            guard submittedCode == activePairingCode else {
                rejectPairingOnNetworkQueue(connection, reason: "Wrong pairing code")
                return
            }
            acceptPairedClientOnNetworkQueue(message.clientName, from: connection, clientDeviceInfo: message.clientDeviceInfo)

        case .button:
            guard isPairedConnection else {
                logDebug("ignored_unpaired_message type=button")
                return
            }
            handleButtonMessageOnNetworkQueue(message, source: "iPhone")

        case .elementInput:
            guard isPairedConnection else {
                logDebug("ignored_unpaired_message type=element_input")
                return
            }
            handleElementInputMessageOnNetworkQueue(message, source: "iPhone")

        case .pointer:
            guard isPairedConnection else {
                logDebug("ignored_unpaired_message type=pointer")
                return
            }
            handlePointerMessageOnNetworkQueue(message, source: "iPhone")

        case .gamepadAnalog:
            guard isPairedConnection else {
                logDebug("ignored_unpaired_message type=gamepad_analog")
                return
            }
            handleGamepadAnalogMessageOnNetworkQueue(message, source: "iPhone")

        case .releaseAll:
            guard isPairedConnection else { return }
            releaseAllOnNetworkQueue(reason: "release_all from iPhone")

        case .heartbeat:
            guard isPairedConnection else { return }
            if let latency = oneWayLatencyMilliseconds(from: message.timestamp) {
                publishEstimatedLatency(latency, from: connection)
            }

        case .ping:
            guard isPairedConnection else { return }
            send(.init(type: .pong, timestamp: message.timestamp), on: connection)

        case .pong:
            guard isPairedConnection else { return }
            if let latency = roundTripLatencyMilliseconds(from: message.timestamp) {
                publishEstimatedLatency(latency, from: connection)
            }

        case .gamepadCustomization:
            guard isPairedConnection else { return }
            guard let clientCustomization = message.gamepadCustomization else {
                sendGamepadCustomizationOnNetworkQueue(realtimeGamepadCustomization)
                return
            }
            let profileID = message.gamepadProfileID
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let profileID,
                   profileID != self.activeGamepadProfileID,
                   self.gamepadProfiles.contains(where: { $0.id == profileID }) {
                    self.selectGamepadProfile(profileID, source: "iphone")
                }
                self.setGamepadCustomization(clientCustomization)
                self.lastReceivedEvent = "Updated keypad layout from iPhone"
                self.publishRuntimeStatus()
            }
            logDebug("gamepad_customization_updated source=iphone profile=\(profileID?.uuidString ?? "active")")

        case .gamepadProfileSelection:
            guard isPairedConnection, let profileID = message.gamepadProfileID else { return }
            DispatchQueue.main.async { [weak self] in
                self?.selectGamepadProfile(profileID, source: "iphone")
            }

        case .gamepadDefaultProfile:
            guard isPairedConnection, let profileID = message.defaultGamepadProfileID ?? message.gamepadProfileID else { return }
            DispatchQueue.main.async { [weak self] in
                self?.setDefaultGamepadProfile(profileID, source: "iphone")
            }

        case .launchProfileTarget:
            guard isPairedConnection else { return }
            let profileID = message.gamepadProfileID
            DispatchQueue.main.async { [weak self] in
                self?.launchAttachedApplication(for: profileID, source: "iphone")
            }

        case .gamepadProfiles:
            guard isPairedConnection else { return }
            sendGamepadProfileStateOnNetworkQueue()

        case .pairingChallenge, .pairingAccepted:
            break

        case .error:
            publishControllerDebug(event: message.message ?? "Client error", immediately: true)
        }
    }

    private func handlePairingRequestOnNetworkQueue(_ message: ControllerMessage, from connection: NWConnection) {
        guard realtimeConnection === connection else { return }

        let requestClientName = message.clientName ?? "iPhone"
        let newPairingCode = Self.generatePairingCode()
        activePairingCode = newPairingCode
        pendingPairingConnection = connection
        pairedConnection = nil
        resetRealtimeDatagramAuthenticationOnNetworkQueue(cancelConnections: true)
        realtimeToken = nil

        send(
            .init(
                type: .pairingChallenge,
                message: "Pairing request accepted. Enter the code shown on PocketPad Mac."
            ),
            on: connection
        )

        DispatchQueue.main.async { [weak self, weak connection] in
            guard let self,
                  let connection,
                  self.connection === connection
            else { return }

            self.pairingCode = newPairingCode
            self.isPairingPending = true
            self.pendingPairingClientName = requestClientName
            self.isClientConnected = false
            self.clientName = requestClientName
            self.clientDeviceInfo = message.clientDeviceInfo
            self.lastHeartbeat = nil
            self.statusText = "Waiting for \(requestClientName) to enter pairing code"
            self.lastReceivedEvent = "Pairing request from \(requestClientName)"
        }

        logDebug("pairing_request client=\(requestClientName)")
    }

    private func acceptPairedClientOnNetworkQueue(
        _ incomingClientName: String?,
        from connection: NWConnection,
        authToken existingAuthToken: String? = nil,
        isTrustedReconnect: Bool = false,
        clientDeviceInfo: ControllerClientDeviceInfo? = nil
    ) {
        guard realtimeConnection === connection else { return }

        let newRealtimeToken = Self.generateRealtimeToken()
        let trustedAuthToken = existingAuthToken ?? Self.generateAuthToken()
        rememberTrustedClientOnNetworkQueue(token: trustedAuthToken, clientName: incomingClientName)
        pendingPairingConnection = nil
        pairedConnection = connection
        realtimeToken = newRealtimeToken
        let clientGamepadCustomization = gamepadCustomizationForClient(realtimeGamepadCustomization)
        let clientGamepadProfiles = gamepadProfilesForClient(realtimeGamepadProfiles)

        send(
            .init(
                type: .pairingAccepted,
                message: isTrustedReconnect ? "Smart Connect complete" : "Pairing complete",
                realtimeToken: newRealtimeToken,
                authToken: trustedAuthToken,
                serverID: serverID,
                gamepadCustomization: clientGamepadCustomization,
                gamepadProfiles: clientGamepadProfiles,
                gamepadProfileID: realtimeActiveGamepadProfileID,
                defaultGamepadProfileID: realtimeDefaultGamepadProfileID
            ),
            on: connection
        )
        publishHello(incomingClientName, clientDeviceInfo: clientDeviceInfo, from: connection)

        DispatchQueue.main.async { [weak self, weak connection] in
            guard let self,
                  let connection,
                  self.connection === connection
            else { return }

            self.isPairingPending = false
            self.pendingPairingClientName = nil
            self.isClientConnected = true
            self.statusText = "Client connected"
        }

        logDebug("pairing_accepted client=\(incomingClientName ?? "Connected iPhone") trusted=\(isTrustedReconnect)")
    }

    private func rejectPairingOnNetworkQueue(_ connection: NWConnection, reason: String) {
        send(.init(type: .error, message: reason), on: connection)
        connection.cancel()
        releaseAllOnNetworkQueue(reason: "Rejected pairing: \(reason)")
        clearPairingStateOnNetworkQueue(for: connection)
        logDebug("pairing_rejected reason=\(reason)")
    }

    private func cancelPendingPairingOnNetworkQueue(reason: String) {
        guard let pendingPairingConnection else { return }
        send(.init(type: .error, message: reason), on: pendingPairingConnection)
        pendingPairingConnection.cancel()
        clearPairingStateOnNetworkQueue(for: pendingPairingConnection)
        logDebug("pairing_cancelled reason=\(reason)")
    }

    private func clearPairingStateOnNetworkQueue(for connection: NWConnection?) {
        if let connection {
            if pendingPairingConnection === connection {
                pendingPairingConnection = nil
            }
            if pairedConnection === connection {
                pairedConnection = nil
            }
            if realtimeConnection === connection {
                realtimeConnection = nil
            }
            if pairedConnection == nil {
                realtimeToken = nil
                resetRealtimeDatagramAuthenticationOnNetworkQueue(cancelConnections: true)
            }
        } else {
            pendingPairingConnection = nil
            pairedConnection = nil
            realtimeToken = nil
            resetRealtimeDatagramAuthenticationOnNetworkQueue(cancelConnections: true)
        }

        let clearedConnection = connection
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let clearedConnection, self.connection !== clearedConnection { return }

            self.isPairingPending = false
            self.pendingPairingClientName = nil
            if !self.isClientConnected {
                self.clientName = "No client"
                self.clientDeviceInfo = nil
                self.statusText = self.isRunning ? "Listening on port \(self.port)" : "Stopped"
            }
        }
    }

    private func normalizedPairingCode(_ code: String?) -> String? {
        guard let code else { return nil }
        let normalized = String(code.filter(\.isNumber).prefix(6))
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedAuthToken(_ token: String?) -> String? {
        guard let token else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func rememberTrustedClientOnNetworkQueue(token: String, clientName: String?) {
        let now = Date.currentMilliseconds
        let resolvedName = clientName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "iPhone"
        let existing = trustedClients[token]
        trustedClients[token] = TrustedClient(
            token: token,
            clientName: resolvedName,
            createdAt: existing?.createdAt ?? now,
            lastSeenAt: now
        )
        saveTrustedClients()
    }

    private func inspectButtonSequence(
        _ message: ControllerMessage,
        button: GameButton,
        state: ButtonPressState
    ) -> ButtonSequenceInspection {
        let inspection = buttonSequenceTracker.inspect(message)
        if inspection.missedFrameBeforeButton,
           let expectedSequence = inspection.expectedSequence,
           let receivedSequence = inspection.receivedSequence
        {
            publishButtonSequenceGap(
                expectedSequence: expectedSequence,
                receivedSequence: receivedSequence,
                missedFrameCount: inspection.missedFrameCount,
                totalMissedButtonFrames: inspection.totalMissedFrameCount,
                button: button,
                state: state
            )
            logDebug("button_sequence_gap expected=\(expectedSequence) received=\(receivedSequence) missed=\(inspection.missedFrameCount) button=\(button.rawValue) state=\(state.rawValue)")
        } else if inspection.isOutOfOrderOrReset,
                  let expectedSequence = inspection.expectedSequence,
                  let receivedSequence = inspection.receivedSequence
        {
            logInputEvent("button_sequence_stale expected=\(expectedSequence) received=\(receivedSequence) button=\(button.rawValue) state=\(state.rawValue)")
        }

        return inspection
    }

    private func handlePointerMessageOnNetworkQueue(_ message: ControllerMessage, source: String) {
        guard let event = message.pointerEvent else {
            publishControllerDebug(event: "Ignored malformed pointer event", immediately: true)
            return
        }

        switch event {
        case .move:
            let deltaX = message.deltaX ?? 0
            let deltaY = message.deltaY ?? 0
            pointerInjector.moveBy(deltaX: deltaX, deltaY: deltaY)
            appendCaptureEvent(PocketPadCaptureEvent(
                kind: "pointer",
                source: source,
                messageType: .pointer,
                pointerEvent: event,
                deltaX: deltaX,
                deltaY: deltaY,
                latencyMS: oneWayLatencyMilliseconds(from: captureLatencyTimestamp(for: message)),
                pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
                pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
                activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue()
            ))
            logInputEvent("pointer source=\(source) event=move dx=\(String(format: "%.2f", deltaX)) dy=\(String(format: "%.2f", deltaY))")

        case .scroll:
            let deltaX = message.deltaX ?? 0
            let deltaY = message.deltaY ?? 0
            pointerInjector.scrollBy(deltaX: deltaX, deltaY: deltaY)
            appendCaptureEvent(PocketPadCaptureEvent(
                kind: "pointer",
                source: source,
                messageType: .pointer,
                pointerEvent: event,
                deltaX: deltaX,
                deltaY: deltaY,
                latencyMS: oneWayLatencyMilliseconds(from: captureLatencyTimestamp(for: message)),
                pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
                pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
                activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue()
            ))
            logInputEvent("pointer source=\(source) event=scroll dx=\(String(format: "%.2f", deltaX)) dy=\(String(format: "%.2f", deltaY))")

        case .button:
            guard let pointerButton = message.pointerButton,
                  let state = message.state
            else {
                publishControllerDebug(event: "Ignored malformed pointer button event", immediately: true)
                return
            }

            let fingerprint = PointerButtonEventFingerprint(
                button: pointerButton,
                state: state,
                timestamp: message.timestamp
            )
            guard !isDuplicatePointerButtonEvent(fingerprint) else { return }

            switch state {
            case .down:
                guard activePointerButtons.insert(pointerButton).inserted else { return }
                rememberPointerButtonEvent(fingerprint)
                pointerInjector.setButton(pointerButton, pressed: true)
            case .up:
                guard activePointerButtons.remove(pointerButton) != nil else { return }
                rememberPointerButtonEvent(fingerprint)
                pointerInjector.setButton(pointerButton, pressed: false)
            }
            appendCaptureEvent(PocketPadCaptureEvent(
                kind: "pointer",
                source: source,
                messageType: .pointer,
                state: state,
                pointerEvent: event,
                pointerButton: pointerButton,
                latencyMS: oneWayLatencyMilliseconds(from: captureLatencyTimestamp(for: message)),
                pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
                pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
                activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue()
            ))
            logInputEvent("pointer source=\(source) event=button button=\(pointerButton.rawValue) state=\(state.rawValue)")
        }
    }

    private func isDuplicatePointerButtonEvent(_ fingerprint: PointerButtonEventFingerprint) -> Bool {
        pruneRecentPointerButtonEvents()
        return recentPointerButtonEvents[fingerprint] != nil
    }

    private func rememberPointerButtonEvent(_ fingerprint: PointerButtonEventFingerprint) {
        pruneRecentPointerButtonEvents()
        recentPointerButtonEvents[fingerprint] = DispatchTime.now().uptimeNanoseconds
    }

    private func pruneRecentPointerButtonEvents() {
        let now = DispatchTime.now().uptimeNanoseconds
        recentPointerButtonEvents = recentPointerButtonEvents.filter { _, eventUptime in
            now - eventUptime <= Self.pointerButtonDuplicateWindowNanoseconds
        }
    }

    private func handleGamepadAnalogMessageOnNetworkQueue(_ message: ControllerMessage, source: String) {
        guard realtimeOutputMode != .keyboard else {
            logInputEvent("gamepad_analog_ignored source=\(source) mode=keyboard")
            return
        }

        if let stick = message.analogStick {
            let sequenceKey = "stick.\(stick.rawValue)"
            guard acceptAnalogSequence(message.analogSequence, key: sequenceKey, source: source) else { return }

            let x = message.analogX ?? 0
            let y = message.analogY ?? 0
            if abs(x) < 0.001 && abs(y) < 0.001 {
                activeAnalogStickLastSeenByStick[stick] = nil
            } else {
                activeAnalogStickLastSeenByStick[stick] = DispatchTime.now().uptimeNanoseconds
            }
            virtualGamepadInjector.setStick(stick, x: x, y: y)
            appendCaptureEvent(PocketPadCaptureEvent(
                kind: "gamepad_analog",
                source: source,
                messageType: .gamepadAnalog,
                analogStick: stick,
                analogX: x,
                analogY: y,
                inputSequence: message.analogSequence,
                latencyMS: oneWayLatencyMilliseconds(from: captureLatencyTimestamp(for: message)),
                pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
                pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
                activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue()
            ))
            logInputEvent("gamepad_analog source=\(source) stick=\(stick.rawValue) x=\(String(format: "%.3f", x)) y=\(String(format: "%.3f", y))")
            return
        }

        if let trigger = message.analogTrigger {
            let sequenceKey = "trigger.\(trigger.rawValue)"
            guard acceptAnalogSequence(message.analogSequence, key: sequenceKey, source: source) else { return }

            let value = message.analogValue ?? 0
            if value < 0.001 {
                activeAnalogTriggerLastSeenByTrigger[trigger] = nil
            } else {
                activeAnalogTriggerLastSeenByTrigger[trigger] = DispatchTime.now().uptimeNanoseconds
            }
            virtualGamepadInjector.setTrigger(trigger, value: value)
            appendCaptureEvent(PocketPadCaptureEvent(
                kind: "gamepad_analog",
                source: source,
                messageType: .gamepadAnalog,
                analogTrigger: trigger,
                analogValue: value,
                inputSequence: message.analogSequence,
                latencyMS: oneWayLatencyMilliseconds(from: captureLatencyTimestamp(for: message)),
                pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
                pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
                activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue()
            ))
            logInputEvent("gamepad_analog source=\(source) trigger=\(trigger.rawValue) value=\(String(format: "%.3f", value))")
            return
        }

        publishControllerDebug(event: "Ignored malformed analog gamepad event", immediately: true)
    }

    private func acceptAnalogSequence(_ sequence: UInt64?, key: String, source: String) -> Bool {
        guard let sequence else { return true }
        if let lastSequence = lastAnalogSequenceNumberByKey[key],
           sequence <= lastSequence,
           lastSequence - sequence < ControllerWireCodec.maximumButtonSequenceNumber / 2
        {
            logInputEvent("gamepad_analog_stale source=\(source) key=\(key) sequence=\(sequence) last=\(lastSequence)")
            return false
        }
        lastAnalogSequenceNumberByKey[key] = sequence
        return true
    }

    private func handleElementInputMessageOnNetworkQueue(_ message: ControllerMessage, source: String) {
        guard let elementID = message.elementID,
              let state = message.state
        else {
            publishControllerDebug(event: "Ignored malformed element input", immediately: true)
            return
        }

        let input = KeypadElementInputID(elementID: elementID, part: message.elementPart ?? .primary)
        if let sequenceNumber = ControllerWireCodec.inputSequenceNumber(from: message),
           shouldTemporarilyBufferButtonMessage(sequenceNumber: sequenceNumber)
        {
            bufferElementInputMessage(
                message,
                input: input,
                state: state,
                source: source,
                sequenceNumber: sequenceNumber
            )
            return
        }

        processElementInputMessageOnNetworkQueue(message, input: input, state: state, source: source)
        drainPendingButtonMessagesOnNetworkQueue()
        cancelButtonReorderFlushIfIdle()
    }

    private func processElementInputMessageOnNetworkQueue(
        _ message: ControllerMessage,
        input: KeypadElementInputID,
        state: ButtonPressState,
        source: String
    ) {
        let inspection = buttonSequenceTracker.inspect(message)
        if inspection.isOutOfOrderOrReset,
           let expectedSequence = inspection.expectedSequence,
           let receivedSequence = inspection.receivedSequence
        {
            logInputEvent("element_input_sequence_stale expected=\(expectedSequence) received=\(receivedSequence) input=\(input.storageKey) state=\(state.rawValue)")
            return
        }
        if inspection.missedFrameBeforeButton,
           let expectedSequence = inspection.expectedSequence,
           let receivedSequence = inspection.receivedSequence
        {
            logDebug("element_input_sequence_gap expected=\(expectedSequence) received=\(receivedSequence) missed=\(inspection.missedFrameCount) input=\(input.storageKey) state=\(state.rawValue)")
        }

        handleElementInputOnNetworkQueue(
            input,
            state: state,
            source: source,
            sequenceInspection: inspection,
            pressIdentifier: ControllerWireCodec.inputPressIdentifier(from: message),
            messageTimestamp: captureLatencyTimestamp(for: message)
        )
    }

    private func handleElementInputOnNetworkQueue(
        _ input: KeypadElementInputID,
        state: ButtonPressState,
        source: String,
        sequenceInspection: ButtonSequenceInspection = ButtonSequenceInspection(),
        pressIdentifier: UInt64?,
        messageTimestamp: Int64? = nil
    ) {
        if sequenceInspection.isOutOfOrderOrReset, sequenceInspection.hasSequence {
            return
        }

        switch state {
        case .down:
            if hasElementPressOnNetworkQueue(input),
               sequenceInspection.missedFrameBeforeButton
            {
                if hasIdentifiedElementPressOnNetworkQueue(input, pressIdentifier: pressIdentifier)
                    || (pressIdentifier == nil && (anonymousPressCountsByElementInput[input] ?? 0) > 0)
                {
                    refreshElementPressSeenOnNetworkQueue(input, pressIdentifier: pressIdentifier)
                    logDebug("element_input_refresh_after_gap input=\(input.storageKey) pressIdentifier=\(pressIdentifier.map(String.init) ?? "nil")")
                    return
                }

                logDebug("recovered_element_input_edge reason=missing_release_before_down input=\(input.storageKey) state=\(state.rawValue)")
                resetElementHoldsOnNetworkQueue(for: input, keeping: pressIdentifier)
                handleElementInputEdgeOnNetworkQueue(input, state: .up, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp, detail: "missing_release_before_down")
                handleElementInputEdgeOnNetworkQueue(input, state: .down, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp, detail: "missing_release_before_down")
                return
            }

            if recordElementPressBeganOnNetworkQueue(input, pressIdentifier: pressIdentifier) {
                handleElementInputEdgeOnNetworkQueue(input, state: .down, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp)
            }

        case .up:
            switch recordElementPressEndedOnNetworkQueue(input, pressIdentifier: pressIdentifier) {
            case .shouldReleaseKey:
                handleElementInputEdgeOnNetworkQueue(input, state: .up, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp)

            case .stillHeld:
                break

            case .orphan:
                if sequenceInspection.missedFrameBeforeButton,
                   !hasElementPressOnNetworkQueue(input)
                {
                    logDebug("recovered_element_input_edge reason=missing_down_before_up input=\(input.storageKey) state=\(state.rawValue)")
                    handleElementInputEdgeOnNetworkQueue(input, state: .down, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp, detail: "missing_down_before_up")
                    handleElementInputEdgeOnNetworkQueue(input, state: .up, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp, detail: "missing_down_before_up")
                } else {
                    appendCaptureEvent(PocketPadCaptureEvent(
                        kind: "ignored_element_input_edge",
                        source: source,
                        messageType: .elementInput,
                        elementInput: input,
                        elementLabel: elementDebugLabelOnNetworkQueue(for: input),
                        state: state,
                        inputSequence: sequenceInspection.receivedSequence,
                        expectedSequence: sequenceInspection.expectedSequence,
                        receivedSequence: sequenceInspection.receivedSequence,
                        missedFrameCount: sequenceInspection.missedFrameCount > 0 ? sequenceInspection.missedFrameCount : nil,
                        totalMissedButtonFrames: sequenceInspection.totalMissedFrameCount > 0 ? sequenceInspection.totalMissedFrameCount : nil,
                        pressIdentifier: pressIdentifier,
                        latencyMS: messageTimestamp.flatMap(oneWayLatencyMilliseconds(from:)),
                        pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
                        pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
                        activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue(),
                        detail: "orphan_up"
                    ))
                    logDebug("ignored_element_input_edge reason=orphan_up input=\(input.storageKey) state=\(state.rawValue)")
                }
            }
        }
    }

    private func handleElementInputEdgeOnNetworkQueue(
        _ input: KeypadElementInputID,
        state: ButtonPressState,
        source: String,
        sequenceInspection: ButtonSequenceInspection = ButtonSequenceInspection(),
        pressIdentifier: UInt64? = nil,
        messageTimestamp: Int64? = nil,
        detail: String? = nil
    ) {
        guard let baseOutput = elementOutputBindingOnNetworkQueue(for: input), !baseOutput.isEmpty else { return }

        switch state {
        case .down:
            guard !inputPressedElementInputs.contains(input) else { return }
            let effectiveOutput = baseOutput.withAdditionalModifiers(activeModifierKeysOnNetworkQueue())
            activeElementOutputBindings[input] = effectiveOutput
            activateOutput(effectiveOutput)
            inputPressedElementInputs.insert(input)
            let label = elementDebugLabelOnNetworkQueue(for: input)
            publishControllerDebug(event: "\(source): \(label) down (\(effectiveOutput.displayName))", pressedButtons: inputPressedButtons)
            captureElementInputEventOnNetworkQueue(
                source: source,
                input: input,
                label: label,
                state: state,
                binding: effectiveOutput,
                sequenceInspection: sequenceInspection,
                pressIdentifier: pressIdentifier,
                messageTimestamp: messageTimestamp,
                detail: detail
            )
            logInputEvent("element_input source=\(source) input=\(input.storageKey) state=down binding=\(effectiveOutput.displayName)")

        case .up:
            guard inputPressedElementInputs.contains(input) else { return }
            let releasedOutput = activeElementOutputBindings.removeValue(forKey: input) ?? baseOutput
            deactivateOutput(releasedOutput)
            inputPressedElementInputs.remove(input)
            let label = elementDebugLabelOnNetworkQueue(for: input)
            publishControllerDebug(event: "\(source): \(label) up (\(releasedOutput.displayName))", pressedButtons: inputPressedButtons)
            captureElementInputEventOnNetworkQueue(
                source: source,
                input: input,
                label: label,
                state: state,
                binding: releasedOutput,
                sequenceInspection: sequenceInspection,
                pressIdentifier: pressIdentifier,
                messageTimestamp: messageTimestamp,
                detail: detail
            )
            logInputEvent("element_input source=\(source) input=\(input.storageKey) state=up binding=\(releasedOutput.displayName)")
        }
    }

    private func elementOutputBindingOnNetworkQueue(for input: KeypadElementInputID) -> MacControlOutputBinding? {
        guard let element = realtimeGamepadCustomization.element(for: input.elementID) else { return nil }
        if let directOutput = element.outputBinding(for: input.part) {
            return MacControlOutputBinding(shared: directOutput)
        }
        guard let legacyButton = Self.legacyButton(for: input.part, element: element) else { return nil }
        return realtimeOutputBindings[legacyButton] ?? realtimeKeyBindings[legacyButton].map { MacControlOutputBinding.keyboard($0) }
    }

    private static func legacyButton(for part: KeypadElementInputPart, element: KeypadElement) -> GameButton? {
        switch part {
        case .primary, .triggerDigital:
            return element.legacySlot
        case .joystickUp:
            return element.joystickMapping?.up
        case .joystickDown:
            return element.joystickMapping?.down
        case .joystickLeft:
            return element.joystickMapping?.left
        case .joystickRight:
            return element.joystickMapping?.right
        }
    }

    private func elementDebugLabelOnNetworkQueue(for input: KeypadElementInputID) -> String {
        guard let element = realtimeGamepadCustomization.element(for: input.elementID) else { return input.storageKey }
        return input.part == .primary ? element.label : "\(element.label) \(input.part.displayName)"
    }

    private func recordElementPressBeganOnNetworkQueue(
        _ input: KeypadElementInputID,
        pressIdentifier: UInt64?
    ) -> Bool {
        let wasPressed = hasElementPressOnNetworkQueue(input)
        let now = DispatchTime.now().uptimeNanoseconds

        if let pressIdentifier {
            activePressLastSeenByElementInput[input, default: [:]][pressIdentifier] = now
            var identifiers = activePressIdentifiersByElementInput[input, default: []]
            let inserted = identifiers.insert(pressIdentifier).inserted
            activePressIdentifiersByElementInput[input] = identifiers
            return inserted && !wasPressed
        }

        anonymousPressLastSeenByElementInput[input] = now
        if (anonymousPressCountsByElementInput[input] ?? 0) > 0 { return false }
        anonymousPressCountsByElementInput[input] = 1
        return !wasPressed
    }

    private func recordElementPressEndedOnNetworkQueue(
        _ input: KeypadElementInputID,
        pressIdentifier: UInt64?
    ) -> PhysicalButtonReleaseResult {
        guard hasElementPressOnNetworkQueue(input) else { return .orphan }
        if let pressIdentifier {
            guard var identifiers = activePressIdentifiersByElementInput[input], identifiers.remove(pressIdentifier) != nil else { return .orphan }
            activePressIdentifiersByElementInput[input] = identifiers.isEmpty ? nil : identifiers
            removeElementLastSeenOnNetworkQueue(input, pressIdentifier: pressIdentifier)
        } else {
            guard let count = anonymousPressCountsByElementInput[input], count > 0 else { return .orphan }
            if count == 1 {
                anonymousPressCountsByElementInput[input] = nil
                anonymousPressLastSeenByElementInput[input] = nil
            } else {
                anonymousPressCountsByElementInput[input] = count - 1
            }
        }
        return hasElementPressOnNetworkQueue(input) ? .stillHeld : .shouldReleaseKey
    }

    private func hasElementPressOnNetworkQueue(_ input: KeypadElementInputID) -> Bool {
        activePressIdentifiersByElementInput[input]?.isEmpty == false
            || (anonymousPressCountsByElementInput[input] ?? 0) > 0
    }

    private func hasIdentifiedElementPressOnNetworkQueue(
        _ input: KeypadElementInputID,
        pressIdentifier: UInt64?
    ) -> Bool {
        guard let pressIdentifier else { return false }
        return activePressIdentifiersByElementInput[input]?.contains(pressIdentifier) == true
    }

    private func refreshElementPressSeenOnNetworkQueue(
        _ input: KeypadElementInputID,
        pressIdentifier: UInt64?
    ) {
        let now = DispatchTime.now().uptimeNanoseconds
        if let pressIdentifier,
           activePressIdentifiersByElementInput[input]?.contains(pressIdentifier) == true
        {
            activePressLastSeenByElementInput[input, default: [:]][pressIdentifier] = now
        } else if pressIdentifier == nil,
                  (anonymousPressCountsByElementInput[input] ?? 0) > 0
        {
            anonymousPressLastSeenByElementInput[input] = now
        }
    }

    private func resetElementHoldsOnNetworkQueue(
        for input: KeypadElementInputID,
        keeping pressIdentifier: UInt64?
    ) {
        let now = DispatchTime.now().uptimeNanoseconds
        if let pressIdentifier {
            activePressIdentifiersByElementInput[input] = [pressIdentifier]
            activePressLastSeenByElementInput[input] = [pressIdentifier: now]
            anonymousPressCountsByElementInput[input] = nil
            anonymousPressLastSeenByElementInput[input] = nil
        } else {
            activePressIdentifiersByElementInput[input] = nil
            activePressLastSeenByElementInput[input] = nil
            anonymousPressCountsByElementInput[input] = 1
            anonymousPressLastSeenByElementInput[input] = now
        }
    }

    private func removeElementLastSeenOnNetworkQueue(_ input: KeypadElementInputID, pressIdentifier: UInt64) {
        guard var lastSeenByIdentifier = activePressLastSeenByElementInput[input] else { return }
        lastSeenByIdentifier[pressIdentifier] = nil
        activePressLastSeenByElementInput[input] = lastSeenByIdentifier.isEmpty ? nil : lastSeenByIdentifier
    }

    private func handleButtonMessageOnNetworkQueue(_ message: ControllerMessage, source: String) {
        guard let button = message.button, let state = message.state else {
            publishControllerDebug(event: "Ignored malformed button event", immediately: true)
            return
        }

        if let sequenceNumber = ControllerWireCodec.buttonSequenceNumber(from: message),
           shouldTemporarilyBufferButtonMessage(sequenceNumber: sequenceNumber)
        {
            bufferButtonMessage(
                message,
                button: button,
                state: state,
                source: source,
                sequenceNumber: sequenceNumber
            )
            return
        }

        processButtonMessageOnNetworkQueue(message, button: button, state: state, source: source)
        drainPendingButtonMessagesOnNetworkQueue()
        cancelButtonReorderFlushIfIdle()
    }

    private func processButtonMessageOnNetworkQueue(
        _ message: ControllerMessage,
        button: GameButton,
        state: ButtonPressState,
        source: String
    ) {
        let sequenceInspection = inspectButtonSequence(message, button: button, state: state)
        handleRealtimeInputOnNetworkQueue(
            button,
            state: state,
            source: source,
            sequenceInspection: sequenceInspection,
            pressIdentifier: ControllerWireCodec.buttonPressIdentifier(from: message),
            messageTimestamp: captureLatencyTimestamp(for: message)
        )
    }

    private func shouldTemporarilyBufferButtonMessage(sequenceNumber: UInt64) -> Bool {
        guard let expectedSequence = buttonSequenceTracker.nextExpectedSequenceNumber else {
            return sequenceNumber > 1 && !buttonSequenceTracker.isAcceptingNextSequenceAsBaseline
        }

        return sequenceNumber > expectedSequence
    }

    private func bufferButtonMessage(
        _ message: ControllerMessage,
        button: GameButton,
        state: ButtonPressState,
        source: String,
        sequenceNumber: UInt64
    ) {
        if pendingButtonMessagesBySequence[sequenceNumber] == nil {
            pendingButtonMessagesBySequence[sequenceNumber] = PendingButtonMessage(
                message: message,
                button: button,
                elementInput: nil,
                state: state,
                source: source
            )
        }
        scheduleButtonReorderFlushIfNeeded()
    }

    private func bufferElementInputMessage(
        _ message: ControllerMessage,
        input: KeypadElementInputID,
        state: ButtonPressState,
        source: String,
        sequenceNumber: UInt64
    ) {
        if pendingButtonMessagesBySequence[sequenceNumber] == nil {
            pendingButtonMessagesBySequence[sequenceNumber] = PendingButtonMessage(
                message: message,
                button: nil,
                elementInput: input,
                state: state,
                source: source
            )
        }
        scheduleButtonReorderFlushIfNeeded()
    }

    private func scheduleButtonReorderFlushIfNeeded() {
        guard buttonReorderFlushWorkItem == nil else { return }

        buttonReorderFlushGeneration += 1
        let generation = buttonReorderFlushGeneration
        let workItem = DispatchWorkItem { [weak self] in
            self?.flushPendingButtonMessagesOnNetworkQueue(generation: generation)
        }
        buttonReorderFlushWorkItem = workItem
        networkQueue.asyncAfter(
            deadline: .now() + .nanoseconds(Int(Self.buttonReorderDelayNanoseconds)),
            execute: workItem
        )
    }

    private func flushPendingButtonMessagesOnNetworkQueue(generation: Int) {
        guard generation == buttonReorderFlushGeneration else { return }
        buttonReorderFlushWorkItem = nil
        drainPendingButtonMessagesOnNetworkQueue(flushOldestGap: true)
        if !pendingButtonMessagesBySequence.isEmpty {
            scheduleButtonReorderFlushIfNeeded()
        }
    }

    private func processPendingButtonMessageOnNetworkQueue(_ pending: PendingButtonMessage) {
        if let button = pending.button {
            processButtonMessageOnNetworkQueue(
                pending.message,
                button: button,
                state: pending.state,
                source: pending.source
            )
        } else if let input = pending.elementInput {
            processElementInputMessageOnNetworkQueue(
                pending.message,
                input: input,
                state: pending.state,
                source: pending.source
            )
        }
    }

    private func drainPendingButtonMessagesOnNetworkQueue(flushOldestGap: Bool = false) {
        var didFlushGap = false

        while true {
            if let expectedSequence = buttonSequenceTracker.nextExpectedSequenceNumber,
               let pending = pendingButtonMessagesBySequence.removeValue(forKey: expectedSequence)
            {
                processPendingButtonMessageOnNetworkQueue(pending)
                continue
            }

            guard flushOldestGap, !didFlushGap,
                  let nextSequence = pendingButtonMessagesBySequence.keys.min(),
                  let pending = pendingButtonMessagesBySequence.removeValue(forKey: nextSequence)
            else {
                return
            }

            didFlushGap = true
            processPendingButtonMessageOnNetworkQueue(pending)
        }
    }

    private func cancelButtonReorderFlushIfIdle() {
        guard pendingButtonMessagesBySequence.isEmpty,
              buttonReorderFlushWorkItem != nil
        else { return }

        buttonReorderFlushGeneration += 1
        buttonReorderFlushWorkItem?.cancel()
        buttonReorderFlushWorkItem = nil
    }

    private func resetPendingButtonMessagesOnNetworkQueue() {
        buttonReorderFlushGeneration += 1
        buttonReorderFlushWorkItem?.cancel()
        buttonReorderFlushWorkItem = nil
        pendingButtonMessagesBySequence.removeAll()
    }

    private enum PhysicalButtonReleaseResult {
        case shouldReleaseKey
        case stillHeld
        case orphan
    }

    private func handleRealtimeInputOnNetworkQueue(
        _ button: GameButton,
        state: ButtonPressState,
        source: String,
        sequenceInspection: ButtonSequenceInspection = ButtonSequenceInspection(),
        pressIdentifier: UInt64? = nil,
        messageTimestamp: Int64? = nil
    ) {
        if sequenceInspection.isOutOfOrderOrReset, sequenceInspection.hasSequence {
            return
        }

        switch state {
        case .down:
            if inputPressedButtons.contains(button),
               sequenceInspection.missedFrameBeforeButton
            {
                if hasIdentifiedPhysicalPressOnNetworkQueue(button, pressIdentifier: pressIdentifier)
                    || (pressIdentifier == nil && (anonymousPressCountsByButton[button] ?? 0) > 0)
                {
                    refreshPhysicalPressSeenOnNetworkQueue(button, pressIdentifier: pressIdentifier)
                    noteDuplicateButtonRefresh(button: button, pressIdentifier: pressIdentifier)
                    return
                }

                noteRecoveredButtonEdge(button: button, state: state, reason: "missing_release_before_down")
                resetPhysicalHoldsOnNetworkQueue(for: button, keeping: pressIdentifier)
                handleButtonOnNetworkQueue(button, state: .up, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp, detail: "missing_release_before_down")
                handleButtonOnNetworkQueue(button, state: .down, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp, detail: "missing_release_before_down")
                return
            }

            if recordPhysicalPressBeganOnNetworkQueue(button, pressIdentifier: pressIdentifier) {
                handleButtonOnNetworkQueue(button, state: .down, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp)
            }

        case .up:
            switch recordPhysicalPressEndedOnNetworkQueue(button, pressIdentifier: pressIdentifier) {
            case .shouldReleaseKey:
                handleButtonOnNetworkQueue(button, state: .up, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp)

            case .stillHeld:
                break

            case .orphan:
                if sequenceInspection.missedFrameBeforeButton,
                   !hasPhysicalPressOnNetworkQueue(button)
                {
                    noteRecoveredButtonEdge(button: button, state: state, reason: "missing_down_before_up")
                    handleButtonOnNetworkQueue(button, state: .down, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp, detail: "missing_down_before_up")
                    handleButtonOnNetworkQueue(button, state: .up, source: source, sequenceInspection: sequenceInspection, pressIdentifier: pressIdentifier, messageTimestamp: messageTimestamp, detail: "missing_down_before_up")
                } else {
                    noteIgnoredButtonEdge(button: button, state: state, reason: "orphan_up")
                }
            }
        }
    }

    private func handleButtonOnNetworkQueue(
        _ button: GameButton,
        state: ButtonPressState,
        source: String,
        sequenceInspection: ButtonSequenceInspection = ButtonSequenceInspection(),
        pressIdentifier: UInt64? = nil,
        messageTimestamp: Int64? = nil,
        detail: String? = nil
    ) {
        let baseOutput = realtimeOutputBindings[button] ?? realtimeKeyBindings[button].map { MacControlOutputBinding.keyboard($0) }
        guard let baseOutput, !baseOutput.isEmpty else { return }

        switch state {
        case .down:
            guard !inputPressedButtons.contains(button) else {
                noteIgnoredButtonEdge(button: button, state: state, reason: "duplicate_down")
                return
            }
            let effectiveOutput = baseOutput.withAdditionalModifiers(activeModifierKeysOnNetworkQueue())
            if let keyboard = effectiveOutput.keyboard {
                activeBindings[button] = keyboard
            }
            activeOutputBindings[button] = effectiveOutput
            activateOutput(effectiveOutput)
            inputPressedButtons.insert(button)
            publishInputDebugIfDue(source: source, button: button, state: state, binding: effectiveOutput)
            captureButtonEventOnNetworkQueue(
                source: source,
                button: button,
                state: state,
                binding: effectiveOutput,
                sequenceInspection: sequenceInspection,
                pressIdentifier: pressIdentifier,
                messageTimestamp: messageTimestamp,
                detail: detail
            )
            logInputEvent("button source=\(source) button=\(button.rawValue) state=down binding=\(effectiveOutput.displayName) pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")

        case .up:
            guard inputPressedButtons.contains(button) else {
                noteIgnoredButtonEdge(button: button, state: state, reason: "orphan_up")
                return
            }
            let releasedOutput = activeOutputBindings.removeValue(forKey: button) ?? baseOutput
            if releasedOutput.keyboard != nil {
                activeBindings.removeValue(forKey: button)
            }
            deactivateOutput(releasedOutput)
            inputPressedButtons.remove(button)
            publishInputDebugIfDue(source: source, button: button, state: state, binding: releasedOutput)
            captureButtonEventOnNetworkQueue(
                source: source,
                button: button,
                state: state,
                binding: releasedOutput,
                sequenceInspection: sequenceInspection,
                pressIdentifier: pressIdentifier,
                messageTimestamp: messageTimestamp,
                detail: detail
            )
            logInputEvent("button source=\(source) button=\(button.rawValue) state=up binding=\(releasedOutput.displayName) pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")
        }
    }

    private func resetButtonSequenceDiagnosticsOnNetworkQueue() {
        resetPendingButtonMessagesOnNetworkQueue()
        buttonSequenceTracker.reset()
        ignoredButtonEdgeCount = 0
        recoveredButtonEdgeCount = 0
    }

    private func resetPhysicalInputTrackingOnNetworkQueue() {
        activePressIdentifiersByButton.removeAll()
        activePressLastSeenByButton.removeAll()
        anonymousPressCountsByButton.removeAll()
        anonymousPressLastSeenByButton.removeAll()
        activePressIdentifiersByElementInput.removeAll()
        activePressLastSeenByElementInput.removeAll()
        anonymousPressCountsByElementInput.removeAll()
        anonymousPressLastSeenByElementInput.removeAll()
    }

    private func recordPhysicalPressBeganOnNetworkQueue(
        _ button: GameButton,
        pressIdentifier: UInt64?
    ) -> Bool {
        let wasPhysicallyPressed = hasPhysicalPressOnNetworkQueue(button)
        let now = DispatchTime.now().uptimeNanoseconds

        if let pressIdentifier {
            activePressLastSeenByButton[button, default: [:]][pressIdentifier] = now
            var identifiers = activePressIdentifiersByButton[button, default: []]
            let inserted = identifiers.insert(pressIdentifier).inserted
            activePressIdentifiersByButton[button] = identifiers
            return inserted && !wasPhysicallyPressed
        }

        anonymousPressLastSeenByButton[button] = now
        if (anonymousPressCountsByButton[button] ?? 0) > 0 {
            return false
        }

        // Without a touch identifier we cannot safely distinguish duplicate
        // heartbeat refreshes from multiple same-button touches. Treat anonymous
        // input as one physical hold so an old/no-ID client cannot build up a
        // count that requires several button-up packets to release.
        anonymousPressCountsByButton[button] = 1
        return !wasPhysicallyPressed
    }

    private func recordPhysicalPressEndedOnNetworkQueue(
        _ button: GameButton,
        pressIdentifier: UInt64?
    ) -> PhysicalButtonReleaseResult {
        guard hasPhysicalPressOnNetworkQueue(button) else { return .orphan }

        if let pressIdentifier {
            guard var identifiers = activePressIdentifiersByButton[button],
                  identifiers.remove(pressIdentifier) != nil
            else {
                return .orphan
            }

            activePressIdentifiersByButton[button] = identifiers.isEmpty ? nil : identifiers
            removeLastSeenOnNetworkQueue(button, pressIdentifier: pressIdentifier)
        } else {
            guard let count = anonymousPressCountsByButton[button],
                  count > 0
            else {
                return .orphan
            }

            if count == 1 {
                anonymousPressCountsByButton[button] = nil
                anonymousPressLastSeenByButton[button] = nil
            } else {
                anonymousPressCountsByButton[button] = count - 1
            }
        }

        return hasPhysicalPressOnNetworkQueue(button) ? .stillHeld : .shouldReleaseKey
    }

    private func hasPhysicalPressOnNetworkQueue(_ button: GameButton) -> Bool {
        activePressIdentifiersByButton[button]?.isEmpty == false
            || (anonymousPressCountsByButton[button] ?? 0) > 0
    }

    private func hasIdentifiedPhysicalPressOnNetworkQueue(
        _ button: GameButton,
        pressIdentifier: UInt64?
    ) -> Bool {
        guard let pressIdentifier else { return false }
        return activePressIdentifiersByButton[button]?.contains(pressIdentifier) == true
    }

    private func refreshPhysicalPressSeenOnNetworkQueue(
        _ button: GameButton,
        pressIdentifier: UInt64?
    ) {
        let now = DispatchTime.now().uptimeNanoseconds
        if let pressIdentifier,
           activePressIdentifiersByButton[button]?.contains(pressIdentifier) == true
        {
            activePressLastSeenByButton[button, default: [:]][pressIdentifier] = now
        } else if pressIdentifier == nil,
                  (anonymousPressCountsByButton[button] ?? 0) > 0
        {
            anonymousPressLastSeenByButton[button] = now
        }
    }

    private func resetPhysicalHoldsOnNetworkQueue(
        for button: GameButton,
        keeping pressIdentifier: UInt64?
    ) {
        let now = DispatchTime.now().uptimeNanoseconds
        if let pressIdentifier {
            activePressIdentifiersByButton[button] = [pressIdentifier]
            activePressLastSeenByButton[button] = [pressIdentifier: now]
            anonymousPressCountsByButton[button] = nil
            anonymousPressLastSeenByButton[button] = nil
        } else {
            activePressIdentifiersByButton[button] = nil
            activePressLastSeenByButton[button] = nil
            anonymousPressCountsByButton[button] = 1
            anonymousPressLastSeenByButton[button] = now
        }
    }

    private func clearPhysicalHoldsOnNetworkQueue(for button: GameButton) {
        activePressIdentifiersByButton[button] = nil
        activePressLastSeenByButton[button] = nil
        anonymousPressCountsByButton[button] = nil
        anonymousPressLastSeenByButton[button] = nil
    }

    private func clearPhysicalHoldsOnNetworkQueue(for input: KeypadElementInputID) {
        activePressIdentifiersByElementInput[input] = nil
        activePressLastSeenByElementInput[input] = nil
        anonymousPressCountsByElementInput[input] = nil
        anonymousPressLastSeenByElementInput[input] = nil
    }

    private func removeLastSeenOnNetworkQueue(_ button: GameButton, pressIdentifier: UInt64) {
        guard var lastSeenByIdentifier = activePressLastSeenByButton[button] else { return }
        lastSeenByIdentifier[pressIdentifier] = nil
        activePressLastSeenByButton[button] = lastSeenByIdentifier.isEmpty ? nil : lastSeenByIdentifier
    }

    private func expireStalePhysicalHoldsOnNetworkQueue() {
        guard pairedConnection != nil else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        var buttonsNeedingRelease: [GameButton] = []
        var elementInputsNeedingRelease: [KeypadElementInputID] = []

        for button in GameButton.allCases {
            var didExpireHold = false

            if var identifiers = activePressIdentifiersByButton[button],
               let lastSeenByIdentifier = activePressLastSeenByButton[button]
            {
                let expiredIdentifiers = identifiers.filter { identifier in
                    guard let lastSeen = lastSeenByIdentifier[identifier], now >= lastSeen else { return false }
                    return now - lastSeen > Self.physicalHoldRefreshTimeoutNanoseconds
                }

                if !expiredIdentifiers.isEmpty {
                    didExpireHold = true
                    var nextLastSeenByIdentifier = lastSeenByIdentifier
                    for identifier in expiredIdentifiers {
                        identifiers.remove(identifier)
                        nextLastSeenByIdentifier[identifier] = nil
                    }

                    activePressIdentifiersByButton[button] = identifiers.isEmpty ? nil : identifiers
                    nextLastSeenByIdentifier = nextLastSeenByIdentifier.filter { identifiers.contains($0.key) }
                    activePressLastSeenByButton[button] = nextLastSeenByIdentifier.isEmpty ? nil : nextLastSeenByIdentifier
                }
            }

            if let lastSeen = anonymousPressLastSeenByButton[button],
               now >= lastSeen,
               now - lastSeen > Self.physicalHoldRefreshTimeoutNanoseconds,
               (anonymousPressCountsByButton[button] ?? 0) > 0
            {
                didExpireHold = true
                anonymousPressCountsByButton[button] = nil
                anonymousPressLastSeenByButton[button] = nil
            }

            if didExpireHold,
               !hasPhysicalPressOnNetworkQueue(button),
               inputPressedButtons.contains(button)
            {
                buttonsNeedingRelease.append(button)
            }
        }

        let trackedElementInputs = Set(activePressIdentifiersByElementInput.keys)
            .union(anonymousPressCountsByElementInput.keys)

        for input in trackedElementInputs {
            var didExpireHold = false

            if var identifiers = activePressIdentifiersByElementInput[input],
               let lastSeenByIdentifier = activePressLastSeenByElementInput[input]
            {
                let expiredIdentifiers = identifiers.filter { identifier in
                    guard let lastSeen = lastSeenByIdentifier[identifier], now >= lastSeen else { return false }
                    return now - lastSeen > Self.physicalHoldRefreshTimeoutNanoseconds
                }

                if !expiredIdentifiers.isEmpty {
                    didExpireHold = true
                    var nextLastSeenByIdentifier = lastSeenByIdentifier
                    for identifier in expiredIdentifiers {
                        identifiers.remove(identifier)
                        nextLastSeenByIdentifier[identifier] = nil
                    }

                    activePressIdentifiersByElementInput[input] = identifiers.isEmpty ? nil : identifiers
                    nextLastSeenByIdentifier = nextLastSeenByIdentifier.filter { identifiers.contains($0.key) }
                    activePressLastSeenByElementInput[input] = nextLastSeenByIdentifier.isEmpty ? nil : nextLastSeenByIdentifier
                }
            }

            if let lastSeen = anonymousPressLastSeenByElementInput[input],
               now >= lastSeen,
               now - lastSeen > Self.physicalHoldRefreshTimeoutNanoseconds,
               (anonymousPressCountsByElementInput[input] ?? 0) > 0
            {
                didExpireHold = true
                anonymousPressCountsByElementInput[input] = nil
                anonymousPressLastSeenByElementInput[input] = nil
            }

            if didExpireHold,
               !hasElementPressOnNetworkQueue(input),
               inputPressedElementInputs.contains(input)
            {
                elementInputsNeedingRelease.append(input)
            }
        }

        let sticksNeedingNeutral = activeAnalogStickLastSeenByStick.compactMap { stick, lastSeen -> VirtualGamepadStick? in
            guard now >= lastSeen,
                  now - lastSeen > Self.physicalHoldRefreshTimeoutNanoseconds
            else { return nil }
            return stick
        }
        let triggersNeedingNeutral = activeAnalogTriggerLastSeenByTrigger.compactMap { trigger, lastSeen -> VirtualGamepadTrigger? in
            guard now >= lastSeen,
                  now - lastSeen > Self.physicalHoldRefreshTimeoutNanoseconds
            else { return nil }
            return trigger
        }

        for button in buttonsNeedingRelease {
            noteRecoveredButtonEdge(button: button, state: .up, reason: "stale_hold_timeout")
            handleButtonOnNetworkQueue(button, state: .up, source: "Stale hold timeout")
        }

        for input in elementInputsNeedingRelease {
            logDebug("recovered_element_input_edge reason=stale_hold_timeout input=\(input.storageKey) state=up")
            handleElementInputEdgeOnNetworkQueue(input, state: .up, source: "Stale hold timeout")
        }

        for stick in sticksNeedingNeutral {
            activeAnalogStickLastSeenByStick[stick] = nil
            virtualGamepadInjector.setStick(stick, x: 0, y: 0)
            logDebug("recovered_gamepad_analog reason=stale_hold_timeout stick=\(stick.rawValue) x=0.000 y=0.000")
        }

        for trigger in triggersNeedingNeutral {
            activeAnalogTriggerLastSeenByTrigger[trigger] = nil
            virtualGamepadInjector.setTrigger(trigger, value: 0)
            logDebug("recovered_gamepad_analog reason=stale_hold_timeout trigger=\(trigger.rawValue) value=0.000")
        }
    }

    private func noteIgnoredButtonEdge(
        button: GameButton,
        state: ButtonPressState,
        reason: String
    ) {
        if ignoredButtonEdgeCount < Int.max {
            ignoredButtonEdgeCount += 1
        }

        let totalIgnoredButtonEdges = ignoredButtonEdgeCount
        let event = "Ignored \(button.rawValue) \(state.rawValue) (\(reason)); total ignored \(totalIgnoredButtonEdges)"
        publishIgnoredButtonEdge(totalIgnoredButtonEdges: totalIgnoredButtonEdges, event: event)
        appendCaptureEvent(PocketPadCaptureEvent(
            kind: "ignored_button_edge",
            button: button,
            state: state,
            pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
            pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
            activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue(),
            detail: reason
        ))
        logDebug("ignored_button_edge reason=\(reason) button=\(button.rawValue) state=\(state.rawValue) pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")
    }

    private func noteDuplicateButtonRefresh(
        button: GameButton,
        pressIdentifier: UInt64?
    ) {
        logDebug("button_refresh_after_gap button=\(button.rawValue) pressIdentifier=\(pressIdentifier.map(String.init) ?? "nil") pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")
    }

    private func noteRecoveredButtonEdge(
        button: GameButton,
        state: ButtonPressState,
        reason: String
    ) {
        if recoveredButtonEdgeCount < Int.max {
            recoveredButtonEdgeCount += 1
        }

        let totalRecoveredButtonEdges = recoveredButtonEdgeCount
        let event = "Recovered \(button.rawValue) \(state.rawValue) (\(reason)); total recovered \(totalRecoveredButtonEdges)"
        publishRecoveredButtonEdge(totalRecoveredButtonEdges: totalRecoveredButtonEdges, event: event)
        appendCaptureEvent(PocketPadCaptureEvent(
            kind: "recovered_button_edge",
            button: button,
            state: state,
            pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
            pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
            activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue(),
            detail: reason
        ))
        logDebug("recovered_button_edge reason=\(reason) button=\(button.rawValue) state=\(state.rawValue)")
    }

    private func releaseIfPressedOnNetworkQueue(_ button: GameButton) {
        clearPhysicalHoldsOnNetworkQueue(for: button)
        guard inputPressedButtons.contains(button) else { return }
        inputPressedButtons.remove(button)
        if let activeOutput = activeOutputBindings.removeValue(forKey: button) {
            deactivateOutput(activeOutput)
        } else if let activeBinding = activeBindings.removeValue(forKey: button) {
            deactivateBinding(activeBinding)
        }
        publishControllerDebug(pressedButtons: inputPressedButtons, immediately: true)
    }

    private func releaseElementInputIfPressedOnNetworkQueue(_ input: KeypadElementInputID) {
        clearPhysicalHoldsOnNetworkQueue(for: input)
        guard inputPressedElementInputs.contains(input) else { return }
        inputPressedElementInputs.remove(input)
        if let activeOutput = activeElementOutputBindings.removeValue(forKey: input) {
            deactivateOutput(activeOutput)
        }
        publishControllerDebug(pressedButtons: inputPressedButtons, immediately: true)
    }

    private func activateOutput(_ output: MacControlOutputBinding) {
        if let binding = output.keyboard {
            activateBinding(binding)
        }
        for button in output.gamepadButtons {
            pressGamepadButton(button)
        }
    }

    private func deactivateOutput(_ output: MacControlOutputBinding) {
        if let binding = output.keyboard {
            deactivateBinding(binding)
        }
        for button in output.gamepadButtons {
            releaseGamepadButton(button)
        }
    }

    private func activateBinding(_ binding: MacKeyBinding) {
        if binding.isSequence {
            injector.tapSequence(binding)
        } else {
            pressBinding(binding)
        }
    }

    private func deactivateBinding(_ binding: MacKeyBinding) {
        guard !binding.isSequence else { return }
        releaseBinding(binding)
    }

    private func pressBinding(_ binding: MacKeyBinding) {
        let currentCount = heldBindingCounts[binding, default: 0]
        heldBindingCounts[binding] = currentCount + 1
        if currentCount == 0 {
            injector.keyDown(binding)
        }
    }

    private func activeModifierKeysOnNetworkQueue() -> MacKeyModifiers {
        heldBindingCounts.reduce(into: MacKeyModifiers()) { modifiers, entry in
            let (binding, count) = entry
            guard count > 0, let keyModifier = MacVirtualKey.keyModifier(for: binding.keyCode) else { return }
            modifiers.formUnion(keyModifier)
        }
    }

    private func releaseBinding(_ binding: MacKeyBinding) {
        let currentCount = heldBindingCounts[binding, default: 0]
        guard currentCount > 0 else {
            injector.keyUp(binding)
            return
        }

        if currentCount == 1 {
            heldBindingCounts[binding] = nil
            injector.keyUp(binding)
        } else {
            heldBindingCounts[binding] = currentCount - 1
        }
    }

    private func pressGamepadButton(_ button: VirtualGamepadButton) {
        let currentCount = heldGamepadButtonCounts[button, default: 0]
        heldGamepadButtonCounts[button] = currentCount + 1
        if currentCount == 0 {
            virtualGamepadInjector.setButton(button, pressed: true)
        }
    }

    private func releaseGamepadButton(_ button: VirtualGamepadButton) {
        let currentCount = heldGamepadButtonCounts[button, default: 0]
        guard currentCount > 0 else {
            virtualGamepadInjector.setButton(button, pressed: false)
            return
        }

        if currentCount == 1 {
            heldGamepadButtonCounts[button] = nil
            virtualGamepadInjector.setButton(button, pressed: false)
        } else {
            heldGamepadButtonCounts[button] = currentCount - 1
        }
    }

    private func send(_ message: ControllerMessage, on connection: NWConnection) {
        guard let data = try? ControllerWireCodec.encode(message, using: encoder) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "PocketPadMessage", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }

    private func gamepadCustomizationForClient(_ customization: GamepadCustomization) -> GamepadCustomization {
        // Realtime customizations are normalized on the main/editor side before being
        // copied to the Network framework queue. Avoid re-normalizing the full value
        // here: GCD network worker threads have small stacks, and the nested Swift
        // value-type normalization can exhaust them during client handshake.
        var clientCustomization = customization
        for button in GameButton.allCases where clientCustomization.labelOverride(for: button) == nil {
            if let output = realtimeOutputBindings[button], !output.isEmpty {
                clientCustomization.setLabel(output.displayName, for: button)
            } else if let binding = realtimeKeyBindings[button] {
                clientCustomization.setLabel(binding.displayName, for: button)
            }
        }
        return clientCustomization
    }

    private func gamepadProfilesForClient(_ profiles: [GamepadConfigurationProfile]) -> [GamepadConfigurationProfile] {
        profiles.map { profile in
            var clientProfile = profile
            clientProfile.customization = gamepadCustomizationForClient(profile.customization)
            clientProfile.landscapeCustomization = profile.landscapeCustomization.map(gamepadCustomizationForClient)
            clientProfile.portraitCustomization = profile.portraitCustomization.map(gamepadCustomizationForClient)
            clientProfile.launchTarget = profile.launchTarget?.normalized
            return clientProfile
        }
    }

    private func sendGamepadCustomizationOnNetworkQueue(_ customization: GamepadCustomization) {
        guard let pairedConnection else { return }
        send(
            .init(
                type: .gamepadCustomization,
                timestamp: 0,
                gamepadCustomization: gamepadCustomizationForClient(customization),
                gamepadProfiles: gamepadProfilesForClient(realtimeGamepadProfiles),
                gamepadProfileID: realtimeActiveGamepadProfileID,
                defaultGamepadProfileID: realtimeDefaultGamepadProfileID
            ),
            on: pairedConnection
        )
    }

    private func sendGamepadProfileStateOnNetworkQueue() {
        guard let pairedConnection else { return }
        send(
            .init(
                type: .gamepadProfiles,
                timestamp: 0,
                gamepadCustomization: gamepadCustomizationForClient(realtimeGamepadCustomization),
                gamepadProfiles: gamepadProfilesForClient(realtimeGamepadProfiles),
                gamepadProfileID: realtimeActiveGamepadProfileID,
                defaultGamepadProfileID: realtimeDefaultGamepadProfileID
            ),
            on: pairedConnection
        )
    }

    private func publishBonjourService(on port: UInt16) {
        stopBonjourService()

        let serviceName = bonjourServiceName
        let service = NetService(
            domain: "local.",
            type: Self.bonjourServiceType,
            name: serviceName,
            port: Int32(port)
        )
        service.includesPeerToPeer = true
        let txtRecord: [String: Data] = [
            "id": Data(serverID.utf8),
            "name": Data(serviceName.utf8)
        ]
        service.setTXTRecord(NetService.data(fromTXTRecord: txtRecord))
        service.publish()
        bonjourService = service
        logDebug("bonjour_published name=\(serviceName) type=\(Self.bonjourServiceType) port=\(port) server=\(serverID)")
    }

    private func stopBonjourService() {
        bonjourService?.stop()
        bonjourService = nil
    }

    private func handleListenerState(
        _ state: NWListener.State,
        listener stateListener: NWListener,
        fallbackIfBusy: Bool,
        usingFallbackPort: Bool
    ) {
        guard listener === stateListener else {
            logDebug("ignored_stale_listener_state state=\(state)")
            return
        }

        switch state {
        case .ready:
            if let assignedPort = stateListener.port?.rawValue, assignedPort != 0 {
                port = assignedPort
            }
            let resolvedPort = port
            asyncOnNetworkQueue { [weak self] in
                self?.startDatagramListenerOnNetworkQueue(on: resolvedPort)
            }
            localURLs = Self.localIPv4Addresses().map { "ws://\($0):\(port)" }
            publishBonjourService(on: port)
            if usingFallbackPort {
                statusText = "Listening on port \(port) (\(Self.preferredPort) was unavailable)"
            } else {
                statusText = "Listening on port \(port)"
            }
            logDebug("listener ready port=\(port) urls=\(localURLs)")
            publishRuntimeStatus()
        case .failed(let error):
            if fallbackIfBusy, isPreferredPortUnavailable(error) {
                statusText = "Port \(Self.preferredPort) is unavailable; trying an available port…"
                logDebug("preferred_port_unavailable port=\(Self.preferredPort) error=\(error.localizedDescription) retry=auto")
                publishRuntimeStatus()
                stateListener.cancel()
                if listener === stateListener {
                    listener = nil
                }
                startListening(on: nil, fallbackIfBusy: false)
                return
            }

            let failureText = "Listener failed: \(error.localizedDescription)"
            logDebug("listener failed error=\(error.localizedDescription)")
            stop(finalStatusText: failureText, releaseReason: "Listener failed")
        case .cancelled:
            if !isRunning {
                statusText = "Stopped"
                publishRuntimeStatus()
            }
        default:
            break
        }
    }

    private func isPreferredPortUnavailable(_ error: Error) -> Bool {
        if let nwError = error as? NWError {
            return isPreferredPortUnavailable(nwError)
        }
        return error.localizedDescription.localizedCaseInsensitiveContains("address already in use")
    }

    private func isPreferredPortUnavailable(_ error: NWError) -> Bool {
        if case .posix(let code) = error {
            return code == .EADDRINUSE || code == .EINVAL
        }
        return error.localizedDescription.localizedCaseInsensitiveContains("address already in use")
    }

    private func handleConnectionState(_ state: NWConnection.State, connection stateConnection: NWConnection) {
        guard connection === stateConnection else { return }

        switch state {
        case .ready:
            if isClientConnected {
                statusText = "Client connected"
            } else if isPairingPending {
                statusText = "Waiting for \(pendingPairingClientName ?? "iPhone") to enter pairing code"
            } else {
                statusText = "Waiting for pairing request"
            }
            receiveNext(on: stateConnection)
        case .failed(let error):
            statusText = "Connection failed: \(error.localizedDescription)"
            disconnectClient(reason: "Connection failed")
        case .cancelled:
            disconnectClient(reason: "Client disconnected")
        default:
            break
        }
    }

    private func handleReceiveError(_ error: NWError, connection errorConnection: NWConnection) {
        guard connection === errorConnection else { return }
        statusText = "Receive error: \(error.localizedDescription)"
        disconnectClient(reason: "Receive error")
    }

    private func disconnectClient(reason: String) {
        let disconnectedConnection = connection
        releaseAll(reason: reason)
        syncOnNetworkQueue {
            if realtimeConnection === disconnectedConnection {
                realtimeConnection = nil
            }
            if pairedConnection === disconnectedConnection {
                pairedConnection = nil
                realtimeToken = nil
                resetRealtimeDatagramAuthenticationOnNetworkQueue(cancelConnections: true)
            }
            if pendingPairingConnection === disconnectedConnection {
                pendingPairingConnection = nil
            }
            disconnectedConnection?.cancel()
        }
        connection = nil
        heartbeatTimedOut = false
        isClientConnected = false
        isPairingPending = false
        pendingPairingClientName = nil
        clientName = "No client"
        clientDeviceInfo = nil
        lastHeartbeat = nil
        if reason == "Client disconnected" {
            statusText = isRunning ? "Listening on port \(port)" : "Stopped"
        }
        logDebug("client disconnected reason=\(reason)")
    }

    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.checkHeartbeatTimeout()
            self.checkStalePhysicalHoldTimeouts()
            if Date().timeIntervalSince(self.lastAccessibilityRefresh) > 2 {
                self.refreshAccessibilityStatus()
            }
        }
        heartbeatTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func beginBackgroundActivity() {
        guard backgroundActivity == nil else { return }
        backgroundActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "PocketPad is forwarding keypad input to the Mac"
        )
    }

    private func endBackgroundActivity() {
        guard let backgroundActivity else { return }
        ProcessInfo.processInfo.endActivity(backgroundActivity)
        self.backgroundActivity = nil
    }

    private func checkHeartbeatTimeout() {
        guard isClientConnected, let lastHeartbeat else { return }
        if Date().timeIntervalSince(lastHeartbeat) > 1.5, !heartbeatTimedOut {
            heartbeatTimedOut = true
            releaseAll(reason: "Heartbeat timeout - released all keys")
            statusText = "Waiting for iPhone heartbeat"
            logDebug("heartbeat_timeout released_keys connection_kept")
        }
    }

    private func checkStalePhysicalHoldTimeouts() {
        asyncOnNetworkQueue { [weak self] in
            self?.expireStalePhysicalHoldsOnNetworkQueue()
        }
    }

    private func noteClientActivity() {
        if heartbeatTimedOut {
            heartbeatTimedOut = false
            statusText = "Client connected"
            logDebug("heartbeat_resumed")
        }
    }

    private func publishClientActivity(from activityConnection: NWConnection, force: Bool = false) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard force || now - lastClientActivityPublishUptime >= Self.clientActivityPublishIntervalNanoseconds else { return }
        lastClientActivityPublishUptime = now
        let activityDate = Date()

        DispatchQueue.main.async { [weak self, weak activityConnection] in
            guard let self,
                  let activityConnection,
                  self.connection === activityConnection
            else { return }

            self.lastHeartbeat = activityDate
            self.noteClientActivity()
        }
    }

    private func publishInputDebugIfDue(
        source: String,
        button: GameButton,
        state: ButtonPressState,
        binding: MacControlOutputBinding
    ) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard inputPressedButtons.isEmpty || now - lastInputDebugPublishUptime >= Self.inputDebugPublishIntervalNanoseconds else { return }
        lastInputDebugPublishUptime = now

        let event = "\(source): \(button.rawValue) \(state.rawValue) (\(binding.displayName))"
        publishControllerDebug(event: event, pressedButtons: inputPressedButtons)
    }

    private func publishHello(
        _ incomingClientName: String?,
        clientDeviceInfo: ControllerClientDeviceInfo?,
        from helloConnection: NWConnection
    ) {
        DispatchQueue.main.async { [weak self, weak helloConnection] in
            guard let self,
                  let helloConnection,
                  self.connection === helloConnection
            else { return }

            let resolvedClientName = incomingClientName ?? "Connected iPhone"
            self.clientName = resolvedClientName
            self.clientDeviceInfo = clientDeviceInfo
            self.isClientConnected = true
            self.lastHeartbeat = Date()
            if let clientDeviceInfo,
               let suggestedFrame = GamepadEditorDeviceCatalog.suggestedFrame(for: clientDeviceInfo) {
                self.lastReceivedEvent = "Hello from \(resolvedClientName) (\(suggestedFrame.spec.displayName))"
            } else {
                self.lastReceivedEvent = "Hello from \(resolvedClientName)"
            }
        }
    }

    private func publishEstimatedLatency(_ latency: Int, from latencyConnection: NWConnection) {
        DispatchQueue.main.async { [weak self, weak latencyConnection] in
            guard let self,
                  let latencyConnection,
                  self.connection === latencyConnection
            else { return }

            self.estimatedLatencyMS = latency
        }
    }

    private func publishButtonSequenceGap(
        expectedSequence: UInt64,
        receivedSequence: UInt64,
        missedFrameCount: UInt64,
        totalMissedButtonFrames: Int,
        button: GameButton,
        state: ButtonPressState
    ) {
        let event = "Missing \(missedFrameCount) input frame(s); expected #\(expectedSequence), got #\(receivedSequence) before \(button.rawValue) \(state.rawValue)"

        DispatchQueue.main.async { [weak self] in
            self?.missedButtonFrames = totalMissedButtonFrames
            self?.publishControllerDebugOnMain(event: event, immediately: true)
        }
    }

    private func publishIgnoredButtonEdge(totalIgnoredButtonEdges: Int, event: String) {
        DispatchQueue.main.async { [weak self] in
            self?.ignoredButtonEdges = totalIgnoredButtonEdges
            self?.publishControllerDebugOnMain(event: event, immediately: true)
        }
    }

    private func publishRecoveredButtonEdge(totalRecoveredButtonEdges: Int, event: String) {
        DispatchQueue.main.async { [weak self] in
            self?.recoveredButtonEdges = totalRecoveredButtonEdges
            self?.publishControllerDebugOnMain(event: event, immediately: true)
        }
    }

    private func publishControllerDebug(
        event: String? = nil,
        pressedButtons: Set<GameButton>? = nil,
        immediately: Bool = false
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.publishControllerDebugOnMain(
                event: event,
                pressedButtons: pressedButtons,
                immediately: immediately
            )
        }
    }

    private func publishControllerDebugOnMain(
        event: String? = nil,
        pressedButtons: Set<GameButton>? = nil,
        immediately: Bool = false
    ) {
        if let event {
            pendingLastReceivedEvent = event
        }
        if let pressedButtons {
            pendingPressedButtons = pressedButtons
        }

        if immediately {
            controllerDebugUpdateTask?.cancel()
            controllerDebugUpdateTask = nil
            flushControllerDebug()
            return
        }

        guard controllerDebugUpdateTask == nil else { return }
        controllerDebugUpdateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self, !Task.isCancelled else { return }
            self.flushControllerDebug()
        }
    }

    private func flushControllerDebug() {
        if let pendingPressedButtons {
            pressedButtons = pendingPressedButtons
            self.pendingPressedButtons = nil
        }
        if let pendingLastReceivedEvent {
            lastReceivedEvent = pendingLastReceivedEvent
            self.pendingLastReceivedEvent = nil
        }
        controllerDebugUpdateTask = nil
        publishRuntimeStatus()
    }

    private func refreshVirtualGamepadMaterialization(reason: String, publish: Bool = true) {
        let shouldMaterialize = Self.needsVirtualGamepadMaterialization(
            outputMode: activeGamepadOutputMode,
            outputBindings: outputBindings,
            customization: gamepadCustomization
        )

        if shouldMaterialize {
            let wasActive = virtualGamepadInjector.isActive
            if virtualGamepadInjector.start() {
                if !wasActive {
                    logDebug("virtual_gamepad_started reason=\(reason)")
                }
            } else {
                let error = virtualGamepadInjector.status().lastError ?? "unknown"
                logDebug("virtual_gamepad_start_failed reason=\(reason) error=\(error)")
            }
        } else if virtualGamepadInjector.isActive {
            virtualGamepadInjector.stop()
            logDebug("virtual_gamepad_stopped reason=\(reason)")
        }

        if publish {
            publishRuntimeStatus()
        }
    }

    private static func needsVirtualGamepadMaterialization(
        outputMode: GamepadProfileOutputMode,
        outputBindings: [GameButton: MacControlOutputBinding],
        customization: GamepadCustomization
    ) -> Bool {
        if outputMode != .keyboard,
           outputBindings.values.contains(where: { !$0.gamepadButtons.isEmpty }) {
            return true
        }

        let normalizedCustomization = customization.normalized
        if normalizedCustomization.elements.contains(where: { element in
            element.output?.gamepadButtons.isEmpty == false
                || element.partOutputs.values.contains { !$0.gamepadButtons.isEmpty }
        }) {
            return true
        }

        return normalizedCustomization.customButtons.contains { customButton in
            let normalizedButton = customButton.normalized
            if normalizedButton.isTrigger {
                return true
            }
            if normalizedButton.isJoystick {
                return (normalizedButton.joystickOutputSettings ?? .defaultValue).normalized.analogTarget.stick != nil
            }
            return false
        }
    }

    private func publishRuntimeStatus(synchronize: Bool = false) {
        if Thread.isMainThread {
            publishRuntimeStatusOnMain(synchronize: synchronize)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.publishRuntimeStatusOnMain(synchronize: synchronize)
            }
        }
    }

    private func publishRuntimeStatusOnMain(synchronize: Bool) {
        if synchronize {
            runtimeStatusPublishTask?.cancel()
            runtimeStatusPublishTask = nil
            writeRuntimeStatusSnapshotOnMain(synchronize: true)
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let elapsed = now - lastRuntimeStatusPublishUptime
        if elapsed >= Self.runtimeStatusPublishIntervalNanoseconds {
            runtimeStatusPublishTask?.cancel()
            runtimeStatusPublishTask = nil
            writeRuntimeStatusSnapshotOnMain(synchronize: false)
            return
        }

        guard runtimeStatusPublishTask == nil else { return }
        let delay = Self.runtimeStatusPublishIntervalNanoseconds - elapsed
        runtimeStatusPublishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, !Task.isCancelled else { return }
            self.writeRuntimeStatusSnapshotOnMain(synchronize: false)
        }
    }

    private func writeRuntimeStatusSnapshotOnMain(synchronize: Bool) {
        runtimeStatusPublishTask = nil
        let snapshot = runtimeStatusSnapshot()
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: PocketPadMacIPC.runtimeStatusDefaultsKey)
        lastRuntimeStatusPublishUptime = DispatchTime.now().uptimeNanoseconds
        if synchronize {
            UserDefaults.standard.synchronize()
        }
    }

    private func runtimeStatusSnapshot() -> PocketPadMacRuntimeStatus {
        let virtualGamepadStatus = virtualGamepadInjector.status()
        return PocketPadMacRuntimeStatus(
            updatedAt: Date.currentMilliseconds,
            statusText: statusText,
            isRunning: isRunning,
            isClientConnected: isClientConnected,
            localURLs: localURLs,
            bonjourServiceName: bonjourServiceName,
            bonjourServiceType: Self.bonjourServiceEndpointType,
            bonjourServiceDomain: Self.bonjourServiceDomain,
            serverID: serverID,
            pairingCode: pairingCode,
            isPairingPending: isPairingPending,
            pendingPairingClientName: pendingPairingClientName,
            clientName: clientName,
            lastHeartbeatMilliseconds: lastHeartbeat.map { Int64($0.timeIntervalSince1970 * 1000) },
            lastReceivedEvent: lastReceivedEvent,
            estimatedLatencyMS: estimatedLatencyMS,
            pressedButtons: GameButton.allCases.filter { pressedButtons.contains($0) },
            missedButtonFrames: missedButtonFrames,
            ignoredButtonEdges: ignoredButtonEdges,
            recoveredButtonEdges: recoveredButtonEdges,
            accessibilityTrusted: accessibilityTrusted,
            port: port,
            activeGamepadProfileID: activeGamepadProfileID,
            defaultGamepadProfileID: defaultGamepadProfileID,
            clientDeviceInfo: clientDeviceInfo,
            virtualGamepadActive: virtualGamepadStatus.isActive,
            virtualGamepadAvailable: virtualGamepadStatus.isAvailable,
            virtualGamepadLastError: virtualGamepadStatus.lastError,
            virtualGamepadPressedButtons: virtualGamepadStatus.pressedButtons,
            virtualGamepadLeftStickX: virtualGamepadStatus.leftStickX,
            virtualGamepadLeftStickY: virtualGamepadStatus.leftStickY,
            virtualGamepadRightStickX: virtualGamepadStatus.rightStickX,
            virtualGamepadRightStickY: virtualGamepadStatus.rightStickY,
            virtualGamepadLeftTrigger: virtualGamepadStatus.leftTrigger,
            virtualGamepadRightTrigger: virtualGamepadStatus.rightTrigger,
            captureLogPath: captureLogURL.path
        )
    }

    private func syncOnNetworkQueue<T>(_ work: () -> T) -> T {
        if DispatchQueue.getSpecific(key: networkQueueKey) == true {
            return work()
        }
        return networkQueue.sync(execute: work)
    }

    private func asyncOnNetworkQueue(_ work: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: networkQueueKey) == true {
            work()
        } else {
            networkQueue.async(execute: work)
        }
    }

    private func capturePressedButtonsSnapshotOnNetworkQueue() -> [GameButton] {
        GameButton.allCases.filter { inputPressedButtons.contains($0) }
    }

    private func capturePressedElementInputsSnapshotOnNetworkQueue() -> [String] {
        inputPressedElementInputs.map(\.storageKey).sorted()
    }

    private func captureActivePointerButtonsSnapshotOnNetworkQueue() -> [ControllerPointerButton] {
        activePointerButtons.sorted { $0.rawValue < $1.rawValue }
    }

    private func appendCaptureEvent(_ event: PocketPadCaptureEvent) {
        var stampedEvent = event
        stampedEvent.recordedAt = Date.currentMilliseconds
        stampedEvent.uptimeNanoseconds = DispatchTime.now().uptimeNanoseconds
        let capturedEvent = stampedEvent
        let captureLogURL = captureLogURL

        captureLogQueue.async { [weak self] in
            guard let self else { return }
            if self.captureLogSequence == UInt64.max {
                self.captureLogSequence = 0
            }
            self.captureLogSequence += 1

            var event = capturedEvent
            event.sequence = self.captureLogSequence
            guard var data = try? JSONEncoder().encode(event) else { return }
            data.append(0x0A)

            if !FileManager.default.fileExists(atPath: captureLogURL.path) {
                FileManager.default.createFile(atPath: captureLogURL.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: captureLogURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        }
    }

    private func captureButtonEventOnNetworkQueue(
        source: String,
        button: GameButton,
        state: ButtonPressState,
        binding: MacControlOutputBinding? = nil,
        sequenceInspection: ButtonSequenceInspection = ButtonSequenceInspection(),
        pressIdentifier: UInt64? = nil,
        messageTimestamp: Int64? = nil,
        detail: String? = nil
    ) {
        appendCaptureEvent(PocketPadCaptureEvent(
            kind: "button",
            source: source,
            messageType: .button,
            button: button,
            state: state,
            binding: binding?.displayName,
            inputSequence: sequenceInspection.receivedSequence,
            expectedSequence: sequenceInspection.expectedSequence,
            receivedSequence: sequenceInspection.receivedSequence,
            missedFrameCount: sequenceInspection.missedFrameCount > 0 ? sequenceInspection.missedFrameCount : nil,
            totalMissedButtonFrames: sequenceInspection.totalMissedFrameCount > 0 ? sequenceInspection.totalMissedFrameCount : nil,
            pressIdentifier: pressIdentifier,
            latencyMS: messageTimestamp.flatMap(oneWayLatencyMilliseconds(from:)),
            pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
            pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
            activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue(),
            detail: detail
        ))
    }

    private func captureElementInputEventOnNetworkQueue(
        source: String,
        input: KeypadElementInputID,
        label: String,
        state: ButtonPressState,
        binding: MacControlOutputBinding? = nil,
        sequenceInspection: ButtonSequenceInspection = ButtonSequenceInspection(),
        pressIdentifier: UInt64? = nil,
        messageTimestamp: Int64? = nil,
        detail: String? = nil
    ) {
        appendCaptureEvent(PocketPadCaptureEvent(
            kind: "element_input",
            source: source,
            messageType: .elementInput,
            elementInput: input,
            elementLabel: label,
            state: state,
            binding: binding?.displayName,
            inputSequence: sequenceInspection.receivedSequence,
            expectedSequence: sequenceInspection.expectedSequence,
            receivedSequence: sequenceInspection.receivedSequence,
            missedFrameCount: sequenceInspection.missedFrameCount > 0 ? sequenceInspection.missedFrameCount : nil,
            totalMissedButtonFrames: sequenceInspection.totalMissedFrameCount > 0 ? sequenceInspection.totalMissedFrameCount : nil,
            pressIdentifier: pressIdentifier,
            latencyMS: messageTimestamp.flatMap(oneWayLatencyMilliseconds(from:)),
            pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
            pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
            activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue(),
            detail: detail
        ))
    }

    private func captureSystemEventOnNetworkQueue(kind: String, source: String? = nil, detail: String? = nil) {
        appendCaptureEvent(PocketPadCaptureEvent(
            kind: kind,
            source: source,
            pressedButtons: capturePressedButtonsSnapshotOnNetworkQueue(),
            pressedElementInputs: capturePressedElementInputsSnapshotOnNetworkQueue(),
            activePointerButtons: captureActivePointerButtonsSnapshotOnNetworkQueue(),
            statusText: statusText,
            clientName: clientName,
            isClientConnected: isClientConnected,
            detail: detail
        ))
    }

    private func logInputEvent(_ line: @autoclosure @escaping () -> String) {
        guard Self.inputEventLoggingEnabled else { return }
        logDebug(line())
    }

    private func logDebug(_ line: String) {
        let debugLogURL = debugLogURL
        logQueue.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let entry = "[\(timestamp)] \(line)\n"
            if !FileManager.default.fileExists(atPath: debugLogURL.path) {
                FileManager.default.createFile(atPath: debugLogURL.path, contents: nil)
            }
            if let handle = try? FileHandle(forWritingTo: debugLogURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(entry.utf8))
            }
        }
    }

    private func captureLatencyTimestamp(for message: ControllerMessage) -> Int64 {
        message.sentAt ?? message.timestamp
    }

    private func oneWayLatencyMilliseconds(from timestamp: Int64) -> Int? {
        let delta = Date.currentMilliseconds - timestamp
        guard delta >= 0, delta < 10_000 else { return nil }
        return Int(delta)
    }

    private func roundTripLatencyMilliseconds(from timestamp: Int64) -> Int? {
        let delta = Date.currentMilliseconds - timestamp
        guard delta >= 0, delta < 10_000 else { return nil }
        return Int(delta)
    }

    private func saveTrustedClients() {
        guard let data = try? JSONEncoder().encode(Array(trustedClients.values)) else { return }
        UserDefaults.standard.set(data, forKey: Self.trustedClientsDefaultsKey)
    }

    private func saveKeyBindings() {
        let stored = Dictionary(uniqueKeysWithValues: keyBindings.map { button, binding in
            (button.rawValue, binding)
        })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.keyBindingsDefaultsKey)
    }

    private func saveProfileKeyBindings() {
        let stored = Dictionary(uniqueKeysWithValues: profileKeyBindings.map { profileID, bindings in
            (
                profileID.uuidString,
                Dictionary(uniqueKeysWithValues: bindings.map { button, binding in
                    (button.rawValue, binding)
                })
            )
        })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.profileKeyBindingsDefaultsKey)
    }

    private func saveOutputBindings() {
        let stored = Self.rawOutputBindings(outputBindings)
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.outputBindingsDefaultsKey)
    }

    private func saveProfileOutputBindings() {
        let stored = Dictionary(uniqueKeysWithValues: profileOutputBindings.map { profileID, bindings in
            (profileID.uuidString, Self.rawOutputBindings(bindings))
        })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.profileOutputBindingsDefaultsKey)
    }

    private static func rawOutputBindings(_ bindings: [GameButton: MacControlOutputBinding]) -> [String: MacControlOutputBinding] {
        Dictionary(uniqueKeysWithValues: bindings.map { button, binding in
            (button.rawValue, binding)
        })
    }

    private static func decodedOutputBindings(_ raw: [String: MacControlOutputBinding]?, fallback: [GameButton: MacControlOutputBinding] = [:]) -> [GameButton: MacControlOutputBinding] {
        var bindings = fallback
        guard let raw else { return bindings }
        for (rawButton, binding) in raw {
            guard let button = GameButton(rawValue: rawButton) else { continue }
            bindings[button] = binding.isEmpty ? nil : binding
        }
        return bindings
    }

    private static func outputBindings(from keyBindings: [GameButton: MacKeyBinding]) -> [GameButton: MacControlOutputBinding] {
        Dictionary(uniqueKeysWithValues: keyBindings.map { button, binding in
            (button, MacControlOutputBinding.keyboard(binding))
        })
    }

    private static func effectiveOutputBindings(
        for mode: GamepadProfileOutputMode,
        keyBindings: [GameButton: MacKeyBinding],
        customOutputBindings: [GameButton: MacControlOutputBinding]
    ) -> [GameButton: MacControlOutputBinding] {
        switch mode {
        case .keyboard:
            return outputBindings(from: keyBindings)
        case .controller:
            return DefaultMacControlOutputMap.xboxStyleBindings
        case .custom:
            return customOutputBindings.isEmpty ? outputBindings(from: keyBindings) : customOutputBindings
        }
    }

    private static func notificationData(from userInfo: [AnyHashable: Any]?, key: String) -> Data? {
        let value = userInfo?[key]
        if let data = value as? Data { return data }
        if let data = value as? NSData { return data as Data }
        return nil
    }

    private static func notificationKeyBindings(from data: Data?, fallback: [GameButton: MacKeyBinding]) -> [GameButton: MacKeyBinding] {
        guard let data,
              let stored = try? JSONDecoder().decode([String: MacKeyBinding].self, from: data)
        else {
            return fallback
        }

        var bindings = fallback
        for (rawButton, binding) in stored {
            guard let button = GameButton(rawValue: rawButton) else { continue }
            bindings[button] = binding
        }
        return bindings
    }

    private static func notificationProfileKeyBindings(from data: Data?) -> [UUID: [GameButton: MacKeyBinding]]? {
        guard let data,
              let stored = try? JSONDecoder().decode([String: [String: MacKeyBinding]].self, from: data)
        else {
            return nil
        }

        var profiles: [UUID: [GameButton: MacKeyBinding]] = [:]
        for (rawProfileID, rawBindings) in stored {
            guard let profileID = UUID(uuidString: rawProfileID) else { continue }
            var bindings: [GameButton: MacKeyBinding] = [:]
            for (rawButton, binding) in rawBindings {
                guard let button = GameButton(rawValue: rawButton) else { continue }
                bindings[button] = binding
            }
            profiles[profileID] = bindings
        }
        return profiles
    }

    private static func notificationOutputBindings(from data: Data?, fallback: [GameButton: MacControlOutputBinding]) -> [GameButton: MacControlOutputBinding] {
        guard let data,
              let stored = try? JSONDecoder().decode([String: MacControlOutputBinding].self, from: data)
        else {
            return fallback
        }
        return decodedOutputBindings(stored, fallback: fallback)
    }

    private static func notificationProfileOutputBindings(
        from data: Data?,
        fallbackProfileKeyBindings: [UUID: [GameButton: MacKeyBinding]]
    ) -> [UUID: [GameButton: MacControlOutputBinding]]? {
        guard let data,
              let stored = try? JSONDecoder().decode([String: [String: MacControlOutputBinding]].self, from: data)
        else {
            return nil
        }

        var profiles: [UUID: [GameButton: MacControlOutputBinding]] = Dictionary(
            uniqueKeysWithValues: fallbackProfileKeyBindings.map { profileID, bindings in
                (profileID, outputBindings(from: bindings))
            }
        )
        for (rawProfileID, rawBindings) in stored {
            guard let profileID = UUID(uuidString: rawProfileID) else { continue }
            profiles[profileID] = decodedOutputBindings(rawBindings, fallback: profiles[profileID] ?? [:])
        }
        return profiles
    }

    private static func loadProfileKeyBindings() -> [UUID: [GameButton: MacKeyBinding]] {
        guard let data = UserDefaults.standard.data(forKey: profileKeyBindingsDefaultsKey),
              let stored = try? JSONDecoder().decode([String: [String: MacKeyBinding]].self, from: data)
        else {
            return [:]
        }

        var profiles: [UUID: [GameButton: MacKeyBinding]] = [:]
        for (rawProfileID, rawBindings) in stored {
            guard let profileID = UUID(uuidString: rawProfileID) else { continue }
            var bindings: [GameButton: MacKeyBinding] = [:]
            for (rawButton, binding) in rawBindings {
                guard let button = GameButton(rawValue: rawButton) else { continue }
                bindings[button] = binding
            }
            profiles[profileID] = bindings
        }
        return profiles
    }

    private static func loadProfileOutputBindings(
        fallbackProfileKeyBindings: [UUID: [GameButton: MacKeyBinding]]
    ) -> [UUID: [GameButton: MacControlOutputBinding]] {
        var profiles = Dictionary(
            uniqueKeysWithValues: fallbackProfileKeyBindings.map { profileID, bindings in
                (profileID, outputBindings(from: bindings))
            }
        )

        guard let data = UserDefaults.standard.data(forKey: profileOutputBindingsDefaultsKey),
              let stored = try? JSONDecoder().decode([String: [String: MacControlOutputBinding]].self, from: data)
        else {
            return profiles
        }

        for (rawProfileID, rawBindings) in stored {
            guard let profileID = UUID(uuidString: rawProfileID) else { continue }
            profiles[profileID] = decodedOutputBindings(rawBindings, fallback: profiles[profileID] ?? [:])
        }
        return profiles
    }

    private static func resolvedKeyBindings(
        for profileID: UUID,
        in profileKeyBindings: [UUID: [GameButton: MacKeyBinding]],
        fallback: [GameButton: MacKeyBinding]
    ) -> [GameButton: MacKeyBinding] {
        var bindings = fallback
        if let storedBindings = profileKeyBindings[profileID] {
            for (button, binding) in storedBindings {
                bindings[button] = binding
            }
        }
        return bindings
    }

    private static func resolvedOutputBindings(
        for profileID: UUID,
        in profileOutputBindings: [UUID: [GameButton: MacControlOutputBinding]],
        fallback: [GameButton: MacControlOutputBinding]
    ) -> [GameButton: MacControlOutputBinding] {
        var bindings = fallback
        if let storedBindings = profileOutputBindings[profileID] {
            for (button, binding) in storedBindings {
                bindings[button] = binding.isEmpty ? nil : binding
            }
        }
        return bindings
    }

    private static func loadKeyBindings() -> [GameButton: MacKeyBinding] {
        var bindings = DefaultKeypadKeyMap.defaultBindings

        if let data = UserDefaults.standard.data(forKey: keyBindingsDefaultsKey),
           let stored = try? JSONDecoder().decode([String: MacKeyBinding].self, from: data) {
            for (rawButton, binding) in stored {
                guard let button = GameButton(rawValue: rawButton) else { continue }
                bindings[button] = binding
            }
            return bindings
        }

        return loadLegacyKeyBindings(fallback: bindings)
    }

    private static func loadLegacyKeyBindings(fallback: [GameButton: MacKeyBinding]) -> [GameButton: MacKeyBinding] {
        var bindings = fallback
        guard let stored = UserDefaults.standard.dictionary(forKey: legacyKeyBindingsDefaultsKey) else {
            return bindings
        }

        for (rawButton, rawKeyCode) in stored {
            guard let button = GameButton(rawValue: rawButton) else { continue }

            let keyCode: Int?
            if let intValue = rawKeyCode as? Int {
                keyCode = intValue
            } else if let numberValue = rawKeyCode as? NSNumber {
                keyCode = numberValue.intValue
            } else {
                keyCode = nil
            }

            guard let keyCode, keyCode >= 0, keyCode <= Int(UInt16.max) else { continue }
            bindings[button] = MacKeyBinding(keyCode: CGKeyCode(keyCode))
        }

        return bindings
    }

    private static func loadOrCreateServerID() -> String {
        if let stored = UserDefaults.standard.string(forKey: serverIdentityDefaultsKey),
           !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return stored
        }

        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: serverIdentityDefaultsKey)
        return generated
    }

    private static func loadTrustedClients() -> [String: TrustedClient] {
        guard let data = UserDefaults.standard.data(forKey: trustedClientsDefaultsKey),
              let clients = try? JSONDecoder().decode([TrustedClient].self, from: data)
        else {
            return [:]
        }

        return Dictionary(uniqueKeysWithValues: clients.map { ($0.token, $0) })
    }

    private static func defaultBonjourServiceName() -> String {
        let hostName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        let trimmedHostName = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedHostName.isEmpty ? "PocketPad Mac" : "PocketPad on \(trimmedHostName)"
    }

    private static func generatePairingCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    private static func generateAuthToken() -> String {
        "\(UUID().uuidString)-\(UUID().uuidString)"
    }

    private static func generateRealtimeToken() -> String {
        UUID().uuidString
    }

    private static func localIPv4Addresses() -> [String] {
        var addresses: [String] = []
        var interfaces: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return ["127.0.0.1"]
        }
        defer { freeifaddrs(interfaces) }

        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(interface.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
            guard isUp, !isLoopback else { continue }

            let addr = interface.pointee.ifa_addr.pointee
            guard addr.sa_family == UInt8(AF_INET) else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            var addrCopy = addr
            let result = getnameinfo(
                &addrCopy,
                socklen_t(addr.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            if result == 0 {
                addresses.append(String(cString: hostname))
            }
        }

        return addresses.isEmpty ? ["127.0.0.1"] : addresses
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
