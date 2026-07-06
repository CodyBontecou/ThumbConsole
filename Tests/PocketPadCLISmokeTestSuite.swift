import CoreGraphics
import SwiftUI
import XCTest

final class PocketPadCLISmokeTestSuite: XCTestCase {
    func testKeypadConfigurationExportSchemaRoundTrip() throws {
        var customization = GamepadCustomization.defaultValue
        customization.accentStyle = .blue
        customization.labelOverrides[.jump] = "Fire"
        let profile = GamepadConfigurationProfile(name: "Arcade Test", customization: customization)
        let export = PocketPadKeypadConfigurationExport(
            exportedAt: 123_456,
            profiles: [profile],
            activeProfileID: profile.id,
            defaultProfileID: profile.id
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(export)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"schema\":\"\(PocketPadKeypadConfigurationExport.schemaIdentifier)\""))
        XCTAssertTrue(json.contains("\"version\":\(PocketPadKeypadConfigurationExport.currentVersion)"))

        let decoded = try JSONDecoder().decode(PocketPadKeypadConfigurationExport.self, from: data)
        XCTAssertEqual(decoded.schema, PocketPadKeypadConfigurationExport.schemaIdentifier)
        XCTAssertEqual(decoded.version, PocketPadKeypadConfigurationExport.currentVersion)
        XCTAssertEqual(decoded.exportedAt, 123_456)
        XCTAssertEqual(decoded.profiles.map(\.normalized), [profile.normalized])
        XCTAssertEqual(decoded.activeProfileID, profile.id)
        XCTAssertEqual(decoded.defaultProfileID, profile.id)
    }

    func testKeypadConfigurationNormalizesLegacyButtonsIntoElements() throws {
        var customization = GamepadCustomization.defaultValue.normalized
        XCTAssertFalse(customization.elements.isEmpty)
        XCTAssertNotNil(customization.elements.first { $0.builtInButton == .pause })
        XCTAssertEqual(customization.elements.first { $0.builtInButton == .pause }?.legacySlot, .pause)

        customization.addCustomButton()
        var added = try XCTUnwrap(customization.normalized.elements.first { $0.builtInButton == nil && $0.kind == .button })
        XCTAssertNil(added.legacySlot)

        customization = GamepadCustomization.blankCanvas
        customization.addJoystick()
        added = try XCTUnwrap(customization.normalized.elements.first { $0.kind == .joystick })
        XCTAssertNil(added.legacySlot)

        customization = GamepadCustomization.blankCanvas
        customization.addTrigger()
        added = try XCTUnwrap(customization.normalized.elements.first { $0.kind == .trigger })
        XCTAssertNil(added.legacySlot)

        customization = GamepadCustomization.blankCanvas
        customization.addTrackpad()
        added = try XCTUnwrap(customization.normalized.elements.first { $0.kind == .trackpad })
        XCTAssertNil(added.legacySlot)
    }

    func testElementInputMessageRoundTrips() throws {
        let elementID = UUID(uuidString: "00000000-0000-0000-0000-00000000E1E1")!
        let message = ControllerMessage(
            type: .elementInput,
            elementID: elementID,
            elementPart: .primary,
            state: .down,
            timestamp: ControllerWireCodec.inputSequenceTimestamp(for: 42, pressIdentifier: 7)
        )
        let data = try ControllerWireCodec.encode(message, using: JSONEncoder())
        let decoded = try ControllerWireCodec.decode(data, using: JSONDecoder())
        XCTAssertEqual(decoded.type, .elementInput)
        XCTAssertEqual(decoded.elementID, elementID)
        XCTAssertEqual(decoded.elementPart, .primary)
        XCTAssertEqual(decoded.state, .down)
        XCTAssertEqual(ControllerWireCodec.inputSequenceNumber(from: decoded), 42)
        XCTAssertEqual(ControllerWireCodec.inputPressIdentifier(from: decoded), 7)
    }

    func testKeypadProfileOutputModeDefaultsToKeyboardAndPreservesLegacyBindings() throws {
        let newProfile = GamepadConfigurationProfile(name: "Keyboard Setup", customization: .defaultValue)
        XCTAssertEqual(newProfile.outputMode, .keyboard)

        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-00000000ABCD",
          "name": "Legacy Mixed Setup",
          "customization": {}
        }
        """
        let legacyProfile = try JSONDecoder().decode(GamepadConfigurationProfile.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(legacyProfile.outputMode, .custom)
    }

    func testKeypadConfigurationExportFilenameSanitizesProfileNames() {
        XCTAssertEqual(
            PocketPadKeypadConfigurationExport.suggestedFilename(activeProfileName: "My Arcade / Setup"),
            "PocketPad-My-Arcade-Setup.json"
        )
    }

    func testKeypadConfigurationExportRejectsEmptyProfileLists() {
        let json = """
        {
          "schema": "\(PocketPadKeypadConfigurationExport.schemaIdentifier)",
          "version": 1,
          "profiles": []
        }
        """
        XCTAssertThrowsError(try JSONDecoder().decode(PocketPadKeypadConfigurationExport.self, from: Data(json.utf8)))
    }

    func testCornerRadiiPreserveValuesBeyondRenderedBounds() {
        let largeRadius: CGFloat = 999
        let uniform = GamepadButtonCustomization(
            shape: .roundedRectangle,
            cornerRadius: largeRadius
        ).normalized
        XCTAssertEqual(uniform.cornerRadius, Optional(largeRadius))

        let uneven = GamepadButtonCustomization(
            shape: .roundedRectangle,
            cornerRadii: GamepadCornerRadii(
                topLeading: largeRadius,
                topTrailing: 320,
                bottomTrailing: 128,
                bottomLeading: 512
            )
        ).normalized
        XCTAssertEqual(uneven.cornerRadii?.topLeading, Optional(largeRadius))
        XCTAssertEqual(uneven.cornerRadii?.topTrailing, Optional(CGFloat(320)))
        XCTAssertEqual(uneven.cornerRadii?.bottomTrailing, Optional(CGFloat(128)))
        XCTAssertEqual(uneven.cornerRadii?.bottomLeading, Optional(CGFloat(512)))
    }

    func testCornerRadiiStillClampNegativeAndNonFiniteValues() {
        let negative = GamepadButtonCustomization(
            shape: .roundedRectangle,
            cornerRadius: -20
        ).normalized
        XCTAssertEqual(negative.cornerRadius, Optional(CGFloat(0)))

        let invalid = GamepadButtonCustomization(
            shape: .roundedRectangle,
            cornerRadii: GamepadCornerRadii(
                topLeading: .nan,
                topTrailing: .infinity,
                bottomTrailing: -.infinity,
                bottomLeading: -4
            )
        ).normalized
        XCTAssertEqual(invalid.cornerRadii?.topLeading, Optional(CGFloat(0)))
        XCTAssertEqual(invalid.cornerRadii?.topTrailing, Optional(CGFloat(0)))
        XCTAssertEqual(invalid.cornerRadii?.bottomTrailing, Optional(CGFloat(0)))
        XCTAssertEqual(invalid.cornerRadii?.bottomLeading, Optional(CGFloat(0)))
    }

    func testTrackpadCustomizationRoundTrips() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-00000000A11D")!
        var customization = GamepadCustomization.blankCanvas
        customization.addTrackpad(id: id)
        guard let trackpad = customization.normalized.customButtons.first(where: { $0.id == id }) else {
            XCTFail("trackpad should be present")
            return
        }
        XCTAssertTrue(trackpad.isTrackpad)
        XCTAssertEqual(trackpad.label, "Trackpad")
        XCTAssertEqual(trackpad.trackpadSettings, Optional(GamepadTrackpadSettings.defaultValue.normalized))

        let data = try JSONEncoder().encode(customization.normalized)
        let decoded = try JSONDecoder().decode(GamepadCustomization.self, from: data).normalized
        XCTAssertEqual(decoded.customButtons.first(where: { $0.id == id })?.controlKind, .trackpad)
        XCTAssertEqual(decoded.customButtons.first(where: { $0.id == id })?.trackpadSettings, Optional(GamepadTrackpadSettings.defaultValue.normalized))

        let controls = decoded.resolvedControls(in: CGSize(width: 874, height: 402))
        XCTAssertTrue(controls.contains { $0.id == .custom(id) && $0.isTrackpad })
    }

    func testJoystickThumbColorCustomizationRoundTrips() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!
        var customization = GamepadCustomization.blankCanvas
        customization.addJoystick(id: id)
        guard let index = customization.customButtons.firstIndex(where: { $0.id == id }) else {
            XCTFail("joystick should be present")
            return
        }

        let thumbColor = GamepadRGBAColor(hexString: "#F8FAFC")!
        customization.customButtons[index].layout.joystickKnobColor = thumbColor

        let data = try JSONEncoder().encode(customization.normalized)
        let decoded = try JSONDecoder().decode(GamepadCustomization.self, from: data).normalized
        let joystick = decoded.customButtons.first(where: { $0.id == id })?.normalized

        XCTAssertEqual(joystick?.controlKind, .joystick)
        XCTAssertEqual(joystick?.layout.joystickKnobColor, thumbColor.normalized)
        XCTAssertEqual(joystick?.layout.joystickKnobColor(for: .light), thumbColor.normalized)
    }

    func testAgentJoystickThumbColorSpecGeneratesCustomJoystick() throws {
        let json = """
        {
          "gameName": "Joystick Color Test",
          "controls": [
            {
              "label": "Move",
              "key": "W",
              "kind": "joystick",
              "fill": "#111827",
              "thumbFill": "#F8FAFC",
              "up": "up",
              "down": "down",
              "left": "left",
              "right": "right"
            }
          ]
        }
        """

        let spec = try JSONDecoder().decode(AgentKeypadSpec.self, from: Data(json.utf8))
        let generated = GameKeypadGenerator.generate(from: spec)
        guard let joystick = generated.profile.customization.customButtons.first?.normalized else {
            XCTFail("generated profile should include a custom joystick")
            return
        }

        XCTAssertTrue(joystick.isJoystick)
        XCTAssertEqual(joystick.layout.fillColor, GamepadRGBAColor(hexString: "#111827")!.normalized)
        XCTAssertEqual(joystick.layout.joystickKnobColor, GamepadRGBAColor(hexString: "#F8FAFC")!.normalized)
    }

    func testAgentTrackpadSensitivitySpecGeneratesCustomTrackpad() throws {
        let json = """
        {
          "gameName": "Trackpad Sensitivity Test",
          "controls": [
            {
              "label": "Aim Pad",
              "key": "Space",
              "kind": "trackpad",
              "sensitivity": 2.5,
              "scrollSensitivity": 1.75,
              "tapToClick": false,
              "twoFingerScroll": true,
              "naturalScroll": false
            }
          ]
        }
        """

        let spec = try JSONDecoder().decode(AgentKeypadSpec.self, from: Data(json.utf8))
        let generated = GameKeypadGenerator.generate(from: spec)
        guard let trackpad = generated.profile.customization.customButtons.first?.normalized else {
            XCTFail("generated profile should include a custom trackpad")
            return
        }

        XCTAssertTrue(trackpad.isTrackpad)
        XCTAssertEqual(trackpad.label, "Aim Pad")
        XCTAssertEqual(trackpad.layout.centerX, Optional(CGFloat(0.50)))
        XCTAssertEqual(trackpad.layout.centerY, Optional(CGFloat(0.58)))
        XCTAssertEqual(trackpad.layout.widthScale, CGFloat(1.25))
        XCTAssertEqual(trackpad.layout.cornerRadius, Optional(CGFloat(18)))
        XCTAssertEqual(trackpad.trackpadSettings?.sensitivity, CGFloat(2.5))
        XCTAssertEqual(trackpad.trackpadSettings?.scrollSensitivity, CGFloat(1.75))
        XCTAssertEqual(trackpad.trackpadSettings?.tapToClick, false)
        XCTAssertEqual(trackpad.trackpadSettings?.twoFingerScroll, true)
        XCTAssertEqual(trackpad.trackpadSettings?.naturalScrolling, false)
        XCTAssertEqual(generated.keyBindings[trackpad.mappedButton]?.key, "Space")
    }

    func testDesignMetadataLayerOrderControlsResolvedZOrder() throws {
        var customization = GamepadCustomization.defaultValue
        customization.addCustomButton(id: UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!, mappedTo: .custom1)
        customization.designMetadata = GamepadDesignMetadata(
            layerOrder: [.custom(UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!), .builtin(.jump)]
        )

        let controls = customization.normalized.resolvedControls(in: CGSize(width: 874, height: 402))
        let jumpIndex = controls.firstIndex { $0.id == .builtin(.jump) }
        let customIndex = controls.firstIndex { $0.id == .custom(UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!) }
        XCTAssertNotNil(jumpIndex)
        XCTAssertNotNil(customIndex)
        XCTAssertLessThan(customIndex!, jumpIndex!)
    }

    func testStyleTokenPresentationOverridesLegacyAppearance() throws {
        let style = GamepadStyleToken(
            id: "soul-orb",
            name: "Soul Orb",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(
                    fillStyle: .solid(GamepadRGBAColor(hexString: "#F8FAFC")!),
                    strokeColor: GamepadRGBAColor(hexString: "#38BDF8")!,
                    strokeWidth: 3,
                    glowColor: GamepadRGBAColor(hexString: "#0EA5E9")!,
                    glowRadius: 12
                ),
                pressed: GamepadControlStateStyle(fillStyle: .solid(GamepadRGBAColor(hexString: "#0EA5E9")!)),
                icon: .sfSymbol("circle.hexagongrid.fill"),
                hapticStyle: .medium
            )
        )
        var layout = GamepadButtonCustomization(fillColor: GamepadRGBAColor(hexString: "#111827")!, styleID: "soul-orb")
        var customization = GamepadCustomization.defaultValue
        customization.styleLibrary = GamepadStyleLibrary(styles: [style])
        customization.setButtonCustomization(layout, for: .focus)

        let control = customization.resolvedControls(in: CGSize(width: 874, height: 402)).first { $0.id == .builtin(.focus) }!
        let normal = customization.resolvedPresentation(for: control, state: .normal, scheme: .dark)
        XCTAssertEqual(normal.fillStyle.representativeColor, GamepadRGBAColor(hexString: "#F8FAFC")!.normalized)
        XCTAssertEqual(normal.strokeColor, GamepadRGBAColor(hexString: "#38BDF8")!.normalized)
        XCTAssertEqual(normal.strokeWidth, CGFloat(3))
        XCTAssertEqual(normal.icon?.value, "circle.hexagongrid.fill")
        XCTAssertEqual(normal.hapticStyle, .medium)
        XCTAssertEqual(normal.hapticFeedback.style, .medium)
        XCTAssertEqual(normal.hapticFeedback.pattern, .single)

        let pressed = customization.resolvedPresentation(for: control, state: .pressed, scheme: .dark)
        XCTAssertEqual(pressed.fillStyle.representativeColor, GamepadRGBAColor(hexString: "#0EA5E9")!.normalized)

        let data = try JSONEncoder().encode(customization.normalized)
        let decoded = try JSONDecoder().decode(GamepadCustomization.self, from: data).normalized
        XCTAssertEqual(decoded.styleLibrary.styles.first?.id, "soul-orb")
        layout = decoded.buttonCustomization(for: .focus)
        XCTAssertEqual(layout.styleID, "soul-orb")
    }

    func testAgentRichStyleSpecGeneratesIconAndPressedFill() throws {
        let json = """
        {
          "gameName": "Rich Style Test",
          "controls": [
            {
              "label": "Focus",
              "key": "F",
              "button": "focus",
              "fill": "#111827",
              "pressedFill": "#38BDF8",
              "stroke": "#F8FAFC",
              "strokeWidth": 2,
              "sfSymbol": "sparkles",
              "hapticStyle": "heavy",
              "hapticPattern": "double",
              "hapticIntensity": 0.73,
              "hapticSharpness": 0.88,
              "hapticDurationMS": 90
            }
          ]
        }
        """

        let spec = try JSONDecoder().decode(AgentKeypadSpec.self, from: Data(json.utf8))
        let generated = GameKeypadGenerator.generate(from: spec)
        let layout = generated.profile.customization.buttonCustomization(for: .focus)
        XCTAssertEqual(layout.icon?.value, "sparkles")
        XCTAssertEqual(layout.hapticStyle, .heavy)
        XCTAssertEqual(layout.hapticFeedback?.pattern, .double)
        XCTAssertEqual(layout.hapticFeedback?.intensity ?? 0, CGFloat(0.73), accuracy: 0.0001)
        XCTAssertEqual(layout.hapticFeedback?.sharpness ?? 0, CGFloat(0.88), accuracy: 0.0001)
        XCTAssertEqual(layout.hapticFeedback?.duration ?? 0, CGFloat(0.09), accuracy: 0.0001)
        XCTAssertEqual(layout.visualStyle?.normal.strokeWidth, Optional(CGFloat(2)))
        XCTAssertEqual(layout.visualStyle?.pressed?.fillStyle?.representativeColor, GamepadRGBAColor(hexString: "#38BDF8")!.normalized)
    }

    func testThemePresetAppliesCavernGlowDesignSystem() throws {
        var customization = GamepadCustomization.defaultValue
        GamepadThemePreset.cavernGlow.apply(to: &customization)
        let normalized = customization.normalized

        XCTAssertEqual(normalized.colorSchemePreference, .dark)
        XCTAssertEqual(normalized.backgroundDarkFillStyle?.displayName, "Linear")
        XCTAssertEqual(normalized.styleLibrary.styles.map(\.id).sorted(), [
            "cavern-dash",
            "cavern-jump",
            "cavern-nail",
            "cavern-parchment",
            "cavern-rune",
            "cavern-soul",
            "cavern-stone"
        ])
        XCTAssertEqual(normalized.buttonCustomization(for: .focus).styleID, "cavern-soul")
        XCTAssertEqual(normalized.buttonCustomization(for: .attack).styleID, "cavern-nail")
        XCTAssertEqual(normalized.buttonCustomization(for: .dash).styleID, "cavern-dash")
        XCTAssertTrue(normalized.designMetadata?.tags.contains("marketable") == true)

        let focus = normalized.resolvedControls(in: CGSize(width: 874, height: 402)).first { $0.id == .builtin(.focus) }!
        let normal = normalized.resolvedPresentation(for: focus, state: .normal, scheme: .dark)
        let pressed = normalized.resolvedPresentation(for: focus, state: .pressed, scheme: .dark)
        XCTAssertEqual(normal.icon?.value, "sparkles")
        XCTAssertEqual(normal.hapticFeedback.pattern, .pulse)
        XCTAssertNotNil(normal.glowColor)
        XCTAssertNotEqual(normal.fillStyle.representativeColor, pressed.fillStyle.representativeColor)
    }

    func testHollowKnightBuiltInUsesMarketableCavernGlowTheme() throws {
        let generated = try XCTUnwrap(GameKeypadGenerator.generate(for: "Hollow Knight"))
        let customization = generated.profile.customization.normalized

        XCTAssertEqual(generated.source, "Built-in Hollow Knight default keyboard template with PocketPad's Cavern Glow showcase theme")
        XCTAssertEqual(customization.colorSchemePreference, .dark)
        XCTAssertEqual(customization.buttonCustomization(for: .focus).styleID, "cavern-soul")
        XCTAssertEqual(customization.buttonCustomization(for: .attack).styleID, "cavern-nail")
        XCTAssertEqual(customization.buttonCustomization(for: .map).styleID, "cavern-parchment")
        XCTAssertTrue(customization.styleLibrary.style(id: "cavern-soul") != nil)
        XCTAssertTrue(customization.hasCustomBackgroundFill(for: .dark))
        XCTAssertTrue(customization.designMetadata?.tags.contains("showcase") == true)
        XCTAssertTrue(generated.notes.contains { $0.contains("dark cave gradient") })
    }

    func testPointerMessageRoundTripsThroughJSONCodec() throws {
        let message = ControllerMessage(
            type: .pointer,
            state: .down,
            timestamp: 123,
            pointerEvent: .button,
            pointerButton: .right,
            deltaX: 1.5,
            deltaY: -2.25
        )
        let data = try ControllerWireCodec.encode(message, using: JSONEncoder())
        XCTAssertNotEqual(data.count, 14)
        let decoded = try ControllerWireCodec.decode(data, using: JSONDecoder())
        XCTAssertEqual(decoded.type, .pointer)
        XCTAssertEqual(decoded.pointerEvent, .button)
        XCTAssertEqual(decoded.pointerButton, .right)
        XCTAssertEqual(decoded.state, .down)
        XCTAssertEqual(decoded.deltaX, 1.5)
        XCTAssertEqual(decoded.deltaY, -2.25)
    }

    func testAnalogGamepadMessageRoundTripsThroughJSONCodec() throws {
        let message = ControllerMessage(
            type: .gamepadAnalog,
            timestamp: 456,
            analogStick: .left,
            analogX: -0.35,
            analogY: 0.75,
            analogSequence: 42
        )
        let data = try ControllerWireCodec.encode(message, using: JSONEncoder())
        XCTAssertNotEqual(data.count, 14)
        let decoded = try ControllerWireCodec.decode(data, using: JSONDecoder())
        XCTAssertEqual(decoded.type, .gamepadAnalog)
        XCTAssertEqual(decoded.analogStick, .left)
        XCTAssertEqual(decoded.analogX, -0.35)
        XCTAssertEqual(decoded.analogY, 0.75)
        XCTAssertEqual(decoded.analogSequence, 42)
    }

    func testBackgroundFillStyleRoundTripsAndSupportsSchemeOverrides() throws {
        let base = GamepadRGBAColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1)
        let gradient = GamepadFillStyle.gradient(GamepadGradientFill.defaultValue(baseColor: base).normalized)
        var customization = GamepadCustomization.defaultValue
        customization.backgroundFillStyle = gradient

        XCTAssertEqual(customization.keypadBackgroundFillStyle(scheme: .light), gradient.normalized)
        XCTAssertEqual(customization.keypadBackgroundFillStyle(scheme: .dark), gradient.normalized)
        XCTAssertTrue(customization.hasCustomBackgroundFill(for: .light))
        XCTAssertTrue(customization.hasCustomBackgroundFill(for: .dark))

        let lightColor = GamepadRGBAColor(red: 1, green: 0.9, blue: 0.7, alpha: 0.5)
        customization.setBackgroundColor(lightColor, for: .light)

        XCTAssertNil(customization.backgroundFillStyle)
        XCTAssertEqual(customization.backgroundLightColor, lightColor.normalized)
        XCTAssertEqual(customization.backgroundDarkFillStyle, gradient.normalized)
        XCTAssertEqual(customization.keypadBackgroundFillStyle(scheme: .light), .solid(lightColor.normalized))
        XCTAssertEqual(customization.keypadBackgroundFillStyle(scheme: .dark), gradient.normalized)

        let data = try JSONEncoder().encode(customization.normalized)
        let decoded = try JSONDecoder().decode(GamepadCustomization.self, from: data).normalized
        XCTAssertTrue(decoded.hasSamePresentation(as: customization.normalized))
    }

    func testButtonPulseSequencerSmokeSuite() {
        ButtonPulseSequencerSmokeTests.main()
    }

    func testControllerActiveInputStateSmokeSuite() {
        ControllerActiveInputStateSmokeTests.main()
    }

    func testInputLatencySimulationSmokeSuite() {
        InputLatencySimulationSmokeTests.main()
    }

    func testGamepadLayoutResolverSmokeSuite() {
        GamepadLayoutResolverSmokeTests.main()
    }
}
