import Foundation
import UniformTypeIdentifiers
import XCTest
import ZIPFoundation

final class PocketPadSkinPackageTests: XCTestCase {
    func testSkinPackageRoundTripsManifestVariantsAndExternalAssets() throws {
        let assetData = Data("not-a-real-image-but-a-stable-package-resource".utf8)
        let package = makePackage(assetData: assetData)

        let encoded = try PocketPadSkinPackageCodec.encode(package)
        XCTAssertFalse(encoded.isEmpty)
        XCTAssertEqual(encoded, try PocketPadSkinPackageCodec.encode(package), "Package encoding should be reproducible for stable catalog hashes and sync deduplication")

        let decoded = try PocketPadSkinPackageCodec.decode(encoded)
        XCTAssertEqual(decoded.manifest.identifier, "com.example.neon-arcade")
        XCTAssertEqual(decoded.manifest.version, "1.2.3")
        XCTAssertEqual(decoded.assets["neon-texture"], assetData)
        XCTAssertEqual(decoded.manifest.assets.first?.byteCount, assetData.count)
        XCTAssertEqual(decoded.manifest.assets.first?.sha256.count, 64)

        let appearance = try XCTUnwrap(decoded.skin).appearance(orientation: .portrait, colorScheme: .dark)
        XCTAssertEqual(appearance.accentStyle, .purple)
        XCTAssertEqual(appearance.showsButtonLabels, false)
        XCTAssertEqual(
            appearance.controlAppearance(for: .jump, controlKind: .button).styleID,
            "neon-primary"
        )
    }

