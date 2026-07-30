import Darwin
import Foundation
import XCTest

final class ThumbleCLIBackendTests: XCTestCase {
    private let invocationID = UUID(uuidString: "AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE")!

    func testTypedHelperAcceptsOneStrictBoundedResponseAndPreservesInvocation() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","authorityPresent":false}'
        """)
        let backend = try ThumbleCLIProfileBackend(executableURL: helper)
        let response = try backend.perform(.authorityStatus, invocationID: invocationID)
        XCTAssertEqual(response.invocationID, invocationID)
        XCTAssertEqual(response.authorityPresent, false)
    }

    func testOrientationProjectionIsStrictTypedAndRevisionTagged() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","orientation":{"configurationRevision":9,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","orientation":"portrait"}}'
        """)
        let backend = try ThumbleCLIProfileBackend(executableURL: helper)
        let response = try backend.perform(
            .orientationGet(.active),
            invocationID: invocationID
        )
        XCTAssertEqual(response.orientation?.configurationRevision, 9)
        XCTAssertEqual(response.orientation?.profileName, "Arcade")
        XCTAssertEqual(response.orientation?.orientation, .portrait)
    }

    func testBindingProjectionIsStrictBoundedSemanticAndRevisionTagged() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","projection":{"kind":"bindingList","configurationRevision":11,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","outputMode":"custom","rows":[{"button":"jump","output":{"keyboard":[{"key":"Space","modifiers":["shift"]}],"gamepadButtons":["south"]}}]}}'
        """)
        let backend = try ThumbleCLIProfileBackend(executableURL: helper)
        let response = try backend.perform(
            .bindingList(.active),
            invocationID: invocationID
        )
        XCTAssertEqual(response.projection?.configurationRevision, 11)
        XCTAssertEqual(response.projection?.kind, .bindingList)
        XCTAssertEqual(response.projection?.rows?.first?.button, .jump)
        XCTAssertEqual(response.projection?.rows?.first?.output?.keyboard.first?.key, "Space")
        XCTAssertEqual(response.projection?.rows?.first?.output?.gamepadButtons, [.south])
    }

    func testBindingProjectionRejectsUnknownNestedFields() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","projection":{"kind":"bindingList","configurationRevision":11,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","rows":[{"button":"jump","output":{"keyboard":[{"key":"Space","modifiers":[],"keyCode":49}],"gamepadButtons":[]}}]}}'
        """)
        XCTAssertThrowsError(
            try ThumbleCLIProfileBackend(executableURL: helper)
                .perform(.bindingList(.active), invocationID: invocationID)
        ) { XCTAssertEqual($0 as? ThumbleCLIProfileBackend.BackendError, .malformedResponse) }
    }

    func testControlBarProjectionIsStrictBoundedAndRevisionTagged() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","controlBar":{"configurationRevision":13,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","variant":"landscape","items":[{"order":1,"item":"settings"},{"order":2,"item":"home"}]}}'
        """)
        let backend = try ThumbleCLIProfileBackend(executableURL: helper)
        let response = try backend.perform(
            .controlBarList(.active, .landscape),
            invocationID: invocationID
        )
        XCTAssertEqual(response.controlBar?.configurationRevision, 13)
        XCTAssertEqual(response.controlBar?.variant, .landscape)
        XCTAssertEqual(response.controlBar?.items.map(\.item), [.settings, .home])
    }

    func testControlBarItemProjectionIsStrictSanitizedAndRevisionTagged() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","controlBarItem":{"configurationRevision":14,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","variant":"portrait","order":2,"item":"settings","appearance":{"item":"settings","targetID":"control_bar_item.settings","index":1,"isHidden":false,"widthScale":0.8,"heightScale":1.2,"shape":"capsule","shadowStrength":0.4,"fill":{"kind":"solid","color":{"red":1,"green":0,"blue":0,"alpha":0.7}},"unsupportedContentOmitted":true}}}'
        """)
        let response = try ThumbleCLIProfileBackend(executableURL: helper).perform(
            .controlBarItemShow(.active, .portrait, .settings),
            invocationID: invocationID
        )
        XCTAssertEqual(response.controlBarItem?.configurationRevision, 14)
        XCTAssertEqual(response.controlBarItem?.order, 2)
        XCTAssertEqual(response.controlBarItem?.appearance.widthScale, 0.8)
        XCTAssertEqual(response.controlBarItem?.appearance.fill, .solid(.init(red: 1, green: 0, blue: 0, alpha: 0.7)))
        XCTAssertEqual(response.controlBarItem?.appearance.unsupportedContentOmitted, true)
    }

    func testLayerProjectionIsStrictSanitizedAndRevisionTagged() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","layers":{"configurationRevision":17,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","variant":"primary","layers":[{"targetID":"jump","stableID":"builtin.jump","label":"Action 1","kind":"button","zIndex":3,"isHidden":false,"isLocationLocked":false,"styleID":"soul"}]}}'
        """)
        let response = try ThumbleCLIProfileBackend(executableURL: helper).perform(
            .layerList(.active, .primary),
            invocationID: invocationID
        )
        XCTAssertEqual(response.layers?.configurationRevision, 17)
        XCTAssertEqual(response.layers?.variant, .primary)
        XCTAssertEqual(response.layers?.layers.first?.stableID, "builtin.jump")
        XCTAssertEqual(response.layers?.layers.first?.styleID, "soul")
    }

    func testGroupProjectionIsStrictSanitizedVariantScopedAndRevisionTagged() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","groups":{"configurationRevision":18,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","variant":"portrait","groups":[{"id":"00000000-0000-0000-0000-000000000801","name":"Actions","childTargetIDs":["00000000-0000-0000-0000-000000000105"],"childStableIDs":["builtin.jump"],"isLocked":false,"isHidden":true}]}}'
        """)
        let response = try ThumbleCLIProfileBackend(executableURL: helper).perform(
            .groupList(.active, .portrait),
            invocationID: invocationID
        )
        XCTAssertEqual(response.groups?.configurationRevision, 18)
        XCTAssertEqual(response.groups?.variant, .portrait)
        XCTAssertEqual(response.groups?.groups.first?.name, "Actions")
        XCTAssertEqual(response.groups?.groups.first?.childStableIDs, ["builtin.jump"])
        XCTAssertEqual(response.groups?.groups.first?.isHidden, true)
    }

    func testStyleProjectionIsStrictSanitizedAndRevisionTagged() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","styles":{"configurationRevision":16,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","styles":[{"id":"soul","name":"Soul","appliesTo":["button"],"appearance":{"normal":{"fillColor":{"red":1,"green":0.5,"blue":0,"alpha":1},"shadows":[]}},"unsupportedContentOmitted":false}]}}'
        """)
        let response = try ThumbleCLIProfileBackend(executableURL: helper).perform(
            .styleList(.active),
            invocationID: invocationID
        )
        XCTAssertEqual(response.styles?.configurationRevision, 16)
        XCTAssertEqual(response.styles?.styles.first?.id, "soul")
        XCTAssertEqual(response.styles?.styles.first?.appearance.normal.fillColor?.green, 0.5)
    }

    func testDeviceProjectionIsStrictCatalogTypedAndRevisionTagged() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","device":{"configurationRevision":15,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","variant":"portrait","frameID":"iphone-16-pro-portrait","frameOrientation":"portrait"}}'
        """)
        let response = try ThumbleCLIProfileBackend(executableURL: helper).perform(
            .deviceGet(.active, .portrait),
            invocationID: invocationID
        )
        XCTAssertEqual(response.device?.configurationRevision, 15)
        XCTAssertEqual(response.device?.variant, .portrait)
        XCTAssertEqual(response.device?.frameID, "iphone-16-pro-portrait")
    }

    func testControlBarProjectionRejectsUnknownNestedFieldsAndInvalidOrder() throws {
        let helper = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","controlBar":{"configurationRevision":13,"profileID":"00000000-0000-0000-0000-000000000201","profileName":"Arcade","variant":"primary","items":[{"order":2,"item":"settings","appearance":{}}]}}'
        """)
        XCTAssertThrowsError(
            try ThumbleCLIProfileBackend(executableURL: helper)
                .perform(.controlBarList(.active, .primary), invocationID: invocationID)
        ) { XCTAssertEqual($0 as? ThumbleCLIProfileBackend.BackendError, .malformedResponse) }
    }

    func testUnknownAndMultilineResponsesFailClosed() throws {
        let unknown = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n' '{"schemaVersion":6,"ok":true,"invocationID":"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE","authorityMode":"offline","rawProfile":{}}'
        """)
        XCTAssertThrowsError(
            try ThumbleCLIProfileBackend(executableURL: unknown)
                .perform(.list, invocationID: invocationID)
        ) { XCTAssertEqual($0 as? ThumbleCLIProfileBackend.BackendError, .malformedResponse) }

        let multiline = try makeHelper(body: """
        IFS= read -r line || exit 3
        printf '%s\\n%s\\n' '{}' '{}'
        """)
        XCTAssertThrowsError(
            try ThumbleCLIProfileBackend(executableURL: multiline)
                .perform(.list, invocationID: invocationID)
        ) { XCTAssertEqual($0 as? ThumbleCLIProfileBackend.BackendError, .malformedResponse) }
    }

    func testTimeoutKillsHelperProcessGroup() throws {
        let helper = try makeHelper(body: """
        /bin/sleep 5 &
        /bin/sleep 5
        """)
        let backend = try ThumbleCLIProfileBackend(executableURL: helper, timeout: 0.05)
        XCTAssertThrowsError(try backend.perform(.list, invocationID: invocationID)) {
            XCTAssertEqual($0 as? ThumbleCLIProfileBackend.BackendError, .timeout)
        }
    }

    func testOversizedResponseIsRejectedAndStderrIsNeverSurfaced() throws {
        let helper = try makeHelper(body: """
        printf '%s\\n' 'secret-auth-token' >&2
        /usr/bin/python3 -c 'import sys; sys.stdout.write("x" * 300000 + "\\n")'
        """)
        let backend = try ThumbleCLIProfileBackend(executableURL: helper)
        XCTAssertThrowsError(try backend.perform(.list, invocationID: invocationID)) { error in
            XCTAssertEqual(error as? ThumbleCLIProfileBackend.BackendError, .responseTooLarge)
            XCTAssertFalse(error.localizedDescription.contains("secret-auth-token"))
        }
    }

    func testSymlinkAndWritableSiblingValidationFailClosed() throws {
        let real = try makeHelper(body: "exit 0")
        let link = real.deletingLastPathComponent().appendingPathComponent("linked-helper")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        XCTAssertThrowsError(try ThumbleCLIProfileBackend(executableURL: link)) {
            XCTAssertEqual($0 as? ThumbleCLIProfileBackend.BackendError, .insecureExecutable)
        }

        XCTAssertEqual(chmod(real.path, 0o775), 0)
        XCTAssertThrowsError(try ThumbleCLIProfileBackend(executableURL: real)) {
            XCTAssertEqual($0 as? ThumbleCLIProfileBackend.BackendError, .insecureExecutable)
        }
    }

    func testSelectorEncodingUsesTypedUUIDAndNeverRawPathsOrProfiles() throws {
        let command = ThumbleCLIProfileBackend.Command.move(
            [.init("AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE")],
            .before(.init("Arcade"))
        )
        let request = ThumbleCLIProfileBackend.Request(command: command, invocationID: invocationID)
        let data = try JSONEncoder().encode(request)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"profileID\":\"AAAAAAAA-BBBB-5CCC-8DDD-EEEEEEEEEEEE\""))
        XCTAssertFalse(text.lowercased().contains("statepath"))
        XCTAssertFalse(text.lowercased().contains("controlsocket"))
        XCTAssertFalse(text.lowercased().contains("keycode"))
        XCTAssertFalse(text.contains("customization"))

        let orientation = ThumbleCLIProfileBackend.Command.orientationCopy(
            .active,
            .landscape,
            .portrait,
            true
        )
        let orientationData = try JSONEncoder().encode(
            ThumbleCLIProfileBackend.Request(command: orientation, invocationID: invocationID)
        )
        let orientationText = String(decoding: orientationData, as: UTF8.self)
        XCTAssertTrue(orientationText.contains("\"type\":\"orientation.copy\""))
        XCTAssertTrue(orientationText.contains("\"source\":\"landscape\""))
        XCTAssertTrue(orientationText.contains("\"destination\":\"portrait\""))
        XCTAssertFalse(orientationText.lowercased().contains("statepath"))
        XCTAssertFalse(orientationText.contains("customization"))

        let binding = ThumbleCLIProfileBackend.Command.bindingSet(
            .active,
            .jump,
            [.init(key: "B", modifiers: [.control])]
        )
        let bindingData = try JSONEncoder().encode(
            ThumbleCLIProfileBackend.Request(command: binding, invocationID: invocationID)
        )
        let bindingText = String(decoding: bindingData, as: UTF8.self)
        XCTAssertTrue(bindingText.contains("\"type\":\"binding.set\""))
        XCTAssertTrue(bindingText.contains("\"key\":\"B\""))
        XCTAssertFalse(bindingText.lowercased().contains("keycode"))
        XCTAssertFalse(bindingText.lowercased().contains("statepath"))

        let controlBar = ThumbleCLIProfileBackend.Command.controlBarMove(
            .active,
            .portrait,
            .settings,
            .up
        )
        let controlBarData = try JSONEncoder().encode(
            ThumbleCLIProfileBackend.Request(command: controlBar, invocationID: invocationID)
        )
        let controlBarText = String(decoding: controlBarData, as: UTF8.self)
        XCTAssertTrue(controlBarText.contains("\"type\":\"control-bar.move\""))
        XCTAssertTrue(controlBarText.contains("\"variant\":\"portrait\""))
        XCTAssertTrue(controlBarText.contains("\"item\":\"settings\""))
        XCTAssertTrue(controlBarText.contains("\"direction\":\"up\""))
        XCTAssertFalse(controlBarText.lowercased().contains("customization"))
        XCTAssertFalse(controlBarText.lowercased().contains("statepath"))

        var changes = ThumbleCLIProfileBackend.ControlBarItemChanges()
        changes.widthScale = 0.8
        changes.fill = .solid(.init(red: 1, green: 0, blue: 0, alpha: 1))
        changes.icon = .init(source: .sfSymbol, value: "gear")
        let itemSet = ThumbleCLIProfileBackend.Command.controlBarItemSet(
            .active,
            .portrait,
            .settings,
            changes
        )
        let itemData = try JSONEncoder().encode(
            ThumbleCLIProfileBackend.Request(
                command: itemSet,
                invocationID: invocationID,
                expectedConfigurationRevision: 14
            )
        )
        let itemText = String(decoding: itemData, as: UTF8.self)
        XCTAssertTrue(itemText.contains("\"type\":\"control-bar.item.set\""))
        XCTAssertTrue(itemText.contains("\"expectedConfigurationRevision\":14"))
        XCTAssertTrue(itemText.contains("\"source\":\"sf_symbol\""))
        XCTAssertFalse(itemText.lowercased().contains("statepath"))
        XCTAssertFalse(itemText.lowercased().contains("asset"))
        XCTAssertFalse(itemText.lowercased().contains("image"))

        let device = ThumbleCLIProfileBackend.Command.deviceSet(
            .active,
            .landscape,
            "iphone-15-pro-landscape"
        )
        let deviceData = try JSONEncoder().encode(
            ThumbleCLIProfileBackend.Request(command: device, invocationID: invocationID)
        )
        let deviceText = String(decoding: deviceData, as: UTF8.self)
        XCTAssertTrue(deviceText.contains("\"type\":\"device.set\""))
        XCTAssertTrue(deviceText.contains("\"frameID\":\"iphone-15-pro-landscape\""))
        XCTAssertFalse(deviceText.lowercased().contains("statepath"))
        XCTAssertFalse(deviceText.lowercased().contains("customization"))

        let template = ThumbleCLIProfileBackend.Command.templateInstall(
            .softWhite,
            name: "Desk Pad",
            select: true,
            makeDefault: false
        )
        let templateText = String(
            decoding: try JSONEncoder().encode(
                ThumbleCLIProfileBackend.Request(command: template, invocationID: invocationID)
            ),
            as: UTF8.self
        )
        XCTAssertTrue(templateText.contains("\"type\":\"template.install\""))
        XCTAssertTrue(templateText.contains("\"template\":\"softWhite\""))
        XCTAssertTrue(templateText.contains("\"name\":\"Desk Pad\""))
        XCTAssertTrue(templateText.contains("\"select\":true"))
        XCTAssertFalse(templateText.lowercased().contains("statepath"))
        XCTAssertFalse(templateText.lowercased().contains("customization"))
        XCTAssertFalse(templateText.lowercased().contains("keycode"))

        let generation = ThumbleCLIProfileBackend.Command.generationGenerate(
            select: false,
            makeDefault: false
        )
        let generationText = String(
            decoding: try JSONEncoder().encode(
                ThumbleCLIProfileBackend.Request(command: generation, invocationID: invocationID)
            ),
            as: UTF8.self
        )
        XCTAssertTrue(generationText.contains("\"type\":\"generation.generate\""))
        XCTAssertTrue(generationText.contains("\"select\":false"))
        XCTAssertFalse(generationText.lowercased().contains("profileid"))
        XCTAssertFalse(generationText.lowercased().contains("customization"))

        var scalar = ThumbleCLIProfileBackend.CustomizationChanges()
        scalar.layoutMode = .southpaw
        scalar.controlScale = .large
        scalar.showsButtonLabels = false
        var background = ThumbleCLIProfileBackend.CustomizationChanges()
        background.backgroundEdit = .set(
            .dark,
            .init(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
        )
        let customization = ThumbleCLIProfileBackend.Command.customizationSet(
            .active,
            .portrait,
            [scalar, background],
            frameID: "iphone-16-pro-portrait"
        )
        let customizationText = String(
            decoding: try JSONEncoder().encode(
                ThumbleCLIProfileBackend.Request(
                    command: customization,
                    invocationID: invocationID
                )
            ),
            as: UTF8.self
        )
        XCTAssertTrue(customizationText.contains("\"type\":\"customization.set\""))
        XCTAssertTrue(customizationText.contains("\"layoutMode\":\"southpaw\""))
        XCTAssertTrue(customizationText.contains("\"scope\":\"dark\""))
        XCTAssertTrue(customizationText.contains("\"frameID\":\"iphone-16-pro-portrait\""))
        XCTAssertFalse(customizationText.lowercased().contains("statepath"))
        XCTAssertFalse(customizationText.lowercased().contains("asset"))
        XCTAssertFalse(customizationText.lowercased().contains("image"))

        let repair = ThumbleCLIProfileBackend.Command.customizationFix(
            .active,
            .landscape,
            .repair(.moveInsideSafeArea),
            .size(width: 844, height: 390),
            includeLocked: false
        )
        let repairText = String(
            decoding: try JSONEncoder().encode(
                ThumbleCLIProfileBackend.Request(command: repair, invocationID: invocationID)
            ),
            as: UTF8.self
        )
        XCTAssertTrue(repairText.contains("\"type\":\"customization.fix\""))
        XCTAssertTrue(repairText.contains("\"profile\":{\"kind\":\"active\"}"))
        XCTAssertTrue(repairText.contains("\"repair\":\"move-inside-safe-area\""))
        XCTAssertTrue(repairText.contains("\"source\":\"size\""))
        XCTAssertTrue(repairText.contains("\"width\":844"))
        XCTAssertFalse(repairText.lowercased().contains("statepath"))
        XCTAssertFalse(repairText.lowercased().contains("path"))
        XCTAssertFalse(repairText.lowercased().contains("profileid"))

        var styleAppearance = ThumbleCLIProfileBackend.AuthorityStyleAppearance()
        styleAppearance.fillColor = .init(red: 1, green: 0.5, blue: 0, alpha: 1)
        styleAppearance.icon = .init(source: .sfSymbol, value: "sparkles")
        styleAppearance.haptic = .init(
            style: .medium,
            pattern: .double,
            intensity: 0.7,
            sharpness: 0.8,
            duration: 0.09
        )
        let style = ThumbleCLIProfileBackend.Command.styleCreate(
            .active,
            styleID: "soul",
            name: "Soul",
            appearance: styleAppearance
        )
        let styleText = String(
            decoding: try JSONEncoder().encode(
                ThumbleCLIProfileBackend.Request(command: style, invocationID: invocationID)
            ),
            as: UTF8.self
        )
        XCTAssertTrue(styleText.contains("\"type\":\"style.create\""))
        XCTAssertTrue(styleText.contains("\"styleID\":\"soul\""))
        XCTAssertTrue(styleText.contains("\"source\":\"sf_symbol\""))
        XCTAssertTrue(styleText.contains("\"pattern\":\"double\""))
        XCTAssertFalse(styleText.lowercased().contains("statepath"))
        XCTAssertFalse(styleText.lowercased().contains("asset"))
        XCTAssertFalse(styleText.lowercased().contains("image"))

        let layer = ThumbleCLIProfileBackend.Command.layerMove(
            .active,
            elementID: "Right Stick",
            destination: .before("Action 1")
        )
        let layerText = String(
            decoding: try JSONEncoder().encode(
                ThumbleCLIProfileBackend.Request(command: layer, invocationID: invocationID)
            ),
            as: UTF8.self
        )
        XCTAssertTrue(layerText.contains("\"type\":\"layer.move\""))
        XCTAssertTrue(layerText.contains("\"elementID\":\"Right Stick\""))
        XCTAssertTrue(layerText.contains("\"action\":\"before\""))
        XCTAssertFalse(layerText.lowercased().contains("statepath"))
        XCTAssertFalse(layerText.lowercased().contains("customization"))

        let group = ThumbleCLIProfileBackend.Command.groupCreate(
            .active,
            .portrait,
            name: "Actions",
            elementIDs: ["jump", "attack"]
        )
        let groupText = String(
            decoding: try JSONEncoder().encode(
                ThumbleCLIProfileBackend.Request(command: group, invocationID: invocationID)
            ),
            as: UTF8.self
        )
        XCTAssertTrue(groupText.contains("\"type\":\"group.create\""))
        XCTAssertTrue(groupText.contains("\"variant\":\"portrait\""))
        XCTAssertTrue(groupText.contains("\"elementIDs\":[\"jump\",\"attack\"]"))
        XCTAssertFalse(groupText.lowercased().contains("groupid"))
        XCTAssertFalse(groupText.lowercased().contains("statepath"))
        XCTAssertFalse(groupText.lowercased().contains("customization"))

        let nudge = ThumbleCLIProfileBackend.Command.groupNudge(
            .active,
            .primary,
            group: "Actions",
            canvasFrameID: "iphone-17-pro-landscape",
            deltaX: 10,
            deltaY: 0
        )
        let nudgeText = String(
            decoding: try JSONEncoder().encode(
                ThumbleCLIProfileBackend.Request(command: nudge, invocationID: invocationID)
            ),
            as: UTF8.self
        )
        XCTAssertTrue(nudgeText.contains("\"type\":\"group.nudge\""))
        XCTAssertTrue(nudgeText.contains("\"canvasFrameID\":\"iphone-17-pro-landscape\""))
        XCTAssertTrue(nudgeText.contains("\"deltaX\":10"))
        XCTAssertFalse(nudgeText.lowercased().contains("statepath"))
    }

    private func makeHelper(body: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumble-cli-backend-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        let helper = directory.appendingPathComponent("thumble-cli-bridge")
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: helper, options: .atomic)
        XCTAssertEqual(chmod(helper.path, 0o755), 0)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return helper
    }
}
