import Foundation

public struct KeypadBindingPresentation: Codable, Equatable, Hashable, Sendable {
    public var input: KeypadElementInputID
    public var compactText: String
    public var accessibilityText: String

    public init(input: KeypadElementInputID, compactText: String, accessibilityText: String) {
        self.input = input
        self.compactText = compactText
        self.accessibilityText = accessibilityText
    }
}

public struct GamepadProfileBindingPresentations: Codable, Equatable, Sendable {
    public var profileID: UUID
    /// Nil means the same presentation applies in every orientation.
    public var orientation: GamepadEditorDeviceOrientation?
    public var entries: [KeypadBindingPresentation]

    public init(
        profileID: UUID,
        orientation: GamepadEditorDeviceOrientation? = nil,
        entries: [KeypadBindingPresentation]
    ) {
        self.profileID = profileID
        self.orientation = orientation
        self.entries = entries
    }
}

public extension Collection where Element == GamepadProfileBindingPresentations {
    func bindingPresentation(
        profileID: UUID,
        orientation: GamepadEditorDeviceOrientation,
        input: KeypadElementInputID
    ) -> KeypadBindingPresentation? {
        let profilePresentations = filter { $0.profileID == profileID }
        let entries = profilePresentations.first { $0.orientation == orientation }?.entries
            ?? profilePresentations.first { $0.orientation == nil }?.entries
        return entries?.first { $0.input == input }
    }
}

public struct KeypadBindingFormattedText: Codable, Equatable, Hashable, Sendable {
    public var compactText: String
    public var accessibilityText: String

    public init(compactText: String, accessibilityText: String) {
        self.compactText = compactText
        self.accessibilityText = accessibilityText
    }
}

public enum KeypadBindingFormatter {
    private static let command: UInt8 = 1 << 0
    private static let shift: UInt8 = 1 << 1
    private static let option: UInt8 = 1 << 2
    private static let control: UInt8 = 1 << 3

    public static func format(_ binding: KeypadElementOutputBinding) -> KeypadBindingFormattedText? {
        var compactParts: [String] = []
        var accessibleParts: [String] = []
        if let keyboard = binding.keyboard, let formatted = format(keyboard) {
            compactParts.append(formatted.compactText)
            accessibleParts.append(formatted.accessibilityText)
        }
        for button in binding.gamepadButtons.sorted(by: gamepadDisplayOrder) {
            compactParts.append(button.shortName)
            accessibleParts.append(button.displayName)
        }
        guard !compactParts.isEmpty else { return nil }
        return KeypadBindingFormattedText(
            compactText: compactParts.joined(separator: " + "),
            accessibilityText: accessibleParts.joined(separator: " plus ")
        )
    }

    public static func format(_ binding: KeypadKeyboardBinding) -> KeypadBindingFormattedText? {
        let strokes = binding.strokes
        guard !strokes.isEmpty else { return nil }
        let formatted = strokes.map(format)
        return KeypadBindingFormattedText(
            compactText: formatted.map(\.compactText).joined(separator: " › "),
            accessibilityText: formatted.map(\.accessibilityText).joined(separator: ", then ")
        )
    }

    public static func format(_ stroke: KeypadKeyboardStrokeBinding) -> KeypadBindingFormattedText {
        let compactKey = keyName(for: stroke.keyCode, accessible: false)
        let accessibleKey = keyName(for: stroke.keyCode, accessible: true)
        var symbols = ""
        var modifierNames: [String] = []
        if stroke.modifiersRawValue & control != 0 {
            symbols += "⌃"
            modifierNames.append("Control")
        }
        if stroke.modifiersRawValue & option != 0 {
            symbols += "⌥"
            modifierNames.append("Option")
        }
        if stroke.modifiersRawValue & shift != 0 {
            symbols += "⇧"
            modifierNames.append("Shift")
        }
        if stroke.modifiersRawValue & command != 0 {
            symbols += "⌘"
            modifierNames.append("Command")
        }
        modifierNames.append(accessibleKey)
        return KeypadBindingFormattedText(
            compactText: symbols + compactKey,
            accessibilityText: modifierNames.joined(separator: " ")
        )
    }

    private static func gamepadDisplayOrder(_ lhs: VirtualGamepadButton, _ rhs: VirtualGamepadButton) -> Bool {
        (VirtualGamepadButton.allCases.firstIndex(of: lhs) ?? VirtualGamepadButton.allCases.endIndex)
            < (VirtualGamepadButton.allCases.firstIndex(of: rhs) ?? VirtualGamepadButton.allCases.endIndex)
    }

    private static func keyName(for keyCode: UInt16, accessible: Bool) -> String {
        if let pair = specialKeyNames[keyCode] {
            return accessible ? pair.accessible : pair.compact
        }
        return keyNames[keyCode] ?? "Key \(keyCode)"
    }

