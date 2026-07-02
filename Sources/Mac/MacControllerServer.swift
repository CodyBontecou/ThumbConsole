import CoreGraphics
import Foundation
import Network
import SwiftUI

final class MacControllerServer: ObservableObject {
    @Published private(set) var statusText = "Stopped"
    @Published private(set) var isRunning = false
    @Published private(set) var isClientConnected = false
    @Published private(set) var localURLs: [String] = []
    @Published private(set) var pairingCode: String
    @Published private(set) var isPairingPending = false
    @Published private(set) var pendingPairingClientName: String?
    @Published private(set) var clientName: String = "No client"
    @Published private(set) var lastHeartbeat: Date?
    @Published private(set) var lastReceivedEvent: String = "None"
    @Published private(set) var estimatedLatencyMS: Int?
    @Published private(set) var pressedButtons: Set<GameButton> = []
    @Published private(set) var missedButtonFrames = 0
    @Published private(set) var ignoredButtonEdges = 0
    @Published private(set) var recoveredButtonEdges = 0
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var keyBindings: [GameButton: MacKeyBinding]
    @Published private(set) var gamepadCustomization: GamepadCustomization
    @Published private(set) var gamepadProfiles: [GamepadConfigurationProfile]
    @Published private(set) var activeGamepadProfileID: UUID
    @Published private(set) var defaultGamepadProfileID: UUID
    @Published private(set) var port: UInt16 = MacControllerServer.preferredPort

