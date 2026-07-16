import CoreGraphics
import Foundation

struct MacControlOutputBinding: Codable, Equatable, Hashable, Sendable {
    var keyboard: MacKeyBinding?
    var gamepadButtons: Set<VirtualGamepadButton>

    init(keyboard: MacKeyBinding? = nil, gamepadButtons: Set<VirtualGamepadButton> = []) {
        self.keyboard = keyboard
        self.gamepadButtons = gamepadButtons
    }

    var isEmpty: Bool {
        keyboard == nil && gamepadButtons.isEmpty
    }

    var displayName: String {
        KeypadBindingFormatter.format(sharedBinding)?.compactText ?? "Unmapped"
    }

    var accessibleDisplayName: String {
        KeypadBindingFormatter.format(sharedBinding)?.accessibilityText ?? "Unmapped"
    }

    func withAdditionalModifiers(_ modifiers: MacKeyModifiers) -> MacControlOutputBinding {
        guard let keyboard else { return self }
        var copy = self
        copy.keyboard = keyboard.withAdditionalModifiers(modifiers)
        return copy
    }

    mutating func setKeyboard(_ binding: MacKeyBinding?) {
        keyboard = binding
    }

    mutating func setGamepadButton(_ button: VirtualGamepadButton?) {
        gamepadButtons = button.map { Set([$0]) } ?? []
    }

    static func keyboard(_ binding: MacKeyBinding) -> MacControlOutputBinding {
        MacControlOutputBinding(keyboard: binding)
    }

    init(shared binding: KeypadElementOutputBinding) {
        self.keyboard = binding.keyboard.map(MacKeyBinding.init(shared:))
        self.gamepadButtons = binding.gamepadButtons
    }

    var sharedBinding: KeypadElementOutputBinding {
        KeypadElementOutputBinding(
            keyboard: keyboard?.sharedBinding,
            gamepadButtons: gamepadButtons
        )
    }

    static func gamepadButton(_ button: VirtualGamepadButton) -> MacControlOutputBinding {
        MacControlOutputBinding(gamepadButtons: [button])
    }
}

extension MacKeyStroke {
    init(shared stroke: KeypadKeyboardStrokeBinding) {
        self.init(keyCode: CGKeyCode(stroke.keyCode), modifiers: MacKeyModifiers(rawValue: stroke.modifiersRawValue))
    }

    var sharedBinding: KeypadKeyboardStrokeBinding {
        KeypadKeyboardStrokeBinding(keyCode: UInt16(keyCode), modifiersRawValue: modifiers.rawValue)
    }
}

extension MacKeyBinding {
    init(shared binding: KeypadKeyboardBinding) {
        self.init(strokes: binding.strokes.map(MacKeyStroke.init(shared:)))
    }

    var sharedBinding: KeypadKeyboardBinding {
        let sharedStrokes = strokes.map(\.sharedBinding)
        if sharedStrokes.count > 1 {
            return KeypadKeyboardBinding(
                keyCode: sharedStrokes[0].keyCode,
                modifiersRawValue: sharedStrokes[0].modifiersRawValue,
                sequence: sharedStrokes
            )
        }
        return KeypadKeyboardBinding(keyCode: UInt16(keyCode), modifiersRawValue: modifiers.rawValue)
    }
}

extension Dictionary where Key == GameButton, Value == MacControlOutputBinding {
    var keyboardBindings: [GameButton: MacKeyBinding] {
        reduce(into: [:]) { partial, entry in
            if let keyboard = entry.value.keyboard {
                partial[entry.key] = keyboard
            }
        }
    }
}

extension Set where Element == VirtualGamepadButton {
    var sortedForDisplay: [VirtualGamepadButton] {
        sorted { lhs, rhs in
            let lhsIndex = VirtualGamepadButton.allCases.firstIndex(of: lhs) ?? VirtualGamepadButton.allCases.endIndex
            let rhsIndex = VirtualGamepadButton.allCases.firstIndex(of: rhs) ?? VirtualGamepadButton.allCases.endIndex
            return lhsIndex < rhsIndex
        }
    }
}

extension GamepadControllerTemplate {
    /// Templates whose visible actions promise the standard Mac productivity
    /// shortcuts must install those bindings atomically with the profile rather
    /// than inheriting whichever profile happened to be active.
    var recommendedMacOutputBindings: [GameButton: MacControlOutputBinding]? {
        switch self {
        case .productivityStarter, .productivityOneHandedLeft, .productivityOneHandedRight:
            DefaultMacControlOutputMap.defaultBindings
        default:
            nil
        }
    }
}

enum DefaultMacControlOutputMap {
    static let defaultBindings: [GameButton: MacControlOutputBinding] = Dictionary(
        uniqueKeysWithValues: DefaultKeypadKeyMap.defaultBindings.map { button, binding in
            (button, MacControlOutputBinding.keyboard(binding))
        }
    )

    static func defaultBinding(for button: GameButton) -> MacControlOutputBinding? {
        defaultBindings[button]
    }

    static let xboxStyleBindings: [GameButton: MacControlOutputBinding] = [
        .up: .gamepadButton(.dpadUp),
        .down: .gamepadButton(.dpadDown),
        .left: .gamepadButton(.dpadLeft),
        .right: .gamepadButton(.dpadRight),
        .jump: .gamepadButton(.south),
        .attack: .gamepadButton(.east),
        .dash: .gamepadButton(.west),
        .focus: .gamepadButton(.north),
        .map: .gamepadButton(.select),
        .pause: .gamepadButton(.start),
        .custom1: .gamepadButton(.leftShoulder),
        .custom2: .gamepadButton(.rightShoulder),
        .custom3: .gamepadButton(.leftStickPress),
        .custom4: .gamepadButton(.rightStickPress),
        .custom5: .gamepadButton(.leftTriggerButton),
        .custom6: .gamepadButton(.rightTriggerButton),
        .custom7: .gamepadButton(.home)
    ]
}
