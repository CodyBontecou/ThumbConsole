import CoreGraphics
import XCTest

final class IOSLocalKeypadUXTests: XCTestCase {
    func testPracticeModeSuppressesEveryInputPath() {
        for path in ControllerInputPath.allCases {
            XCTAssertTrue(
                ControllerInputSuppressionPolicy.permitsOutgoingInput(
                    path,
                    isConnected: true,
                    isPracticeModeEnabled: false
                ),
                "Expected live \(path.rawValue) to be permitted"
            )
            XCTAssertFalse(
                ControllerInputSuppressionPolicy.permitsOutgoingInput(
                    path,
                    isConnected: true,
                    isPracticeModeEnabled: true
                ),
                "Expected Practice Mode to suppress \(path.rawValue)"
            )
            XCTAssertFalse(
                ControllerInputSuppressionPolicy.permitsOutgoingInput(
                    path,
                    isConnected: false,
                    isPracticeModeEnabled: false
                ),
                "Expected offline \(path.rawValue) to be suppressed"
            )
        }
    }

    func testGlobalHapticScalingClampsAndPreservesRelativeStrength() {
        XCTAssertEqual(KeypadHapticIntensityPolicy.scaledIntensity(0.8, globalIntensity: 0.5), 0.4, accuracy: 0.0001)
        XCTAssertEqual(KeypadHapticIntensityPolicy.scaledIntensity(0.4, globalIntensity: 0.5), 0.2, accuracy: 0.0001)
        XCTAssertEqual(KeypadHapticIntensityPolicy.scaledIntensity(2, globalIntensity: 2), 1, accuracy: 0.0001)
        XCTAssertEqual(KeypadHapticIntensityPolicy.scaledIntensity(0.8, globalIntensity: -1), 0, accuracy: 0.0001)
        XCTAssertEqual(KeypadHapticIntensityPolicy.normalized(.nan), 1)
    }

    func testCalibrationPointsAndReachZonesNormalize() throws {
        let points = [
            ThumbPlacementNormalizedPoint(x: -2, y: 0.4),
            ThumbPlacementNormalizedPoint(x: 0.4, y: 2)
        ]
        XCTAssertEqual(points[0].x, 0)
        XCTAssertEqual(points[1].y, 1)

        let zone = try XCTUnwrap(ThumbPlacementReachZone(hand: .left, samples: points))
        XCTAssertEqual(zone.center.x, 0.2, accuracy: 0.0001)
        XCTAssertEqual(zone.center.y, 0.7, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(zone.radiusX, 0.12)
        XCTAssertGreaterThanOrEqual(zone.radiusY, 0.14)
    }

    func testCalibrationScoringFindsReachSafeAreaSizeAndRuntimeOverlapSuggestions() {
        let canvas = CGSize(width: 400, height: 800)
        let zone = ThumbPlacementReachZone(
            hand: .left,
            center: .init(x: 0.25, y: 0.72),
            radiusX: 0.18,
            radiusY: 0.22
        )
        let controls = [
            ThumbPlacementControlGeometry(
                id: "good",
                label: "Good",
                visualFrame: CGRect(x: 70, y: 550, width: 50, height: 50),
                runtimeHitFrame: CGRect(x: 60, y: 540, width: 70, height: 70)
            ),
            ThumbPlacementControlGeometry(
                id: "bad",
                label: "Bad",
                visualFrame: CGRect(x: 374, y: 4, width: 30, height: 30),
                runtimeHitFrame: CGRect(x: 350, y: 0, width: 70, height: 70)
            ),
            ThumbPlacementControlGeometry(
                id: "overlap",
                label: "Overlap",
                visualFrame: CGRect(x: 365, y: 20, width: 44, height: 44),
                runtimeHitFrame: CGRect(x: 355, y: 10, width: 64, height: 64)
            )
        ]

        let report = ThumbPlacementScorer.score(
            controls: controls,
            zones: [zone],
            canvasSize: canvas,
            safeArea: CGRect(x: 20, y: 40, width: 360, height: 720)
        )

        XCTAssertEqual(report.controls.first(where: { $0.id == "good" })?.score, 100)
        XCTAssertLessThan(report.controls.first(where: { $0.id == "bad" })?.score ?? 100, 50)
        XCTAssertEqual(
            Set(report.suggestions),
            Set([.moveIntoReach, .moveInsideSafeArea, .minimumTouchTarget, .separateRuntimeHitTargets])
        )
    }

    func testCalibrationPersistenceKeyIncludesEveryIdentityDimension() throws {
        let suiteName = "IOSLocalKeypadUXTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profileID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let key = ThumbPlacementCalibrationKey(
            profileID: profileID,
            deviceIdentity: "phone/device",
            displayIdentity: "1179x2556@3",
            orientation: .landscape
        )

        XCTAssertTrue(key.storageKey.contains(profileID.uuidString.lowercased()))
        XCTAssertTrue(key.storageKey.contains("phone_device"))
        XCTAssertTrue(key.storageKey.contains("1179x2556_3"))
        XCTAssertTrue(key.storageKey.hasSuffix("landscape"))

        let calibration = ThumbPlacementCalibration(
            key: key,
            leftSamples: [.init(x: 0.2, y: 0.8)]
        )
        let store = ThumbPlacementCalibrationStore(defaults: defaults)
        store.save(calibration)
        XCTAssertEqual(store.load(for: key), calibration)

        let otherOrientation = ThumbPlacementCalibrationKey(
            profileID: profileID,
            deviceIdentity: "phone/device",
            displayIdentity: "1179x2556@3",
            orientation: .portrait
        )
        XCTAssertNotEqual(key.storageKey, otherOrientation.storageKey)
        XCTAssertNil(store.load(for: otherOrientation))
    }
}
