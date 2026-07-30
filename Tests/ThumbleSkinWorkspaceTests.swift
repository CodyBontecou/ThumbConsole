import Foundation
import XCTest

final class ThumbleSkinWorkspaceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ThumbleSkinWorkspaceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testMinimalWorkspaceDecodesWithBackwardCompatibleDefaults() throws {
        let data = Data(#"{"identifier":"com.example.skin","name":"Example"}"#.utf8)
        let workspace = try JSONDecoder().decode(ThumbleSkinWorkspace.self, from: data)

        XCTAssertEqual(workspace.schema, ThumbleSkinWorkspaceSchema.identifier)
        XCTAssertEqual(workspace.schemaVersion, 1)
        XCTAssertEqual(workspace.version, "1.0.0")
        XCTAssertEqual(workspace.artboardID, ThumbleSkinArtboardCatalog.defaultID)
        XCTAssertEqual(workspace.orientations, [.landscape])
        XCTAssertEqual(workspace.colorSchemes, [.light, .dark])
        XCTAssertTrue(workspace.materials.isEmpty)
        XCTAssertTrue(workspace.sourceAssets.isEmpty)
    }

    func testLegacyMaterialDecodesWithNilOptionalStateControls() throws {
        let json = ##"{"id":"paper","name":"Paper","kind":"matte_rubber","baseColor":"#112233","foregroundColor":"#FFFFFF","depth":0.4,"gloss":0.1,"pressedScale":0.97}"##
        let material = try JSONDecoder().decode(ThumbleSkinMaterialSpec.self, from: Data(json.utf8))

        XCTAssertNil(material.joystickKnobColor)
        XCTAssertNil(material.darkJoystickKnobColor)
        XCTAssertNil(material.pressedFillColor)
        XCTAssertNil(material.activeFillColor)
        XCTAssertNil(material.disabledFillColor)
        XCTAssertNil(material.shadowScale)
        XCTAssertNil(material.activeStrokeWidth)
        XCTAssertNil(material.disabledOpacity)
    }

    func testOptionalMaterialStateControlsRoundTrip() throws {
        var material = ThumbleSkinMaterialSpec(
            id: "paper",
            name: "Paper",
            kind: .matteRubber,
            baseColor: "#112233",
            foregroundColor: "#FFFFFF"
        )
        material.darkStrokeColor = "#778899"
        material.joystickKnobColor = "#223344"
        material.darkJoystickKnobColor = "#334455"
        material.pressedFillColor = "#101820"
        material.darkPressedFillColor = "#080C10"
        material.activeFillColor = "#203040"
        material.darkActiveFillColor = "#304050"
        material.darkActiveColor = "#FFEEDD"
        material.activeIndexColor = "#AABBCC"
        material.darkActiveIndexColor = "#CCDDEE"
        material.activeIndexWidth = 2
        material.disabledFillColor = "#555555"
        material.darkDisabledFillColor = "#333333"
        material.disabledForegroundColor = "#F0F0F0"
        material.darkDisabledForegroundColor = "#E0E0E0"
        material.disabledStrokeColor = "#999999"
        material.darkDisabledStrokeColor = "#BBBBBB"
        material.shadowScale = 0.25
        material.pressedShadowScale = 0.2
        material.pressedInnerShadowScale = 0.1
        material.activeStrokeWidth = 3
        material.portraitActiveStrokeWidth = 4
        material.landscapeActiveStrokeWidth = 2
        material.disabledStrokeWidth = 2
        material.disabledOpacity = 0.92

        let data = try JSONEncoder().encode(material)
        let decoded = try JSONDecoder().decode(ThumbleSkinMaterialSpec.self, from: data)
        XCTAssertEqual(decoded, material)
    }

