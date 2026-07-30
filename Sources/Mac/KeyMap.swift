import AppKit
import CoreGraphics

struct MacKeyModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt8

    static let command = MacKeyModifiers(rawValue: 1 << 0)
    static let shift = MacKeyModifiers(rawValue: 1 << 1)
    static let option = MacKeyModifiers(rawValue: 1 << 2)
    static let control = MacKeyModifiers(rawValue: 1 << 3)

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    init(eventFlags: NSEvent.ModifierFlags) {
        var modifiers: MacKeyModifiers = []
        let deviceIndependentFlags = eventFlags.intersection(.deviceIndependentFlagsMask)

        if deviceIndependentFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if deviceIndependentFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if deviceIndependentFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if deviceIndependentFlags.contains(.control) {
            modifiers.insert(.control)
        }

        self = modifiers
    }

    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        if contains(.command) { flags.insert(.maskCommand) }
        if contains(.shift) { flags.insert(.maskShift) }
        if contains(.option) { flags.insert(.maskAlternate) }
        if contains(.control) { flags.insert(.maskControl) }
        return flags
    }

    var displaySymbols: String {
        var symbols = ""
        if contains(.control) { symbols += "⌃" }
        if contains(.option) { symbols += "⌥" }
        if contains(.shift) { symbols += "⇧" }
        if contains(.command) { symbols += "⌘" }
        return symbols
    }

    init?(generatedModifierNames names: [String]) {
        var modifiers: MacKeyModifiers = []
        for name in names {
            switch Self.normalizedModifierName(name) {
            case "cmd", "command", "meta":
                modifiers.insert(.command)
            case "shift":
                modifiers.insert(.shift)
            case "opt", "option", "alt":
                modifiers.insert(.option)
            case "ctrl", "control":
                modifiers.insert(.control)
            case "":
                continue
            default:
                return nil
            }
        }
        self = modifiers
    }

    private static func normalizedModifierName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

struct MacKeyStroke: Codable, Equatable, Hashable, Sendable {
    var keyCode: CGKeyCode
    var modifiers: MacKeyModifiers

    init(keyCode: CGKeyCode, modifiers: MacKeyModifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        self.init(
            keyCode: CGKeyCode(event.keyCode),
            modifiers: MacKeyModifiers(eventFlags: event.modifierFlags)
        )
    }

    var displayName: String {
        KeypadBindingFormatter.format(sharedBinding).compactText
    }

    func withAdditionalModifiers(_ additionalModifiers: MacKeyModifiers) -> MacKeyStroke {
        var copy = self
        copy.modifiers.formUnion(additionalModifiers)
        return copy
    }

    func cgEventFlags(keyDown: Bool) -> CGEventFlags {
        var flags = modifiers.cgEventFlags

        if keyDown, let modifierFlag = MacVirtualKey.modifierFlag(for: keyCode) {
            flags.insert(modifierFlag)
        }

        return flags
    }
}

struct MacKeyBinding: Codable, Equatable, Hashable, Sendable {
    var keyCode: CGKeyCode
    var modifiers: MacKeyModifiers
    var sequence: [MacKeyStroke]?

    init(keyCode: CGKeyCode, modifiers: MacKeyModifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.sequence = nil
    }

    init(stroke: MacKeyStroke) {
        self.init(keyCode: stroke.keyCode, modifiers: stroke.modifiers)
    }

    init(strokes: [MacKeyStroke]) {
        guard let firstStroke = strokes.first else {
            keyCode = MacVirtualKey.escape
            modifiers = []
            sequence = nil
            return
        }

        keyCode = firstStroke.keyCode
        modifiers = firstStroke.modifiers
        sequence = strokes.count > 1 ? strokes : nil
    }

    init(event: NSEvent) {
        self.init(stroke: MacKeyStroke(event: event))
    }

