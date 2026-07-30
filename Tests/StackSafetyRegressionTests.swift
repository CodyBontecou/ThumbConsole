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
        case bundledSkinInstallationFailed
        case profileCodableMismatch
        case persistenceStartupFailed
        case reconciliationFailed
    }

    func testCriticalValueTypeInlineSizesStayWithinBudgets() {
        assertInlineSize(GamepadCustomization.self, atMost: 4 * 1024)
        assertInlineSize(GamepadButtonCustomization.self, atMost: 2 * 1024)
        assertInlineSize(GamepadConfigurationProfile.self, atMost: 512)
        assertInlineSize(PendingKeypadLayoutEdit.self, atMost: 4 * 1024)
        assertInlineSize(ControllerMessage.self, atMost: 4 * 1024)
        assertInlineSize(ThumbleSkin.self, atMost: 1024)
        assertInlineSize(ThumbleSkinPackage.self, atMost: 1024)
        assertInlineSize(ThumbleSkinAppearance.self, atMost: 1024)
        assertInlineSize(ThumbleSkinControlAppearance.self, atMost: 2 * 1024)
        assertInlineSize(GamepadControlStateStyle.self, atMost: 2 * 1024)
        assertInlineSize(GamepadControlVisualStyle.self, atMost: 256)
        assertInlineSize(GamepadStyleToken.self, atMost: 256)
        assertInlineSize(ThumbleBridgeOperation.self, atMost: 512)
        assertInlineSize(ThumbleBridgeStyleAppearance.self, atMost: 64)
        assertInlineSize(ThumbleConfigurationBridgeRequest.self, atMost: 512)
    }

    private func assertInlineSize<Value>(
        _ type: Value.Type,
        atMost maximumBytes: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualBytes = MemoryLayout<Value>.size
        print("stack-safety inline size: \(Value.self)=\(actualBytes) bytes")
        XCTAssertLessThanOrEqual(
            actualBytes,
            maximumBytes,
            "\(Value.self) uses \(actualBytes) inline bytes; keep it under \(maximumBytes) bytes or move large fields behind immutable/COW storage.",
            file: file,
            line: line
        )
    }

    func testBoxedProfileCustomizationsPreserveValueSemantics() throws {
        let customization = makeRichCustomization()
        let original = GamepadConfigurationProfile(
            name: "Value Semantics",
            customization: customization,
            landscapeCustomization: customization,
            portraitCustomization: customization,
            skinBaselineCustomization: customization
        )
        var changed = original

        changed.customization.setLabel("Changed Primary", for: .jump)
        changed.landscapeCustomization?.setLabel("Changed Landscape", for: .attack)
        changed.skinBaselineCustomization?.setLabel("Changed Baseline", for: .dash)

        XCTAssertEqual(original.customization, customization)
        XCTAssertEqual(original.landscapeCustomization, customization)
        XCTAssertEqual(original.skinBaselineCustomization, customization)
        XCTAssertNotEqual(changed.customization, original.customization)
        XCTAssertNotEqual(changed.landscapeCustomization, original.landscapeCustomization)
        XCTAssertNotEqual(changed.skinBaselineCustomization, original.skinBaselineCustomization)

        let encoded = try JSONEncoder().encode(changed)
        let decoded = try JSONDecoder().decode(GamepadConfigurationProfile.self, from: encoded)
        XCTAssertEqual(decoded, changed)
    }

    func testCopyOnWriteVisualStylePreservesValueSemantics() throws {
        let original = GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(opacity: 0.9),
            pressed: GamepadControlStateStyle(scale: 0.95)
        )
        var changed = original
        changed.normal.opacity = 0.5
        changed.pressed?.scale = 0.8

        XCTAssertEqual(original.normal.opacity, 0.9)
        XCTAssertEqual(original.pressed?.scale, 0.95)
        XCTAssertEqual(changed.normal.opacity, 0.5)
        XCTAssertEqual(changed.pressed?.scale, 0.8)
        XCTAssertNotEqual(changed, original)

        let encoded = try JSONEncoder().encode(changed)
        let decoded = try JSONDecoder().decode(GamepadControlVisualStyle.self, from: encoded)
        XCTAssertEqual(decoded, changed)
    }

    func testBoxedStyleTokenPreservesValueSemantics() throws {
        let original = GamepadStyleToken(
            id: "stack-style",
            name: "Stack Style",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(opacity: 0.9),
                pressed: GamepadControlStateStyle(scale: 0.95)
            )
        )
        var changed = original
        changed.visualStyle.normal.opacity = 0.5

        XCTAssertEqual(original.visualStyle.normal.opacity, 0.9)
        XCTAssertEqual(changed.visualStyle.normal.opacity, 0.5)
        XCTAssertNotEqual(changed, original)

        let encoded = try JSONEncoder().encode(changed)
        let decoded = try JSONDecoder().decode(GamepadStyleToken.self, from: encoded)
        XCTAssertEqual(decoded, changed)
    }

    private final class ProfileCodableJob: @unchecked Sendable {
        private let profile: GamepadConfigurationProfile
        private var encodedProfile = Data()
        private var encodedProfiles = Data()

        init(profile: GamepadConfigurationProfile) {
            self.profile = profile
        }

        func run() throws {
            try encodeProfile()
            try decodeProfile()
            try encodeProfileArray()
            try decodeProfileArray()
        }

        private func encodeProfile() throws {
            encodedProfile = try JSONEncoder().encode(profile)
            guard !encodedProfile.isEmpty else { throw StackTestError.emptyEncodedPayload }
        }

        private func decodeProfile() throws {
            let decoded = try JSONDecoder().decode(
                GamepadConfigurationProfile.self,
                from: encodedProfile
            )
            guard decoded == profile else { throw StackTestError.profileCodableMismatch }
        }

        private func encodeProfileArray() throws {
            encodedProfiles = try JSONEncoder().encode([profile, profile])
            guard !encodedProfiles.isEmpty else { throw StackTestError.emptyEncodedPayload }
        }

        private func decodeProfileArray() throws {
            let decoded = try JSONDecoder().decode(
                [GamepadConfigurationProfile].self,
                from: encodedProfiles
            )
            guard decoded == [profile, profile] else {
                throw StackTestError.profileCodableMismatch
            }
        }
    }

    private final class ProfilePersistenceStartupJob: @unchecked Sendable {
        func run() throws {
            let customization = GamepadCustomizationPersistence.load()
            let state = GamepadConfigurationProfilePersistence.load(
                activeCustomization: customization
            )
            guard state.profiles.count == 1,
                  state.activeProfile?.name == GamepadControllerTemplate.productivityStarter.displayName,
                  state.activeProfile?.hasCustomizationVariant(for: .landscape) == true,
                  state.activeProfile?.hasCustomizationVariant(for: .portrait) == true
            else {
                throw StackTestError.persistenceStartupFailed
            }

            GamepadCustomizationPersistence.save(state.activeProfile?.customization ?? customization)
            GamepadConfigurationProfilePersistence.save(
                state.profiles,
                activeProfileID: state.activeProfileID,
                defaultProfileID: state.defaultProfileID
            )
            guard UserDefaults.standard.data(
                forKey: GamepadConfigurationProfilePersistence.defaultsKey
            ) != nil else {
                throw StackTestError.persistenceStartupFailed
            }
        }
    }

    private final class PendingReconciliationJob: @unchecked Sendable {
        private let profile: GamepadConfigurationProfile
        private let acknowledgedEdit: PendingKeypadLayoutEdit
        private let changedEdit: PendingKeypadLayoutEdit
        private let missingProfileEdit: PendingKeypadLayoutEdit
        private let serverID = "stack-safety-server"

        init(profile: GamepadConfigurationProfile) {
            self.profile = profile
            let customization = profile.customization(for: .landscape)
            acknowledgedEdit = PendingKeypadLayoutEdit(
                profileID: profile.id,
                orientation: .landscape,
                customization: customization,
                serverID: serverID,
                updatedAt: 10
            )
            var changed = customization
            changed.setLabel("Pending Change", for: .jump)
            changedEdit = PendingKeypadLayoutEdit(
                profileID: profile.id,
                orientation: .landscape,
                customization: changed,
                serverID: serverID,
                updatedAt: 20
            )
            missingProfileEdit = PendingKeypadLayoutEdit(
                profileID: UUID(),
                orientation: .portrait,
                customization: changed,
                serverID: serverID,
                updatedAt: 30
            )
        }

        func run() throws {
            try validateAcknowledgementBranch()
            try validateLocalEditBranch()
            try validateRecoveryBranch()
        }

        private func validateAcknowledgementBranch() throws {
            let result = PendingKeypadLayoutReconciler.reconcile(
                incomingProfiles: [profile],
                pendingEdits: [acknowledgedEdit],
                authoritativeServerID: serverID
            )
            guard result.acknowledgedEditIDs == [acknowledgedEdit.id],
                  result.remainingEdits.isEmpty,
                  result.editsToUpload.isEmpty
            else { throw StackTestError.reconciliationFailed }
        }

        private func validateLocalEditBranch() throws {
            let result = PendingKeypadLayoutReconciler.reconcile(
                incomingProfiles: [profile],
                pendingEdits: [changedEdit],
                authoritativeServerID: serverID
            )
            guard result.remainingEdits == [changedEdit],
                  result.editsToUpload == [changedEdit],
                  result.profiles.first?.customization(for: .landscape)
                    .hasSamePresentation(as: changedEdit.customization) == true
            else { throw StackTestError.reconciliationFailed }
        }

        private func validateRecoveryBranch() throws {
            let result = PendingKeypadLayoutReconciler.reconcile(
                incomingProfiles: [profile],
                pendingEdits: [missingProfileEdit],
                authoritativeServerID: serverID
            )
            guard result.remainingEdits == [missingProfileEdit],
                  result.editsToUpload == [missingProfileEdit],
                  result.profiles.contains(where: { $0.id == missingProfileEdit.profileID })
            else { throw StackTestError.reconciliationFailed }
        }
    }

    private final class ProfileSkinApplicationJob: @unchecked Sendable {
        private var profile: GamepadConfigurationProfile
        private let initialPackage: ThumbleSkinPackage
        private let updatedPackage: ThumbleSkinPackage

        init(
            profile: GamepadConfigurationProfile,
            initialPackage: ThumbleSkinPackage,
            updatedPackage: ThumbleSkinPackage
        ) {
            self.profile = profile
            self.initialPackage = initialPackage
            self.updatedPackage = updatedPackage
        }

        func run() throws {
            applyInitialPackage()
            overrideJumpShape()
            applyUpdatedPackage()
            try validateResult()
        }

        private func applyInitialPackage() {
            profile.applySkin(initialPackage)
        }

        private func overrideJumpShape() {
            var jump = profile.customization.buttonCustomization(for: .jump)
            jump.shape = .rectangle
            profile.customization.setButtonCustomization(jump, for: .jump)
        }

        private func applyUpdatedPackage() {
            profile.applySkin(updatedPackage)
        }

        private func validateResult() throws {
            guard profile.skinReference?.version == "2.0.0" else {
                throw StackTestError.skinApplicationFailed
            }
            guard profile.customization.buttonCustomization(for: .jump).shape == .rectangle else {
                throw StackTestError.skinApplicationFailed
            }
            guard profile.customization.buttonCustomization(for: .attack).shape == .circle else {
                throw StackTestError.skinApplicationFailed
            }
            guard profile.landscapeSkinBaselineCustomization != nil,
                  profile.portraitSkinBaselineCustomization != nil
            else {
                throw StackTestError.skinApplicationFailed
            }
        }
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

    func testDirectFullProfileCodableRunsOn512KiBStack() throws {
        let (_, profile) = makeFullProfileWireMessage()
        let job = ProfileCodableJob(profile: profile)

        try runOnThread(stackSize: 512 * 1024) {
            try job.run()
        }
    }

    func testEmptyPersistenceStartupRunsOn512KiBStack() throws {
        let defaults = UserDefaults.standard
        let customizationKey = GamepadCustomizationPersistence.defaultsKey
        let profilesKey = GamepadConfigurationProfilePersistence.defaultsKey
        let savedCustomization = defaults.data(forKey: customizationKey)
        let savedProfiles = defaults.data(forKey: profilesKey)
        defaults.removeObject(forKey: customizationKey)
        defaults.removeObject(forKey: profilesKey)
        defer {
            if let savedCustomization {
                defaults.set(savedCustomization, forKey: customizationKey)
            } else {
                defaults.removeObject(forKey: customizationKey)
            }
            if let savedProfiles {
                defaults.set(savedProfiles, forKey: profilesKey)
            } else {
                defaults.removeObject(forKey: profilesKey)
            }
        }

        let job = ProfilePersistenceStartupJob()
        try runOnThread(stackSize: 512 * 1024) {
            try job.run()
        }
    }

    func testPendingReconciliationBranchesRunOn512KiBStack() throws {
        let profile = GamepadControllerTemplate.productivityStarter.makeProfile()
        let job = PendingReconciliationJob(profile: profile)

        try runOnThread(stackSize: 512 * 1024) {
            try job.run()
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

    func testProfileSkinApplicationRunsOn512KiBStack() throws {
        let package = makeSkinPackage(shape: .capsule, version: "1.0.0")
        let updatedPackage = makeSkinPackage(shape: .circle, version: "2.0.0")
        let customization = makeRichCustomization()
        let profile = GamepadConfigurationProfile(
            name: "Skin Stack",
            customization: customization,
            landscapeCustomization: customization,
            portraitCustomization: customization
        )

        let job = ProfileSkinApplicationJob(
            profile: profile,
            initialPackage: package,
            updatedPackage: updatedPackage
        )
        try runOnThread(stackSize: 512 * 1024) {
            try job.run()
        }
    }

    func testBundledSkinInstallationRunsOn512KiBStack() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Thumble-Bundled-Skin-Stack-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try runOnThread(stackSize: 512 * 1024) {
            let store = try ThumbleSkinStore(rootURL: rootURL)
            try store.installBundledSkinsIfNeeded()
            guard try store.installedSkins().count == ThumbleBundledSkins.packages.count else {
                throw StackTestError.bundledSkinInstallationFailed
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
    ) -> ThumbleSkinPackage {
        ThumbleSkinPackage(
            manifest: ThumbleSkinManifest(
                identifier: "com.example.stack-safety",
                version: version,
                name: "Stack Safety",
                author: ThumbleSkinAuthor(name: "Tests"),
                license: "MIT"
            ),
            skin: ThumbleSkin(
                base: ThumbleSkinAppearance(
                    defaultControl: ThumbleSkinControlAppearance(shape: shape)
                ),
                variants: [
                    ThumbleSkinVariant(
                        id: "portrait",
                        orientation: .portrait,
                        appearance: ThumbleSkinAppearance(
                            defaultControl: ThumbleSkinControlAppearance(shape: shape)
                        )
                    ),
                    ThumbleSkinVariant(
                        id: "landscape",
                        orientation: .landscape,
                        appearance: ThumbleSkinAppearance(
                            defaultControl: ThumbleSkinControlAppearance(shape: shape)
                        )
                    )
                ]
            )
        )
    }
}
