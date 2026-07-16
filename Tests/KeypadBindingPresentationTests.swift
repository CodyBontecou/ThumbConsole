import XCTest

final class KeypadBindingPresentationTests: XCTestCase {
    func testControllerMessageWithoutPresentationsRemainsDecodable() throws {
        let oldPayload = Data(#"{"type":"gamepad_profiles","timestamp":0,"gamepadProfiles":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(ControllerMessage.self, from: oldPayload)
        XCTAssertEqual(decoded.type, .gamepadProfiles)
        XCTAssertNil(decoded.bindingPresentations)
    }

    func testControllerMessagePresentationRoundTrip() throws {
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
        let input = KeypadElementInputID(elementID: UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!)
        let presentations = [
            GamepadProfileBindingPresentations(
                profileID: profileID,
                entries: [KeypadBindingPresentation(input: input, compactText: "⌘K", accessibilityText: "Command K")]
            )
        ]
        let message = ControllerMessage(type: .gamepadProfiles, bindingPresentations: presentations)
        let decoded = try JSONDecoder().decode(ControllerMessage.self, from: JSONEncoder().encode(message))
        XCTAssertEqual(decoded.bindingPresentations, presentations)
    }

    func testCompactAndAccessibilityFormatting() throws {
        let palette = try XCTUnwrap(KeypadBindingFormatter.format(
            KeypadKeyboardBinding(keyCode: 35, modifiersRawValue: (1 << 0) | (1 << 1))
        ))
        XCTAssertEqual(palette.compactText, "⇧⌘P")
        XCTAssertEqual(palette.accessibilityText, "Shift Command P")

        let escape = try XCTUnwrap(KeypadBindingFormatter.format(KeypadKeyboardBinding(keyCode: 53)))
        XCTAssertEqual(escape.compactText, "Esc")
        XCTAssertEqual(escape.accessibilityText, "Escape")

        let space = try XCTUnwrap(KeypadBindingFormatter.format(KeypadKeyboardBinding(keyCode: 49)))
        XCTAssertEqual(space.compactText, "Space")
        XCTAssertEqual(space.accessibilityText, "Space")

        let sequence = try XCTUnwrap(KeypadBindingFormatter.format(
            KeypadKeyboardBinding(
                keyCode: 11,
                modifiersRawValue: 1 << 3,
                sequence: [
                    KeypadKeyboardStrokeBinding(keyCode: 11, modifiersRawValue: 1 << 3),
                    KeypadKeyboardStrokeBinding(keyCode: 4)
                ]
            )
        ))
        XCTAssertEqual(sequence.compactText, "⌃B › H")
        XCTAssertEqual(sequence.accessibilityText, "Control B, then H")
    }

    func testPerProfilePresentationsAreIsolated() throws {
        let first = GamepadConfigurationProfile(name: "First", customization: .defaultValue)
        let second = GamepadConfigurationProfile(name: "Second", customization: .defaultValue)
        let firstOutputs: [GameButton: KeypadElementOutputBinding] = [
            .jump: KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 49))
        ]
        let secondOutputs: [GameButton: KeypadElementOutputBinding] = [
            .jump: KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 36))
        ]

        let all = KeypadBindingPresentationBuilder.presentations(for: first, effectiveLegacyOutputs: firstOutputs)
            + KeypadBindingPresentationBuilder.presentations(for: second, effectiveLegacyOutputs: secondOutputs)
        let jumpInput = KeypadElementInputID(elementID: KeypadElement.builtInID(for: .jump))
        XCTAssertEqual(
            all.bindingPresentation(profileID: first.id, orientation: .landscape, input: jumpInput)?.compactText,
            "Space"
        )
        XCTAssertEqual(
            all.bindingPresentation(profileID: second.id, orientation: .landscape, input: jumpInput)?.compactText,
            "Return"
        )
    }

    func testDirectElementAndLegacyOutputsAreBothPresented() throws {
        var customization = GamepadCustomization.defaultValue.normalized
        let jumpID = KeypadElement.builtInID(for: .jump)
        let pauseID = KeypadElement.builtInID(for: .pause)
        let jumpIndex = try XCTUnwrap(customization.elements.firstIndex { $0.id == jumpID })
        customization.elements[jumpIndex].setOutputBinding(
            KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 53))
        )
        let profile = GamepadConfigurationProfile(name: "Mixed", customization: customization)
        let legacy: [GameButton: KeypadElementOutputBinding] = [
            .jump: KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 49)),
            .pause: KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 49))
        ]
        let presentations = KeypadBindingPresentationBuilder.presentations(for: profile, effectiveLegacyOutputs: legacy)

        XCTAssertEqual(
            presentations.bindingPresentation(
                profileID: profile.id,
                orientation: .landscape,
                input: KeypadElementInputID(elementID: jumpID)
            )?.compactText,
            "Esc",
            "Direct element output must override its legacy slot"
        )
        XCTAssertEqual(
            presentations.bindingPresentation(
                profileID: profile.id,
                orientation: .landscape,
                input: KeypadElementInputID(elementID: pauseID)
            )?.compactText,
            "Space",
            "Legacy profile output must remain available"
        )
    }

    func testOfflinePresentationPersistenceReplacesSnapshot() throws {
        let suiteName = "KeypadBindingPresentationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profileID = UUID()
        let first = [GamepadProfileBindingPresentations(profileID: profileID, entries: [])]
        KeypadBindingPresentationPersistence.save(first, to: defaults)
        XCTAssertEqual(KeypadBindingPresentationPersistence.load(from: defaults), first)

        let replacement = [
            GamepadProfileBindingPresentations(
                profileID: profileID,
                orientation: .portrait,
                entries: [
                    KeypadBindingPresentation(
                        input: KeypadElementInputID(elementID: UUID()),
                        compactText: "Esc",
                        accessibilityText: "Escape"
                    )
                ]
            )
        ]
        KeypadBindingPresentationPersistence.save(replacement, to: defaults)
        XCTAssertEqual(KeypadBindingPresentationPersistence.load(from: defaults), replacement)
    }
}
