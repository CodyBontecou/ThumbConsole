import Foundation
import Network
import UIKit

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

    private let networkQueue = DispatchQueue(label: "PocketPad.iOS.Network", qos: .userInteractive)
    private var connection: NWConnection?
    private var controlURL: URL?
    private var realtimeDatagramConnection: NWConnection?
    private var isRealtimeDatagramReady = false
    private var heartbeatTask: Task<Void, Never>?
    private var realtimeDatagramHandshakeTask: Task<Void, Never>?
    private var lastSentEventUpdateTask: Task<Void, Never>?
    private var pendingLastSentEvent = "None"
    private var buttonSequenceNumber: UInt64 = 0
    private let binaryMessageContext = NWConnection.ContentContext(
        identifier: "PocketPadMessage",
        metadata: [NWProtocolWebSocket.Metadata(opcode: .binary)]
    )
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private static let liveInputStatusUpdatesEnabled = false
    private static let defaultPort: UInt16 = 8765

    var isConnected: Bool {
        state == .connected
    }

    var isAwaitingPairingCode: Bool {
        state == .pairingCodeRequired
    }

    func connect(hostField: String, port: String, pairingCode: String) {
        disconnect(sendReleaseAll: false)

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
        buttonSequenceNumber = 0

        let deviceName = UIDevice.current.name
        let pairingCode = pairingCode.nilIfBlank

        connection.stateUpdateHandler = { [weak self, weak connection] connectionState in
            guard let connection else { return }
            Task { @MainActor in
                self?.handleConnectionState(
                    connectionState,
                    connection: connection,
                    pairingCode: pairingCode,
                    clientName: deviceName
                )
            }
        }

        connection.start(queue: networkQueue)
    }

    func disconnect(sendReleaseAll: Bool = true) {
        if sendReleaseAll {
            releaseAll()
        }
        heartbeatTask?.cancel()
        heartbeatTask = nil
        stopRealtimeDatagram()
        lastSentEventUpdateTask?.cancel()
        lastSentEventUpdateTask = nil
        connection?.cancel()
        connection = nil
        controlURL = nil
        UIApplication.shared.isIdleTimerDisabled = false
        if case .failed = state {
            return
        }
        state = .disconnected
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
        sendButton(button, state: pressed ? .down : .up, pressIdentifier: pressIdentifier)
    }

    func releaseAll() {
        guard connection != nil else { return }
        send(.init(type: .releaseAll, timestamp: 0), prefersRealtimeDatagram: true)
        updateLastSentEvent("release_all", immediately: true)
    }

    func appWillBecomeInactive() {
        // Losing focus briefly (Control Center, alerts, app switcher, etc.) should not
        // tear down the controller socket. Release held buttons for safety, then keep
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
        clientName: String
    ) {
        guard connection === stateConnection else { return }

        switch connectionState {
        case .ready:
            guard state != .connected else { return }
            lastSentEvent = "Socket ready"
            receiveNext(on: stateConnection)

            if let pairingCode {
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
            heartbeatTask?.cancel()
            heartbeatTask = nil
            stopRealtimeDatagram()
            lastSentEventUpdateTask?.cancel()
            lastSentEventUpdateTask = nil
            connection = nil
            controlURL = nil
            UIApplication.shared.isIdleTimerDisabled = false
            if case .failed = state {
                return
            }
            state = .disconnected

        default:
            break
        }
    }

    private func sendButton(
        _ button: GameButton,
        state: ButtonPressState,
        pressIdentifier: UInt64?
    ) {
        let sequenceNumber = nextButtonSequenceNumber()
        let data = ControllerWireCodec.encodeButton(
            button,
            state: state,
            sequenceNumber: sequenceNumber,
            pressIdentifier: pressIdentifier
        )
        sendRealtimeDataWithReliableMirror(data)
        if Self.liveInputStatusUpdatesEnabled {
            updateLastSentEvent("\(button.rawValue) \(state.rawValue)")
        }
    }

    private func nextButtonSequenceNumber() -> UInt64 {
        if buttonSequenceNumber >= ControllerWireCodec.maximumButtonSequenceNumber {
            buttonSequenceNumber = 1
        } else {
            buttonSequenceNumber += 1
        }
        return buttonSequenceNumber
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
            finishPairing(
                on: messageConnection,
                message: decoded.message,
                realtimeToken: decoded.realtimeToken
            )

        case .pong:
            break

        case .error:
            lastError = decoded.message ?? "Mac helper returned an error"
            state = .failed(lastError ?? "Unknown error")
            disconnect(sendReleaseAll: false)

        default:
            break
        }
    }

    private func finishPairing(
        on pairedConnection: NWConnection,
        message: String?,
        realtimeToken: String?
    ) {
        guard connection === pairedConnection else { return }
        guard state != .connected else { return }

        state = .connected
        lastError = nil
        lastSentEvent = message ?? "Pairing complete"
        UIApplication.shared.isIdleTimerDisabled = true
        startRealtimeDatagram(realtimeToken: realtimeToken)
        startHeartbeat()
    }

    private func handleSocketError(_ error: Error, for failedConnection: NWConnection) {
        guard connection === failedConnection else { return }
        lastError = error.localizedDescription
        heartbeatTask?.cancel()
        heartbeatTask = nil
        stopRealtimeDatagram()
        lastSentEventUpdateTask?.cancel()
        lastSentEventUpdateTask = nil
        connection = nil
        controlURL = nil
        UIApplication.shared.isIdleTimerDisabled = false
        state = .failed(error.localizedDescription)
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
            startRealtimeDatagramHandshake(realtimeToken: realtimeToken)

        case .failed, .cancelled:
            if realtimeDatagramConnection === stateConnection {
                realtimeDatagramConnection = nil
                isRealtimeDatagramReady = false
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

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
