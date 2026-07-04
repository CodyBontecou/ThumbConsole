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
    case custom1
    case custom2
    case custom3
    case custom4
    case custom5
    case custom6
    case custom7
    case custom8

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        case .jump: "Action 1"
        case .attack: "Action 2"
        case .dash: "Action 3"
        case .focus: "Action 4"
        case .map: "Utility 1"
        case .pause: "Utility 2"
        case .custom1: "Custom Key 1"
        case .custom2: "Custom Key 2"
        case .custom3: "Custom Key 3"
        case .custom4: "Custom Key 4"
        case .custom5: "Custom Key 5"
        case .custom6: "Custom Key 6"
        case .custom7: "Custom Key 7"
        case .custom8: "Custom Key 8"
        }
    }

    static var builtInControls: [GameButton] {
        [.up, .down, .left, .right, .jump, .attack, .dash, .focus, .map, .pause]
    }

    static var customSlots: [GameButton] {
        [.custom1, .custom2, .custom3, .custom4, .custom5, .custom6, .custom7, .custom8]
    }
}

public enum PocketPadMacIPC {
    public static let appDefaultsDomain = "com.codybontecou.PocketPadMac"
    public static let commandNotificationName = "com.codybontecou.PocketPadMac.cliCommand"
    public static let commandDataKey = "commandData"
    public static let runtimeStatusDefaultsKey = "PocketPadMac.runtimeStatus.v1"
}

public enum PocketPadMacCLICommand: String, Codable, Sendable {
    case publishStatus
    case start
    case stop
    case restart
    case cancelPairing
    case refreshAccessibility
    case promptAccessibility
    case openAccessibilitySettings
    case releaseAll
    case testDown
    case testUp
}

public struct ControllerClientDeviceInsets: Codable, Equatable, Sendable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double

    public init(top: Double, leading: Double, bottom: Double, trailing: Double) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

public struct ControllerClientDeviceInfo: Codable, Equatable, Sendable {
    public var deviceName: String
    public var modelIdentifier: String?
    public var systemName: String
    public var systemVersion: String
    public var screenBoundsWidth: Double
    public var screenBoundsHeight: Double
    public var nativeBoundsWidth: Double
    public var nativeBoundsHeight: Double
    public var scale: Double
    public var nativeScale: Double
    public var safeAreaInsets: ControllerClientDeviceInsets?
    public var interfaceOrientation: String?

    public init(
        deviceName: String,
        modelIdentifier: String?,
        systemName: String,
        systemVersion: String,
        screenBoundsWidth: Double,
        screenBoundsHeight: Double,
        nativeBoundsWidth: Double,
        nativeBoundsHeight: Double,
        scale: Double,
        nativeScale: Double,
        safeAreaInsets: ControllerClientDeviceInsets? = nil,
        interfaceOrientation: String? = nil
    ) {
        self.deviceName = deviceName
        self.modelIdentifier = modelIdentifier
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.screenBoundsWidth = screenBoundsWidth
        self.screenBoundsHeight = screenBoundsHeight
        self.nativeBoundsWidth = nativeBoundsWidth
        self.nativeBoundsHeight = nativeBoundsHeight
        self.scale = scale
        self.nativeScale = nativeScale
        self.safeAreaInsets = safeAreaInsets
        self.interfaceOrientation = interfaceOrientation
    }
}

public struct PocketPadMacCLICommandPayload: Codable, Sendable {
    public var command: PocketPadMacCLICommand
    public var button: GameButton?
    public var reason: String?

    public init(
        command: PocketPadMacCLICommand,
        button: GameButton? = nil,
        reason: String? = nil
    ) {
        self.command = command
        self.button = button
        self.reason = reason
    }
}

public struct PocketPadMacRuntimeStatus: Codable, Sendable {
    public var updatedAt: Int64
    public var statusText: String
    public var isRunning: Bool
    public var isClientConnected: Bool
    public var localURLs: [String]
    public var pairingCode: String
    public var isPairingPending: Bool
    public var pendingPairingClientName: String?
    public var clientName: String
    public var lastHeartbeatMilliseconds: Int64?
    public var lastReceivedEvent: String
    public var estimatedLatencyMS: Int?
    public var pressedButtons: [GameButton]
    public var missedButtonFrames: Int
    public var ignoredButtonEdges: Int
    public var recoveredButtonEdges: Int
    public var accessibilityTrusted: Bool
    public var port: UInt16
    public var activeGamepadProfileID: UUID
    public var defaultGamepadProfileID: UUID
    public var clientDeviceInfo: ControllerClientDeviceInfo?

