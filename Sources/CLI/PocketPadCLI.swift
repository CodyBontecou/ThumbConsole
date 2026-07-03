import Foundation

@main
struct PocketPadCLI {
    private static let appDefaultsDomain = "com.codybontecou.PocketPadMac"
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

    private struct GenerateOptions {
        var gameName: String?
        var specPath: String?
        var install = true
        var select = true
        var makeDefault = true
        var printJSON = false
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

        switch first {
        case "--help", "-h", "help":
            throw CLIError.helpRequested
        case "generate":
            try generate(arguments: Array(arguments.dropFirst()))
        case "install-spec", "import":
            let rest = Array(arguments.dropFirst())
            guard let path = rest.first else {
                throw CLIError.message("Missing spec path")
            }
            try generate(arguments: ["--spec", path] + Array(rest.dropFirst()))
        case "profile":
            try profile(arguments: Array(arguments.dropFirst()))
        default:
            try generate(arguments: arguments)
        }
    }

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
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(generated)
            print(String(decoding: data, as: UTF8.self))
        }

        if options.install {
            try install(generated: generated, macBindings: macBindings, select: options.select, makeDefault: options.makeDefault)
            printSummary(generated: generated, macBindings: macBindings, installed: true, selected: options.select)
        } else if !options.printJSON {
            printSummary(generated: generated, macBindings: macBindings, installed: false, selected: false)
        }
    }

    private static func profile(arguments: [String]) throws {
        guard let subcommand = arguments.first else { throw CLIError.message("Missing profile subcommand") }
        switch subcommand {
        case "list":
            let state = loadProfileState(from: loadAppDomain())
            for profile in state.profiles {
                let activeMarker = profile.id == state.activeProfileID ? "*" : " "
                let defaultMarker = profile.id == state.defaultProfileID ? "default" : ""
                print("\(activeMarker) \(profile.name) \(defaultMarker)")
            }
        default:
            throw CLIError.message("Unknown profile subcommand: \(subcommand)")
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
                guard index < arguments.count else {
                    throw CLIError.message("Missing path after \(argument)")
                }
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
                if argument.hasPrefix("-") {
                    throw CLIError.message("Unknown option: \(argument)")
                }
                gameNameParts.append(argument)
            }
            index += 1
        }

        let gameName = gameNameParts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if !gameName.isEmpty {
            options.gameName = gameName
        }
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
        generated: GeneratedGameKeypadProfile,
        macBindings: [GameButton: MacKeyBinding],
        select: Bool,
        makeDefault: Bool
    ) throws {
        var domain = loadAppDomain()
        let existingState = loadProfileState(from: domain)
        var profiles = existingState.profiles
        var profile = generated.profile.normalized

        if let existingIndex = profiles.firstIndex(where: { sameProfileName($0.name, profile.name) }) {
            profile.id = profiles[existingIndex].id
            profile.updatedAt = Date.currentMilliseconds
            profiles[existingIndex] = profile
        } else {
            profiles.append(profile)
        }

        let activeProfileID = select ? profile.id : existingState.activeProfileID
        let defaultProfileID = makeDefault ? profile.id : existingState.defaultProfileID
        let normalizedState = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: profiles,
            activeProfileID: activeProfileID,
            defaultProfileID: defaultProfileID,
            fallbackCustomization: profile.customization
        )

        let stateData = try JSONEncoder().encode(
            StoredProfileState(
                profiles: normalizedState.profiles,
                activeProfileID: normalizedState.activeProfileID,
                defaultProfileID: normalizedState.defaultProfileID
            )
        )
        domain[GamepadConfigurationProfilePersistence.defaultsKey] = stateData

        let activeCustomizationData: Data?
        let keyBindingsData: Data?
        if select {
            let customizationData = try JSONEncoder().encode(profile.customization.normalized)
            let bindingsData = try JSONEncoder().encode(rawBindings(macBindings))
            activeCustomizationData = customizationData
            keyBindingsData = bindingsData
            domain[GamepadCustomizationPersistence.defaultsKey] = customizationData
            domain[keyBindingsDefaultsKey] = bindingsData
        } else {
            activeCustomizationData = nil
            keyBindingsData = nil
        }

        var profileBindings = loadProfileBindings(from: domain)
        profileBindings[profile.id.uuidString] = rawBindings(macBindings)
        let profileKeyBindingsData = try JSONEncoder().encode(profileBindings)
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
        else {
            return [:]
        }
        return decoded
    }

    private static func rawBindings(_ bindings: [GameButton: MacKeyBinding]) -> [String: MacKeyBinding] {
        Dictionary(uniqueKeysWithValues: bindings.map { button, binding in
            (button.rawValue, binding)
        })
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
        if let activeCustomizationData {
            userInfo[notificationActiveCustomizationDataKey] = activeCustomizationData
        }
        if let keyBindingsData {
            userInfo[notificationKeyBindingsDataKey] = keyBindingsData
        }

        DistributedNotificationCenter.default().postNotificationName(
            profileStoreChangedNotificationName,
            object: nil,
            userInfo: userInfo,
            deliverImmediately: true
        )
    }

    private static func sameProfileName(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(rhs.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
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
        for note in generated.notes {
            print("- \(note)")
        }
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

    private static func printHelp() {
        print("""
        pocketpad — generate and install PocketPad keypad profiles

        Usage:
          pocketpad generate "Hollow Knight" [--json] [--dry-run]
          pocketpad generate --spec agent-keypad.json
          pocketpad generate --stdin < agent-keypad.json
          pocketpad install-spec agent-keypad.json
          pocketpad profile list

        Defaults:
          `generate` installs, selects, and marks the generated profile as default.
          Unknown games do not use a hardcoded fallback; pass --spec with an
          agent-generated best-guess control list instead.

        Options:
          --spec, --from-spec PATH   Read an agent-provided keypad JSON spec
          --stdin                    Read an agent-provided keypad JSON spec from stdin
          --dry-run, --no-install   Generate only; do not write PocketPad Mac defaults
          --no-select               Install without selecting the profile
          --no-default              Install/select without making it the startup default
          --json                    Also print the generated profile JSON
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
