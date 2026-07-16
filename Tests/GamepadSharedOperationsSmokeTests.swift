import CoreGraphics
import XCTest

final class GamepadSharedOperationsSmokeTests: XCTestCase {
    func testStableControlIdentityParsesEveryExistingIDShape() {
        let customID = UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!
        let identities: [GamepadControlIdentity] = [
            .builtin(.jump),
            .custom(customID),
            .system(.topBarActivation),
            .controlBarItem(.settings)
        ]

        for identity in identities {
            XCTAssertEqual(GamepadControlIdentity(stableID: identity.id), identity)
        }
        XCTAssertEqual(GamepadControlIdentity(stableID: "jump"), .builtin(.jump))
        XCTAssertEqual(GamepadControlIdentity(stableID: customID.uuidString), .custom(customID))
        XCTAssertNil(GamepadControlIdentity(stableID: "custom.not-a-uuid"))
    }

    func testDuplicateBuiltInCreatesEquivalentCustomControlWithClonedOutput() throws {
        var customization = GamepadCustomization.defaultValue.normalized
        var jumpLayout = customization.buttonCustomization(for: .jump)
        jumpLayout.centerX = 0.72
        jumpLayout.centerY = 0.66
        jumpLayout.fillColor = GamepadRGBAColor(hexString: "#112233")
        customization.setButtonCustomization(jumpLayout, for: .jump)

        let sourceID = try XCTUnwrap(customization.elementID(for: .builtin(.jump)))
        let sourceIndex = try XCTUnwrap(customization.elements.firstIndex(where: { $0.id == sourceID }))
        let primary = KeypadElementOutputBinding(
            keyboard: KeypadKeyboardBinding(keyCode: 49),
            gamepadButtons: [.south]
        )
        let alternate = KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 36))
        customization.elements[sourceIndex].setOutputBinding(primary)
        customization.elements[sourceIndex].setOutputBinding(alternate, for: .joystickUp)

        let result = try customization.duplicateControls(
            [.builtin(.jump)],
            normalizedOffset: CGSize(width: 0.04, height: -0.03),
            canvasSize: CGSize(width: 874, height: 402)
        )
        let duplicateIdentity = try XCTUnwrap(result.identityMap[.builtin(.jump)])
        guard case .custom(let duplicateID) = duplicateIdentity else {
            return XCTFail("built-in duplicate should be custom")
        }
        let duplicate = try XCTUnwrap(customization.customButtons.first(where: { $0.id == duplicateID }))
        XCTAssertEqual(duplicate.mappedButton, .jump)
        XCTAssertEqual(duplicate.label, customization.visualLabel(for: .jump))
        XCTAssertEqual(try XCTUnwrap(duplicate.layout.centerX), CGFloat(0.76), accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(duplicate.layout.centerY), CGFloat(0.63), accuracy: 0.001)
        XCTAssertEqual(duplicate.layout.fillColor, GamepadRGBAColor(hexString: "#112233")?.normalized)

        let duplicateElement = try XCTUnwrap(customization.element(for: duplicateIdentity))
        XCTAssertEqual(duplicateElement.outputBinding(), primary)
        XCTAssertEqual(duplicateElement.outputBinding(for: .joystickUp), alternate)
    }

    func testDuplicateCustomPreservesSpecializedSettingsAndLayerPlacement() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
        var customization = GamepadCustomization.blankCanvas
        customization.addJoystick(
            id: id,
            label: "Aim",
            mapping: .secondary,
            outputSettings: .analogRightStick
        )
        customization.designMetadata = GamepadDesignMetadata(layerOrder: [.custom(id)])

        let result = try customization.duplicateControls([.custom(id)])
        guard case .custom(let duplicateID) = try XCTUnwrap(result.identityMap[.custom(id)]) else {
            return XCTFail("custom duplicate should remain custom")
        }
        let duplicate = try XCTUnwrap(customization.customButtons.first(where: { $0.id == duplicateID }))
        XCTAssertEqual(duplicate.controlKind, .joystick)
        XCTAssertEqual(duplicate.joystickMapping, .secondary)
        XCTAssertEqual(duplicate.joystickOutputSettings, .analogRightStick.normalized)
        let order = customization.orderedControlIdentitiesForDesign
        XCTAssertEqual(order.firstIndex(of: .custom(duplicateID)), (order.firstIndex(of: .custom(id)) ?? -2) + 1)
    }

    func testOrientationCopyPreservesBothVariantsAndNonLayoutProfileData() throws {
        let launchTarget = GamepadProfileLaunchTarget(
            displayName: "Example",
            bundleIdentifier: "com.example.game"
        )
        var landscape = GamepadCustomization.blankCanvas
        landscape.colorSchemePreference = .dark
        landscape.accentStyle = .purple
        landscape.styleLibrary = GamepadStyleLibrary(styles: [
            GamepadStyleToken(
                id: "shared",
                name: "Shared",
                visualStyle: GamepadControlVisualStyle(normal: GamepadControlStateStyle(opacity: 0.8))
            )
        ])
        landscape.addCustomButton(id: UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!, mappedTo: .custom1)
        landscape.customButtons[0].layout.centerX = 0.8
        landscape.customButtons[0].layout.centerY = 0.25
        landscape.deviceCanvas = GamepadDeviceCanvas(frameID: "iphone-17-pro-landscape")

        var profile = GamepadConfigurationProfile(
            name: "Variants",
            customization: landscape,
            outputMode: .controller,
            launchTarget: launchTarget
        )
        profile.copyLayoutVariant(from: .landscape, to: .portrait)

        let savedLandscape = try XCTUnwrap(profile.landscapeCustomization)
        let savedPortrait = try XCTUnwrap(profile.portraitCustomization)
        XCTAssertEqual(savedLandscape.deviceCanvas.editorDeviceFrame.orientation, .landscape)
        XCTAssertEqual(savedPortrait.deviceCanvas.editorDeviceFrame.orientation, .portrait)
        XCTAssertEqual(try XCTUnwrap(savedLandscape.customButtons[0].layout.centerX), CGFloat(0.8), accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(savedLandscape.customButtons[0].layout.centerY), CGFloat(0.25), accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(savedPortrait.customButtons[0].layout.centerX), CGFloat(0.25), accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(savedPortrait.customButtons[0].layout.centerY), CGFloat(0.2), accuracy: 0.001)
        XCTAssertEqual(savedPortrait.accentStyle, .purple)
        XCTAssertEqual(savedPortrait.styleLibrary, savedLandscape.styleLibrary)
        XCTAssertEqual(profile.outputMode, .controller)
        XCTAssertEqual(profile.launchTarget?.bundleIdentifier, "com.example.game")
    }

    func testOrientationCopyIgnoresMissingSourceVariant() {
        var landscape = GamepadCustomization.blankCanvas
        landscape.deviceCanvas = GamepadDeviceCanvas(frameID: "iphone-17-pro-landscape")
        var profile = GamepadConfigurationProfile(name: "Landscape Only", customization: landscape)
        let original = profile

        profile.copyLayoutVariant(from: .portrait, to: .landscape)

        XCTAssertEqual(profile, original)
        XCTAssertNil(profile.portraitCustomization)
    }

    func testSetCustomizationCorrectsVariantFrameOrientation() {
        var profile = GamepadConfigurationProfile(name: "Variants", customization: .blankCanvas)
        var landscapeFramedCustomization = GamepadCustomization.blankCanvas
        landscapeFramedCustomization.deviceCanvas = GamepadDeviceCanvas(frameID: "iphone-17-pro-landscape")

        profile.setCustomization(landscapeFramedCustomization, for: .portrait)

        XCTAssertEqual(profile.portraitCustomization?.deviceCanvas.editorDeviceFrame.orientation, .portrait)
        XCTAssertEqual(profile.portraitCustomization?.deviceCanvas.editorDeviceFrame.spec.id, "iphone-17-pro")
    }

    func testSharedAlignAndDistributeOperationsUseExplicitModes() throws {
        let ids = (1...3).map { index in
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", 0xC000 + index))!
        }
        var customization = GamepadCustomization.blankCanvas
        customization.customButtons = zip(ids, [0.2, 0.45, 0.8]).map { id, x in
            GamepadCustomButton(
                id: id,
                mappedButton: .custom1,
                label: "Key",
                layout: GamepadButtonCustomization(centerX: x, centerY: 0.2 + x / 2, shape: .rectangle)
            )
        }
        let canvas = CGSize(width: 600, height: 300)
        let identities = Set(ids.map(GamepadControlIdentity.custom))

        XCTAssertTrue(try customization.alignControls(identities, alignment: .topEdges, in: canvas))
        let aligned = customization.resolvedControls(in: canvas).filter { identities.contains($0.id) }
        XCTAssertEqual(Set(aligned.map { Int($0.frame.minY.rounded()) }).count, 1)

        customization.customButtons[1].layout.centerX = 0.3
        XCTAssertTrue(try customization.distributeControls(identities, distribution: .horizontalCenters, in: canvas))
        let distributed = customization.resolvedControls(in: canvas)
            .filter { identities.contains($0.id) }
            .sorted { $0.center.x < $1.center.x }
        XCTAssertEqual(distributed[1].center.x - distributed[0].center.x, distributed[2].center.x - distributed[1].center.x, accuracy: 0.001)
    }

    func testMinimumTouchTargetRepairGrowsOnlyAffectedUnlockedControls() throws {
        let smallID = UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!
        let lockedID = UUID(uuidString: "00000000-0000-0000-0000-00000000E002")!
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(id: smallID, mappedTo: .custom1)
        customization.addCustomButton(id: lockedID, mappedTo: .custom2)
        customization.customButtons[0].layout.widthScale = 0.2
        customization.customButtons[0].layout.heightScale = 0.2
        customization.customButtons[1].layout.widthScale = 0.2
        customization.customButtons[1].layout.heightScale = 0.2
        customization.customButtons[1].layout.isLocationLocked = true
        let canvas = CGSize(width: 600, height: 300)
        let issue = GamepadLayoutIssue(
            severity: .warning,
            code: "small-control",
            message: "Small controls",
            controls: [GamepadControlIdentity.custom(smallID).id, GamepadControlIdentity.custom(lockedID).id],
            metric: 20
        )

        let result = customization.applyLayoutRepair(.minimumTouchTarget, issue: issue, canvasSize: canvas)
        let repaired = try XCTUnwrap(customization.resolvedControls(in: canvas).first { $0.id == .custom(smallID) })
        let locked = try XCTUnwrap(customization.resolvedControls(in: canvas).first { $0.id == .custom(lockedID) })

        XCTAssertGreaterThanOrEqual(repaired.size.width, 43.9)
        XCTAssertGreaterThanOrEqual(repaired.size.height, 43.9)
        XCTAssertLessThan(locked.size.width, 44)
        XCTAssertTrue(result.changedControlIDs.contains(GamepadControlIdentity.custom(smallID).id))
        XCTAssertTrue(result.skippedLockedControlIDs.contains(GamepadControlIdentity.custom(lockedID).id))
    }

    func testEdgeRepairMovesControlToComfortableInset() throws {
        let id = UUID(uuidString: "00000000-0000-0000-0000-00000000E003")!
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(id: id, mappedTo: .custom1)
        customization.customButtons[0].layout.centerX = 0
        customization.customButtons[0].layout.centerY = 0
        let canvas = CGSize(width: 600, height: 300)
        let issue = GamepadLayoutIssue(
            severity: .warning,
            code: "edge-hugging-control",
            message: "Edge",
            controls: [GamepadControlIdentity.custom(id).id],
            metric: nil
        )

        let result = customization.applyLayoutRepair(.moveInsideSafeArea, issue: issue, canvasSize: canvas)
        let repaired = try XCTUnwrap(customization.resolvedControls(in: canvas).first { $0.id == .custom(id) })

        XCTAssertGreaterThan(repaired.frame.minX, 1)
        XCTAssertGreaterThan(repaired.frame.minY, 1)
        XCTAssertTrue(result.didChange)
    }

    func testOverlapRepairSeparatesSecondControl() throws {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-00000000E004")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-00000000E005")!
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(id: firstID, mappedTo: .custom1)
        customization.addCustomButton(id: secondID, mappedTo: .custom2)
        customization.customButtons[0].layout.centerX = 0.5
        customization.customButtons[0].layout.centerY = 0.5
        customization.customButtons[1].layout.centerX = 0.5
        customization.customButtons[1].layout.centerY = 0.5
        let canvas = CGSize(width: 600, height: 300)
        let issue = GamepadLayoutIssue(
            severity: .warning,
            code: "control-overlap",
            message: "Overlap",
            controls: [GamepadControlIdentity.custom(firstID).id, GamepadControlIdentity.custom(secondID).id],
            metric: 1
        )

        let result = customization.applyLayoutRepair(.resolveOverlap, issue: issue, canvasSize: canvas)
        let controls = customization.resolvedControls(in: canvas).filter { $0.id == .custom(firstID) || $0.id == .custom(secondID) }

        XCTAssertEqual(controls.count, 2)
        XCTAssertFalse(controls[0].frame.intersects(controls[1].frame))
        XCTAssertTrue(result.changedControlIDs.contains(GamepadControlIdentity.custom(secondID).id))
    }

    func testOverlapRepairMovesUnlockedControlAroundLockedPeer() throws {
        let unlockedID = UUID(uuidString: "00000000-0000-0000-0000-00000000E006")!
        let lockedID = UUID(uuidString: "00000000-0000-0000-0000-00000000E007")!
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(id: unlockedID, mappedTo: .custom1)
        customization.addCustomButton(id: lockedID, mappedTo: .custom2)
        customization.customButtons[0].layout.centerX = 0.5
        customization.customButtons[0].layout.centerY = 0.5
        customization.customButtons[1].layout.centerX = 0.5
        customization.customButtons[1].layout.centerY = 0.5
        customization.customButtons[1].layout.isLocationLocked = true
        let canvas = CGSize(width: 600, height: 300)
        let issue = GamepadLayoutIssue(
            severity: .warning,
            code: "control-overlap",
            message: "Overlap",
            controls: [GamepadControlIdentity.custom(unlockedID).id, GamepadControlIdentity.custom(lockedID).id],
            metric: 1
        )

        let result = customization.applyLayoutRepair(.resolveOverlap, issue: issue, canvasSize: canvas)
        let unlocked = try XCTUnwrap(customization.resolvedControls(in: canvas).first { $0.id == .custom(unlockedID) })
        let locked = try XCTUnwrap(customization.resolvedControls(in: canvas).first { $0.id == .custom(lockedID) })

        XCTAssertFalse(unlocked.frame.intersects(locked.frame))
        XCTAssertTrue(result.changedControlIDs.contains(GamepadControlIdentity.custom(unlockedID).id))
        XCTAssertTrue(result.skippedLockedControlIDs.contains(GamepadControlIdentity.custom(lockedID).id))
    }

    func testGroupRenameAndDuplicateCloneChildrenAndOutputs() throws {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-00000000D002")!
        let groupID = UUID(uuidString: "00000000-0000-0000-0000-00000000D100")!
        var customization = GamepadCustomization.blankCanvas
        customization.addCustomButton(id: firstID, mappedTo: .custom1)
        customization.addCustomButton(id: secondID, mappedTo: .custom2)
        customization = customization.normalized
        let elementIndex = try XCTUnwrap(customization.elements.firstIndex(where: { $0.id == firstID }))
        customization.elements[elementIndex].setOutputBinding(
            KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 49))
        )
        customization.designMetadata = GamepadDesignMetadata(
            layerOrder: [.custom(firstID), .custom(secondID)],
            groups: [GamepadLayerGroup(id: groupID, name: "Old", children: [.custom(firstID), .custom(secondID)])]
        )

        let renamed = try customization.renameLayerGroup(id: groupID, to: "Actions")
        XCTAssertEqual(renamed.name, "Actions")
        let duplicate = try customization.duplicateLayerGroup(id: groupID, name: "Actions Copy")
        XCTAssertEqual(duplicate.group.name, "Actions Copy")
        XCTAssertEqual(duplicate.group.children.count, 2)
        XCTAssertEqual(customization.designMetadata?.groups.count, 2)

        let duplicatedFirst = try XCTUnwrap(duplicate.elements.identityMap[.custom(firstID)])
        XCTAssertEqual(
            customization.element(for: duplicatedFirst)?.outputBinding(),
            KeypadElementOutputBinding(keyboard: KeypadKeyboardBinding(keyCode: 49))
        )
    }
}
