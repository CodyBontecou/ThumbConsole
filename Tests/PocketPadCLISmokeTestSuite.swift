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
