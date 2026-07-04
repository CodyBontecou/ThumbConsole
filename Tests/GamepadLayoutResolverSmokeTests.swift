import Foundation

#if !XCODEBUILD_TEST
@main
#endif
struct GamepadLayoutResolverSmokeTests {
    static func main() {
        testAdjacentControlsCanTouchWithoutBeingSeparated()
        testNudgeMovesSingleControlByPixels()
        testNudgeMovesMultipleControlsTogether()
        testNudgeSkipsLockedControls()
        testNudgePreventsOverlaps()
        testLayoutQualityPassesDefaultController()
        testLayoutQualityDetectsBadOverlaps()
        testLayoutQualityDetectsUnderusedBottomSpace()
        print("GamepadLayoutResolver smoke tests passed")
    }

    private static func testAdjacentControlsCanTouchWithoutBeingSeparated() {
        let canvasSize = CGSize(width: 400, height: 200)
        let leftID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let rightID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        let initialLayout = GamepadButtonCustomization(
            centerX: 0.5,
            centerY: 0.5,
            widthScale: 2.0,
            heightScale: 1.0,
            shape: .rectangle
        )

        var customization = GamepadCustomization.blankCanvas
        customization.customButtons = [
            GamepadCustomButton(id: leftID, mappedButton: .custom1, label: "Left", layout: initialLayout),
            GamepadCustomButton(id: rightID, mappedButton: .custom2, label: "Right", layout: initialLayout)
        ]

        let preliminaryControls = customization.resolvedControls(in: canvasSize)
        guard let preliminaryLeft = preliminaryControls.first(where: { $0.id == .custom(leftID) }) else {
            fail("could not resolve preliminary left custom control")
        }

        let buttonWidth = preliminaryLeft.frame.width
        let joinX = canvasSize.width / 2
        customization.customButtons[0].layout.centerX = (joinX - buttonWidth / 2) / canvasSize.width
        customization.customButtons[1].layout.centerX = (joinX + buttonWidth / 2) / canvasSize.width

        let controls = customization.resolvedControls(in: canvasSize)
        guard let left = controls.first(where: { $0.id == .custom(leftID) }),
              let right = controls.first(where: { $0.id == .custom(rightID) })
        else {
            fail("could not resolve adjacent custom controls")
        }

        expectAlmostEqual(
            left.frame.maxX,
            right.frame.minX,
            "adjacent controls should be allowed to touch exactly without a forced gap"
        )
        expect(
            !framesOverlap(left.frame, right.frame),
            "touching controls should not overlap"
        )
    }

    private static func testNudgeMovesSingleControlByPixels() {
        let canvasSize = CGSize(width: 400, height: 200)
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
        var customization = GamepadCustomization.blankCanvas
        customization.customButtons = [customButton(id: id, center: CGPoint(x: 0.5, y: 0.5))]

        guard let before = customization.resolvedControls(in: canvasSize).first(where: { $0.id == .custom(id) }) else {
            fail("could not resolve control before single nudge")
        }
        expect(customization.nudgeControls([.custom(id)], by: CGSize(width: 1, height: 0), in: canvasSize), "single nudge should move")
        guard let after = customization.resolvedControls(in: canvasSize).first(where: { $0.id == .custom(id) }) else {
            fail("could not resolve control after single nudge")
        }

        expectAlmostEqual(after.center.x, before.center.x + 1, "single nudge should move right by one pixel")
        expectAlmostEqual(after.center.y, before.center.y, "single nudge should not change y")
    }

    private static func testNudgeMovesMultipleControlsTogether() {
        let canvasSize = CGSize(width: 400, height: 200)
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
        var customization = GamepadCustomization.blankCanvas
        customization.customButtons = [
            customButton(id: firstID, center: CGPoint(x: 0.30, y: 0.55)),
            customButton(id: secondID, center: CGPoint(x: 0.70, y: 0.55))
        ]

        let before = controlsByID(customization.resolvedControls(in: canvasSize))
        expect(customization.nudgeControls([.custom(firstID), .custom(secondID)], by: CGSize(width: 0, height: -10), in: canvasSize), "group nudge should move")
        let after = controlsByID(customization.resolvedControls(in: canvasSize))

        expectAlmostEqual(after[.custom(firstID)]?.center.y ?? -1, (before[.custom(firstID)]?.center.y ?? 0) - 10, "first control should move up by ten pixels")
        expectAlmostEqual(after[.custom(secondID)]?.center.y ?? -1, (before[.custom(secondID)]?.center.y ?? 0) - 10, "second control should move up by ten pixels")
    }

    private static func testNudgeSkipsLockedControls() {
        let canvasSize = CGSize(width: 400, height: 200)
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
        var locked = customButton(id: id, center: CGPoint(x: 0.5, y: 0.5))
        locked.layout.isLocationLocked = true
        var customization = GamepadCustomization.blankCanvas
        customization.customButtons = [locked]

        expect(!customization.nudgeControls([.custom(id)], by: CGSize(width: 10, height: 0), in: canvasSize), "locked nudge should not move")
    }

