import CoreGraphics
import Foundation
import Network
import SwiftUI

final class MacControllerServer: ObservableObject {
    @Published private(set) var statusText = "Stopped"
    @Published private(set) var isRunning = false
    @Published private(set) var isClientConnected = false
    @Published private(set) var localURLs: [String] = []
    @Published private(set) var pairingCode: String = MacControllerServer.generatePairingCode()
    @Published private(set) var clientName: String = "No client"
    @Published private(set) var lastHeartbeat: Date?
    @Published private(set) var lastReceivedEvent: String = "None"
    @Published private(set) var estimatedLatencyMS: Int?
    @Published private(set) var pressedButtons: Set<GameButton> = []
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var keyBindings: [GameButton: CGKeyCode] = MacControllerServer.loadKeyBindings()

    let port: UInt16 = 8765

    var pairingPayload: String {
        let payload = PairingPayload(urls: localURLs, pairingCode: pairingCode)
        guard let data = try? JSONEncoder().encode(payload) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private let networkQueue = DispatchQueue(label: "PocketPad.WebSocketServer")
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let injector = KeyboardInjector()
    private let debugLogURL = URL(fileURLWithPath: "/tmp/pocketpad-mac-events.log")
    private static let keyBindingsDefaultsKey = "PocketPadMac.keyBindings.v1"
    private var listener: NWListener?
    private var connection: NWConnection?
    private var backgroundActivity: NSObjectProtocol?
    private var heartbeatTimer: Timer?
    private var heartbeatTimedOut = false
    private var activeKeyCodes: [GameButton: CGKeyCode] = [:]
    private var heldKeyCounts: [CGKeyCode: Int] = [:]

    init() {
        refreshAccessibilityStatus()
        localURLs = Self.localIPv4Addresses().map { "ws://\($0):\(port)" }
    }

    deinit {
        stop()
    }

    func start() {
        guard !isRunning else { return }

        let parameters = NWParameters.tcp
        let websocketOptions = NWProtocolWebSocket.Options()
        websocketOptions.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(websocketOptions, at: 0)

        do {
            let nwPort = NWEndpoint.Port(rawValue: port)!
            let listener = try NWListener(using: parameters, on: nwPort)
            self.listener = listener

            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async { self?.handleListenerState(state) }
            }

            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }

            listener.start(queue: networkQueue)
            beginBackgroundActivity()
            isRunning = true
            statusText = "Starting on port \(port)…"
            logDebug("server starting port=\(port)")
            startHeartbeatTimer()
        } catch {
            statusText = "Failed to start: \(error.localizedDescription)"
            logDebug("server failed error=\(error.localizedDescription)")
        }
    }

    func stop() {
        releaseAll(reason: "Server stopped")
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
        statusText = "Stopped"
        clientName = "No client"
        logDebug("server stopped")
    }

    func refreshAccessibilityStatus() {
        accessibilityTrusted = injector.isAccessibilityTrusted
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
        releaseIfPressed(button)
        keyBindings[button] = keyCode
        saveKeyBindings()
        lastReceivedEvent = "Mapped \(button.displayName) to \(MacVirtualKey.displayName(for: keyCode))"
        logDebug("key_binding button=\(button.rawValue) keyCode=\(keyCode)")
    }

    func resetKeyBinding(_ button: GameButton) {
        guard let defaultKeyCode = HollowKnightKeyMap.defaultKeyCode(for: button) else { return }
        setKeyBinding(defaultKeyCode, for: button)
    }

    func resetAllKeyBindings() {
        releaseAll(reason: "Reset all key bindings")
        keyBindings = HollowKnightKeyMap.defaultKeyCodes
        saveKeyBindings()
        lastReceivedEvent = "Reset all key bindings"
        logDebug("key_bindings_reset_all")
    }

    func sendTestDown(_ button: GameButton) {
        handleButton(button, state: .down, source: "Local test")
    }

    func sendTestUp(_ button: GameButton) {
        handleButton(button, state: .up, source: "Local test")
    }

    func releaseAll(reason: String = "Release all") {
        guard !pressedButtons.isEmpty || !heldKeyCounts.isEmpty else { return }
        for keyCode in heldKeyCounts.keys {
            injector.keyUp(keyCode)
        }
        heldKeyCounts.removeAll()
        activeKeyCodes.removeAll()
        pressedButtons.removeAll()
        lastReceivedEvent = reason
        logDebug("release_all reason=\(reason) pressed=[]")
    }

    private func accept(_ newConnection: NWConnection) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let existing = self.connection {
                self.releaseAll(reason: "Replaced by new iPhone connection")
                existing.cancel()
            }
            self.connection = newConnection
            self.heartbeatTimedOut = false
            self.isClientConnected = true
            self.clientName = "Connected iPhone"
            self.lastHeartbeat = Date()
            self.statusText = "Client connected"
            self.logDebug("client accepted")
        }

        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let newConnection else { return }
            DispatchQueue.main.async { self?.handleConnectionState(state, connection: newConnection) }
        }

        receiveNext(on: newConnection)
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
                DispatchQueue.main.async { self.handle(data, from: connection) }
            }

            self.receiveNext(on: connection)
        }
    }

    private func handle(_ data: Data, from connection: NWConnection) {
        guard self.connection === connection else { return }
        do {
            let message = try decoder.decode(ControllerMessage.self, from: data)
            handle(message, from: connection)
        } catch {
            lastReceivedEvent = "Invalid JSON: \(error.localizedDescription)"
            logDebug("invalid_json error=\(error.localizedDescription)")
        }
    }

    private func handle(_ message: ControllerMessage, from connection: NWConnection) {
        guard self.connection === connection else { return }
        noteClientActivity()

        switch message.type {
        case .hello:
            if let code = message.pairingCode, code != pairingCode {
                send(.init(type: .error, message: "Wrong pairing code"), on: connection)
                connection.cancel()
                releaseAll(reason: "Rejected wrong pairing code")
                return
            }
            clientName = message.clientName ?? "Connected iPhone"
            isClientConnected = true
            lastHeartbeat = Date()
            lastReceivedEvent = "Hello from \(clientName)"
            logDebug("hello client=\(clientName)")

        case .button:
            guard let button = message.button, let state = message.state else {
                lastReceivedEvent = "Ignored malformed button event"
                return
            }
            lastHeartbeat = Date()
            handleButton(button, state: state, source: "iPhone")

        case .releaseAll:
            lastHeartbeat = Date()
            releaseAll(reason: "release_all from iPhone")

        case .heartbeat:
            lastHeartbeat = Date()
            if let latency = oneWayLatencyMilliseconds(from: message.timestamp) {
                estimatedLatencyMS = latency
            }

        case .ping:
            lastHeartbeat = Date()
            send(.init(type: .pong, timestamp: message.timestamp), on: connection)

        case .pong:
            if let latency = roundTripLatencyMilliseconds(from: message.timestamp) {
                estimatedLatencyMS = latency
            }

        case .error:
            lastReceivedEvent = message.message ?? "Client error"
        }
    }

    private func handleButton(_ button: GameButton, state: ButtonPressState, source: String) {
        guard let keyCode = keyBindings[button] else { return }

        switch state {
        case .down:
            guard !pressedButtons.contains(button) else { return }
            pressedButtons.insert(button)
            activeKeyCodes[button] = keyCode
            pressKey(keyCode)
            lastReceivedEvent = "\(source): \(button.rawValue) down (\(MacVirtualKey.displayName(for: keyCode)))"
            logDebug("button source=\(source) button=\(button.rawValue) state=down keyCode=\(keyCode) pressed=\(pressedButtons.map(\.rawValue).sorted())")

        case .up:
            guard pressedButtons.contains(button) else { return }
            pressedButtons.remove(button)
            let releasedKeyCode = activeKeyCodes.removeValue(forKey: button) ?? keyCode
            releaseKey(releasedKeyCode)
            lastReceivedEvent = "\(source): \(button.rawValue) up (\(MacVirtualKey.displayName(for: releasedKeyCode)))"
            logDebug("button source=\(source) button=\(button.rawValue) state=up keyCode=\(releasedKeyCode) pressed=\(pressedButtons.map(\.rawValue).sorted())")
        }
    }

    private func releaseIfPressed(_ button: GameButton) {
        guard pressedButtons.contains(button) else { return }
        pressedButtons.remove(button)
        if let activeKeyCode = activeKeyCodes.removeValue(forKey: button) {
            releaseKey(activeKeyCode)
        }
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
        guard let data = try? encoder.encode(message) else { return }
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "PocketPadMessage", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            localURLs = Self.localIPv4Addresses().map { "ws://\($0):\(port)" }
            statusText = "Listening on port \(port)"
            logDebug("listener ready urls=\(localURLs)")
        case .failed(let error):
            statusText = "Listener failed: \(error.localizedDescription)"
            stop()
        case .cancelled:
            statusText = "Stopped"
        default:
            break
        }
    }

    private func handleConnectionState(_ state: NWConnection.State, connection stateConnection: NWConnection) {
        guard connection === stateConnection else { return }

        switch state {
        case .ready:
            isClientConnected = true
            statusText = "Client connected"
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
        releaseAll(reason: reason)
        connection?.cancel()
        connection = nil
        heartbeatTimedOut = false
        isClientConnected = false
        clientName = "No client"
        lastHeartbeat = nil
        logDebug("client disconnected reason=\(reason)")
    }

    private func startHeartbeatTimer() {
        heartbeatTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.checkHeartbeatTimeout()
            self?.refreshAccessibilityStatus()
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

    private func logDebug(_ line: String) {
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
