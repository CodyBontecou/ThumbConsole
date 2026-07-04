import Foundation

#if !XCODEBUILD_TEST
@main
#endif
struct InputLatencySimulationSmokeTests {
    static func main() {
        let current = PocketPadInputLatencySimulator.run(
            pattern: .hollowKnight,
            mode: .current
        )
        expect(
            current.summary.p95Milliseconds < 4,
            "current Hollow Knight p95 stays below 4 ms"
        )
        expect(
            current.summary.overSixteenMilliseconds == 0,
            "current Hollow Knight path has no frame-budget misses"
        )

        let legacyBurst = PocketPadInputLatencySimulator.run(
            pattern: .sameButtonBurst,
            mode: .legacyMainActor
        )
        let currentBurst = PocketPadInputLatencySimulator.run(
            pattern: .sameButtonBurst,
            mode: .current
        )
        expect(
            legacyBurst.summary.p95Milliseconds > currentBurst.summary.p95Milliseconds + 16,
            "legacy main-actor model exposes burst input lag"
        )

        let recovery = PocketPadInputLatencySimulator.run(
            pattern: .udpRecovery,
            mode: .current
        )
        expect(
            recovery.recoveredByMirrorFrames >= 2,
            "TCP mirror recovers dropped UDP frames"
        )
        expect(
            recovery.summary.overSixteenMilliseconds == 0,
            "UDP recovery stays within one frame"
        )
        expect(
            recovery.summary.maxMilliseconds < 4,
            "TCP mirror recovery stays below the strict action-game budget"
        )

        let recoveryBurst = PocketPadInputLatencySimulator.run(
            pattern: .udpRecoveryBurst,
            mode: .current
        )
        expect(
            recoveryBurst.summary.maxMilliseconds < 4,
            "UDP recovery burst stays below the strict action-game budget"
        )

        let heldRecovery = PocketPadInputLatencySimulator.run(
            pattern: .heldDirectionHeartbeatRecovery,
            mode: .current
        )
        expect(
            heldRecovery.heartbeatResyncFrames == 1,
            "held direction heartbeat recovery reasserts the active hold"
        )
        expect(
            heldRecovery.samples.contains {
                $0.button == .left && $0.state == .down && $0.heartbeatResync
            },
            "held direction heartbeat recovery emits a left down re-sync frame"
        )
        expect(
            heldRecovery.summary.maxMilliseconds < 4,
            "held direction heartbeat recovery stays below the strict action-game budget"
        )

        let verification = PocketPadInputLatencySimulator.verifyCurrentPath()
        expect(
            verification.passed,
            "strict latency verification passes every current-path pattern"
        )

        print("Input latency simulation smoke tests passed")
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else {
            fputs("InputLatencySimulationSmokeTests failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
