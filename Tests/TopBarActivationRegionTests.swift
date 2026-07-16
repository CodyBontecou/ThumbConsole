import XCTest

final class TopBarActivationRegionTests: XCTestCase {
    func testDefaultActivationRegionMatchesCompactRevealHandle() {
        let customization = GamepadCustomization.defaultValue

        for canvasSize in [
            CGSize(width: 390, height: 844),
            CGSize(width: 844, height: 390)
        ] {
            let frame = customization.topBarActivationFrame(in: canvasSize)
            XCTAssertEqual(frame.width, 60, accuracy: 0.001)
            XCTAssertEqual(frame.height, 44, accuracy: 0.001)
        }
    }

    func testActivationRegionCanStillBeIntentionallyEnlarged() {
        var customization = GamepadCustomization.defaultValue
        customization.topBarActivationRegion.widthScale = 1.5
        customization.topBarActivationRegion.heightScale = 2

        let frame = customization.topBarActivationFrame(in: CGSize(width: 844, height: 390))
        XCTAssertEqual(frame.width, 90, accuracy: 0.001)
        XCTAssertEqual(frame.height, 88, accuracy: 0.001)
    }
}