    func testVariantCascadeUsesBaseThenIncreasingSpecificity() throws {
        let baseStyle = GamepadStyleToken(
            id: "base",
            name: "Base",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(fillStyle: .solid(color("#111111")))
            )
        )
        let portraitStyle = GamepadStyleToken(
            id: "portrait",
            name: "Portrait",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(fillStyle: .solid(color("#222222")))
            )
        )
        let skin = PocketPadSkin(
            base: PocketPadSkinAppearance(
                accentStyle: .blue,
                showsButtonLabels: true,
                defaultControl: PocketPadSkinControlAppearance(styleID: "base"),
                styleLibrary: GamepadStyleLibrary(styles: [baseStyle])
            ),
            variants: [
                PocketPadSkinVariant(
                    id: "portrait",
                    orientation: .portrait,
                    appearance: PocketPadSkinAppearance(
                        defaultControl: PocketPadSkinControlAppearance(styleID: "portrait"),
                        styleLibrary: GamepadStyleLibrary(styles: [portraitStyle])
                    )
                ),
                PocketPadSkinVariant(
                    id: "portrait-dark",
                    orientation: .portrait,
                    colorScheme: .dark,
                    appearance: PocketPadSkinAppearance(showsButtonLabels: false)
                )
            ]
        )

        let portraitDark = skin.appearance(orientation: .portrait, colorScheme: .dark)
        XCTAssertEqual(portraitDark.accentStyle, .blue)
        XCTAssertEqual(portraitDark.showsButtonLabels, false)
        XCTAssertEqual(portraitDark.defaultControl?.styleID, "portrait")
        XCTAssertEqual(Set(portraitDark.styleLibrary.styles.map(\.id)), ["base", "portrait"])

        let landscapeLight = skin.appearance(orientation: .landscape, colorScheme: .light)
        XCTAssertEqual(landscapeLight.showsButtonLabels, true)
        XCTAssertEqual(landscapeLight.defaultControl?.styleID, "base")
    }

    func testVisualRolesDoNotDependOnProfileUUIDsOrLabels() {
        XCTAssertEqual(GamepadVisualRole.inferred(for: .up, controlKind: .button), .movement)
        XCTAssertEqual(GamepadVisualRole.inferred(for: .jump, controlKind: .button), .primaryAction)
        XCTAssertEqual(GamepadVisualRole.inferred(for: .pause, controlKind: .button), .menu)
        XCTAssertEqual(GamepadVisualRole.inferred(for: .custom8, controlKind: .button), .custom)
        XCTAssertEqual(GamepadVisualRole.inferred(for: .jump, controlKind: .joystick), .joystick)
        XCTAssertEqual(GamepadVisualRole.inferred(for: .jump, controlKind: .decoration), .decoration)
    }

    func testValidatorRejectsBadIdentityVersionAndMissingStyle() {
        let skin = PocketPadSkin(
            base: PocketPadSkinAppearance(
                defaultControl: PocketPadSkinControlAppearance(styleID: "missing")
            )
        )
        let package = PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "bad",
                version: "one",
                name: "Broken",
                author: PocketPadSkinAuthor(name: "Tester")
            ),
            skin: skin
        )

        let report = PocketPadSkinPackageValidator.validate(package)
        XCTAssertFalse(report.isValid)
        let codes = Set(report.errors.map(\.code))
        XCTAssertTrue(codes.contains("invalid-identifier"))
        XCTAssertTrue(codes.contains("invalid-version"))
        XCTAssertTrue(codes.contains("missing-style-reference"))
    }

    func testValidatorRejectsInvalidCompatibilityDeclarationsBeforeNormalization() {
        let compatibility = PocketPadSkinCompatibility(
            mode: .templateAligned,
            templates: [
                PocketPadSkinTemplateRequirement(templateID: "", minimumRevision: 0, maximumRevision: -1),
                PocketPadSkinTemplateRequirement(templateID: "SNES", minimumRevision: 2, maximumRevision: 1),
                PocketPadSkinTemplateRequirement(templateID: "snes", minimumRevision: 1)
            ],
            orientations: [],
            minimumAspectRatio: 3,
            maximumAspectRatio: 1
        )
        let package = PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                schemaVersion: 1,
                identifier: "com.example.invalid-compatibility",
                version: "1.0.0",
                name: "Invalid Compatibility",
                author: PocketPadSkinAuthor(name: "Tests"),
                compatibility: compatibility
            ),
            skin: PocketPadSkin(base: .empty)
        )

        let codes = Set(PocketPadSkinPackageValidator.validate(package).errors.map(\.code))
        XCTAssertTrue(codes.contains("compatibility-requires-v2"))
        XCTAssertTrue(codes.contains("missing-compatible-orientation"))
        XCTAssertTrue(codes.contains("invalid-aspect-range"))
        XCTAssertTrue(codes.contains("invalid-template-requirement"))
        XCTAssertTrue(codes.contains("invalid-template-revision-range"))
        XCTAssertTrue(codes.contains("duplicate-template-requirement"))
        XCTAssertThrowsError(try PocketPadSkinPackageCodec.encode(package))
    }

    func testValidatorRejectsUnsafeResourcePaths() {
        let package = PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.unsafe",
                version: "1.0.0",
                name: "Unsafe",
                author: PocketPadSkinAuthor(name: "Tester"),
                assets: [
                    PocketPadSkinResourceDescriptor(
                        id: "bad",
                        path: "assets/../escape.png",
                        contentType: "image/png",
                        role: .texture,
                        byteCount: 1,
                        sha256: String(repeating: "0", count: 64)
                    )
                ]
            ),
            skin: PocketPadSkin(base: .empty),
            assets: ["bad": Data([0])]
        )

        let report = PocketPadSkinPackageValidator.validate(package)
        XCTAssertTrue(report.errors.contains { $0.code == "unsafe-asset-path" })
        XCTAssertThrowsError(try PocketPadSkinPackageCodec.encode(package))
    }

    func testDecoderRejectsUndeclaredArchiveEntries() throws {
        let original = try PocketPadSkinPackageCodec.encode(makePackage(assetData: Data("asset".utf8)))
        let archive = try Archive(data: original, accessMode: .update)
        let unexpected = Data("surprise".utf8)
        try archive.addEntry(
            with: "unexpected.txt",
            type: .file,
            uncompressedSize: Int64(unexpected.count),
            compressionMethod: .deflate
        ) { position, size in
            let start = Int(position)
            return unexpected.subdata(in: start..<(start + size))
        }
        let tampered = try XCTUnwrap(archive.data)

        XCTAssertThrowsError(try PocketPadSkinPackageCodec.decode(tampered)) { error in
            XCTAssertEqual(error as? PocketPadSkinPackageCodecError, .unexpectedEntry("unexpected.txt"))
        }
    }

    func testDecoderRejectsSymlinksCompressionBombsAndOversizedEntries() throws {
        let original = try PocketPadSkinPackageCodec.encode(makePackage(assetData: Data("asset".utf8)))

        let symlinkArchive = try Archive(data: original, accessMode: .update)
        let linkTarget = Data("../../outside".utf8)
        try symlinkArchive.addEntry(
            with: "assets/link.png",
            type: .symlink,
            uncompressedSize: Int64(linkTarget.count),
            compressionMethod: .none
        ) { position, size in
            let start = Int(position)
            return linkTarget.subdata(in: start..<(start + size))
        }
        XCTAssertThrowsError(try PocketPadSkinPackageCodec.decode(try XCTUnwrap(symlinkArchive.data))) { error in
            XCTAssertEqual(error as? PocketPadSkinPackageCodecError, .unsupportedEntry("assets/link.png"))
        }

        let bombArchive = try Archive(data: original, accessMode: .update)
        let compressible = Data(repeating: 0, count: 500_000)
        try bombArchive.addEntry(
            with: "assets/bomb.png",
            type: .file,
            uncompressedSize: Int64(compressible.count),
            compressionMethod: .deflate
        ) { position, size in
            let start = Int(position)
            return compressible.subdata(in: start..<(start + size))
        }
        XCTAssertThrowsError(try PocketPadSkinPackageCodec.decode(try XCTUnwrap(bombArchive.data))) { error in
            XCTAssertEqual(error as? PocketPadSkinPackageCodecError, .compressionRatioTooHigh("assets/bomb.png"))
        }

        let oversizedArchive = try Archive(data: original, accessMode: .update)
        let oversized = Data(repeating: 1, count: PocketPadSkinPackageCodec.maximumEntryBytes + 1)
        try oversizedArchive.addEntry(
            with: "assets/oversized.png",
            type: .file,
            uncompressedSize: Int64(oversized.count),
            compressionMethod: .none
        ) { position, size in
            let start = Int(position)
            return oversized.subdata(in: start..<(start + size))
        }
        XCTAssertThrowsError(try PocketPadSkinPackageCodec.decode(try XCTUnwrap(oversizedArchive.data))) { error in
            XCTAssertEqual(error as? PocketPadSkinPackageCodecError, .entryTooLarge("assets/oversized.png"))
        }
    }

    func testValidatorRejectsExecutableAssetsDuplicateIDsAndProfilesInSkins() {
        let payload = Data("#!/bin/sh".utf8)
        let descriptors = [
            PocketPadSkinResourceDescriptor(
                id: "script",
                path: "assets/run.sh",
                contentType: "application/x-sh",
                role: .reference,
                byteCount: payload.count,
                sha256: ""
            ),
            PocketPadSkinResourceDescriptor(
                id: "script",
                path: "assets/run-again.sh",
                contentType: "application/x-sh",
                role: .reference,
                byteCount: payload.count,
                sha256: ""
            )
        ]
        let package = PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.no-executables",
                version: "1.0.0",
                name: "No Executables",
                author: PocketPadSkinAuthor(name: "Tests"),
                assets: descriptors
            ),
            skin: PocketPadSkin(base: .empty),
            profile: GamepadConfigurationProfile(name: "Should Not Run", customization: .defaultValue),
            assets: ["script": payload]
        )

        let codes = Set(PocketPadSkinPackageValidator.validate(package).errors.map(\.code))
        XCTAssertTrue(codes.contains("executable-asset"))
        XCTAssertTrue(codes.contains("duplicate-asset-id"))
        XCTAssertTrue(codes.contains("unexpected-profile"))
        XCTAssertThrowsError(try PocketPadSkinPackageCodec.encode(package))
    }

    func testSemanticVersionOrdering() throws {
        let alpha = try XCTUnwrap(PocketPadSemanticVersion("1.0.0-alpha"))
        let release = try XCTUnwrap(PocketPadSemanticVersion("1.0.0"))
        let next = try XCTUnwrap(PocketPadSemanticVersion("1.1.0"))
        XCTAssertLessThan(alpha, release)
        XCTAssertLessThan(release, next)
        XCTAssertNil(PocketPadSemanticVersion("1.0"))
        XCTAssertNil(PocketPadSemanticVersion("latest"))
    }

    func testPackageDocumentAdvertisesCustomFileType() {
        XCTAssertEqual(PocketPadSkinPackageDocument.readableContentTypes, [.pocketPadSkinPackage])
        XCTAssertEqual(PocketPadSkinPackageDocument.writableContentTypes, [.pocketPadSkinPackage])
        XCTAssertEqual(UTType.pocketPadSkinPackage.identifier, "com.codybontecou.pocketpad.skin-package")
    }

    private func makePackage(assetData: Data) -> PocketPadSkinPackage {
        let style = GamepadStyleToken(
            id: "neon-primary",
            name: "Neon Primary",
            visualStyle: GamepadControlVisualStyle(
                normal: GamepadControlStateStyle(
                    fillStyle: .image(GamepadImageFill(assetID: "neon-texture")),
                    foregroundColor: color("#FFFFFF"),
                    glowColor: color("#00D9FF"),
                    glowRadius: 12
                ),
                pressed: GamepadControlStateStyle(scale: 0.94),
                hapticFeedback: GamepadHapticFeedback(style: .rigid)
            )
        )
        let skin = PocketPadSkin(
            base: PocketPadSkinAppearance(
                accentStyle: .purple,
                showsButtonLabels: true,
                roleRules: [
                    PocketPadSkinRoleRule(
                        role: .primaryAction,
                        appearance: PocketPadSkinControlAppearance(styleID: style.id)
                    )
                ],
                styleLibrary: GamepadStyleLibrary(styles: [style])
            ),
            variants: [
                PocketPadSkinVariant(
                    id: "portrait-dark",
                    orientation: .portrait,
                    colorScheme: .dark,
                    appearance: PocketPadSkinAppearance(showsButtonLabels: false)
                )
            ]
        )
        let manifest = PocketPadSkinManifest(
            identifier: "com.example.neon-arcade",
            version: "1.2.3",
            name: "Neon Arcade",
            author: PocketPadSkinAuthor(name: "Example Creator", url: URL(string: "https://example.com")),
            summary: "A test skin.",
            license: "MIT",
            tags: ["arcade", "neon"],
            assets: [
                PocketPadSkinResourceDescriptor(
                    id: "neon-texture",
                    path: "assets/neon-texture.png",
                    contentType: "image/png",
                    role: .texture,
                    byteCount: 0,
                    sha256: ""
                )
            ]
        )
        return PocketPadSkinPackage(
            manifest: manifest,
            skin: skin,
            assets: ["neon-texture": assetData]
        )
    }

    private func color(_ hex: String) -> GamepadRGBAColor {
        GamepadRGBAColor(hexString: hex) ?? .defaultValue
    }
}