    private static let specialKeyNames: [UInt16: (compact: String, accessible: String)] = [
        36: ("Return", "Return"), 48: ("Tab", "Tab"), 49: ("Space", "Space"),
        51: ("Delete", "Delete"), 53: ("Esc", "Escape"), 54: ("⌘", "Right Command"),
        55: ("⌘", "Command"), 56: ("⇧", "Shift"), 57: ("Caps", "Caps Lock"),
        58: ("⌥", "Option"), 59: ("⌃", "Control"), 60: ("⇧", "Right Shift"),
        61: ("⌥", "Right Option"), 62: ("⌃", "Right Control"), 63: ("Fn", "Function"),
        71: ("Clear", "Clear"), 76: ("⌤", "Keypad Enter"), 114: ("Help", "Help"),
        115: ("Home", "Home"), 116: ("PgUp", "Page Up"), 117: ("⌦", "Forward Delete"),
        119: ("End", "End"), 121: ("PgDn", "Page Down"), 123: ("←", "Left Arrow"),
        124: ("→", "Right Arrow"), 125: ("↓", "Down Arrow"), 126: ("↑", "Up Arrow")
    ]

    private static let keyNames: [UInt16: String] = [
        0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",
        12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",
        22:"6",23:"5",24:"=",25:"9",26:"7",27:"-",28:"8",29:"0",30:"]",31:"O",
        32:"U",33:"[",34:"I",35:"P",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",
        43:",",44:"/",45:"N",46:"M",47:".",50:"`",64:"F17",65:"Keypad .",67:"Keypad *",
        69:"Keypad +",75:"Keypad /",78:"Keypad -",81:"Keypad =",82:"Keypad 0",83:"Keypad 1",
        84:"Keypad 2",85:"Keypad 3",86:"Keypad 4",87:"Keypad 5",88:"Keypad 6",89:"Keypad 7",
        91:"Keypad 8",92:"Keypad 9",96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",101:"F9",
        103:"F11",105:"F13",106:"F16",107:"F14",109:"F10",111:"F12",113:"F15",118:"F4",
        120:"F2",122:"F1"
    ]
}

public enum KeypadBindingPresentationBuilder {
    public static func presentations(
        for profile: GamepadConfigurationProfile,
        effectiveLegacyOutputs: [GameButton: KeypadElementOutputBinding]
    ) -> [GamepadProfileBindingPresentations] {
        let landscape = entries(
            customization: profile.customization(for: .landscape),
            effectiveLegacyOutputs: effectiveLegacyOutputs
        )
        let portrait = entries(
            customization: profile.customization(for: .portrait),
            effectiveLegacyOutputs: effectiveLegacyOutputs
        )
        if landscape == portrait {
            return [GamepadProfileBindingPresentations(profileID: profile.id, entries: landscape)]
        }
        return [
            GamepadProfileBindingPresentations(profileID: profile.id, orientation: .landscape, entries: landscape),
            GamepadProfileBindingPresentations(profileID: profile.id, orientation: .portrait, entries: portrait)
        ]
    }

    public static func entries(
        customization: GamepadCustomization,
        effectiveLegacyOutputs: [GameButton: KeypadElementOutputBinding]
    ) -> [KeypadBindingPresentation] {
        var entries: [KeypadBindingPresentation] = []
        for element in customization.normalized.elements {
            var relevantParts: Set<KeypadElementInputPart> = [.primary]
            relevantParts.formUnion(element.partOutputs.keys)
            if element.kind == .joystick {
                relevantParts.formUnion([.joystickUp, .joystickDown, .joystickLeft, .joystickRight])
            }
            if element.kind == .trigger {
                relevantParts.insert(.triggerDigital)
            }
            for part in KeypadElementInputPart.allCases where relevantParts.contains(part) {
                let output = element.outputBinding(for: part)
                    ?? legacyButton(for: part, element: element).flatMap { effectiveLegacyOutputs[$0] }
                guard let output, let text = KeypadBindingFormatter.format(output) else { continue }
                entries.append(
                    KeypadBindingPresentation(
                        input: KeypadElementInputID(elementID: element.id, part: part),
                        compactText: text.compactText,
                        accessibilityText: text.accessibilityText
                    )
                )
            }
        }
        return entries.sorted { $0.input.storageKey < $1.input.storageKey }
    }

    private static func legacyButton(for part: KeypadElementInputPart, element: KeypadElement) -> GameButton? {
        switch part {
        case .primary, .triggerDigital: element.legacySlot
        case .joystickUp: element.joystickMapping?.up
        case .joystickDown: element.joystickMapping?.down
        case .joystickLeft: element.joystickMapping?.left
        case .joystickRight: element.joystickMapping?.right
        }
    }
}

public enum KeypadBindingPresentationPersistence {
    public static let defaultsKey = "PocketPad.iOS.bindingPresentations.v1"

    public static func load(from defaults: UserDefaults = .standard) -> [GamepadProfileBindingPresentations] {
        guard let data = defaults.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([GamepadProfileBindingPresentations].self, from: data)) ?? []
    }

    public static func save(_ presentations: [GamepadProfileBindingPresentations], to defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(presentations) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
