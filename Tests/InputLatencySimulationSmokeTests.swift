import Foundation

#if !XCODEBUILD_TEST
@main
#endif
struct InputLatencySimulationSmokeTests {
    static func main() {
        testV2CompactButtonRoundTrip()
        testV1CompactButtonCompatibility()
        testJSONInputFields()
        testPipelineCaptureFieldsRoundTrip()

        let current = ThumbConsoleInputLatencySimulator.run(
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

        let legacyBurst = ThumbConsoleInputLatencySimulator.run(
            pattern: .sameButtonBurst,
            mode: .legacyMainActor
        )
        let currentBurst = ThumbConsoleInputLatencySimulator.run(
            pattern: .sameButtonBurst,
            mode: .current
        )
        expect(
            legacyBurst.summary.p95Milliseconds > currentBurst.summary.p95Milliseconds + 16,
            "legacy main-actor model exposes burst input lag"
        )

        let recovery = ThumbConsoleInputLatencySimulator.run(
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

        let recoveryBurst = ThumbConsoleInputLatencySimulator.run(
            pattern: .udpRecoveryBurst,
            mode: .current
        )
        expect(
            recoveryBurst.summary.maxMilliseconds < 4,
            "UDP recovery burst stays below the strict action-game budget"
        )

        let heldRecovery = ThumbConsoleInputLatencySimulator.run(
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

        let verification = ThumbConsoleInputLatencySimulator.verifyCurrentPath()
        expect(
            verification.passed,
            "strict latency verification passes every current-path pattern"
        )

        print("Input latency simulation smoke tests passed")
    }

    private static func testV2CompactButtonRoundTrip() {
        let generation = UInt64.max - 10
        let sequence = UInt64.max - 20
        let pressIdentifier = UInt64.max - 30
        let data = ControllerWireCodec.encodeButton(
            .attack,
            state: .up,
            sequenceNumber: sequence,
            pressIdentifier: pressIdentifier,
            generation: generation
        )

        expect(data.count == 32, "v2 compact button has the fixed 32-byte layout")
        expect(data[2] == UInt8(ControllerWireCodec.currentInputProtocolVersion), "v2 compact button has the v2 version byte")

        let decoded = decode(data, "v2 compact button")
        expect(decoded.type == .button, "v2 compact button preserves type")
        expect(decoded.button == .attack, "v2 compact button preserves button")
        expect(decoded.state == .up, "v2 compact button preserves state")
        expect(decoded.inputProtocolVersion == 2, "v2 compact button preserves protocol version")
        expect(decoded.inputGeneration == generation, "v2 compact button preserves full generation")
        expect(decoded.inputSequence == sequence, "v2 compact button preserves full sequence")
        expect(decoded.pressIdentifier == pressIdentifier, "v2 compact button preserves full press identifier")
        expect(ControllerWireCodec.inputSequenceNumber(from: decoded) == sequence, "sequence helper prefers the explicit v2 sequence")
        expect(ControllerWireCodec.inputPressIdentifier(from: decoded) == pressIdentifier, "press helper prefers the explicit v2 identifier")
    }

    private static func testV1CompactButtonCompatibility() {
        let data = ControllerWireCodec.encodeButton(
            .dash,
            state: .down,
            sequenceNumber: 42,
            pressIdentifier: 1234
        )

        expect(data.count == 14, "v1 compact button remains 14 bytes")
        expect(data[2] == 1, "v1 compact button retains the v1 version byte")

        let decoded = decode(data, "v1 compact button")
        expect(decoded.button == .dash, "v1 compact button preserves button")
        expect(decoded.state == .down, "v1 compact button preserves state")
        expect(decoded.inputProtocolVersion == nil, "v1 compact button has no explicit protocol version")
        expect(ControllerWireCodec.inputSequenceNumber(from: decoded) == 42, "v1 compact sequence still decodes from timestamp packing")
        expect(ControllerWireCodec.inputPressIdentifier(from: decoded) == 1234, "v1 compact press identifier still decodes from timestamp packing")
    }

    private static func testJSONInputFields() {
        let encoder = JSONEncoder()
        let elementID = UUID(uuidString: "729B071A-B5BB-4A91-B2A7-F644C61E5920")!
        let element = ControllerMessage(
            type: .elementInput,
            elementID: elementID,
            elementPart: .joystickLeft,
            state: .down,
            inputProtocolVersion: 2,
            inputGeneration: 91,
            inputSequence: UInt64.max - 1,
            pressIdentifier: UInt64.max
        )
        let elementData = encode(element, using: encoder, "JSON element input")
        expect(elementData.first == 0x7B, "element input with v2 fields uses JSON")
        let decodedElement = decode(elementData, "JSON element input")
        expect(decodedElement.elementID == elementID, "JSON element input preserves element ID")
        expect(decodedElement.elementPart == .joystickLeft, "JSON element input preserves element part")
        expect(decodedElement.inputGeneration == 91, "JSON element input preserves generation")
        expect(decodedElement.inputSequence == UInt64.max - 1, "JSON element input preserves full sequence")
        expect(decodedElement.pressIdentifier == UInt64.max, "JSON element input preserves full press identifier")

        let release = ControllerMessage(
            type: .releaseAll,
            inputProtocolVersion: 2,
            inputGeneration: 92,
            inputSequence: UInt64.max,
            pressIdentifier: UInt64.max - 2
        )
        let releaseData = encode(release, using: encoder, "JSON release-all")
        expect(releaseData.first == 0x7B, "release-all with v2 fields uses JSON instead of lossy compact encoding")
        let decodedRelease = decode(releaseData, "JSON release-all")
        expect(decodedRelease.inputProtocolVersion == 2, "JSON release-all preserves protocol version")
        expect(decodedRelease.inputGeneration == 92, "JSON release-all preserves generation")
        expect(decodedRelease.inputSequence == UInt64.max, "JSON release-all preserves full sequence")
        expect(decodedRelease.pressIdentifier == UInt64.max - 2, "JSON release-all preserves full press identifier")

        let legacyJSON = Data(#"{"type":"button","button":"jump","state":"down","timestamp":1}"#.utf8)
        let decodedLegacyJSON = decode(legacyJSON, "legacy JSON button")
        expect(decodedLegacyJSON.inputProtocolVersion == nil, "legacy JSON remains decodable without v2 fields")
        expect(decodedLegacyJSON.inputGeneration == nil, "legacy JSON has no generation")
        expect(decodedLegacyJSON.inputSequence == nil, "legacy JSON has no explicit sequence")
        expect(decodedLegacyJSON.pressIdentifier == nil, "legacy JSON has no explicit press identifier")
    }

    private static func testPipelineCaptureFieldsRoundTrip() {
        let event = ThumbConsoleCaptureEvent(
            schemaVersion: 3,
            kind: "input_pipeline",
            source: "iPhone UDP",
            messageType: .elementInput,
            inputGeneration: 77,
            inputSequence: 88,
            decodeLatencyMS: 0.125,
            receiveToProcessedMS: 1.75,
            reorderWaitMS: 0.5,
            processingToCompletionMS: 1.125,
            bindingLookupMS: 0.025,
            outputInjectionMS: 0.75,
            postInjectionMS: 0.2,
            outputDeferred: false
        )
        do {
            let data = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(ThumbConsoleCaptureEvent.self, from: data)
            expect(decoded.inputGeneration == 77, "pipeline capture preserves generation")
            expect(decoded.inputSequence == 88, "pipeline capture preserves input sequence")
            expect(decoded.decodeLatencyMS == 0.125, "pipeline capture preserves decode timing")
            expect(decoded.receiveToProcessedMS == 1.75, "pipeline capture preserves processing timing")
            expect(decoded.reorderWaitMS == 0.5, "pipeline capture preserves reorder timing")
            expect(decoded.processingToCompletionMS == 1.125, "pipeline capture preserves input processing timing")
            expect(decoded.bindingLookupMS == 0.025, "pipeline capture preserves binding lookup timing")
            expect(decoded.outputInjectionMS == 0.75, "pipeline capture preserves output injection timing")
            expect(decoded.postInjectionMS == 0.2, "pipeline capture preserves post-injection timing")
            expect(decoded.outputDeferred == false, "pipeline capture preserves deferred-output state")

            let legacyData = Data(#"{"schemaVersion":2,"recordedAt":1,"kind":"input_pipeline","decodeLatencyMS":0.1}"#.utf8)
            let legacy = try JSONDecoder().decode(ThumbConsoleCaptureEvent.self, from: legacyData)
            expect(legacy.outputInjectionMS == nil, "legacy pipeline capture remains decodable without output stages")
            expect(legacy.outputDeferred == nil, "legacy pipeline capture has no deferred-output state")
        } catch {
            fputs("InputLatencySimulationSmokeTests failed: pipeline capture round trip: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func encode(
        _ message: ControllerMessage,
        using encoder: JSONEncoder,
        _ description: String
    ) -> Data {
        do {
            return try ControllerWireCodec.encode(message, using: encoder)
        } catch {
            fputs("InputLatencySimulationSmokeTests failed to encode \(description): \(error)\n", stderr)
            exit(1)
        }
    }

    private static func decode(_ data: Data, _ description: String) -> ControllerMessage {
        do {
            return try ControllerWireCodec.decode(data, using: JSONDecoder())
        } catch {
            fputs("InputLatencySimulationSmokeTests failed to decode \(description): \(error)\n", stderr)
            exit(1)
        }
    }

    private static func expect(_ condition: Bool, _ message: String) {
        guard condition else {
            fputs("InputLatencySimulationSmokeTests failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
