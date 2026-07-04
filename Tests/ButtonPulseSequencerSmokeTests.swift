import Foundation

#if !XCODEBUILD_TEST
@main
#endif
struct ButtonPulseSequencerSmokeTests {
    private static let minTap: UInt64 = 35_000_000
    private static let minGap: UInt64 = 20_000_000

    static func main() {
        testSingleFastTap()
        testRepeatedFastTapsProduceTwoPulses()
        testRawIOSFastTapEdgesRemainDistinctAtMac()
        testSecondFastTapCanBecomeHeldPress()
        testOverlappingTouchStartsQueueSecondPulse()
        testOverlappingTouchReleasedBeforeSyntheticPress()
        testIdentifiedQueuedTapReleasedBeforeActiveHoldEmitsSyntheticPulse()
        testIdentifiedInterruptedHoldReleaseCancelsResume()
        testResetClearsInterruptedHoldAndQueuedTapState()
        testBurstFastTapsProduceEveryPulse()
        testEightFastTapsBeforeFirstReleaseProduceEveryPulse()
        testActionGameTimingKeepsQueuedBurstLowLatency()
        testIdentifiedMixedStressSequenceKeepsEveryPressVisible()
        testTapDuringPendingPressQueuesAnotherPulse()
        testHeldPressDuringPendingPressStartsAfterQueuedPulse()
        testHeldPressBeforeFirstReleaseDoesNotStealOlderQueuedTap()
        testMissingReleaseRecoveryProducesSeparatePulse()
        testMissingReleaseRecoveryWhileReleasePendingProducesPulse()
        testIdentifiedMissingReleaseRecoveryPreservesUnrelatedHeldPress()
        testMissingPressRecoveryProducesPulse()
        testMissingPressRecoveryWhileReleasePendingProducesQueuedPulse()
        testIdentifiedMissingPressRecoveryWhileOtherHoldActiveProducesTap()
        testButtonSequenceTrackerAcceptsInOrderRapidEdges()
        testButtonSequenceTrackerReportsInitialGap()
        testButtonSequenceTrackerReportsMidstreamGap()
        testButtonSequenceTrackerTreatsOlderSequenceAsReset()
        testButtonSequenceTrackerCanRebaseAfterReleaseAll()
        testCompactButtonSequenceRoundTrip()
        testCompactButtonPressIdentifierRoundTrip()
        print("ButtonPulseSequencer smoke tests passed")
    }