    public init(
        updatedAt: Int64,
        statusText: String,
        isRunning: Bool,
        isClientConnected: Bool,
        localURLs: [String],
        pairingCode: String,
        isPairingPending: Bool,
        pendingPairingClientName: String?,
        clientName: String,
        lastHeartbeatMilliseconds: Int64?,
        lastReceivedEvent: String,
        estimatedLatencyMS: Int?,
        pressedButtons: [GameButton],
        missedButtonFrames: Int,
        ignoredButtonEdges: Int,
        recoveredButtonEdges: Int,
        accessibilityTrusted: Bool,
        port: UInt16,
        activeGamepadProfileID: UUID,
        defaultGamepadProfileID: UUID,
        clientDeviceInfo: ControllerClientDeviceInfo? = nil
    ) {
        self.updatedAt = updatedAt
        self.statusText = statusText
        self.isRunning = isRunning
        self.isClientConnected = isClientConnected
        self.localURLs = localURLs
        self.pairingCode = pairingCode
        self.isPairingPending = isPairingPending
        self.pendingPairingClientName = pendingPairingClientName
        self.clientName = clientName
        self.lastHeartbeatMilliseconds = lastHeartbeatMilliseconds
        self.lastReceivedEvent = lastReceivedEvent
        self.estimatedLatencyMS = estimatedLatencyMS
        self.pressedButtons = pressedButtons
        self.missedButtonFrames = missedButtonFrames
        self.ignoredButtonEdges = ignoredButtonEdges
        self.recoveredButtonEdges = recoveredButtonEdges
        self.accessibilityTrusted = accessibilityTrusted
        self.port = port
        self.activeGamepadProfileID = activeGamepadProfileID
        self.defaultGamepadProfileID = defaultGamepadProfileID
        self.clientDeviceInfo = clientDeviceInfo
    }
}

public enum ButtonPressState: String, Codable, Sendable {
    case down
    case up
}

public enum ControllerMessageType: String, Codable, Sendable {
    case hello
    case pairingRequest = "pairing_request"
    case pairingChallenge = "pairing_challenge"
    case pairingAccepted = "pairing_accepted"
    case button
    case releaseAll = "release_all"
    case heartbeat
    case ping
    case pong
    case gamepadCustomization = "gamepad_customization"
    case gamepadProfiles = "gamepad_profiles"
    case gamepadProfileSelection = "gamepad_profile_selection"
    case gamepadDefaultProfile = "gamepad_default_profile"
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
    public var realtimeToken: String?
    public var authToken: String?
    public var serverID: String?
    public var gamepadCustomization: GamepadCustomization?
    public var gamepadProfiles: [GamepadConfigurationProfile]?
    public var gamepadProfileID: UUID?
    public var defaultGamepadProfileID: UUID?
    public var clientDeviceInfo: ControllerClientDeviceInfo?

    public init(
        type: ControllerMessageType,
        button: GameButton? = nil,
        state: ButtonPressState? = nil,
        timestamp: Int64 = Date.currentMilliseconds,
        pairingCode: String? = nil,
        clientName: String? = nil,
        message: String? = nil,
        realtimeToken: String? = nil,
        authToken: String? = nil,
        serverID: String? = nil,
        gamepadCustomization: GamepadCustomization? = nil,
        gamepadProfiles: [GamepadConfigurationProfile]? = nil,
        gamepadProfileID: UUID? = nil,
        defaultGamepadProfileID: UUID? = nil,
        clientDeviceInfo: ControllerClientDeviceInfo? = nil
    ) {
        self.type = type
        self.button = button
        self.state = state
        self.timestamp = timestamp
        self.pairingCode = pairingCode
        self.clientName = clientName
        self.message = message
        self.realtimeToken = realtimeToken
        self.authToken = authToken
        self.serverID = serverID
        self.gamepadCustomization = gamepadCustomization
        self.gamepadProfiles = gamepadProfiles
        self.gamepadProfileID = gamepadProfileID
        self.defaultGamepadProfileID = defaultGamepadProfileID
        self.clientDeviceInfo = clientDeviceInfo
    }
}

