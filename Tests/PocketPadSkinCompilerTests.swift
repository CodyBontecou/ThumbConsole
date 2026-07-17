import Foundation
import XCTest

@MainActor
final class PocketPadSkinCompilerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketPadSkinCompilerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
    }

    func testCompilerProducesDeterministicPackageAssetsStatesAndBuildDirectory() throws {
        let source = try makePublishableWorkspace()
        let first = try PocketPadSkinCompiler.compile(source: source, clean: true, strict: true)
        let second = try PocketPadSkinCompiler.compile(source: source, clean: true, strict: true)

        XCTAssertEqual(first.packageData, second.packageData)
        XCTAssertEqual(first.package.manifest.identifier, "com.example.indigo-pocket")
        XCTAssertEqual(first.package.manifest.previews.count, 4)
        XCTAssertEqual(first.package.manifest.assets.count, 4)
        XCTAssertTrue(first.package.manifest.tags.contains("handcrafted"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.packageURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.buildDirectory.appendingPathComponent("skin.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.buildDirectory.appendingPathComponent("assets/canvas-landscape-dark.png").path))

        let report = PocketPadSkinPackageValidator.validate(second.package)
        XCTAssertTrue(report.isValid)
        XCTAssertTrue(report.warnings.isEmpty, "\(report.warnings)")

        let skin = try XCTUnwrap(second.package.skin)
        let dark = skin.appearance(orientation: .landscape, colorScheme: .dark)
        guard case .image(let background)? = dark.backgroundFillStyle else {
            return XCTFail("Expected compiled background image")
        }
        XCTAssertEqual(background.assetID, "canvas-landscape-dark")
        let action = dark.controlAppearance(for: .primaryAction)
        let styleID = try XCTUnwrap(action.styleID)
        let style = try XCTUnwrap(dark.styleLibrary.style(id: styleID)?.visualStyle)
        XCTAssertNotNil(style.pressed)
        XCTAssertNotNil(style.active)
        XCTAssertNotNil(style.disabled)
        XCTAssertLessThan(style.pressed?.scale ?? 1, 1)

        let png = try XCTUnwrap(second.package.assets["canvas-landscape-dark"])
        XCTAssertEqual(Array(png.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        XCTAssertEqual(readBigEndianUInt32(png, at: 16), 1748)
        XCTAssertEqual(readBigEndianUInt32(png, at: 20), 804)
    }

    func testWorkspaceDetectionDoesNotTreatExistingPackageAsJSONSource() throws {
        let workspace = temporaryDirectory.appendingPathComponent("Workspace", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        let source = workspace.appendingPathComponent(PocketPadSkinScaffolder.sourceFileName)
        try Data("{}".utf8).write(to: source)
        let package = temporaryDirectory.appendingPathComponent("skin.pocketpad")
        try Data([0x50, 0x4B, 0x03, 0x04]).write(to: package)

        XCTAssertTrue(PocketPadSkinCompiler.containsWorkspace(at: workspace))
        XCTAssertTrue(PocketPadSkinCompiler.containsWorkspace(at: source))
        XCTAssertFalse(PocketPadSkinCompiler.containsWorkspace(at: package))
    }

    func testSourceValidatorFindsBrokenIdentityReferencesColorsAndMatrix() throws {
        var workspace = PocketPadSkinWorkspace.starter(
            name: "Broken",
            identifier: "bad",
            artboardID: "classic-16-bit-v1"
        )
        workspace.version = "one"
        workspace.materials[0].baseColor = "not-a-color"
        workspace.components[0].materialID = "missing"
        workspace.assignments = [PocketPadSemanticStyleAssignment(materialID: "missing")]
        workspace.orientations = [.landscape]
        workspace.previews = []

        let report = PocketPadSkinSourceValidator.validate(workspace)
        let errors = Set(report.errors.map(\.code))
        let warnings = Set(report.warnings.map(\.code))
        XCTAssertTrue(errors.contains("invalid-identifier"))
        XCTAssertTrue(errors.contains("invalid-version"))
        XCTAssertTrue(errors.contains("invalid-color"))
        XCTAssertTrue(errors.contains("missing-material"))
        XCTAssertTrue(errors.contains("empty-assignment"))
        XCTAssertTrue(warnings.contains("incomplete-orientation-matrix"))
        XCTAssertTrue(warnings.contains("missing-preview-matrix"))
    }

    func testSVGSanitizerRejectsExecutableExternalAndPathologicalSources() throws {
        let safe = Data(#"<svg xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="a"/></defs><path fill="url(#a)" d="M0 0L1 1"/></svg>"#.utf8)
        XCTAssertEqual(try PocketPadSVGRasterizer.sanitize(safe), safe)

        for source in [
            #"<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>"#,
            #"<!DOCTYPE svg [<!ENTITY xxe SYSTEM "file:///etc/passwd">]><svg/>"#,
            #"<svg xmlns="http://www.w3.org/2000/svg"><image href="https://example.com/a.png"/></svg>"#,
            #"<svg xmlns="http://www.w3.org/2000/svg"><rect onclick="run()"/></svg>"#,
            #"<svg xmlns="http://www.w3.org/2000/svg"><style>.x{fill:url(https://example.com/a)}</style></svg>"#
        ] {
            XCTAssertThrowsError(try PocketPadSVGRasterizer.sanitize(Data(source.utf8)), source)
        }
        XCTAssertThrowsError(try PocketPadSVGRasterizer.sanitize(Data(repeating: 65, count: PocketPadSVGRasterizer.maximumSourceBytes + 1)))
    }

    func testVectorCompilerRejectsTraversalAndSymlinkSources() throws {
        let source = try makePublishableWorkspace()
        let sourceURL = source.appendingPathComponent("skin-source.json")
        var workspace = try JSONDecoder().decode(PocketPadSkinWorkspace.self, from: Data(contentsOf: sourceURL))
        workspace.sourceAssets[0].path = "sources/../outside.svg"
        try write(workspace, to: sourceURL)
        XCTAssertThrowsError(try PocketPadSkinCompiler.compile(source: source))

        workspace.sourceAssets[0].path = "sources/artwork/link.svg"
        try write(workspace, to: sourceURL)
        let outside = temporaryDirectory.appendingPathComponent("outside.svg")
        try Data(#"<svg xmlns="http://www.w3.org/2000/svg"/>"#.utf8).write(to: outside)
        let link = source.appendingPathComponent("sources/artwork/link.svg")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
        XCTAssertThrowsError(try PocketPadSkinCompiler.compile(source: source))
    }

    private func makePublishableWorkspace() throws -> URL {
        let source = temporaryDirectory.appendingPathComponent("IndigoPocket", isDirectory: true)
        var workspace = try PocketPadSkinScaffolder.write(
            name: "Indigo Pocket",
            identifier: "com.example.indigo-pocket",
            artboardID: "classic-16-bit-v1",
            to: source
        )
        workspace.author = PocketPadSkinAuthor(name: "Example Designer", url: URL(string: "https://example.com"))
        workspace.summary = "A carefully authored translucent indigo controller with rubber movement controls and glossy action buttons."
        workspace.license = "MIT"
        try write(workspace, to: source.appendingPathComponent("skin-source.json"))
        return source
    }

    private func write(_ workspace: PocketPadSkinWorkspace, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(workspace).write(to: url, options: .atomic)
    }

    private func readBigEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }
}