    var pairingPayload: String {
        let payload = PairingPayload(urls: localURLs, pairingCode: pairingCode)
        guard let data = try? JSONEncoder().encode(payload) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private let networkQueue = DispatchQueue(label: "PocketPad.NetworkServer", qos: .userInteractive)
    private let networkQueueKey = DispatchSpecificKey<Bool>()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let injector = KeyboardInjector()
    private let debugLogURL = URL(fileURLWithPath: "/tmp/pocketpad-mac-events.log")
    private let logQueue = DispatchQueue(label: "PocketPad.DebugLog", qos: .utility)
    private static let preferredPort: UInt16 = 8765
    private static let keyBindingsDefaultsKey = "PocketPadMac.keyBindings.v2"
    private static let legacyKeyBindingsDefaultsKey = "PocketPadMac.keyBindings.v1"
    private static let inputEventLoggingEnabled = false
    private static let inputDebugPublishIntervalNanoseconds: UInt64 = 100_000_000
    private static let clientActivityPublishIntervalNanoseconds: UInt64 = 100_000_000
    private static let buttonReorderDelayNanoseconds: UInt64 = 8_000_000
    private var listener: NWListener?
    private var datagramListener: NWListener?
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
    private var realtimeKeyBindings: [GameButton: MacKeyBinding]
    private var realtimeGamepadCustomization: GamepadCustomization
    private var realtimeGamepadProfiles: [GamepadConfigurationProfile]
    private var realtimeActiveGamepadProfileID: UUID
    private var realtimeDefaultGamepadProfileID: UUID
    private var pendingLastReceivedEvent: String?
    private var pendingPressedButtons: Set<GameButton>?
    private var controllerDebugUpdateTask: Task<Void, Never>?
    private var lastInputDebugPublishUptime: UInt64 = 0
    private var lastClientActivityPublishUptime: UInt64 = 0
    private var lastAccessibilityRefresh = Date.distantPast
    private var activeBindings: [GameButton: MacKeyBinding] = [:]
    private var heldBindingCounts: [MacKeyBinding: Int] = [:]
    private struct PendingButtonMessage {
        let message: ControllerMessage
        let button: GameButton
        let state: ButtonPressState
        let source: String
    }

    private var activePressIdentifiersByButton: [GameButton: Set<UInt64>] = [:]
    private var anonymousPressCountsByButton: [GameButton: Int] = [:]
    private var buttonSequenceTracker = ButtonSequenceTracker()
    private var pendingButtonMessagesBySequence: [UInt64: PendingButtonMessage] = [:]
    private var buttonReorderFlushWorkItem: DispatchWorkItem?
    private var buttonReorderFlushGeneration = 0
    private var ignoredButtonEdgeCount = 0
    private var recoveredButtonEdgeCount = 0

    init() {
        let initialPairingCode = Self.generatePairingCode()
        pairingCode = initialPairingCode
        activePairingCode = initialPairingCode

        let loadedKeyBindings = Self.loadKeyBindings()
        let savedGamepadCustomization = GamepadCustomizationPersistence.load()
        let loadedProfileState = GamepadConfigurationProfilePersistence.load(activeCustomization: savedGamepadCustomization)
        let startupProfile = loadedProfileState.defaultProfile ?? loadedProfileState.activeProfile ?? loadedProfileState.profiles[0]
        let startupGamepadCustomization = startupProfile.customization.normalized

        keyBindings = loadedKeyBindings
        realtimeKeyBindings = loadedKeyBindings
        gamepadCustomization = startupGamepadCustomization
        gamepadProfiles = loadedProfileState.profiles
        activeGamepadProfileID = startupProfile.id
        defaultGamepadProfileID = loadedProfileState.defaultProfileID
        realtimeGamepadCustomization = startupGamepadCustomization
        realtimeGamepadProfiles = loadedProfileState.profiles
        realtimeActiveGamepadProfileID = startupProfile.id
        realtimeDefaultGamepadProfileID = loadedProfileState.defaultProfileID
        GamepadCustomizationPersistence.save(startupGamepadCustomization)
        GamepadConfigurationProfilePersistence.save(
            loadedProfileState.profiles,
            activeProfileID: startupProfile.id,
            defaultProfileID: loadedProfileState.defaultProfileID
        )
        networkQueue.setSpecific(key: networkQueueKey, value: true)
        refreshAccessibilityStatus()
        localURLs = Self.localIPv4Addresses().map { "ws://\($0):\(port)" }
    }

    deinit {
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
        } catch {
            guard fallbackIfBusy, isPreferredPortUnavailable(error) else {
                let failureText = "Failed to start: \(error.localizedDescription)"
                stop(finalStatusText: failureText, releaseReason: "Server failed to start")
                logDebug("server failed error=\(error.localizedDescription)")
                return
            }

            statusText = "Port \(Self.preferredPort) is unavailable; trying an available port…"
            logDebug("preferred_port_unavailable port=\(Self.preferredPort) error=\(error.localizedDescription) retry=auto")
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
        if finalStatusText == "Stopped" {
            logDebug("server stopped")
        } else {
            logDebug("server stopped status=\(finalStatusText)")
        }
    }

    func cancelPairing() {
        syncOnNetworkQueue {
            cancelPendingPairingOnNetworkQueue(reason: "Pairing cancelled")
        }
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = syncOnNetworkQueue {
            injector.refreshAccessibilityStatus()
        }
        lastAccessibilityRefresh = Date()
    }

    func promptForAccessibility() {
        _ = injector.promptForAccessibility()
        refreshAccessibilityStatus()
    }

    func openAccessibilitySettings() {
        injector.openAccessibilitySettings()
    }

    func keyLabel(for button: GameButton) -> String {
        guard let binding = keyBindings[button] else { return "Unmapped" }
        return binding.displayName
    }

    func recordedShortcutLabel(for button: GameButton) -> String? {
        keyBindings[button]?.displayName
    }

    func isDefaultBinding(for button: GameButton) -> Bool {
        keyBindings[button] == DefaultKeypadKeyMap.defaultBinding(for: button)
    }

    func setKeyBinding(_ binding: MacKeyBinding, for button: GameButton) {
        keyBindings[button] = binding
        syncOnNetworkQueue {
            releaseIfPressedOnNetworkQueue(button)
            realtimeKeyBindings[button] = binding
            sendGamepadProfileStateOnNetworkQueue()
        }
        saveKeyBindings()
        lastReceivedEvent = "Mapped \(button.displayName) to \(binding.displayName)"
        logDebug("key_binding button=\(button.rawValue) keyCode=\(binding.keyCode) modifiers=\(binding.modifiers.rawValue)")
    }

    func setKeyBinding(_ keyCode: CGKeyCode, for button: GameButton) {
        setKeyBinding(MacKeyBinding(keyCode: keyCode), for: button)
    }

    func resetKeyBinding(_ button: GameButton) {
        guard let defaultBinding = DefaultKeypadKeyMap.defaultBinding(for: button) else { return }
        setKeyBinding(defaultBinding, for: button)
    }

    func resetAllKeyBindings() {
        keyBindings = DefaultKeypadKeyMap.defaultBindings
        syncOnNetworkQueue {
            releaseAllOnNetworkQueue(reason: "Reset all key bindings")
            realtimeKeyBindings = DefaultKeypadKeyMap.defaultBindings
            sendGamepadProfileStateOnNetworkQueue()
        }
        saveKeyBindings()
        lastReceivedEvent = "Reset all key bindings"
        logDebug("key_bindings_reset_all")
    }

    func setGamepadCustomization(_ customization: GamepadCustomization) {
        var normalizedCustomization = customization.normalized
        guard !normalizedCustomization.hasSamePresentation(as: gamepadCustomization) else { return }
        normalizedCustomization = normalizedCustomization.stampedForLocalUpdate

        gamepadCustomization = normalizedCustomization
        GamepadCustomizationPersistence.save(normalizedCustomization)
        lastReceivedEvent = "Updated iPhone keypad layout"

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeGamepadCustomization = normalizedCustomization
            self.sendGamepadCustomizationOnNetworkQueue(normalizedCustomization)
        }
        logDebug("gamepad_customization_updated source=mac")
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

        gamepadProfiles = state.profiles
        activeGamepadProfileID = state.activeProfileID
        defaultGamepadProfileID = state.defaultProfileID

        if shouldApplyActiveCustomization {
            gamepadCustomization = realtimeCustomization
            GamepadCustomizationPersistence.save(realtimeCustomization)
        }
        persistGamepadProfileState()

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeGamepadCustomization = realtimeCustomization
            self.realtimeGamepadProfiles = state.profiles
            self.realtimeActiveGamepadProfileID = state.activeProfileID
            self.realtimeDefaultGamepadProfileID = state.defaultProfileID
            self.sendGamepadProfileStateOnNetworkQueue()
        }
    }

    func selectGamepadProfile(_ profileID: UUID, source: String = "mac") {
        guard let profile = gamepadProfiles.first(where: { $0.id == profileID }) else { return }
        let normalizedCustomization = profile.customization.stampedForLocalUpdate

        releaseAll(reason: "Switch keypad setup")
        activeGamepadProfileID = profile.id
        gamepadCustomization = normalizedCustomization
        GamepadCustomizationPersistence.save(normalizedCustomization)
        persistGamepadProfileState()
        lastReceivedEvent = "Switched keypad to \(profile.name)"

        asyncOnNetworkQueue { [weak self] in
            guard let self else { return }
            self.realtimeGamepadCustomization = normalizedCustomization
            self.realtimeActiveGamepadProfileID = profile.id
            self.sendGamepadCustomizationOnNetworkQueue(normalizedCustomization)
        }
        logDebug("gamepad_profile_selected source=\(source) profile=\(profile.id.uuidString)")
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
    }

    private func persistGamepadProfileState() {
        GamepadConfigurationProfilePersistence.save(
            gamepadProfiles,
            activeProfileID: activeGamepadProfileID,
            defaultProfileID: defaultGamepadProfileID
        )
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

        guard !inputPressedButtons.isEmpty || !heldBindingCounts.isEmpty else { return }
        for binding in heldBindingCounts.keys {
            injector.keyUp(binding)
        }
        heldBindingCounts.removeAll()
        activeBindings.removeAll()
        inputPressedButtons.removeAll()
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

        publishClientActivity(from: pairedConnection, force: message.type != .button)

        switch message.type {
        case .button:
            handleButtonMessageOnNetworkQueue(message, source: "iPhone UDP")

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
            publishClientActivity(from: connection, force: message.type != .button)
        }

        switch message.type {
        case .pairingRequest:
            handlePairingRequestOnNetworkQueue(message, from: connection)

        case .hello:
            guard let submittedCode = normalizedPairingCode(message.pairingCode) else {
                handlePairingRequestOnNetworkQueue(message, from: connection)
                return
            }
            guard submittedCode == activePairingCode else {
                rejectPairingOnNetworkQueue(connection, reason: "Wrong pairing code")
                return
            }
            acceptPairedClientOnNetworkQueue(message.clientName, from: connection)

        case .button:
            guard isPairedConnection else {
                logDebug("ignored_unpaired_message type=button")
                return
            }
            handleButtonMessageOnNetworkQueue(message, source: "iPhone")

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
            sendGamepadCustomizationOnNetworkQueue(realtimeGamepadCustomization)
            publishControllerDebug(event: "Customize keypad in PocketPad Mac", immediately: true)
            logDebug("ignored_gamepad_customization source=iphone reason=mac_only")

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
            self.lastHeartbeat = nil
            self.statusText = "Waiting for \(requestClientName) to enter pairing code"
            self.lastReceivedEvent = "Pairing request from \(requestClientName)"
        }

        logDebug("pairing_request client=\(requestClientName)")
    }

    private func acceptPairedClientOnNetworkQueue(_ incomingClientName: String?, from connection: NWConnection) {
        guard realtimeConnection === connection else { return }

        let newRealtimeToken = Self.generateRealtimeToken()
        pendingPairingConnection = nil
        pairedConnection = connection
        realtimeToken = newRealtimeToken
        let clientGamepadCustomization = gamepadCustomizationForClient(realtimeGamepadCustomization)
        let clientGamepadProfiles = gamepadProfilesForClient(realtimeGamepadProfiles)

        send(
            .init(
                type: .pairingAccepted,
                message: "Pairing complete",
                realtimeToken: newRealtimeToken,
                gamepadCustomization: clientGamepadCustomization,
                gamepadProfiles: clientGamepadProfiles,
                gamepadProfileID: realtimeActiveGamepadProfileID,
                defaultGamepadProfileID: realtimeDefaultGamepadProfileID
            ),
            on: connection
        )
        publishHello(incomingClientName, from: connection)

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

        logDebug("pairing_accepted client=\(incomingClientName ?? "Connected iPhone")")
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
                self.statusText = self.isRunning ? "Listening on port \(self.port)" : "Stopped"
            }
        }
    }

    private func normalizedPairingCode(_ code: String?) -> String? {
        guard let code else { return nil }
        let normalized = String(code.filter(\.isNumber).prefix(6))
        return normalized.isEmpty ? nil : normalized
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
            pressIdentifier: ControllerWireCodec.buttonPressIdentifier(from: message)
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

    private func drainPendingButtonMessagesOnNetworkQueue(flushOldestGap: Bool = false) {
        var didFlushGap = false

        while true {
            if let expectedSequence = buttonSequenceTracker.nextExpectedSequenceNumber,
               let pending = pendingButtonMessagesBySequence.removeValue(forKey: expectedSequence)
            {
                processButtonMessageOnNetworkQueue(
                    pending.message,
                    button: pending.button,
                    state: pending.state,
                    source: pending.source
                )
                continue
            }

            guard flushOldestGap, !didFlushGap,
                  let nextSequence = pendingButtonMessagesBySequence.keys.min(),
                  let pending = pendingButtonMessagesBySequence.removeValue(forKey: nextSequence)
            else {
                return
            }

            didFlushGap = true
            processButtonMessageOnNetworkQueue(
                pending.message,
                button: pending.button,
                state: pending.state,
                source: pending.source
            )
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
        pressIdentifier: UInt64? = nil
    ) {
        if sequenceInspection.isOutOfOrderOrReset, sequenceInspection.hasSequence {
            return
        }

        switch state {
        case .down:
            if inputPressedButtons.contains(button),
               sequenceInspection.missedFrameBeforeButton
            {
                noteRecoveredButtonEdge(button: button, state: state, reason: "missing_release_before_down")
                resetPhysicalHoldsOnNetworkQueue(for: button, keeping: pressIdentifier)
                handleButtonOnNetworkQueue(button, state: .up, source: source)
                handleButtonOnNetworkQueue(button, state: .down, source: source)
                return
            }

            if recordPhysicalPressBeganOnNetworkQueue(button, pressIdentifier: pressIdentifier) {
                handleButtonOnNetworkQueue(button, state: .down, source: source)
            }

        case .up:
            switch recordPhysicalPressEndedOnNetworkQueue(button, pressIdentifier: pressIdentifier) {
            case .shouldReleaseKey:
                handleButtonOnNetworkQueue(button, state: .up, source: source)

            case .stillHeld:
                break

            case .orphan:
                if sequenceInspection.missedFrameBeforeButton,
                   !hasPhysicalPressOnNetworkQueue(button)
                {
                    noteRecoveredButtonEdge(button: button, state: state, reason: "missing_down_before_up")
                    handleButtonOnNetworkQueue(button, state: .down, source: source)
                    handleButtonOnNetworkQueue(button, state: .up, source: source)
                } else {
                    noteIgnoredButtonEdge(button: button, state: state, reason: "orphan_up")
                }
            }
        }
    }

    private func handleButtonOnNetworkQueue(_ button: GameButton, state: ButtonPressState, source: String) {
        guard let binding = realtimeKeyBindings[button] else { return }

        switch state {
        case .down:
            guard !inputPressedButtons.contains(button) else {
                noteIgnoredButtonEdge(button: button, state: state, reason: "duplicate_down")
                return
            }
            let effectiveBinding = binding.withAdditionalModifiers(activeModifierKeysOnNetworkQueue())
            activeBindings[button] = effectiveBinding
            pressBinding(effectiveBinding)
            inputPressedButtons.insert(button)
            publishInputDebugIfDue(source: source, button: button, state: state, binding: effectiveBinding)
            logInputEvent("button source=\(source) button=\(button.rawValue) state=down keyCode=\(effectiveBinding.keyCode) modifiers=\(effectiveBinding.modifiers.rawValue) pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")

        case .up:
            guard inputPressedButtons.contains(button) else {
                noteIgnoredButtonEdge(button: button, state: state, reason: "orphan_up")
                return
            }
            let releasedBinding = activeBindings.removeValue(forKey: button) ?? binding
            releaseBinding(releasedBinding)
            inputPressedButtons.remove(button)
            publishInputDebugIfDue(source: source, button: button, state: state, binding: releasedBinding)
            logInputEvent("button source=\(source) button=\(button.rawValue) state=up keyCode=\(releasedBinding.keyCode) modifiers=\(releasedBinding.modifiers.rawValue) pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")
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
        anonymousPressCountsByButton.removeAll()
    }

    private func recordPhysicalPressBeganOnNetworkQueue(
        _ button: GameButton,
        pressIdentifier: UInt64?
    ) -> Bool {
        let wasPhysicallyPressed = hasPhysicalPressOnNetworkQueue(button)

        if let pressIdentifier {
            var identifiers = activePressIdentifiersByButton[button, default: []]
            let inserted = identifiers.insert(pressIdentifier).inserted
            activePressIdentifiersByButton[button] = identifiers
            return inserted && !wasPhysicallyPressed
        }

        anonymousPressCountsByButton[button, default: 0] += 1
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
        } else {
            guard let count = anonymousPressCountsByButton[button],
                  count > 0
            else {
                return .orphan
            }

            if count == 1 {
                anonymousPressCountsByButton[button] = nil
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

    private func resetPhysicalHoldsOnNetworkQueue(
        for button: GameButton,
        keeping pressIdentifier: UInt64?
    ) {
        if let pressIdentifier {
            activePressIdentifiersByButton[button] = [pressIdentifier]
            anonymousPressCountsByButton[button] = nil
        } else {
            activePressIdentifiersByButton[button] = nil
            anonymousPressCountsByButton[button] = 1
        }
    }

    private func clearPhysicalHoldsOnNetworkQueue(for button: GameButton) {
        activePressIdentifiersByButton[button] = nil
        anonymousPressCountsByButton[button] = nil
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
        logDebug("ignored_button_edge reason=\(reason) button=\(button.rawValue) state=\(state.rawValue) pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")
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
        logDebug("recovered_button_edge reason=\(reason) button=\(button.rawValue) state=\(state.rawValue)")
    }

    private func releaseIfPressedOnNetworkQueue(_ button: GameButton) {
        clearPhysicalHoldsOnNetworkQueue(for: button)
        guard inputPressedButtons.contains(button) else { return }
        inputPressedButtons.remove(button)
        if let activeBinding = activeBindings.removeValue(forKey: button) {
            releaseBinding(activeBinding)
        }
        publishControllerDebug(pressedButtons: inputPressedButtons, immediately: true)
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

    private func send(_ message: ControllerMessage, on connection: NWConnection) {
        guard let data = try? ControllerWireCodec.encode(message, using: encoder) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "PocketPadMessage", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }

    private func gamepadCustomizationForClient(_ customization: GamepadCustomization) -> GamepadCustomization {
        var clientCustomization = customization.normalized
        for button in GameButton.allCases where clientCustomization.labelOverride(for: button) == nil {
            guard let binding = realtimeKeyBindings[button] else { continue }
            clientCustomization.setLabel(binding.displayName, for: button)
        }
        return clientCustomization.normalized
    }

    private func gamepadProfilesForClient(_ profiles: [GamepadConfigurationProfile]) -> [GamepadConfigurationProfile] {
        profiles.map { profile in
            var clientProfile = profile
            clientProfile.customization = gamepadCustomizationForClient(profile.customization)
            return clientProfile.normalized
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
            if usingFallbackPort {
                statusText = "Listening on port \(port) (\(Self.preferredPort) was unavailable)"
            } else {
                statusText = "Listening on port \(port)"
            }
            logDebug("listener ready port=\(port) urls=\(localURLs)")
        case .failed(let error):
            if fallbackIfBusy, isPreferredPortUnavailable(error) {
                statusText = "Port \(Self.preferredPort) is unavailable; trying an available port…"
                logDebug("preferred_port_unavailable port=\(Self.preferredPort) error=\(error.localizedDescription) retry=auto")
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
        binding: MacKeyBinding
    ) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard inputPressedButtons.isEmpty || now - lastInputDebugPublishUptime >= Self.inputDebugPublishIntervalNanoseconds else { return }
        lastInputDebugPublishUptime = now

        let event = "\(source): \(button.rawValue) \(state.rawValue) (\(binding.displayName))"
        publishControllerDebug(event: event, pressedButtons: inputPressedButtons)
    }

    private func publishHello(_ incomingClientName: String?, from helloConnection: NWConnection) {
        DispatchQueue.main.async { [weak self, weak helloConnection] in
            guard let self,
                  let helloConnection,
                  self.connection === helloConnection
            else { return }

            let resolvedClientName = incomingClientName ?? "Connected iPhone"
            self.clientName = resolvedClientName
            self.isClientConnected = true
            self.lastHeartbeat = Date()
            self.lastReceivedEvent = "Hello from \(resolvedClientName)"
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

    private func saveKeyBindings() {
        let stored = Dictionary(uniqueKeysWithValues: keyBindings.map { button, binding in
            (button.rawValue, binding)
        })
        guard let data = try? JSONEncoder().encode(stored) else { return }
        UserDefaults.standard.set(data, forKey: Self.keyBindingsDefaultsKey)
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

    private static func generatePairingCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
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
