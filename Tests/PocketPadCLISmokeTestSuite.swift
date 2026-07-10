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

    func testControlBarItemsNormalizeAndRoundTrip() throws {
        var customization = GamepadCustomization.defaultValue
        customization.controlBarItems = [.home, .settings, .home, .connectionAction]

        XCTAssertEqual(customization.normalized.controlBarItems, [.home, .settings, .connectionAction])

        let data = try JSONEncoder().encode(customization)
        let decoded = try JSONDecoder().decode(GamepadCustomization.self, from: data)
        XCTAssertEqual(decoded.normalized.controlBarItems, [.home, .settings, .connectionAction])
    }

    func testControlBarItemAppearancesNormalizeAndRoundTrip() throws {
        var customization = GamepadCustomization.defaultValue
        var settingsAppearance = GamepadButtonCustomization(
            centerX: 0.2,
            centerY: 0.8,
            widthScale: 1.35,
            heightScale: 1.2,
            shape: .capsule,
            fillColor: GamepadRGBAColor(hexString: "#112233"),
            icon: .sfSymbol("slider.horizontal.3"),
            cornerRadius: 14,
            isLocationLocked: true
        )
        settingsAppearance.hapticStyle = .medium
        customization.setControlBarItemCustomization(settingsAppearance, for: .settings)

        let normalizedAppearance = customization.normalized.controlBarItemCustomization(for: .settings)
        XCTAssertNil(normalizedAppearance.centerX)
        XCTAssertNil(normalizedAppearance.centerY)
        XCTAssertFalse(normalizedAppearance.isLocationLocked)
        XCTAssertEqual(normalizedAppearance.widthScale, 1.35, accuracy: 0.001)
        XCTAssertEqual(normalizedAppearance.heightScale, 1.2, accuracy: 0.001)
        XCTAssertEqual(normalizedAppearance.icon?.value, "slider.horizontal.3")
        XCTAssertEqual(normalizedAppearance.hapticStyle, .medium)

        let data = try JSONEncoder().encode(customization)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("controlBarItemCustomizations"))

        let decoded = try JSONDecoder().decode(GamepadCustomization.self, from: data).normalized
        XCTAssertEqual(decoded.controlBarItemCustomization(for: .settings), normalizedAppearance)
        XCTAssertFalse(GamepadCustomization.defaultValue.hasSamePresentation(as: decoded))

        var reordered = decoded
        reordered.moveControlBarItem(.settings, to: 0)
        XCTAssertEqual(reordered.normalized.controlBarItems.first, .settings)
        XCTAssertEqual(reordered.controlBarItemCustomization(for: .settings), normalizedAppearance)

        reordered.removeControlBarItem(.settings)
        XCTAssertFalse(reordered.normalized.controlBarItems.contains(.settings))
        XCTAssertTrue(reordered.normalized.controlBarItemCustomizations.isEmpty)
    }

    func testControlBarItemIdentityRoundTrips() throws {
        let identity = GamepadControlIdentity.controlBarItem(.connectionAction)
        let data = try JSONEncoder().encode(identity)
        XCTAssertEqual(try JSONDecoder().decode(GamepadControlIdentity.self, from: data), identity)
    }

    func testStyledProfilePayloadEncodesOnNetworkQueue() throws {
        var customization = GamepadCustomization.defaultValue.normalized
        let visualStyle = GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(
                fillStyle: .solid(GamepadRGBAColor(hexString: "#F7F4F8") ?? .defaultValue),
                foregroundColor: GamepadRGBAColor(hexString: "#7C61A8") ?? .defaultValue,
                strokeColor: GamepadRGBAColor(hexString: "#FFFFFF") ?? .defaultValue,
                strokeWidth: 1,
                shadowColor: GamepadRGBAColor(hexString: "#00000066") ?? .defaultValue,
                shadowRadius: 8
            ),
            pressed: GamepadControlStateStyle(opacity: 0.86, scale: 0.94)
        )

        for button in GameButton.builtInControls {
            var layout = customization.buttonCustomization(for: button)
            layout.visualStyle = visualStyle
            customization.setButtonCustomization(layout, for: button)
        }

        let profile = GamepadConfigurationProfile(name: "Styled Network Payload", customization: customization)
        let message = ControllerMessage(
            type: .gamepadProfiles,
            gamepadCustomization: customization,
            gamepadProfiles: [profile],
            gamepadProfileID: profile.id,
            defaultGamepadProfileID: profile.id
        )
        let queue = DispatchQueue(label: "PocketPad.Tests.NetworkStack")
        let data = try queue.sync {
            try ControllerWireCodec.encode(message, using: JSONEncoder())
        }

        XCTAssertFalse(data.isEmpty)
        let decoded = try ControllerWireCodec.decode(data, using: JSONDecoder())
        XCTAssertEqual(decoded.gamepadProfiles?.first?.customization.normalized.buttonCustomizations.count, GameButton.builtInControls.count)
    }

    func testAddedJoystickDefaultsToKeyboardDigitalDirections() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-00000000D1D1")!
        var customization = GamepadCustomization.blankCanvas
        customization.addJoystick(id: id)

        let joystick = try XCTUnwrap(customization.normalized.customButtons.first(where: { $0.id == id })?.normalized)
        XCTAssertEqual(joystick.label, "Arrow Keys")
        XCTAssertEqual(joystick.mappedButton, .up)
        XCTAssertEqual(joystick.joystickMapping, .movement)
        XCTAssertEqual(joystick.joystickOutputSettings, Optional(GamepadJoystickOutputSettings.defaultValue.normalized))

        let element = try XCTUnwrap(customization.normalized.elements.first { $0.id == id && $0.kind == .joystick })
        XCTAssertEqual(element.joystickMapping, .movement)
        XCTAssertEqual(element.joystickOutputSettings, Optional(GamepadJoystickOutputSettings.defaultValue.normalized))
    }

    func testCaptureEventRoundTripsThroughJSONCodec() throws {
        let event = PocketPadCaptureEvent(
            sequence: 42,
            recordedAt: 123_456,
            uptimeNanoseconds: 789,
            kind: "button",
            source: "iPhone UDP",
            messageType: .button,
            button: .jump,
            state: .down,
            binding: "Space",
            inputSequence: 7,
            pressIdentifier: 99,
            latencyMS: 4,
            pressedButtons: [.jump],
            detail: "smoke"
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(PocketPadCaptureEvent.self, from: data)
        XCTAssertEqual(decoded.sequence, 42)
        XCTAssertEqual(decoded.kind, "button")
        XCTAssertEqual(decoded.source, "iPhone UDP")
        XCTAssertEqual(decoded.messageType, .button)
        XCTAssertEqual(decoded.button, .jump)
        XCTAssertEqual(decoded.state, .down)
        XCTAssertEqual(decoded.binding, "Space")
        XCTAssertEqual(decoded.inputSequence, 7)
        XCTAssertEqual(decoded.pressIdentifier, 99)
        XCTAssertEqual(decoded.latencyMS, 4)
        XCTAssertEqual(decoded.pressedButtons, [.jump])
        XCTAssertEqual(decoded.detail, "smoke")
    }

    func testElementInputMessageRoundTrips() throws {
        let elementID = UUID(uuidString: "00000000-0000-0000-0000-00000000E1E1")!
        let message = ControllerMessage(
            type: .elementInput,
            elementID: elementID,
            elementPart: .primary,
            state: .down,
            timestamp: ControllerWireCodec.inputSequenceTimestamp(for: 42, pressIdentifier: 7),
            sentAt: 123_456
        )
        let data = try ControllerWireCodec.encode(message, using: JSONEncoder())
        let decoded = try ControllerWireCodec.decode(data, using: JSONDecoder())
        XCTAssertEqual(decoded.type, .elementInput)
        XCTAssertEqual(decoded.elementID, elementID)
        XCTAssertEqual(decoded.elementPart, .primary)
        XCTAssertEqual(decoded.state, .down)
        XCTAssertEqual(decoded.sentAt, 123_456)
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

    func testCommandClickedProfileSelectionExcludesActiveByDefault() {
        let activeID = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
        let firstClickedID = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
        let secondClickedID = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
        let orderedIDs = [activeID, firstClickedID, secondClickedID]

        var explicitSelection = GamepadProfileSelectionLogic.toggledExplicitSelection(
            firstClickedID,
            currentExplicitSelection: [],
            orderedProfileIDs: orderedIDs
        )
        explicitSelection = GamepadProfileSelectionLogic.toggledExplicitSelection(
            secondClickedID,
            currentExplicitSelection: explicitSelection,
            orderedProfileIDs: orderedIDs
        )

        XCTAssertEqual(explicitSelection, [firstClickedID, secondClickedID])
        XCTAssertEqual(
            GamepadProfileSelectionLogic.actionIDs(
                explicitSelection: explicitSelection,
                activeID: activeID,
                orderedProfileIDs: orderedIDs
            ),
            [firstClickedID, secondClickedID]
        )
    }

    func testProfileActionsFallBackToActiveWhenNothingIsCommandSelected() {
        let activeID = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
        let otherID = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!

        XCTAssertEqual(
            GamepadProfileSelectionLogic.actionIDs(
                explicitSelection: [],
                activeID: activeID,
                orderedProfileIDs: [activeID, otherID]
            ),
            [activeID]
        )
    }

    func testActiveProfileMustBeExplicitlyCommandSelectedForBulkActions() {
        let activeID = UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!
        let otherID = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!
        let orderedIDs = [activeID, otherID]

        var explicitSelection = GamepadProfileSelectionLogic.toggledExplicitSelection(
            activeID,
            currentExplicitSelection: [],
            orderedProfileIDs: orderedIDs
        )
        explicitSelection = GamepadProfileSelectionLogic.toggledExplicitSelection(
            otherID,
            currentExplicitSelection: explicitSelection,
            orderedProfileIDs: orderedIDs
        )

        XCTAssertEqual(
            GamepadProfileSelectionLogic.actionIDs(
                explicitSelection: explicitSelection,
                activeID: activeID,
                orderedProfileIDs: orderedIDs
            ),
            [activeID, otherID]
        )
    }

    func testKeypadProfileLaunchTargetRoundTrips() throws {
        let iconData = Data([0x89, 0x50, 0x4E, 0x47])
        let target = GamepadProfileLaunchTarget(
            displayName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            filePath: "/Applications/Safari.app",
            iconPNGData: iconData,
            attachedAt: 123_456
        )
        let profile = GamepadConfigurationProfile(
            name: "Browser Setup",
            customization: .defaultValue,
            launchTarget: target
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(GamepadConfigurationProfile.self, from: data)
        XCTAssertEqual(decoded.launchTarget?.displayName, "Safari")
        XCTAssertEqual(decoded.launchTarget?.bundleIdentifier, "com.apple.Safari")
        XCTAssertEqual(decoded.launchTarget?.filePath, "/Applications/Safari.app")
        XCTAssertEqual(decoded.launchTarget?.iconPNGData, iconData)
        XCTAssertEqual(decoded.launchTarget?.attachedAt, 123_456)
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
        customization.customButtons[index].layout.joystickVisualStyle = .thumbstick

        let data = try JSONEncoder().encode(customization.normalized)
        let decoded = try JSONDecoder().decode(GamepadCustomization.self, from: data).normalized
        let joystick = decoded.customButtons.first(where: { $0.id == id })?.normalized

        XCTAssertEqual(joystick?.controlKind, .joystick)
        XCTAssertEqual(joystick?.layout.joystickKnobColor, thumbColor.normalized)
        XCTAssertEqual(joystick?.layout.joystickKnobColor(for: .light), thumbColor.normalized)
        XCTAssertEqual(joystick?.layout.joystickVisualStyle, .thumbstick)
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
              "joystickStyle": "thumbstick",
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
        XCTAssertEqual(joystick.layout.joystickVisualStyle, .thumbstick)
        XCTAssertEqual(joystick.layout.widthScale, 0.58, accuracy: 0.001)
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

    func testControlZIndexOverridesLayerOrderForResolvedZOrder() throws {
        let backID = UUID(uuidString: "00000000-0000-0000-0000-00000000D111")!
        let frontID = UUID(uuidString: "00000000-0000-0000-0000-00000000D222")!
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(id: backID, mappedTo: .custom1)
        customization.addCustomButton(id: frontID, mappedTo: .custom2)
        customization.customButtons[0].layout.zIndex = 50
        customization.customButtons[1].layout.zIndex = -10
        customization.designMetadata = GamepadDesignMetadata(layerOrder: [.custom(backID), .custom(frontID)])

        let controls = customization.normalized.resolvedControls(in: CGSize(width: 874, height: 402))
        let backIndex = controls.firstIndex { $0.id == .custom(backID) }
        let frontIndex = controls.firstIndex { $0.id == .custom(frontID) }
        XCTAssertNotNil(backIndex)
        XCTAssertNotNil(frontIndex)
        XCTAssertLessThan(frontIndex!, backIndex!)
        XCTAssertEqual(GamepadButtonCustomization(zIndex: 250).zIndex, 100)
        XCTAssertEqual(GamepadButtonCustomization(zIndex: -250).zIndex, -100)
    }

    func testGroupedLayerOperationsMoveChildrenAsBlock() throws {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-00000000A111")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-00000000B222")!
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(id: firstID, mappedTo: .custom1)
        customization.addCustomButton(id: secondID, mappedTo: .custom2)
        customization.designMetadata = GamepadDesignMetadata(
            layerOrder: [.custom(firstID), .custom(secondID), .builtin(.jump)],
            groups: [GamepadLayerGroup(name: "Pair", children: [.custom(firstID), .custom(secondID)])]
        )

        customization.bringLayersForward([.custom(firstID), .custom(secondID)])
        XCTAssertEqual(
            Array(customization.orderedControlIdentitiesForDesign.prefix(3)),
            [.builtin(.jump), .custom(firstID), .custom(secondID)]
        )

        customization.sendLayersToBack([.custom(firstID), .custom(secondID)])
        XCTAssertEqual(
            Array(customization.orderedControlIdentitiesForDesign.prefix(2)),
            [.custom(firstID), .custom(secondID)]
        )
    }

    func testStyleTokenPresentationOverridesLegacyAppearance() throws {
        let style = GamepadStyleToken(
            id: "soul-orb",
            name: "Soul Orb",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(
                    fillStyle: .solid(GamepadRGBAColor(hexString: "#F8FAFC")!),
                    foregroundColor: GamepadRGBAColor(hexString: "#7C61A8")!,
                    strokeColor: GamepadRGBAColor(hexString: "#38BDF8")!,
                    strokeWidth: 3,
                    shadowColor: GamepadRGBAColor(hexString: "#000000", alpha: 0.12)!,
                    shadowRadius: 6,
                    shadowX: 1,
                    shadowY: 2,
                    shadows: [
                        GamepadControlShadowStyle(color: GamepadRGBAColor(hexString: "#FFFFFF", alpha: 0.9)!, radius: 12, x: -6, y: -6),
                        GamepadControlShadowStyle(color: GamepadRGBAColor(hexString: "#9B91AA", alpha: 0.24)!, radius: 20, x: 8, y: 9)
                    ],
                    glowColor: GamepadRGBAColor(hexString: "#0EA5E9")!,
                    glowRadius: 12,
                    innerShadowColor: GamepadRGBAColor(hexString: "#B8B2C2")!,
                    innerShadowRadius: 5,
                    innerShadowX: 1,
                    innerShadowY: 2,
                    highlightColor: GamepadRGBAColor(hexString: "#FFFFFF")!,
                    highlightRadius: 8,
                    highlightX: -4,
                    highlightY: -4,
                    highlightOpacity: 0.45,
                    bevelHighlightColor: GamepadRGBAColor(hexString: "#FFFFFF")!,
                    bevelShadowColor: GamepadRGBAColor(hexString: "#C7C0CC")!,
                    bevelWidth: 1.5
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
        XCTAssertEqual(normal.foregroundColor, GamepadRGBAColor(hexString: "#7C61A8")!.normalized)
        XCTAssertEqual(normal.strokeColor, GamepadRGBAColor(hexString: "#38BDF8")!.normalized)
        XCTAssertEqual(normal.strokeWidth, CGFloat(3))
        XCTAssertEqual(normal.shadowRadius, CGFloat(6))
        XCTAssertEqual(normal.shadowX, CGFloat(1))
        XCTAssertEqual(normal.shadowY, CGFloat(2))
        XCTAssertEqual(normal.shadows.count, 2)
        XCTAssertEqual(normal.shadows.first?.radius, CGFloat(12))
        XCTAssertEqual(normal.innerShadowColor, GamepadRGBAColor(hexString: "#B8B2C2")!.normalized)
        XCTAssertEqual(normal.innerShadowRadius, CGFloat(5))
        XCTAssertEqual(normal.innerShadowX, CGFloat(1))
        XCTAssertEqual(normal.innerShadowY, CGFloat(2))
        XCTAssertEqual(normal.highlightColor, GamepadRGBAColor(hexString: "#FFFFFF")!.normalized)
        XCTAssertEqual(normal.highlightRadius, CGFloat(8))
        XCTAssertEqual(normal.highlightX, CGFloat(-4))
        XCTAssertEqual(normal.highlightY, CGFloat(-4))
        XCTAssertEqual(normal.highlightOpacity, CGFloat(0.45))
        XCTAssertEqual(normal.bevelHighlightColor, GamepadRGBAColor(hexString: "#FFFFFF")!.normalized)
        XCTAssertEqual(normal.bevelShadowColor, GamepadRGBAColor(hexString: "#C7C0CC")!.normalized)
        XCTAssertEqual(normal.bevelWidth, CGFloat(1.5))
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
              "foreground": "#7C61A8",
              "shadows": [
                { "color": { "red": 1, "green": 1, "blue": 1, "alpha": 0.9 }, "radius": 12, "x": -6, "y": -6 },
                { "color": { "red": 0.61, "green": 0.57, "blue": 0.67, "alpha": 0.24 }, "radius": 20, "x": 8, "y": 9 }
              ],
              "innerShadow": "#B8B2C2",
              "innerShadowRadius": 5,
              "highlight": "#FFFFFF",
              "highlightOpacity": 0.45,
              "highlightX": -4,
              "highlightY": -4,
              "bevelHighlight": "#FFFFFF",
              "bevelShadow": "#C7C0CC",
              "bevelWidth": 1.5,
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
        XCTAssertEqual(layout.visualStyle?.normal.shadows?.count, 2)
        XCTAssertEqual(layout.visualStyle?.normal.shadows?.first?.radius, Optional(CGFloat(12)))
        XCTAssertEqual(layout.visualStyle?.normal.foregroundColor, Optional(GamepadRGBAColor(hexString: "#7C61A8")!.normalized))
        XCTAssertEqual(layout.visualStyle?.normal.innerShadowColor, Optional(GamepadRGBAColor(hexString: "#B8B2C2")!.normalized))
        XCTAssertEqual(layout.visualStyle?.normal.innerShadowRadius, Optional(CGFloat(5)))
        XCTAssertEqual(layout.visualStyle?.normal.highlightColor, Optional(GamepadRGBAColor(hexString: "#FFFFFF")!.normalized))
        XCTAssertEqual(layout.visualStyle?.normal.highlightOpacity, Optional(CGFloat(0.45)))
        XCTAssertEqual(layout.visualStyle?.normal.highlightX, Optional(CGFloat(-4)))
        XCTAssertEqual(layout.visualStyle?.normal.highlightY, Optional(CGFloat(-4)))
        XCTAssertEqual(layout.visualStyle?.normal.bevelHighlightColor, Optional(GamepadRGBAColor(hexString: "#FFFFFF")!.normalized))
        XCTAssertEqual(layout.visualStyle?.normal.bevelShadowColor, Optional(GamepadRGBAColor(hexString: "#C7C0CC")!.normalized))
        XCTAssertEqual(layout.visualStyle?.normal.bevelWidth, Optional(CGFloat(1.5)))
        XCTAssertEqual(layout.visualStyle?.pressed?.fillStyle?.representativeColor, GamepadRGBAColor(hexString: "#38BDF8")!.normalized)
    }

    func testSoftWhiteThemeAndTemplateSupportDecorationLayers() throws {
        var customization = GamepadCustomization.defaultValue
        GamepadThemePreset.softWhiteController.apply(to: &customization)
        let themed = customization.normalized
        XCTAssertEqual(themed.colorSchemePreference, .light)
        XCTAssertTrue(themed.styleLibrary.style(id: "soft-white-raised") != nil)
        XCTAssertEqual(themed.buttonCustomization(for: .jump).styleID, "soft-white-lavender")
        let jump = themed.resolvedControls(in: CGSize(width: 874, height: 402)).first { $0.id == .builtin(.jump) }!
        XCTAssertGreaterThan(themed.resolvedPresentation(for: jump, state: .normal, scheme: .light).shadows.count, 1)

        let template = GamepadControllerTemplate.softWhite.makeProfile().customization.normalized
        let decorations = template.customButtons.filter { $0.normalized.isDecoration }
        XCTAssertGreaterThanOrEqual(decorations.count, 5)
        XCTAssertTrue(template.resolvedControls(in: CGSize(width: 874, height: 402)).contains { $0.isDecoration })
        XCTAssertEqual(template.orderedControlIdentitiesForDesign.first, .custom(decorations.first!.id))

        let report = template.layoutQualityReport(profileName: "Soft White Pro", canvasSize: CGSize(width: 874, height: 402))
        XCTAssertFalse(report.hasErrors)
        XCTAssertEqual(report.summary.warningCount, 0)
        XCTAssertTrue(report.controls.contains { $0.kind == "decoration" })
    }

    func testDecorationAgentSpecDoesNotCreateKeyBinding() throws {
        let json = """
        {
          "gameName": "Decor Spec",
          "controls": [
            {
              "label": "Shell",
              "kind": "decoration",
              "material": "soft-white-plate",
              "x": 0.5,
              "y": 0.5,
              "width": 3.2,
              "height": 1.5,
              "shape": "rounded_rectangle"
            }
          ]
        }
        """
        let spec = try JSONDecoder().decode(AgentKeypadSpec.self, from: Data(json.utf8))
        let generated = GameKeypadGenerator.generate(from: spec)
        let decoration = try XCTUnwrap(generated.profile.customization.customButtons.first?.normalized)
        XCTAssertTrue(decoration.isDecoration)
        XCTAssertTrue(generated.keyBindings.isEmpty)
        XCTAssertEqual(decoration.layout.visualStyle?.normal.shadows?.count, 2)
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

    func testControllerLayoutRoutingSelectsStandardAndFreeformPresentations() {
        XCTAssertEqual(
            GamepadControllerPresentationRouting.layoutRoute(
                orientation: .portrait,
                isEditingLayout: false,
                usesFreeformLayout: false
            ),
            .standard(.portrait)
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.layoutRoute(
                orientation: .landscape,
                isEditingLayout: false,
                usesFreeformLayout: false
            ),
            .standard(.landscape)
        )

        for orientation in GamepadEditorDeviceOrientation.allCases {
            XCTAssertEqual(
                GamepadControllerPresentationRouting.layoutRoute(
                    orientation: orientation,
                    isEditingLayout: true,
                    usesFreeformLayout: false
                ),
                .freeform(orientation)
            )
            XCTAssertEqual(
                GamepadControllerPresentationRouting.layoutRoute(
                    orientation: orientation,
                    isEditingLayout: false,
                    usesFreeformLayout: true
                ),
                .freeform(orientation)
            )
        }
    }

    func testControllerOrientationRoutingMatchesRuntimeGeometryRule() {
        XCTAssertEqual(
            GamepadControllerPresentationRouting.orientation(for: CGSize(width: 430, height: 932)),
            .portrait
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.orientation(for: CGSize(width: 932, height: 430)),
            .landscape
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.orientation(for: CGSize(width: 430, height: 430)),
            .landscape
        )
    }

    func testStandardControllerSlotsPreserveLayoutOrderWithoutBuilderBranches() {
        XCTAssertEqual(
            GamepadControllerPresentationRouting.standardSlots(
                orientation: .landscape,
                layoutMode: .standard
            ),
            [
                .control(.dPad),
                .flexibleSpace(0),
                .control(.utilityButtons),
                .flexibleSpace(1),
                .control(.actionButtons)
            ]
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.standardSlots(
                orientation: .landscape,
                layoutMode: .southpaw
            ),
            [
                .control(.actionButtons),
                .flexibleSpace(0),
                .control(.utilityButtons),
                .flexibleSpace(1),
                .control(.dPad)
            ]
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.standardSlots(
                orientation: .portrait,
                layoutMode: .standard
            ),
            [
                .flexibleSpace(0),
                .control(.dPad),
                .control(.utilityButtons),
                .control(.actionButtons),
                .flexibleSpace(1)
            ]
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.standardSlots(
                orientation: .portrait,
                layoutMode: .southpaw
            ),
            [
                .flexibleSpace(0),
                .control(.actionButtons),
                .control(.utilityButtons),
                .control(.dPad),
                .flexibleSpace(1)
            ]
        )
    }

    func testControlBarRoutingFiltersUnavailableAndHiddenItemsInStableOrder() {
        let items: [GamepadControlBarItem] = [
            .profileMenu,
            .home,
            .profileMenu,
            .launchTarget,
            .settings,
            .connectionStatus
        ]

        XCTAssertEqual(
            GamepadControllerPresentationRouting.visibleControlBarItems(
                items,
                hiddenItems: [.settings],
                hasProfiles: false,
                hasLaunchTarget: false
            ),
            [.home, .connectionStatus]
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.visibleControlBarItems(
                items,
                hiddenItems: [],
                hasProfiles: true,
                hasLaunchTarget: true
            ),
            [.profileMenu, .home, .launchTarget, .settings, .connectionStatus]
        )
    }

    func testResolvedControlRoutingPreservesSpecializedFallbacks() {
        XCTAssertEqual(
            GamepadControllerPresentationRouting.resolvedControlRoute(
                kind: .decoration,
                hasJoystickMapping: false,
                hasTriggerSettings: false
            ),
            .decoration
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.resolvedControlRoute(
                kind: .joystick,
                hasJoystickMapping: true,
                hasTriggerSettings: false
            ),
            .joystick
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.resolvedControlRoute(
                kind: .joystick,
                hasJoystickMapping: false,
                hasTriggerSettings: false
            ),
            .button
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.resolvedControlRoute(
                kind: .trigger,
                hasJoystickMapping: false,
                hasTriggerSettings: true
            ),
            .trigger
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.resolvedControlRoute(
                kind: .trigger,
                hasJoystickMapping: false,
                hasTriggerSettings: false
            ),
            .button
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.resolvedControlRoute(
                kind: .trackpad,
                hasJoystickMapping: false,
                hasTriggerSettings: false
            ),
            .trackpad
        )
        XCTAssertEqual(
            GamepadControllerPresentationRouting.resolvedControlRoute(
                kind: .button,
                hasJoystickMapping: false,
                hasTriggerSettings: false
            ),
            .button
        )
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