    init?(generatedSpec spec: GeneratedKeyBindingSpec) {
        guard let keyCode = MacVirtualKey.keyCode(named: spec.key),
              let modifiers = MacKeyModifiers(generatedModifierNames: spec.modifiers)
        else {
            return nil
        }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    var strokes: [MacKeyStroke] {
        guard let sequence, !sequence.isEmpty else {
            return [MacKeyStroke(keyCode: keyCode, modifiers: modifiers)]
        }
        return sequence
    }

    var isSequence: Bool {
        strokes.count > 1
    }

    var displayName: String {
        KeypadBindingFormatter.format(sharedBinding)?.compactText ?? "Unmapped"
    }

    var accessibleDisplayName: String {
        KeypadBindingFormatter.format(sharedBinding)?.accessibilityText ?? "Unmapped"
    }

    func withAdditionalModifiers(_ additionalModifiers: MacKeyModifiers) -> MacKeyBinding {
        guard isSequence else {
            var copy = self
            copy.modifiers.formUnion(additionalModifiers)
            return copy
        }

        return MacKeyBinding(strokes: strokes.map { $0.withAdditionalModifiers(additionalModifiers) })
    }

    func cgEventFlags(keyDown: Bool) -> CGEventFlags {
        MacKeyStroke(keyCode: keyCode, modifiers: modifiers).cgEventFlags(keyDown: keyDown)
    }

    static let controlKey = MacKeyBinding(keyCode: MacVirtualKey.control)
    static let optionKey = MacKeyBinding(keyCode: MacVirtualKey.option)
    static let shiftKey = MacKeyBinding(keyCode: MacVirtualKey.shift)
    static let commandKey = MacKeyBinding(keyCode: MacVirtualKey.command)
    static let tmuxPrefix = MacKeyBinding(keyCode: MacVirtualKey.b, modifiers: .control)
    static let herdrLeft = MacKeyBinding(strokes: [.init(keyCode: MacVirtualKey.b, modifiers: .control), .init(keyCode: MacVirtualKey.h)])
    static let herdrDown = MacKeyBinding(strokes: [.init(keyCode: MacVirtualKey.b, modifiers: .control), .init(keyCode: MacVirtualKey.j)])
    static let herdrUp = MacKeyBinding(strokes: [.init(keyCode: MacVirtualKey.b, modifiers: .control), .init(keyCode: MacVirtualKey.k)])
    static let herdrRight = MacKeyBinding(strokes: [.init(keyCode: MacVirtualKey.b, modifiers: .control), .init(keyCode: MacVirtualKey.l)])
}

/// General-purpose starter bindings for a programmable Mac keypad.
enum DefaultKeypadKeyMap {
    static let defaultBindings: [GameButton: MacKeyBinding] = [
        .left: MacKeyBinding(keyCode: MacVirtualKey.leftArrow),
        .right: MacKeyBinding(keyCode: MacVirtualKey.rightArrow),
        .up: MacKeyBinding(keyCode: MacVirtualKey.upArrow),
        .down: MacKeyBinding(keyCode: MacVirtualKey.downArrow),
        .jump: MacKeyBinding(keyCode: MacVirtualKey.returnKey),
        .attack: MacKeyBinding(keyCode: MacVirtualKey.tab),
        .dash: MacKeyBinding(keyCode: MacVirtualKey.k, modifiers: .command),
        .focus: .tmuxPrefix,
        .map: MacKeyBinding(keyCode: MacVirtualKey.p, modifiers: [.command, .shift]),
        .pause: MacKeyBinding(keyCode: MacVirtualKey.escape)
    ]

    static func defaultBinding(for button: GameButton) -> MacKeyBinding? {
        defaultBindings[button]
    }
}

enum MacVirtualKey {
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let downArrow: CGKeyCode = 125
    static let upArrow: CGKeyCode = 126

    static let a: CGKeyCode = 0
    static let s: CGKeyCode = 1
    static let d: CGKeyCode = 2
    static let h: CGKeyCode = 4
    static let z: CGKeyCode = 6
    static let x: CGKeyCode = 7
    static let c: CGKeyCode = 8
    static let b: CGKeyCode = 11
    static let q: CGKeyCode = 12
    static let w: CGKeyCode = 13
    static let e: CGKeyCode = 14
    static let r: CGKeyCode = 15
    static let p: CGKeyCode = 35
    static let l: CGKeyCode = 37
    static let j: CGKeyCode = 38
    static let k: CGKeyCode = 40

