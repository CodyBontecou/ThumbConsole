import Foundation
import UIKit

@MainActor
final class ControllerClient: ObservableObject {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)

        var label: String {
            switch self {
            case .disconnected: "Disconnected"
            case .connecting: "Connecting…"
            case .connected: "Connected"
            case .failed(let message): "Failed: \(message)"
            }
        }
    }

    @Published private(set) var state: ConnectionState = .disconnected
    @Published private(set) var pressedButtons: Set<GameButton> = []
    @Published private(set) var lastSentEvent = "None"
    @Published private(set) var lastError: String?

    private var task: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    var isConnected: Bool {
        state == .connected
    }

    func connect(hostField: String, port: String, pairingCode: String) {
        disconnect(sendReleaseAll: false)

        guard let url = makeURL(hostField: hostField, port: port) else {
            state = .failed("Enter a valid ws:// host and port")
            return
        }

        state = .connecting
        lastError = nil

        let request = URLRequest(url: url, timeoutInterval: 3)
        let task = URLSession.shared.webSocketTask(with: request)
        self.task = task
        task.resume()

        state = .connected
        UIApplication.shared.isIdleTimerDisabled = true

        let deviceName = UIDevice.current.name
        send(.init(type: .hello, pairingCode: pairingCode.nilIfBlank, clientName: deviceName))
        startHeartbeat()
        receiveNext()
    }

    func disconnect(sendReleaseAll: Bool = true) {
        if sendReleaseAll {
            releaseAll()
        }
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        pressedButtons.removeAll()
        UIApplication.shared.isIdleTimerDisabled = false
        if case .failed = state {
            return
        }
        state = .disconnected
    }

    func setButton(_ button: GameButton, pressed: Bool) {
        guard isConnected else { return }

        if pressed {
            guard !pressedButtons.contains(button) else { return }
            pressedButtons.insert(button)
            sendButton(button, state: .down)
        } else {
            guard pressedButtons.contains(button) else { return }
            pressedButtons.remove(button)
            sendButton(button, state: .up)
        }
    }

    func releaseAll() {
        guard task != nil else { return }
        send(.init(type: .releaseAll))
        pressedButtons.removeAll()
        lastSentEvent = "release_all"
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

    private func sendButton(_ button: GameButton, state: ButtonPressState) {
        send(.init(type: .button, button: button, state: state))
        lastSentEvent = "\(button.rawValue) \(state.rawValue)"
    }

    private func sendHeartbeat() {
        send(.init(type: .heartbeat))
    }

    private func send(_ message: ControllerMessage) {
        guard let task else { return }

        do {
            let data = try encoder.encode(message)
            let text = String(decoding: data, as: UTF8.self)
            task.send(.string(text)) { [weak self, task] error in
                guard let error else { return }
                Task { @MainActor in
                    self?.handleSocketError(error, for: task)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func receiveNext() {
        guard let task else { return }
        task.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.task === task else { return }
                switch result {
                case .success(let message):
                    self.handleIncoming(message)
                    self.receiveNext()
                case .failure(let error):
                    self.handleSocketError(error, for: task)
                }
            }
        }
    }

    private func handleIncoming(_ message: URLSessionWebSocketTask.Message) {
        let data: Data?
        switch message {
        case .data(let incomingData):
            data = incomingData
        case .string(let text):
            data = text.data(using: .utf8)
        @unknown default:
            data = nil
        }

        guard let data else { return }
        guard let decoded = try? decoder.decode(ControllerMessage.self, from: data) else { return }

        switch decoded.type {
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

    private func handleSocketError(_ error: Error, for failedTask: URLSessionWebSocketTask) {
        guard task === failedTask else { return }
        lastError = error.localizedDescription
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task = nil
        pressedButtons.removeAll()
        UIApplication.shared.isIdleTimerDisabled = false
        state = .failed(error.localizedDescription)
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await self?.sendHeartbeat()
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
