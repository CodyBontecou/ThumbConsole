import Foundation
import XCTest

final class PocketPadSkinWorkspaceTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketPadSkinWorkspaceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
    }

    func testMinimalWorkspaceDecodesWithBackwardCompatibleDefaults() throws {
        let data = Data(#"{"identifier":"com.example.skin","name":"Example"}"#.utf8)
        let workspace = try JSONDecoder().decode(PocketPadSkinWorkspace.self, from: data)

        XCTAssertEqual(workspace.schema, PocketPadSkinWorkspaceSchema.identifier)
        XCTAssertEqual(workspace.schemaVersion, 1)
        XCTAssertEqual(workspace.version, "1.0.0")
        XCTAssertEqual(workspace.artboardID, PocketPadSkinArtboardCatalog.defaultID)
        XCTAssertEqual(workspace.orientations, [.landscape])
        XCTAssertEqual(workspace.colorSchemes, [.light, .dark])
        XCTAssertTrue(workspace.materials.isEmpty)
        XCTAssertTrue(workspace.sourceAssets.isEmpty)
    }

    func testCanonicalArtboardsHaveStableFramesRolesAndProfiles() throws {
        let artboards = PocketPadSkinArtboardCatalog.all
        XCTAssertGreaterThan(artboards.count, 10)
        let showcase = try XCTUnwrap(PocketPadSkinArtboardCatalog.resolve("showcase-controller-v1"))
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

        let first = try XCTUnwrap(PocketPadSkinArtboardCatalog.profile(for: showcase.id))
        let second = try XCTUnwrap(PocketPadSkinArtboardCatalog.profile(for: showcase.id))
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
            let committed = try JSONDecoder().decode(PocketPadSkinArtboard.self, from: Data(contentsOf: url))
            XCTAssertEqual(committed, PocketPadSkinArtboardCatalog.resolve(id), id)
        }
    }

    func testScaffolderWritesEditableSourcesAndProtectsExistingWork() throws {
        let destination = temporaryDirectory.appendingPathComponent("IndigoPocket", isDirectory: true)
        let workspace = try PocketPadSkinScaffolder.write(
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
            PocketPadSkinWorkspace.self,
            from: Data(contentsOf: destination.appendingPathComponent("skin-source.json"))
        )
        XCTAssertEqual(decoded.artboardID, "classic-16-bit-v1")
        XCTAssertEqual(decoded.materials.count, 4)
        XCTAssertTrue(decoded.assignments.contains { $0.role == .movement && $0.materialID == "rubber" })

        XCTAssertThrowsError(
            try PocketPadSkinScaffolder.write(
                name: "Replacement",
                identifier: "com.example.replacement",
                to: destination
            )
        ) { error in
            guard case PocketPadSkinScaffoldError.destinationNotEmpty = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testScaffolderRejectsUnknownArtboardsAndUnsafeIdentity() {
        XCTAssertThrowsError(
            try PocketPadSkinScaffolder.write(
                name: "Bad",
                identifier: "not-an-id",
                to: temporaryDirectory.appendingPathComponent("bad")
            )
        ) { error in
            XCTAssertEqual(error as? PocketPadSkinScaffoldError, .invalidIdentity)
        }
        XCTAssertThrowsError(
            try PocketPadSkinScaffolder.write(
                name: "Bad",
                identifier: "com.example.bad",
                artboardID: "missing-artboard",
                to: temporaryDirectory.appendingPathComponent("missing")
            )
        ) { error in
            XCTAssertEqual(error as? PocketPadSkinScaffoldError, .unknownArtboard("missing-artboard"))
        }
    }
}