    static let returnKey: CGKeyCode = 36
    static let tab: CGKeyCode = 48
    static let space: CGKeyCode = 49
    static let escape: CGKeyCode = 53
    static let command: CGKeyCode = 55
    static let shift: CGKeyCode = 56
    static let option: CGKeyCode = 58
    static let control: CGKeyCode = 59

    static func displayName(for keyCode: CGKeyCode) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    static func keyCode(named name: String) -> CGKeyCode? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let exactMatch = keyNames.first(where: { $0.value.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return exactMatch.key
        }

        let normalized = normalizedKeyName(trimmed)
        switch normalized {
        case "left", "leftarrow", "arrowleft":
            return leftArrow
        case "right", "rightarrow", "arrowright":
            return rightArrow
        case "up", "uparrow", "arrowup":
            return upArrow
        case "down", "downarrow", "arrowdown":
            return downArrow
        case "esc", "escape":
            return escape
        case "return", "enter":
            return returnKey
        case "space", "spacebar":
            return 49
        case "delete", "backspace":
            return 51
        case "forwarddelete":
            return 117
        default:
            break
        }

        if let namedMatch = keyNames.first(where: { normalizedKeyName($0.value) == normalized }) {
            return namedMatch.key
        }

        if let numericCode = UInt16(trimmed) {
            return CGKeyCode(numericCode)
        }

        return nil
    }

    static func modifierFlag(for keyCode: CGKeyCode) -> CGEventFlags? {
        switch keyCode {
        case 54, 55:
            return .maskCommand
        case 56, 60:
            return .maskShift
        case 58, 61:
            return .maskAlternate
        case 59, 62:
            return .maskControl
        case 63:
            return .maskSecondaryFn
        default:
            return nil
        }
    }

    static func keyModifier(for keyCode: CGKeyCode) -> MacKeyModifiers? {
        switch keyCode {
        case 54, 55:
            return .command
        case 56, 60:
            return .shift
        case 58, 61:
            return .option
        case 59, 62:
            return .control
        default:
            return nil
        }
    }

    private static func normalizedKeyName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static let keyNames: [CGKeyCode: String] = [
        0: "A",
        1: "S",
        2: "D",
        3: "F",
        4: "H",
        5: "G",
        6: "Z",
        7: "X",
        8: "C",
        9: "V",
        11: "B",
        12: "Q",
        13: "W",
        14: "E",
        15: "R",
        16: "Y",
        17: "T",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        24: "=",
        25: "9",
        26: "7",
        27: "-",
        28: "8",
        29: "0",
        30: "]",
        31: "O",
        32: "U",
        33: "[",
        34: "I",
        35: "P",
        36: "Return",
        37: "L",
        38: "J",
        39: "'",
        40: "K",
        41: ";",
        42: "\\",
        43: ",",
        44: "/",
        45: "N",
        46: "M",
        47: ".",
        48: "Tab",
        49: "Space",
        50: "`",
        51: "Delete",
        53: "Esc",
        54: "Right Command",
        55: "Command",
        56: "Shift",
        57: "Caps Lock",
        58: "Option",
        59: "Control",
        60: "Right Shift",
        61: "Right Option",
        62: "Right Control",
        63: "Fn",
        64: "F17",
        65: "Keypad .",
        67: "Keypad *",
        69: "Keypad +",
        71: "Clear",
        75: "Keypad /",
        76: "Keypad Enter",
        78: "Keypad -",
        81: "Keypad =",
        82: "Keypad 0",
        83: "Keypad 1",
        84: "Keypad 2",
        85: "Keypad 3",
        86: "Keypad 4",
        87: "Keypad 5",
        88: "Keypad 6",
        89: "Keypad 7",
        91: "Keypad 8",
        92: "Keypad 9",
        96: "F5",
        97: "F6",
        98: "F7",
        99: "F3",
        100: "F8",
        101: "F9",
        103: "F11",
        105: "F13",
        106: "F16",
        107: "F14",
        109: "F10",
        111: "F12",
        113: "F15",
        114: "Help",
        115: "Home",
        116: "Page Up",
        117: "Forward Delete",
        118: "F4",
        119: "End",
        120: "F2",
        121: "Page Down",
        122: "F1",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑"
    ]
}
