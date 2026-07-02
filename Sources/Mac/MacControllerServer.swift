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
    @Published private(set) var keyBindings: [GameButton: CGKeyCode]
    @Published private(set) var port: UInt16 = MacControllerServer.preferredPort

    var pairingPayload: String {
        let payload = PairingPayload(urls: localURLs, pairingCode: pairingCode)
        guard let data = try? JSONEncoder().encode(payload) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private let networkQueue = DispatchQueue(label: "PocketPad.WebSocketServer", qos: .userInteractive)
    private let networkQueueKey = DispatchSpecificKey<Bool>()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let injector = KeyboardInjector()
    private let debugLogURL = URL(fileURLWithPath: "/tmp/pocketpad-mac-events.log")
    private let logQueue = DispatchQueue(label: "PocketPad.DebugLog", qos: .utility)
    private static let preferredPort: UInt16 = 8765
    private static let keyBindingsDefaultsKey = "PocketPadMac.keyBindings.v1"
    private static let inputEventLoggingEnabled = false
    private static let inputDebugPublishIntervalNanoseconds: UInt64 = 100_000_000
    private static let clientActivityPublishIntervalNanoseconds: UInt64 = 100_000_000
    private var listener: NWListener?
    private var connection: NWConnection?
    private var realtimeConnection: NWConnection?
    private var pairedConnection: NWConnection?
    private var pendingPairingConnection: NWConnection?
    private var activePairingCode: String
    private var backgroundActivity: NSObjectProtocol?
    private var heartbeatTimer: Timer?
    private var heartbeatTimedOut = false
    private var inputPressedButtons: Set<GameButton> = []
    private var realtimeKeyBindings: [GameButton: CGKeyCode]
    private var pendingLastReceivedEvent: String?
    private var pendingPressedButtons: Set<GameButton>?
    private var controllerDebugUpdateTask: Task<Void, Never>?
    private var lastInputDebugPublishUptime: UInt64 = 0
    private var lastClientActivityPublishUptime: UInt64 = 0
    private var lastAccessibilityRefresh = Date.distantPast
    private var activeKeyCodes: [GameButton: CGKeyCode] = [:]
    private var heldKeyCounts: [CGKeyCode: Int] = [:]
    private var buttonSequenceTracker = ButtonSequenceTracker()
    private var ignoredButtonEdgeCount = 0
    private var recoveredButtonEdgeCount = 0
    private var inputPulseSequencer = ButtonPulseSequencer(
        minimumTapDurationNanoseconds: ButtonPulseSequencer.actionGameMinimumTapDurationNanoseconds,
        minimumInterTapGapNanoseconds: ButtonPulseSequencer.actionGameMinimumInterTapGapNanoseconds
    )
    private var pendingInputReleaseTimers: [GameButton: DispatchWorkItem] = [:]
    private var pendingInputPressTimers: [GameButton: DispatchWorkItem] = [:]

    init() {
        let initialPairingCode = Self.generatePairingCode()
        pairingCode = initialPairingCode
        activePairingCode = initialPairingCode

        let loadedKeyBindings = Self.loadKeyBindings()
        keyBindings = loadedKeyBindings
        realtimeKeyBindings = loadedKeyBindings
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
        }
        connection?.cancel()
        listener?.cancel()
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        endBackgroundActivity()
        connection = nil
        listener = nil
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
        guard let keyCode = keyBindings[button] else { return "Unmapped" }
        return MacVirtualKey.displayName(for: keyCode)
    }

    func isDefaultBinding(for button: GameButton) -> Bool {
        keyBindings[button] == HollowKnightKeyMap.defaultKeyCode(for: button)
    }

    func setKeyBinding(_ keyCode: CGKeyCode, for button: GameButton) {
        keyBindings[button] = keyCode
        syncOnNetworkQueue {
            releaseIfPressedOnNetworkQueue(button)
            realtimeKeyBindings[button] = keyCode
        }
        saveKeyBindings()
        lastReceivedEvent = "Mapped \(button.displayName) to \(MacVirtualKey.displayName(for: keyCode))"
        logDebug("key_binding button=\(button.rawValue) keyCode=\(keyCode)")
    }

    func resetKeyBinding(_ button: GameButton) {
        guard let defaultKeyCode = HollowKnightKeyMap.defaultKeyCode(for: button) else { return }
        setKeyBinding(defaultKeyCode, for: button)
    }

    func resetAllKeyBindings() {
        keyBindings = HollowKnightKeyMap.defaultKeyCodes
        syncOnNetworkQueue {
            releaseAllOnNetworkQueue(reason: "Reset all key bindings")
            realtimeKeyBindings = HollowKnightKeyMap.defaultKeyCodes
        }
        saveKeyBindings()
        lastReceivedEvent = "Reset all key bindings"
        logDebug("key_bindings_reset_all")
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
        resetInputPulseStateOnNetworkQueue()
        buttonSequenceTracker.resetAcceptingNextSequenceAsBaseline()

        guard !inputPressedButtons.isEmpty || !heldKeyCounts.isEmpty else { return }
        for keyCode in heldKeyCounts.keys {
            injector.keyUp(keyCode)
        }
        heldKeyCounts.removeAll()
        activeKeyCodes.removeAll()
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
        realtimeConnection = newConnection
        pairedConnection = nil
        pendingPairingConnection = newConnection
        resetButtonSequenceDiagnosticsOnNetworkQueue()
        resetInputPulseStateOnNetworkQueue()

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

    private func handleReceivedDataOnNetworkQueue(_ data: Data, from connection: NWConnection) {
        guard realtimeConnection === connection else { return }
        do {
            let message = try ControllerWireCodec.decode(data, using: decoder)
            handleMessageOnNetworkQueue(message, from: connection)
        } catch {
            publishControllerDebug(event: "Invalid controller message: \(error.localizedDescription)", immediately: true)
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
            guard let button = message.button, let state = message.state else {
                publishControllerDebug(event: "Ignored malformed button event", immediately: true)
                return
            }
            let sequenceInspection = inspectButtonSequence(message, button: button, state: state)
            handleInputPulseOnNetworkQueue(
                button,
                state: state,
                source: "iPhone",
                sequenceInspection: sequenceInspection,
                pressIdentifier: ControllerWireCodec.buttonPressIdentifier(from: message)
            )

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

        pendingPairingConnection = nil
        pairedConnection = connection
        send(.init(type: .pairingAccepted, message: "Pairing complete"), on: connection)
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
        } else {
            pendingPairingConnection = nil
            pairedConnection = nil
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
            logDebug("button_sequence_reset expected=\(expectedSequence) received=\(receivedSequence) button=\(button.rawValue) state=\(state.rawValue)")
        }

        return inspection
    }

    private func handleInputPulseOnNetworkQueue(
        _ button: GameButton,
        state: ButtonPressState,
        source: String,
        sequenceInspection: ButtonSequenceInspection = ButtonSequenceInspection(),
        pressIdentifier: UInt64? = nil
    ) {
        let now = DispatchTime.now().uptimeNanoseconds
        let commands: [ButtonPulseCommand]

        if state == .up,
           sequenceInspection.missedFrameBeforeButton,
           !inputPulseSequencer.hasPhysicalPress(button, pressIdentifier: pressIdentifier)
        {
            noteRecoveredButtonEdge(button: button, state: state, reason: "missing_down_before_up")
            commands = inputPulseSequencer.recoverMissingPressBeforeRelease(
                button,
                pressIdentifier: pressIdentifier,
                now: now
            )
        } else if state == .down,
                  inputPulseSequencer.isPressed(button),
                  (!sequenceInspection.hasSequence || sequenceInspection.missedFrameBeforeButton)
        {
            noteRecoveredButtonEdge(button: button, state: state, reason: "missing_release_before_down")
            commands = inputPulseSequencer.recoverMissingReleaseBeforePress(
                button,
                pressIdentifier: pressIdentifier,
                now: now
            )
        } else {
            commands = inputPulseSequencer.setButton(
                button,
                pressed: state == .down,
                pressIdentifier: pressIdentifier,
                now: now
            )
        }

        handleInputPulseCommands(
            commands,
            source: source
        )
    }

    private func handleInputPulseCommands(_ commands: [ButtonPulseCommand], source: String) {
        for command in commands {
            handleInputPulseCommand(command, source: source)
        }
    }

    private func handleInputPulseCommand(_ command: ButtonPulseCommand, source: String) {
        switch command {
        case .send(let button, let state):
            handleButtonOnNetworkQueue(button, state: state, source: source)

        case .scheduleRelease(let button, let delayNanoseconds):
            pendingInputReleaseTimers[button]?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingInputReleaseTimers[button] = nil
                self.handleInputPulseCommands(
                    self.inputPulseSequencer.releaseTimerFired(
                        for: button,
                        now: DispatchTime.now().uptimeNanoseconds
                    ),
                    source: source
                )
            }
            pendingInputReleaseTimers[button] = workItem
            networkQueue.asyncAfter(
                deadline: .now() + dispatchDelay(for: delayNanoseconds),
                execute: workItem
            )

        case .schedulePress(let button, let delayNanoseconds):
            pendingInputPressTimers[button]?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.pendingInputPressTimers[button] = nil
                self.handleInputPulseCommands(
                    self.inputPulseSequencer.pressTimerFired(
                        for: button,
                        now: DispatchTime.now().uptimeNanoseconds
                    ),
                    source: source
                )
            }
            pendingInputPressTimers[button] = workItem
            networkQueue.asyncAfter(
                deadline: .now() + dispatchDelay(for: delayNanoseconds),
                execute: workItem
            )
        }
    }

    private func handleButtonOnNetworkQueue(_ button: GameButton, state: ButtonPressState, source: String) {
        guard let keyCode = realtimeKeyBindings[button] else { return }

        switch state {
        case .down:
            guard !inputPressedButtons.contains(button) else {
                noteIgnoredButtonEdge(button: button, state: state, reason: "duplicate_down")
                return
            }
            activeKeyCodes[button] = keyCode
            pressKey(keyCode)
            inputPressedButtons.insert(button)
            publishInputDebugIfDue(source: source, button: button, state: state, keyCode: keyCode)
            logInputEvent("button source=\(source) button=\(button.rawValue) state=down keyCode=\(keyCode) pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")

        case .up:
            guard inputPressedButtons.contains(button) else {
                noteIgnoredButtonEdge(button: button, state: state, reason: "orphan_up")
                return
            }
            let releasedKeyCode = activeKeyCodes.removeValue(forKey: button) ?? keyCode
            releaseKey(releasedKeyCode)
            inputPressedButtons.remove(button)
            publishInputDebugIfDue(source: source, button: button, state: state, keyCode: releasedKeyCode)
            logInputEvent("button source=\(source) button=\(button.rawValue) state=up keyCode=\(releasedKeyCode) pressed=\(self.inputPressedButtons.map(\.rawValue).sorted())")
        }
    }

    private func resetButtonSequenceDiagnosticsOnNetworkQueue() {
        buttonSequenceTracker.reset()
        ignoredButtonEdgeCount = 0
        recoveredButtonEdgeCount = 0
    }

    private func resetInputPulseStateOnNetworkQueue() {
        for workItem in pendingInputReleaseTimers.values {
            workItem.cancel()
        }
        for workItem in pendingInputPressTimers.values {
            workItem.cancel()
        }
        pendingInputReleaseTimers.removeAll()
        pendingInputPressTimers.removeAll()
        inputPulseSequencer.reset()
    }

    private func dispatchDelay(for nanoseconds: UInt64) -> DispatchTimeInterval {
        .nanoseconds(Int(min(nanoseconds, UInt64(Int.max))))
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
        guard inputPressedButtons.contains(button) else { return }
        inputPressedButtons.remove(button)
        if let activeKeyCode = activeKeyCodes.removeValue(forKey: button) {
            releaseKey(activeKeyCode)
        }
        publishControllerDebug(pressedButtons: inputPressedButtons, immediately: true)
    }

    private func pressKey(_ keyCode: CGKeyCode) {
        let currentCount = heldKeyCounts[keyCode, default: 0]
        heldKeyCounts[keyCode] = currentCount + 1
        if currentCount == 0 {
            injector.keyDown(keyCode)
        }
    }

    private func releaseKey(_ keyCode: CGKeyCode) {
        let currentCount = heldKeyCounts[keyCode, default: 0]
        guard currentCount > 0 else {
            injector.keyUp(keyCode)
            return
        }

        if currentCount == 1 {
            heldKeyCounts[keyCode] = nil
            injector.keyUp(keyCode)
        } else {
            heldKeyCounts[keyCode] = currentCount - 1
        }
    }

    private func send(_ message: ControllerMessage, on connection: NWConnection) {
        guard let data = try? ControllerWireCodec.encode(message, using: encoder) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "PocketPadMessage", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
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
            reason: "PocketPad is forwarding controller input to a game"
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
        keyCode: CGKeyCode
    ) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard inputPressedButtons.isEmpty || now - lastInputDebugPublishUptime >= Self.inputDebugPublishIntervalNanoseconds else { return }
        lastInputDebugPublishUptime = now

        let event = "\(source): \(button.rawValue) \(state.rawValue) (\(MacVirtualKey.displayName(for: keyCode)))"
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
        let stored = Dictionary(uniqueKeysWithValues: keyBindings.map { button, keyCode in
            (button.rawValue, Int(keyCode))
        })
        UserDefaults.standard.set(stored, forKey: Self.keyBindingsDefaultsKey)
    }

    private static func loadKeyBindings() -> [GameButton: CGKeyCode] {
        var bindings = HollowKnightKeyMap.defaultKeyCodes
        guard let stored = UserDefaults.standard.dictionary(forKey: keyBindingsDefaultsKey) else {
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
            bindings[button] = CGKeyCode(keyCode)
        }

        return bindings
    }

    private static func generatePairingCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
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
