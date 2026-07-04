import Foundation

#if !XCODEBUILD_TEST
@main
#endif
struct GamepadLayoutResolverSmokeTests {
    static func main() {
        testAdjacentControlsCanTouchWithoutBeingSeparated()
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