    private static func testNudgePreventsOverlaps() {
        let canvasSize = CGSize(width: 400, height: 200)
        let leftID = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
        let rightID = UUID(uuidString: "00000000-0000-0000-0000-000000000502")!
        var customization = GamepadCustomization.blankCanvas
        customization.customButtons = [
            customButton(id: leftID, center: CGPoint(x: 0.5, y: 0.5)),
            customButton(id: rightID, center: CGPoint(x: 0.5, y: 0.5))
        ]

        let preliminaryControls = customization.resolvedControls(in: canvasSize)
        guard let preliminaryLeft = preliminaryControls.first(where: { $0.id == .custom(leftID) }) else {
            fail("could not resolve preliminary left control for nudge overlap test")
        }
        let buttonWidth = preliminaryLeft.frame.width
        let joinX = canvasSize.width / 2
        customization.customButtons[0].layout.centerX = (joinX - buttonWidth / 2) / canvasSize.width
        customization.customButtons[1].layout.centerX = (joinX + buttonWidth / 2) / canvasSize.width

        let before = controlsByID(customization.resolvedControls(in: canvasSize))
        expect(!customization.nudgeControls([.custom(leftID)], by: CGSize(width: 1, height: 0), in: canvasSize), "nudge should not move into an overlapping frame")
        let after = controlsByID(customization.resolvedControls(in: canvasSize))
        expectAlmostEqual(after[.custom(leftID)]?.center.x ?? -1, before[.custom(leftID)]?.center.x ?? 0, "blocked nudge should keep x position")
    }

    private static func testLayoutQualityPassesDefaultController() {
        let report = GamepadCustomization.defaultValue.layoutQualityReport(
            profileName: "Default",
            canvasSize: CGSize(width: 874, height: 402)
        )
        expect(!report.hasErrors, "default controller layout should not have blocking layout errors")
    }

    private static func testLayoutQualityDetectsBadOverlaps() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000602")!
        var customization = GamepadCustomization.blankCanvas
        let badLayout = GamepadButtonCustomization(
            centerX: 0.5,
            centerY: 0.5,
            widthScale: 2.4,
            heightScale: 2.4,
            shape: .circle
        )
        customization.customButtons = [
            GamepadCustomButton(id: firstID, mappedButton: .custom1, label: "One", layout: badLayout),
            GamepadCustomButton(id: secondID, mappedButton: .custom2, label: "Two", layout: badLayout)
        ]

        let report = customization.layoutQualityReport(
            profileName: "Bad",
            canvasSize: CGSize(width: 874, height: 402)
        )
        expect(report.hasErrors, "overlapping oversized controls should fail layout quality validation")
        expect(report.issues.contains { $0.code == "requested-overlap" || $0.code == "resolved-overlap" }, "bad layout should report overlap issues")
    }

    private static func testLayoutQualityDetectsUnderusedBottomSpace() {
        var customization = GamepadCustomization.blankCanvas
        customization.customButtons = GameButton.customSlots.enumerated().map { index, button in
            let row = index / 4
            let column = index % 4
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", 0x700 + index))!
            let layout = GamepadButtonCustomization(
                centerX: 0.18 + CGFloat(column) * 0.21,
                centerY: row == 0 ? 0.14 : 0.34,
                widthScale: 0.55,
                heightScale: 0.55,
                shape: .roundedRectangle
            )
            return GamepadCustomButton(id: id, mappedButton: button, label: "Button \(index + 1)", layout: layout)
        }

        let report = customization.layoutQualityReport(
            profileName: "Top Heavy",
            canvasSize: CGSize(width: 874, height: 402)
        )
        expect(report.issues.contains { $0.code == "underused-bottom-space" }, "top-heavy layouts should warn about unused bottom space")
    }

    private static func customButton(id: UUID, center: CGPoint) -> GamepadCustomButton {
        GamepadCustomButton(
            id: id,
            mappedButton: .custom1,
            label: "Key",
            layout: GamepadButtonCustomization(
                centerX: center.x,
                centerY: center.y,
                widthScale: 1.0,
                heightScale: 1.0,
                shape: .rectangle
            )
        )
    }

    private static func controlsByID(_ controls: [GamepadResolvedControl]) -> [GamepadControlIdentity: GamepadResolvedControl] {
        Dictionary(uniqueKeysWithValues: controls.map { ($0.id, $0) })
    }

    private static func framesOverlap(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        lhs.minX < rhs.maxX
            && lhs.maxX > rhs.minX
            && lhs.minY < rhs.maxY
            && lhs.maxY > rhs.minY
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else { fail(message) }
    }

    private static func expectAlmostEqual(_ actual: CGFloat, _ expected: CGFloat, _ message: String, tolerance: CGFloat = 0.001) {
        guard abs(actual - expected) <= tolerance else {
            fail("\(message). Expected \(expected), got \(actual)")
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("GamepadLayoutResolverSmokeTests failed: \(message)\n", stderr)
        exit(1)
    }
}
