import SwiftUI
import XCTest

final class PocketPadSkinCompatibilityTests: XCTestCase {
    func testTemplateCompatibilityDistinguishesExactUnknownAndWrongLayouts() {
        let declaration = PocketPadSkinCompatibility(
            mode: .templateAligned,
            templates: [PocketPadSkinTemplateRequirement(templateID: "showcase", minimumRevision: 1, maximumRevision: 1)],
            orientations: [.landscape],
            requiredRoles: [.movement, .primaryAction]
        )
        var exact = GamepadCustomization.defaultValue
        exact.designMetadata = GamepadDesignMetadata(sourceTemplateID: "showcase", sourceTemplateRevision: 1)

        let exactResult = PocketPadSkinCompatibilityEvaluator.evaluate(
            declaration,
            customization: exact,
            orientation: .landscape
        )
        XCTAssertEqual(exactResult.status, .compatible)
        XCTAssertTrue(exactResult.allowsTemplateArtwork)

        var unknown = exact
        unknown.designMetadata = nil
        let unknownResult = PocketPadSkinCompatibilityEvaluator.evaluate(
            declaration,
            customization: unknown,
            orientation: .landscape
        )
        XCTAssertEqual(unknownResult.status, .degraded)
        XCTAssertFalse(unknownResult.allowsTemplateArtwork)
        XCTAssertTrue(unknownResult.issues.contains { $0.code == "unknown-template" })

        var wrong = exact
        wrong.designMetadata = GamepadDesignMetadata(sourceTemplateID: "classic", sourceTemplateRevision: 1)
        let wrongResult = PocketPadSkinCompatibilityEvaluator.evaluate(
            declaration,
            customization: wrong,
            orientation: .landscape
        )
        XCTAssertEqual(wrongResult.status, .incompatible)
        XCTAssertTrue(wrongResult.issues.contains { $0.code == "template-mismatch" })
    }

    func testArtworkLayerCascadeReplacesByIDAndSortsDeterministically() {
        let baseLayer = PocketPadSkinArtworkLayer(
            id: "badge",
            plane: .underlay,
            fillStyle: .solid(color("#112233")),
            opacity: 0.4,
            zIndex: 4
        )
        let topLayer = PocketPadSkinArtworkLayer(
            id: "top",
            plane: .overlay,
            fillStyle: .solid(color("#445566")),
            zIndex: 2
        )
        let replacement = PocketPadSkinArtworkLayer(
            id: "badge",
            plane: .overlay,
            fillStyle: .solid(color("#778899")),
            opacity: 0.9,
            zIndex: 1
        )
        let skin = PocketPadSkin(
            base: PocketPadSkinAppearance(artworkLayers: [topLayer, baseLayer]),
            variants: [
                PocketPadSkinVariant(
                    id: "portrait-dark",
                    orientation: .portrait,
                    colorScheme: .dark,
                    appearance: PocketPadSkinAppearance(artworkLayers: [replacement])
                )
            ]
        )

        let appearance = skin.appearance(orientation: .portrait, colorScheme: .dark)
        XCTAssertEqual(appearance.artworkLayers?.map(\.id), ["badge", "top"])
        XCTAssertEqual(appearance.artworkLayers?.first?.plane, .overlay)
        XCTAssertEqual(appearance.artworkLayers?.first?.opacity, 0.9)
    }

    func testResolverHydratesLayersOnlyForCompatibleTemplate() throws {
        let data = Data("layer".utf8)
        let layer = PocketPadSkinArtworkLayer(
            id: "shell",
            fillStyle: .image(GamepadImageFill(
                assetID: "layer",
                resizingMode: .nineSliceStretch,
                nineSliceInsets: GamepadImageCapInsets(top: 0.2, leading: 0.15, bottom: 0.2, trailing: 0.15)
            ))
        )
        let package = PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.layers",
                version: "1.0.0",
                name: "Layers",
                author: PocketPadSkinAuthor(name: "Tests"),
                assets: [
                    PocketPadSkinResourceDescriptor(
                        id: "layer",
                        path: "assets/layer.png",
                        contentType: "image/png",
                        role: .texture,
                        byteCount: data.count,
                        sha256: data.pocketPadSHA256
                    )
                ],
                compatibility: PocketPadSkinCompatibility(
                    mode: .templateAligned,
                    templates: [PocketPadSkinTemplateRequirement(templateID: "showcase")]
                )
            ),
            skin: PocketPadSkin(base: PocketPadSkinAppearance(artworkLayers: [layer])),
            assets: ["layer": data]
        )
        var customization = GamepadCustomization.defaultValue
        customization.designMetadata = GamepadDesignMetadata(sourceTemplateID: "showcase", sourceTemplateRevision: 1)

        let resolved = customization.applying(
            skinPackage: package,
            orientation: .landscape,
            colorScheme: .dark,
            options: .replacingAppearance
        )
        let resolvedLayer = try XCTUnwrap(resolved.artworkLayers.first)
        guard case .image(let image) = try XCTUnwrap(resolvedLayer.fillStyle) else {
            return XCTFail("Expected image artwork")
        }
        XCTAssertEqual(image.data, data)
        XCTAssertEqual(image.effectiveResizingMode, .nineSliceStretch)
        XCTAssertEqual(image.nineSliceInsets, GamepadImageCapInsets(top: 0.2, leading: 0.15, bottom: 0.2, trailing: 0.15))

        customization.designMetadata = GamepadDesignMetadata(sourceTemplateID: "classic", sourceTemplateRevision: 1)
        let mismatched = customization.applying(
            skinPackage: package,
            orientation: .landscape,
            colorScheme: .dark,
            options: .replacingAppearance
        )
        XCTAssertTrue(mismatched.artworkLayers.isEmpty)
    }

    func testManifestValidatorRejectsInvalidTemplateCompatibility() {
        let package = PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: "com.example.invalid-compatibility",
                version: "1.0.0",
                name: "Invalid",
                author: PocketPadSkinAuthor(name: "Tests"),
                compatibility: PocketPadSkinCompatibility(
                    mode: .templateAligned,
                    templates: [],
                    orientations: []
                )
            ),
            skin: PocketPadSkin(base: PocketPadSkinAppearance())
        )
        let report = PocketPadSkinPackageValidator.validate(package)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.code == "missing-template-requirement" })
        XCTAssertTrue(report.errors.contains { $0.code == "missing-compatible-orientation" })
    }

    private func color(_ hex: String) -> GamepadRGBAColor {
        GamepadRGBAColor(hexString: hex) ?? .defaultValue
    }
}
