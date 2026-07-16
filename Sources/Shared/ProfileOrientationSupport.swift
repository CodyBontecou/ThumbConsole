import Foundation

public enum GamepadProfileOrientationCLIRequest: Equatable, Sendable {
    case get(profile: String?, json: Bool)
    case set(GamepadProfileOrientationPreference, profile: String?)
}

public enum GamepadProfileOrientationCLIParseError: LocalizedError, Equatable, Sendable {
    case missingSubcommand
    case missingPreference
    case missingProfile
    case unexpectedArgument(String)
    case unknownPreference(String)

    public var errorDescription: String? {
        switch self {
        case .missingSubcommand:
            "Missing orientation subcommand. Use get, set, copy, or arrange."
        case .missingPreference:
            "Missing orientation preference. Use automatic, portrait, or landscape."
        case .missingProfile:
            "Missing profile after --profile."
        case .unexpectedArgument(let argument):
            "Unexpected orientation argument: \(argument)"
        case .unknownPreference(let value):
            "Unknown orientation preference: \(value). Use automatic, portrait, or landscape."
        }
    }
}

public enum GamepadProfileOrientationCLIParser {
    public static func parse(_ arguments: [String]) throws -> GamepadProfileOrientationCLIRequest {
        guard let subcommand = arguments.first else {
            throw GamepadProfileOrientationCLIParseError.missingSubcommand
        }

        var profile: String?
        var json = false
        var positionals: [String] = []
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--profile":
                index += 1
                guard index < arguments.count else {
                    throw GamepadProfileOrientationCLIParseError.missingProfile
                }
                profile = arguments[index]
            case "--json":
                json = true
            default:
                guard !argument.hasPrefix("-") else {
                    throw GamepadProfileOrientationCLIParseError.unexpectedArgument(argument)
                }
                positionals.append(argument)
            }
            index += 1
        }

        switch subcommand.lowercased() {
        case "get", "show":
            guard positionals.isEmpty else {
                throw GamepadProfileOrientationCLIParseError.unexpectedArgument(positionals[0])
            }
            return .get(profile: profile, json: json)
        case "set":
            guard let value = positionals.first else {
                throw GamepadProfileOrientationCLIParseError.missingPreference
            }
            guard positionals.count == 1, !json else {
                throw GamepadProfileOrientationCLIParseError.unexpectedArgument(positionals.dropFirst().first ?? "--json")
            }
            return .set(try parsePreference(value), profile: profile)
        default:
            throw GamepadProfileOrientationCLIParseError.unexpectedArgument(subcommand)
        }
    }

    public static func parsePreference(_ value: String) throws -> GamepadProfileOrientationPreference {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "automatic", "auto", "follow-device", "follow_device": .automatic
        case "portrait": .portrait
        case "landscape": .landscape
        default: throw GamepadProfileOrientationCLIParseError.unknownPreference(value)
        }
    }
}

public enum ControllerProfileOrientationMutationRoute: Equatable, Sendable {
    case accept(profileID: UUID, preference: GamepadProfileOrientationPreference)
    case rejectUnauthenticated
    case rejectUnsupportedCapability
    case rejectMalformed
}

public enum ControllerProfileOrientationMutationRouter {
    public static func route(
        message: ControllerMessage,
        isAuthenticated: Bool,
        advertisedCapabilities: Set<ControllerCapability>
    ) -> ControllerProfileOrientationMutationRoute {
        guard isAuthenticated else { return .rejectUnauthenticated }
        guard advertisedCapabilities.contains(.gamepadProfileOrientationPreferenceMutation) else {
            return .rejectUnsupportedCapability
        }
        guard message.type == .gamepadProfileOrientationPreferenceMutation,
              let profileID = message.gamepadProfileID,
              let preference = message.gamepadProfileOrientationPreferenceMutation
        else {
            return .rejectMalformed
        }
        return .accept(profileID: profileID, preference: preference)
    }
}

public enum GamepadSupportedOrientationSet: Equatable, Sendable {
    case automatic
    case portrait
    case landscape

    public init(_ preference: GamepadProfileOrientationPreference) {
        switch preference {
        case .automatic: self = .automatic
        case .portrait: self = .portrait
        case .landscape: self = .landscape
        }
    }
}
