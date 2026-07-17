import XCTest

@MainActor
final class PocketPadSkinQualityTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketPadSkinQualityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory { try? FileManager.default.removeItem(at: temporaryDirectory) }
    }

    func testCompiledHandcraftedWorkspacePassesRequiredQualityGates() throws {
        let (workspace, package) = try makeWorkspaceAndPackage()
        let report = PocketPadSkinQualityEvaluator.evaluate(package: package, workspace: workspace)

        XCTAssertTrue(report.isPassing, "\(report.errors)")
        XCTAssertEqual(report.checkedArtboardID, "classic-16-bit-v1")
        XCTAssertFalse(report.issues.contains { $0.code == "missing-artwork-variant" })
        XCTAssertFalse(report.issues.contains { $0.code == "missing-preview-variant" })
        XCTAssertFalse(report.issues.contains { $0.code == "missing-pressed-state" })
        XCTAssertFalse(report.issues.contains { $0.code == "canonical-template-incompatible" })
        XCTAssertGreaterThan(report.score, 50)
    }

    func testQualityGateFindsContrastStateAndVariantRegressions() throws {
        var (workspace, package) = try makeWorkspaceAndPackage()
        workspace.materials[0].foregroundColor = workspace.materials[0].baseColor
        workspace.materials[0].darkForegroundColor = workspace.materials[0].darkBaseColor ?? workspace.materials[0].baseColor

        package.manifest.previews.removeAll { $0.orientation == .portrait && $0.colorScheme == .dark }
        var skin = try XCTUnwrap(package.skin)
        XCTAssertFalse(skin.base.styleLibrary.styles.isEmpty)
        skin.base.styleLibrary.styles[0].visualStyle.pressed = nil
        package.skin = skin

        let report = PocketPadSkinQualityEvaluator.evaluate(package: package, workspace: workspace)
        let codes = Set(report.issues.map(\.code))
        XCTAssertFalse(report.isPassing)
        XCTAssertTrue(codes.contains("low-material-contrast"))
        XCTAssertTrue(codes.contains("missing-pressed-state"))
        XCTAssertTrue(codes.contains("missing-preview-variant"))
    }

    func testQualityReportScoreAndStrictStatusAreDeterministic() {
        let issues = [
            PocketPadSkinQualityIssue(severity: .warning, code: "warning", message: "Review"),
            PocketPadSkinQualityIssue(severity: .error, code: "error", message: "Fix")
        ]
        let report = PocketPadSkinQualityReport(issues: issues, checkedArtboardID: "showcase-controller-v1")
        XCTAssertEqual(report.score, 78)
        XCTAssertFalse(report.isPassing)
        XCTAssertFalse(report.isStrictlyPassing)
        XCTAssertEqual(report.errors.count, 1)
        XCTAssertEqual(report.warnings.count, 1)
    }

    private func makeWorkspaceAndPackage() throws -> (PocketPadSkinWorkspace, PocketPadSkinPackage) {
        let source = temporaryDirectory.appendingPathComponent("QualitySkin", isDirectory: true)
        var workspace = try PocketPadSkinScaffolder.write(
            name: "Quality Skin",
            identifier: "com.example.quality-skin",
            artboardID: "classic-16-bit-v1",
            to: source
        )
        workspace.author = PocketPadSkinAuthor(name: "Test Designer", url: URL(string: "https://example.com/designer"))
        workspace.summary = "A deliberate indigo hardware study with a layered shell, inset wells, and legible controls."
        workspace.license = "MIT"
        for index in workspace.materials.indices {
            workspace.materials[index].baseColor = "#11131A"
            workspace.materials[index].darkBaseColor = "#080A10"
            workspace.materials[index].foregroundColor = "#FFFFFF"
            workspace.materials[index].darkForegroundColor = "#FFFFFF"
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(workspace).write(
            to: source.appendingPathComponent(PocketPadSkinScaffolder.sourceFileName),
            options: .atomic
        )
        let compiled = try PocketPadSkinCompiler.compile(
            source: source,
            buildDirectory: source.appendingPathComponent("build", isDirectory: true),
            clean: true
        )
        return (workspace, compiled.package)
    }
}
