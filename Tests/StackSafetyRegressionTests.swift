import Darwin
import Foundation
import XCTest

final class StackSafetyRegressionTests: XCTestCase {
    private enum StackTestError: Error {
        case emptyEncodedPayload
        case escapedProfileKeyWasNotDecoded
        case missingDecodedProfile
        case unexpectedDecodedState
        case skinApplicationFailed
    }

    private final class ThreadResultBox: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Int, Error>?

        func store(_ result: Result<Int, Error>) {
            lock.lock()
            self.result = result
            lock.unlock()
        }

        func load() -> Result<Int, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return result
        }
    }

    func testFullProfileWireEncodingRunsFrom512KiBStack() throws {
        let (message, _) = makeFullProfileWireMessage()

        try runOnThread(stackSize: 512 * 1024) {
            let data = try ControllerWireCodec.encode(message, using: JSONEncoder())
            guard !data.isEmpty else { throw StackTestError.emptyEncodedPayload }
        }
    }

    func testFullProfileWireDecodingRunsFrom512KiBStack() throws {
        let (message, profile) = makeFullProfileWireMessage()
        let data = try ControllerWireCodec.encode(message, using: JSONEncoder())

        try runOnThread(stackSize: 512 * 1024) {
            let decoded = try ControllerWireCodec.decode(data, using: JSONDecoder())
            guard let decodedProfile = decoded.gamepadProfiles?.first else {
                throw StackTestError.missingDecodedProfile
            }
            guard decodedProfile.normalized == profile.normalized,
                  decoded.gamepadProfileID == profile.id,
                  decoded.defaultGamepadProfileID == profile.id
            else {
                throw StackTestError.unexpectedDecodedState
            }
        }
    }

    func testEscapedHeavyFieldNameUsesExpandedDecodeStack() throws {
        let canonical = try ControllerWireCodec.encode(
            ControllerMessage(type: .gamepadProfiles, gamepadProfiles: []),
            using: JSONEncoder()
        )
        let escapedJSON = String(decoding: canonical, as: UTF8.self).replacingOccurrences(
            of: "\"gamepadProfiles\"",
            with: "\"\\u0067amepadProfiles\""
        )
        let escaped = Data(escapedJSON.utf8)
        XCTAssertLessThan(escaped.count, 32 * 1024)
        XCTAssertTrue(ControllerWireCodec.requiresExpandedStackForDecoding(escaped))

        try runOnThread(stackSize: 512 * 1024) {
            let message = try ControllerWireCodec.decode(escaped, using: JSONDecoder())
            guard message.type == .gamepadProfiles, message.gamepadProfiles == [] else {
                throw StackTestError.escapedProfileKeyWasNotDecoded
            }
        }
    }

    func testWireDecoderRejectsOversizedPayloadBeforeParsing() {
        let data = Data(count: ControllerWireCodec.maximumInboundPayloadSize + 1)

        XCTAssertThrowsError(try ControllerWireCodec.decode(data, using: JSONDecoder())) { error in
            XCTAssertEqual(
                error as? ControllerWireCodecError,
                .inboundPayloadTooLarge(
                    actualBytes: data.count,
                    maximumBytes: ControllerWireCodec.maximumInboundPayloadSize
                )
            )
        }
    }

    func testPresentationComparisonRunsOn512KiBStack() throws {
        let lhs = makeRichCustomization()
        var updatedRHS = lhs
        updatedRHS.updatedAt = 999
        let rhs = updatedRHS

        try runOnThread(stackSize: 512 * 1024) {
            guard lhs.hasSamePresentation(as: rhs) else {
                throw StackTestError.unexpectedDecodedState
            }
            var changed = rhs
            changed.setLabel("Changed", for: .jump)
            guard !lhs.hasSamePresentation(as: changed) else {
                throw StackTestError.unexpectedDecodedState
            }
        }
    }

    func testProfileSkinApplicationRunsOnOneMiBStack() throws {
        let package = makeSkinPackage(shape: .capsule, version: "1.0.0")
        let updatedPackage = makeSkinPackage(shape: .circle, version: "2.0.0")
        let customization = makeRichCustomization()
        let profile = GamepadConfigurationProfile(
            name: "Skin Stack",
            customization: customization,
            landscapeCustomization: customization,
            portraitCustomization: customization
        )

        try runOnThread(stackSize: 1024 * 1024) {
            var applied = profile
            applied.applySkin(package)
            var jump = applied.customization.buttonCustomization(for: .jump)
            jump.shape = .rectangle
            applied.customization.setButtonCustomization(jump, for: .jump)
            applied.applySkin(updatedPackage)
            guard applied.skinReference?.version == "2.0.0",
                  applied.customization.buttonCustomization(for: .jump).shape == .rectangle,
                  applied.customization.buttonCustomization(for: .attack).shape == .circle,
                  applied.landscapeSkinBaselineCustomization != nil,
                  applied.portraitSkinBaselineCustomization != nil
            else {
                throw StackTestError.skinApplicationFailed
            }
        }
    }

    private func runOnThread(
        stackSize: Int,
        timeout: TimeInterval = 15,
        operation: @escaping @Sendable () throws -> Void
    ) throws {
        let completed = expectation(description: "constrained-stack operation")
        let resultBox = ThreadResultBox()
        let thread = Thread {
            do {
                let actualStackSize = pthread_get_stacksize_np(pthread_self())
                try operation()
                resultBox.store(.success(actualStackSize))
            } catch {
                resultBox.store(.failure(error))
            }
            completed.fulfill()
        }
        thread.stackSize = stackSize
        thread.start()
        wait(for: [completed], timeout: timeout)

        let result = try XCTUnwrap(resultBox.load())
        let actualStackSize = try result.get()
        XCTAssertGreaterThanOrEqual(actualStackSize, stackSize)
        XCTAssertLessThan(actualStackSize, stackSize + (64 * 1024))
    }

    private func makeFullProfileWireMessage() -> (ControllerMessage, GamepadConfigurationProfile) {
        let customization = makeRichCustomization()
        let profile = GamepadConfigurationProfile(
            name: "Stack-Safe Profile",
            customization: customization,
            landscapeCustomization: customization,
            portraitCustomization: customization,
            skinBaselineCustomization: customization,
            landscapeSkinBaselineCustomization: customization,
            portraitSkinBaselineCustomization: customization
        )
        let message = ControllerMessage(
            type: .gamepadProfiles,
            gamepadCustomization: customization,
            gamepadProfiles: [profile],
            gamepadProfileID: profile.id,
            defaultGamepadProfileID: profile.id
        )
        return (message, profile)
    }

    private func makeRichCustomization() -> GamepadCustomization {
        var customization = GamepadControllerTemplate.productivityStarter.makeProfile().customization.normalized
        let visualStyle = GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(
                fillStyle: .solid(GamepadRGBAColor(hexString: "#302A42") ?? .defaultValue),
                foregroundColor: GamepadRGBAColor(hexString: "#F7F4FF") ?? .defaultValue,
                strokeColor: GamepadRGBAColor(hexString: "#9277C8") ?? .defaultValue,
                strokeWidth: 1.5,
                shadowColor: GamepadRGBAColor(hexString: "#00000066") ?? .defaultValue,
                shadowRadius: 8
            ),
            pressed: GamepadControlStateStyle(opacity: 0.82, scale: 0.94)
        )
        for button in GameButton.builtInControls {
            var layout = customization.buttonCustomization(for: button)
            layout.visualStyle = visualStyle
            layout.hapticStyle = .medium
            customization.setButtonCustomization(layout, for: button)
        }
        var settingsAppearance = GamepadButtonCustomization.defaultValue
        settingsAppearance.visualStyle = visualStyle
        settingsAppearance.icon = .sfSymbol("slider.horizontal.3")
        customization.setControlBarItemCustomization(settingsAppearance, for: .settings)
        customization.setLabel("Primary Action", for: .jump)
        customization.updatedAt = 123
        return customization.normalized
    }

    private func makeSkinPackage(
        shape: GamepadButtonShapeStyle,
        version: String
    ) -> PocketPadSkinPackage {
        PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.stack-safety",
                version: version,
                name: "Stack Safety",
                author: PocketPadSkinAuthor(name: "Tests"),
                license: "MIT"
            ),
            skin: PocketPadSkin(
                base: PocketPadSkinAppearance(
                    defaultControl: PocketPadSkinControlAppearance(shape: shape)
                ),
                variants: [
                    PocketPadSkinVariant(
                        id: "portrait",
                        orientation: .portrait,
                        appearance: PocketPadSkinAppearance(
                            defaultControl: PocketPadSkinControlAppearance(shape: shape)
                        )
                    ),
                    PocketPadSkinVariant(
                        id: "landscape",
                        orientation: .landscape,
                        appearance: PocketPadSkinAppearance(
                            defaultControl: PocketPadSkinControlAppearance(shape: shape)
                        )
                    )
                ]
            )
        )
    }
}
