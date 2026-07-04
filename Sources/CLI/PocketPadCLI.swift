import AppKit
import Foundation

@main
struct PocketPadCLI {
    private static let appDefaultsDomain = PocketPadMacIPC.appDefaultsDomain
    private static let keyBindingsDefaultsKey = "PocketPadMac.keyBindings.v2"
    private static let profileKeyBindingsDefaultsKey = "PocketPadMac.profileKeyBindings.v1"
    private static let profileStoreChangedNotificationName = Notification.Name("com.codybontecou.PocketPadMac.profileStoreChanged")
    private static let notificationProfileStateDataKey = "profileStateData"
    private static let notificationActiveCustomizationDataKey = "activeCustomizationData"
    private static let notificationKeyBindingsDataKey = "keyBindingsData"
    private static let notificationProfileKeyBindingsDataKey = "profileKeyBindingsData"

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
    }

    private struct GenerateOptions {
        var gameName: String?
        var specPath: String?
        var install = true
        var select = true
        var makeDefault = true
        var printJSON = false
    }

    private struct InstallOptions {
        var select = true
        var makeDefault = true
    }

    private struct ProfileExportEnvelope: Codable {
        var version: Int = 1
        var exportedAt: Int64 = Date.currentMilliseconds
        var profiles: [GamepadConfigurationProfile]
        var activeProfileID: UUID?
        var defaultProfileID: UUID?
        var profileKeyBindings: [String: [String: MacKeyBinding]]
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
        case "binding", "bindings", "shortcut", "shortcuts":
            try binding(arguments: rest)
        case "customization", "customize", "layout":
            try customization(arguments: rest)
        case "element", "control", "controls":
            try element(arguments: rest)
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
                try printJSON(ProfileExportEnvelope(profiles: store.profiles, activeProfileID: store.activeProfileID, defaultProfileID: store.defaultProfileID, profileKeyBindings: store.profileKeyBindings))
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
                try printJSON(ProfileExportEnvelope(profiles: [profile], activeProfileID: profile.id, defaultProfileID: store.defaultProfileID == profile.id ? profile.id : nil, profileKeyBindings: [profile.id.uuidString: bindings]))
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
            let duplicate = GamepadConfigurationProfile(name: duplicateName, customization: source.customization)
            store.profiles.append(duplicate)
            store.activeProfileID = duplicate.id
            store.profileKeyBindings[duplicate.id.uuidString] = store.profileKeyBindings[source.id.uuidString] ?? rawBindings(DefaultKeypadKeyMap.defaultBindings)
            try persistStore(store)
            print("Duplicated \"\(source.name)\" as \"\(duplicate.name)\".")

        case "delete", "rm":
            guard let target = firstPositional(in: rest) else { throw CLIError.message("Missing profile name or id") }
            var store = loadStore()
            guard store.profiles.count > 1 else { throw CLIError.message("Cannot delete the last remaining profile") }
            let index = try resolveProfileIndex(target, in: store)
            let removed = store.profiles.remove(at: index)
            store.profileKeyBindings[removed.id.uuidString] = nil
            if store.activeProfileID == removed.id { store.activeProfileID = store.profiles[min(index, store.profiles.count - 1)].id }
            if store.defaultProfileID == removed.id { store.defaultProfileID = store.activeProfileID }
            try persistStore(store)
            print("Deleted profile \"\(removed.name)\".")

        case "reset":
            let target = firstPositional(in: rest)
            var store = loadStore()
            let index = try resolveProfileIndex(target, in: store)
            store.profiles[index].customization = GamepadCustomization.defaultValue
            store.profiles[index].updatedAt = Date.currentMilliseconds
            try persistStore(store)
            print("Reset profile \"\(store.profiles[index].name)\" to the default keypad layout.")

        case "new", "create":
            try createProfile(arguments: rest)

        case "export":
            try exportProfiles(arguments: rest)

        case "import":
            try importProfiles(arguments: rest)

        default:
            throw CLIError.message("Unknown profile subcommand: \(subcommand)")
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
        let defaultName: String
        var baseBindings = decodedBindings(store.profileKeyBindings[store.activeProfileID.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings

        if let templateName {
            let template = try resolveTemplate(templateName)
            let profile = template.makeProfile()
            baseCustomization = profile.customization
            defaultName = profile.name
        } else if let fromProfile {
            let profile = try resolveProfile(fromProfile, in: store)
            baseCustomization = profile.customization
            defaultName = "\(profile.name) Copy"
            baseBindings = decodedBindings(store.profileKeyBindings[profile.id.uuidString]) ?? baseBindings
        } else if blank {
            baseCustomization = .blankCanvas
            defaultName = "Blank Setup"
        } else {
            baseCustomization = .defaultValue
            defaultName = "Setup \(store.profiles.count + 1)"
        }

        let profile = GamepadConfigurationProfile(name: requestedName.isEmpty ? defaultName : requestedName, customization: baseCustomization)
        store.profiles.append(profile)
        store.profileKeyBindings[profile.id.uuidString] = rawBindings(baseBindings)
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
        let envelope = ProfileExportEnvelope(profiles: profiles, activeProfileID: activeID, defaultProfileID: defaultID, profileKeyBindings: bindings)
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
        var importedActiveID: UUID?
        var importedDefaultID: UUID?

        if let envelope = try? decoder.decode(ProfileExportEnvelope.self, from: data) {
            importedProfiles = envelope.profiles.map(\.normalized)
            importedBindings = envelope.profileKeyBindings
            importedActiveID = envelope.activeProfileID
            importedDefaultID = envelope.defaultProfileID
        } else if let generated = try? decoder.decode(GeneratedGameKeypadProfile.self, from: data) {
            importedProfiles = [generated.profile.normalized]
            importedBindings[generated.profile.id.uuidString] = rawBindings(try resolvedMacBindings(for: generated))
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
        let profile = try resolveProfile(profileTarget, in: store)
        var bindings = decodedBindings(store.profileKeyBindings[profile.id.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings
        try mutate(&bindings)
        store.profileKeyBindings[profile.id.uuidString] = rawBindings(bindings)
        try persistStore(store)
    }

    // MARK: - Customization

    private static func customization(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing customization subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "show":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            try printJSON(profile.customization)
        case "export":
            let outputPath = optionValue("--output", in: rest) ?? optionValue("-o", in: rest)
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            try writeJSON(profile.customization, to: outputPath)
        case "import":
            guard let path = firstPositional(in: rest) else { throw CLIError.message("Missing customization JSON path") }
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let customization = try JSONDecoder().decode(GamepadCustomization.self, from: data)
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { $0 = customization }
            print("Imported customization.")
        case "set":
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { customization in
                if let layout = optionValue("--layout", in: rest) { customization.layoutMode = try parseLayoutMode(layout) }
                if let scale = optionValue("--scale", in: rest) ?? optionValue("--control-scale", in: rest) { customization.controlScale = try parseControlScale(scale) }
                if let appearance = optionValue("--appearance", in: rest) ?? optionValue("--color-scheme", in: rest) ?? optionValue("--scheme", in: rest) { customization.colorSchemePreference = try parseColorSchemePreference(appearance) }
                if let accent = optionValue("--accent", in: rest) ?? optionValue("--color", in: rest) { customization.accentStyle = try parseAccentStyle(accent) }
                if rest.contains("--show-labels") { customization.showsButtonLabels = true }
                if rest.contains("--hide-labels") { customization.showsButtonLabels = false }
                if let labels = optionValue("--labels", in: rest) { customization.showsButtonLabels = try parseBool(labels) }
            }
            print("Updated customization.")
        case "reset":
            try mutateCustomization(profileTarget: optionValue("--profile", in: rest)) { $0 = .defaultValue }
            print("Reset customization.")
        default:
            throw CLIError.message("Unknown customization subcommand: \(subcommand)")
        }
    }

    private static func mutateCustomization(profileTarget: String?, mutate: (inout GamepadCustomization) throws -> Void) throws {
        var store = loadStore()
        let index = try resolveProfileIndex(profileTarget, in: store)
        var customization = store.profiles[index].customization
        try mutate(&customization)
        store.profiles[index].customization = customization.normalized
        store.profiles[index].updatedAt = Date.currentMilliseconds
        try persistStore(store)
    }

    // MARK: - Elements / controls

    private static func element(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing element subcommand") }
        let rest = Array(arguments.dropFirst())
        switch subcommand {
        case "list", "ls":
            let store = loadStore()
            let profile = try resolveProfile(optionValue("--profile", in: rest), in: store)
            let summaries = elementSummaries(for: profile.customization)
            if rest.contains("--json") {
                try printJSON(summaries)
            } else {
                for item in summaries {
                    print("\(item.id)\t\(item.kind)\t\(item.label)\t→ \(item.mappedButton.rawValue)\t\(item.isHidden ? "hidden" : "visible")\(item.isLocationLocked ? " locked" : "")")
                }
            }
        case "add":
            try addElement(arguments: rest)
        case "set":
            try setElement(arguments: rest)
        case "delete", "rm":
            try deleteElement(arguments: rest)
        case "reset":
            try resetElement(arguments: rest)
        default:
            throw CLIError.message("Unknown element subcommand: \(subcommand)")
        }
    }

    private static func addElement(arguments: [String]) throws {
        guard let kindText = firstPositional(in: arguments) else { throw CLIError.message("Usage: pocketpad element add <button|joystick> [options]") }
        let kind = try parseCustomControlKind(kindText)
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments)) { customization in
            guard customization.customButtons.count < GamepadCustomization.maximumCustomButtons else { throw CLIError.message("Maximum custom element count reached") }
            if kind == .joystick && customization.customButtons.filter({ $0.normalized.isJoystick }).count >= GamepadCustomization.maximumJoysticks {
                throw CLIError.message("Maximum joystick count reached")
            }

            let id = UUID()
            let mapped = try optionValue("--maps-to", in: arguments).map(parseButton) ?? (kind == .joystick ? .up : firstAvailableCustomSlot(in: customization) ?? .custom1)
            var customButton = GamepadCustomButton(
                id: id,
                mappedButton: mapped,
                label: optionValue("--label", in: arguments) ?? (kind == .joystick ? "Joystick" : "Shape"),
                controlKind: kind,
                joystickMapping: kind == .joystick ? try joystickMapping(from: arguments) : nil
            )
            try applyLayoutOptions(arguments, to: &customButton.layout)
            if kind == .joystick {
                customButton.layout.shape = .circle
                customButton.layout.widthScale = customButton.layout.widthScale == 1.0 ? 1.35 : customButton.layout.widthScale
                customButton.layout.heightScale = customButton.layout.heightScale == 1.0 ? 1.35 : customButton.layout.heightScale
                customButton.joystickMapping = try joystickMapping(from: arguments)
            }
            customization.customButtons.append(customButton)
        }
        print("Added \(kind.displayName.lowercased()).")
    }

    private static func setElement(arguments: [String]) throws {
        guard let targetText = firstPositional(in: arguments) else { throw CLIError.message("Missing element id, button, or label") }
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments)) { customization in
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
                if customization.customButtons[index].controlKind == .joystick || hasAnyOption(["--up", "--down", "--left", "--right"], in: arguments) {
                    customization.customButtons[index].controlKind = .joystick
                    customization.customButtons[index].joystickMapping = try joystickMapping(from: arguments, fallback: customization.customButtons[index].joystickMapping ?? .movement)
                    customization.customButtons[index].layout.shape = .circle
                }
                try applyLayoutOptions(arguments, to: &customization.customButtons[index].layout)
            }
        }
        print("Updated element \"\(targetText)\".")
    }

    private static func deleteElement(arguments: [String]) throws {
        guard let targetText = firstPositional(in: arguments) else { throw CLIError.message("Missing element id, button, or label") }
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments)) { customization in
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
        try mutateCustomization(profileTarget: optionValue("--profile", in: arguments)) { customization in
            let target = try resolveElementTarget(targetText, in: customization)
            switch target {
            case .builtin(let button):
                customization.setButtonCustomization(.defaultValue, for: button)
                customization.setLabel("", for: button)
            case .custom(let id):
                guard let index = customization.customButtons.firstIndex(where: { $0.id == id }) else { return }
                let isJoystick = customization.customButtons[index].normalized.isJoystick
                customization.customButtons[index].label = isJoystick ? "Joystick" : "Shape"
                customization.customButtons[index].layout = GamepadButtonCustomization(
                    centerX: 0.5,
                    centerY: 0.5,
                    widthScale: isJoystick ? 1.35 : 1.0,
                    heightScale: isJoystick ? 1.35 : 1.0,
                    shape: isJoystick ? .circle : .roundedRectangle
                )
                if isJoystick { customization.customButtons[index].joystickMapping = customization.customButtons[index].joystickMapping ?? .movement }
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
        if let value = optionValue("--accent", in: arguments), let accent = parseAccentStyleIfPresent(value) {
            layout.accentStyle = accent
            layout.fillColor = nil
            layout.lightFillColor = nil
            layout.darkFillColor = nil
        }
        if let value = optionValue("--fill", in: arguments) ?? optionValue("--color", in: arguments) {
            layout.fillColor = try parseRGBAColor(value)
            layout.lightFillColor = nil
            layout.darkFillColor = nil
        }
        if arguments.contains("--clear-fill") || arguments.contains("--clear-color") {
            layout.fillColor = nil
            layout.lightFillColor = nil
            layout.darkFillColor = nil
        }
        if let value = optionValue("--light-fill", in: arguments) ?? optionValue("--fill-light", in: arguments) ?? optionValue("--light-color", in: arguments) {
            setLayoutFillColor(try parseRGBAColor(value), isDark: false, in: &layout)
        }
        if let value = optionValue("--dark-fill", in: arguments) ?? optionValue("--fill-dark", in: arguments) ?? optionValue("--dark-color", in: arguments) {
            setLayoutFillColor(try parseRGBAColor(value), isDark: true, in: &layout)
        }
        if arguments.contains("--clear-light-fill") || arguments.contains("--clear-light-color") {
            clearLayoutFillColor(isDark: false, in: &layout)
        }
        if arguments.contains("--clear-dark-fill") || arguments.contains("--clear-dark-color") {
            clearLayoutFillColor(isDark: true, in: &layout)
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
        if let legacyFillColor = layout.fillColor?.normalized {
            if layout.lightFillColor == nil {
                layout.lightFillColor = legacyFillColor
            }
            if layout.darkFillColor == nil {
                layout.darkFillColor = legacyFillColor
            }
        }
        layout.fillColor = nil
        if isDark {
            layout.darkFillColor = color.normalized
        } else {
            layout.lightFillColor = color.normalized
        }
    }

    private static func clearLayoutFillColor(isDark: Bool, in layout: inout GamepadButtonCustomization) {
        if let legacyFillColor = layout.fillColor?.normalized {
            if isDark {
                if layout.lightFillColor == nil {
                    layout.lightFillColor = legacyFillColor
                }
            } else if layout.darkFillColor == nil {
                layout.darkFillColor = legacyFillColor
            }
        }
        layout.fillColor = nil
        if isDark {
            layout.darkFillColor = nil
        } else {
            layout.lightFillColor = nil
        }
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
            let payload = PairingPayload(urls: status.localURLs, pairingCode: status.pairingCode)
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
            print("Port: \(status.port)")
            print("Pairing Code: \(status.pairingCode)")
            print("Accessibility: \(status.accessibilityTrusted ? "granted" : "required")")
            if !status.localURLs.isEmpty {
                print("Addresses:")
                for url in status.localURLs { print("- \(url)") }
            }
            print("Last Event: \(status.lastReceivedEvent)")
            print("Pressed: \(status.pressedButtons.map(\.rawValue).sorted().joined(separator: ", "))")
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
        return ProfileStore(
            profiles: state.profiles,
            activeProfileID: state.activeProfileID,
            defaultProfileID: state.defaultProfileID,
            profileKeyBindings: profileBindings
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
        let activeProfile = state.activeProfile ?? state.profiles[0]
        let activeBindings = decodedBindings(store.profileKeyBindings[activeProfile.id.uuidString]) ?? DefaultKeypadKeyMap.defaultBindings
        store.profileKeyBindings[activeProfile.id.uuidString] = rawBindings(activeBindings)

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

        domain[GamepadConfigurationProfilePersistence.defaultsKey] = stateData
        domain[GamepadCustomizationPersistence.defaultsKey] = activeCustomizationData
        domain[keyBindingsDefaultsKey] = keyBindingsData
        domain[profileKeyBindingsDefaultsKey] = profileKeyBindingsData

        UserDefaults.standard.setPersistentDomain(domain, forName: appDefaultsDomain)
        UserDefaults.standard.synchronize()
        notifyRunningMacHelper(
            profileStateData: stateData,
            activeCustomizationData: activeCustomizationData,
            keyBindingsData: keyBindingsData,
            profileKeyBindingsData: profileKeyBindingsData
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

    private static func dataValue(_ value: Any?) -> Data? {
        if let data = value as? Data { return data }
        if let data = value as? NSData { return data as Data }
        return nil
    }

    private static func notifyRunningMacHelper(
        profileStateData: Data,
        activeCustomizationData: Data?,
        keyBindingsData: Data?,
        profileKeyBindingsData: Data
    ) {
        var userInfo: [String: Any] = [
            notificationProfileStateDataKey: profileStateData,
            notificationProfileKeyBindingsDataKey: profileKeyBindingsData
        ]
        if let activeCustomizationData { userInfo[notificationActiveCustomizationDataKey] = activeCustomizationData }
        if let keyBindingsData { userInfo[notificationKeyBindingsDataKey] = keyBindingsData }

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

    private static func parseShapeStyleIfPresent(_ text: String) -> GamepadButtonShapeStyle? {
        GamepadButtonShapeStyle(rawValue: text) ?? GamepadButtonShapeStyle.allCases.first { normalizedLookup($0.displayName) == normalizedLookup(text) }
    }

    private static func parseCustomControlKind(_ text: String) throws -> GamepadCustomControlKind {
        if let value = GamepadCustomControlKind(rawValue: text) { return value }
        let normalized = normalizedLookup(text)
        if normalized == "shape" { return .button }
        if normalized == "stick" { return .joystick }
        throw CLIError.message("Unknown element kind: \(text)")
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

    private static func joystickMapping(from arguments: [String], fallback: GamepadJoystickMapping = .movement) throws -> GamepadJoystickMapping {
        var mapping = fallback
        if let value = optionValue("--up", in: arguments) { mapping.up = try parseButton(value) }
        if let value = optionValue("--down", in: arguments) { mapping.down = try parseButton(value) }
        if let value = optionValue("--left", in: arguments) { mapping.left = try parseButton(value) }
        if let value = optionValue("--right", in: arguments) { mapping.right = try parseButton(value) }
        return mapping
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
                joystickMapping: nil
            )
        }
        summaries += customization.customButtons.map { custom in
            let normalized = custom.normalized
            return ElementSummary(
                id: normalized.id.uuidString,
                kind: normalized.isJoystick ? "joystick" : "button",
                mappedButton: normalized.mappedButton,
                label: normalized.visualLabel(fallback: normalized.mappedButton.displayName),
                isHidden: normalized.layout.isHidden,
                isLocationLocked: normalized.layout.isLocationLocked,
                layout: normalized.layout,
                joystickMapping: normalized.joystickMapping
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
            "--sequence", "--key", "--modifiers", "--mods", "--layout", "--scale", "--control-scale",
            "--appearance", "--color-scheme", "--scheme", "--accent", "--color", "--labels", "--label", "--maps-to", "--x", "--center-x", "--y", "--center-y",
            "--width", "--width-scale", "--height", "--height-scale", "--shape", "--fill", "--light-fill", "--fill-light",
            "--light-color", "--dark-fill", "--fill-dark", "--dark-color", "--opacity", "--light-opacity", "--dark-opacity",
            "--corner", "--radius", "--corner-tl", "--corner-tr", "--corner-br", "--corner-bl", "--shadow",
            "--shadow-strength", "--kind", "--up", "--down", "--left", "--right", "--hold-ms"
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
        print("Layout: \(profile.customization.layoutMode.rawValue)")
        print("Scale: \(profile.customization.controlScale.rawValue)")
        print("Appearance: \(profile.customization.colorSchemePreference.rawValue)")
        print("Accent: \(profile.customization.accentStyle.rawValue)")
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
          pocketpad generate --spec agent-keypad.json
          pocketpad install-spec agent-keypad.json

        Profiles:
          pocketpad profile list [--ids|--json]
          pocketpad profile show [active|default|NAME|UUID] [--json]
          pocketpad profile create NAME [--blank|--template TEMPLATE|--from PROFILE]
          pocketpad profile select NAME|UUID
          pocketpad profile default NAME|UUID
          pocketpad profile rename NAME|UUID NEW_NAME
          pocketpad profile duplicate [NAME|UUID] [NEW_NAME]
          pocketpad profile delete NAME|UUID
          pocketpad profile reset [NAME|UUID]
          pocketpad profile export [NAME|UUID|--all] [-o file.json]
          pocketpad profile import file.json [--default] [--append]

        Templates:
          pocketpad template list
          pocketpad template install nes [--name "My NES"] [--default]

        Bindings:
          pocketpad binding list [--profile PROFILE]
          pocketpad binding set jump Return
          pocketpad binding set focus --sequence 'Control+B,H'
          pocketpad binding reset jump
          pocketpad binding reset-all

        Customization:
          pocketpad customization set --layout standard --scale large --appearance dark --accent blue --show-labels
          pocketpad customization export -o customization.json
          pocketpad element list
          pocketpad element add button --label Fire --maps-to custom1 --x 0.5 --y 0.8 --light-fill '#F59E0B' --dark-fill '#78350F'
          pocketpad element add joystick --label "Right Stick" --up custom1 --down custom2 --left custom3 --right custom4
          pocketpad element set jump --label A --light-fill '#7C3AED' --dark-fill '#C4B5FD' --shape circle --width 1.2 --height 1.2

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

    var errorDescription: String? {
        switch self {
        case .helpRequested:
            "Help requested"
        case .message(let message):
            message
        }
    }
}
