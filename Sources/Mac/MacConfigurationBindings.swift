import Foundation

/// Pure binding/output transformations shared by the standalone CLI and the
/// constrained configuration bridge. Persistence, revisions, and timestamps
/// remain the caller's responsibility.
enum MacConfigurationBindings {
    static func decodedKeyBindings(
        _ raw: [String: MacKeyBinding]?
    ) -> [GameButton: MacKeyBinding]? {
        guard let raw else { return nil }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, binding in
            guard let button = GameButton(rawValue: key) else { return nil }
            return (button, binding)
        })
    }

    static func rawKeyBindings(
        _ bindings: [GameButton: MacKeyBinding]
    ) -> [String: MacKeyBinding] {
        Dictionary(uniqueKeysWithValues: bindings.map { button, binding in
            (button.rawValue, binding)
        })
    }

    static func keyboardOutputs(
        from keyBindings: [GameButton: MacKeyBinding]
    ) -> [GameButton: MacControlOutputBinding] {
        Dictionary(uniqueKeysWithValues: keyBindings.map { button, binding in
            (button, MacControlOutputBinding.keyboard(binding))
        })
    }

    static func effectiveOutputs(
        for mode: GamepadProfileOutputMode,
        keyBindings: [GameButton: MacKeyBinding],
        customOutputs: [GameButton: MacControlOutputBinding]
    ) -> [GameButton: MacControlOutputBinding] {
        switch mode {
        case .keyboard:
            keyboardOutputs(from: keyBindings)
        case .controller:
            DefaultMacControlOutputMap.xboxStyleBindings
        case .custom:
            customOutputs.isEmpty ? keyboardOutputs(from: keyBindings) : customOutputs
        }
    }

    static func decodedOutputs(
        _ raw: [String: MacControlOutputBinding]?
    ) -> [GameButton: MacControlOutputBinding]? {
        guard let raw else { return nil }
        return Dictionary(uniqueKeysWithValues: raw.compactMap { key, binding in
            guard let button = GameButton(rawValue: key), !binding.isEmpty else { return nil }
            return (button, binding)
        })
    }

    static func rawOutputs(
        _ bindings: [GameButton: MacControlOutputBinding]
    ) -> [String: MacControlOutputBinding] {
        Dictionary(uniqueKeysWithValues: bindings.map { button, binding in
            (button.rawValue, binding)
        })
    }

    static func synchronizeElementOutputs(
        in profile: inout GamepadConfigurationProfile,
        outputs: [GameButton: MacControlOutputBinding]
    ) {
        func update(_ customization: inout GamepadCustomization) {
            var normalizedCustomization = customization.normalized
            for button in GameButton.allCases {
                let matchingCustomIDs = Set(
                    normalizedCustomization.customButtons
                        .filter { $0.mappedButton == button }
                        .map(\.id)
                )
                let sharedBinding = outputs[button]?.sharedBinding
                for index in normalizedCustomization.elements.indices {
                    let element = normalizedCustomization.elements[index]
                    guard element.builtInButton == button
                            || element.legacySlot == button
                            || matchingCustomIDs.contains(element.id)
                    else { continue }
                    normalizedCustomization.elements[index].setOutputBinding(
                        sharedBinding,
                        for: .primary
                    )
                }
            }
            customization = normalizedCustomization.normalized
        }

        update(&profile.customization)
        if var landscape = profile.landscapeCustomization {
            update(&landscape)
            profile.landscapeCustomization = landscape
        }
        if var portrait = profile.portraitCustomization {
            update(&portrait)
            profile.portraitCustomization = portrait
        }
    }
}
