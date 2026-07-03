import Foundation
import Network
import UIKit

private final class ControllerInputTransport {
    private struct ButtonSendSnapshot {
        let sequenceNumber: UInt64
        let reliableConnection: NWConnection
        let datagramConnection: NWConnection?
    }

    private let networkQueue: DispatchQueue
    private let lock = NSLock()
    private var reliableConnection: NWConnection?
    private var realtimeDatagramConnection: NWConnection?
    private var isRealtimeDatagramReady = false
    private var buttonSequenceNumber: UInt64 = 0
    private let binaryMessageContext = NWConnection.ContentContext(
        identifier: "PocketPadInputMessage",
        metadata: [NWProtocolWebSocket.Metadata(opcode: .binary)]
    )

    // Keep TCP close behind UDP so packet-loss recovery stays below a tight
    // action-game frame budget while the UDP fast path still wins normal races.
    private static let reliableMirrorDelayNanoseconds: Int = 500_000

    init(networkQueue: DispatchQueue) {
        self.networkQueue = networkQueue
    }

    func setReliableConnection(_ connection: NWConnection?, resetSequence: Bool) {
        lock.lock()
        reliableConnection = connection
        if resetSequence {
            buttonSequenceNumber = 0
        }
        lock.unlock()
    }

    func setRealtimeDatagramConnection(_ connection: NWConnection?, ready: Bool) {
        lock.lock()
        realtimeDatagramConnection = connection
        isRealtimeDatagramReady = connection != nil && ready
        lock.unlock()
    }

    func setRealtimeDatagramReady(_ ready: Bool, for connection: NWConnection) {
        lock.lock()
        if realtimeDatagramConnection === connection {
            isRealtimeDatagramReady = ready
        }
        lock.unlock()
    }

    func clearRealtimeDatagramConnection(_ connection: NWConnection?) {
        lock.lock()
        if connection == nil || realtimeDatagramConnection === connection {
            realtimeDatagramConnection = nil
            isRealtimeDatagramReady = false
        }
        lock.unlock()
    }

    func disconnect() {
        lock.lock()
        reliableConnection = nil
        realtimeDatagramConnection = nil
        isRealtimeDatagramReady = false
        buttonSequenceNumber = 0
        lock.unlock()
    }

    @discardableResult
    func sendButton(
        _ button: GameButton,
        state: ButtonPressState,
        pressIdentifier: UInt64?
    ) -> Bool {
        guard let snapshot = makeButtonSendSnapshot() else { return false }

        let messageContext = binaryMessageContext
        let sendQueue = networkQueue
        sendQueue.async {
            let data = ControllerWireCodec.encodeButton(
                button,
                state: state,
                sequenceNumber: snapshot.sequenceNumber,
                pressIdentifier: pressIdentifier
            )

            if let datagramConnection = snapshot.datagramConnection {
                datagramConnection.send(
                    content: data,
                    contentContext: .defaultMessage,
                    isComplete: true,
                    completion: .idempotent
                )
                Self.sendReliableMirror(
                    data,
                    on: snapshot.reliableConnection,
                    context: messageContext,
                    queue: sendQueue
                )
            } else {
                snapshot.reliableConnection.send(
                    content: data,
                    contentContext: messageContext,
                    isComplete: true,
                    completion: .idempotent
                )
            }
        }

        return true
    }

    private func makeButtonSendSnapshot() -> ButtonSendSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        guard let reliableConnection else { return nil }
        let sequenceNumber = nextButtonSequenceNumber()
        let datagramConnection = isRealtimeDatagramReady ? realtimeDatagramConnection : nil
        return ButtonSendSnapshot(
            sequenceNumber: sequenceNumber,
            reliableConnection: reliableConnection,
            datagramConnection: datagramConnection
        )
    }

    private func nextButtonSequenceNumber() -> UInt64 {
        if buttonSequenceNumber >= ControllerWireCodec.maximumButtonSequenceNumber {
            buttonSequenceNumber = 1
        } else {
            buttonSequenceNumber += 1
        }
        return buttonSequenceNumber
    }

    private static func sendReliableMirror(
        _ data: Data,
        on connection: NWConnection,
        context: NWConnection.ContentContext,
        queue: DispatchQueue
    ) {
        queue.asyncAfter(deadline: .now() + .nanoseconds(reliableMirrorDelayNanoseconds)) {
            connection.send(
                content: data,
                contentContext: context,
                isComplete: true,
                completion: .idempotent
            )
        }
    }
}

