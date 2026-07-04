import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// PocketPad's versioned JSON format for saving and sharing keypad setup layouts.
///
/// There is not a broadly adopted interchange format for PocketPad-style multitouch
/// keypad layouts, so exports use this app-owned schema identifier and version.
/// The macOS CLI may add Mac-only shortcut binding data next to these fields, while
/// iOS exports include the layout/profile state that the phone can actually use.
public struct PocketPadKeypadConfigurationExport: Codable, Equatable, Sendable {
    public static let schemaIdentifier = "com.codybontecou.pocketpad.keypad-configuration"
    public static let currentVersion = 1

    public var schema: String
    public var version: Int
    public var exportedAt: Int64
    public var profiles: [GamepadConfigurationProfile]
    public var activeProfileID: UUID?
    public var defaultProfileID: UUID?

    public init(
        schema: String = Self.schemaIdentifier,
        version: Int = Self.currentVersion,
        exportedAt: Int64 = Date.currentMilliseconds,
        profiles: [GamepadConfigurationProfile],
        activeProfileID: UUID?,
        defaultProfileID: UUID?
    ) {
        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: profiles,
            activeProfileID: activeProfileID,
            defaultProfileID: defaultProfileID
        )
        self.schema = schema
        self.version = version
        self.exportedAt = exportedAt
        self.profiles = state.profiles
        self.activeProfileID = state.activeProfileID
        self.defaultProfileID = state.defaultProfileID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decodeIfPresent(String.self, forKey: .schema) ?? Self.schemaIdentifier
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion

        guard schema == Self.schemaIdentifier else {
            throw DecodingError.dataCorruptedError(
                forKey: .schema,
                in: container,
                debugDescription: "Unsupported PocketPad keypad configuration schema: \(schema)"
            )
        }
        guard version >= 1 && version <= Self.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version,
                in: container,
                debugDescription: "Unsupported PocketPad keypad configuration version: \(version)"
            )
        }

        exportedAt = try container.decodeIfPresent(Int64.self, forKey: .exportedAt) ?? Date.currentMilliseconds
        let decodedProfiles = try container.decode([GamepadConfigurationProfile].self, forKey: .profiles)
        guard !decodedProfiles.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .profiles,
                in: container,
                debugDescription: "PocketPad keypad configuration export must contain at least one profile."
            )
        }
        let decodedActiveID = try container.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        let decodedDefaultID = try container.decodeIfPresent(UUID.self, forKey: .defaultProfileID)
        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: decodedProfiles,
            activeProfileID: decodedActiveID,
            defaultProfileID: decodedDefaultID
        )
        profiles = state.profiles
        activeProfileID = state.activeProfileID
        defaultProfileID = state.defaultProfileID
    }

    func normalizedProfileState(
        fallbackCustomization: GamepadCustomization = .defaultValue
    ) -> GamepadConfigurationProfilePersistence.LoadedState {
        GamepadConfigurationProfilePersistence.normalizedState(
            profiles: profiles,
            activeProfileID: activeProfileID,
            defaultProfileID: defaultProfileID,
            fallbackCustomization: fallbackCustomization
        )
    }

    public static func suggestedFilename(activeProfileName: String? = nil) -> String {
        let name = activeProfileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = name?.isEmpty == false ? name! : "keypads"
        let safeName = sanitizedFilenameComponent(baseName)
        return "PocketPad-\(safeName).json"
    }

    private static func sanitizedFilenameComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).union(.whitespaces)
        let replacement = UnicodeScalar("-")
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? scalar : replacement
        }
        let collapsedWhitespace = String(String.UnicodeScalarView(scalars))
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: "-")
        let collapsedDashes = collapsedWhitespace.replacingOccurrences(
            of: "-+",
            with: "-",
            options: String.CompareOptions.regularExpression
        )
        let trimmed = collapsedDashes.trimmingCharacters(in: CharacterSet(charactersIn: "-_. "))
        return trimmed.isEmpty ? "keypads" : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case schema
        case version
        case exportedAt
        case profiles
        case activeProfileID
        case defaultProfileID
    }
}

public struct PocketPadKeypadConfigurationJSONDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }
    public static var writableContentTypes: [UTType] { [.json] }

    public var export: PocketPadKeypadConfigurationExport

    public init(export: PocketPadKeypadConfigurationExport) {
        self.export = export
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        export = try JSONDecoder().decode(PocketPadKeypadConfigurationExport.self, from: data)
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(export)
        return FileWrapper(regularFileWithContents: data)
    }
}
