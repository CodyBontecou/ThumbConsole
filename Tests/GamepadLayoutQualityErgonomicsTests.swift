import CoreGraphics
import XCTest

final class GamepadLayoutQualityErgonomicsTests: XCTestCase {
    private let landscape = CGSize(width: 400, height: 200)
    private let portrait = CGSize(width: 300, height: 600)

    func testExpandedRuntimeHitOverlapIsDistinctFromVisualOverlapAndRepairable() throws {
        let firstID = uuid(1)
        let secondID = uuid(2)
        var customization = makeCustomization([
            button(firstID, .custom1, x: 0.30, y: 0.72),
            button(secondID, .custom2, x: 0.70, y: 0.72)
        ])
        let preliminary = customization.resolvedControls(in: landscape).sorted { $0.id.id < $1.id.id }
        let width = try XCTUnwrap(preliminary.first?.frame.width)
        let visualGap: CGFloat = 12
        let join = landscape.width / 2
        customization.customButtons[0].layout.centerX = (join - visualGap / 2 - width / 2) / landscape.width
        customization.customButtons[1].layout.centerX = (join + visualGap / 2 + width / 2) / landscape.width

        let report = customization.layoutQualityReport(canvasSize: landscape)
        let hitIssue = try XCTUnwrap(report.issues.first { $0.code == "expanded-hit-overlap" })
        XCTAssertFalse(report.issues.contains { $0.code == "control-overlap" })
        XCTAssertEqual(hitIssue.controls, ["custom.\(firstID.uuidString)", "custom.\(secondID.uuidString)"])
        XCTAssertGreaterThan(try XCTUnwrap(hitIssue.metric), 0)
        XCTAssertEqual(report.suggestedRepairs.first?.kind, .separateExpandedHitTargets)
        XCTAssertNotNil(report.controls.first?.expandedHitFrame)

        XCTAssertTrue(customization.separateExpandedHitTargets(in: landscape))
        XCTAssertFalse(customization.layoutQualityReport(canvasSize: landscape).issues.contains { $0.code == "expanded-hit-overlap" })
    }

    func testVisualOverlapKeepsExistingCodeAndReportsZOrderMismatch() {
        let backID = uuid(10)
        let frontID = uuid(11)
        var back = button(backID, .custom1, x: 0.5, y: 0.6, scale: 0.65)
        var front = button(frontID, .custom2, x: 0.5, y: 0.6, scale: 1.25)
        back.layout.zIndex = 0
        front.layout.zIndex = 20
        let customization = makeCustomization([back, front], order: [.custom(backID), .custom(frontID)])

        let report = customization.layoutQualityReport(canvasSize: landscape)
        XCTAssertTrue(report.issues.contains { $0.code == "control-overlap" })
        XCTAssertTrue(report.issues.contains { $0.code == "hit-region-z-order-mismatch" })
        XCTAssertFalse(report.issues.contains { $0.code == "expanded-hit-overlap" })
    }