    func testSourceSchemaDeclaresStateControlsAsOptionalMaterialProperties() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let schemaURL = repository.appendingPathComponent("docs/skins/pocketpad-skin-source.schema.json")
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: schemaURL)) as? [String: Any]
        )
        let definitions = try XCTUnwrap(root["$defs"] as? [String: Any])
        let material = try XCTUnwrap(definitions["material"] as? [String: Any])
        let properties = try XCTUnwrap(material["properties"] as? [String: Any])
        let required = Set((material["required"] as? [String]) ?? [])

        for key in [
            "joystickKnobColor", "darkJoystickKnobColor", "pressedFillColor",
            "activeFillColor", "activeStrokeWidth", "portraitActiveStrokeWidth",
            "landscapeActiveStrokeWidth", "activeIndexColor", "activeIndexWidth", "disabledFillColor",
            "disabledStrokeColor", "disabledStrokeWidth", "disabledOpacity", "shadowScale"
        ] {
            XCTAssertNotNil(properties[key], key)
            XCTAssertFalse(required.contains(key), key)
        }
    }

    func testCanonicalArtboardsHaveStableFramesRolesAndProfiles() throws {
        let artboards = ThumbleSkinArtboardCatalog.all
        XCTAssertGreaterThan(artboards.count, 10)
        let showcase = try XCTUnwrap(ThumbleSkinArtboardCatalog.resolve("showcase-controller-v1"))
        XCTAssertEqual(showcase.templateID, GamepadControllerTemplate.snes.rawValue)
        XCTAssertFalse(showcase.variants.isEmpty)
        XCTAssertTrue(showcase.expectedRoles.contains(.movement))
        XCTAssertTrue(showcase.expectedRoles.contains(.primaryAction))

        for artboard in artboards {
            XCTAssertFalse(artboard.variants.isEmpty, artboard.id)
            for variant in artboard.variants {
                XCTAssertGreaterThan(variant.canvasWidth, 100)
                XCTAssertGreaterThan(variant.canvasHeight, 100)
                for control in variant.controls {
                    XCTAssertGreaterThan(control.frame.width, 0)
                    XCTAssertGreaterThan(control.frame.height, 0)
                    XCTAssertGreaterThanOrEqual(control.frame.x, 0)
                    XCTAssertGreaterThanOrEqual(control.frame.y, 0)
                    XCTAssertLessThanOrEqual(control.frame.x + control.frame.width, 1.0001)
                    XCTAssertLessThanOrEqual(control.frame.y + control.frame.height, 1.0001)
                }
            }
        }

        let first = try XCTUnwrap(ThumbleSkinArtboardCatalog.profile(for: showcase.id))
        let second = try XCTUnwrap(ThumbleSkinArtboardCatalog.profile(for: showcase.id))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(first), try encoder.encode(second))
        XCTAssertEqual(first.updatedAt, 0)
        XCTAssertEqual(first.customization.designMetadata?.sourceTemplateID, GamepadControllerTemplate.snes.rawValue.lowercased())
        XCTAssertEqual(first.customization.designMetadata?.sourceTemplateRevision, 2)
    }

    func testCommittedCanonicalArtboardsMatchCompiledCatalog() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for id in ["showcase-controller-v1", "classic-16-bit-v1"] {
            let url = repository.appendingPathComponent("docs/skins/artboards/\(id).json")
            let committed = try JSONDecoder().decode(ThumbleSkinArtboard.self, from: Data(contentsOf: url))
            XCTAssertEqual(committed, ThumbleSkinArtboardCatalog.resolve(id), id)
        }
    }

    func testScaffolderWritesEditableSourcesAndProtectsExistingWork() throws {
        let destination = temporaryDirectory.appendingPathComponent("IndigoPocket", isDirectory: true)
        let workspace = try ThumbleSkinScaffolder.write(
            name: "Indigo Pocket",
            identifier: "com.example.pocketpad.skin.indigo-pocket",
            artboardID: "classic-16-bit-v1",
            to: destination
        )

        XCTAssertEqual(workspace.name, "Indigo Pocket")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("skin-source.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("sources/artwork/accent-lines.svg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("README.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent("reviews/README.md").path))
        let approval = try String(contentsOf: destination.appendingPathComponent("reviews/human-approval.json"), encoding: .utf8)
        XCTAssertTrue(approval.contains("\"status\": \"pending\""))
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("build").path))

        let decoded = try JSONDecoder().decode(
            ThumbleSkinWorkspace.self,
            from: Data(contentsOf: destination.appendingPathComponent("skin-source.json"))
        )
        XCTAssertEqual(decoded.artboardID, "classic-16-bit-v1")
        XCTAssertEqual(decoded.materials.count, 4)
        XCTAssertTrue(decoded.assignments.contains { $0.role == .movement && $0.materialID == "rubber" })

        XCTAssertThrowsError(
            try ThumbleSkinScaffolder.write(
                name: "Replacement",
                identifier: "com.example.replacement",
                to: destination
            )
        ) { error in
            guard case ThumbleSkinScaffoldError.destinationNotEmpty = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testScaffolderRejectsUnknownArtboardsAndUnsafeIdentity() {
        XCTAssertThrowsError(
            try ThumbleSkinScaffolder.write(
                name: "Bad",
                identifier: "not-an-id",
                to: temporaryDirectory.appendingPathComponent("bad")
            )
        ) { error in
            XCTAssertEqual(error as? ThumbleSkinScaffoldError, .invalidIdentity)
        }
        XCTAssertThrowsError(
            try ThumbleSkinScaffolder.write(
                name: "Bad",
                identifier: "com.example.bad",
                artboardID: "missing-artboard",
                to: temporaryDirectory.appendingPathComponent("missing")
            )
        ) { error in
            XCTAssertEqual(error as? ThumbleSkinScaffoldError, .unknownArtboard("missing-artboard"))
        }
    }
}
