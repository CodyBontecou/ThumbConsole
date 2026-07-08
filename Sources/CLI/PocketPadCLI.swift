import AppKit
import Foundation
import SwiftUI

@main
struct PocketPadCLI {
    private static let appDefaultsDomain = PocketPadMacIPC.appDefaultsDomain
    private static let keyBindingsDefaultsKey = "PocketPadMac.keyBindings.v2"
    private static let profileKeyBindingsDefaultsKey = "PocketPadMac.profileKeyBindings.v1"
    private static let outputBindingsDefaultsKey = "PocketPadMac.outputBindings.v1"
    private static let profileOutputBindingsDefaultsKey = "PocketPadMac.profileOutputBindings.v1"
    private static let profileStoreChangedNotificationName = Notification.Name("com.codybontecou.PocketPadMac.profileStoreChanged")
    private static let notificationProfileStateDataKey = "profileStateData"
    private static let notificationActiveCustomizationDataKey = "activeCustomizationData"
    private static let notificationKeyBindingsDataKey = "keyBindingsData"
    private static let notificationProfileKeyBindingsDataKey = "profileKeyBindingsData"
    private static let notificationOutputBindingsDataKey = "outputBindingsData"
    private static let notificationProfileOutputBindingsDataKey = "profileOutputBindingsData"
    private static let defaultEditorCanvasSize = GamepadEditorDeviceCatalog.defaultFrame.screenRect.size
    private static let portraitEditorCanvasSize = GamepadEditorDeviceFrame(spec: GamepadEditorDeviceCatalog.specs[0], orientation: .portrait).screenRect.size
    private static let trackpadOptionNames = [
        "--sensitivity", "--cursor-sensitivity", "--pointer-sensitivity",
        "--scroll-sensitivity", "--tap-to-click", "--two-finger-scroll",
        "--natural-scrolling", "--natural-scroll"
    ]
    private static let triggerOptionNames = [
        "--target", "--trigger", "--orientation", "--dead-zone", "--deadzone",
        "--digital", "--digital-button", "--digital-threshold"
    ]
    private static let joystickOptionNames = [
        "--up", "--down", "--left", "--right", "--analog", "--analog-stick", "--stick",
        "--digital-directions", "--send-digital-directions", "--sends-digital-directions",
        "--no-digital-directions", "--invert-x", "--invert-y", "--snap-to-cardinal", "--snap-cardinal",
        "--joystick-style", "--stick-style", "--thumbstick", "--classic-joystick"
    ]
    private static let elementOutputOptionNames = [
        "--keyboard", "--key", "--sequence", "--gamepad-button", "--gamepad",
        "--clear-output", "--clear-keyboard", "--clear-gamepad"
    ]

    private struct StoredProfileState: Codable {
        var profiles: [GamepadConfigurationProfile]
        var activeProfileID: UUID?
        var defaultProfileID: UUID?
    }

    private struct ProfileStore {
        var profiles: [GamepadConfigurationProfile]
        var activeProfileID: UUID
        var defaultProfileID: UUID
        var profileKeyBindings: [String: [String: MacKeyBinding]]
        var profileOutputBindings: [String: [String: MacControlOutputBinding]]
    }

    private struct GenerateOptions {
        var gameName: String?
        var specPath: String?
        var install = true
        var select = true
        var makeDefault = true
        var printJSON = false
        var validateLayout = true
        var strictLayoutValidation = false
        var previewOutputPath: String?
    }

    private struct InstallOptions {
        var select = true
        var makeDefault = true
    }

    private struct ProfileExportEnvelope: Codable {
        var schema: String = PocketPadKeypadConfigurationExport.schemaIdentifier
        var version: Int = PocketPadKeypadConfigurationExport.currentVersion
        var exportedAt: Int64 = Date.currentMilliseconds
        var profiles: [GamepadConfigurationProfile]
        var activeProfileID: UUID?
        var defaultProfileID: UUID?
        var profileKeyBindings: [String: [String: MacKeyBinding]]
        var profileOutputBindings: [String: [String: MacControlOutputBinding]]

        init(
            profiles: [GamepadConfigurationProfile],
            activeProfileID: UUID?,
            defaultProfileID: UUID?,
            profileKeyBindings: [String: [String: MacKeyBinding]] = [:],
            profileOutputBindings: [String: [String: MacControlOutputBinding]] = [:]
        ) {
            let state = GamepadConfigurationProfilePersistence.normalizedState(
                profiles: profiles,
                activeProfileID: activeProfileID,
                defaultProfileID: defaultProfileID
            )
            self.profiles = state.profiles
            self.activeProfileID = state.activeProfileID
            self.defaultProfileID = state.defaultProfileID
            self.profileKeyBindings = profileKeyBindings
            self.profileOutputBindings = profileOutputBindings
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schema = try container.decodeIfPresent(String.self, forKey: .schema) ?? PocketPadKeypadConfigurationExport.schemaIdentifier
            version = try container.decodeIfPresent(Int.self, forKey: .version) ?? PocketPadKeypadConfigurationExport.currentVersion
            guard schema == PocketPadKeypadConfigurationExport.schemaIdentifier else {
                throw DecodingError.dataCorruptedError(
                    forKey: .schema,
                    in: container,
                    debugDescription: "Unsupported PocketPad keypad configuration schema: \(schema)"
                )
            }
            guard version >= 1 && version <= PocketPadKeypadConfigurationExport.currentVersion else {
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
            profileKeyBindings = try container.decodeIfPresent([String: [String: MacKeyBinding]].self, forKey: .profileKeyBindings) ?? [:]
            profileOutputBindings = try container.decodeIfPresent([String: [String: MacControlOutputBinding]].self, forKey: .profileOutputBindings) ?? [:]
        }
    }

    private struct ThemeSummary: Codable {
        var id: String
        var name: String
        var description: String
    }

    private struct ElementSummary: Codable {
        var id: String
        var kind: String
        var mappedButton: GameButton
        var label: String
        var isHidden: Bool
        var isLocationLocked: Bool
        var layout: GamepadButtonCustomization
        var joystickMapping: GamepadJoystickMapping?
        var joystickOutputSettings: GamepadJoystickOutputSettings?
        var triggerSettings: GamepadTriggerSettings?
        var trackpadSettings: GamepadTrackpadSettings?
    }

    private struct DeviceFrameSummary: Codable {
        var id: String
        var device: String
        var orientation: String
        var screenPoints: String
        var nativePixels: String
        var scale: Double
        var nativeScale: Double
        var frameStyle: String
        var modelIdentifiers: [String]
    }

    private enum ElementTarget: Equatable {
        case builtin(GameButton)
        case custom(UUID)
    }

    static func main() {
        do {
            try run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch CLIError.helpRequested {
            printHelp()
        } catch CLIError.validationFailed(let message) {
            fputs("pocketpad: \(message)\n", stderr)
            exit(1)
        } catch {
            fputs("pocketpad: \(error.localizedDescription)\n", stderr)
            fputs("Run `pocketpad --help` for usage.\n", stderr)
            exit(1)
        }
    }

    private static func run(arguments: [String]) throws {
        guard let first = arguments.first else {
            throw CLIError.helpRequested
        }

        let rest = Array(arguments.dropFirst())
        switch first {
        case "--help", "-h", "help":
            throw CLIError.helpRequested
        case "generate":
            try generate(arguments: rest)
        case "install-spec", "import":
            guard let path = rest.first else { throw CLIError.message("Missing spec path") }
            try generate(arguments: ["--spec", path] + Array(rest.dropFirst()))
        case "profile", "profiles":
            try profile(arguments: rest)
        case "template", "templates":
            try template(arguments: rest)
        case "theme", "themes":
            try theme(arguments: rest)
        case "binding", "bindings", "shortcut", "shortcuts":
            try binding(arguments: rest)
        case "output", "outputs":
            try output(arguments: rest)
        case "customization", "customize", "layout":
            try customization(arguments: rest)
        case "device", "devices", "frame", "frames":
            try device(arguments: rest)
        case "element", "control", "controls":
            try element(arguments: rest)
        case "style", "styles":
            try style(arguments: rest)
        case "layer", "layers":
            try layer(arguments: rest)
        case "group", "groups":
            try group(arguments: rest)
        case "asset", "assets":
            try asset(arguments: rest)
        case "status", "diagnostics":
            try printRuntimeStatus(json: rest.contains("--json"))
        case "latency":
            try latency(arguments: rest)
        case "server":
            try server(arguments: rest)
        case "pairing":
            try pairing(arguments: rest)
        case "accessibility":
            try accessibility(arguments: rest)
        case "release-all":
            postRuntimeCommand(.releaseAll, reason: "Release all from CLI")
            print("Sent release-all to PocketPad Mac.")
        case "test":
            try test(arguments: rest)
        case "app":
            try app(arguments: rest)
        default:
            try generate(arguments: arguments)
        }
    }

    // MARK: - Generate / install

    private static func generate(arguments: [String]) throws {
        let options = try parseGenerateOptions(arguments)
        let generated: GeneratedGameKeypadProfile
        if let specPath = options.specPath {
            let spec = try loadAgentSpec(path: specPath)
            generated = GameKeypadGenerator.generate(from: spec, requestedGameName: options.gameName)
        } else if let gameName = options.gameName, let builtInProfile = GameKeypadGenerator.generate(for: gameName) {
            generated = builtInProfile
        } else if let gameName = options.gameName {
            throw CLIError.message("No built-in template for \"\(gameName)\". Have your agent write a JSON keypad spec and run `pocketpad generate --spec <file>`.")
        } else {
            throw CLIError.message("Missing game name or --spec <file>")
        }
        let macBindings = try resolvedMacBindings(for: generated)
        let layoutReport = generated.profile.customization.layoutQualityReport(profileName: generated.resolvedGameName)
        if options.validateLayout {
            try enforceLayoutQuality(layoutReport, strict: options.strictLayoutValidation, quiet: options.printJSON)
        }
        if let previewOutputPath = options.previewOutputPath {
#if os(macOS)
            try GamepadLayoutPreviewRenderer.writePNG(
                customization: generated.profile.customization,
                profileName: generated.resolvedGameName,
                outputURL: URL(fileURLWithPath: previewOutputPath)
            )
            if !options.printJSON {
                print("Wrote layout preview to \(previewOutputPath).")
            }
#endif
        }

        if options.printJSON {
            try printJSON(generated)
        }

        if options.install {
            try install(profile: generated.profile, macBindings: macBindings, select: options.select, makeDefault: options.makeDefault)
            printSummary(generated: generated, macBindings: macBindings, installed: true, selected: options.select)
        } else if !options.printJSON {
            printSummary(generated: generated, macBindings: macBindings, installed: false, selected: false)
        }
    }

    private static func parseGenerateOptions(_ arguments: [String]) throws -> GenerateOptions {
        var gameNameParts: [String] = []
        var options = GenerateOptions()

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--dry-run", "--no-install":
                options.install = false
            case "--spec", "--from-spec":
                index += 1
                guard index < arguments.count else { throw CLIError.message("Missing path after \(argument)") }
                options.specPath = arguments[index]
            case "--stdin":
                options.specPath = "-"
            case "--select":
                options.select = true
            case "--no-select":
                options.select = false
                options.makeDefault = false
            case "--default":
                options.makeDefault = true
            case "--no-default":
                options.makeDefault = false
            case "--json":
                options.printJSON = true
            case "--skip-layout-validation", "--no-layout-validation":
                options.validateLayout = false
            case "--strict-layout", "--strict-layout-validation":
                options.strictLayoutValidation = true
            case "--layout-preview", "--preview-output":
                index += 1
                guard index < arguments.count else { throw CLIError.message("Missing path after \(argument)") }
                options.previewOutputPath = arguments[index]
            case "--help", "-h":
                throw CLIError.helpRequested
            default:
                if argument.hasPrefix("-") { throw CLIError.message("Unknown option: \(argument)") }
                gameNameParts.append(argument)
            }
            index += 1
        }

        let gameName = gameNameParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if !gameName.isEmpty { options.gameName = gameName }
        if options.gameName == nil && options.specPath == nil {
            throw CLIError.message("Missing game name or --spec <file>")
        }
        return options
    }

    private static func loadAgentSpec(path: String) throws -> AgentKeypadSpec {
        let data: Data
        if path == "-" {
            data = FileHandle.standardInput.readDataToEndOfFile()
        } else {
            data = try Data(contentsOf: URL(fileURLWithPath: path))
        }
        return try JSONDecoder().decode(AgentKeypadSpec.self, from: data)
    }

    private static func install(
        profile inputProfile: GamepadConfigurationProfile,
        macBindings: [GameButton: MacKeyBinding],
        select: Bool,
        makeDefault: Bool
    ) throws {
        var store = loadStore()
        var profile = inputProfile.normalized

        if let existingIndex = store.profiles.firstIndex(where: { sameProfileName($0.name, profile.name) }) {
            profile.id = store.profiles[existingIndex].id
            profile.updatedAt = Date.currentMilliseconds
            store.profiles[existingIndex] = profile
        } else {
            store.profiles.append(profile)
        }

        if select { store.activeProfileID = profile.id }
        if makeDefault { store.defaultProfileID = profile.id }
        store.profileKeyBindings[profile.id.uuidString] = rawBindings(macBindings)
        try persistStore(store)
    }

    // MARK: - Profiles

    private static func profile(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing profile subcommand") }
        let rest = Array(arguments.dropFirst())

        switch subcommand {
        case "list", "ls":
            let json = rest.contains("--json")
            let showIDs = rest.contains("--ids") || json
            let store = loadStore()
            if json {
                try printJSON(ProfileExportEnvelope(profiles: store.profiles, activeProfileID: store.activeProfileID, defaultProfileID: store.defaultProfileID, profileKeyBindings: store.profileKeyBindings, profileOutputBindings: store.profileOutputBindings))
            } else {
                for profile in store.profiles {
                    let activeMarker = profile.id == store.activeProfileID ? "*" : " "
                    let defaultMarker = profile.id == store.defaultProfileID ? " default" : ""
                    let idText = showIDs ? " [\(profile.id.uuidString)]" : ""
                    print("\(activeMarker) \(profile.name)\(defaultMarker)\(idText)")
                }
            }

        case "show":
            let json = rest.contains("--json")
            let target = firstPositional(in: rest)
            let store = loadStore()
            let profile = try resolveProfile(target, in: store)
            if json {
                let bindings = store.profileKeyBindings[profile.id.uuidString] ?? rawBindings(DefaultKeypadKeyMap.defaultBindings)
                let keyboardBindings = decodedBindings(bindings) ?? DefaultKeypadKeyMap.defaultBindings
                let storedOutputs = decodedOutputBindings(store.profileOutputBindings[profile.id.uuidString]) ?? outputBindings(from: keyboardBindings)
                let outputs = effectiveOutputBindings(for: profile.outputMode, keyBindings: keyboardBindings, customOutputBindings: storedOutputs)
                try printJSON(ProfileExportEnvelope(profiles: [profile], activeProfileID: profile.id, defaultProfileID: store.defaultProfileID == profile.id ? profile.id : nil, profileKeyBindings: [profile.id.uuidString: bindings], profileOutputBindings: [profile.id.uuidString: rawOutputBindings(outputs)]))
            } else {
                printProfile(profile, store: store)
            }

        case "select", "use":
            guard let target = firstPositional(in: rest) else { throw CLIError.message("Missing profile name or id") }
            var store = loadStore()
            let profile = try resolveProfile(target, in: store)
            store.activeProfileID = profile.id
            try persistStore(store)
            print("Selected profile \"\(profile.name)\".")

        case "default", "set-default":
            guard let target = firstPositional(in: rest) else { throw CLIError.message("Missing profile name or id") }
            var store = loadStore()
            let profile = try resolveProfile(target, in: store)
            store.defaultProfileID = profile.id
            try persistStore(store)
            print("Made \"\(profile.name)\" the default profile.")

        case "rename":
            guard rest.count >= 2 else { throw CLIError.message("Usage: pocketpad profile rename <profile> <new name>") }
            var store = loadStore()
            let target = rest[0]
            let newName = rest.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !newName.isEmpty else { throw CLIError.message("New profile name cannot be empty") }
            let index = try resolveProfileIndex(target, in: store)
            store.profiles[index].name = newName
            store.profiles[index].updatedAt = Date.currentMilliseconds
            try persistStore(store)
            print("Renamed profile to \"\(newName)\".")

        case "duplicate", "copy":
            var mutableRest = rest
            let target = mutableRest.first.map { $0.hasPrefix("-") ? nil : $0 } ?? nil
            if target != nil { mutableRest.removeFirst() }
            let name = optionValue("--name", in: mutableRest) ?? mutableRest.filter { !$0.hasPrefix("-") }.joined(separator: " ")
            var store = loadStore()
            let source = try resolveProfile(target, in: store)
            let duplicateName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(source.name) Copy" : name
            var duplicate = source.normalized
            duplicate.id = UUID()
            duplicate.name = duplicateName
            duplicate.updatedAt = Date.currentMilliseconds
            store.profiles.append(duplicate)
            store.activeProfileID = duplicate.id
            store.profileKeyBindings[duplicate.id.uuidString] = store.profileKeyBindings[source.id.uuidString] ?? rawBindings(DefaultKeypadKeyMap.defaultBindings)
            store.profileOutputBindings[duplicate.id.uuidString] = store.profileOutputBindings[source.id.uuidString] ?? rawOutputBindings(DefaultMacControlOutputMap.defaultBindings)
            try persistStore(store)
            print("Duplicated \"\(source.name)\" as \"\(duplicate.name)\".")

        case "delete", "rm":
            let targets = positionals(in: rest)
            guard !targets.isEmpty else { throw CLIError.message("Missing profile name or id") }
            var store = loadStore()
            let indexes = try resolveProfileIndexes(targets, in: store)
            let removedEveryProfile = indexes.count == store.profiles.count
            let removedIndexSet = Set(indexes)
            let removedProfiles = indexes.map { store.profiles[$0] }
            let removedIDs = Set(removedProfiles.map(\.id))
            let firstRemovedIndex = indexes.min() ?? 0
            let removedActiveIndex = indexes.first { store.profiles[$0].id == store.activeProfileID } ?? firstRemovedIndex
            store.profiles.removeAll { removedIDs.contains($0.id) }
            for removed in removedProfiles {
                store.profileKeyBindings[removed.id.uuidString] = nil
                store.profileOutputBindings[removed.id.uuidString] = nil
            }
            if removedEveryProfile {
                let replacementProfile = GamepadConfigurationProfile(
                    name: "Setup 1",
                    customization: GamepadCustomization.blankCanvas
                )
                store.profiles = [replacementProfile]
                store.activeProfileID = replacementProfile.id
                store.defaultProfileID = replacementProfile.id
                store.profileKeyBindings[replacementProfile.id.uuidString] = rawBindings(DefaultKeypadKeyMap.defaultBindings)
                store.profileOutputBindings[replacementProfile.id.uuidString] = rawOutputBindings(outputBindings(from: DefaultKeypadKeyMap.defaultBindings))
            } else {
                if removedIDs.contains(store.activeProfileID) {
                    store.activeProfileID = store.profiles[min(removedActiveIndex, store.profiles.count - 1)].id
                }
                if removedIDs.contains(store.defaultProfileID) { store.defaultProfileID = store.activeProfileID }
            }
            try persistStore(store)
            if removedProfiles.count == 1, let removed = removedProfiles.first {
                let suffix = removedEveryProfile ? " Created a new blank setup." : ""
                print("Deleted profile \"\(removed.name)\".\(suffix)")
            } else {
                let suffix = removedEveryProfile ? " Created a new blank setup." : ""
                print("Deleted \(removedIndexSet.count) profiles: \(removedProfiles.map(\.name).joined(separator: ", ")).\(suffix)")
            }

        case "move", "reorder":
            try moveProfiles(arguments: rest)

        case "reset":
            let target = firstPositional(in: rest)
            var store = loadStore()
            let index = try resolveProfileIndex(target, in: store)
            store.profiles[index].customization = GamepadCustomization.defaultValue
            store.profiles[index].landscapeCustomization = nil
            store.profiles[index].portraitCustomization = nil
            store.profiles[index].updatedAt = Date.currentMilliseconds
            try persistStore(store)
            print("Reset profile \"\(store.profiles[index].name)\" to the default keypad layout.")

        case "new", "create":
            try createProfile(arguments: rest)

        case "export":
            try exportProfiles(arguments: rest)

        case "import":
            try importProfiles(arguments: rest)

        case "attach-app", "attach-application", "app", "application":
            try attachApplicationToProfile(arguments: rest)

        case "detach-app", "detach-application", "clear-app", "remove-app":
            try detachApplicationFromProfile(arguments: rest)

        case "launch", "open-app":
            try launchAttachedApplication(arguments: rest)

        default:
            throw CLIError.message("Unknown profile subcommand: \(subcommand)")
        }
    }

    private static func moveProfiles(arguments: [String]) throws {
        let targets = positionals(in: arguments)
        guard !targets.isEmpty else {
            throw CLIError.message("Usage: pocketpad profile move <profile> [profile...] --to INDEX|--before PROFILE|--after PROFILE")
        }

        let toText = optionValue("--to", in: arguments)
        let beforeText = optionValue("--before", in: arguments)
        let afterText = optionValue("--after", in: arguments)
        let destinationCount = [toText, beforeText, afterText].compactMap { $0 }.count
        guard destinationCount == 1 else {
            throw CLIError.message("profile move needs exactly one of --to, --before, or --after")
        }

        var store = loadStore()
        let movingIndexes = try resolveProfileIndexes(targets, in: store)
        let movingProfiles = movingIndexes.map { store.profiles[$0] }
        let movingIDs = Set(movingProfiles.map(\.id))
        var remainingProfiles = store.profiles.filter { !movingIDs.contains($0.id) }

        let insertionIndex: Int
        let destinationDescription: String
        if let toText {
            let toIndex = try parseInteger(toText)
            guard toIndex >= 0 && toIndex <= remainingProfiles.count else {
                throw CLIError.message("Profile move index must be between 0 and \(remainingProfiles.count)")
            }
            insertionIndex = toIndex
            destinationDescription = "to index \(toIndex)"
        } else if let beforeText {
            let beforeProfile = try resolveProfile(beforeText, in: store)
            guard !movingIDs.contains(beforeProfile.id) else { throw CLIError.message("Destination profile cannot be one of the profiles being moved") }
            insertionIndex = remainingProfiles.firstIndex(where: { $0.id == beforeProfile.id }) ?? 0
            destinationDescription = "before \"\(beforeProfile.name)\""
        } else if let afterText {
            let afterProfile = try resolveProfile(afterText, in: store)
            guard !movingIDs.contains(afterProfile.id) else { throw CLIError.message("Destination profile cannot be one of the profiles being moved") }
            insertionIndex = (remainingProfiles.firstIndex(where: { $0.id == afterProfile.id }) ?? (remainingProfiles.count - 1)) + 1
            destinationDescription = "after \"\(afterProfile.name)\""
        } else {
            throw CLIError.message("profile move needs --to, --before, or --after")
        }

        remainingProfiles.insert(contentsOf: movingProfiles, at: insertionIndex)
        store.profiles = remainingProfiles
        try persistStore(store)

        if movingProfiles.count == 1, let moved = movingProfiles.first {
            print("Moved profile \"\(moved.name)\" \(destinationDescription).")
        } else {
            print("Moved \(movingProfiles.count) profiles \(destinationDescription): \(movingProfiles.map(\.name).joined(separator: ", ")).")
        }
    }