struct ButtonSequenceInspection: Equatable {
    var hasSequence = false
    var missedFrameBeforeButton = false
    var expectedSequence: UInt64?
    var receivedSequence: UInt64?
    var missedFrameCount: UInt64 = 0
    var totalMissedFrameCount = 0
    var isOutOfOrderOrReset = false
}

struct ButtonSequenceTracker {
    private var nextExpectedButtonSequence: UInt64?
    private var acceptsNextSequenceAsBaseline = false
    private(set) var totalMissedFrameCount = 0

    var nextExpectedSequenceNumber: UInt64? {
        nextExpectedButtonSequence
    }

    var isAcceptingNextSequenceAsBaseline: Bool {
        acceptsNextSequenceAsBaseline
    }

    mutating func inspect(_ message: ControllerMessage) -> ButtonSequenceInspection {
        guard let sequenceNumber = ControllerWireCodec.buttonSequenceNumber(from: message) else {
            return ButtonSequenceInspection()
        }

        var inspection = ButtonSequenceInspection(
            hasSequence: true,
            receivedSequence: sequenceNumber,
            totalMissedFrameCount: totalMissedFrameCount
        )

        if acceptsNextSequenceAsBaseline {
            acceptsNextSequenceAsBaseline = false
        } else if let expectedSequence = nextExpectedButtonSequence, sequenceNumber != expectedSequence {
            inspection.expectedSequence = expectedSequence
            if sequenceNumber > expectedSequence {
                inspection.missedFrameBeforeButton = true
                inspection.missedFrameCount = sequenceNumber - expectedSequence
                inspection.totalMissedFrameCount = recordMissedFrames(inspection.missedFrameCount)
            } else {
                inspection.isOutOfOrderOrReset = true
                return inspection
            }
        } else if nextExpectedButtonSequence == nil, sequenceNumber > 1 {
            inspection.expectedSequence = 1
            inspection.missedFrameBeforeButton = true
            inspection.missedFrameCount = sequenceNumber - 1
            inspection.totalMissedFrameCount = recordMissedFrames(inspection.missedFrameCount)
        }

        if sequenceNumber >= ControllerWireCodec.maximumButtonSequenceNumber {
            nextExpectedButtonSequence = 1
        } else {
            nextExpectedButtonSequence = sequenceNumber + 1
        }

        return inspection
    }

    mutating func reset() {
        nextExpectedButtonSequence = nil
        acceptsNextSequenceAsBaseline = false
        totalMissedFrameCount = 0
    }

    mutating func resetAcceptingNextSequenceAsBaseline() {
        nextExpectedButtonSequence = nil
        acceptsNextSequenceAsBaseline = true
        totalMissedFrameCount = 0
    }

    @discardableResult
    private mutating func recordMissedFrames(_ count: UInt64) -> Int {
        let clampedMissedFrameCount = Int(min(count, UInt64(Int.max)))
        if Int.max - totalMissedFrameCount <= clampedMissedFrameCount {
            totalMissedFrameCount = Int.max
        } else {
            totalMissedFrameCount += clampedMissedFrameCount
        }
        return totalMissedFrameCount
    }
}