    private static func testSingleFastTap() {
        var sequencer = makeSequencer()

        expect(
            sequencer.setButton(.jump, pressed: true, now: 0),
            [.send(.jump, .down)],
            "single fast tap down"
        )
        expect(
            sequencer.setButton(.jump, pressed: false, now: 5_000_000),
            [.scheduleRelease(.jump, delayNanoseconds: 30_000_000)],
            "single fast tap schedules minimum hold"
        )
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap),
            [.send(.jump, .up)],
            "single fast tap releases after minimum hold"
        )
    }

    private static func testRepeatedFastTapsProduceTwoPulses() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.attack, pressed: true, now: 0)
        _ = sequencer.setButton(.attack, pressed: false, now: 5_000_000)
        expect(
            sequencer.setButton(.attack, pressed: true, now: 10_000_000),
            [],
            "second fast tap queues while first release is pending"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, now: 15_000_000),
            [],
            "second fast tap release waits for queued pulse"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "first fast tap releases and schedules second pulse"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [
                .send(.attack, .down),
                .scheduleRelease(.attack, delayNanoseconds: minTap)
            ],
            "second fast tap emits a separate down pulse"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap + minGap + minTap),
            [.send(.attack, .up)],
            "second fast tap releases after its own minimum hold"
        )
    }

    private static func testRawIOSFastTapEdgesRemainDistinctAtMac() {
        var sequencer = makeSequencer()

        expect(
            sequencer.setButton(.jump, pressed: true, now: 0),
            [.send(.jump, .down)],
            "raw iOS first down reaches Mac immediately"
        )
        expect(
            sequencer.setButton(.jump, pressed: false, now: 4_000_000),
            [.scheduleRelease(.jump, delayNanoseconds: 31_000_000)],
            "raw iOS first fast up is held long enough for the game"
        )
        expect(
            sequencer.setButton(.jump, pressed: true, now: 8_000_000),
            [],
            "raw iOS in-order second down queues while first pulse is still held"
        )
        expect(
            sequencer.setButton(.jump, pressed: false, now: 12_000_000),
            [],
            "raw iOS second fast up remains queued"
        )
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap),
            [
                .send(.jump, .up),
                .schedulePress(.jump, delayNanoseconds: minGap)
            ],
            "Mac releases first raw iOS tap and schedules the second"
        )
        expect(
            sequencer.pressTimerFired(for: .jump, now: minTap + minGap),
            [
                .send(.jump, .down),
                .scheduleRelease(.jump, delayNanoseconds: minTap)
            ],
            "Mac emits a separate down for the second raw iOS tap"
        )
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap + minGap + minTap),
            [.send(.jump, .up)],
            "Mac releases the second raw iOS tap"
        )
    }

    private static func testSecondFastTapCanBecomeHeldPress() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.dash, pressed: true, now: 0)
        _ = sequencer.setButton(.dash, pressed: false, now: 5_000_000)
        _ = sequencer.setButton(.dash, pressed: true, now: 10_000_000)
        expect(
            sequencer.releaseTimerFired(for: .dash, now: minTap),
            [
                .send(.dash, .up),
                .schedulePress(.dash, delayNanoseconds: minGap)
            ],
            "held second tap waits for first pulse to end"
        )
        expect(
            sequencer.pressTimerFired(for: .dash, now: minTap + minGap),
            [.send(.dash, .down)],
            "held second tap starts without scheduling synthetic release"
        )
        expect(
            sequencer.setButton(.dash, pressed: false, now: minTap + minGap + minTap),
            [.send(.dash, .up)],
            "held second tap releases on physical up"
        )
    }

    private static func testOverlappingTouchStartsQueueSecondPulse() {
        var sequencer = makeSequencer()

        expect(
            sequencer.setButton(.attack, pressed: true, now: 0),
            [.send(.attack, .down)],
            "first overlapping touch starts the first pulse"
        )
        expect(
            sequencer.setButton(.attack, pressed: true, now: 10_000_000),
            [.scheduleRelease(.attack, delayNanoseconds: 25_000_000)],
            "second overlapping touch queues another pulse and ends the first"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, now: 12_000_000),
            [],
            "lifting the first overlapping touch keeps the second physically active"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "first overlapping pulse releases before the second starts"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [.send(.attack, .down)],
            "second overlapping touch becomes the active held pulse"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, now: minTap + minGap + 15_000_000),
            [.scheduleRelease(.attack, delayNanoseconds: 20_000_000)],
            "second overlapping touch release still respects minimum tap time"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap + minGap + minTap),
            [.send(.attack, .up)],
            "second overlapping pulse releases cleanly"
        )
    }

    private static func testOverlappingTouchReleasedBeforeSyntheticPress() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.jump, pressed: true, now: 0)
        _ = sequencer.setButton(.jump, pressed: true, now: 8_000_000)
        _ = sequencer.setButton(.jump, pressed: false, now: 10_000_000)
        _ = sequencer.setButton(.jump, pressed: false, now: 12_000_000)
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap),
            [
                .send(.jump, .up),
                .schedulePress(.jump, delayNanoseconds: minGap)
            ],
            "overlapping quick tap schedules a synthetic second down"
        )
        expect(
            sequencer.pressTimerFired(for: .jump, now: minTap + minGap),
            [
                .send(.jump, .down),
                .scheduleRelease(.jump, delayNanoseconds: minTap)
            ],
            "released overlapping touch still produces its own minimum pulse"
        )
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap + minGap + minTap),
            [.send(.jump, .up)],
            "released overlapping synthetic pulse finishes"
        )
    }

    private static func testIdentifiedQueuedTapReleasedBeforeActiveHoldEmitsSyntheticPulse() {
        var sequencer = makeSequencer()

        expect(
            sequencer.setButton(.attack, pressed: true, pressIdentifier: 101, now: 0),
            [.send(.attack, .down)],
            "identified active touch starts first pulse"
        )
        expect(
            sequencer.setButton(.attack, pressed: true, pressIdentifier: 202, now: 8_000_000),
            [.scheduleRelease(.attack, delayNanoseconds: 27_000_000)],
            "identified second touch queues another same-button pulse"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, pressIdentifier: 202, now: 12_000_000),
            [],
            "identified second touch release clears the queued hold, not the active hold"
        )
        expectEqual(
            sequencer.hasPhysicalPress(.attack),
            true,
            "identified active touch remains physically held after queued touch releases"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "identified first pulse releases and schedules released queued tap"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [
                .send(.attack, .down),
                .scheduleRelease(.attack, delayNanoseconds: minTap)
            ],
            "identified released queued tap becomes a synthetic pulse"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap * 2 + minGap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "identified synthetic queued tap releases and schedules original hold resume"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap * 2 + minGap * 2),
            [.send(.attack, .down)],
            "identified original hold resumes after queued tap"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, pressIdentifier: 101, now: minTap * 2 + minGap * 2 + minTap),
            [.send(.attack, .up)],
            "identified resumed hold releases normally"
        )
    }

    private static func testIdentifiedInterruptedHoldReleaseCancelsResume() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.attack, pressed: true, pressIdentifier: 101, now: 0)
        _ = sequencer.setButton(.attack, pressed: true, pressIdentifier: 202, now: 8_000_000)
        _ = sequencer.setButton(.attack, pressed: false, pressIdentifier: 202, now: 12_000_000)
        expect(
            sequencer.setButton(.attack, pressed: false, pressIdentifier: 101, now: 14_000_000),
            [],
            "identified interrupted hold release waits for scheduled game-visible up"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "identified first pulse releases and schedules queued tap without a hold resume"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [
                .send(.attack, .down),
                .scheduleRelease(.attack, delayNanoseconds: minTap)
            ],
            "identified released queued tap still emits"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap * 2 + minGap),
            [.send(.attack, .up)],
            "identified interrupted hold does not emit a phantom resume"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap * 2 + minGap * 2),
            [],
            "identified interrupted hold leaves no hidden queued resume"
        )
    }

    private static func testResetClearsInterruptedHoldAndQueuedTapState() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.attack, pressed: true, pressIdentifier: 101, now: 0)
        _ = sequencer.setButton(.attack, pressed: true, pressIdentifier: 202, now: 8_000_000)
        expectEqual(
            sequencer.hasPhysicalPress(.attack),
            true,
            "reset setup has active physical press"
        )

        sequencer.reset()

        expectEqual(
            sequencer.hasPhysicalPress(.attack),
            false,
            "reset clears physical press state"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [],
            "reset cancels pending release state"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [],
            "reset cancels queued press state"
        )
        expect(
            sequencer.setButton(.attack, pressed: true, pressIdentifier: 303, now: minTap + minGap),
            [.send(.attack, .down)],
            "reset allows next tap to start cleanly"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, pressIdentifier: 303, now: minTap * 2 + minGap),
            [.send(.attack, .up)],
            "reset allows next tap to release cleanly"
        )
    }

    private static func testBurstFastTapsProduceEveryPulse() {
        var sequencer = makeSequencer()

        expect(
            sequencer.setButton(.attack, pressed: true, now: 0),
            [.send(.attack, .down)],
            "burst first tap starts immediately"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, now: 5_000_000),
            [.scheduleRelease(.attack, delayNanoseconds: 30_000_000)],
            "burst first tap schedules release"
        )
        expect(
            sequencer.setButton(.attack, pressed: true, now: 10_000_000),
            [],
            "burst second tap queues during first hold"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, now: 15_000_000),
            [],
            "burst second tap release waits"
        )
        expect(
            sequencer.setButton(.attack, pressed: true, now: 20_000_000),
            [],
            "burst third tap queues during first hold"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, now: 25_000_000),
            [],
            "burst third tap release waits"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "burst first pulse releases and schedules second"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [
                .send(.attack, .down),
                .scheduleRelease(.attack, delayNanoseconds: minTap)
            ],
            "burst second pulse starts"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap * 2 + minGap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "burst second pulse releases and schedules third"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap * 2 + minGap * 2),
            [
                .send(.attack, .down),
                .scheduleRelease(.attack, delayNanoseconds: minTap)
            ],
            "burst third pulse starts"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap * 3 + minGap * 2),
            [.send(.attack, .up)],
            "burst third pulse releases"
        )
    }

    private static func testTapDuringPendingPressQueuesAnotherPulse() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.jump, pressed: true, now: 0)
        _ = sequencer.setButton(.jump, pressed: false, now: 5_000_000)
        _ = sequencer.setButton(.jump, pressed: true, now: 10_000_000)
        _ = sequencer.setButton(.jump, pressed: false, now: 15_000_000)
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap),
            [
                .send(.jump, .up),
                .schedulePress(.jump, delayNanoseconds: minGap)
            ],
            "pending press schedules the second pulse"
        )
        expect(
            sequencer.setButton(.jump, pressed: true, now: minTap + 5_000_000),
            [],
            "tap during pending press queues a third pulse"
        )
        expect(
            sequencer.setButton(.jump, pressed: false, now: minTap + 10_000_000),
            [],
            "tap during pending press release waits"
        )
        expect(
            sequencer.pressTimerFired(for: .jump, now: minTap + minGap),
            [
                .send(.jump, .down),
                .scheduleRelease(.jump, delayNanoseconds: minTap)
            ],
            "pending second pulse still emits"
        )
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap * 2 + minGap),
            [
                .send(.jump, .up),
                .schedulePress(.jump, delayNanoseconds: minGap)
            ],
            "queued third pulse is not lost"
        )
        expect(
            sequencer.pressTimerFired(for: .jump, now: minTap * 2 + minGap * 2),
            [
                .send(.jump, .down),
                .scheduleRelease(.jump, delayNanoseconds: minTap)
            ],
            "queued third pulse starts"
        )
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap * 3 + minGap * 2),
            [.send(.jump, .up)],
            "queued third pulse releases"
        )
    }

    private static func testEightFastTapsBeforeFirstReleaseProduceEveryPulse() {
        var sequencer = makeSequencer()
        var sentDownCount = 0
        var sentUpCount = 0

        for tapIndex in 0..<8 {
            let tapStart = UInt64(tapIndex) * 4_000_000
            countSends(
                sequencer.setButton(.attack, pressed: true, now: tapStart),
                sentDownCount: &sentDownCount,
                sentUpCount: &sentUpCount
            )
            countSends(
                sequencer.setButton(.attack, pressed: false, now: tapStart + 2_000_000),
                sentDownCount: &sentDownCount,
                sentUpCount: &sentUpCount
            )
        }

        var releaseTime = minTap
        countSends(
            sequencer.releaseTimerFired(for: .attack, now: releaseTime),
            sentDownCount: &sentDownCount,
            sentUpCount: &sentUpCount
        )

        for _ in 1..<8 {
            let pressTime = releaseTime + minGap
            countSends(
                sequencer.pressTimerFired(for: .attack, now: pressTime),
                sentDownCount: &sentDownCount,
                sentUpCount: &sentUpCount
            )

            releaseTime = pressTime + minTap
            countSends(
                sequencer.releaseTimerFired(for: .attack, now: releaseTime),
                sentDownCount: &sentDownCount,
                sentUpCount: &sentUpCount
            )
        }

        expectEqual(sentDownCount, 8, "eight-tap burst emits every down")
        expectEqual(sentUpCount, 8, "eight-tap burst emits every up")
        expect(
            sequencer.pressTimerFired(for: .attack, now: releaseTime + minGap),
            [],
            "eight-tap burst leaves no hidden queued pulse"
        )
    }

    private static func testActionGameTimingKeepsQueuedBurstLowLatency() {
        let tapDuration = ButtonPulseSequencer.actionGameMinimumTapDurationNanoseconds
        let gapDuration = ButtonPulseSequencer.actionGameMinimumInterTapGapNanoseconds
        var sequencer = ButtonPulseSequencer(
            minimumTapDurationNanoseconds: tapDuration,
            minimumInterTapGapNanoseconds: gapDuration
        )
        var sentDownCount = 0
        var sentUpCount = 0

        for tapIndex in 0..<4 {
            let tapStart = UInt64(tapIndex) * 4_000_000
            countSends(
                sequencer.setButton(.attack, pressed: true, pressIdentifier: UInt64(tapIndex + 1), now: tapStart),
                sentDownCount: &sentDownCount,
                sentUpCount: &sentUpCount
            )
            countSends(
                sequencer.setButton(.attack, pressed: false, pressIdentifier: UInt64(tapIndex + 1), now: tapStart + 2_000_000),
                sentDownCount: &sentDownCount,
                sentUpCount: &sentUpCount
            )
        }

        var releaseTime = tapDuration
        countSends(
            sequencer.releaseTimerFired(for: .attack, now: releaseTime),
            sentDownCount: &sentDownCount,
            sentUpCount: &sentUpCount
        )

        for _ in 1..<4 {
            let pressTime = releaseTime + gapDuration
            countSends(
                sequencer.pressTimerFired(for: .attack, now: pressTime),
                sentDownCount: &sentDownCount,
                sentUpCount: &sentUpCount
            )

            releaseTime = pressTime + tapDuration
            countSends(
                sequencer.releaseTimerFired(for: .attack, now: releaseTime),
                sentDownCount: &sentDownCount,
                sentUpCount: &sentUpCount
            )
        }

        expectEqual(sentDownCount, 4, "action-game timing emits every burst down")
        expectEqual(sentUpCount, 4, "action-game timing emits every burst up")
        guard releaseTime <= 150_000_000 else {
            fatalError("action-game timing queued burst took too long: \(releaseTime)ns")
        }
    }

    private static func testIdentifiedMixedStressSequenceKeepsEveryPressVisible() {
        var sequencer = makeSequencer()
        var pendingReleaseTime: UInt64?
        var pendingPressTime: UInt64?
        var sentDownCount = 0
        var sentUpCount = 0
        var physicalPressCount = 0

        func handle(_ commands: [ButtonPulseCommand], now: UInt64) {
            for command in commands {
                switch command {
                case .send(_, .down):
                    sentDownCount += 1
                case .send(_, .up):
                    sentUpCount += 1
                case .scheduleRelease(_, let delayNanoseconds):
                    pendingReleaseTime = now + delayNanoseconds
                case .schedulePress(_, let delayNanoseconds):
                    pendingPressTime = now + delayNanoseconds
                }
            }
        }

        func fireDueTimers(until limit: UInt64) {
            while true {
                let nextReleaseTime = pendingReleaseTime
                let nextPressTime = pendingPressTime
                let nextTime: UInt64
                let firesRelease: Bool

                switch (nextReleaseTime, nextPressTime) {
                case (.none, .none):
                    return
                case (.some(let releaseTime), .none):
                    nextTime = releaseTime
                    firesRelease = true
                case (.none, .some(let pressTime)):
                    nextTime = pressTime
                    firesRelease = false
                case (.some(let releaseTime), .some(let pressTime)):
                    if releaseTime <= pressTime {
                        nextTime = releaseTime
                        firesRelease = true
                    } else {
                        nextTime = pressTime
                        firesRelease = false
                    }
                }

                guard nextTime <= limit else { return }

                if firesRelease {
                    pendingReleaseTime = nil
                    handle(sequencer.releaseTimerFired(for: .attack, now: nextTime), now: nextTime)
                } else {
                    pendingPressTime = nil
                    handle(sequencer.pressTimerFired(for: .attack, now: nextTime), now: nextTime)
                }
            }
        }

        let events: [(time: UInt64, identifier: UInt64, pressed: Bool)] = [
            (0, 1, true),
            (3_000_000, 1, false),
            (6_000_000, 2, true),
            (9_000_000, 2, false),
            (12_000_000, 3, true),
            (16_000_000, 4, true),
            (20_000_000, 4, false),
            (24_000_000, 5, true),
            (27_000_000, 5, false),
            (70_000_000, 3, false),
            (73_000_000, 6, true),
            (75_000_000, 6, false),
            (80_000_000, 7, true),
            (120_000_000, 8, true),
            (122_000_000, 8, false),
            (160_000_000, 7, false)
        ]

        for event in events {
            fireDueTimers(until: event.time)
            if event.pressed {
                physicalPressCount += 1
            }
            handle(
                sequencer.setButton(
                    .attack,
                    pressed: event.pressed,
                    pressIdentifier: event.identifier,
                    now: event.time
                ),
                now: event.time
            )
        }

        for _ in 0..<64 {
            guard let nextTime = [pendingReleaseTime, pendingPressTime].compactMap({ $0 }).min() else {
                break
            }
            fireDueTimers(until: nextTime)
        }

        expectEqual(pendingReleaseTime, nil, "mixed stress drains pending release timer")
        expectEqual(pendingPressTime, nil, "mixed stress drains pending press timer")
        expectEqual(sequencer.hasPhysicalPress(.attack), false, "mixed stress ends without physical holds")
        expectEqual(sentDownCount, sentUpCount, "mixed stress emits balanced visible down/up pulses")
        guard sentDownCount >= physicalPressCount else {
            fatalError("mixed stress dropped visible presses. Expected at least \(physicalPressCount), got \(sentDownCount)")
        }
    }

    private static func testHeldPressDuringPendingPressStartsAfterQueuedPulse() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.jump, pressed: true, now: 0)
        _ = sequencer.setButton(.jump, pressed: false, now: 5_000_000)
        _ = sequencer.setButton(.jump, pressed: true, now: 10_000_000)
        _ = sequencer.setButton(.jump, pressed: false, now: 15_000_000)
        _ = sequencer.releaseTimerFired(for: .jump, now: minTap)
        expect(
            sequencer.setButton(.jump, pressed: true, now: minTap + 5_000_000),
            [],
            "held press during pending press queues behind already scheduled pulse"
        )
        expect(
            sequencer.pressTimerFired(for: .jump, now: minTap + minGap),
            [
                .send(.jump, .down),
                .scheduleRelease(.jump, delayNanoseconds: minTap)
            ],
            "already scheduled pulse stays synthetic despite later held press"
        )
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap * 2 + minGap),
            [
                .send(.jump, .up),
                .schedulePress(.jump, delayNanoseconds: minGap)
            ],
            "held press gets its own queued pulse after synthetic pulse releases"
        )
        expect(
            sequencer.pressTimerFired(for: .jump, now: minTap * 2 + minGap * 2),
            [.send(.jump, .down)],
            "held press starts as separate held pulse"
        )
        expect(
            sequencer.setButton(.jump, pressed: false, now: minTap * 2 + minGap * 2 + minTap),
            [.send(.jump, .up)],
            "held press releases normally after its own pulse"
        )
    }

    private static func testHeldPressBeforeFirstReleaseDoesNotStealOlderQueuedTap() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.jump, pressed: true, now: 0)
        _ = sequencer.setButton(.jump, pressed: false, now: 5_000_000)
        _ = sequencer.setButton(.jump, pressed: true, now: 10_000_000)
        _ = sequencer.setButton(.jump, pressed: false, now: 15_000_000)
        _ = sequencer.setButton(.jump, pressed: true, now: 20_000_000)
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap),
            [
                .send(.jump, .up),
                .schedulePress(.jump, delayNanoseconds: minGap)
            ],
            "first pulse release schedules the older queued tap first"
        )
        expect(
            sequencer.pressTimerFired(for: .jump, now: minTap + minGap),
            [
                .send(.jump, .down),
                .scheduleRelease(.jump, delayNanoseconds: minTap)
            ],
            "older queued tap remains synthetic despite the newer held press"
        )
        expect(
            sequencer.releaseTimerFired(for: .jump, now: minTap * 2 + minGap),
            [
                .send(.jump, .up),
                .schedulePress(.jump, delayNanoseconds: minGap)
            ],
            "newer held press waits behind the older queued tap"
        )
        expect(
            sequencer.pressTimerFired(for: .jump, now: minTap * 2 + minGap * 2),
            [.send(.jump, .down)],
            "newer held press starts as the next pulse"
        )
        expect(
            sequencer.setButton(.jump, pressed: false, now: minTap * 2 + minGap * 2 + minTap),
            [.send(.jump, .up)],
            "newer held press releases normally"
        )
    }

    private static func testMissingReleaseRecoveryProducesSeparatePulse() {
        var sequencer = makeSequencer()

        expect(
            sequencer.setButton(.attack, pressed: true, now: 0),
            [.send(.attack, .down)],
            "duplicate recovery first down starts immediately"
        )
        expect(
            sequencer.recoverMissingReleaseBeforePress(.attack, now: 15_000_000),
            [.scheduleRelease(.attack, delayNanoseconds: 20_000_000)],
            "missing release recovery schedules release instead of disappearing"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "missing release recovery releases first pulse and schedules replacement down"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [.send(.attack, .down)],
            "missing release recovery replacement down remains held while physically active"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, now: minTap + minGap + minTap),
            [.send(.attack, .up)],
            "missing release recovery held pulse releases normally"
        )
    }

    private static func testMissingReleaseRecoveryWhileReleasePendingProducesPulse() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.attack, pressed: true, now: 0)
        _ = sequencer.setButton(.attack, pressed: false, now: 5_000_000)
        expect(
            sequencer.recoverMissingReleaseBeforePress(.attack, now: 10_000_000),
            [],
            "missing release recovery queues while release timer is pending"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, now: 12_000_000),
            [],
            "missing release recovery quick release waits for pending release"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "missing release recovery pending release schedules replacement pulse"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [
                .send(.attack, .down),
                .scheduleRelease(.attack, delayNanoseconds: minTap)
            ],
            "missing release recovery pending release emits replacement down"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap + minGap + minTap),
            [.send(.attack, .up)],
            "missing release recovery pending release replacement pulse finishes"
        )
    }

    private static func testIdentifiedMissingReleaseRecoveryPreservesUnrelatedHeldPress() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.attack, pressed: true, pressIdentifier: 101, now: 0)
        expect(
            sequencer.recoverMissingReleaseBeforePress(.attack, pressIdentifier: 202, now: 8_000_000),
            [.scheduleRelease(.attack, delayNanoseconds: 27_000_000)],
            "identified missing release recovery interrupts active hold for new press"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "identified missing release recovery schedules new press first"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [.send(.attack, .down)],
            "identified recovered new press is held while physically active"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, pressIdentifier: 202, now: minTap + minGap + minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "identified recovered new press release schedules original hold resume"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap * 2 + minTap),
            [.send(.attack, .down)],
            "identified original hold resumes after recovered press"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, pressIdentifier: 101, now: minTap * 2 + minGap * 2 + minTap),
            [.send(.attack, .up)],
            "identified original hold releases after resume"
        )
    }

    private static func testMissingPressRecoveryProducesPulse() {
        var sequencer = makeSequencer()

        expectEqual(sequencer.hasPhysicalPress(.jump), false, "missing press starts without physical count")
        expect(
            sequencer.recoverMissingPressBeforeRelease(.jump, now: 12_000_000),
            [
                .send(.jump, .down),
                .scheduleRelease(.jump, delayNanoseconds: minTap)
            ],
            "missing press recovery synthesizes a game-visible tap"
        )
        expectEqual(sequencer.hasPhysicalPress(.jump), false, "missing press recovery does not leave a physical hold")
        expect(
            sequencer.releaseTimerFired(for: .jump, now: 12_000_000 + minTap),
            [.send(.jump, .up)],
            "missing press recovery releases the synthetic tap"
        )
    }

    private static func testMissingPressRecoveryWhileReleasePendingProducesQueuedPulse() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.attack, pressed: true, now: 0)
        _ = sequencer.setButton(.attack, pressed: false, now: 4_000_000)
        expectEqual(sequencer.hasPhysicalPress(.attack), false, "first fast tap is no longer physically held")
        expect(
            sequencer.recoverMissingPressBeforeRelease(.attack, now: 8_000_000),
            [],
            "missing press recovery queues while the prior release timer is pending"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "missing press recovery schedules a queued synthetic press"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [
                .send(.attack, .down),
                .scheduleRelease(.attack, delayNanoseconds: minTap)
            ],
            "missing press recovery queued pulse starts and schedules release"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap + minGap + minTap),
            [.send(.attack, .up)],
            "missing press recovery queued pulse releases"
        )
    }

    private static func testIdentifiedMissingPressRecoveryWhileOtherHoldActiveProducesTap() {
        var sequencer = makeSequencer()

        _ = sequencer.setButton(.attack, pressed: true, pressIdentifier: 101, now: 0)
        expectEqual(
            sequencer.hasPhysicalPress(.attack),
            true,
            "identified held press is active before missing tap recovery"
        )
        expectEqual(
            sequencer.hasPhysicalPress(.attack, pressIdentifier: 202),
            false,
            "missing tap identifier is not physically active yet"
        )
        expect(
            sequencer.recoverMissingPressBeforeRelease(.attack, pressIdentifier: 202, now: 8_000_000),
            [.scheduleRelease(.attack, delayNanoseconds: 27_000_000)],
            "identified missing tap recovery interrupts the unrelated active hold"
        )
        expect(
            sequencer.setButton(.attack, pressed: false, pressIdentifier: 101, now: 12_000_000),
            [],
            "identified unrelated hold release cancels its later resume"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap),
            [
                .send(.attack, .up),
                .schedulePress(.attack, delayNanoseconds: minGap)
            ],
            "identified unrelated hold releases and schedules recovered missing tap"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap + minGap),
            [
                .send(.attack, .down),
                .scheduleRelease(.attack, delayNanoseconds: minTap)
            ],
            "identified missing tap emits a synthetic down"
        )
        expect(
            sequencer.releaseTimerFired(for: .attack, now: minTap * 2 + minGap),
            [.send(.attack, .up)],
            "identified missing tap synthetic pulse releases"
        )
        expect(
            sequencer.pressTimerFired(for: .attack, now: minTap * 2 + minGap * 2),
            [],
            "identified unrelated released hold leaves no hidden resume"
        )
    }

    private static func testButtonSequenceTrackerAcceptsInOrderRapidEdges() {
        var tracker = ButtonSequenceTracker()

        expectEqual(
            tracker.inspect(buttonMessage(.jump, .down, sequenceNumber: 1)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: false,
                expectedSequence: nil,
                receivedSequence: 1,
                missedFrameCount: 0,
                totalMissedFrameCount: 0,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker first in-order edge"
        )
        expectEqual(
            tracker.inspect(buttonMessage(.jump, .up, sequenceNumber: 2)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: false,
                expectedSequence: nil,
                receivedSequence: 2,
                missedFrameCount: 0,
                totalMissedFrameCount: 0,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker second in-order edge"
        )
        expectEqual(
            tracker.inspect(buttonMessage(.jump, .down, sequenceNumber: 3)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: false,
                expectedSequence: nil,
                receivedSequence: 3,
                missedFrameCount: 0,
                totalMissedFrameCount: 0,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker in-order rapid duplicate down is not transport loss"
        )
    }

    private static func testButtonSequenceTrackerReportsInitialGap() {
        var tracker = ButtonSequenceTracker()

        expectEqual(
            tracker.inspect(buttonMessage(.attack, .up, sequenceNumber: 2)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: true,
                expectedSequence: 1,
                receivedSequence: 2,
                missedFrameCount: 1,
                totalMissedFrameCount: 1,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker reports first missing frame"
        )
    }

    private static func testButtonSequenceTrackerReportsMidstreamGap() {
        var tracker = ButtonSequenceTracker()
        _ = tracker.inspect(buttonMessage(.dash, .down, sequenceNumber: 1))

        expectEqual(
            tracker.inspect(buttonMessage(.dash, .up, sequenceNumber: 4)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: true,
                expectedSequence: 2,
                receivedSequence: 4,
                missedFrameCount: 2,
                totalMissedFrameCount: 2,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker reports midstream missing frames"
        )
        expectEqual(
            tracker.inspect(buttonMessage(.jump, .down, sequenceNumber: 6)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: true,
                expectedSequence: 5,
                receivedSequence: 6,
                missedFrameCount: 1,
                totalMissedFrameCount: 3,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker accumulates missing frame count"
        )
    }

    private static func testButtonSequenceTrackerTreatsOlderSequenceAsReset() {
        var tracker = ButtonSequenceTracker()
        _ = tracker.inspect(buttonMessage(.dash, .down, sequenceNumber: 4))

        expectEqual(
            tracker.inspect(buttonMessage(.dash, .up, sequenceNumber: 2)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: false,
                expectedSequence: 5,
                receivedSequence: 2,
                missedFrameCount: 0,
                totalMissedFrameCount: 3,
                isOutOfOrderOrReset: true
            ),
            "sequence tracker treats older sequence as reset instead of more loss"
        )
        expectEqual(
            tracker.inspect(buttonMessage(.dash, .up, sequenceNumber: 5)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: false,
                expectedSequence: nil,
                receivedSequence: 5,
                missedFrameCount: 0,
                totalMissedFrameCount: 3,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker keeps expected sequence after an older stale frame"
        )
    }

    private static func testButtonSequenceTrackerCanRebaseAfterReleaseAll() {
        var tracker = ButtonSequenceTracker()
        _ = tracker.inspect(buttonMessage(.jump, .down, sequenceNumber: 12))

        tracker.resetAcceptingNextSequenceAsBaseline()

        expectEqual(
            tracker.inspect(buttonMessage(.attack, .down, sequenceNumber: 40)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: false,
                expectedSequence: nil,
                receivedSequence: 40,
                missedFrameCount: 0,
                totalMissedFrameCount: 0,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker rebases first post-reset button without phantom loss"
        )
        expectEqual(
            tracker.inspect(buttonMessage(.attack, .up, sequenceNumber: 42)),
            ButtonSequenceInspection(
                hasSequence: true,
                missedFrameBeforeButton: true,
                expectedSequence: 41,
                receivedSequence: 42,
                missedFrameCount: 1,
                totalMissedFrameCount: 1,
                isOutOfOrderOrReset: false
            ),
            "sequence tracker resumes gap detection after post-reset baseline"
        )
    }

    private static func testCompactButtonSequenceRoundTrip() {
        let data = ControllerWireCodec.encodeButton(.dash, state: .down, sequenceNumber: 42)
        let decoded = tryOrFail(
            try ControllerWireCodec.decode(data, using: JSONDecoder()),
            "sequence button decode"
        )

        expectEqual(decoded.type, .button, "sequence button type")
        expectEqual(decoded.button, .dash, "sequence button")
        expectEqual(decoded.state, .down, "sequence state")
        expectEqual(
            ControllerWireCodec.buttonSequenceNumber(from: decoded),
            42,
            "sequence number round trip"
        )

        let unsequenced = tryOrFail(
            try ControllerWireCodec.decode(
                ControllerWireCodec.encodeButton(.dash, state: .up),
                using: JSONDecoder()
            ),
            "unsequenced button decode"
        )
        expectEqual(
            ControllerWireCodec.buttonSequenceNumber(from: unsequenced),
            nil,
            "unsequenced cached button has no sequence marker"
        )
        expectEqual(
            ControllerWireCodec.buttonPressIdentifier(from: unsequenced),
            nil,
            "unsequenced cached button has no press identifier"
        )
    }

    private static func testCompactButtonPressIdentifierRoundTrip() {
        let data = ControllerWireCodec.encodeButton(
            .attack,
            state: .up,
            sequenceNumber: 77,
            pressIdentifier: 1234
        )
        let decoded = tryOrFail(
            try ControllerWireCodec.decode(data, using: JSONDecoder()),
            "identified sequence button decode"
        )

        expectEqual(decoded.type, .button, "identified sequence button type")
        expectEqual(decoded.button, .attack, "identified sequence button")
        expectEqual(decoded.state, .up, "identified sequence state")
        expectEqual(
            ControllerWireCodec.buttonSequenceNumber(from: decoded),
            77,
            "identified sequence number round trip"
        )
        expectEqual(
            ControllerWireCodec.buttonPressIdentifier(from: decoded),
            1234,
            "press identifier round trip"
        )
    }

    private static func makeSequencer() -> ButtonPulseSequencer {
        ButtonPulseSequencer(
            minimumTapDurationNanoseconds: minTap,
            minimumInterTapGapNanoseconds: minGap
        )
    }

    private static func buttonMessage(
        _ button: GameButton,
        _ state: ButtonPressState,
        sequenceNumber: UInt64
    ) -> ControllerMessage {
        tryOrFail(
            try ControllerWireCodec.decode(
                ControllerWireCodec.encodeButton(button, state: state, sequenceNumber: sequenceNumber),
                using: JSONDecoder()
            ),
            "sequenced button message"
        )
    }

    private static func expect(
        _ actual: [ButtonPulseCommand],
        _ expected: [ButtonPulseCommand],
        _ message: String
    ) {
        guard actual == expected else {
            fatalError("\(message) failed. Expected \(expected), got \(actual)")
        }
    }

    private static func countSends(
        _ commands: [ButtonPulseCommand],
        sentDownCount: inout Int,
        sentUpCount: inout Int
    ) {
        for command in commands {
            switch command {
            case .send(_, .down):
                sentDownCount += 1
            case .send(_, .up):
                sentUpCount += 1
            case .schedulePress, .scheduleRelease:
                break
            }
        }
    }

    private static func tryOrFail<T>(_ expression: @autoclosure () throws -> T, _ message: String) -> T {
        do {
            return try expression()
        } catch {
            fatalError("\(message) failed with error: \(error)")
        }
    }

    private static func expectEqual<T: Equatable>(
        _ actual: T,
        _ expected: T,
        _ message: String
    ) {
        guard actual == expected else {
            fatalError("\(message) failed. Expected \(expected), got \(actual)")
        }
    }
}