    private static func createProfile(arguments: [String]) throws {
        var nameParts: [String] = []
        var templateName: String?
        var fromProfile: String?
        var select = true
        var makeDefault = false
        var blank = false

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--template":
                index += 1
                guard index < arguments.count else { throw CLIError.message("Missing template name") }
                templateName = arguments[index]
            case "--from":
                index += 1
                guard index < arguments.count else { throw CLIError.message("Missing source profile") }
                fromProfile = arguments[index]
            case "--blank":
                blank = true
            case "--select":
                select = true
            case "--no-select":
                select = false
            case "--default":
                makeDefault = true
            case "--no-default":
                makeDefault = false
            default:
                if argument.hasPrefix("-") { throw CLIError.message("Unknown option: \(argument)") }
                nameParts.append(argument)
            }
            index += 1
        }

        var store = loadStore()
        let requestedName = nameParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let baseCustomization: GamepadCustomization
        let baseOutputMode: GamepadProfileOutputMode
        let defaultName: String
        var baseBindings = decodedBindings(store.profileKeyBindings[store.activeProfileID.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings
        var baseOutputBindings: [String: MacControlOutputBinding]?

        if let templateName {
            let template = try resolveTemplate(templateName)
            let profile = template.makeProfile()
            baseCustomization = profile.customization
            baseOutputMode = profile.outputMode
            defaultName = profile.name
        } else if let fromProfile {
            let profile = try resolveProfile(fromProfile, in: store)
            baseCustomization = profile.customization
            baseOutputMode = profile.outputMode
            defaultName = "\(profile.name) Copy"
            baseBindings = decodedBindings(store.profileKeyBindings[profile.id.uuidString]) ?? baseBindings
            baseOutputBindings = store.profileOutputBindings[profile.id.uuidString]
        } else if blank {
            baseCustomization = .blankCanvas
            baseOutputMode = .keyboard
            defaultName = "Blank Setup"
        } else {
            baseCustomization = .defaultValue
            baseOutputMode = .keyboard
            defaultName = "Setup \(store.profiles.count + 1)"
        }

        let profile = GamepadConfigurationProfile(name: requestedName.isEmpty ? defaultName : requestedName, customization: baseCustomization, outputMode: baseOutputMode)
        store.profiles.append(profile)
        store.profileKeyBindings[profile.id.uuidString] = rawBindings(baseBindings)
        if let baseOutputBindings {
            store.profileOutputBindings[profile.id.uuidString] = baseOutputBindings
        }
        if select { store.activeProfileID = profile.id }
        if makeDefault { store.defaultProfileID = profile.id }
        try persistStore(store)
        print("Created profile \"\(profile.name)\".")
    }

    private static func exportProfiles(arguments: [String]) throws {
        let store = loadStore()
        let outputPath = optionValue("--output", in: arguments) ?? optionValue("-o", in: arguments)
        let exportAll = arguments.contains("--all")
        let target = firstPositional(in: arguments)

        let profiles: [GamepadConfigurationProfile]
        let activeID: UUID?
        let defaultID: UUID?
        if exportAll || target == nil {
            profiles = store.profiles
            activeID = store.activeProfileID
            defaultID = store.defaultProfileID
        } else {
            let profile = try resolveProfile(target, in: store)
            profiles = [profile]
            activeID = profile.id
            defaultID = store.defaultProfileID == profile.id ? profile.id : nil
        }
        let validIDs = Set(profiles.map { $0.id.uuidString })
        let bindings = store.profileKeyBindings.filter { validIDs.contains($0.key) }
        let envelope = ProfileExportEnvelope(profiles: profiles, activeProfileID: activeID, defaultProfileID: defaultID, profileKeyBindings: bindings, profileOutputBindings: store.profileOutputBindings.filter { validIDs.contains($0.key) })
        try writeJSON(envelope, to: outputPath)
    }

    private static func importProfiles(arguments: [String]) throws {
        guard let path = firstPositional(in: arguments) else { throw CLIError.message("Missing import path") }
        let select = !arguments.contains("--no-select")
        let makeDefault = arguments.contains("--default")
        let replace = !arguments.contains("--append")
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        var importedProfiles: [GamepadConfigurationProfile] = []
        var importedBindings: [String: [String: MacKeyBinding]] = [:]
        var importedOutputBindings: [String: [String: MacControlOutputBinding]] = [:]
        var importedActiveID: UUID?
        var importedDefaultID: UUID?

        if let envelope = try? decoder.decode(ProfileExportEnvelope.self, from: data) {
            importedProfiles = envelope.profiles.map(\.normalized)
            importedBindings = envelope.profileKeyBindings
            importedOutputBindings = envelope.profileOutputBindings
            importedActiveID = envelope.activeProfileID
            importedDefaultID = envelope.defaultProfileID
        } else if let generated = try? decoder.decode(GeneratedGameKeypadProfile.self, from: data) {
            importedProfiles = [generated.profile.normalized]
            let generatedBindings = try resolvedMacBindings(for: generated)
            importedBindings[generated.profile.id.uuidString] = rawBindings(generatedBindings)
            importedOutputBindings[generated.profile.id.uuidString] = rawOutputBindings(outputBindings(from: generatedBindings))
            importedActiveID = generated.profile.id
        } else if let profile = try? decoder.decode(GamepadConfigurationProfile.self, from: data) {
            importedProfiles = [profile.normalized]
            importedActiveID = profile.id
        } else if let profiles = try? decoder.decode([GamepadConfigurationProfile].self, from: data) {
            importedProfiles = profiles.map(\.normalized)
            importedActiveID = profiles.first?.id
        } else if let customization = try? decoder.decode(GamepadCustomization.self, from: data) {
            let name = optionValue("--name", in: arguments) ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            let profile = GamepadConfigurationProfile(name: name, customization: customization)
            importedProfiles = [profile]
            importedActiveID = profile.id
        } else {
            throw CLIError.message("Unsupported profile import JSON")
        }

        guard !importedProfiles.isEmpty else { throw CLIError.message("Import did not contain any profiles") }
        var store = loadStore()
        var selectedID: UUID?
        for imported in importedProfiles {
            var profile = imported.normalized
            if replace, let existingIndex = store.profiles.firstIndex(where: { $0.id == profile.id || sameProfileName($0.name, profile.name) }) {
                profile.id = store.profiles[existingIndex].id
                profile.updatedAt = Date.currentMilliseconds
                store.profiles[existingIndex] = profile
            } else {
                store.profiles.append(profile)
            }
            selectedID = selectedID ?? profile.id
            if let raw = importedBindings[imported.id.uuidString] ?? importedBindings[profile.id.uuidString] {
                store.profileKeyBindings[profile.id.uuidString] = raw
            }
            if let rawOutput = importedOutputBindings[imported.id.uuidString] ?? importedOutputBindings[profile.id.uuidString] {
                store.profileOutputBindings[profile.id.uuidString] = rawOutput
            }
        }

        if select {
            store.activeProfileID = importedActiveID.flatMap { validProfileID($0, in: store.profiles) } ?? selectedID ?? store.activeProfileID
        }
        if makeDefault {
            store.defaultProfileID = importedDefaultID.flatMap { validProfileID($0, in: store.profiles) } ?? store.activeProfileID
        }
        try persistStore(store)
        print("Imported \(importedProfiles.count) profile\(importedProfiles.count == 1 ? "" : "s").")
    }

    private static func attachApplicationToProfile(arguments: [String]) throws {
        let profileTarget = optionValue("--profile", in: arguments) ?? firstPositional(in: arguments)
        let path = optionValue("--path", in: arguments)
            ?? optionValue("--app", in: arguments)
            ?? optionValue("--application", in: arguments)
        let bundleIdentifier = optionValue("--bundle-id", in: arguments)
            ?? optionValue("--bundle", in: arguments)
        let applicationURL = try resolveApplicationURL(path: path, bundleIdentifier: bundleIdentifier)
        let launchTarget = GamepadProfileLaunchTarget.application(url: applicationURL)

        var store = loadStore()
        let index = try resolveProfileIndex(profileTarget, in: store)
        store.profiles[index].launchTarget = launchTarget
        store.profiles[index].updatedAt = Date.currentMilliseconds
        let profileName = store.profiles[index].name
        try persistStore(store)
        print("Attached \"\(launchTarget.displayName)\" to profile \"\(profileName)\".")
    }

    private static func detachApplicationFromProfile(arguments: [String]) throws {
        let profileTarget = optionValue("--profile", in: arguments) ?? firstPositional(in: arguments)
        var store = loadStore()
        let index = try resolveProfileIndex(profileTarget, in: store)
        let removedName = store.profiles[index].launchTarget?.displayName
        store.profiles[index].launchTarget = nil
        store.profiles[index].updatedAt = Date.currentMilliseconds
        let profileName = store.profiles[index].name
        try persistStore(store)
        if let removedName {
            print("Removed \"\(removedName)\" from profile \"\(profileName)\".")
        } else {
            print("Profile \"\(profileName)\" did not have an attached application.")
        }
    }

    private static func launchAttachedApplication(arguments: [String]) throws {
        let profileTarget = optionValue("--profile", in: arguments) ?? firstPositional(in: arguments)
        let store = loadStore()
        let profile = try resolveProfile(profileTarget, in: store)
        guard let launchTarget = profile.launchTarget else {
            throw CLIError.message("Profile \"\(profile.name)\" does not have an attached application.")
        }
        try openLaunchTarget(launchTarget)
        print("Launched \"\(launchTarget.displayName)\" from profile \"\(profile.name)\".")
    }

    private static func resolveApplicationURL(path: String?, bundleIdentifier: String?) throws -> URL {
        if let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            let expandedPath = (path as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath).standardizedFileURL
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                throw CLIError.message("Application not found at path: \(path)")
            }
            guard url.pathExtension.lowercased() == "app" || Bundle(url: url)?.bundleIdentifier != nil else {
                throw CLIError.message("Path must point to a macOS .app bundle: \(path)")
            }
            return url
        }

        if let bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !bundleIdentifier.isEmpty {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                throw CLIError.message("No installed application found for bundle id: \(bundleIdentifier)")
            }
            return url.standardizedFileURL
        }

        throw CLIError.message("Usage: pocketpad profile attach-app [PROFILE|--profile PROFILE] --path /Applications/App.app or --bundle-id com.example.App")
    }

    private static func openLaunchTarget(_ launchTarget: GamepadProfileLaunchTarget) throws {
        if let applicationURL = launchTarget.resolvedApplicationURL() {
            try runProcess("/usr/bin/open", arguments: [applicationURL.path])
            return
        }

        if let bundleIdentifier = launchTarget.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines), !bundleIdentifier.isEmpty {
            try runProcess("/usr/bin/open", arguments: ["-b", bundleIdentifier])
            return
        }

        throw CLIError.message("Could not resolve attached application \"\(launchTarget.displayName)\". Reattach it with `pocketpad profile attach-app`.")
    }

    // MARK: - Templates

    private static func template(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing template subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            if rest.contains("--json") {
                let rows = GamepadControllerTemplate.allCases.map { ["id": $0.rawValue, "name": $0.displayName, "description": $0.description] }
                try printJSON(rows)
            } else {
                for template in GamepadControllerTemplate.allCases {
                    print("\(template.rawValue)\t\(template.displayName) — \(template.description)")
                }
            }
        case "install", "create", "add":
            guard let name = firstPositional(in: rest) else { throw CLIError.message("Missing template name") }
            let template = try resolveTemplate(name)
            var profile = template.makeProfile()
            if let customName = optionValue("--name", in: rest) { profile.name = customName }
            let select = !rest.contains("--no-select")
            let makeDefault = rest.contains("--default") && !rest.contains("--no-default")
            let store = loadStore()
            let inheritedBindings = decodedBindings(store.profileKeyBindings[store.activeProfileID.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings
            try install(profile: profile, macBindings: inheritedBindings, select: select, makeDefault: makeDefault)
            print("Installed template \"\(profile.name)\".")
        case "show":
            guard let name = firstPositional(in: rest) else { throw CLIError.message("Missing template name") }
            let template = try resolveTemplate(name)
            try printJSON(template.makeProfile())
        default:
            throw CLIError.message("Unknown template subcommand: \(subcommand)")
        }
    }

    // MARK: - Themes

    private static func theme(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing theme subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let summaries = GamepadThemePreset.allCases.map { themeSummary(for: $0) }
            if rest.contains("--json") {
                try printJSON(summaries)
            } else {
                for summary in summaries {
                    print("\(summary.id)\t\(summary.name) — \(summary.description)")
                }
            }
        case "show":
            guard let name = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad theme show <theme-id>") }
            let preset = try resolveThemePreset(name)
            try printJSON(themeSummary(for: preset))
        case "apply", "set":
            guard let name = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad theme apply <theme-id> [--profile PROFILE]") }
            let preset = try resolveThemePreset(name)
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                preset.apply(to: &customization)
            }
            print("Applied theme \"\(preset.displayName)\".")
        default:
            throw CLIError.message("Unknown theme subcommand: \(subcommand)")
        }
    }

    private static func resolveThemePreset(_ value: String) throws -> GamepadThemePreset {
        guard let preset = GamepadThemePreset.resolve(value) else {
            let ids = GamepadThemePreset.allCases.map(\.rawValue).joined(separator: ", ")
            throw CLIError.message("Unknown theme: \(value). Available themes: \(ids)")
        }
        return preset
    }

    private static func themeSummary(for preset: GamepadThemePreset) -> ThemeSummary {
        ThemeSummary(id: preset.rawValue, name: preset.displayName, description: preset.description)
    }

    // MARK: - Bindings

    private static func binding(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing binding subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let bindings = decodedBindings(store.profileKeyBindings[profile.id.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings
            if rest.contains("--json") {
                try printJSON(rawBindings(bindings))
            } else {
                print("Bindings for \"\(profile.name)\":")
                for button in GameButton.allCases {
                    print("- \(button.rawValue): \(bindings[button]?.displayName ?? "Unmapped")")
                }
            }

        case "set":
            try setBinding(arguments: rest)

        case "reset":
            guard let buttonText = firstPositional(in: rest) else { throw CLIError.message("Missing button") }
            let button = try parseButton(buttonText)
            try mutateBindings(profileTarget: optionValue("--profile", in: rest)) { bindings in
                if let defaultBinding = DefaultKeypadKeyMap.defaultBinding(for: button) {
                    bindings[button] = defaultBinding
                } else {
                    bindings[button] = nil
                }
            }
            print("Reset binding for \(button.displayName).")

        case "clear", "unset":
            guard let buttonText = firstPositional(in: rest) else { throw CLIError.message("Missing button") }
            let button = try parseButton(buttonText)
            try mutateBindings(profileTarget: optionValue("--profile", in: rest)) { bindings in
                bindings[button] = nil
            }
            print("Cleared binding for \(button.displayName).")

        case "reset-all":
            try mutateBindings(profileTarget: optionValue("--profile", in: rest)) { bindings in
                bindings = DefaultKeypadKeyMap.defaultBindings
            }
            print("Reset all bindings to defaults.")

        default:
            throw CLIError.message("Unknown binding subcommand: \(subcommand)")
        }
    }

    private static func setBinding(arguments: [String]) throws {
        guard let buttonText = firstPositional(in: arguments) else { throw CLIError.message("Missing button") }
        let button = try parseButton(buttonText)
        let sequenceText = optionValue("--sequence", in: arguments)
        let keyText = optionValue("--key", in: arguments)
        let modifiersText = optionValue("--modifiers", in: arguments) ?? optionValue("--mods", in: arguments)
        let positional = positionals(in: arguments)
        let fallbackBindingText = positional.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

        let binding: MacKeyBinding
        if let sequenceText {
            binding = try parseKeyBindingSequence(sequenceText)
        } else if let keyText {
            let modifiers = try parseModifiers(modifiersText)
            guard let keyCode = MacVirtualKey.keyCode(named: keyText) else { throw CLIError.message("Unsupported key: \(keyText)") }
            binding = MacKeyBinding(keyCode: keyCode, modifiers: modifiers)
        } else if !fallbackBindingText.isEmpty {
            binding = try parseKeyBindingSequence(fallbackBindingText)
        } else {
            throw CLIError.message("Missing binding. Use `binding set <button> <key>` or `--sequence Control+B,H`.")
        }

        try mutateBindings(profileTarget: optionValue("--profile", in: arguments)) { bindings in
            bindings[button] = binding
        }
        print("Mapped \(button.displayName) to \(binding.displayName).")
    }

    private static func mutateBindings(profileTarget: String?, mutate: (inout [GameButton: MacKeyBinding]) throws -> Void) throws {
        var store = loadStore()
        let profileIndex = try resolveProfileIndex(profileTarget, in: store)
        let profile = store.profiles[profileIndex]
        let profileID = profile.id.uuidString
        var bindings = decodedBindings(store.profileKeyBindings[profileID]) ?? DefaultKeypadKeyMap.defaultBindings
        try mutate(&bindings)
        store.profileKeyBindings[profileID] = rawBindings(bindings)
        var outputs = decodedOutputBindings(store.profileOutputBindings[profileID]) ?? outputBindings(from: bindings)
        switch profile.outputMode {
        case .keyboard:
            outputs = outputBindings(from: bindings)
        case .controller:
            outputs = effectiveOutputBindings(for: .controller, keyBindings: bindings, customOutputBindings: outputs)
        case .custom:
            for (button, binding) in bindings {
                var output = outputs[button] ?? MacControlOutputBinding()
                output.keyboard = binding
                outputs[button] = output
            }
        }
        syncElementOutputs(in: &store.profiles[profileIndex], outputs: outputs)
        store.profileOutputBindings[profileID] = rawOutputBindings(outputs)
        try persistStore(store)
    }

    // MARK: - Outputs

    private static func output(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing output subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let keyboardBindings = decodedBindings(store.profileKeyBindings[profile.id.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings
            let storedOutputs = decodedOutputBindings(store.profileOutputBindings[profile.id.uuidString]) ?? outputBindings(from: keyboardBindings)
            let outputs = effectiveOutputBindings(for: profile.outputMode, keyBindings: keyboardBindings, customOutputBindings: storedOutputs)
            if rest.contains("--json") {
                try printJSON(rawOutputBindings(outputs))
            } else {
                print("Outputs for \"\(profile.name)\":")
                print("Mode: \(profile.outputMode.displayName)")
                for button in GameButton.allCases {
                    print("- \(button.rawValue): \(outputs[button]?.displayName ?? "Unmapped")")
                }
            }
        case "mode", "preset":
            try outputMode(arguments: rest)
        case "set":
            try setOutput(arguments: rest)
        case "reset":
            guard let buttonText = firstPositional(in: rest) else { throw CLIError.message("Missing button") }
            let button = try parseButton(buttonText)
            try mutateOutputs(profileTarget: optionValue("--profile", in: rest)) { outputs in
                outputs[button] = DefaultMacControlOutputMap.defaultBinding(for: button)
            }
            print("Reset output for \(button.displayName).")
        case "reset-all":
            try mutateOutputs(profileTarget: optionValue("--profile", in: rest), outputMode: .keyboard) { outputs in
                outputs = DefaultMacControlOutputMap.defaultBindings
            }
            print("Reset all outputs to keyboard defaults.")
        default:
            throw CLIError.message("Unknown output subcommand: \(subcommand)")
        }
    }

    private static func outputMode(arguments: [String]) throws {
        var store = loadStore()
        let profileTarget = optionValue("--profile", in: arguments)
        let index = try resolveProfileIndex(profileTarget, in: store)
        let modeText = firstPositional(in: arguments)

        guard let modeText else {
            let profile = store.profiles[index]
            print("\(profile.name): \(profile.outputMode.displayName)")
            print(profile.outputMode.description)
            return
        }

        let mode = try parseOutputMode(modeText)
        store.profiles[index].outputMode = mode
        store.profiles[index].updatedAt = Date.currentMilliseconds
        let profileID = store.profiles[index].id.uuidString
        let keyboardBindings = decodedBindings(store.profileKeyBindings[profileID]) ?? DefaultKeypadKeyMap.defaultBindings
        let storedOutputs = decodedOutputBindings(store.profileOutputBindings[profileID]) ?? outputBindings(from: keyboardBindings)
        let effectiveOutputs = effectiveOutputBindings(
            for: mode,
            keyBindings: keyboardBindings,
            customOutputBindings: storedOutputs
        )
        store.profileOutputBindings[profileID] = rawOutputBindings(effectiveOutputs)
        syncElementOutputs(in: &store.profiles[index], outputs: effectiveOutputs)
        try persistStore(store)
        print("Set \"\(store.profiles[index].name)\" output mode to \(mode.displayName).")
    }

    private static func setOutput(arguments: [String]) throws {
        guard let buttonText = firstPositional(in: arguments) else { throw CLIError.message("Missing button") }
        let button = try parseButton(buttonText)
        let keyboardText = optionValue("--keyboard", in: arguments) ?? optionValue("--key", in: arguments)
        let sequenceText = optionValue("--sequence", in: arguments)
        let gamepadButtonText = optionValue("--gamepad-button", in: arguments) ?? optionValue("--gamepad", in: arguments)
        let clearKeyboard = arguments.contains("--clear-keyboard")
        let clearGamepad = arguments.contains("--clear-gamepad")

        try mutateOutputs(
            profileTarget: optionValue("--profile", in: arguments),
            preserveKeyboardForChangedButtons: !clearKeyboard && keyboardText == nil && sequenceText == nil
        ) { outputs in
            var output = outputs[button] ?? MacControlOutputBinding()
            if clearKeyboard {
                output.keyboard = nil
            }
            if let sequenceText {
                output.keyboard = try parseKeyBindingSequence(sequenceText)
            } else if let keyboardText {
                output.keyboard = try parseKeyBindingSequence(keyboardText)
            }
            if clearGamepad {
                output.gamepadButtons.removeAll()
            }
            if let gamepadButtonText {
                let normalized = gamepadButtonText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if normalized == "none" || normalized == "clear" || normalized == "off" {
                    output.gamepadButtons.removeAll()
                } else {
                    output.setGamepadButton(try parseVirtualGamepadButton(gamepadButtonText))
                }
            }
            outputs[button] = output.isEmpty ? nil : output
        }
        print("Updated output for \(button.displayName).")
    }

    private static func mutateOutputs(
        profileTarget: String?,
        outputMode: GamepadProfileOutputMode = .custom,
        preserveKeyboardForChangedButtons: Bool = false,
        mutate: (inout [GameButton: MacControlOutputBinding]) throws -> Void
    ) throws {
        var store = loadStore()
        let profileIndex = try resolveProfileIndex(profileTarget, in: store)
        let profileID = store.profiles[profileIndex].id.uuidString
        let keyboardBindings = decodedBindings(store.profileKeyBindings[profileID]) ?? DefaultKeypadKeyMap.defaultBindings
        var outputs = decodedOutputBindings(store.profileOutputBindings[profileID]) ?? outputBindings(from: keyboardBindings)
        let originalOutputs = outputs
        try mutate(&outputs)
        if preserveKeyboardForChangedButtons {
            for button in GameButton.allCases where outputs[button] != originalOutputs[button] {
                guard outputs[button]?.keyboard == nil,
                      outputs[button]?.gamepadButtons.isEmpty == false,
                      let keyboard = keyboardBindings[button]
                else { continue }
                outputs[button]?.keyboard = keyboard
            }
        }
        store.profiles[profileIndex].outputMode = outputMode
        store.profiles[profileIndex].updatedAt = Date.currentMilliseconds
        syncElementOutputs(in: &store.profiles[profileIndex], outputs: outputs)
        store.profileOutputBindings[profileID] = rawOutputBindings(outputs)
        if outputMode == .keyboard {
            store.profileKeyBindings[profileID] = rawBindings(outputs.keyboardBindings)
        } else {
            var nextKeyboardBindings = keyboardBindings
            for button in GameButton.allCases where outputs[button] != originalOutputs[button] {
                if let keyboard = outputs[button]?.keyboard {
                    nextKeyboardBindings[button] = keyboard
                } else {
                    nextKeyboardBindings[button] = nil
                }
            }
            store.profileKeyBindings[profileID] = rawBindings(nextKeyboardBindings)
        }
        try persistStore(store)
    }

    private static func syncElementOutputs(in profile: inout GamepadConfigurationProfile, outputs: [GameButton: MacControlOutputBinding]) {
        func update(_ customization: inout GamepadCustomization) {
            var normalizedCustomization = customization.normalized
            for button in GameButton.allCases {
                let matchingCustomIDs = Set(normalizedCustomization.customButtons.filter { $0.mappedButton == button }.map(\.id))
                let sharedBinding = outputs[button]?.sharedBinding
                for index in normalizedCustomization.elements.indices {
                    let element = normalizedCustomization.elements[index]
                    guard element.builtInButton == button || element.legacySlot == button || matchingCustomIDs.contains(element.id) else { continue }
                    normalizedCustomization.elements[index].setOutputBinding(sharedBinding, for: .primary)
                }
            }
            customization = normalizedCustomization.normalized
        }

        update(&profile.customization)
        if var landscapeCustomization = profile.landscapeCustomization {
            update(&landscapeCustomization)
            profile.landscapeCustomization = landscapeCustomization
        }
        if var portraitCustomization = profile.portraitCustomization {
            update(&portraitCustomization)
            profile.portraitCustomization = portraitCustomization
        }
        profile.updatedAt = Date.currentMilliseconds
    }

    // MARK: - Customization

    private static func customization(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing customization subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "show":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            try printJSON(customization(for: profile, arguments: rest))
        case "export":
            let outputPath = optionValue("--output", in: rest) ?? optionValue("-o", in: rest)
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            try writeJSON(customization(for: profile, arguments: rest), to: outputPath)
        case "import":
            guard let path = firstPositional(in: rest) else { throw CLIError.message("Missing customization JSON path") }
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let customization = try JSONDecoder().decode(GamepadCustomization.self, from: data)
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest), variant: try customizationVariant(in: rest)) { $0 = customization }
            print("Imported customization.")
        case "validate", "check", "lint":
            try validateLayout(arguments: rest)
        case "preview", "render":
            try previewLayout(arguments: rest)
        case "set":
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest), variant: try customizationVariant(in: rest)) { customization in
                if let layout = optionValue("--layout", in: rest) { customization.layoutMode = try parseLayoutMode(layout) }
                if let scale = optionValue("--scale", in: rest) ?? optionValue("--control-scale", in: rest) { customization.controlScale = try parseControlScale(scale) }
                if let appearance = optionValue("--appearance", in: rest) ?? optionValue("--color-scheme", in: rest) ?? optionValue("--scheme", in: rest) { customization.colorSchemePreference = try parseColorSchemePreference(appearance) }
                if let device = optionValue("--device", in: rest) ?? optionValue("--frame", in: rest) ?? optionValue("--canvas", in: rest) {
                    let orientation = try (optionValue("--orientation", in: rest) ?? optionValue("--device-orientation", in: rest)).map(parseDeviceOrientation)
                    customization.deviceCanvas = GamepadDeviceCanvas(frameID: try resolveDeviceFrameTarget(device, arguments: rest, preferredOrientation: orientation).id)
                }
                if let deviceSize = optionValue("--device-size", in: rest) ?? optionValue("--size", in: rest) {
                    let orientation = try (optionValue("--orientation", in: rest) ?? optionValue("--device-orientation", in: rest)).map(parseDeviceOrientation)
                    customization.deviceCanvas = GamepadDeviceCanvas(frameID: try resolveCustomDeviceFrame(sizeText: deviceSize, preferredOrientation: orientation).id)
                }
                if let background = optionValue("--background", in: rest) ?? optionValue("--bg", in: rest) {
                    setBackgroundFillColor(try parseRGBAColor(background), in: &customization)
                }
                if let lightBackground = optionValue("--light-background", in: rest) ?? optionValue("--background-light", in: rest) {
                    setBackgroundFillColor(try parseRGBAColor(lightBackground), isDark: false, in: &customization)
                }
                if let darkBackground = optionValue("--dark-background", in: rest) ?? optionValue("--background-dark", in: rest) {
                    setBackgroundFillColor(try parseRGBAColor(darkBackground), isDark: true, in: &customization)
                }
                if let value = optionValue("--background-gradient", in: rest) ?? optionValue("--bg-gradient", in: rest) {
                    setBackgroundFillStyle(try parseGradientFill(value, arguments: rest), in: &customization)
                }
                if let value = optionValue("--background-tile", in: rest) ?? optionValue("--bg-tile", in: rest) {
                    setBackgroundFillStyle(try parseTileFill(value, arguments: rest), in: &customization)
                }
                if let value = optionValue("--background-image", in: rest) ?? optionValue("--bg-image", in: rest) {
                    setBackgroundFillStyle(try parseImageFill(value, arguments: rest), in: &customization)
                }
                if let value = optionValue("--light-background-gradient", in: rest) ?? optionValue("--background-light-gradient", in: rest) {
                    setBackgroundFillStyle(try parseGradientFill(value, arguments: rest), isDark: false, in: &customization)
                }
                if let value = optionValue("--dark-background-gradient", in: rest) ?? optionValue("--background-dark-gradient", in: rest) {
                    setBackgroundFillStyle(try parseGradientFill(value, arguments: rest), isDark: true, in: &customization)
                }
                if let value = optionValue("--light-background-tile", in: rest) ?? optionValue("--background-light-tile", in: rest) {
                    setBackgroundFillStyle(try parseTileFill(value, arguments: rest), isDark: false, in: &customization)
                }
                if let value = optionValue("--dark-background-tile", in: rest) ?? optionValue("--background-dark-tile", in: rest) {
                    setBackgroundFillStyle(try parseTileFill(value, arguments: rest), isDark: true, in: &customization)
                }
                if let value = optionValue("--light-background-image", in: rest) ?? optionValue("--background-light-image", in: rest) {
                    setBackgroundFillStyle(try parseImageFill(value, arguments: rest), isDark: false, in: &customization)
                }
                if let value = optionValue("--dark-background-image", in: rest) ?? optionValue("--background-dark-image", in: rest) {
                    setBackgroundFillStyle(try parseImageFill(value, arguments: rest), isDark: true, in: &customization)
                }
                if rest.contains("--reset-background") {
                    clearBackgroundFill(in: &customization)
                }
                if let accent = optionValue("--accent", in: rest) ?? optionValue("--color", in: rest) { customization.accentStyle = try parseAccentStyle(accent) }
                if rest.contains("--show-labels") { customization.showsButtonLabels = true }
                if rest.contains("--hide-labels") { customization.showsButtonLabels = false }
                if let labels = optionValue("--labels", in: rest) { customization.showsButtonLabels = try parseBool(labels) }
            }
            print("Updated customization.")
        case "reset":
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest), variant: try customizationVariant(in: rest)) { $0 = .defaultValue }
            print("Reset customization.")
        default:
            throw CLIError.message("Unknown customization subcommand: \(subcommand)")
        }
    }

    private static func validateLayout(arguments: [String]) throws {
        let store = loadStore()
        let profile = try resolveProfile(layoutProfileTarget(in: arguments), in: store)
        let resolvedCustomization = try customization(for: profile, arguments: arguments)
        let canvasSize = try parseLayoutCanvasSize(arguments, fallback: resolvedCustomization.deviceCanvas.editorDeviceFrame.screenRect.size)
        let report = resolvedCustomization.layoutQualityReport(profileName: profile.name, canvasSize: canvasSize)

        if arguments.contains("--json") {
            try printJSON(report)
        } else {
            printLayoutReport(report)
        }

        try enforceLayoutQuality(
            report,
            strict: arguments.contains("--strict"),
            quiet: true
        )
    }

    private static func previewLayout(arguments: [String]) throws {
        let store = loadStore()
        let profile = try resolveProfile(layoutProfileTarget(in: arguments), in: store)
        let resolvedCustomization = try customization(for: profile, arguments: arguments)
        let canvasSize = try parseLayoutCanvasSize(arguments, fallback: resolvedCustomization.deviceCanvas.editorDeviceFrame.screenRect.size)
        let outputPath = optionValue("--output", in: arguments) ?? optionValue("-o", in: arguments) ?? optionValue("--path", in: arguments) ?? "pocketpad-layout-preview.png"
        let scale = try parsePreviewScale(arguments)

#if os(macOS)
        try GamepadLayoutPreviewRenderer.writePNG(
            customization: resolvedCustomization,
            profileName: profile.name,
            canvasSize: canvasSize,
            outputURL: URL(fileURLWithPath: outputPath),
            scale: scale,
            annotateIssues: !arguments.contains("--no-annotations")
        )
        let report = resolvedCustomization.layoutQualityReport(profileName: profile.name, canvasSize: canvasSize)
        if arguments.contains("--json") {
            try printJSON(report)
        } else {
            print("Wrote layout preview to \(outputPath).")
            print("Layout quality: \(report.statusText) (\(report.summary.errorCount) errors, \(report.summary.warningCount) warnings).")
        }
#else
        throw CLIError.message("Layout preview rendering is only available on macOS.")
#endif
    }

    private static func layoutProfileTarget(in arguments: [String]) -> String? {
        optionValue("--profile", in: arguments) ?? firstPositional(in: arguments)
    }

    private static func parseLayoutCanvasSize(_ arguments: [String], fallback: CGSize) throws -> CGSize {
        var canvasSize = fallback
        if let canvas = optionValue("--canvas", in: arguments) ?? optionValue("--device", in: arguments) ?? optionValue("--frame", in: arguments) {
            let normalized = normalizedLookup(canvas)
            if normalized == "landscape" {
                canvasSize = defaultEditorCanvasSize
            } else if normalized == "portrait" {
                canvasSize = portraitEditorCanvasSize
            } else if let parsed = parseCanvasSizeLiteral(canvas) {
                canvasSize = parsed
            } else {
                canvasSize = try resolveDeviceFrame(canvas, preferredOrientation: nil).screenRect.size
            }
        }
        if let size = optionValue("--size", in: arguments) ?? optionValue("--device-size", in: arguments) {
            guard let parsed = parseCanvasSizeLiteral(size) else { throw CLIError.message("Invalid canvas size: \(size). Use WIDTHxHEIGHT.") }
            canvasSize = parsed
        }
        let explicitWidth = optionValue("--canvas-width", in: arguments)
        let explicitHeight = optionValue("--canvas-height", in: arguments)
        if explicitWidth != nil || explicitHeight != nil {
            guard let explicitWidth, let explicitHeight else { throw CLIError.message("Use --canvas-width and --canvas-height together") }
            canvasSize = CGSize(width: try parsePixels(explicitWidth), height: try parsePixels(explicitHeight))
        }
        guard canvasSize.width > 1, canvasSize.height > 1 else { throw CLIError.message("Canvas size must be greater than 1×1") }
        return canvasSize
    }

    private static func parsePreviewScale(_ arguments: [String]) throws -> CGFloat {
        guard let value = optionValue("--image-scale", in: arguments) ?? optionValue("--render-scale", in: arguments) ?? optionValue("--scale", in: arguments) else {
            return 2
        }
        let parsed = try parsePixels(value)
        guard parsed > 0 else { throw CLIError.message("Preview scale must be greater than zero") }
        return parsed
    }

    private static func printLayoutReport(_ report: GamepadLayoutQualityReport) {
        let profileName = report.profileName ?? "active"
        print("Layout validation for \"\(profileName)\": \(report.statusText)")
        print("Canvas: \(formatPixels(CGFloat(report.canvas.width)))×\(formatPixels(CGFloat(report.canvas.height))) pt")
        print("Elements: \(report.summary.controlCount), errors: \(report.summary.errorCount), warnings: \(report.summary.warningCount)")
        print("Usage: width \(formatPercentage(report.summary.layoutWidthCoverage)), height \(formatPercentage(report.summary.layoutHeightCoverage)), bottom unused \(formatPercentage(report.summary.bottomUnusedRatio))")
        if report.issues.isEmpty {
            print("No layout issues found.")
            return
        }
        for issue in report.issues {
            let prefix = switch issue.severity {
            case .info: "info"
            case .warning: "warning"
            case .error: "error"
            }
            print("- \(prefix) [\(issue.code)]: \(issue.message)")
        }
    }

    private static func enforceLayoutQuality(_ report: GamepadLayoutQualityReport, strict: Bool, quiet: Bool) throws {
        let shouldFail = report.hasErrors || (strict && report.hasWarnings)
        if !quiet {
            if report.issues.isEmpty {
                print("Layout quality: passed.")
            } else {
                print("Layout quality: \(report.statusText) (\(report.summary.errorCount) errors, \(report.summary.warningCount) warnings).")
                for issue in report.issues.prefix(6) {
                    print("- \(issue.severity.rawValue) [\(issue.code)]: \(issue.message)")
                }
                if report.issues.count > 6 {
                    print("- …and \(report.issues.count - 6) more layout issues")
                }
            }
        }
        guard !shouldFail else {
            throw CLIError.validationFailed("Layout validation failed for \"\(report.profileName ?? "profile")\". Run `pocketpad layout validate --profile \"\(report.profileName ?? "active")\"` or `pocketpad layout preview -o preview.png` for details.")
        }
    }

    private static func customizationVariant(in arguments: [String]) throws -> GamepadEditorDeviceOrientation? {
        guard let value = optionValue("--variant", in: arguments) ?? optionValue("--layout-variant", in: arguments) else { return nil }
        return try parseDeviceOrientation(value)
    }

    private static func customization(for profile: GamepadConfigurationProfile, arguments: [String]) throws -> GamepadCustomization {
        if let variant = try customizationVariant(in: arguments) {
            return profile.customization(for: variant)
        }
        return profile.customization
    }

    private static func mutateCustomization(profileTarget: String?, variant: GamepadEditorDeviceOrientation? = nil, mutate: (inout GamepadCustomization) throws -> Void) throws {
        var store = loadStore()
        let index = try resolveProfileIndex(profileTarget, in: store)
        var customization = variant.map { store.profiles[index].customization(for: $0) } ?? store.profiles[index].customization
        try mutate(&customization)
        let normalizedCustomization = customization.normalized
        if let variant {
            store.profiles[index].setCustomization(normalizedCustomization, for: variant)
        } else {
            store.profiles[index].setCustomization(
                normalizedCustomization,
                for: normalizedCustomization.deviceCanvas.editorDeviceFrame.orientation
            )
        }
        store.profiles[index].updatedAt = Date.currentMilliseconds
        try persistStore(store)
    }

    // MARK: - Styles / layers / groups / assets

    private static func style(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing style subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let styles = profile.customization.styleLibrary.normalized.styles
            if rest.contains("--json") {
                try printJSON(styles)
            } else if styles.isEmpty {
                print("No styles saved for \"\(profile.name)\".")
            } else {
                for style in styles { print("\(style.id)\t\(style.name)") }
            }
        case "show":
            guard let id = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad style show <style-id>") }
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            guard let token = profile.customization.styleLibrary.style(id: id) else { throw CLIError.message("Style not found: \(id)") }
            try printJSON(token)
        case "create", "new", "set":
            guard let name = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad style create <name> [--id ID] [--fill #RRGGBB]") }
            let id = optionValue("--id", in: rest) ?? slug(name)
            let token = try makeStyleToken(id: id, name: name, arguments: rest)
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                var library = customization.styleLibrary.normalized
                library.styles.removeAll { $0.id == token.id }
                library.styles.append(token)
                customization.styleLibrary = library.normalized
            }
            print("Saved style \"\(token.name)\" (\(token.id)).")
        case "apply":
            let positional = positionals(in: rest)
            guard positional.count >= 2 else { throw CLIError.message("Usage: pocketpad style apply <style-id> <element>") }
            let styleID = positional[0]
            let targetText = positional[1]
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                guard customization.styleLibrary.style(id: styleID) != nil else { throw CLIError.message("Style not found: \(styleID)") }
                let target = try resolveElementTarget(targetText, in: customization)
                try mutateLayout(for: target, in: &customization) { layout in
                    layout.styleID = styleID
                }
            }
            print("Applied style \"\(styleID)\" to \"\(targetText)\".")
        case "detach", "clear":
            guard let targetText = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad style detach <element>") }
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                let target = try resolveElementTarget(targetText, in: customization)
                try mutateLayout(for: target, in: &customization) { layout in
                    layout.styleID = nil
                }
            }
            print("Detached style from \"\(targetText)\".")
        case "delete", "rm":
            guard let id = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad style delete <style-id>") }
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                customization.styleLibrary.styles.removeAll { $0.id == id }
                for button in GameButton.allCases {
                    var layout = customization.buttonCustomization(for: button)
                    if layout.styleID == id {
                        layout.styleID = nil
                        customization.setButtonCustomization(layout, for: button)
                    }
                }
                for index in customization.customButtons.indices where customization.customButtons[index].layout.styleID == id {
                    customization.customButtons[index].layout.styleID = nil
                }
            }
            print("Deleted style \"\(id)\".")
        case "export":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            try writeJSON(profile.customization.styleLibrary.normalized, to: optionValue("--output", in: rest) ?? optionValue("-o", in: rest))
        case "import":
            guard let path = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad style import <style-library.json>") }
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let library = try JSONDecoder().decode(GamepadStyleLibrary.self, from: data).normalized
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { $0.styleLibrary = library }
            print("Imported style library.")
        default:
            throw CLIError.message("Unknown style subcommand: \(subcommand)")
        }
    }

    private static func layer(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing layer subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let order = profile.customization.orderedControlIdentitiesForDesign
            if rest.contains("--json") {
                try printJSON(order.map { layerSummary(identity: $0, customization: profile.customization) })
            } else {
                for (index, identity) in order.enumerated() {
                    let summary = layerSummary(identity: identity, customization: profile.customization)
                    print("\(index)\t\(summary.id)\t\(summary.label)\t\(summary.kind)")
                }
            }
        case "move":
            let positional = positionals(in: rest)
            guard let targetText = positional.first else { throw CLIError.message("Usage: pocketpad layer move <element> --to INDEX") }
            let toIndex = try optionValue("--to", in: rest).map(parseInteger)
            let beforeText = optionValue("--before", in: rest)
            let afterText = optionValue("--after", in: rest)
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                let target = try resolveElementTarget(targetText, in: customization)
                let layerIdentity = identity(for: target)
                if let toIndex {
                    customization.moveLayer(layerIdentity, to: toIndex)
                } else if let beforeText {
                    let before = identity(for: try resolveElementTarget(beforeText, in: customization))
                    let order = customization.orderedControlIdentitiesForDesign
                    customization.moveLayer(layerIdentity, to: order.firstIndex(of: before) ?? 0)
                } else if let afterText {
                    let after = identity(for: try resolveElementTarget(afterText, in: customization))
                    let order = customization.orderedControlIdentitiesForDesign
                    customization.moveLayer(layerIdentity, to: (order.firstIndex(of: after) ?? order.count - 1) + 1)
                } else {
                    throw CLIError.message("layer move needs --to, --before, or --after")
                }
            }
            print("Moved layer \"\(targetText)\".")
        case "bring-forward", "forward":
            try mutateLayer(rest) { $0.bringLayerForward($1) }
        case "send-backward", "backward":
            try mutateLayer(rest) { $0.sendLayerBackward($1) }
        case "front", "bring-front":
            try mutateLayer(rest) { $0.bringLayerToFront($1) }
        case "back", "send-back":
            try mutateLayer(rest) { $0.sendLayerToBack($1) }
        default:
            throw CLIError.message("Unknown layer subcommand: \(subcommand)")
        }
    }

    private static func group(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing group subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let groups = profile.customization.designMetadata?.groups ?? []
            if rest.contains("--json") { try printJSON(groups) } else { groups.forEach { print("\($0.id.uuidString)\t\($0.name)\t\($0.children.count) elements") } }
        case "create", "new":
            let positional = positionals(in: rest)
            guard let name = positional.first, positional.count >= 2 else { throw CLIError.message("Usage: pocketpad group create <name> <element>...") }
            let targets = Array(positional.dropFirst())
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                let children = try targets.map { identity(for: try resolveElementTarget($0, in: customization)) }
                var metadata = customization.designMetadata ?? .empty
                metadata.groups.append(GamepadLayerGroup(name: name, children: children))
                customization.designMetadata = metadata.normalized(availableControls: customization.allControlIdentitiesForDesign)
            }
            print("Created group \"\(name)\".")
        case "ungroup", "delete", "rm":
            guard let target = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad group ungroup <group-name-or-id>") }
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                var metadata = customization.designMetadata ?? .empty
                metadata.groups.removeAll { groupMatches($0, target: target) }
                customization.designMetadata = metadata.normalized(availableControls: customization.allControlIdentitiesForDesign)
            }
            print("Removed group \"\(target)\".")
        case "hide", "show", "lock", "unlock":
            guard let targetName = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad group \(subcommand) <group-name-or-id>") }
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                var metadata = customization.designMetadata ?? .empty
                guard let index = metadata.groups.firstIndex(where: { groupMatches($0, target: targetName) }) else { throw CLIError.message("Group not found: \(targetName)") }
                let hidden = subcommand == "hide" ? true : (subcommand == "show" ? false : metadata.groups[index].isHidden)
                let locked = subcommand == "lock" ? true : (subcommand == "unlock" ? false : metadata.groups[index].isLocked)
                metadata.groups[index].isHidden = hidden
                metadata.groups[index].isLocked = locked
                for child in metadata.groups[index].children {
                    try mutateLayout(for: target(for: child), in: &customization) { layout in
                        layout.isHidden = hidden
                        layout.isLocationLocked = locked
                    }
                }
                customization.designMetadata = metadata.normalized(availableControls: customization.allControlIdentitiesForDesign)
            }
            print("Updated group \"\(targetName)\".")
        default:
            throw CLIError.message("Unknown group subcommand: \(subcommand)")
        }
    }

    private static func asset(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing asset subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let assets = profile.customization.assetLibrary.normalized.assets
            if rest.contains("--json") { try printJSON(assets) } else { assets.forEach { print("\($0.id)\t\($0.name)\t\($0.role.rawValue)\t\($0.byteCount) bytes") } }
        case "import":
            guard let path = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad asset import <path> [--name NAME] [--role background|icon|texture]") }
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            guard data.count <= GamepadAsset.maximumStoredBytes else { throw CLIError.message("Assets must be under \(GamepadAsset.maximumStoredBytes) bytes") }
            let name = optionValue("--name", in: rest) ?? url.deletingPathExtension().lastPathComponent
            let role = try optionValue("--role", in: rest).map(parseAssetRole) ?? .reference
            let asset = GamepadAsset(name: name, fileName: url.lastPathComponent, contentType: contentType(for: url), data: data, role: role)
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                var library = customization.assetLibrary.normalized
                library.assets.append(asset)
                customization.assetLibrary = library.normalized
            }
            print("Imported asset \"\(name)\".")
        case "remove", "delete", "rm":
            guard let id = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad asset remove <asset-id>") }
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                customization.assetLibrary.assets.removeAll { $0.id == id }
            }
            print("Removed asset \"\(id)\".")
        default:
            throw CLIError.message("Unknown asset subcommand: \(subcommand)")
        }
    }

    private struct LayerSummary: Codable {
        var id: String
        var kind: String
        var label: String
        var isHidden: Bool
        var isLocked: Bool
    }

    private static func layerSummary(identity: GamepadControlIdentity, customization: GamepadCustomization) -> LayerSummary {
        switch identity {
        case .builtin(let button):
            let layout = customization.buttonCustomization(for: button)
            return LayerSummary(id: identity.id, kind: "button", label: customization.visualLabel(for: button), isHidden: layout.isHidden, isLocked: layout.isLocationLocked)
        case .custom(let id):
            let custom = customization.customButtons.first { $0.id == id }?.normalized
            return LayerSummary(id: identity.id, kind: custom?.controlKind.rawValue ?? "custom", label: custom?.label ?? id.uuidString, isHidden: custom?.layout.isHidden ?? false, isLocked: custom?.layout.isLocationLocked ?? false)
        }
    }

    private static func makeStyleToken(id: String, name: String, arguments: [String]) throws -> GamepadStyleToken {
        var layout = GamepadButtonCustomization.defaultValue
        try applyRichVisualOptions(arguments, to: &layout)
        if let fill = optionValue("--fill", in: arguments) ?? optionValue("--color", in: arguments) {
            var style = layout.visualStyle ?? .empty
            var normal = style.normal
            normal.fillStyle = .solid(try parseRGBAColor(fill))
            style.normal = normal
            layout.visualStyle = style
        }
        let icon = try parseIconOption(arguments)
        let haptic = try parseHapticFeedbackOptions(arguments, existing: nil)
        var visualStyle = layout.visualStyle ?? .empty
        if let icon { visualStyle.icon = icon }
        if let haptic {
            visualStyle.hapticStyle = haptic.style
            visualStyle.hapticFeedback = haptic
        }
        guard let token = GamepadStyleToken(id: id, name: name, visualStyle: visualStyle).normalized else { throw CLIError.message("Style needs at least one visual property") }
        return token
    }

    private static func applyRichVisualOptions(_ arguments: [String], to layout: inout GamepadButtonCustomization) throws {
        var style = if let material = optionValue("--material", in: arguments) ?? optionValue("--material-preset", in: arguments) {
            try parseMaterialVisualStyle(material)
        } else {
            layout.visualStyle ?? .empty
        }
        var normal = style.normal
        if let stroke = optionValue("--stroke", in: arguments) ?? optionValue("--stroke-color", in: arguments) { normal.strokeColor = try parseRGBAColor(stroke) }
        if let foreground = optionValue("--foreground", in: arguments) ?? optionValue("--foreground-color", in: arguments) ?? optionValue("--text-color", in: arguments) { normal.foregroundColor = try parseRGBAColor(foreground) }
        if let value = optionValue("--stroke-width", in: arguments), let width = Double(value) { normal.strokeWidth = CGFloat(width) }
        if let glow = optionValue("--glow", in: arguments) ?? optionValue("--glow-color", in: arguments) { normal.glowColor = try parseRGBAColor(glow) }
        if let value = optionValue("--glow-radius", in: arguments), let radius = Double(value) { normal.glowRadius = CGFloat(radius) }
        if let innerShadow = optionValue("--inner-shadow", in: arguments) ?? optionValue("--inner-shadow-color", in: arguments) { normal.innerShadowColor = try parseRGBAColor(innerShadow) }
        if let value = optionValue("--inner-shadow-radius", in: arguments), let radius = Double(value) { normal.innerShadowRadius = CGFloat(radius) }
        if let value = optionValue("--inner-shadow-x", in: arguments), let x = Double(value) { normal.innerShadowX = CGFloat(x) }
        if let value = optionValue("--inner-shadow-y", in: arguments), let y = Double(value) { normal.innerShadowY = CGFloat(y) }
        if let highlight = optionValue("--highlight", in: arguments) ?? optionValue("--highlight-color", in: arguments) { normal.highlightColor = try parseRGBAColor(highlight) }
        if let value = optionValue("--highlight-radius", in: arguments), let radius = Double(value) { normal.highlightRadius = CGFloat(radius) }
        if let value = optionValue("--highlight-x", in: arguments), let x = Double(value) { normal.highlightX = CGFloat(x) }
        if let value = optionValue("--highlight-y", in: arguments), let y = Double(value) { normal.highlightY = CGFloat(y) }
        if let value = optionValue("--highlight-opacity", in: arguments), let opacity = parseOpacityIfPresent(value) { normal.highlightOpacity = opacity }
        if let bevelHighlight = optionValue("--bevel-highlight", in: arguments) { normal.bevelHighlightColor = try parseRGBAColor(bevelHighlight) }
        if let bevelShadow = optionValue("--bevel-shadow", in: arguments) { normal.bevelShadowColor = try parseRGBAColor(bevelShadow) }
        if let value = optionValue("--bevel-width", in: arguments) ?? optionValue("--bevel", in: arguments), let width = Double(value) { normal.bevelWidth = CGFloat(width) }
        if let value = optionValue("--opacity", in: arguments), let opacity = parseOpacityIfPresent(value) { normal.opacity = opacity }
        if let shadows = optionValue("--shadow-layers", in: arguments) ?? optionValue("--shadows", in: arguments) {
            normal.shadows = try parseShadowLayers(shadows)
        }
        if let value = optionValue("--press-scale", in: arguments) ?? optionValue("--scale-on-press", in: arguments), let scale = Double(value) {
            var pressed = style.pressed ?? .empty
            pressed.scale = CGFloat(scale)
            style.pressed = pressed
        }
        if let fill = optionValue("--pressed-fill", in: arguments) ?? optionValue("--pressed-color", in: arguments) {
            var pressed = style.pressed ?? .empty
            pressed.fillStyle = .solid(try parseRGBAColor(fill))
            style.pressed = pressed
        }
        if normal != style.normal { style.normal = normal }
        layout.visualStyle = style.normalized
    }

    private static func mutateLayer(_ arguments: [String], mutate: (inout GamepadCustomization, GamepadControlIdentity) -> Void) throws {
        guard let targetText = firstPositional(in: arguments) else { throw CLIError.message("Missing layer element") }
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments)) { customization in
            let identity = identity(for: try resolveElementTarget(targetText, in: customization))
            mutate(&customization, identity)
        }
        print("Updated layer \"\(targetText)\".")
    }

    private static func mutateLayout(for target: ElementTarget, in customization: inout GamepadCustomization, mutate: (inout GamepadButtonCustomization) throws -> Void) throws {
        switch target {
        case .builtin(let button):
            var layout = customization.buttonCustomization(for: button)
            try mutate(&layout)
            customization.setButtonCustomization(layout, for: button)
        case .custom(let id):
            guard let index = customization.customButtons.firstIndex(where: { $0.id == id }) else { throw CLIError.message("Custom element not found") }
            try mutate(&customization.customButtons[index].layout)
        }
    }

    private static func identity(for target: ElementTarget) -> GamepadControlIdentity {
        switch target {
        case .builtin(let button): .builtin(button)
        case .custom(let id): .custom(id)
        }
    }

    private static func target(for identity: GamepadControlIdentity) -> ElementTarget {
        switch identity {
        case .builtin(let button): .builtin(button)
        case .custom(let id): .custom(id)
        }
    }

    private static func groupMatches(_ group: GamepadLayerGroup, target: String) -> Bool {
        group.id.uuidString.lowercased() == target.lowercased() || normalizedLookup(group.name) == normalizedLookup(target)
    }

    private static func parseInteger(_ value: String) throws -> Int {
        guard let integer = Int(value) else { throw CLIError.message("Expected integer, got \(value)") }
        return integer
    }

    private static func slug(_ value: String) -> String {
        let scalars = value.lowercased().unicodeScalars.map { scalar -> UnicodeScalar in
            if CharacterSet.alphanumerics.contains(scalar) { return scalar }
            return UnicodeScalar("-")
        }
        let collapsed = String(String.UnicodeScalarView(scalars)).replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
        return GamepadStyleToken.normalizedIdentifier(collapsed).isEmpty ? UUID().uuidString : GamepadStyleToken.normalizedIdentifier(collapsed)
    }

    private static func parseHapticStyle(_ value: String) throws -> GamepadHapticStyle {
        let normalized = normalizedLookup(value)
        guard let style = GamepadHapticStyle.allCases.first(where: { normalizedLookup($0.rawValue) == normalized || normalizedLookup($0.displayName) == normalized }) else {
            throw CLIError.message("Unknown haptic style: \(value)")
        }
        return style
    }

    private static func parseHapticPattern(_ value: String) throws -> GamepadHapticPattern {
        let normalized = normalizedLookup(value)
        guard let pattern = GamepadHapticPattern.allCases.first(where: { normalizedLookup($0.rawValue) == normalized || normalizedLookup($0.displayName) == normalized }) else {
            throw CLIError.message("Unknown haptic pattern: \(value)")
        }
        return pattern
    }

    private static func parseHapticFeedbackOptions(_ arguments: [String], existing: GamepadHapticFeedback?) throws -> GamepadHapticFeedback? {
        let style = try optionValue("--haptic", in: arguments).map(parseHapticStyle)
        let pattern = try (optionValue("--haptic-pattern", in: arguments) ?? optionValue("--haptic-rhythm", in: arguments)).map(parseHapticPattern)
        let intensity = try (optionValue("--haptic-intensity", in: arguments) ?? optionValue("--haptic-strength", in: arguments)).map { try parseHapticUnitInterval($0, option: "--haptic-intensity") }
        let sharpness = try optionValue("--haptic-sharpness", in: arguments).map { try parseHapticUnitInterval($0, option: "--haptic-sharpness") }
        let duration = try (optionValue("--haptic-duration", in: arguments) ?? optionValue("--haptic-duration-ms", in: arguments)).map(parseHapticDuration)

        guard style != nil || pattern != nil || intensity != nil || sharpness != nil || duration != nil else { return nil }

        var feedback = existing ?? GamepadHapticFeedback(style: style ?? .light)
        if let style {
            let hadAdvancedOverrides = existing != nil
            feedback.style = style
            if !hadAdvancedOverrides && intensity == nil { feedback.intensity = style.defaultIntensity }
            if !hadAdvancedOverrides && sharpness == nil { feedback.sharpness = style.defaultSharpness }
        }
        if let pattern { feedback.pattern = pattern }
        if let intensity { feedback.intensity = intensity }
        if let sharpness { feedback.sharpness = sharpness }
        if let duration { feedback.duration = duration }
        return feedback.normalized
    }

    private static func setHapticFeedback(_ feedback: GamepadHapticFeedback, in layout: inout GamepadButtonCustomization) {
        let normalized = feedback.normalized
        if normalized.isDefault {
            layout.hapticStyle = nil
            layout.hapticFeedback = nil
        } else {
            layout.hapticStyle = normalized.style
            layout.hapticFeedback = normalized
        }
    }

    private static func parseHapticUnitInterval(_ value: String, option: String) throws -> CGFloat {
        guard let parsed = parseOpacityIfPresent(value) else { throw CLIError.message("Invalid \(option): \(value)") }
        return parsed
    }

    private static func parseHapticDuration(_ value: String) throws -> CGFloat {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let seconds: Double?
        if trimmed.hasSuffix("ms") {
            seconds = Double(trimmed.dropLast(2)).map { $0 / 1_000 }
        } else if trimmed.hasSuffix("s") {
            seconds = Double(trimmed.dropLast())
        } else if let raw = Double(trimmed) {
            seconds = raw > 1 ? raw / 1_000 : raw
        } else {
            seconds = nil
        }
        guard let seconds, seconds.isFinite else { throw CLIError.message("Invalid --haptic-duration: \(value)") }
        return CGFloat(seconds)
    }

    private static func parseIconOption(_ arguments: [String]) throws -> GamepadControlIcon? {
        guard let value = optionValue("--icon", in: arguments) ?? optionValue("--sf-symbol", in: arguments) ?? optionValue("--icon-text", in: arguments) else { return nil }
        if value.hasPrefix("text:") { return GamepadControlIcon.text(String(value.dropFirst(5))).normalized }
        if value.hasPrefix("sf:") { return GamepadControlIcon.sfSymbol(String(value.dropFirst(3))).normalized }
        if arguments.contains("--icon-text") { return GamepadControlIcon.text(value).normalized }
        return GamepadControlIcon.sfSymbol(value).normalized
    }

    private static func parseAssetRole(_ value: String) throws -> GamepadAssetRole {
        guard let role = GamepadAssetRole(rawValue: normalizedLookup(value)) else { throw CLIError.message("Unknown asset role: \(value)") }
        return role
    }

    private static func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "svg": "image/svg+xml"
        default: "application/octet-stream"
        }
    }

    // MARK: - Device frames

    private static func device(arguments: [String]) throws {
        let subcommand = arguments.first?.hasPrefix("-") == true ? "list" : (arguments.first ?? "list")
        let rest = subcommand == "list" && arguments.first?.hasPrefix("-") == true ? arguments : Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let summaries = GamepadEditorDeviceCatalog.frames.map(deviceFrameSummary)
            if arguments.contains("--json") || rest.contains("--json") {
                try printJSON(summaries)
            } else {
                for summary in summaries {
                    print("\(summary.id)\t\(summary.device)\t\(summary.orientation)\t\(summary.screenPoints)pt\t\(summary.frameStyle)")
                }
            }
        case "show", "current":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let frame = try customization(for: profile, arguments: rest).deviceCanvas.editorDeviceFrame
            if rest.contains("--json") {
                try printJSON(deviceFrameSummary(frame))
            } else {
                print("Profile: \(profile.name)")
                print("Device frame: \(frame.displayName)")
                print("ID: \(frame.id)")
                print("Screen: \(formatSize(frame.screenRect.size)) pt")
                print("Native: \(formatSize(frame.spec.nativePixels)) px @\(formatScale(frame.spec.nativeScale))")
                print("Frame style: \(frame.frameStyle.displayName)")
            }
        case "set", "select", "use":
            guard let target = firstPositional(in: rest) else { throw CLIError.message("Usage: pocketpad device set <device-or-frame-id|custom|WIDTHxHEIGHT> [--orientation landscape|portrait] [--profile PROFILE]") }
            let orientationText = optionValue("--orientation", in: rest) ?? optionValue("--device-orientation", in: rest)
            let orientation = try orientationText.map(parseDeviceOrientation)
            let frame = try resolveDeviceFrameTarget(target, arguments: rest, preferredOrientation: orientation)
            try saveEditorDeviceFrame(frame, profileTarget: optionValue("--profile", in: rest), variant: try customizationVariant(in: rest))
            print("Selected device frame for profile: \(frame.displayName) (\(formatSize(frame.screenRect.size)) pt)")
        default:
            let orientationText = optionValue("--orientation", in: rest) ?? optionValue("--device-orientation", in: rest)
            let orientation = try orientationText.map(parseDeviceOrientation)
            if let frame = GamepadEditorDeviceCatalog.frame(matching: subcommand, preferredOrientation: orientation) {
                try saveEditorDeviceFrame(frame, profileTarget: optionValue("--profile", in: rest), variant: try customizationVariant(in: rest))
                print("Selected device frame for profile: \(frame.displayName) (\(formatSize(frame.screenRect.size)) pt)")
            } else {
                throw CLIError.message("Unknown device subcommand: \(subcommand)")
            }
        }
    }

    private static func saveEditorDeviceFrame(_ frame: GamepadEditorDeviceFrame, profileTarget: String?, variant: GamepadEditorDeviceOrientation? = nil) throws {
        try mutateCustomization(profileTarget: profileTarget, variant: variant) { customization in
            customization.deviceCanvas = GamepadDeviceCanvas(frameID: frame.id)
        }

        var domain = loadAppDomain()
        domain[GamepadEditorDeviceCatalog.selectedFrameDefaultsKey] = frame.id
        domain[GamepadEditorDeviceCatalog.didChooseFrameDefaultsKey] = true
        UserDefaults.standard.setPersistentDomain(domain, forName: appDefaultsDomain)
        UserDefaults.standard.synchronize()
    }

    private static func resolveDeviceFrame(_ target: String, preferredOrientation: GamepadEditorDeviceOrientation?) throws -> GamepadEditorDeviceFrame {
        guard let frame = GamepadEditorDeviceCatalog.frame(matching: target, preferredOrientation: preferredOrientation) else {
            throw CLIError.message("Unknown iPhone device frame: \(target). Run `pocketpad device list` to see supported frames or use WIDTHxHEIGHT for a custom canvas.")
        }
        return frame
    }

    private static func resolveDeviceFrameTarget(_ target: String, arguments: [String], preferredOrientation: GamepadEditorDeviceOrientation?) throws -> GamepadEditorDeviceFrame {
        if normalizedLookup(target) == "custom" {
            if let sizeText = optionValue("--size", in: arguments) ?? optionValue("--device-size", in: arguments) {
                return try resolveCustomDeviceFrame(sizeText: sizeText, preferredOrientation: preferredOrientation)
            }
            let widthText = optionValue("--width", in: arguments) ?? optionValue("--device-width", in: arguments)
            let heightText = optionValue("--height", in: arguments) ?? optionValue("--device-height", in: arguments)
            guard let widthText, let heightText else {
                throw CLIError.message("Custom device frames need --size WIDTHxHEIGHT or --width W --height H.")
            }
            guard let frame = GamepadEditorDeviceCatalog.customFrame(width: try parsePixels(widthText), height: try parsePixels(heightText), preferredOrientation: preferredOrientation) else {
                throw CLIError.message("Invalid custom device size.")
            }
            return frame
        }

        if let sizeText = optionValue("--size", in: arguments) ?? optionValue("--device-size", in: arguments) {
            return try resolveCustomDeviceFrame(sizeText: sizeText, preferredOrientation: preferredOrientation)
        }

        return try resolveDeviceFrame(target, preferredOrientation: preferredOrientation)
    }

    private static func resolveCustomDeviceFrame(sizeText: String, preferredOrientation: GamepadEditorDeviceOrientation?) throws -> GamepadEditorDeviceFrame {
        guard let size = parseCanvasSizeLiteral(sizeText),
              let frame = GamepadEditorDeviceCatalog.customFrame(width: size.width, height: size.height, preferredOrientation: preferredOrientation)
        else {
            throw CLIError.message("Invalid custom device size: \(sizeText). Use WIDTHxHEIGHT, such as 844x390.")
        }
        return frame
    }

    private static func parseDeviceOrientation(_ text: String) throws -> GamepadEditorDeviceOrientation {
        switch normalizedLookup(text) {
        case "landscape", "horizontal":
            return .landscape
        case "portrait", "vertical":
            return .portrait
        default:
            throw CLIError.message("Unknown device orientation: \(text). Use landscape or portrait.")
        }
    }

    private static func deviceFrameSummary(_ frame: GamepadEditorDeviceFrame) -> DeviceFrameSummary {
        DeviceFrameSummary(
            id: frame.id,
            device: frame.spec.displayName,
            orientation: frame.orientation.rawValue,
            screenPoints: formatSize(frame.screenRect.size),
            nativePixels: formatSize(frame.spec.nativePixels),
            scale: Double(frame.spec.scale),
            nativeScale: Double(frame.spec.nativeScale),
            frameStyle: frame.frameStyle.rawValue,
            modelIdentifiers: frame.spec.modelIdentifiers
        )
    }

    // MARK: - Elements

    private static func element(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing element subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let summaries = elementSummaries(for: try customization(for: profile, arguments: rest))
            if rest.contains("--json") {
                try printJSON(summaries)
            } else {
                for item in summaries {
                    print("\(item.id)\t\(item.kind)\t\(item.label)\t\(item.isHidden ? "hidden" : "visible")\(item.isLocationLocked ? " locked" : "")")
                }
            }
        case "add":
            try addElement(arguments: rest)
        case "set":
            try setElement(arguments: rest)
        case "nudge", "move":
            try nudgeElement(arguments: rest)
        case "delete", "rm":
            try deleteElement(arguments: rest)
        case "reset":
            try resetElement(arguments: rest)
        default:
            throw CLIError.message("Unknown element subcommand: \(subcommand)")
        }
    }

    private static func addElement(arguments: [String]) throws {
        guard let kindText = firstPositional(in: arguments) else { throw CLIError.message("Usage: pocketpad element add <button|joystick|trigger|trackpad|decoration> [options]") }
        let kind = try parseCustomControlKind(kindText)
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments), variant: try customizationVariant(in: arguments)) { customization in
            guard customization.customButtons.count < GamepadCustomization.maximumCustomButtons else { throw CLIError.message("Maximum custom element count reached") }
            if kind == .joystick && customization.customButtons.filter({ $0.normalized.isJoystick }).count >= GamepadCustomization.maximumJoysticks {
                throw CLIError.message("Maximum joystick count reached")
            }
            if kind == .trigger && customization.customButtons.filter({ $0.normalized.isTrigger }).count >= GamepadCustomization.maximumTriggers {
                throw CLIError.message("Maximum trigger count reached")
            }
            if kind == .trackpad && customization.customButtons.filter({ $0.normalized.isTrackpad }).count >= GamepadCustomization.maximumTrackpads {
                throw CLIError.message("Maximum trackpad count reached")
            }

            let id = UUID()
            let triggerCount = customization.customButtons.filter { $0.normalized.isTrigger }.count
            let defaultTriggerTarget: VirtualGamepadTrigger = triggerCount == 0 ? .left : .right
            let mapped = try optionValue("--maps-to", in: arguments).map(parseButton) ?? (kind == .joystick ? .up : (kind == .decoration ? .custom8 : firstAvailableCustomSlot(in: customization) ?? .custom1))
            var customButton = GamepadCustomButton(
                id: id,
                mappedButton: mapped,
                label: optionValue("--label", in: arguments) ?? (kind == .trigger ? defaultTriggerTarget.shortName : defaultLabel(for: kind)),
                controlKind: kind,
                joystickMapping: kind == .joystick ? try joystickMapping(from: arguments) : nil,
                joystickOutputSettings: kind == .joystick ? try joystickOutputSettings(from: arguments) : nil,
                triggerSettings: kind == .trigger ? try triggerSettings(from: arguments, fallback: GamepadTriggerSettings(target: defaultTriggerTarget, orientation: .horizontal)) : nil,
                trackpadSettings: kind == .trackpad ? .defaultValue : nil
            )
            try applyLayoutOptions(arguments, to: &customButton.layout)
            if kind == .joystick {
                customButton.layout.shape = .circle
                let defaultScale: CGFloat = customButton.layout.joystickVisualStyle == .thumbstick ? 0.58 : 1.35
                customButton.layout.widthScale = customButton.layout.widthScale == 1.0 ? defaultScale : customButton.layout.widthScale
                customButton.layout.heightScale = customButton.layout.heightScale == 1.0 ? defaultScale : customButton.layout.heightScale
                customButton.joystickMapping = try joystickMapping(from: arguments)
                customButton.joystickOutputSettings = try joystickOutputSettings(from: arguments, fallback: customButton.joystickOutputSettings ?? .defaultValue)
                customButton.triggerSettings = nil
            } else if kind == .trigger {
                let settings = try triggerSettings(from: arguments, fallback: customButton.triggerSettings ?? .defaultValue)
                customButton.layout.shape = .capsule
                customButton.layout.widthScale = customButton.layout.widthScale == 1.0 ? 1.08 : customButton.layout.widthScale
                customButton.layout.heightScale = customButton.layout.heightScale == 1.0 ? 0.42 : customButton.layout.heightScale
                if optionValue("--x", in: arguments) == nil && optionValue("--center-x", in: arguments) == nil {
                    customButton.layout.centerX = settings.target == .left ? 0.20 : 0.80
                }
                if optionValue("--y", in: arguments) == nil && optionValue("--center-y", in: arguments) == nil {
                    customButton.layout.centerY = 0.14
                }
                customButton.joystickMapping = nil
                customButton.triggerSettings = settings
                customButton.trackpadSettings = nil
            } else if kind == .trackpad {
                customButton.layout.shape = customButton.layout.shape ?? .roundedRectangle
                customButton.layout.widthScale = customButton.layout.widthScale == 1.0 ? 1.25 : customButton.layout.widthScale
                customButton.layout.heightScale = customButton.layout.heightScale == 1.0 ? 1.0 : customButton.layout.heightScale
                if optionValue("--y", in: arguments) == nil && optionValue("--center-y", in: arguments) == nil {
                    customButton.layout.centerY = 0.58
                }
                if optionValue("--corner", in: arguments) == nil && optionValue("--radius", in: arguments) == nil {
                    customButton.layout.cornerRadius = customButton.layout.cornerRadius ?? 18
                }
                customButton.triggerSettings = nil
                customButton.trackpadSettings = try trackpadSettings(from: arguments)
            } else if kind == .decoration {
                customButton.layout.shape = customButton.layout.shape ?? .roundedRectangle
                customButton.layout.widthScale = customButton.layout.widthScale == 1.0 ? 2.2 : customButton.layout.widthScale
                customButton.layout.heightScale = customButton.layout.heightScale == 1.0 ? 1.2 : customButton.layout.heightScale
                customButton.layout.shadowStrength = 0
                customButton.layout.visualStyle = customButton.layout.visualStyle ?? .softWhitePlate()
                if optionValue("--corner", in: arguments) == nil && optionValue("--radius", in: arguments) == nil {
                    customButton.layout.cornerRadius = customButton.layout.cornerRadius ?? 28
                }
                customButton.joystickMapping = nil
                customButton.triggerSettings = nil
                customButton.trackpadSettings = nil
            }
            customization.customButtons.append(customButton)
            if kind != .decoration && hasAnyOption(elementOutputOptionNames, in: arguments) {
                try applyElementOutputOptions(arguments, target: .custom(id), to: &customization)
            }
        }
        print("Added \(kind.displayName.lowercased()).")
    }

    private static func setElement(arguments: [String]) throws {
        guard let targetText = firstPositional(in: arguments) else { throw CLIError.message("Missing element id, button, or label") }
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments), variant: try customizationVariant(in: arguments)) { customization in
            let target = try resolveElementTarget(targetText, in: customization)
            switch target {
            case .builtin(let button):
                if let label = optionValue("--label", in: arguments) { customization.setLabel(label, for: button) }
                var layout = customization.buttonCustomization(for: button)
                try applyLayoutOptions(arguments, to: &layout)
                customization.setButtonCustomization(layout, for: button)
            case .custom(let id):
                guard let index = customization.customButtons.firstIndex(where: { $0.id == id }) else { throw CLIError.message("Custom element not found") }
                if let label = optionValue("--label", in: arguments) { customization.customButtons[index].label = normalizedLabel(label) }
                if let mapped = optionValue("--maps-to", in: arguments) { customization.customButtons[index].mappedButton = try parseButton(mapped) }
                if let kind = optionValue("--kind", in: arguments) { customization.customButtons[index].controlKind = try parseCustomControlKind(kind) }
                let currentKind = customization.customButtons[index].controlKind
                let hasJoystickOptions = hasAnyOption(joystickOptionNames, in: arguments)
                    || (currentKind == .joystick && hasAnyOption(["--target", "--dead-zone", "--deadzone", "--sensitivity"], in: arguments))
                let hasTriggerOptions = hasAnyOption(triggerOptionNames, in: arguments)
                let hasTrackpadOptions = hasAnyOption(trackpadOptionNames, in: arguments)
                if customization.customButtons[index].controlKind == .joystick || hasJoystickOptions {
                    customization.customButtons[index].controlKind = .joystick
                    customization.customButtons[index].joystickMapping = try joystickMapping(from: arguments, fallback: customization.customButtons[index].joystickMapping ?? .movement)
                    customization.customButtons[index].joystickOutputSettings = try joystickOutputSettings(from: arguments, fallback: customization.customButtons[index].joystickOutputSettings ?? .defaultValue)
                    customization.customButtons[index].triggerSettings = nil
                    customization.customButtons[index].trackpadSettings = nil
                    customization.customButtons[index].layout.shape = .circle
                } else if customization.customButtons[index].controlKind == .trigger || hasTriggerOptions {
                    customization.customButtons[index].controlKind = .trigger
                    customization.customButtons[index].joystickMapping = nil
                    customization.customButtons[index].joystickOutputSettings = nil
                    customization.customButtons[index].triggerSettings = try triggerSettings(from: arguments, fallback: customization.customButtons[index].triggerSettings ?? .defaultValue)
                    customization.customButtons[index].trackpadSettings = nil
                    customization.customButtons[index].layout.shape = .capsule
                } else if customization.customButtons[index].controlKind == .trackpad || hasTrackpadOptions {
                    customization.customButtons[index].controlKind = .trackpad
                    customization.customButtons[index].joystickMapping = nil
                    customization.customButtons[index].joystickOutputSettings = nil
                    customization.customButtons[index].triggerSettings = nil
                    customization.customButtons[index].layout.shape = customization.customButtons[index].layout.shape ?? .roundedRectangle
                    customization.customButtons[index].trackpadSettings = try trackpadSettings(from: arguments, fallback: customization.customButtons[index].trackpadSettings ?? .defaultValue)
                } else if customization.customButtons[index].controlKind == .decoration {
                    customization.customButtons[index].joystickMapping = nil
                    customization.customButtons[index].joystickOutputSettings = nil
                    customization.customButtons[index].triggerSettings = nil
                    customization.customButtons[index].trackpadSettings = nil
                    customization.customButtons[index].layout.shape = customization.customButtons[index].layout.shape ?? .roundedRectangle
                    customization.customButtons[index].layout.shadowStrength = 0
                } else if customization.customButtons[index].controlKind == .button {
                    customization.customButtons[index].joystickMapping = nil
                    customization.customButtons[index].joystickOutputSettings = nil
                    customization.customButtons[index].triggerSettings = nil
                    customization.customButtons[index].trackpadSettings = nil
                }
                try applyLayoutOptions(arguments, to: &customization.customButtons[index].layout)
            }

            if hasAnyOption(elementOutputOptionNames, in: arguments) {
                if case .custom(let id) = target,
                   customization.customButtons.first(where: { $0.id == id })?.normalized.isDecoration == true {
                    throw CLIError.message("Decoration elements do not send output")
                }
                try applyElementOutputOptions(arguments, target: target, to: &customization)
            }
        }
        print("Updated element \"\(targetText)\".")
    }

    private static func applyElementOutputOptions(_ arguments: [String], target: ElementTarget, to customization: inout GamepadCustomization) throws {
        let part = try parseElementInputPart(optionValue("--part", in: arguments) ?? optionValue("--input", in: arguments))
        let keyboardText = optionValue("--keyboard", in: arguments) ?? optionValue("--key", in: arguments)
        let sequenceText = optionValue("--sequence", in: arguments)
        let gamepadButtonText = optionValue("--gamepad-button", in: arguments) ?? optionValue("--gamepad", in: arguments)
        let clearOutput = arguments.contains("--clear-output")
        let clearKeyboard = arguments.contains("--clear-keyboard")
        let clearGamepad = arguments.contains("--clear-gamepad")

        var normalizedCustomization = customization.normalized
        let identity: GamepadControlIdentity = switch target {
        case .builtin(let button): .builtin(button)
        case .custom(let id): .custom(id)
        }
        guard let elementID = normalizedCustomization.elementID(for: identity),
              let index = normalizedCustomization.elements.firstIndex(where: { $0.id == elementID })
        else {
            throw CLIError.message("Element is not visible in this layout variant")
        }

        var output = normalizedCustomization.elements[index]
            .outputBinding(for: part)
            .map(MacControlOutputBinding.init(shared:)) ?? MacControlOutputBinding()
        if clearOutput {
            output = MacControlOutputBinding()
        }
        if clearKeyboard {
            output.keyboard = nil
        }
        if let sequenceText {
            output.keyboard = try parseKeyBindingSequence(sequenceText)
        } else if let keyboardText {
            output.keyboard = try parseKeyBindingSequence(keyboardText)
        }
        if clearGamepad {
            output.gamepadButtons.removeAll()
        }
        if let gamepadButtonText {
            let normalized = gamepadButtonText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "none" || normalized == "clear" || normalized == "off" {
                output.gamepadButtons.removeAll()
            } else {
                output.setGamepadButton(try parseVirtualGamepadButton(gamepadButtonText))
            }
        }

        normalizedCustomization.elements[index].setOutputBinding(output.isEmpty ? nil : output.sharedBinding, for: part)
        customization = normalizedCustomization.normalized
    }

    private static func parseElementInputPart(_ text: String?) throws -> KeypadElementInputPart {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .primary }
        let normalized = normalizedLookup(text)
        switch normalized {
        case "primary", "press", "button", "tap":
            return .primary
        case "up", "joystickup", "stickup":
            return .joystickUp
        case "down", "joystickdown", "stickdown":
            return .joystickDown
        case "left", "joystickleft", "stickleft":
            return .joystickLeft
        case "right", "joystickright", "stickright":
            return .joystickRight
        case "trigger", "triggerdigital", "digitaltrigger", "digital":
            return .triggerDigital
        default:
            if let part = KeypadElementInputPart(rawValue: text) { return part }
            throw CLIError.message("Unknown element output part: \(text)")
        }
    }

    private static func nudgeElement(arguments: [String]) throws {
        let positional = positionals(in: arguments)
        guard let targetText = positional.first else {
            throw CLIError.message("Usage: pocketpad element nudge <element> <left|right|up|down> [--step 1|10]")
        }
        let directionText = positional.dropFirst().first
        let translation = try parseNudgeTranslation(arguments: arguments, directionText: directionText)
        let canvasSize = try parseNudgeCanvasSize(arguments)

        var store = loadStore()
        let profileIndex = try resolveProfileIndex(optionValue("--profile", in: arguments), in: store)
        let variant = try customizationVariant(in: arguments)
        let sourceCustomization = variant.map { store.profiles[profileIndex].customization(for: $0) } ?? store.profiles[profileIndex].customization
        let target = try resolveElementTarget(targetText, in: sourceCustomization)
        let identity: GamepadControlIdentity = switch target {
        case .builtin(let button): .builtin(button)
        case .custom(let id): .custom(id)
        }

        guard let nudgedCustomization = sourceCustomization.nudgedControls([identity], by: translation, in: canvasSize) else {
            print("Element \"\(targetText)\" could not move.")
            return
        }

        let normalizedNudgedCustomization = nudgedCustomization.normalized
        if let variant {
            store.profiles[profileIndex].setCustomization(normalizedNudgedCustomization, for: variant)
        } else {
            store.profiles[profileIndex].setCustomization(
                normalizedNudgedCustomization,
                for: normalizedNudgedCustomization.deviceCanvas.editorDeviceFrame.orientation
            )
        }
        store.profiles[profileIndex].updatedAt = Date.currentMilliseconds
        try persistStore(store)
        print("Nudged element \"\(targetText)\" by \(formatPixels(translation.width))px, \(formatPixels(translation.height))px.")
    }

    private static func deleteElement(arguments: [String]) throws {
        guard let targetText = firstPositional(in: arguments) else { throw CLIError.message("Missing element id, button, or label") }
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments), variant: try customizationVariant(in: arguments)) { customization in
            let target = try resolveElementTarget(targetText, in: customization)
            switch target {
            case .builtin(let button):
                var layout = customization.buttonCustomization(for: button)
                layout.isHidden = true
                customization.setButtonCustomization(layout, for: button)
            case .custom(let id):
                customization.removeCustomButton(id: id)
            }
        }
        print("Deleted/hidden element \"\(targetText)\".")
    }

    private static func resetElement(arguments: [String]) throws {
        guard let targetText = firstPositional(in: arguments) else { throw CLIError.message("Missing element id, button, or label") }
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments), variant: try customizationVariant(in: arguments)) { customization in
            let target = try resolveElementTarget(targetText, in: customization)
            switch target {
            case .builtin(let button):
                customization.setButtonCustomization(.defaultValue, for: button)
                customization.setLabel("", for: button)
            case .custom(let id):
                guard let index = customization.customButtons.firstIndex(where: { $0.id == id }) else { return }
                let kind = customization.customButtons[index].normalized.controlKind
                customization.customButtons[index].label = defaultLabel(for: kind)
                switch kind {
                case .joystick:
                    customization.customButtons[index].layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.5,
                        widthScale: 1.35,
                        heightScale: 1.35,
                        shape: .circle
                    )
                    customization.customButtons[index].joystickMapping = customization.customButtons[index].joystickMapping ?? .movement
                    customization.customButtons[index].joystickOutputSettings = customization.customButtons[index].joystickOutputSettings ?? .defaultValue
                    customization.customButtons[index].triggerSettings = nil
                    customization.customButtons[index].trackpadSettings = nil
                case .trackpad:
                    customization.customButtons[index].layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.58,
                        widthScale: 1.25,
                        heightScale: 1.0,
                        shape: .roundedRectangle,
                        cornerRadius: 18
                    )
                    customization.customButtons[index].joystickMapping = nil
                    customization.customButtons[index].trackpadSettings = .defaultValue
                    customization.customButtons[index].triggerSettings = nil
                case .trigger:
                    let target = (customization.customButtons[index].triggerSettings ?? .defaultValue).normalized.target
                    customization.customButtons[index].layout = GamepadButtonCustomization(
                        centerX: target == .left ? 0.20 : 0.80,
                        centerY: 0.14,
                        widthScale: 1.08,
                        heightScale: 0.42,
                        shape: .capsule,
                        accentStyle: .monochrome
                    )
                    customization.customButtons[index].joystickMapping = nil
                    customization.customButtons[index].trackpadSettings = nil
                    customization.customButtons[index].triggerSettings = GamepadTriggerSettings(target: target, orientation: .horizontal)
                case .button:
                    customization.customButtons[index].layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.5,
                        widthScale: 1.0,
                        heightScale: 1.0,
                        shape: .roundedRectangle
                    )
                    customization.customButtons[index].joystickMapping = nil
                    customization.customButtons[index].trackpadSettings = nil
                case .decoration:
                    customization.customButtons[index].layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.5,
                        widthScale: 2.2,
                        heightScale: 1.2,
                        shape: .roundedRectangle,
                        fillColor: GamepadRGBAColor(hexString: "#F2EEF5"),
                        visualStyle: .softWhitePlate(),
                        cornerRadius: 28,
                        shadowStrength: 0
                    )
                    customization.customButtons[index].joystickMapping = nil
                    customization.customButtons[index].joystickOutputSettings = nil
                    customization.customButtons[index].triggerSettings = nil
                    customization.customButtons[index].trackpadSettings = nil
                }
            }
        }
        print("Reset element \"\(targetText)\".")
    }

    private static func applyLayoutOptions(_ arguments: [String], to layout: inout GamepadButtonCustomization) throws {
        if let value = optionValue("--x", in: arguments) ?? optionValue("--center-x", in: arguments), let number = Double(value) { layout.centerX = CGFloat(number) }
        if let value = optionValue("--y", in: arguments) ?? optionValue("--center-y", in: arguments), let number = Double(value) { layout.centerY = CGFloat(number) }
        if let value = optionValue("--width", in: arguments) ?? optionValue("--width-scale", in: arguments), let number = Double(value) { layout.widthScale = CGFloat(number) }
        if let value = optionValue("--height", in: arguments) ?? optionValue("--height-scale", in: arguments), let number = Double(value) { layout.heightScale = CGFloat(number) }
        if let value = optionValue("--shape", in: arguments), let shape = parseShapeStyleIfPresent(value) { layout.shape = shape }
        if let value = optionValue("--joystick-style", in: arguments) ?? optionValue("--stick-style", in: arguments) {
            layout.joystickVisualStyle = try parseJoystickVisualStyle(value)
        }
        if arguments.contains("--thumbstick") {
            layout.joystickVisualStyle = .thumbstick
        }
        if arguments.contains("--classic-joystick") || arguments.contains("--full-joystick") {
            layout.joystickVisualStyle = nil
        }
        if let value = optionValue("--accent", in: arguments), let accent = parseAccentStyleIfPresent(value) {
            layout.accentStyle = accent
            layout.fillColor = nil
            layout.lightFillColor = nil
            layout.darkFillColor = nil
            layout.fillStyle = nil
            layout.lightFillStyle = nil
            layout.darkFillStyle = nil
        }
        if let value = optionValue("--fill", in: arguments) ?? optionValue("--color", in: arguments) {
            layout.fillColor = try parseRGBAColor(value)
            layout.lightFillColor = nil
            layout.darkFillColor = nil
            layout.fillStyle = nil
            layout.lightFillStyle = nil
            layout.darkFillStyle = nil
        }
        if arguments.contains("--clear-fill") || arguments.contains("--clear-color") {
            layout.fillColor = nil
            layout.lightFillColor = nil
            layout.darkFillColor = nil
            layout.fillStyle = nil
            layout.lightFillStyle = nil
            layout.darkFillStyle = nil
        }
        if let value = optionValue("--fill-gradient", in: arguments) ?? optionValue("--gradient", in: arguments) {
            setLayoutFillStyle(try parseGradientFill(value, arguments: arguments), in: &layout)
        }
        if let value = optionValue("--fill-tile", in: arguments) ?? optionValue("--tile", in: arguments) {
            setLayoutFillStyle(try parseTileFill(value, arguments: arguments), in: &layout)
        }
        if let value = optionValue("--fill-image", in: arguments) ?? optionValue("--image", in: arguments) {
            setLayoutFillStyle(try parseImageFill(value, arguments: arguments), in: &layout)
        }
        if arguments.contains("--clear-fill-style") {
            layout.fillStyle = nil
            layout.lightFillStyle = nil
            layout.darkFillStyle = nil
        }
        if let value = optionValue("--light-fill", in: arguments) ?? optionValue("--fill-light", in: arguments) ?? optionValue("--light-color", in: arguments) {
            setLayoutFillColor(try parseRGBAColor(value), isDark: false, in: &layout)
        }
        if let value = optionValue("--dark-fill", in: arguments) ?? optionValue("--fill-dark", in: arguments) ?? optionValue("--dark-color", in: arguments) {
            setLayoutFillColor(try parseRGBAColor(value), isDark: true, in: &layout)
        }
        if let value = optionValue("--light-fill-gradient", in: arguments) ?? optionValue("--gradient-light", in: arguments) {
            setLayoutFillStyle(try parseGradientFill(value, arguments: arguments), isDark: false, in: &layout)
        }
        if let value = optionValue("--dark-fill-gradient", in: arguments) ?? optionValue("--gradient-dark", in: arguments) {
            setLayoutFillStyle(try parseGradientFill(value, arguments: arguments), isDark: true, in: &layout)
        }
        if let value = optionValue("--light-fill-tile", in: arguments) ?? optionValue("--tile-light", in: arguments) {
            setLayoutFillStyle(try parseTileFill(value, arguments: arguments), isDark: false, in: &layout)
        }
        if let value = optionValue("--dark-fill-tile", in: arguments) ?? optionValue("--tile-dark", in: arguments) {
            setLayoutFillStyle(try parseTileFill(value, arguments: arguments), isDark: true, in: &layout)
        }
        if arguments.contains("--clear-light-fill") || arguments.contains("--clear-light-color") {
            clearLayoutFillColor(isDark: false, in: &layout)
        }
        if arguments.contains("--clear-dark-fill") || arguments.contains("--clear-dark-color") {
            clearLayoutFillColor(isDark: true, in: &layout)
        }
        if let value = optionValue("--thumb-fill", in: arguments) ?? optionValue("--thumb-color", in: arguments) ?? optionValue("--joystick-thumb-fill", in: arguments) ?? optionValue("--joystick-knob-fill", in: arguments) {
            layout.joystickKnobColor = try parseRGBAColor(value)
            layout.lightJoystickKnobColor = nil
            layout.darkJoystickKnobColor = nil
        }
        if arguments.contains("--clear-thumb-fill") || arguments.contains("--clear-thumb-color") || arguments.contains("--clear-joystick-thumb-fill") || arguments.contains("--clear-joystick-knob-fill") {
            layout.joystickKnobColor = nil
            layout.lightJoystickKnobColor = nil
            layout.darkJoystickKnobColor = nil
        }
        if let value = optionValue("--light-thumb-fill", in: arguments) ?? optionValue("--thumb-light", in: arguments) ?? optionValue("--light-thumb-color", in: arguments) {
            setLayoutJoystickKnobColor(try parseRGBAColor(value), isDark: false, in: &layout)
        }
        if let value = optionValue("--dark-thumb-fill", in: arguments) ?? optionValue("--thumb-dark", in: arguments) ?? optionValue("--dark-thumb-color", in: arguments) {
            setLayoutJoystickKnobColor(try parseRGBAColor(value), isDark: true, in: &layout)
        }
        if arguments.contains("--clear-light-thumb-fill") || arguments.contains("--clear-light-thumb-color") {
            clearLayoutJoystickKnobColor(isDark: false, in: &layout)
        }
        if arguments.contains("--clear-dark-thumb-fill") || arguments.contains("--clear-dark-thumb-color") {
            clearLayoutJoystickKnobColor(isDark: true, in: &layout)
        }
        if let value = optionValue("--thumb-opacity", in: arguments), let opacity = parseOpacityIfPresent(value) {
            var color = layout.joystickKnobColor ?? .defaultValue
            color.alpha = opacity
            layout.joystickKnobColor = color
        }
        if let value = optionValue("--light-thumb-opacity", in: arguments), let opacity = parseOpacityIfPresent(value) {
            var color = layoutJoystickKnobColor(isDark: false, in: layout) ?? .defaultValue
            color.alpha = opacity
            setLayoutJoystickKnobColor(color, isDark: false, in: &layout)
        }
        if let value = optionValue("--dark-thumb-opacity", in: arguments), let opacity = parseOpacityIfPresent(value) {
            var color = layoutJoystickKnobColor(isDark: true, in: layout) ?? .defaultValue
            color.alpha = opacity
            setLayoutJoystickKnobColor(color, isDark: true, in: &layout)
        }
        if let value = optionValue("--opacity", in: arguments), let opacity = parseOpacityIfPresent(value) {
            var color = layout.fillColor ?? .defaultValue
            color.alpha = opacity
            layout.fillColor = color
        }
        if let value = optionValue("--light-opacity", in: arguments), let opacity = parseOpacityIfPresent(value) {
            var color = layoutFillColor(isDark: false, in: layout) ?? .defaultValue
            color.alpha = opacity
            setLayoutFillColor(color, isDark: false, in: &layout)
        }
        if let value = optionValue("--dark-opacity", in: arguments), let opacity = parseOpacityIfPresent(value) {
            var color = layoutFillColor(isDark: true, in: layout) ?? .defaultValue
            color.alpha = opacity
            setLayoutFillColor(color, isDark: true, in: &layout)
        }
        if let styleID = optionValue("--style", in: arguments) ?? optionValue("--style-id", in: arguments) {
            layout.styleID = styleID
        }
        if arguments.contains("--clear-style") || arguments.contains("--detach-style") {
            layout.styleID = nil
        }
        if let icon = try parseIconOption(arguments) {
            layout.icon = icon
        }
        if arguments.contains("--clear-icon") {
            layout.icon = nil
        }
        let existingHapticFeedback = layout.hapticFeedback ?? layout.hapticStyle.map { GamepadHapticFeedback(style: $0) }
        if let haptic = try parseHapticFeedbackOptions(arguments, existing: existingHapticFeedback) {
            setHapticFeedback(haptic, in: &layout)
        }
        if arguments.contains("--clear-haptic") {
            layout.hapticStyle = nil
            layout.hapticFeedback = nil
        }
        try applyRichVisualOptions(arguments, to: &layout)
        if let value = optionValue("--corner", in: arguments) ?? optionValue("--radius", in: arguments), let radius = Double(value) {
            layout.shape = .roundedRectangle
            layout.cornerRadius = CGFloat(radius)
            layout.cornerRadii = nil
        }
        var radii = layout.resolvedCornerRadii()
        var changedRadii = false
        for (option, corner) in [("--corner-tl", GamepadCorner.topLeading), ("--corner-tr", .topTrailing), ("--corner-br", .bottomTrailing), ("--corner-bl", .bottomLeading)] {
            if let value = optionValue(option, in: arguments), let radius = Double(value) {
                radii[corner] = CGFloat(radius)
                changedRadii = true
            }
        }
        if changedRadii {
            layout.shape = .roundedRectangle
            layout.cornerRadius = nil
            layout.cornerRadii = radii
        }
        if let value = optionValue("--shadow", in: arguments) ?? optionValue("--shadow-strength", in: arguments), let shadow = Double(value) { layout.shadowStrength = CGFloat(shadow) }
        if arguments.contains("--hide") || arguments.contains("--hidden") { layout.isHidden = true }
        if arguments.contains("--show") || arguments.contains("--visible") { layout.isHidden = false }
        if arguments.contains("--lock") || arguments.contains("--locked") { layout.isLocationLocked = true }
        if arguments.contains("--unlock") || arguments.contains("--unlocked") { layout.isLocationLocked = false }
    }

    private static func layoutFillColor(isDark: Bool, in layout: GamepadButtonCustomization) -> GamepadRGBAColor? {
        isDark ? (layout.darkFillColor ?? layout.fillColor) : (layout.lightFillColor ?? layout.fillColor)
    }

    private static func setLayoutFillColor(_ color: GamepadRGBAColor, isDark: Bool, in layout: inout GamepadButtonCustomization) {
        prepareSchemeSpecificFillStorage(in: &layout)
        if isDark {
            layout.darkFillColor = color.normalized
            layout.darkFillStyle = nil
        } else {
            layout.lightFillColor = color.normalized
            layout.lightFillStyle = nil
        }
    }

    private static func setLayoutFillStyle(_ style: GamepadFillStyle, in layout: inout GamepadButtonCustomization) {
        layout.fillStyle = style.normalized
        layout.fillColor = nil
        layout.lightFillColor = nil
        layout.darkFillColor = nil
        layout.lightFillStyle = nil
        layout.darkFillStyle = nil
    }

    private static func setLayoutFillStyle(_ style: GamepadFillStyle, isDark: Bool, in layout: inout GamepadButtonCustomization) {
        prepareSchemeSpecificFillStorage(in: &layout)
        if isDark {
            layout.darkFillStyle = style.normalized
            layout.darkFillColor = nil
        } else {
            layout.lightFillStyle = style.normalized
            layout.lightFillColor = nil
        }
    }

    private static func clearLayoutFillColor(isDark: Bool, in layout: inout GamepadButtonCustomization) {
        prepareSchemeSpecificFillStorage(in: &layout)
        if isDark {
            layout.darkFillColor = nil
            layout.darkFillStyle = nil
        } else {
            layout.lightFillColor = nil
            layout.lightFillStyle = nil
        }
    }

    private static func layoutJoystickKnobColor(isDark: Bool, in layout: GamepadButtonCustomization) -> GamepadRGBAColor? {
        isDark ? (layout.darkJoystickKnobColor ?? layout.joystickKnobColor) : (layout.lightJoystickKnobColor ?? layout.joystickKnobColor)
    }

    private static func setLayoutJoystickKnobColor(_ color: GamepadRGBAColor, isDark: Bool, in layout: inout GamepadButtonCustomization) {
        prepareSchemeSpecificJoystickKnobColorStorage(in: &layout)
        if isDark {
            layout.darkJoystickKnobColor = color.normalized
        } else {
            layout.lightJoystickKnobColor = color.normalized
        }
    }

    private static func clearLayoutJoystickKnobColor(isDark: Bool, in layout: inout GamepadButtonCustomization) {
        prepareSchemeSpecificJoystickKnobColorStorage(in: &layout)
        if isDark {
            layout.darkJoystickKnobColor = nil
        } else {
            layout.lightJoystickKnobColor = nil
        }
    }

    private static func prepareSchemeSpecificJoystickKnobColorStorage(in layout: inout GamepadButtonCustomization) {
        if let legacyColor = layout.joystickKnobColor?.normalized {
            if layout.lightJoystickKnobColor == nil {
                layout.lightJoystickKnobColor = legacyColor
            }
            if layout.darkJoystickKnobColor == nil {
                layout.darkJoystickKnobColor = legacyColor
            }
        }
        layout.joystickKnobColor = nil
    }

    private static func prepareSchemeSpecificFillStorage(in layout: inout GamepadButtonCustomization) {
        if let legacyFillColor = layout.fillColor?.normalized {
            if layout.lightFillColor == nil {
                layout.lightFillColor = legacyFillColor
            }
            if layout.darkFillColor == nil {
                layout.darkFillColor = legacyFillColor
            }
        }
        if let legacyFillStyle = layout.fillStyle?.normalized {
            if layout.lightFillStyle == nil {
                layout.lightFillStyle = legacyFillStyle
            }
            if layout.darkFillStyle == nil {
                layout.darkFillStyle = legacyFillStyle
            }
        }
        layout.fillColor = nil
        layout.fillStyle = nil
    }

    private static func setBackgroundFillColor(_ color: GamepadRGBAColor, in customization: inout GamepadCustomization) {
        customization.backgroundLightColor = color.normalized
        customization.backgroundDarkColor = color.normalized
        customization.backgroundFillStyle = nil
        customization.backgroundLightFillStyle = nil
        customization.backgroundDarkFillStyle = nil
    }

    private static func setBackgroundFillColor(_ color: GamepadRGBAColor, isDark: Bool, in customization: inout GamepadCustomization) {
        customization.prepareSchemeSpecificBackgroundFillStorage()
        if isDark {
            customization.backgroundDarkColor = color.normalized
            customization.backgroundDarkFillStyle = nil
        } else {
            customization.backgroundLightColor = color.normalized
            customization.backgroundLightFillStyle = nil
        }
    }

    private static func setBackgroundFillStyle(_ style: GamepadFillStyle, in customization: inout GamepadCustomization) {
        customization.backgroundFillStyle = style.normalized
        customization.backgroundLightColor = nil
        customization.backgroundDarkColor = nil
        customization.backgroundLightFillStyle = nil
        customization.backgroundDarkFillStyle = nil
    }

    private static func setBackgroundFillStyle(_ style: GamepadFillStyle, isDark: Bool, in customization: inout GamepadCustomization) {
        customization.prepareSchemeSpecificBackgroundFillStorage()
        if isDark {
            customization.backgroundDarkFillStyle = style.normalized
            customization.backgroundDarkColor = nil
        } else {
            customization.backgroundLightFillStyle = style.normalized
            customization.backgroundLightColor = nil
        }
    }

    private static func clearBackgroundFill(in customization: inout GamepadCustomization) {
        customization.backgroundLightColor = nil
        customization.backgroundDarkColor = nil
        customization.backgroundFillStyle = nil
        customization.backgroundLightFillStyle = nil
        customization.backgroundDarkFillStyle = nil
    }

    // MARK: - Runtime commands

    private static func server(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing server subcommand") }
        switch subcommand {
        case "start":
            try openApp()
            postRuntimeCommand(.start)
            print("Requested server start.")
        case "stop":
            postRuntimeCommand(.stop)
            print("Requested server stop.")
        case "restart":
            try openApp()
            postRuntimeCommand(.restart)
            print("Requested server restart.")
        case "status":
            try printRuntimeStatus(json: arguments.contains("--json"))
        case "addresses", "urls":
            let status = try readFreshRuntimeStatus()
            for url in status.localURLs { print(url) }
        default:
            throw CLIError.message("Unknown server subcommand: \(subcommand)")
        }
    }

    private static func pairing(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing pairing subcommand") }
        switch subcommand {
        case "code":
            print(try readFreshRuntimeStatus().pairingCode)
        case "payload":
            let status = try readFreshRuntimeStatus()
            let payload = PairingPayload(
                urls: status.localURLs,
                pairingCode: status.pairingCode,
                serviceName: status.bonjourServiceName,
                serviceType: status.bonjourServiceType,
                serviceDomain: status.bonjourServiceDomain,
                serverID: status.serverID
            )
            try printJSON(payload)
        case "cancel":
            postRuntimeCommand(.cancelPairing)
            print("Requested pairing cancel.")
        default:
            throw CLIError.message("Unknown pairing subcommand: \(subcommand)")
        }
    }

    private static func accessibility(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing accessibility subcommand") }
        switch subcommand {
        case "status":
            postRuntimeCommand(.refreshAccessibility)
            let status = try readFreshRuntimeStatus()
            print(status.accessibilityTrusted ? "granted" : "required")
        case "prompt", "request":
            postRuntimeCommand(.promptAccessibility)
            print("Requested Accessibility permission prompt.")
        case "open", "settings":
            postRuntimeCommand(.openAccessibilitySettings)
            print("Opened Accessibility settings.")
        case "refresh":
            postRuntimeCommand(.refreshAccessibility)
            print("Requested Accessibility status refresh.")
        default:
            throw CLIError.message("Unknown accessibility subcommand: \(subcommand)")
        }
    }

    private static func test(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing test subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "down":
            let button = try parseButton(firstPositional(in: rest) ?? "jump")
            postRuntimeCommand(.testDown, button: button)
            print("Sent test down for \(button.displayName).")
        case "up":
            let button = try parseButton(firstPositional(in: rest) ?? "jump")
            postRuntimeCommand(.testUp, button: button)
            print("Sent test up for \(button.displayName).")
        case "tap":
            let button = try parseButton(firstPositional(in: rest) ?? "jump")
            let holdMS = Int(optionValue("--hold-ms", in: rest) ?? "120") ?? 120
            postRuntimeCommand(.testDown, button: button)
            Thread.sleep(forTimeInterval: Double(max(0, holdMS)) / 1000.0)
            postRuntimeCommand(.testUp, button: button)
            print("Tapped \(button.displayName).")
        default:
            throw CLIError.message("Unknown test subcommand: \(subcommand)")
        }
    }

    private static func latency(arguments: [String]) throws {
        if arguments.first == "verify" {
            try verifyLatency(arguments: Array(arguments.dropFirst()))
            return
        }

        let rest = arguments.first == "simulate" ? Array(arguments.dropFirst()) : arguments
        let options = try parseLatencyOptions(rest)
        let modes: [PocketPadLatencySimulationMode]
        if let mode = options.mode {
            modes = [mode]
        } else {
            modes = [.current, .legacyMainActor]
        }
        let reports = modes.map {
            PocketPadInputLatencySimulator.run(pattern: options.pattern, mode: $0)
        }

        if let logPath = options.logPath {
            try writeJSON(reports, to: logPath)
        }

        if options.printJSON {
            try printJSON(reports)
        } else {
            printLatencyReports(reports, logPath: options.logPath)
        }
    }

    private static func verifyLatency(arguments: [String]) throws {
        let options = try parseLatencyVerificationOptions(arguments)
        let report = PocketPadInputLatencySimulator.verifyCurrentPath(
            maxAllowedMilliseconds: options.maxAllowedMilliseconds,
            p95AllowedMilliseconds: options.p95AllowedMilliseconds
        )

        if let logPath = options.logPath {
            try writeJSON(report, to: logPath)
        }

        if options.printJSON {
            try printJSON(report)
        } else {
            printLatencyVerificationReport(report, logPath: options.logPath)
        }

        guard report.passed else {
            throw CLIError.message("Latency verification failed")
        }
    }

    private struct LatencyOptions {
        var pattern: PocketPadLatencySimulationPattern = .hollowKnight
        var mode: PocketPadLatencySimulationMode?
        var printJSON = false
        var logPath: String?
    }

    private struct LatencyVerificationOptions {
        var maxAllowedMilliseconds = 4.0
        var p95AllowedMilliseconds = 4.0
        var printJSON = false
        var logPath: String?
    }

    private static func parseLatencyOptions(_ arguments: [String]) throws -> LatencyOptions {
        var options = LatencyOptions()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--json":
                options.printJSON = true

            case "--pattern":
                index += 1
                guard index < arguments.count else { throw CLIError.message("Missing value for --pattern") }
                guard let pattern = PocketPadLatencySimulationPattern(rawValue: arguments[index]) else {
                    throw CLIError.message("Unsupported latency pattern: \(arguments[index])")
                }
                options.pattern = pattern

            case "--mode":
                index += 1
                guard index < arguments.count else { throw CLIError.message("Missing value for --mode") }
                let value = arguments[index]
                if value == "compare" {
                    options.mode = nil
                } else if let mode = PocketPadLatencySimulationMode(rawValue: value) {
                    options.mode = mode
                } else {
                    throw CLIError.message("Unsupported latency mode: \(value)")
                }

            case "--log":
                index += 1
                guard index < arguments.count else { throw CLIError.message("Missing value for --log") }
                options.logPath = arguments[index]

            case "--help", "-h", "help":
                throw CLIError.message("Usage: pocketpad latency simulate [--pattern hollow-knight|same-button-burst|udp-recovery|udp-recovery-burst|held-direction-heartbeat-recovery] [--mode current|legacy-main-actor|compare] [--json] [--log file.json]")

            default:
                throw CLIError.message("Unknown latency option: \(argument)")
            }

            index += 1
        }

        return options
    }

    private static func parseLatencyVerificationOptions(_ arguments: [String]) throws -> LatencyVerificationOptions {
        var options = LatencyVerificationOptions()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--json":
                options.printJSON = true

            case "--max-ms":
                index += 1
                guard index < arguments.count,
                      let value = Double(arguments[index])
                else {
                    throw CLIError.message("Missing numeric value for --max-ms")
                }
                options.maxAllowedMilliseconds = value

            case "--p95-ms":
                index += 1
                guard index < arguments.count,
                      let value = Double(arguments[index])
                else {
                    throw CLIError.message("Missing numeric value for --p95-ms")
                }
                options.p95AllowedMilliseconds = value

            case "--log":
                index += 1
                guard index < arguments.count else { throw CLIError.message("Missing value for --log") }
                options.logPath = arguments[index]

            case "--help", "-h", "help":
                throw CLIError.message("Usage: pocketpad latency verify [--max-ms 4] [--p95-ms 4] [--json] [--log file.json]")

            default:
                throw CLIError.message("Unknown latency verify option: \(argument)")
            }

            index += 1
        }

        return options
    }

    private static func printLatencyVerificationReport(
        _ report: PocketPadLatencyVerificationReport,
        logPath: String?
    ) {
        print(report.passed ? "Latency verification passed" : "Latency verification failed")
        print("Budget: max <= \(formatMilliseconds(report.maxAllowedMilliseconds)) ms, p95 <= \(formatMilliseconds(report.p95AllowedMilliseconds)) ms")

        for simulation in report.reports {
            let summary = simulation.summary
            print(
                "- \(simulation.pattern.rawValue): p95 \(formatMilliseconds(summary.p95Milliseconds)) ms, " +
                "max \(formatMilliseconds(summary.maxMilliseconds)) ms, over16 \(summary.overSixteenMilliseconds), " +
                "heartbeat re-sync \(simulation.heartbeatResyncFrames)"
            )
        }

        if !report.failures.isEmpty {
            print("Failures:")
            for failure in report.failures {
                print("- \(failure)")
            }
        }

        if let logPath {
            print("Wrote detailed report: \(logPath)")
        }
    }

    private static func printLatencyReports(
        _ reports: [PocketPadLatencySimulationReport],
        logPath: String?
    ) {
        guard let first = reports.first else { return }
        print("Latency simulation: \(first.pattern.displayName)")
        print("Pattern: \(first.pattern.rawValue)")

        for report in reports {
            let summary = report.summary
            print("")
            print(report.mode.displayName)
            print("  p50: \(formatMilliseconds(summary.p50Milliseconds)) ms")
            print("  p95: \(formatMilliseconds(summary.p95Milliseconds)) ms")
            print("  max: \(formatMilliseconds(summary.maxMilliseconds)) ms")
            print("  over 8 ms: \(summary.overEightMilliseconds)/\(summary.sampleCount)")
            print("  over 16 ms: \(summary.overSixteenMilliseconds)/\(summary.sampleCount)")
            print("  recovered by TCP mirror: \(report.recoveredByMirrorFrames)")
            print("  buffered frames: \(report.bufferedFrames)")
            print("  heartbeat re-sync frames: \(report.heartbeatResyncFrames)")

            let worstSamples = report.samples
                .filter { $0.latencyMilliseconds != nil }
                .sorted { ($0.latencyMilliseconds ?? 0) > ($1.latencyMilliseconds ?? 0) }
                .prefix(3)
            for sample in worstSamples {
                print(
                    "  worst seq \(sample.sequenceNumber): \(sample.button.rawValue) \(sample.state.rawValue) " +
                    "\(formatMilliseconds(sample.latencyMilliseconds ?? 0)) ms via \(sample.source ?? "unknown")"
                )
            }
        }

        if reports.count == 2,
           let current = reports.first(where: { $0.mode == .current }),
           let legacy = reports.first(where: { $0.mode == .legacyMainActor })
        {
            let delta = legacy.summary.p95Milliseconds - current.summary.p95Milliseconds
            print("")
            print("p95 improvement vs legacy model: \(formatMilliseconds(delta)) ms")
        }

        if let logPath {
            print("")
            print("Wrote detailed report: \(logPath)")
        }
    }

    private static func formatMilliseconds(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func app(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing app subcommand") }
        switch subcommand {
        case "open", "launch":
            try openApp()
            print("Opened PocketPad Mac.")
        case "quit":
            try quitApp()
            print("Requested PocketPad Mac quit.")
        default:
            throw CLIError.message("Unknown app subcommand: \(subcommand)")
        }
    }

    private static func postRuntimeCommand(_ command: PocketPadMacCLICommand, button: GameButton? = nil, reason: String? = nil) {
        let payload = PocketPadMacCLICommandPayload(command: command, button: button, reason: reason)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(PocketPadMacIPC.commandNotificationName),
            object: nil,
            userInfo: [PocketPadMacIPC.commandDataKey: data],
            deliverImmediately: true
        )
    }

    private static func readFreshRuntimeStatus() throws -> PocketPadMacRuntimeStatus {
        postRuntimeCommand(.publishStatus)
        Thread.sleep(forTimeInterval: 0.12)
        guard let data = dataValue(loadAppDomain()[PocketPadMacIPC.runtimeStatusDefaultsKey]),
              let status = try? JSONDecoder().decode(PocketPadMacRuntimeStatus.self, from: data)
        else {
            throw CLIError.message("No runtime status found. Open PocketPad Mac first with `pocketpad app open`.")
        }
        return status
    }

    private static func printRuntimeStatus(json: Bool) throws {
        let status = try readFreshRuntimeStatus()
        if json {
            try printJSON(status)
        } else {
            print("Status: \(status.statusText)")
            print("Running: \(status.isRunning ? "yes" : "no")")
            print("Client: \(status.clientName)\(status.isClientConnected ? " (connected)" : "")")
            if let clientDeviceInfo = status.clientDeviceInfo {
                if let frame = GamepadEditorDeviceCatalog.suggestedFrame(for: clientDeviceInfo) {
                    print("Client Device: \(frame.spec.displayName) (\(formatSize(frame.screenRect.size)) pt \(frame.orientation.rawValue))")
                } else {
                    let model = clientDeviceInfo.modelIdentifier.map { " \($0)" } ?? ""
                    print("Client Device: \(clientDeviceInfo.deviceName)\(model)")
                }
            }
            print("Port: \(status.port)")
            print("Pairing Code: \(status.pairingCode)")
            print("Accessibility: \(status.accessibilityTrusted ? "granted" : "required")")
            if let serviceName = status.bonjourServiceName, !serviceName.isEmpty {
                let serviceType = status.bonjourServiceType ?? PairingPayload.defaultServiceType
                print("Nearby Service: \(serviceName) (\(serviceType))")
            }
            if !status.localURLs.isEmpty {
                print("Addresses:")
                for url in status.localURLs { print("- \(url)") }
            }
            print("Last Event: \(status.lastReceivedEvent)")
            print("Pressed: \(status.pressedButtons.map(\.rawValue).sorted().joined(separator: ", "))")
            if status.virtualGamepadActive != nil || status.virtualGamepadAvailable != nil || status.virtualGamepadLastError != nil {
                let active = status.virtualGamepadActive == true ? "active" : "inactive"
                let availability = status.virtualGamepadAvailable == false ? "unavailable" : "available"
                print("Virtual Gamepad: \(active), \(availability)")
                if let error = status.virtualGamepadLastError, !error.isEmpty {
                    print("Virtual Gamepad Error: \(error)")
                }
                if let pressed = status.virtualGamepadPressedButtons, !pressed.isEmpty {
                    print("Virtual Gamepad Pressed: \(pressed.map(\.shortName).joined(separator: ", "))")
                }
            }
            print("Frames: missing=\(status.missedButtonFrames) ignored=\(status.ignoredButtonEdges) recovered=\(status.recoveredButtonEdges)")
        }
    }

    // MARK: - Persistence

    private static func loadStore() -> ProfileStore {
        let domain = loadAppDomain()
        let state = loadProfileState(from: domain)
        var profileBindings = loadProfileBindings(from: domain)
        if profileBindings[state.activeProfileID.uuidString] == nil {
            profileBindings[state.activeProfileID.uuidString] = rawBindings(loadActiveKeyBindings(from: domain))
        }
        var profileOutputBindings = loadProfileOutputBindings(from: domain, fallbackProfileKeyBindings: profileBindings)
        if profileOutputBindings[state.activeProfileID.uuidString] == nil {
            let activeBindings = decodedBindings(profileBindings[state.activeProfileID.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings
            let activeProfile = state.activeProfile ?? state.profiles[0]
            profileOutputBindings[state.activeProfileID.uuidString] = rawOutputBindings(
                effectiveOutputBindings(
                    for: activeProfile.outputMode,
                    keyBindings: activeBindings,
                    customOutputBindings: outputBindings(from: activeBindings)
                )
            )
        }
        return ProfileStore(
            profiles: state.profiles,
            activeProfileID: state.activeProfileID,
            defaultProfileID: state.defaultProfileID,
            profileKeyBindings: profileBindings,
            profileOutputBindings: profileOutputBindings
        )
    }

    private static func persistStore(_ inputStore: ProfileStore) throws {
        var store = inputStore
        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: store.profiles,
            activeProfileID: store.activeProfileID,
            defaultProfileID: store.defaultProfileID,
            fallbackCustomization: store.profiles.first?.customization ?? .defaultValue
        )
        store.profiles = state.profiles
        store.activeProfileID = state.activeProfileID
        store.defaultProfileID = state.defaultProfileID

        let validIDs = Set(store.profiles.map { $0.id.uuidString })
        store.profileKeyBindings = store.profileKeyBindings.filter { validIDs.contains($0.key) }
        store.profileOutputBindings = store.profileOutputBindings.filter { validIDs.contains($0.key) }
        let activeProfile = state.activeProfile ?? state.profiles[0]
        let activeBindings = decodedBindings(store.profileKeyBindings[activeProfile.id.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings
        store.profileKeyBindings[activeProfile.id.uuidString] = rawBindings(activeBindings)
        let storedActiveOutputBindings = decodedOutputBindings(store.profileOutputBindings[activeProfile.id.uuidString]) ?? outputBindings(from: activeBindings)
        let activeOutputBindings = effectiveOutputBindings(
            for: activeProfile.outputMode,
            keyBindings: activeBindings,
            customOutputBindings: storedActiveOutputBindings
        )
        store.profileOutputBindings[activeProfile.id.uuidString] = rawOutputBindings(activeOutputBindings)

        var domain = loadAppDomain()
        let stateData = try JSONEncoder().encode(
            StoredProfileState(
                profiles: state.profiles,
                activeProfileID: state.activeProfileID,
                defaultProfileID: state.defaultProfileID
            )
        )
        let activeCustomizationData = try JSONEncoder().encode(activeProfile.customization.normalized)
        let keyBindingsData = try JSONEncoder().encode(rawBindings(activeBindings))
        let profileKeyBindingsData = try JSONEncoder().encode(store.profileKeyBindings)
        let outputBindingsData = try JSONEncoder().encode(rawOutputBindings(activeOutputBindings))
        let profileOutputBindingsData = try JSONEncoder().encode(store.profileOutputBindings)

        domain[GamepadConfigurationProfilePersistence.defaultsKey] = stateData
        domain[GamepadCustomizationPersistence.defaultsKey] = activeCustomizationData
        domain[keyBindingsDefaultsKey] = keyBindingsData
        domain[profileKeyBindingsDefaultsKey] = profileKeyBindingsData
        domain[outputBindingsDefaultsKey] = outputBindingsData
        domain[profileOutputBindingsDefaultsKey] = profileOutputBindingsData

        UserDefaults.standard.setPersistentDomain(domain, forName: appDefaultsDomain)
        UserDefaults.standard.synchronize()
        notifyRunningMacHelper(
            profileStateData: stateData,
            activeCustomizationData: activeCustomizationData,
            keyBindingsData: keyBindingsData,
            profileKeyBindingsData: profileKeyBindingsData,
            outputBindingsData: outputBindingsData,
            profileOutputBindingsData: profileOutputBindingsData
        )
    }

    private static func loadAppDomain() -> [String: Any] {
        UserDefaults.standard.persistentDomain(forName: appDefaultsDomain) ?? [:]
    }

    private static func loadProfileState(from domain: [String: Any]) -> GamepadConfigurationProfilePersistence.LoadedState {
        let activeCustomization: GamepadCustomization
        if let data = dataValue(domain[GamepadCustomizationPersistence.defaultsKey]),
           let decoded = try? JSONDecoder().decode(GamepadCustomization.self, from: data) {
            activeCustomization = decoded.normalized
        } else {
            activeCustomization = .defaultValue
        }

        if let data = dataValue(domain[GamepadConfigurationProfilePersistence.defaultsKey]),
           let stored = try? JSONDecoder().decode(StoredProfileState.self, from: data) {
            return GamepadConfigurationProfilePersistence.normalizedState(
                profiles: stored.profiles,
                activeProfileID: stored.activeProfileID,
                defaultProfileID: stored.defaultProfileID,
                fallbackCustomization: activeCustomization
            )
        }

        return GamepadConfigurationProfilePersistence.normalizedState(
            profiles: [],
            activeProfileID: nil,
            defaultProfileID: nil,
            fallbackCustomization: activeCustomization
        )
    }

    private static func loadProfileBindings(from domain: [String: Any]) -> [String: [String: MacKeyBinding]] {
        guard let data = dataValue(domain[profileKeyBindingsDefaultsKey]),
              let decoded = try? JSONDecoder().decode([String: [String: MacKeyBinding]].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func loadActiveKeyBindings(from domain: [String: Any]) -> [GameButton: MacKeyBinding] {
        guard let data = dataValue(domain[keyBindingsDefaultsKey]),
              let raw = try? JSONDecoder().decode([String: MacKeyBinding].self, from: data),
              let decoded = decodedBindings(raw)
        else { return DefaultKeypadKeyMap.defaultBindings }
        return decoded
    }

    private static func decodedBindings(_ raw: [String: MacKeyBinding]?) -> [GameButton: MacKeyBinding]? {
        guard let raw else { return nil }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, binding in
            guard let button = GameButton(rawValue: key) else { return nil }
            return (button, binding)
        })
    }

    private static func rawBindings(_ bindings: [GameButton: MacKeyBinding]) -> [String: MacKeyBinding] {
        Dictionary(uniqueKeysWithValues: bindings.map { button, binding in (button.rawValue, binding) })
    }

    private static func outputBindings(from keyBindings: [GameButton: MacKeyBinding]) -> [GameButton: MacControlOutputBinding] {
        Dictionary(uniqueKeysWithValues: keyBindings.map { button, binding in
            (button, MacControlOutputBinding.keyboard(binding))
        })
    }

    private static func effectiveOutputBindings(
        for mode: GamepadProfileOutputMode,
        keyBindings: [GameButton: MacKeyBinding],
        customOutputBindings: [GameButton: MacControlOutputBinding]
    ) -> [GameButton: MacControlOutputBinding] {
        switch mode {
        case .keyboard:
            return outputBindings(from: keyBindings)
        case .controller:
            return DefaultMacControlOutputMap.xboxStyleBindings
        case .custom:
            return customOutputBindings.isEmpty ? outputBindings(from: keyBindings) : customOutputBindings
        }
    }

    private static func rawOutputBindings(_ bindings: [GameButton: MacControlOutputBinding]) -> [String: MacControlOutputBinding] {
        Dictionary(uniqueKeysWithValues: bindings.map { button, binding in (button.rawValue, binding) })
    }

    private static func decodedOutputBindings(_ raw: [String: MacControlOutputBinding]?) -> [GameButton: MacControlOutputBinding]? {
        guard let raw else { return nil }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, binding in
            guard let button = GameButton(rawValue: key), !binding.isEmpty else { return nil }
            return (button, binding)
        })
    }

    private static func loadProfileOutputBindings(
        from domain: [String: Any],
        fallbackProfileKeyBindings: [String: [String: MacKeyBinding]]
    ) -> [String: [String: MacControlOutputBinding]] {
        var resolvedOutputBindings = Dictionary(uniqueKeysWithValues: fallbackProfileKeyBindings.map { profileID, rawBindings in
            (profileID, rawOutputBindings(outputBindings(from: decodedBindings(rawBindings) ?? DefaultKeypadKeyMap.defaultBindings)))
        })
        guard let data = dataValue(domain[profileOutputBindingsDefaultsKey]),
              let decoded = try? JSONDecoder().decode([String: [String: MacControlOutputBinding]].self, from: data)
        else { return resolvedOutputBindings }
        for (profileID, bindings) in decoded {
            resolvedOutputBindings[profileID] = bindings
        }
        return resolvedOutputBindings
    }

    private static func dataValue(_ value: Any?) -> Data? {
        if let data = value as? Data { return data }
        if let data = value as? NSData { return data as Data }
        return nil
    }

    private static func notifyRunningMacHelper(
        profileStateData: Data,
        activeCustomizationData: Data?,
        keyBindingsData: Data?,
        profileKeyBindingsData: Data,
        outputBindingsData: Data?,
        profileOutputBindingsData: Data
    ) {
        var userInfo: [String: Any] = [
            notificationProfileStateDataKey: profileStateData,
            notificationProfileKeyBindingsDataKey: profileKeyBindingsData,
            notificationProfileOutputBindingsDataKey: profileOutputBindingsData
        ]
        if let activeCustomizationData { userInfo[notificationActiveCustomizationDataKey] = activeCustomizationData }
        if let keyBindingsData { userInfo[notificationKeyBindingsDataKey] = keyBindingsData }
        if let outputBindingsData { userInfo[notificationOutputBindingsDataKey] = outputBindingsData }

        DistributedNotificationCenter.default().postNotificationName(
            profileStoreChangedNotificationName,
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    // MARK: - Resolution / parsing helpers

    private static func resolveProfile(_ target: String?, in store: ProfileStore) throws -> GamepadConfigurationProfile {
        store.profiles[try resolveProfileIndex(target, in: store)]
    }

    private static func resolveProfileIndex(_ target: String?, in store: ProfileStore) throws -> Int {
        let trimmed = target?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty, trimmed.lowercased() != "active" else {
            guard let index = store.profiles.firstIndex(where: { $0.id == store.activeProfileID }) else { throw CLIError.message("Active profile not found") }
            return index
        }
        if trimmed.lowercased() == "default" {
            guard let index = store.profiles.firstIndex(where: { $0.id == store.defaultProfileID }) else { throw CLIError.message("Default profile not found") }
            return index
        }
        if let uuid = UUID(uuidString: trimmed), let index = store.profiles.firstIndex(where: { $0.id == uuid }) { return index }
        if let index = store.profiles.firstIndex(where: { sameProfileName($0.name, trimmed) }) { return index }
        let normalized = normalizedLookup(trimmed)
        let matches = store.profiles.indices.filter { normalizedLookup(store.profiles[$0].name).contains(normalized) }
        if matches.count == 1 { return matches[0] }
        if matches.count > 1 { throw CLIError.message("Profile name is ambiguous: \(trimmed)") }
        throw CLIError.message("Profile not found: \(trimmed)")
    }

    private static func resolveProfileIndexes(_ targets: [String], in store: ProfileStore) throws -> [Int] {
        var indexes: [Int] = []
        var seenIndexes = Set<Int>()
        for target in targets {
            let index = try resolveProfileIndex(target, in: store)
            if seenIndexes.insert(index).inserted {
                indexes.append(index)
            }
        }
        return indexes.sorted()
    }

    private static func validProfileID(_ id: UUID, in profiles: [GamepadConfigurationProfile]) -> UUID? {
        profiles.contains(where: { $0.id == id }) ? id : nil
    }

    private static func resolveTemplate(_ text: String) throws -> GamepadControllerTemplate {
        let normalized = normalizedLookup(text)
        if let template = GamepadControllerTemplate.allCases.first(where: { normalizedLookup($0.rawValue) == normalized || normalizedLookup($0.displayName) == normalized }) {
            return template
        }
        let matches = GamepadControllerTemplate.allCases.filter { normalizedLookup($0.displayName).contains(normalized) || normalizedLookup($0.rawValue).contains(normalized) }
        if matches.count == 1 { return matches[0] }
        if matches.count > 1 { throw CLIError.message("Template name is ambiguous: \(text)") }
        throw CLIError.message("Template not found: \(text)")
    }

    private static func parseButton(_ text: String) throws -> GameButton {
        let normalized = normalizedLookup(text)
        if let button = GameButton(rawValue: text) { return button }
        if let button = GameButton.allCases.first(where: { normalizedLookup($0.rawValue) == normalized || normalizedLookup($0.displayName) == normalized }) {
            return button
        }
        throw CLIError.message("Unknown button: \(text)")
    }

    private static func parseOutputMode(_ text: String) throws -> GamepadProfileOutputMode {
        if let mode = GamepadProfileOutputMode(rawValue: text.lowercased()) { return mode }
        switch normalizedLookup(text) {
        case "key", "keys", "keyboard", "shortcut", "shortcuts":
            return .keyboard
        case "controller", "gamepad", "pad", "xbox":
            return .controller
        case "custom", "mixed", "hybrid", "both":
            return .custom
        default:
            throw CLIError.message("Unknown output mode: \(text). Use keyboard, controller, or custom.")
        }
    }

    private static func parseVirtualGamepadButton(_ text: String) throws -> VirtualGamepadButton {
        let normalized = normalizedLookup(text)
        if let button = VirtualGamepadButton(rawValue: text) { return button }
        if let button = VirtualGamepadButton.allCases.first(where: {
            normalizedLookup($0.rawValue) == normalized
                || normalizedLookup($0.displayName) == normalized
                || normalizedLookup($0.shortName) == normalized
        }) {
            return button
        }
        throw CLIError.message("Unknown gamepad button: \(text)")
    }

    private static func parseVirtualGamepadTrigger(_ text: String) throws -> VirtualGamepadTrigger {
        let normalized = normalizedLookup(text)
        if let trigger = VirtualGamepadTrigger(rawValue: text) { return trigger }
        if normalized == "lt" || normalized == "l2" || normalized == "lefttrigger" { return .left }
        if normalized == "rt" || normalized == "r2" || normalized == "righttrigger" { return .right }
        if let trigger = VirtualGamepadTrigger.allCases.first(where: {
            normalizedLookup($0.rawValue) == normalized
                || normalizedLookup($0.displayName) == normalized
                || normalizedLookup($0.shortName) == normalized
        }) {
            return trigger
        }
        throw CLIError.message("Unknown gamepad trigger: \(text)")
    }

    private static func parseTriggerOrientation(_ text: String) throws -> GamepadTriggerOrientation {
        if let orientation = GamepadTriggerOrientation(rawValue: text.lowercased()) { return orientation }
        throw CLIError.message("Unknown trigger orientation: \(text). Use vertical or horizontal.")
    }

    private static func parseKeyBindingSequence(_ text: String) throws -> MacKeyBinding {
        let separators = CharacterSet(charactersIn: ",")
        let parts = text.components(separatedBy: separators).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let strokeTexts = parts.isEmpty ? [text] : parts
        let strokes = try strokeTexts.map(parseKeyStroke)
        return MacKeyBinding(strokes: strokes)
    }

    private static func parseKeyStroke(_ text: String) throws -> MacKeyStroke {
        let parts = text.split(separator: "+").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard let keyName = parts.last else { throw CLIError.message("Empty key stroke") }
        let modifierNames = Array(parts.dropLast())
        let modifiers = try parseModifiers(modifierNames.joined(separator: ","))
        guard let keyCode = MacVirtualKey.keyCode(named: keyName) else { throw CLIError.message("Unsupported key: \(keyName)") }
        return MacKeyStroke(keyCode: keyCode, modifiers: modifiers)
    }

    private static func parseModifiers(_ text: String?) throws -> MacKeyModifiers {
        let names = text?.split { $0 == "," || $0 == "+" || $0 == " " }.map(String.init) ?? []
        guard let modifiers = MacKeyModifiers(generatedModifierNames: names) else { throw CLIError.message("Unsupported modifiers: \(text ?? "")") }
        return modifiers
    }

    private static func parseLayoutMode(_ text: String) throws -> GamepadLayoutMode {
        if let value = GamepadLayoutMode(rawValue: text) { return value }
        let normalized = normalizedLookup(text)
        if normalized == "navleft" { return .standard }
        if normalized == "actionsleft" { return .southpaw }
        throw CLIError.message("Unknown layout mode: \(text)")
    }

    private static func parseControlScale(_ text: String) throws -> GamepadControlScale {
        if let value = GamepadControlScale(rawValue: text) { return value }
        throw CLIError.message("Unknown control scale: \(text)")
    }

    private static func parseColorSchemePreference(_ text: String) throws -> GamepadColorSchemePreference {
        if let value = GamepadColorSchemePreference(rawValue: text.lowercased()) { return value }
        switch normalizedLookup(text) {
        case "system", "auto", "device", "followdevice", "followsdevice", "followssystem":
            return .system
        case "light", "lightmode", "alwayslight":
            return .light
        case "dark", "darkmode", "alwaysdark":
            return .dark
        default:
            throw CLIError.message("Unknown appearance: \(text)")
        }
    }

    private static func parseAccentStyle(_ text: String) throws -> GamepadAccentStyle {
        if let value = parseAccentStyleIfPresent(text) { return value }
        throw CLIError.message("Unknown accent style: \(text)")
    }

    private static func parseAccentStyleIfPresent(_ text: String) -> GamepadAccentStyle? {
        GamepadAccentStyle(rawValue: text) ?? GamepadAccentStyle.allCases.first { normalizedLookup($0.displayName) == normalizedLookup(text) }
    }

    private static func parseRGBAColor(_ text: String) throws -> GamepadRGBAColor {
        guard let color = GamepadRGBAColor(hexString: text) else {
            throw CLIError.message("Invalid color: \(text). Use #RRGGBB or #RRGGBBAA.")
        }
        return color
    }

    private static func parseGradientFill(_ text: String, arguments: [String]) throws -> GamepadFillStyle {
        let colors = text
            .split { $0 == "," || $0 == ";" || $0 == " " }
            .map(String.init)
            .filter { !$0.isEmpty }
        guard colors.count >= 2 else {
            throw CLIError.message("Gradient fill expects at least two colors, e.g. --fill-gradient '#FF0000,#0000FF'")
        }
        let stops = try colors.enumerated().map { index, colorText in
            let denominator = max(colors.count - 1, 1)
            return GamepadGradientStop(offset: CGFloat(index) / CGFloat(denominator), color: try parseRGBAColor(colorText))
        }
        let type = try optionValue("--gradient-type", in: arguments).map(parseGradientType) ?? .linear
        let angle = optionValue("--gradient-angle", in: arguments).flatMap(Double.init).map { CGFloat($0) } ?? 0
        return .gradient(GamepadGradientFill(type: type, angleDegrees: angle, stops: stops).normalized)
    }

    private static func parseGradientType(_ text: String) throws -> GamepadGradientType {
        if let type = GamepadGradientType(rawValue: text.lowercased()) { return type }
        throw CLIError.message("Unknown gradient type: \(text). Use linear or radial.")
    }

    private static func parseTileFill(_ text: String, arguments: [String]) throws -> GamepadFillStyle {
        let pattern = try parseTilePattern(text)
        let foreground = try optionValue("--tile-foreground", in: arguments).map(parseRGBAColor) ?? GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: 0.78)
        let background = try optionValue("--tile-background", in: arguments).map(parseRGBAColor) ?? .defaultValue
        let scale = optionValue("--tile-scale", in: arguments).flatMap(Double.init).map { CGFloat($0) } ?? 1
        let spacingX = optionValue("--tile-spacing-x", in: arguments).flatMap(Double.init).map { CGFloat($0) } ?? 0
        let spacingY = optionValue("--tile-spacing-y", in: arguments).flatMap(Double.init).map { CGFloat($0) } ?? 0
        let tile = GamepadTileFill(pattern: pattern, foregroundColor: foreground, backgroundColor: background, scale: scale, spacingX: spacingX, spacingY: spacingY)
        return .tile(tile.normalized)
    }

    private static func parseTilePattern(_ text: String) throws -> GamepadTilePattern {
        if let pattern = GamepadTilePattern(rawValue: text.lowercased()) { return pattern }
        let normalized = normalizedLookup(text)
        if let pattern = GamepadTilePattern.allCases.first(where: { normalizedLookup($0.displayName) == normalized }) { return pattern }
        throw CLIError.message("Unknown tile pattern: \(text). Use dots, grid, checker, or diagonal.")
    }

    private static func parseImageFill(_ path: String, arguments: [String]) throws -> GamepadFillStyle {
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        let data = try Data(contentsOf: url)
        guard data.count <= GamepadImageFill.maximumStoredBytes else {
            throw CLIError.message("Image fill must be under 2.5 MB")
        }
        let mode = try optionValue("--image-mode", in: arguments).map(parseImageContentMode) ?? .fill
        return .image(GamepadImageFill(data: data, fileName: url.lastPathComponent, contentMode: mode).normalized)
    }

    private static func parseImageContentMode(_ text: String) throws -> GamepadImageContentMode {
        if let mode = GamepadImageContentMode(rawValue: text.lowercased()) { return mode }
        throw CLIError.message("Unknown image mode: \(text). Use fill, fit, or tile.")
    }

    private static func parseShapeStyleIfPresent(_ text: String) -> GamepadButtonShapeStyle? {
        GamepadButtonShapeStyle(rawValue: text) ?? GamepadButtonShapeStyle.allCases.first { normalizedLookup($0.displayName) == normalizedLookup(text) }
    }

    private static func parseJoystickVisualStyle(_ text: String) throws -> GamepadJoystickVisualStyle {
        if let style = GamepadJoystickVisualStyle(rawValue: text) { return style }
        switch normalizedLookup(text) {
        case "pad", "fullpad", "classic", "joystick": return .pad
        case "thumbstick", "thumb", "nub", "stickball", "ball": return .thumbstick
        default: throw CLIError.message("Unknown joystick style: \(text). Use pad or thumbstick.")
        }
    }

    private static func parseCustomControlKind(_ text: String) throws -> GamepadCustomControlKind {
        if let value = GamepadCustomControlKind(rawValue: text) { return value }
        let normalized = normalizedLookup(text)
        if normalized == "shape" { return .button }
        if normalized == "stick" { return .joystick }
        if normalized == "trigger" || normalized == "slider" { return .trigger }
        if normalized == "touchpad" || normalized == "trackpad" || normalized == "cursorpad" { return .trackpad }
        if normalized == "decoration" || normalized == "decor" || normalized == "visual" || normalized == "plate" || normalized == "panel" || normalized == "ring" { return .decoration }
        throw CLIError.message("Unknown element kind: \(text)")
    }

    private static func parseMaterialVisualStyle(_ text: String) throws -> GamepadControlVisualStyle {
        switch normalizedLookup(text) {
        case "softwhite", "softwhiteraised", "raised", "neumorphic", "neumorphicraised":
            return .softWhiteRaised()
        case "softwhiteinset", "inset", "recessed", "well":
            return .softWhiteInset()
        case "softwhiteplate", "plate", "panel", "shell":
            return .softWhitePlate()
        default:
            throw CLIError.message("Unknown material preset: \(text). Use soft-white, soft-white-inset, or soft-white-plate.")
        }
    }

    private static func parseShadowLayers(_ text: String) throws -> [GamepadControlShadowStyle] {
        let parts = text.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else { return [] }
        return try parts.map { part in
            let fields = part.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard fields.count >= 4 else {
                throw CLIError.message("Invalid shadow layer \"\(part)\". Use color,radius,x,y[,opacity]; separate layers with semicolons.")
            }
            let color = try parseRGBAColor(fields[0])
            guard let radius = Double(fields[1]), let x = Double(fields[2]), let y = Double(fields[3]) else {
                throw CLIError.message("Invalid shadow layer numbers in \"\(part)\".")
            }
            let opacity = fields.count >= 5 ? (parseOpacityIfPresent(fields[4]) ?? 1) : 1
            return GamepadControlShadowStyle(color: color, radius: CGFloat(radius), x: CGFloat(x), y: CGFloat(y), opacity: opacity)
        }
    }

    private static func defaultLabel(for kind: GamepadCustomControlKind) -> String {
        switch kind {
        case .button: return "Shape"
        case .joystick: return "Joystick"
        case .trigger: return "Trigger"
        case .trackpad: return "Trackpad"
        case .decoration: return "Decoration"
        }
    }

    private static func triggerSettings(
        from arguments: [String],
        fallback: GamepadTriggerSettings = .defaultValue
    ) throws -> GamepadTriggerSettings {
        var settings = fallback.normalized
        if let value = optionValue("--target", in: arguments) ?? optionValue("--trigger", in: arguments) {
            settings.target = try parseVirtualGamepadTrigger(value)
        }
        if let value = optionValue("--orientation", in: arguments) {
            settings.orientation = try parseTriggerOrientation(value)
        }
        if let value = optionValue("--dead-zone", in: arguments) ?? optionValue("--deadzone", in: arguments) {
            settings.deadZone = try parseUnitInterval(value, option: "trigger dead zone")
        }
        if let value = optionValue("--sensitivity", in: arguments) {
            settings.sensitivity = try parseTrackpadScale(value, option: "trigger sensitivity")
        }
        if let value = optionValue("--digital", in: arguments) ?? optionValue("--digital-button", in: arguments) {
            settings.sendsDigitalButton = try parseBool(value)
        }
        if let value = optionValue("--digital-threshold", in: arguments) {
            settings.digitalThreshold = try parseUnitInterval(value, option: "trigger digital threshold")
        }
        return settings.normalized
    }

    private static func trackpadSettings(
        from arguments: [String],
        fallback: GamepadTrackpadSettings = .defaultValue
    ) throws -> GamepadTrackpadSettings {
        var settings = fallback.normalized
        if let value = optionValue("--sensitivity", in: arguments) ?? optionValue("--cursor-sensitivity", in: arguments) ?? optionValue("--pointer-sensitivity", in: arguments) {
            settings.sensitivity = try parseTrackpadScale(value, option: "sensitivity")
        }
        if let value = optionValue("--scroll-sensitivity", in: arguments) {
            settings.scrollSensitivity = try parseTrackpadScale(value, option: "scroll sensitivity")
        }
        if let value = optionValue("--tap-to-click", in: arguments) {
            settings.tapToClick = try parseBool(value)
        }
        if let value = optionValue("--two-finger-scroll", in: arguments) {
            settings.twoFingerScroll = try parseBool(value)
        }
        if let value = optionValue("--natural-scrolling", in: arguments) ?? optionValue("--natural-scroll", in: arguments) {
            settings.naturalScrolling = try parseBool(value)
        }
        return settings.normalized
    }

    private static func parseTrackpadScale(_ text: String, option: String) throws -> CGFloat {
        guard let value = Double(text), value.isFinite else {
            throw CLIError.message("Invalid \(option): \(text)")
        }
        return CGFloat(value)
    }

    private static func parseUnitInterval(_ text: String, option: String) throws -> CGFloat {
        guard let value = Double(text), value.isFinite else {
            throw CLIError.message("Invalid \(option): \(text)")
        }
        return CGFloat(value)
    }

    private static func parseBool(_ text: String) throws -> Bool {
        switch normalizedLookup(text) {
        case "true", "yes", "y", "1", "on": return true
        case "false", "no", "n", "0", "off": return false
        default: throw CLIError.message("Expected boolean, got: \(text)")
        }
    }

    private static func parseOpacityIfPresent(_ text: String) -> CGFloat? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("%"), let value = Double(trimmed.dropLast()) { return CGFloat(min(max(value / 100, 0), 1)) }
        guard let value = Double(trimmed) else { return nil }
        return CGFloat(min(max(value > 1 ? value / 100 : value, 0), 1))
    }

    private static func parseNudgeTranslation(arguments: [String], directionText: String?) throws -> CGSize {
        let dxText = optionValue("--dx", in: arguments)
        let dyText = optionValue("--dy", in: arguments)
        if dxText != nil || dyText != nil {
            guard directionText == nil else { throw CLIError.message("Use either a direction or --dx/--dy, not both") }
            let dx = try dxText.map(parsePixels) ?? 0
            let dy = try dyText.map(parsePixels) ?? 0
            guard abs(dx) > 0.001 || abs(dy) > 0.001 else { throw CLIError.message("Nudge delta cannot be zero") }
            return CGSize(width: dx, height: dy)
        }

        guard let directionText else { throw CLIError.message("Missing nudge direction: left, right, up, or down") }
        let step = try parseNudgeStep(arguments)
        switch normalizedLookup(directionText) {
        case "left", "arrowleft":
            return CGSize(width: -step, height: 0)
        case "right", "arrowright":
            return CGSize(width: step, height: 0)
        case "up", "arrowup":
            return CGSize(width: 0, height: -step)
        case "down", "arrowdown":
            return CGSize(width: 0, height: step)
        default:
            throw CLIError.message("Unknown nudge direction: \(directionText)")
        }
    }

    private static func parseNudgeStep(_ arguments: [String]) throws -> CGFloat {
        if let value = optionValue("--step", in: arguments) ?? optionValue("--pixels", in: arguments) ?? optionValue("--by", in: arguments) {
            let step = try parsePixels(value)
            guard step > 0 else { throw CLIError.message("Nudge step must be greater than zero") }
            return step
        }
        return (arguments.contains("--large") || arguments.contains("--shift")) ? 10 : 1
    }

    private static func parseNudgeCanvasSize(_ arguments: [String]) throws -> CGSize {
        var canvasSize = defaultEditorCanvasSize
        if let canvas = optionValue("--canvas", in: arguments) {
            let normalized = normalizedLookup(canvas)
            if normalized == "landscape" {
                canvasSize = defaultEditorCanvasSize
            } else if normalized == "portrait" {
                canvasSize = portraitEditorCanvasSize
            } else if let frame = GamepadEditorDeviceCatalog.frame(matching: canvas, preferredOrientation: nil) {
                canvasSize = frame.screenRect.size
            } else if let parsed = parseCanvasSizeLiteral(canvas) {
                canvasSize = parsed
            } else {
                throw CLIError.message("Invalid canvas size: \(canvas). Use landscape, portrait, a device frame id, or WIDTHxHEIGHT.")
            }
        }

        let explicitWidth = optionValue("--canvas-width", in: arguments)
        let explicitHeight = optionValue("--canvas-height", in: arguments)
        if explicitWidth != nil || explicitHeight != nil {
            guard let explicitWidth, let explicitHeight else { throw CLIError.message("Use --canvas-width and --canvas-height together") }
            canvasSize = CGSize(width: try parsePixels(explicitWidth), height: try parsePixels(explicitHeight))
        }

        guard canvasSize.width > 1, canvasSize.height > 1 else { throw CLIError.message("Canvas size must be greater than 1×1") }
        return canvasSize
    }

    private static func parseCanvasSizeLiteral(_ text: String) -> CGSize? {
        let separators = CharacterSet(charactersIn: "xX,:")
        let parts = text.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard parts.count == 2,
              let width = Double(parts[0]),
              let height = Double(parts[1])
        else { return nil }
        return CGSize(width: CGFloat(width), height: CGFloat(height))
    }

    private static func parsePixels(_ text: String) throws -> CGFloat {
        guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw CLIError.message("Expected a numeric pixel value, got: \(text)")
        }
        return CGFloat(value)
    }

    private static func formatPixels(_ value: CGFloat) -> String {
        let doubleValue = Double(value)
        if doubleValue.rounded() == doubleValue {
            return String(Int(doubleValue))
        }
        return String(format: "%.2f", doubleValue)
    }

    private static func formatSize(_ size: CGSize) -> String {
        "\(formatPixels(size.width))×\(formatPixels(size.height))"
    }

    private static func formatPercentage(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func formatScale(_ value: CGFloat) -> String {
        let doubleValue = Double(value)
        if doubleValue.rounded() == doubleValue {
            return String(Int(doubleValue))
        }
        return String(format: "%.2f", doubleValue)
    }

    private static func joystickMapping(from arguments: [String], fallback: GamepadJoystickMapping = .movement) throws -> GamepadJoystickMapping {
        var mapping = fallback
        if let value = optionValue("--up", in: arguments) { mapping.up = try parseButton(value) }
        if let value = optionValue("--down", in: arguments) { mapping.down = try parseButton(value) }
        if let value = optionValue("--left", in: arguments) { mapping.left = try parseButton(value) }
        if let value = optionValue("--right", in: arguments) { mapping.right = try parseButton(value) }
        return mapping
    }

    private static func joystickOutputSettings(
        from arguments: [String],
        fallback: GamepadJoystickOutputSettings = .defaultValue
    ) throws -> GamepadJoystickOutputSettings {
        var settings = fallback.normalized
        if let value = optionValue("--analog", in: arguments)
            ?? optionValue("--analog-stick", in: arguments)
            ?? optionValue("--stick", in: arguments)
            ?? optionValue("--target", in: arguments) {
            settings.analogTarget = try parseJoystickAnalogTarget(value)
        }
        if arguments.contains("--digital-directions") || arguments.contains("--send-digital-directions") || arguments.contains("--sends-digital-directions") {
            settings.sendsDigitalDirections = true
        }
        if let value = optionValue("--sends-digital-directions", in: arguments) {
            settings.sendsDigitalDirections = try parseBool(value)
        }
        if arguments.contains("--no-digital-directions") {
            settings.sendsDigitalDirections = false
        }
        if let value = optionValue("--dead-zone", in: arguments) ?? optionValue("--deadzone", in: arguments) {
            settings.deadZone = try parseUnitInterval(value, option: "joystick dead zone")
        }
        if let value = optionValue("--sensitivity", in: arguments) {
            settings.sensitivity = try parseTrackpadScale(value, option: "joystick sensitivity")
        }
        if arguments.contains("--invert-x") {
            settings.invertX = true
        }
        if arguments.contains("--invert-y") {
            settings.invertY = true
        }
        if arguments.contains("--snap-to-cardinal") || arguments.contains("--snap-cardinal") {
            settings.snapToCardinal = true
        }
        return settings.normalized
    }

    private static func parseJoystickAnalogTarget(_ text: String) throws -> GamepadJoystickAnalogTarget {
        if let target = GamepadJoystickAnalogTarget(rawValue: text) { return target }
        switch normalizedLookup(text) {
        case "none", "digital", "digitaldirections", "off": return .none
        case "left", "leftstick", "lstick", "ls": return .leftStick
        case "right", "rightstick", "rstick", "rs": return .rightStick
        default: throw CLIError.message("Unknown joystick analog target: \(text). Use none, left-stick, or right-stick.")
        }
    }

    private static func resolveElementTarget(_ text: String, in customization: GamepadCustomization) throws -> ElementTarget {
        if let uuid = UUID(uuidString: text), customization.customButtons.contains(where: { $0.id == uuid }) { return .custom(uuid) }
        if let button = try? parseButton(text) {
            if GameButton.builtInControls.contains(button) { return .builtin(button) }
            let matches = customization.customButtons.filter { $0.mappedButton == button }
            if matches.count == 1 { return .custom(matches[0].id) }
        }
        let normalized = normalizedLookup(text)
        let matches = customization.customButtons.filter { normalizedLookup($0.visualLabel(fallback: $0.mappedButton.displayName)) == normalized || normalizedLookup($0.label) == normalized }
        if matches.count == 1 { return .custom(matches[0].id) }
        if matches.count > 1 { throw CLIError.message("Element is ambiguous: \(text)") }
        throw CLIError.message("Element not found: \(text)")
    }

    private static func elementSummaries(for customization: GamepadCustomization) -> [ElementSummary] {
        var summaries: [ElementSummary] = GameButton.builtInControls.map { button in
            let layout = customization.buttonCustomization(for: button)
            return ElementSummary(
                id: button.rawValue,
                kind: "builtin",
                mappedButton: button,
                label: customization.visualLabel(for: button, defaultLabel: button.displayName),
                isHidden: layout.isHidden,
                isLocationLocked: layout.isLocationLocked,
                layout: layout,
                joystickMapping: nil,
                joystickOutputSettings: nil,
                triggerSettings: nil,
                trackpadSettings: nil
            )
        }
        summaries += customization.customButtons.map { custom in
            let normalized = custom.normalized
            let kind = normalized.isJoystick ? "joystick" : (normalized.isTrigger ? "trigger" : (normalized.isTrackpad ? "trackpad" : (normalized.isDecoration ? "decoration" : "button")))
            let fallbackLabel = normalized.isDecoration ? "Decoration" : (normalized.isTrigger ? (normalized.triggerSettings ?? .defaultValue).normalized.target.shortName : (normalized.isTrackpad ? "Trackpad" : "Button"))
            return ElementSummary(
                id: normalized.id.uuidString,
                kind: kind,
                mappedButton: normalized.mappedButton,
                label: normalized.visualLabel(fallback: fallbackLabel),
                isHidden: normalized.layout.isHidden,
                isLocationLocked: normalized.layout.isLocationLocked,
                layout: normalized.layout,
                joystickMapping: normalized.joystickMapping,
                joystickOutputSettings: normalized.joystickOutputSettings,
                triggerSettings: normalized.triggerSettings,
                trackpadSettings: normalized.trackpadSettings
            )
        }
        return summaries
    }

    private static func firstAvailableCustomSlot(in customization: GamepadCustomization) -> GameButton? {
        GameButton.customSlots.first { slot in !customization.customButtons.contains { $0.mappedButton == slot } }
    }

    private static func resolvedMacBindings(for generated: GeneratedGameKeypadProfile) throws -> [GameButton: MacKeyBinding] {
        var bindings = DefaultKeypadKeyMap.defaultBindings
        for (button, spec) in generated.keyBindings {
            guard let binding = MacKeyBinding(generatedSpec: spec) else {
                let rawBinding = (spec.modifiers + [spec.key]).joined(separator: "+")
                throw CLIError.message("Unsupported key binding for \(button.displayName): \(rawBinding)")
            }
            bindings[button] = binding
        }
        return bindings
    }

    private static func sameProfileName(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    private static func normalizedLookup(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func normalizedLabel(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > GamepadCustomization.maximumLabelLength else { return trimmed }
        return String(trimmed.prefix(GamepadCustomization.maximumLabelLength))
    }

    private static func optionValue(_ option: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: option), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func hasAnyOption(_ options: [String], in arguments: [String]) -> Bool {
        options.contains { arguments.contains($0) }
    }

    private static func firstPositional(in arguments: [String]) -> String? {
        positionals(in: arguments).first
    }

    private static func positionals(in arguments: [String]) -> [String] {
        var values: [String] = []
        var skipNext = false
        let optionsWithValues: Set<String> = [
            "--spec", "--from-spec", "--output", "-o", "--profile", "--name", "--template", "--from",
            "--layout-preview", "--preview-output", "--path", "--app", "--application", "--bundle-id", "--bundle", "--image-scale", "--render-scale",
            "--sequence", "--keyboard", "--key", "--gamepad-button", "--gamepad", "--part", "--input", "--modifiers", "--mods", "--layout", "--scale", "--control-scale",
            "--appearance", "--color-scheme", "--scheme", "--accent", "--color", "--labels", "--label", "--maps-to", "--x", "--center-x", "--y", "--center-y",
            "--background", "--bg", "--light-background", "--background-light", "--dark-background", "--background-dark",
            "--background-gradient", "--bg-gradient", "--background-tile", "--bg-tile", "--background-image", "--bg-image",
            "--light-background-gradient", "--background-light-gradient", "--dark-background-gradient", "--background-dark-gradient",
            "--light-background-tile", "--background-light-tile", "--dark-background-tile", "--background-dark-tile",
            "--light-background-image", "--background-light-image", "--dark-background-image", "--background-dark-image",
            "--width", "--width-scale", "--device-width", "--height", "--height-scale", "--device-height", "--shape", "--fill", "--light-fill", "--fill-light",
            "--light-color", "--dark-fill", "--fill-dark", "--dark-color", "--opacity", "--light-opacity", "--dark-opacity",
            "--thumb-fill", "--thumb-color", "--joystick-thumb-fill", "--joystick-knob-fill", "--light-thumb-fill", "--thumb-light", "--light-thumb-color",
            "--dark-thumb-fill", "--thumb-dark", "--dark-thumb-color", "--thumb-opacity", "--light-thumb-opacity", "--dark-thumb-opacity",
            "--fill-gradient", "--gradient", "--gradient-type", "--gradient-angle", "--light-fill-gradient", "--dark-fill-gradient", "--gradient-light", "--gradient-dark",
            "--fill-tile", "--tile", "--tile-foreground", "--tile-background", "--tile-scale", "--tile-spacing-x", "--tile-spacing-y", "--light-fill-tile", "--dark-fill-tile", "--tile-light", "--tile-dark",
            "--fill-image", "--image", "--image-mode",
            "--corner", "--radius", "--corner-tl", "--corner-tr", "--corner-br", "--corner-bl", "--shadow",
            "--shadow-strength", "--kind", "--up", "--down", "--left", "--right", "--target", "--trigger", "--dead-zone", "--deadzone", "--sensitivity",
            "--analog", "--analog-stick", "--stick", "--sends-digital-directions", "--joystick-style", "--stick-style",
            "--cursor-sensitivity", "--pointer-sensitivity", "--scroll-sensitivity", "--tap-to-click",
            "--two-finger-scroll", "--natural-scrolling", "--natural-scroll", "--digital", "--digital-button", "--digital-threshold", "--hold-ms",
            "--step", "--pixels", "--by", "--dx", "--dy", "--canvas", "--canvas-width", "--canvas-height",
            "--device", "--frame", "--size", "--device-size", "--orientation", "--device-orientation", "--variant", "--layout-variant",
            "--id", "--style", "--style-id", "--icon", "--sf-symbol", "--icon-text", "--haptic",
            "--haptic-pattern", "--haptic-rhythm", "--haptic-intensity", "--haptic-strength", "--haptic-sharpness", "--haptic-duration", "--haptic-duration-ms",
            "--stroke", "--stroke-color", "--stroke-width", "--foreground", "--foreground-color", "--text-color",
            "--glow", "--glow-color", "--glow-radius", "--inner-shadow", "--inner-shadow-color", "--inner-shadow-radius", "--inner-shadow-x", "--inner-shadow-y",
            "--highlight", "--highlight-color", "--highlight-radius", "--highlight-x", "--highlight-y", "--highlight-opacity",
            "--bevel", "--bevel-highlight", "--bevel-shadow", "--bevel-width", "--pressed-fill", "--pressed-color", "--press-scale", "--scale-on-press",
            "--material", "--material-preset", "--shadow-layers", "--shadows",
            "--to", "--before", "--after", "--role"
        ]
        for argument in arguments {
            if skipNext {
                skipNext = false
                continue
            }
            if optionsWithValues.contains(argument) {
                skipNext = true
                continue
            }
            if argument.hasPrefix("-") { continue }
            values.append(argument)
        }
        return values
    }

    // MARK: - Output / process helpers

    private static func printProfile(_ profile: GamepadConfigurationProfile, store: ProfileStore) {
        print("Name: \(profile.name)")
        print("ID: \(profile.id.uuidString)")
        print("Active: \(profile.id == store.activeProfileID ? "yes" : "no")")
        print("Default: \(profile.id == store.defaultProfileID ? "yes" : "no")")
        print("Output: \(profile.outputMode.displayName)")
        if let launchTarget = profile.launchTarget {
            print("Attached Application: \(launchTarget.displayName) (\(launchTarget.detailText))")
        } else {
            print("Attached Application: none")
        }
        print("Layout: \(profile.customization.layoutMode.rawValue)")
        print("Scale: \(profile.customization.controlScale.rawValue)")
        let deviceFrame = profile.customization.deviceCanvas.editorDeviceFrame
        print("Appearance: \(profile.customization.colorSchemePreference.rawValue)")
        print("Device: \(deviceFrame.displayName) (\(formatSize(deviceFrame.screenRect.size)) pt)")
        let variants = [
            profile.landscapeCustomization == nil ? nil : "landscape",
            profile.portraitCustomization == nil ? nil : "portrait"
        ].compactMap { $0 }.joined(separator: ", ")
        print("Orientation variants: \(variants.isEmpty ? "none" : variants)")
        let lightBackground = profile.customization.keypadBackgroundFillStyle(scheme: .light)
        let darkBackground = profile.customization.keypadBackgroundFillStyle(scheme: .dark)
        print("Background: light \(lightBackground.displayName) \(lightBackground.representativeColor.hexString), dark \(darkBackground.displayName) \(darkBackground.representativeColor.hexString)")
        print("Accent: \(profile.customization.accentStyle.displayName)")
        print("Labels: \(profile.customization.showsButtonLabels ? "shown" : "hidden")")
        print("Custom elements: \(profile.customization.customButtons.count)")
    }

    private static func printSummary(
        generated: GeneratedGameKeypadProfile,
        macBindings: [GameButton: MacKeyBinding],
        installed: Bool,
        selected: Bool
    ) {
        let action = installed ? (selected ? "Generated, installed, and selected" : "Generated and installed") : "Generated"
        print("\(action) \"\(generated.resolvedGameName)\"")
        print("Source: \(generated.source)")
        print("Confidence: \(generated.confidence.rawValue)")
        for note in generated.notes { print("- \(note)") }
        print("\nBindings:")
        for button in GameButton.allCases {
            guard let binding = macBindings[button], generated.keyBindings[button] != nil else { continue }
            let label = generatedLabel(for: button, in: generated.profile.customization)
            print("- \(label): \(binding.displayName)")
        }
    }

    private static func generatedLabel(for button: GameButton, in customization: GamepadCustomization) -> String {
        if let customButton = customization.customButtons.first(where: { $0.mappedButton == button }) {
            return customButton.visualLabel(fallback: button.displayName)
        }
        return customization.visualLabel(for: button, defaultLabel: button.displayName)
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        print(String(decoding: data, as: UTF8.self))
    }

    private static func writeJSON<T: Encodable>(_ value: T, to path: String?) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        if let path, path != "-" {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } else {
            print(String(decoding: data, as: UTF8.self))
        }
    }

    private static func openApp() throws {
        try runProcess("/usr/bin/open", arguments: ["-b", appDefaultsDomain])
        Thread.sleep(forTimeInterval: 0.35)
    }

    private static func quitApp() throws {
        try runProcess("/usr/bin/osascript", arguments: ["-e", "tell application id \"\(appDefaultsDomain)\" to quit"])
    }

    private static func runProcess(_ executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CLIError.message("Command failed: \(executable) \(arguments.joined(separator: " "))") }
    }

    private static func printHelp() {
        print("""
        pocketpad — configure and control PocketPad Mac from the command line

        Generation:
          pocketpad generate "Hollow Knight" [--json] [--dry-run]
          pocketpad generate --spec agent-keypad.json [--layout-preview preview.png]
          pocketpad install-spec agent-keypad.json

        Profiles:
          pocketpad profile list [--ids|--json]
          pocketpad profile show [active|default|NAME|UUID] [--json]
          pocketpad profile create NAME [--blank|--template TEMPLATE|--from PROFILE]
          pocketpad profile select NAME|UUID
          pocketpad profile default NAME|UUID
          pocketpad profile rename NAME|UUID NEW_NAME
          pocketpad profile duplicate [NAME|UUID] [NEW_NAME]
          pocketpad profile delete NAME|UUID [NAME|UUID ...]
          pocketpad profile move NAME|UUID [NAME|UUID ...] --to INDEX|--before PROFILE|--after PROFILE
          pocketpad profile reset [NAME|UUID]
          pocketpad profile attach-app [NAME|UUID|--profile PROFILE] --path /Applications/App.app
          pocketpad profile attach-app [NAME|UUID|--profile PROFILE] --bundle-id com.example.App
          pocketpad profile detach-app [NAME|UUID|--profile PROFILE]
          pocketpad profile launch [NAME|UUID|--profile PROFILE]
          pocketpad profile export [NAME|UUID|--all] [-o file.json]
          pocketpad profile import file.json [--default] [--append]

        Templates:
          pocketpad template list
          pocketpad template install nes [--name "My NES"] [--default]
          pocketpad template install softWhite [--name "Soft Pad"]

        Themes:
          pocketpad theme list
          pocketpad theme show cavern-glow
          pocketpad theme apply cavern-glow [--profile PROFILE]
          pocketpad theme apply soft-white-controller [--profile PROFILE]

        Bindings:
          pocketpad binding list [--profile PROFILE]
          pocketpad binding set jump Return
          pocketpad binding set focus --sequence 'Control+B,H'
          pocketpad binding reset jump
          pocketpad binding reset-all
          pocketpad output list [--profile PROFILE]
          pocketpad output mode keyboard|controller|custom [--profile PROFILE]
          pocketpad output set jump --keyboard Space --gamepad south
          pocketpad output set custom5 --clear-keyboard --gamepad leftTriggerButton

        Customization:
          pocketpad customization set --appearance dark --device iphone-17-pro --background '#101014'
          pocketpad customization set --background-gradient '#101014,#4338CA' --gradient-angle 45
          pocketpad customization set --device iphone-17-pro --orientation landscape
          pocketpad customization set --variant portrait --device iphone-17-pro --orientation portrait
          pocketpad customization export -o customization.json [--variant portrait|landscape]
          pocketpad layout validate [PROFILE|--profile PROFILE] [--variant portrait|landscape] [--json|--strict]
          pocketpad layout preview [PROFILE|--profile PROFILE] -o preview.png [--variant portrait|landscape] [--canvas iphone-17-pro-landscape]
          pocketpad device list
          pocketpad device set iphone-17-pro --orientation landscape
          pocketpad device set custom --size 844x390
          pocketpad element list
          pocketpad element add button --label Fire --keyboard Space --gamepad south --x 0.5 --y 0.8 --light-fill '#6B7280' --dark-fill '#374151'
          pocketpad element add joystick --label "Right Stick" --fill '#111827' --thumb-fill '#F8FAFC' --part up --keyboard W
          pocketpad element add joystick --label Nub --thumbstick --target right-stick --no-digital-directions --x 0.5 --y 0.58
          pocketpad element add trigger --target left --orientation horizontal --sensitivity 1.2
          pocketpad element add trackpad --label Trackpad --x 0.5 --y 0.58 --width 1.4 --sensitivity 1.2 --tap-to-click true
          pocketpad element add decoration --label Shell --material soft-white-plate --x 0.5 --y 0.5 --width 3.2 --height 1.5 --shape rounded_rectangle
          pocketpad element set jump --keyboard Space --gamepad south
          pocketpad element set jump --variant portrait --label A --light-fill '#7C3AED' --dark-fill '#C4B5FD' --shape circle --width 1.2 --height 1.2
          pocketpad element set "Right Stick" --thumb-fill '#22C55E'
          pocketpad element set jump --fill-gradient '#000000,#666666' --gradient-angle 0
          pocketpad element set jump --fill-tile dots --tile-foreground '#FFFFFF' --tile-background '#111111'
          pocketpad element set jump --fill-image ./button-texture.png --image-mode fill
          pocketpad element set focus --icon sf:sparkles --haptic medium --haptic-pattern double --haptic-intensity 75% --haptic-duration 70ms --stroke '#38BDF8' --pressed-fill '#0EA5E9' --glow '#0EA5E9'
          pocketpad element set jump --text-color '#7C61A8' --inner-shadow '#B8B2C2' --inner-shadow-radius 5 --highlight '#FFFFFF' --highlight-opacity 45% --highlight-x -4 --highlight-y -4 --bevel-width 1.5
          pocketpad element set jump --material soft-white --shadow-layers '#FFFFFF,14,-7,-7,96%;#9B91AA,20,8,9,24%'
          pocketpad element nudge jump right --step 10 --canvas iphone-17-pro-landscape
          pocketpad style create SoftWhite --material soft-white --fill '#F8F6F7' --text-color '#7C61A8'
          pocketpad style create Soul --fill '#F8FAFC' --stroke '#38BDF8' --pressed-fill '#0EA5E9' --icon sf:sparkles
          pocketpad style apply soul focus
          pocketpad layer list
          pocketpad layer front focus
          pocketpad group create Actions jump attack dash focus
          pocketpad asset import ./icon.png --role icon --name SoulOrb

        Runtime:
          pocketpad app open|quit
          pocketpad status [--json]
          pocketpad latency simulate [--pattern hollow-knight] [--mode compare] [--log report.json]
          pocketpad latency verify [--max-ms 4] [--p95-ms 4] [--log report.json]
          pocketpad server start|stop|restart|addresses
          pocketpad pairing code|payload|cancel
          pocketpad accessibility status|prompt|open|refresh
          pocketpad test tap jump
          pocketpad release-all
        """)
    }
}

private enum CLIError: LocalizedError {
    case helpRequested
    case message(String)
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .helpRequested:
            "Help requested"
        case .message(let message), .validationFailed(let message):
            message
        }
    }
}