@MainActor
final class ControllerClient: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case pairingCodeRequired
        case connected
        case failed(String)

        var label: String {
            switch self {
            case .disconnected: "Disconnected"
            case .connecting: "Connecting…"
            case .pairingCodeRequired: "Enter pairing code"
            case .connected: "Connected"
            case .failed(let message): "Failed: \(message)"
            }
        }
    }

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var lastSentEvent = "None"
    @Published private(set) var lastError: String?
    @Published private(set) var gamepadCustomization: GamepadCustomization
    @Published private(set) var gamepadProfiles: [GamepadConfigurationProfile]
    @Published private(set) var selectedGamepadProfileID: UUID
    @Published private(set) var defaultGamepadProfileID: UUID
    @Published private(set) var hasSavedKeypadSnapshot = false
    @Published private(set) var smartConnectStatus: String?

    private let networkQueue = DispatchQueue(label: "PocketPad.iOS.Network", qos: .userInteractive)
    private let inputTransport: ControllerInputTransport
    private var connection: NWConnection?
    private var controlURL: URL?
    private var trustedMacCredential: TrustedMacCredential?
    private var currentAuthToken: String?
    private var currentExpectedServerID: String?
    private var smartDiscovery: SmartMacDiscovery?
    private var reconnectTask: Task<Void, Never>?
    private var autoReconnectEnabled = false
    private var realtimeDatagramConnection: NWConnection?
    private var isRealtimeDatagramReady = false
    private var heartbeatTask: Task<Void, Never>?
    private var realtimeDatagramHandshakeTask: Task<Void, Never>?
    private var lastSentEventUpdateTask: Task<Void, Never>?
    private var pendingLastSentEvent = "None"
    private var activeInputState = ControllerActiveInputState()
    private let binaryMessageContext = NWConnection.ContentContext(
        identifier: "PocketPadMessage",
        metadata: [NWProtocolWebSocket.Metadata(opcode: .binary)]
    )
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private static let liveInputStatusUpdatesEnabled = false
    private static let defaultPort: UInt16 = 8765
    private static let trustedMacCredentialDefaultsKey = "PocketPad.iOS.trustedMacCredential.v1"
    private static let hasSavedKeypadSnapshotDefaultsKey = "PocketPad.iOS.hasSavedKeypadSnapshot.v1"

    var isConnected: Bool {
        state == .connected
    }

    var canViewSavedKeypadOffline: Bool {
        hasSavedKeypadSnapshot || trustedMacCredential != nil
    }

    var savedKeypadMacName: String? {
        trustedMacCredential?.macName
    }

    var isAwaitingPairingCode: Bool {
        state == .pairingCodeRequired
    }

    var selectedGamepadProfile: GamepadConfigurationProfile? {
        gamepadProfiles.first { $0.id == selectedGamepadProfileID }
    }

    var selectedGamepadProfileName: String {
        selectedGamepadProfile?.name ?? "Keypad"
    }

    var isSelectedGamepadProfileDefault: Bool {
        selectedGamepadProfileID == defaultGamepadProfileID
    }

    init() {
        inputTransport = ControllerInputTransport(networkQueue: networkQueue)
        let savedCustomization = GamepadCustomizationPersistence.load()
        let loadedProfileState = GamepadConfigurationProfilePersistence.load(activeCustomization: savedCustomization)
        let savedTrustedMacCredential = Self.loadTrustedMacCredential()
        let startupProfile = loadedProfileState.defaultProfile ?? loadedProfileState.activeProfile ?? loadedProfileState.profiles[0]
        let startupCustomization = startupProfile.customization.normalized

        gamepadCustomization = startupCustomization
        gamepadProfiles = loadedProfileState.profiles
        selectedGamepadProfileID = startupProfile.id
        defaultGamepadProfileID = loadedProfileState.defaultProfileID
        GamepadCustomizationPersistence.save(startupCustomization)
        GamepadConfigurationProfilePersistence.save(
            loadedProfileState.profiles,
            activeProfileID: startupProfile.id,
            defaultProfileID: loadedProfileState.defaultProfileID
        )
        trustedMacCredential = savedTrustedMacCredential
        hasSavedKeypadSnapshot = Self.loadHasSavedKeypadSnapshot() || savedTrustedMacCredential != nil
        if hasSavedKeypadSnapshot {
            UserDefaults.standard.set(true, forKey: Self.hasSavedKeypadSnapshotDefaultsKey)
        }
    }

    func startSmartConnect() {
        guard state != .connected, state != .connecting, state != .pairingCodeRequired else { return }
        guard let credential = trustedMacCredential ?? Self.loadTrustedMacCredential() else {
            smartConnectStatus = "Pair once with the Mac QR code to enable Smart Connect."
            return
        }

        trustedMacCredential = credential
        autoReconnectEnabled = true
        lastError = nil
        smartConnectStatus = "Smart Connect: looking for your Mac…"

        if let url = credential.lastURL {
            connectTrusted(to: url, credential: credential)
        }
        startSmartDiscovery(for: credential)
    }

    func appDidBecomeActive() {
        startSmartConnect()
    }

    func connect(hostField: String, port: String, pairingCode: String) {
        stopSmartDiscovery()
        reconnectTask?.cancel()
        reconnectTask = nil
        autoReconnectEnabled = false
        smartConnectStatus = nil
        openConnection(hostField: hostField, port: port, pairingCode: pairingCode)
    }

    func disconnect(sendReleaseAll: Bool = true) {
        autoReconnectEnabled = false
        stopSmartDiscovery()
        reconnectTask?.cancel()
        reconnectTask = nil
        closeConnection(sendReleaseAll: sendReleaseAll)
        if case .failed = state {
            return
        }
        state = .disconnected
    }

    private func connectTrusted(to url: URL, credential: TrustedMacCredential) {
        openConnection(
            hostField: url.absoluteString,
            port: "",
            pairingCode: "",
            authToken: credential.authToken,
            expectedServerID: credential.serverID
        )
    }

    private func openConnection(
        hostField: String,
        port: String,
        pairingCode: String,
        authToken: String? = nil,
        expectedServerID: String? = nil
    ) {
        closeConnection(sendReleaseAll: false)

        guard let url = makeURL(hostField: hostField, port: port),
              url.host?.isEmpty == false
        else {
            state = .failed("Enter a valid ws:// host and port")
            return
        }

        state = .connecting
        lastError = nil

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true

        let scheme = url.scheme?.lowercased()
        let tlsOptions = scheme == "wss" ? NWProtocolTLS.Options() : nil
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        let websocketOptions = NWProtocolWebSocket.Options()
        websocketOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(websocketOptions, at: 0)

        let connection = NWConnection(to: .url(url), using: parameters)
        self.connection = connection
        controlURL = url
        currentAuthToken = authToken?.nilIfBlank
        currentExpectedServerID = expectedServerID?.nilIfBlank
        inputTransport.setReliableConnection(nil, resetSequence: true)

        let deviceName = UIDevice.current.name
        let pairingCode = pairingCode.nilIfBlank
        let connectionAuthToken = currentAuthToken
        let connectionExpectedServerID = currentExpectedServerID

        connection.stateUpdateHandler = { [weak self, weak connection] connectionState in
            guard let connection else { return }
            Task { @MainActor in
                self?.handleConnectionState(
                    connectionState,
                    connection: connection,
                    pairingCode: pairingCode,
                    authToken: connectionAuthToken,
                    expectedServerID: connectionExpectedServerID,
                    clientName: deviceName
                )
            }
        }

        connection.start(queue: networkQueue)
    }

    private func closeConnection(sendReleaseAll: Bool) {
        if sendReleaseAll {
            releaseAll()
        }
        activeInputState.removeAll()
        inputTransport.disconnect()
        heartbeatTask?.cancel()
        heartbeatTask = nil
        stopRealtimeDatagram()
        lastSentEventUpdateTask?.cancel()
        lastSentEventUpdateTask = nil
        connection?.cancel()
        connection = nil
        controlURL = nil
        currentAuthToken = nil
        currentExpectedServerID = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    func submitPairingCode(_ code: String) {
        let normalizedCode = String(code.filter(\.isNumber).prefix(6))
        guard !normalizedCode.isEmpty, connection != nil else { return }

        lastError = nil
        updateLastSentEvent("pairing code sent", immediately: true)
        send(.init(type: .hello, timestamp: 0, pairingCode: normalizedCode, clientName: UIDevice.current.name))
    }

    func setButton(_ button: GameButton, pressed: Bool, pressIdentifier: UInt64? = nil) {
        guard isConnected else { return }
        // Send raw per-touch edges immediately. The Mac helper keeps physical
        // touch identity so the injected key state can change without timer delays.
        let state: ButtonPressState = pressed ? .down : .up
        guard inputTransport.sendButton(button, state: state, pressIdentifier: pressIdentifier) else { return }
        activeInputState.record(button: button, state: state, pressIdentifier: pressIdentifier)
        if Self.liveInputStatusUpdatesEnabled {
            updateLastSentEvent("\(button.rawValue) \(state.rawValue)")
        }
    }

    func releaseAll() {
        activeInputState.removeAll()
        guard connection != nil else { return }
        send(.init(type: .releaseAll, timestamp: 0), prefersRealtimeDatagram: true)
        updateLastSentEvent("release_all", immediately: true)
    }

    func selectGamepadProfile(_ profileID: UUID) {
        guard let profile = gamepadProfiles.first(where: { $0.id == profileID }) else { return }
        releaseAll()
        selectedGamepadProfileID = profile.id
        applyLocalGamepadCustomization(profile.customization.stampedForLocalUpdate)
        persistGamepadProfiles()
        send(.init(type: .gamepadProfileSelection, timestamp: 0, gamepadProfileID: profile.id))
        updateLastSentEvent("keypad setup: \(profile.name)", immediately: true)
    }

    func setDefaultGamepadProfile(_ profileID: UUID) {
        guard gamepadProfiles.contains(where: { $0.id == profileID }) else { return }
        defaultGamepadProfileID = profileID
        persistGamepadProfiles()
        send(
            .init(
                type: .gamepadDefaultProfile,
                timestamp: 0,
                gamepadProfileID: profileID,
                defaultGamepadProfileID: profileID
            )
        )
        updateLastSentEvent("default keypad saved", immediately: true)
    }

    private func applyLocalGamepadCustomization(_ customization: GamepadCustomization) {
        let normalizedCustomization = customization.normalized
        guard normalizedCustomization != gamepadCustomization else { return }
        gamepadCustomization = normalizedCustomization
        GamepadCustomizationPersistence.save(normalizedCustomization)
    }

    private func applyGamepadCustomizationFromMac(_ customization: GamepadCustomization) {
        applyLocalGamepadCustomization(customization)
    }

    private func applyGamepadProfileStateFromMac(_ message: ControllerMessage) {
        guard let incomingProfiles = message.gamepadProfiles, !incomingProfiles.isEmpty else {
            if let customization = message.gamepadCustomization {
                applyGamepadCustomizationFromMac(customization)
            }
            return
        }

        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: incomingProfiles,
            activeProfileID: message.gamepadProfileID,
            defaultProfileID: message.defaultGamepadProfileID,
            fallbackCustomization: message.gamepadCustomization ?? gamepadCustomization
        )
        gamepadProfiles = state.profiles
        selectedGamepadProfileID = state.activeProfileID
        defaultGamepadProfileID = state.defaultProfileID
        markSavedKeypadSnapshotAvailable()

        if let customization = message.gamepadCustomization {
            applyGamepadCustomizationFromMac(customization)
        } else if let activeProfile = state.activeProfile {
            applyGamepadCustomizationFromMac(activeProfile.customization)
        }

        persistGamepadProfiles()
    }

    private func persistGamepadProfiles() {
        GamepadConfigurationProfilePersistence.save(
            gamepadProfiles,
            activeProfileID: selectedGamepadProfileID,
            defaultProfileID: defaultGamepadProfileID
        )
    }

    func appWillBecomeInactive() {
        // Losing focus briefly (Control Center, alerts, app switcher, etc.) should not
        // tear down the keypad socket. Release held buttons for safety, then keep
        // heartbeats running so the Mac helper can recover when the app is active again.
        releaseAll()
    }

    func appDidEnterBackground() {
        releaseAll()
        disconnect(sendReleaseAll: false)
    }

    private func handleConnectionState(
        _ connectionState: NWConnection.State,
        connection stateConnection: NWConnection,
        pairingCode: String?,
        authToken: String?,
        expectedServerID: String?,
        clientName: String
    ) {
        guard connection === stateConnection else { return }

        switch connectionState {
        case .ready:
            guard state != .connected else { return }
            lastSentEvent = "Socket ready"
            receiveNext(on: stateConnection)

            if let authToken {
                send(.init(type: .hello, timestamp: 0, clientName: clientName, authToken: authToken, serverID: expectedServerID))
            } else if let pairingCode {
                send(.init(type: .hello, timestamp: 0, pairingCode: pairingCode, clientName: clientName))
            } else {
                send(.init(type: .pairingRequest, timestamp: 0, clientName: clientName))
            }

        case .waiting(let error):
            lastError = error.localizedDescription

        case .failed(let error):
            handleSocketError(error, for: stateConnection)

        case .cancelled:
            guard connection === stateConnection else { return }
            inputTransport.disconnect()
            activeInputState.removeAll()
            heartbeatTask?.cancel()
            heartbeatTask = nil
            stopRealtimeDatagram()
            lastSentEventUpdateTask?.cancel()
            lastSentEventUpdateTask = nil
            connection = nil
            controlURL = nil
            currentAuthToken = nil
            currentExpectedServerID = nil
            UIApplication.shared.isIdleTimerDisabled = false
            if case .failed = state {
                return
            }
            state = .disconnected
            scheduleSmartReconnectIfNeeded()

        default:
            break
        }
    }

    private func updateLastSentEvent(_ value: String, immediately: Bool = false) {
        pendingLastSentEvent = value

        if immediately {
            lastSentEventUpdateTask?.cancel()
            lastSentEventUpdateTask = nil
            lastSentEvent = value
            return
        }

        guard lastSentEventUpdateTask == nil else { return }
        lastSentEventUpdateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self, !Task.isCancelled else { return }
            self.lastSentEvent = self.pendingLastSentEvent
            self.lastSentEventUpdateTask = nil
        }
    }

    private func sendHeartbeat() {
        send(.init(type: .heartbeat))
        resendActiveInputs()
    }

    private func resendActiveInputs() {
        guard isConnected, !activeInputState.isEmpty else { return }

        for activePress in activeInputState.activePresses {
            _ = inputTransport.sendButton(
                activePress.button,
                state: .down,
                pressIdentifier: activePress.pressIdentifier
            )
        }
    }

    private func send(_ message: ControllerMessage, prefersRealtimeDatagram: Bool = false) {
        do {
            let data = try ControllerWireCodec.encode(message, using: encoder)
            if prefersRealtimeDatagram {
                sendRealtimeDataWithReliableMirror(data)
            } else {
                sendData(data)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func sendRealtimeDataWithReliableMirror(_ data: Data) {
        _ = sendRealtimeDatagramData(data)
        sendData(data, reportsSendErrors: false)
    }

    @discardableResult
    private func sendRealtimeDatagramData(_ data: Data) -> Bool {
        guard isRealtimeDatagramReady,
              let realtimeDatagramConnection
        else {
            return false
        }

        realtimeDatagramConnection.send(
            content: data,
            contentContext: .defaultMessage,
            isComplete: true,
            completion: .idempotent
        )
        return true
    }

    private func sendData(_ data: Data) {
        sendData(data, reportsSendErrors: true)
    }

    private func sendData(_ data: Data, reportsSendErrors: Bool) {
        guard let connection else { return }

        if reportsSendErrors {
            connection.send(content: data, contentContext: binaryMessageContext, isComplete: true, completion: .contentProcessed { [weak self, connection] error in
                guard let error else { return }
                Task { @MainActor in
                    self?.handleSocketError(error, for: connection)
                }
            })
        } else {
            connection.send(content: data, contentContext: binaryMessageContext, isComplete: true, completion: .idempotent)
        }
    }

    nonisolated private func receiveNext(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection else { return }

            if let error {
                Task { @MainActor in
                    self.handleSocketError(error, for: connection)
                }
                return
            }

            if let data, !data.isEmpty {
                Task { @MainActor in
                    self.handleIncoming(data, from: connection)
                }
            }

            self.receiveNext(on: connection)
        }
    }

    private func handleIncoming(_ data: Data, from messageConnection: NWConnection) {
        guard connection === messageConnection else { return }
        guard let decoded = try? ControllerWireCodec.decode(data, using: decoder) else { return }

        switch decoded.type {
        case .pairingChallenge:
            lastError = nil
            state = .pairingCodeRequired
            updateLastSentEvent(decoded.message ?? "pairing request accepted", immediately: true)

        case .pairingAccepted, .hello:
            applyGamepadProfileStateFromMac(decoded)
            finishPairing(
                on: messageConnection,
                message: decoded.message,
                realtimeToken: decoded.realtimeToken,
                authToken: decoded.authToken,
                serverID: decoded.serverID
            )

        case .gamepadCustomization:
            applyGamepadProfileStateFromMac(decoded)
            if decoded.gamepadCustomization != nil {
                updateLastSentEvent("keypad customization updated", immediately: true)
            }

        case .gamepadProfiles:
            applyGamepadProfileStateFromMac(decoded)
            updateLastSentEvent("keypad setups updated", immediately: true)

        case .pong:
            break

        case .error:
            lastError = decoded.message ?? "Mac helper returned an error"
            if decoded.message?.localizedCaseInsensitiveContains("Trusted pairing expired") == true {
                clearTrustedMacCredential()
            }
            state = .failed(lastError ?? "Unknown error")
            closeConnection(sendReleaseAll: false)

        case .gamepadProfileSelection, .gamepadDefaultProfile:
            break

        default:
            break
        }
    }

    private func finishPairing(
        on pairedConnection: NWConnection,
        message: String?,
        realtimeToken: String?,
        authToken: String?,
        serverID: String?
    ) {
        guard connection === pairedConnection else { return }
        guard state != .connected else { return }

        rememberTrustedMacIfAvailable(authToken: authToken, serverID: serverID)
        stopSmartDiscovery()
        reconnectTask?.cancel()
        reconnectTask = nil
        autoReconnectEnabled = trustedMacCredential != nil
        state = .connected
        lastError = nil
        smartConnectStatus = nil
        lastSentEvent = message ?? "Pairing complete"
        UIApplication.shared.isIdleTimerDisabled = true
        inputTransport.setReliableConnection(pairedConnection, resetSequence: true)
        startRealtimeDatagram(realtimeToken: realtimeToken)
        startHeartbeat()
    }

    private func rememberTrustedMacIfAvailable(authToken: String?, serverID: String?) {
        guard let controlURL else { return }
        let tokenToStore = authToken?.nilIfBlank ?? currentAuthToken?.nilIfBlank
        let serverIDToStore = serverID?.nilIfBlank ?? currentExpectedServerID?.nilIfBlank
        guard let tokenToStore, let serverIDToStore else { return }

        let macName = trustedMacCredential?.macName ?? controlURL.host ?? "PocketPad Mac"
        let credential = TrustedMacCredential(
            serverID: serverIDToStore,
            authToken: tokenToStore,
            macName: macName,
            lastURLString: controlURL.absoluteString,
            updatedAt: Date.currentMilliseconds
        )
        trustedMacCredential = credential
        Self.saveTrustedMacCredential(credential)
    }

    private func clearTrustedMacCredential() {
        trustedMacCredential = nil
        UserDefaults.standard.removeObject(forKey: Self.trustedMacCredentialDefaultsKey)
        autoReconnectEnabled = false
        smartConnectStatus = nil
    }

    private func startSmartDiscovery(for credential: TrustedMacCredential) {
        smartDiscovery?.stop()
        let discovery = SmartMacDiscovery(
            expectedServerID: credential.serverID,
            onStatus: { [weak self] status in
                self?.smartConnectStatus = status
            },
            onResolved: { [weak self] url, serviceName in
                guard let self else { return }
                var updatedCredential = credential
                updatedCredential.macName = serviceName.nilIfBlank ?? credential.macName
                updatedCredential.lastURLString = url.absoluteString
                updatedCredential.updatedAt = Date.currentMilliseconds
                self.trustedMacCredential = updatedCredential
                Self.saveTrustedMacCredential(updatedCredential)
                self.stopSmartDiscovery()
                self.smartConnectStatus = "Smart Connect: found \(updatedCredential.macName)"
                self.connectTrusted(to: url, credential: updatedCredential)
            }
        )
        smartDiscovery = discovery
        discovery.start()
    }

    private func stopSmartDiscovery() {
        smartDiscovery?.stop()
        smartDiscovery = nil
    }

    private func scheduleSmartReconnectIfNeeded() {
        guard autoReconnectEnabled, let credential = trustedMacCredential else { return }
        guard state != .connected, state != .pairingCodeRequired else { return }
        guard reconnectTask == nil else { return }

        smartConnectStatus = "Smart Connect: reconnecting…"
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.reconnectTask = nil
            self.startSmartConnect(using: credential)
        }
    }

    private func startSmartConnect(using credential: TrustedMacCredential) {
        trustedMacCredential = credential
        autoReconnectEnabled = true
        if let url = credential.lastURL {
            connectTrusted(to: url, credential: credential)
        }
        startSmartDiscovery(for: credential)
    }

    private func handleSocketError(_ error: Error, for failedConnection: NWConnection) {
        guard connection === failedConnection else { return }
        inputTransport.disconnect()
        activeInputState.removeAll()
        lastError = error.localizedDescription
        heartbeatTask?.cancel()
        heartbeatTask = nil
        stopRealtimeDatagram()
        lastSentEventUpdateTask?.cancel()
        lastSentEventUpdateTask = nil
        connection = nil
        controlURL = nil
        currentAuthToken = nil
        currentExpectedServerID = nil
        UIApplication.shared.isIdleTimerDisabled = false
        state = .failed(error.localizedDescription)
        scheduleSmartReconnectIfNeeded()
    }

    private func startRealtimeDatagram(realtimeToken: String?) {
        stopRealtimeDatagram()

        guard let realtimeToken,
              let controlURL,
              let host = controlURL.host,
              let port = realtimeDatagramPort(for: controlURL)
        else {
            return
        }

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        let datagramConnection = NWConnection(
            host: NWEndpoint.Host(host),
            port: port,
            using: parameters
        )
        realtimeDatagramConnection = datagramConnection
        isRealtimeDatagramReady = false
        inputTransport.setRealtimeDatagramConnection(datagramConnection, ready: false)

        datagramConnection.stateUpdateHandler = { [weak self, weak datagramConnection] state in
            guard let datagramConnection else { return }
            Task { @MainActor in
                self?.handleRealtimeDatagramState(
                    state,
                    connection: datagramConnection,
                    realtimeToken: realtimeToken
                )
            }
        }

        datagramConnection.start(queue: networkQueue)
    }

    private func handleRealtimeDatagramState(
        _ state: NWConnection.State,
        connection stateConnection: NWConnection,
        realtimeToken: String
    ) {
        guard realtimeDatagramConnection === stateConnection else { return }

        switch state {
        case .ready:
            isRealtimeDatagramReady = true
            inputTransport.setRealtimeDatagramReady(true, for: stateConnection)
            startRealtimeDatagramHandshake(realtimeToken: realtimeToken)

        case .failed, .cancelled:
            if realtimeDatagramConnection === stateConnection {
                realtimeDatagramConnection = nil
                isRealtimeDatagramReady = false
                inputTransport.clearRealtimeDatagramConnection(stateConnection)
            }
            realtimeDatagramHandshakeTask?.cancel()
            realtimeDatagramHandshakeTask = nil

        default:
            break
        }
    }

    private func startRealtimeDatagramHandshake(realtimeToken: String) {
        realtimeDatagramHandshakeTask?.cancel()
        realtimeDatagramHandshakeTask = Task { @MainActor [weak self] in
            for _ in 0..<5 {
                guard let self, !Task.isCancelled else { return }
                self.sendRealtimeDatagramHello(realtimeToken: realtimeToken)
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            self?.realtimeDatagramHandshakeTask = nil
        }
    }

    private func sendRealtimeDatagramHello(realtimeToken: String) {
        guard let data = try? ControllerWireCodec.encode(
            .init(
                type: .hello,
                timestamp: 0,
                clientName: UIDevice.current.name,
                realtimeToken: realtimeToken
            ),
            using: encoder
        ) else {
            return
        }

        _ = sendRealtimeDatagramData(data)
    }

    private func stopRealtimeDatagram() {
        realtimeDatagramHandshakeTask?.cancel()
        realtimeDatagramHandshakeTask = nil
        inputTransport.clearRealtimeDatagramConnection(realtimeDatagramConnection)
        realtimeDatagramConnection?.cancel()
        realtimeDatagramConnection = nil
        isRealtimeDatagramReady = false
    }

    private func realtimeDatagramPort(for url: URL) -> NWEndpoint.Port? {
        let portValue = url.port ?? Int(Self.defaultPort)
        guard let port = UInt16(exactly: portValue) else { return nil }
        return NWEndpoint.Port(rawValue: port)
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self?.sendHeartbeat()
            }
        }
    }

    private static func loadTrustedMacCredential() -> TrustedMacCredential? {
        guard let data = UserDefaults.standard.data(forKey: trustedMacCredentialDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(TrustedMacCredential.self, from: data)
    }

    private static func saveTrustedMacCredential(_ credential: TrustedMacCredential) {
        guard let data = try? JSONEncoder().encode(credential) else { return }
        UserDefaults.standard.set(data, forKey: trustedMacCredentialDefaultsKey)
    }

    private static func loadHasSavedKeypadSnapshot() -> Bool {
        UserDefaults.standard.bool(forKey: hasSavedKeypadSnapshotDefaultsKey)
    }

    private func markSavedKeypadSnapshotAvailable() {
        guard !hasSavedKeypadSnapshot else { return }
        hasSavedKeypadSnapshot = true
        UserDefaults.standard.set(true, forKey: Self.hasSavedKeypadSnapshotDefaultsKey)
    }

    private func makeURL(hostField: String, port: String) -> URL? {
        let trimmedHost = hostField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else { return nil }

        if trimmedHost.lowercased().hasPrefix("ws://") || trimmedHost.lowercased().hasPrefix("wss://") {
            return URL(string: trimmedHost)
        }

        let cleanPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalPort = cleanPort.isEmpty ? "8765" : cleanPort
        return URL(string: "ws://\(trimmedHost):\(finalPort)")
    }

}

