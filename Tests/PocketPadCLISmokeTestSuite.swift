import XCTest

final class PocketPadCLISmokeTestSuite: XCTestCase {
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
