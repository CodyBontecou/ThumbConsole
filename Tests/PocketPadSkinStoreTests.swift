import XCTest

final class PocketPadSkinStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketPadSkinStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testInstallLookupVersionConflictsAndRemoval() throws {
        let store = try PocketPadSkinStore(rootURL: temporaryDirectory)
        let one = makePackage(version: "1.0.0", shape: .rectangle)
        let oneData = try PocketPadSkinPackageCodec.encode(one)
        let reference = PocketPadSkinReference(identifier: one.manifest.identifier, version: "1.0.0")

        XCTAssertEqual(try store.install(data: oneData), .installed(reference))
        XCTAssertEqual(try store.install(data: oneData), .unchanged(reference))
        XCTAssertEqual(try store.package(for: reference).skin, one.skin?.normalized)

        let changedSameVersion = makePackage(version: "1.0.0", shape: .circle, summary: "Different bytes")
        XCTAssertThrowsError(try store.install(package: changedSameVersion)) { error in
            XCTAssertEqual(error as? PocketPadSkinStoreError, .versionAlreadyInstalled(reference))
        }
        XCTAssertEqual(try store.install(package: changedSameVersion, policy: .replaceSameVersion), .replaced(reference))

        let two = makePackage(version: "2.0.0", shape: .capsule)
        let twoReference = PocketPadSkinReference(identifier: two.manifest.identifier, version: "2.0.0")
        XCTAssertEqual(
            try store.install(package: two),
            .updated(twoReference, previousVersion: "1.0.0")
        )

        let old = makePackage(version: "0.9.0", shape: .roundedRectangle)
        XCTAssertThrowsError(try store.install(package: old)) { error in
            XCTAssertEqual(
                error as? PocketPadSkinStoreError,
                .newerVersionInstalled(identifier: old.manifest.identifier, installedVersion: "2.0.0")
            )
        }

        XCTAssertEqual(try store.installedSkins().count, 2)
        try store.remove(reference)
        XCTAssertThrowsError(try store.package(for: reference))
        XCTAssertEqual(try store.installedSkins().map(\.reference), [twoReference])

        let traversal = PocketPadSkinReference(identifier: "../../outside", version: "../1.0.0")
        XCTAssertThrowsError(try store.packageData(for: traversal)) { error in
            XCTAssertEqual(error as? PocketPadSkinStoreError, .invalidIdentity)
        }
        XCTAssertThrowsError(try store.remove(traversal)) { error in
            XCTAssertEqual(error as? PocketPadSkinStoreError, .invalidIdentity)
        }

        let outside = temporaryDirectory.deletingLastPathComponent()
            .appendingPathComponent("PocketPadSkinStoreOutside-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let symlink = temporaryDirectory.appendingPathComponent("com.example.symlink")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)
        var symlinkPackage = makePackage(version: "1.0.0", shape: .circle)
        symlinkPackage.manifest.identifier = "com.example.symlink"
        XCTAssertThrowsError(try store.install(package: symlinkPackage)) { error in
            XCTAssertEqual(error as? PocketPadSkinStoreError, .invalidIdentity)
        }
    }

    func testBundledThemesUseThePackageStore() throws {
        let store = try PocketPadSkinStore(rootURL: temporaryDirectory)
        try store.installBundledSkinsIfNeeded()

        let installed = try store.installedSkins()
        XCTAssertEqual(Set(installed.map(\.reference.identifier)), PocketPadBundledSkins.identifiers)
        XCTAssertTrue(installed.allSatisfy(\.isBundled))
        XCTAssertTrue(installed.allSatisfy { (try? store.package(for: $0.reference).skin) != nil })
        for package in PocketPadBundledSkins.packages {
            XCTAssertTrue(PocketPadSkinPackageValidator.validate(package).isValid)
        }
    }

    func testProfileBaselinePreservesOnlyUserAppearanceOverrides() throws {
        let originalPackage = makePackage(version: "1.0.0", shape: .rectangle)
        var profile = GamepadConfigurationProfile(name: "Player One", customization: .defaultValue)
        let originalJumpCenterX = profile.customization.buttonCustomization(for: .jump).centerX ?? 0
        profile.applySkin(originalPackage)

        XCTAssertEqual(profile.skinReference?.version, "1.0.0")
        XCTAssertEqual(profile.customization.buttonCustomization(for: .attack).shape, .rectangle)

        var jump = profile.customization.buttonCustomization(for: .jump)
        jump.shape = .circle
        jump.centerX = 0.82
        profile.customization.setButtonCustomization(jump, for: .jump)

        // A package update changes the inherited shape. Only the explicit jump override survives.
        var updatedPackage = makePackage(version: "1.0.0", shape: .capsule)
        updatedPackage.manifest.summary = "Updated skin contents"
        let rendered = profile.resolvedCustomization(
            for: .landscape,
            colorScheme: .light,
            skinPackage: updatedPackage
        )

        XCTAssertEqual(rendered.buttonCustomization(for: .jump).shape, .circle)
        XCTAssertEqual(rendered.buttonCustomization(for: .attack).shape, .capsule)
        XCTAssertEqual(rendered.buttonCustomization(for: .jump).centerX ?? 0, 0.82, accuracy: 0.001)
        XCTAssertNotEqual(rendered.buttonCustomization(for: .jump).centerX ?? 0, originalJumpCenterX)

        updatedPackage.manifest.version = "2.0.0"
        profile.applySkin(updatedPackage)
        XCTAssertEqual(profile.skinReference?.version, "2.0.0")
        XCTAssertEqual(profile.customization.buttonCustomization(for: .jump).shape, .circle)
        XCTAssertEqual(profile.customization.buttonCustomization(for: .attack).shape, .capsule)
        XCTAssertEqual(profile.skinBaselineCustomization?.buttonCustomization(for: .jump).shape, .capsule)

        profile.detachSkin()
        XCTAssertNil(profile.skinReference)
        XCTAssertNil(profile.skinBaselineCustomization)
        XCTAssertEqual(profile.customization.buttonCustomization(for: .jump).shape, .circle)
    }