public enum ControllerWireCodec {
    private static let magic: [UInt8] = [0x50, 0x50] // "PP"
    private static let version: UInt8 = 1
    private static let emptyField: UInt8 = UInt8.max
    private static let compactMessageSize = 14
    private static let buttonSequenceMarker: UInt64 = UInt64(1) << 63
    private static let buttonSequenceBitCount: UInt64 = 48
    private static let buttonSequenceMask: UInt64 = (UInt64(1) << buttonSequenceBitCount) - 1
    private static let buttonPressIdentifierShift = buttonSequenceBitCount
    private static let buttonPressIdentifierMask: UInt64 = (UInt64(1) << 15) - 1
    public static let maximumButtonSequenceNumber = buttonSequenceMask
    public static let maximumButtonPressIdentifier = buttonPressIdentifierMask
    private static let buttonDownFrames = GameButton.allCases.map {
        compactData(
            typeCode: ControllerMessageType.button.compactWireCode!,
            timestamp: 0,
            buttonCode: $0.compactWireCode,
            stateCode: ButtonPressState.down.compactWireCode
        )
    }
    private static let buttonUpFrames = GameButton.allCases.map {
        compactData(
            typeCode: ControllerMessageType.button.compactWireCode!,
            timestamp: 0,
            buttonCode: $0.compactWireCode,
            stateCode: ButtonPressState.up.compactWireCode
        )
    }

    public static func encode(_ message: ControllerMessage, using encoder: JSONEncoder) throws -> Data {
        if let compactData = compactData(for: message) {
            return compactData
        }
        return try encoder.encode(message)
    }

    public static func decode(_ data: Data, using decoder: JSONDecoder) throws -> ControllerMessage {
        if let compactMessage = compactMessage(from: data) {
            return compactMessage
        }
        return try decoder.decode(ControllerMessage.self, from: data)
    }

    public static func encodeButton(_ button: GameButton, state: ButtonPressState) -> Data {
        switch state {
        case .down: buttonDownFrames[button.compactFrameIndex]
        case .up: buttonUpFrames[button.compactFrameIndex]
        }
    }

    public static func encodeButton(
        _ button: GameButton,
        state: ButtonPressState,
        sequenceNumber: UInt64,
        pressIdentifier: UInt64? = nil
    ) -> Data {
        compactData(
            typeCode: ControllerMessageType.button.compactWireCode!,
            timestamp: buttonSequenceTimestamp(
                for: sequenceNumber,
                pressIdentifier: pressIdentifier
            ),
            buttonCode: button.compactWireCode,
            stateCode: state.compactWireCode
        )
    }

    public static func buttonSequenceNumber(from message: ControllerMessage) -> UInt64? {
        guard message.type == .button else { return nil }

        let timestampBits = UInt64(bitPattern: message.timestamp)
        guard timestampBits & buttonSequenceMarker == buttonSequenceMarker else { return nil }

        let sequenceNumber = timestampBits & buttonSequenceMask
        return sequenceNumber == 0 ? nil : sequenceNumber
    }

    public static func buttonPressIdentifier(from message: ControllerMessage) -> UInt64? {
        guard message.type == .button else { return nil }

        let timestampBits = UInt64(bitPattern: message.timestamp)
        guard timestampBits & buttonSequenceMarker == buttonSequenceMarker else { return nil }

        let pressIdentifier = (timestampBits >> buttonPressIdentifierShift) & buttonPressIdentifierMask
        return pressIdentifier == 0 ? nil : pressIdentifier
    }

    private static func compactData(for message: ControllerMessage) -> Data? {
        guard message.pairingCode == nil,
              message.clientName == nil,
              message.message == nil,
              message.realtimeToken == nil,
              message.authToken == nil,
              message.serverID == nil,
              message.gamepadCustomization == nil,
              message.gamepadProfiles == nil,
              message.gamepadProfileID == nil,
              message.defaultGamepadProfileID == nil,
              let typeCode = message.type.compactWireCode
        else {
            return nil
        }

        if message.type == .button, (message.button == nil || message.state == nil) {
            return nil
        }

        return compactData(
            typeCode: typeCode,
            timestamp: message.timestamp,
            buttonCode: message.button?.compactWireCode,
            stateCode: message.state?.compactWireCode
        )
    }

    private static func compactData(
        typeCode: UInt8,
        timestamp: Int64,
        buttonCode: UInt8?,
        stateCode: UInt8?
    ) -> Data {
        var data = Data(count: compactMessageSize)
        data.withUnsafeMutableBytes { rawBuffer in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress else { return }

            bytes[0] = magic[0]
            bytes[1] = magic[1]
            bytes[2] = version
            bytes[3] = typeCode

            let timestampBits = UInt64(bitPattern: timestamp)
            for offset in 0..<8 {
                bytes[4 + offset] = UInt8(truncatingIfNeeded: timestampBits >> UInt64(offset * 8))
            }

            bytes[12] = buttonCode ?? emptyField
            bytes[13] = stateCode ?? emptyField
        }
        return data
    }