    func testEqualAreaOverlappingTargetsReportDeterministicZOrderAmbiguity() {
        let backID = uuid(20)
        let frontID = uuid(21)
        var back = button(backID, .custom1, x: 0.5, y: 0.7)
        var front = button(frontID, .custom2, x: 0.5, y: 0.7)
        back.layout.zIndex = -1
        front.layout.zIndex = 1
        let customization = makeCustomization([back, front])

        let first = customization.layoutQualityReport(canvasSize: landscape)
        let second = customization.layoutQualityReport(canvasSize: landscape)
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.issues.contains { $0.code == "hit-region-z-order-ambiguous" })
        XCTAssertEqual(first.issues.map { "\($0.code):\($0.controls.joined(separator: ","))" }, first.issues.map { "\($0.code):\($0.controls.joined(separator: ","))" }.sorted())
    }

    func testLandscapeThumbReachFlagsTopCentralAndOppositeSidePrimaryControls() {
        let customization = makeCustomization([
            button(uuid(30), .jump, x: 0.82, y: 0.10),
            button(uuid(31), .attack, x: 0.50, y: 0.55),
            button(uuid(32), .left, x: 0.92, y: 0.68)
        ])
        let report = customization.layoutQualityReport(canvasSize: landscape)

        XCTAssertTrue(report.issues.contains { $0.code == "primary-control-too-high" && $0.controls == ["custom.\(uuid(30).uuidString)"] })
        XCTAssertTrue(report.issues.contains { $0.code == "primary-control-too-central" && $0.controls == ["custom.\(uuid(31).uuidString)"] })
        XCTAssertTrue(report.issues.contains { $0.code == "primary-control-out-of-reach" && $0.controls == ["custom.\(uuid(32).uuidString)"] })
        XCTAssertEqual(report.suggestedRepairs.last?.kind, .ergonomicAutoArrange)
    }

    func testPortraitDeadSpaceAndUnbalancedPrimaryDistributionAreReported() {
        let customization = makeCustomization([
            button(uuid(40), .map, x: 0.25, y: 0.08, scale: 0.55),
            button(uuid(41), .pause, x: 0.75, y: 0.08, scale: 0.55),
            button(uuid(42), .jump, x: 0.70, y: 0.72, scale: 0.55),
            button(uuid(43), .attack, x: 0.84, y: 0.72, scale: 0.55),
            button(uuid(44), .dash, x: 0.70, y: 0.86, scale: 0.55),
            button(uuid(45), .focus, x: 0.84, y: 0.86, scale: 0.55)
        ])
        let report = customization.layoutQualityReport(canvasSize: portrait)

        XCTAssertTrue(report.issues.contains { $0.code == "portrait-dead-space" })
        XCTAssertTrue(report.issues.contains { $0.code == "portrait-primary-action-distribution" })
    }

    func testReasonableLayoutsAvoidErgonomicFalsePositivesIncludingSpecializedControls() {
        let simpleReasonableLayout = makeCustomization([
            button(uuid(48), .left, x: 0.18, y: 0.68, scale: 0.90),
            button(uuid(49), .jump, x: 0.82, y: 0.68, scale: 0.90)
        ])
        let simpleReport = simpleReasonableLayout.layoutQualityReport(canvasSize: landscape)
        XCTAssertTrue(simpleReport.issues.isEmpty, "Reasonable two-thumb layout issues: \(simpleReport.issues)")

        var landscapeCustomization = makeCustomization([
            button(uuid(50), .up, x: 0.18, y: 0.52, scale: 0.55),
            button(uuid(51), .left, x: 0.11, y: 0.68, scale: 0.55),
            button(uuid(52), .right, x: 0.25, y: 0.68, scale: 0.55),
            button(uuid(53), .down, x: 0.18, y: 0.84, scale: 0.55),
            button(uuid(54), .jump, x: 0.82, y: 0.84, scale: 0.55),
            button(uuid(55), .attack, x: 0.75, y: 0.68, scale: 0.55),
            button(uuid(56), .dash, x: 0.89, y: 0.68, scale: 0.55),
            button(uuid(57), .focus, x: 0.82, y: 0.52, scale: 0.55),
            button(uuid(58), .map, x: 0.5, y: 0.10, scale: 0.45)
        ])
        landscapeCustomization.addJoystick(id: uuid(59), label: "Stick", mapping: .movement)
        let joystickIndex = landscapeCustomization.customButtons.count - 1
        landscapeCustomization.customButtons[joystickIndex].layout.centerX = 0.5
        landscapeCustomization.customButtons[joystickIndex].layout.centerY = 0.12
        landscapeCustomization.addTrackpad(id: uuid(60))
        let trackpadIndex = landscapeCustomization.customButtons.count - 1
        landscapeCustomization.customButtons[trackpadIndex].layout.centerX = 0.5
        landscapeCustomization.customButtons[trackpadIndex].layout.centerY = 0.35

        let landscapeReport = landscapeCustomization.layoutQualityReport(canvasSize: landscape)
        XCTAssertFalse(landscapeReport.issues.contains { $0.code.hasPrefix("primary-control-") })

        let portraitCustomization = makeCustomization([
            button(uuid(61), .up, x: 0.27, y: 0.62, scale: 0.45),
            button(uuid(62), .down, x: 0.27, y: 0.84, scale: 0.45),
            button(uuid(63), .jump, x: 0.73, y: 0.84, scale: 0.45),
            button(uuid(64), .attack, x: 0.73, y: 0.62, scale: 0.45)
        ])
        let portraitReport = portraitCustomization.layoutQualityReport(canvasSize: portrait)
        XCTAssertFalse(portraitReport.issues.contains { $0.code.hasPrefix("primary-control-") || $0.code == "portrait-primary-action-distribution" })
    }

    func testErgonomicRepairMovesPrimaryControlsButLeavesUtilitiesAndJoysticksAlone() throws {
        let actionID = uuid(65)
        let utilityID = uuid(66)
        let joystickID = uuid(67)
        var customization = makeCustomization([
            button(actionID, .jump, x: 0.5, y: 0.12, scale: 0.5),
            button(utilityID, .map, x: 0.10, y: 0.12, scale: 0.5)
        ])
        customization.addJoystick(id: joystickID, label: "Aim", mapping: .secondary)
        let joystickIndex = customization.customButtons.count - 1
        customization.customButtons[joystickIndex].layout.centerX = 0.5
        customization.customButtons[joystickIndex].layout.centerY = 0.35
        let before = Dictionary(uniqueKeysWithValues: customization.resolvedControls(in: portrait).map { ($0.id, $0.center) })

        XCTAssertTrue(customization.ergonomicallyAutoArrange(in: portrait))
        let after = Dictionary(uniqueKeysWithValues: customization.resolvedControls(in: portrait).map { ($0.id, $0.center) })
        XCTAssertNotEqual(try XCTUnwrap(after[.custom(actionID)]), try XCTUnwrap(before[.custom(actionID)]))
        XCTAssertEqual(try XCTUnwrap(after[.custom(utilityID)]), try XCTUnwrap(before[.custom(utilityID)]))
        XCTAssertEqual(try XCTUnwrap(after[.custom(joystickID)]), try XCTUnwrap(before[.custom(joystickID)]))
        XCTAssertFalse(customization.layoutQualityReport(canvasSize: portrait).issues.contains {
            $0.code.hasPrefix("primary-control-") && $0.controls.contains("custom.\(actionID.uuidString)")
        })
    }

    func testSmallControlsAreReportedAndLockedControlsAreNeverMovedByRepairs() throws {
        let lockedID = uuid(70)
        let movableID = uuid(71)
        var locked = button(lockedID, .custom1, x: 0.45, y: 0.72, scale: 0.30)
        locked.layout.isLocationLocked = true
        let movable = button(movableID, .custom2, x: 0.52, y: 0.72, scale: 0.30)
        var customization = makeCustomization([locked, movable])
        let before = try XCTUnwrap(customization.resolvedControls(in: landscape).first { $0.id == .custom(lockedID) }).center

        let report = customization.layoutQualityReport(canvasSize: landscape)
        XCTAssertTrue(report.issues.contains { $0.code == "small-control" })
        XCTAssertTrue(customization.separateExpandedHitTargets(in: landscape))
        let after = try XCTUnwrap(customization.resolvedControls(in: landscape).first { $0.id == .custom(lockedID) }).center
        XCTAssertEqual(after.x, before.x, accuracy: 0.001)
        XCTAssertEqual(after.y, before.y, accuracy: 0.001)

        var bothLocked = customization
        bothLocked.customButtons[1].layout.isLocationLocked = true
        bothLocked.customButtons[1].layout.centerX = bothLocked.customButtons[0].layout.centerX
        bothLocked.customButtons[1].layout.centerY = bothLocked.customButtons[0].layout.centerY
        let lockedReport = bothLocked.layoutQualityReport(canvasSize: landscape)
        XCTAssertTrue(lockedReport.issues.contains { $0.code == "control-overlap" })
        XCTAssertFalse(lockedReport.suggestedRepairs.contains { $0.kind == .separateExpandedHitTargets })
        XCTAssertFalse(bothLocked.separateExpandedHitTargets(in: landscape))
    }

    func testQualityReportDecodesWithoutNewRepairAndExpandedHitFields() throws {
        let report = makeCustomization([button(uuid(80), .jump, x: 0.8, y: 0.75)]).layoutQualityReport(canvasSize: landscape)
        let encoded = try JSONEncoder().encode(report)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "suggestedRepairs")
        if var controls = object["controls"] as? [[String: Any]] {
            for index in controls.indices { controls[index].removeValue(forKey: "expandedHitFrame") }
            object["controls"] = controls
        }
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(GamepadLayoutQualityReport.self, from: legacyData)
        XCTAssertEqual(decoded.suggestedRepairs, [])
        XCTAssertNil(decoded.controls.first?.expandedHitFrame)
    }

    private func makeCustomization(
        _ buttons: [GamepadCustomButton],
        order: [GamepadControlIdentity]? = nil
    ) -> GamepadCustomization {
        var customization = GamepadCustomization.blankCanvas
        customization.customButtons = buttons
        customization.designMetadata = GamepadDesignMetadata(layerOrder: order ?? buttons.map { .custom($0.id) })
        return customization
    }

    private func button(
        _ id: UUID,
        _ mappedButton: GameButton,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat = 1
    ) -> GamepadCustomButton {
        GamepadCustomButton(
            id: id,
            mappedButton: mappedButton,
            label: mappedButton.displayName,
            layout: GamepadButtonCustomization(
                centerX: x,
                centerY: y,
                widthScale: scale,
                heightScale: scale,
                shape: .rectangle
            )
        )
    }

    private func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", suffix))!
    }
}