    func testProfileStoresPackageAssetReferencesWithoutDuplicatingBinaryData() throws {
        let data = Data("package-only-image".utf8)
        let assetID = "package-image"
        let package = PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.external-assets",
                version: "1.0.0",
                name: "External Assets",
                author: PocketPadSkinAuthor(name: "Tests"),
                assets: [
                    PocketPadSkinResourceDescriptor(
                        id: assetID,
                        path: "assets/package-image.png",
                        contentType: "image/png",
                        role: .background,
                        byteCount: data.count,
                        sha256: ""
                    )
                ]
            ),
            skin: PocketPadSkin(
                base: PocketPadSkinAppearance(
                    backgroundFillStyle: .image(GamepadImageFill(assetID: assetID))
                )
            ),
            assets: [assetID: data]
        )
        let canonical = try PocketPadSkinPackageCodec.decode(PocketPadSkinPackageCodec.encode(package))
        var profile = GamepadConfigurationProfile(name: "External", customization: .defaultValue)
        profile.applySkin(canonical)

        XCTAssertNil(profile.customization.assetLibrary.asset(id: assetID)?.data)
        if case .image(let savedImage) = profile.customization.backgroundFillStyle {
            XCTAssertNil(savedImage.data)
            XCTAssertEqual(savedImage.assetID, assetID)
        } else {
            XCTFail("Expected saved image reference")
        }

        let encodedProfile = try JSONEncoder().encode(profile)
        XCTAssertFalse(String(decoding: encodedProfile, as: UTF8.self).contains(data.base64EncodedString()))

        let rendered = profile.resolvedCustomization(
            for: .landscape,
            colorScheme: .light,
            skinPackage: canonical
        )
        XCTAssertEqual(rendered.assetLibrary.asset(id: assetID)?.data, data)
        if case .image(let renderedImage) = rendered.backgroundFillStyle {
            XCTAssertEqual(renderedImage.data, data)
        } else {
            XCTFail("Expected hydrated image fill")
        }
    }

    func testProfileSkinFieldsAreBackwardCompatibleAndWirePayloadCarriesPackages() throws {
        let legacyJSON = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "name": "Legacy",
          "customization": {}
        }
        """.data(using: .utf8)!
        let legacy = try JSONDecoder().decode(GamepadConfigurationProfile.self, from: legacyJSON)
        XCTAssertNil(legacy.skinReference)
        XCTAssertNil(legacy.skinBaselineCustomization)

        let data = try PocketPadSkinPackageCodec.encode(makePackage(version: "1.0.0", shape: .circle))
        let message = ControllerMessage(type: .gamepadProfiles, skinPackages: [data])
        let encoded = try ControllerWireCodec.encode(message, using: JSONEncoder())
        let decoded = try ControllerWireCodec.decode(encoded, using: JSONDecoder())
        XCTAssertEqual(decoded.skinPackages, [data])

        let reference = PocketPadSkinReference(identifier: "com.example.store-test", version: "1.0.0")
        let apply = ControllerMessage(
            type: .gamepadProfileSkinSelection,
            skinReference: reference,
            gamepadProfileID: legacy.id,
            capabilities: [.skinPackages, .gamepadProfileSkinSelection]
        )
        let applyData = try ControllerWireCodec.encode(apply, using: JSONEncoder())
        let decodedApply = try ControllerWireCodec.decode(applyData, using: JSONDecoder())
        XCTAssertEqual(decodedApply.type, .gamepadProfileSkinSelection)
        XCTAssertEqual(decodedApply.skinReference, reference)
        XCTAssertEqual(decodedApply.gamepadProfileID, legacy.id)
        XCTAssertEqual(Set(decodedApply.capabilities ?? []), [.skinPackages, .gamepadProfileSkinSelection])

        let detach = ControllerMessage(type: .gamepadProfileSkinSelection, gamepadProfileID: legacy.id)
        let detachData = try ControllerWireCodec.encode(detach, using: JSONEncoder())
        let decodedDetach = try ControllerWireCodec.decode(detachData, using: JSONDecoder())
        XCTAssertNil(decodedDetach.skinReference)

        let removal = ControllerMessage(type: .skinPackageRemoval, skinReference: reference)
        let removalData = try ControllerWireCodec.encode(removal, using: JSONEncoder())
        let decodedRemoval = try ControllerWireCodec.decode(removalData, using: JSONDecoder())
        XCTAssertEqual(decodedRemoval.type, .skinPackageRemoval)
        XCTAssertEqual(decodedRemoval.skinReference, reference)
    }

    private func makePackage(
        version: String,
        shape: GamepadButtonShapeStyle,
        summary: String = "A test skin"
    ) -> PocketPadSkinPackage {
        PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.store-test",
                version: version,
                name: "Store Test",
                author: PocketPadSkinAuthor(name: "Tests"),
                summary: summary,
                license: "MIT"
            ),
            skin: PocketPadSkin(
                base: PocketPadSkinAppearance(
                    defaultControl: PocketPadSkinControlAppearance(shape: shape)
                )
            )
        )
    }
}
