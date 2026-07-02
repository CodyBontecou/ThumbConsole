import Foundation

public enum GameButton: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case up
    case down
    case left
    case right
    case jump
    case attack
    case dash
    case focus
    case map
    case pause

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        case .jump: "Jump"
        case .attack: "Attack"
        case .dash: "Dash"
        case .focus: "Focus"
        case .map: "Map"
        case .pause: "Pause"
        }
    }
}

public enum ButtonPressState: String, Codable, Sendable {
    case down
    case up
}

public enum ControllerMessageType: String, Codable, Sendable {
    case hello
    case button
    case releaseAll = "release_all"
    case heartbeat
    case ping
    case pong
    case error
}

public struct ControllerMessage: Codable, Sendable {
    public var type: ControllerMessageType
    public var button: GameButton?
    public var state: ButtonPressState?
    public var timestamp: Int64
    public var pairingCode: String?
    public var clientName: String?
    public var message: String?

    public init(
        type: ControllerMessageType,
        button: GameButton? = nil,
        state: ButtonPressState? = nil,
        timestamp: Int64 = Date.currentMilliseconds,
        pairingCode: String? = nil,
        clientName: String? = nil,
        message: String? = nil
    ) {
        self.type = type
        self.button = button
        self.state = state
        self.timestamp = timestamp
        self.pairingCode = pairingCode
        self.clientName = clientName
        self.message = message
    }
}

public extension Date {
    static var currentMilliseconds: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