private struct TrustedMacCredential: Codable, Equatable {
    var serverID: String
    var authToken: String
    var macName: String
    var lastURLString: String
    var updatedAt: Int64

    var lastURL: URL? {
        URL(string: lastURLString)
    }
}

private final class SmartMacDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private static let serviceType = "_pocketpad._tcp."

    private let expectedServerID: String
    private let onStatus: (String?) -> Void
    private let onResolved: (URL, String) -> Void
    private let browser = NetServiceBrowser()
    private var services: [NetService] = []

    init(
        expectedServerID: String,
        onStatus: @escaping (String?) -> Void,
        onResolved: @escaping (URL, String) -> Void
    ) {
        self.expectedServerID = expectedServerID
        self.onStatus = onStatus
        self.onResolved = onResolved
        super.init()
        browser.delegate = self
        browser.includesPeerToPeer = true
    }

    func start() {
        onStatus("Smart Connect: scanning nearby Macs…")
        browser.searchForServices(ofType: Self.serviceType, inDomain: "local.")
    }

    func stop() {
        browser.stop()
        services.forEach { $0.stop() }
        services.removeAll()
        onStatus(nil)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.includesPeerToPeer = true
        services.append(service)
        service.resolve(withTimeout: 4)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard serviceServerID(sender) == expectedServerID,
              sender.port > 0,
              let hostName = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
              !hostName.isEmpty
        else {
            return
        }

        var components = URLComponents()
        components.scheme = "ws"
        components.host = hostName
        components.port = sender.port
        guard let url = components.url else { return }

        let serviceName = serviceDisplayName(sender) ?? sender.name
        onResolved(url, serviceName)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        services.removeAll { $0 === sender }
    }

    private func serviceServerID(_ service: NetService) -> String? {
        guard let txtRecordData = service.txtRecordData() else { return nil }
        let record = NetService.dictionary(fromTXTRecord: txtRecordData)
        guard let data = record["id"] else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func serviceDisplayName(_ service: NetService) -> String? {
        guard let txtRecordData = service.txtRecordData() else { return nil }
        let record = NetService.dictionary(fromTXTRecord: txtRecordData)
        guard let data = record["name"] else { return nil }
        return String(data: data, encoding: .utf8)?.nilIfBlank
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
