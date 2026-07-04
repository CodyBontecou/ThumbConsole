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