    private static func buttonSequenceTimestamp(
        for sequenceNumber: UInt64,
        pressIdentifier: UInt64?
    ) -> Int64 {
        let boundedSequenceNumber = min(max(sequenceNumber, 1), maximumButtonSequenceNumber)
        let boundedPressIdentifier = min(pressIdentifier ?? 0, maximumButtonPressIdentifier)
        let pressIdentifierBits = boundedPressIdentifier << buttonPressIdentifierShift
        return Int64(bitPattern: buttonSequenceMarker | pressIdentifierBits | boundedSequenceNumber)
    }

    private static func compactMessage(from data: Data) -> ControllerMessage? {
        guard data.count == compactMessageSize else { return nil }

        return data.withUnsafeBytes { rawBuffer -> ControllerMessage? in
            guard let bytes = rawBuffer.bindMemory(to: UInt8.self).baseAddress,
                  bytes[0] == magic[0],
                  bytes[1] == magic[1],
                  bytes[2] == version,
                  let type = ControllerMessageType(compactWireCode: bytes[3])
            else {
                return nil
            }

            var timestampBits: UInt64 = 0
            for offset in 0..<8 {
                timestampBits |= UInt64(bytes[4 + offset]) << UInt64(offset * 8)
            }

            let button = bytes[12] == emptyField ? nil : GameButton(compactWireCode: bytes[12])
            let state = bytes[13] == emptyField ? nil : ButtonPressState(compactWireCode: bytes[13])

            if type == .button, (button == nil || state == nil) {
                return nil
            }

            return ControllerMessage(
                type: type,
                button: button,
                state: state,
                timestamp: Int64(bitPattern: timestampBits)
            )
        }
    }
}

private extension ControllerMessageType {
    var compactWireCode: UInt8? {
        switch self {
        case .button: 1
        case .releaseAll: 2
        case .heartbeat: 3
        case .ping: 4
        case .pong: 5
        case .hello, .pairingRequest, .pairingChallenge, .pairingAccepted, .gamepadCustomization, .gamepadProfiles, .gamepadProfileSelection, .gamepadDefaultProfile, .error: nil
        }
    }

    init?(compactWireCode: UInt8) {
        switch compactWireCode {
        case 1: self = .button
        case 2: self = .releaseAll
        case 3: self = .heartbeat
        case 4: self = .ping
        case 5: self = .pong
        default: return nil
        }
    }
}

private extension GameButton {
    var compactFrameIndex: Int {
        Int(compactWireCode - 1)
    }

    var compactWireCode: UInt8 {
        switch self {
        case .up: 1
        case .down: 2
        case .left: 3
        case .right: 4
        case .jump: 5
        case .attack: 6
        case .dash: 7
        case .focus: 8
        case .map: 9
        case .pause: 10
        case .custom1: 11
        case .custom2: 12
        case .custom3: 13
        case .custom4: 14
        case .custom5: 15
        case .custom6: 16
        case .custom7: 17
        case .custom8: 18
        }
    }

    init?(compactWireCode: UInt8) {
        switch compactWireCode {
        case 1: self = .up
        case 2: self = .down
        case 3: self = .left
        case 4: self = .right
        case 5: self = .jump
        case 6: self = .attack
        case 7: self = .dash
        case 8: self = .focus
        case 9: self = .map
        case 10: self = .pause
        case 11: self = .custom1
        case 12: self = .custom2
        case 13: self = .custom3
        case 14: self = .custom4
        case 15: self = .custom5
        case 16: self = .custom6
        case 17: self = .custom7
        case 18: self = .custom8
        default: return nil
        }
    }
}

private extension ButtonPressState {
    var compactWireCode: UInt8 {
        switch self {
        case .down: 1
        case .up: 2
        }
    }

    init?(compactWireCode: UInt8) {
        switch compactWireCode {
        case 1: self = .down
        case 2: self = .up
        default: return nil
        }
    }
}

public extension Date {
    static var currentMilliseconds: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
