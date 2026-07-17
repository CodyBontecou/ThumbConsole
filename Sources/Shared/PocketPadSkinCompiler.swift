import Foundation

public enum PocketPadSkinSourceIssueSeverity: String, Codable, Equatable, Sendable {
    case warning
    case error
}

public struct PocketPadSkinSourceIssue: Codable, Equatable, Sendable {
    public var severity: PocketPadSkinSourceIssueSeverity
    public var code: String
    public var message: String
    public var path: String?

    public init(
        severity: PocketPadSkinSourceIssueSeverity,
        code: String,
        message: String,
        path: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.path = path
    }
}

public struct PocketPadSkinSourceValidationReport: Codable, Equatable, Sendable {
    public var issues: [PocketPadSkinSourceIssue]

    public init(issues: [PocketPadSkinSourceIssue]) {
        self.issues = issues
    }

    public var errors: [PocketPadSkinSourceIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [PocketPadSkinSourceIssue] { issues.filter { $0.severity == .warning } }
    public var isValid: Bool { errors.isEmpty }
}

public enum PocketPadSkinSourceValidator {
    public static func validate(_ workspace: PocketPadSkinWorkspace) -> PocketPadSkinSourceValidationReport {
        var issues: [PocketPadSkinSourceIssue] = []
        func issue(_ severity: PocketPadSkinSourceIssueSeverity, _ code: String, _ message: String, _ path: String? = nil) {
            issues.append(.init(severity: severity, code: code, message: message, path: path))
        }
        guard workspace.schema == PocketPadSkinWorkspaceSchema.identifier else {
            issue(.error, "invalid-source-schema", "Unknown skin source schema.", "schema")
            return PocketPadSkinSourceValidationReport(issues: issues)
        }
        if workspace.schemaVersion > PocketPadSkinWorkspaceSchema.currentVersion || workspace.schemaVersion < 1 {
            issue(.error, "unsupported-source-version", "Unsupported skin source schema version.", "schemaVersion")
        }
        if !PocketPadSkinPackageValidator.isValidReverseDNSIdentifier(workspace.identifier) {
            issue(.error, "invalid-identifier", "Use a reverse-DNS package identifier.", "identifier")
        }
        if PocketPadSemanticVersion(workspace.version) == nil {
            issue(.error, "invalid-version", "Use a semantic version such as 1.0.0.", "version")
        }
        if workspace.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issue(.error, "missing-name", "Give the skin a name.", "name")
        }
        if workspace.author.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "your name" {
            issue(.warning, "placeholder-author", "Replace the scaffold author before publication.", "author.name")
        }
        if workspace.summary.trimmingCharacters(in: .whitespacesAndNewlines).count < 20 {
            issue(.warning, "short-summary", "Describe the skin's visual direction and material language.", "summary")
        }
        guard let artboard = PocketPadSkinArtboardCatalog.resolve(workspace.artboardID) else {
            issue(.error, "missing-artboard", "Unknown canonical artboard \(workspace.artboardID).", "artboardID")
            return PocketPadSkinSourceValidationReport(issues: issues)
        }

        checkUnique(workspace.palette.map(\.id), path: "palette", issues: &issues)
        checkUnique(workspace.materials.map(\.id), path: "materials", issues: &issues)
        checkUnique(workspace.components.map(\.id), path: "components", issues: &issues)
        checkUnique(workspace.sourceAssets.map(\.id), path: "sourceAssets", issues: &issues)
        checkUnique(workspace.previews.map(\.id), path: "previews", issues: &issues)

        let materialIDs = Set(workspace.materials.map(\.id))
        for (index, material) in workspace.materials.enumerated() {
            let values = [material.baseColor, material.foregroundColor]
                + [material.darkBaseColor, material.darkForegroundColor, material.strokeColor, material.highlightColor, material.activeColor, material.shadowColor].compactMap { $0 }
            for value in values where GamepadRGBAColor(hexString: value) == nil {
                issue(.error, "invalid-color", "Invalid material color \(value).", "materials[\(index)]")
            }
            if !(0...1).contains(material.depth) || !(0...1).contains(material.gloss) {
                issue(.error, "invalid-material-range", "Material depth and gloss must be between 0 and 1.", "materials[\(index)]")
            }
            if !(0.5...1).contains(material.pressedScale) {
                issue(.error, "invalid-pressed-scale", "Pressed scale must be between 0.5 and 1.", "materials[\(index)].pressedScale")
            }
        }
        for (index, component) in workspace.components.enumerated() where !materialIDs.contains(component.materialID) {
            issue(.error, "missing-material", "Component references missing material \(component.materialID).", "components[\(index)].materialID")
        }
        for (index, assignment) in workspace.assignments.enumerated() {
            if assignment.role == nil && assignment.button == nil {
                issue(.error, "empty-assignment", "A semantic assignment needs a role or button.", "assignments[\(index)]")
            }
            if !materialIDs.contains(assignment.materialID) {
                issue(.error, "missing-material", "Assignment references missing material \(assignment.materialID).", "assignments[\(index)].materialID")
            }
        }
        if workspace.assignments.isEmpty {
            issue(.error, "missing-assignments", "Assign materials to semantic control roles.", "assignments")
        }
        let assignedRoles = Set(workspace.assignments.compactMap(\.role))
        for role in artboard.expectedRoles where role != .system && role != .decoration && !assignedRoles.contains(role) {
            issue(.warning, "unstyled-role", "Canonical artboard role \(role.rawValue) has no explicit material assignment.", "assignments")
        }
        for orientation in workspace.orientations where !artboard.variants.contains(where: { $0.orientation == orientation }) {
            issue(.error, "unsupported-orientation", "The artboard has no \(orientation.rawValue) variant.", "orientations")
        }
        if Set(workspace.orientations) != Set(PocketPadSkinOrientation.allCases) {
            issue(.warning, "incomplete-orientation-matrix", "Directory-quality skins should intentionally support portrait and landscape.", "orientations")
        }
        if Set(workspace.colorSchemes) != Set(PocketPadSkinColorScheme.allCases) {
            issue(.warning, "incomplete-color-matrix", "Directory-quality skins should intentionally support light and dark.", "colorSchemes")
        }
        for (index, asset) in workspace.sourceAssets.enumerated() {
            if !PocketPadSkinPackageCodec.isSafePackagePath(asset.path, requiredRoot: "sources") {
                issue(.error, "unsafe-source-path", "Source assets must stay below sources/.", "sourceAssets[\(index)].path")
            }
            if !(16...4096).contains(asset.outputWidth) || !(16...4096).contains(asset.outputHeight) {
                issue(.error, "invalid-source-dimensions", "Source raster dimensions must be 16...4096.", "sourceAssets[\(index)]")
            }
            if asset.format != .png {
                issue(.warning, "unsupported-raster-format", "The current compiler emits deterministic PNG; WebP is reserved for a future encoder.", "sourceAssets[\(index)].format")
            }
        }
        if workspace.previews.isEmpty {
            issue(.warning, "missing-preview-matrix", "Declare native preview requests for visual review.", "previews")
        }
        return PocketPadSkinSourceValidationReport(issues: issues)
    }

    private static func checkUnique(
        _ ids: [String],
        path: String,
        issues: inout [PocketPadSkinSourceIssue]
    ) {
        var seen = Set<String>()
        for id in ids {
            let normalized = GamepadStyleToken.normalizedIdentifier(id)
            if normalized.isEmpty {
                issues.append(.init(severity: .error, code: "invalid-id", message: "IDs cannot be empty.", path: path))
            } else if !seen.insert(normalized).inserted {
                issues.append(.init(severity: .error, code: "duplicate-id", message: "Duplicate ID \(normalized).", path: path))
            }
        }
    }
}

public enum PocketPadSkinCompilerError: Error, LocalizedError {
    case missingSource(URL)
    case invalidSource(PocketPadSkinSourceValidationReport)
    case strictWarnings(PocketPadSkinSourceValidationReport)
    case cannotPrepareBuild(String)
    case unsupportedPlatform

    public var errorDescription: String? {
        switch self {
        case .missingSource(let url): "No skin-source.json exists at \(url.path)."
        case .invalidSource(let report): report.errors.first?.message ?? "Skin source validation failed."
        case .strictWarnings(let report): report.warnings.first?.message ?? "Strict skin source validation failed."
        case .cannotPrepareBuild(let message): "Could not prepare generated skin build: \(message)"
        case .unsupportedPlatform: "Skin compilation is supported by the macOS authoring CLI."
        }
    }
}

public struct PocketPadSkinCompilationResult: Sendable {
    public var workspace: PocketPadSkinWorkspace
    public var sourceReport: PocketPadSkinSourceValidationReport
    public var package: PocketPadSkinPackage
    public var packageData: Data
    public var buildDirectory: URL
    public var packageURL: URL

    public init(
        workspace: PocketPadSkinWorkspace,
        sourceReport: PocketPadSkinSourceValidationReport,
        package: PocketPadSkinPackage,
        packageData: Data,
        buildDirectory: URL,
        packageURL: URL
    ) {
        self.workspace = workspace
        self.sourceReport = sourceReport
        self.package = package
        self.packageData = packageData
        self.buildDirectory = buildDirectory
        self.packageURL = packageURL
    }
}

public enum PocketPadSkinCompiler {
    public static func sourceURL(for input: URL) -> URL {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: input.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return input.appendingPathComponent(PocketPadSkinScaffolder.sourceFileName)
        }
        return input
    }

    public static func containsWorkspace(at input: URL, fileManager: FileManager = .default) -> Bool {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: input.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return fileManager.fileExists(
                atPath: input.appendingPathComponent(PocketPadSkinScaffolder.sourceFileName).path
            )
        }
        return input.lastPathComponent == PocketPadSkinScaffolder.sourceFileName
            && fileManager.fileExists(atPath: input.path)
    }

    public static func loadWorkspace(from input: URL) throws -> (workspace: PocketPadSkinWorkspace, root: URL) {
        let source = sourceURL(for: input)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw PocketPadSkinCompilerError.missingSource(source)
        }
        let workspace = try JSONDecoder().decode(
            PocketPadSkinWorkspace.self,
            from: Data(contentsOf: source, options: [.mappedIfSafe])
        )
        return (workspace, source.deletingLastPathComponent())
    }

    public static func compile(
        source input: URL,
        buildDirectory requestedBuildDirectory: URL? = nil,
        packageOutputURL: URL? = nil,
        clean: Bool = false,
        strict: Bool = false,
        fileManager: FileManager = .default
    ) throws -> PocketPadSkinCompilationResult {
        #if !os(macOS)
        throw PocketPadSkinCompilerError.unsupportedPlatform
        #else
        let loaded = try loadWorkspace(from: input)
        let report = PocketPadSkinSourceValidator.validate(loaded.workspace)
        guard report.isValid else { throw PocketPadSkinCompilerError.invalidSource(report) }
        if strict, !report.warnings.isEmpty { throw PocketPadSkinCompilerError.strictWarnings(report) }
        let canvases = try PocketPadVectorCompiler.compileCanvases(
            workspace: loaded.workspace,
            sourceRoot: loaded.root,
            fileManager: fileManager
        )
        let package = try makePackage(workspace: loaded.workspace, canvases: canvases)
        let packageData = try PocketPadSkinPackageCodec.encode(package)
        let decodedPackage = try PocketPadSkinPackageCodec.decode(packageData)
        let buildDirectory = requestedBuildDirectory ?? loaded.root.appendingPathComponent("build", isDirectory: true)
        let staging = buildDirectory.deletingLastPathComponent()
            .appendingPathComponent(".\(buildDirectory.lastPathComponent).staging-\(UUID().uuidString)", isDirectory: true)
        do {
            if fileManager.fileExists(atPath: staging.path) { try fileManager.removeItem(at: staging) }
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            try writeGeneratedPackageDirectory(decodedPackage, to: staging, fileManager: fileManager)
            let filename = suggestedFilename(loaded.workspace)
            let stagedPackage = staging.appendingPathComponent(filename)
            try packageData.write(to: stagedPackage, options: .atomic)
            if clean, fileManager.fileExists(atPath: buildDirectory.path) {
                try fileManager.removeItem(at: buildDirectory)
            }
            if fileManager.fileExists(atPath: buildDirectory.path) {
                try fileManager.removeItem(at: buildDirectory)
            }
            try fileManager.moveItem(at: staging, to: buildDirectory)
            let builtPackage = buildDirectory.appendingPathComponent(filename)
            if let packageOutputURL {
                try fileManager.createDirectory(at: packageOutputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try packageData.write(to: packageOutputURL, options: .atomic)
            }
            return PocketPadSkinCompilationResult(
                workspace: loaded.workspace,
                sourceReport: report,
                package: decodedPackage,
                packageData: packageData,
                buildDirectory: buildDirectory,
                packageURL: packageOutputURL ?? builtPackage
            )
        } catch let error as PocketPadSkinCompilerError {
            throw error
        } catch {
            try? fileManager.removeItem(at: staging)
            throw PocketPadSkinCompilerError.cannotPrepareBuild(error.localizedDescription)
        }
        #endif
    }

    private static func makePackage(
        workspace: PocketPadSkinWorkspace,
        canvases: [PocketPadCompiledCanvas]
    ) throws -> PocketPadSkinPackage {
        let materialByID = Dictionary(uniqueKeysWithValues: workspace.materials.map { ($0.id, $0) })
        let lightStyles = workspace.materials.compactMap { materialStyle($0, scheme: .light) }
        let darkStyles = workspace.materials.compactMap { materialStyle($0, scheme: .dark) }
        let roleRules = workspace.assignments.compactMap { assignment -> PocketPadSkinRoleRule? in
            guard let role = assignment.role, materialByID[assignment.materialID] != nil else { return nil }
            return PocketPadSkinRoleRule(
                role: role,
                appearance: PocketPadSkinControlAppearance(styleID: assignment.materialID)
            )
        }
        let buttonRules = workspace.assignments.compactMap { assignment -> PocketPadSkinButtonRule? in
            guard let button = assignment.button, materialByID[assignment.materialID] != nil else { return nil }
            return PocketPadSkinButtonRule(
                button: button,
                appearance: PocketPadSkinControlAppearance(styleID: assignment.materialID)
            )
        }
        let base = PocketPadSkinAppearance(
            accentStyle: .purple,
            showsButtonLabels: true,
            roleRules: roleRules,
            buttonRules: buttonRules,
            styleLibrary: GamepadStyleLibrary(styles: lightStyles)
        )
        var variants: [PocketPadSkinVariant] = []
        for scheme in workspace.colorSchemes {
            variants.append(PocketPadSkinVariant(
                id: "styles-\(scheme.rawValue)",
                colorScheme: scheme,
                appearance: PocketPadSkinAppearance(
                    styleLibrary: GamepadStyleLibrary(styles: scheme == .dark ? darkStyles : lightStyles)
                )
            ))
        }
        for canvas in canvases {
            let image = GamepadImageFill(
                assetID: canvas.id,
                fileName: "\(canvas.id).png",
                contentMode: .fill
            )
            variants.append(PocketPadSkinVariant(
                id: "canvas-\(canvas.orientation.rawValue)-\(canvas.colorScheme.rawValue)",
                orientation: canvas.orientation,
                colorScheme: canvas.colorScheme,
                appearance: PocketPadSkinAppearance(backgroundFillStyle: .image(image))
            ))
        }
        let skin = PocketPadSkin(base: base, variants: variants)
        let assetDescriptors = canvases.map { canvas in
            PocketPadSkinResourceDescriptor(
                id: canvas.id,
                path: "assets/\(canvas.id).png",
                contentType: "image/png",
                role: .background,
                byteCount: canvas.data.count,
                sha256: canvas.data.pocketPadSHA256
            )
        }
        let previewDescriptors = canvases.map { canvas in
            PocketPadSkinPreviewDescriptor(
                id: "preview-\(canvas.id)",
                path: "previews/\(canvas.id).png",
                orientation: canvas.orientation,
                colorScheme: canvas.colorScheme,
                byteCount: canvas.data.count,
                sha256: canvas.data.pocketPadSHA256
            )
        }
        let artboard = PocketPadSkinArtboardCatalog.resolve(workspace.artboardID)
        let compatibleRoles = (artboard?.expectedRoles ?? [])
            .filter { ![GamepadVisualRole.system, .decoration, .custom].contains($0) }
        return PocketPadSkinPackage(
            manifest: PocketPadSkinManifest(
                identifier: workspace.identifier,
                version: workspace.version,
                name: workspace.name,
                author: workspace.author,
                summary: workspace.summary,
                license: workspace.license,
                minimumAppVersion: "1.0.0",
                tags: ["handcrafted", "agent-source", workspace.artboardID],
                assets: assetDescriptors,
                previews: previewDescriptors,
                compatibility: PocketPadSkinCompatibility(
                    mode: .templateAligned,
                    templates: artboard.map {
                        [PocketPadSkinTemplateRequirement(templateID: $0.templateID, minimumRevision: $0.revision, maximumRevision: $0.revision)]
                    } ?? [],
                    orientations: workspace.orientations,
                    minimumAspectRatio: 0.4,
                    maximumAspectRatio: 2.5,
                    requiredRoles: compatibleRoles,
                    requiredFeatures: [.bitmapControlStates]
                )
            ),
            skin: skin,
            assets: Dictionary(uniqueKeysWithValues: canvases.map { ($0.id, $0.data) }),
            previews: Dictionary(uniqueKeysWithValues: canvases.map { ("preview-\($0.id)", $0.data) })
        )
    }

    private static func materialStyle(
        _ material: PocketPadSkinMaterialSpec,
        scheme: PocketPadSkinColorScheme
    ) -> GamepadStyleToken? {
        guard let base = GamepadRGBAColor(hexString: scheme == .dark ? (material.darkBaseColor ?? material.baseColor) : material.baseColor),
              let foreground = GamepadRGBAColor(hexString: scheme == .dark ? (material.darkForegroundColor ?? material.foregroundColor) : material.foregroundColor)
        else { return nil }
        let highlight = GamepadRGBAColor(hexString: material.highlightColor ?? "#FFFFFF") ?? foreground
        let activeAccent = GamepadRGBAColor(hexString: material.activeColor ?? material.highlightColor ?? material.foregroundColor) ?? foreground
        let shadow = GamepadRGBAColor(hexString: material.shadowColor ?? "#000000") ?? .defaultValue
        let stroke = GamepadRGBAColor(hexString: material.strokeColor ?? material.highlightColor ?? material.foregroundColor) ?? foreground
        let depth = min(max(material.depth, 0), 1)
        let gloss = min(max(material.gloss, 0), 1)
        let isMatte = material.kind == .matteRubber || material.kind == .inset
        let isLacquer = material.kind == .glossyPlastic
        let surfaceHighlightRadius: CGFloat = isMatte ? 2.4 : (isLacquer ? 0.6 : 1 + gloss * 1.4)
        let surfaceHighlightOpacity: CGFloat = isMatte ? 0.07 : (isLacquer ? 0.25 : 0.08 + gloss * 0.14)
        let surfaceBevelWidth: CGFloat = isMatte ? 0.75 : (isLacquer ? 1.6 : 0.6 + depth * 1.1)
        let fill: GamepadFillStyle
        switch material.kind {
        case .matteRubber, .inset:
            fill = .solid(base)
        default:
            fill = .gradient(GamepadGradientFill(
                type: .linear,
                angleDegrees: 135,
                stops: [
                    GamepadGradientStop(offset: 0, color: base.mixed(with: highlight, amount: 0.22 + gloss * 0.34)),
                    GamepadGradientStop(offset: 0.38, color: base),
                    GamepadGradientStop(offset: 1, color: base.mixed(with: shadow, amount: 0.22 + depth * 0.28))
                ]
            ))
        }
        let normal = GamepadControlStateStyle(
            fillStyle: fill,
            foregroundColor: foreground,
            strokeColor: stroke.withAlpha(0.34 + gloss * 0.38),
            strokeWidth: 0.8 + gloss * 1.2,
            shadows: [
                GamepadControlShadowStyle(
                    color: shadow.withAlpha(0.28 + depth * 0.22),
                    radius: 2 + depth * 3,
                    x: 1.5 + depth * 2,
                    y: 2 + depth * 2.5
                )
            ],
            innerShadowColor: material.kind == .inset ? shadow.withAlpha(0.42) : nil,
            innerShadowRadius: material.kind == .inset ? 7 : nil,
            innerShadowX: material.kind == .inset ? 3 : nil,
            innerShadowY: material.kind == .inset ? 4 : nil,
            highlightColor: highlight,
            highlightRadius: surfaceHighlightRadius,
            highlightX: -1 - gloss,
            highlightY: -1 - gloss,
            highlightOpacity: surfaceHighlightOpacity,
            bevelHighlightColor: highlight.withAlpha(isLacquer ? 0.72 : 0.24 + gloss * 0.24),
            bevelShadowColor: shadow.withAlpha(0.25 + depth * 0.30),
            bevelWidth: surfaceBevelWidth
        )
        let pressed = GamepadControlStateStyle(
            fillStyle: .solid(base.mixed(with: shadow, amount: 0.10 + depth * 0.12)),
            shadows: [GamepadControlShadowStyle(color: shadow.withAlpha(0.20), radius: 5, x: 2, y: 3)],
            innerShadowColor: shadow.withAlpha(0.42 + depth * 0.22),
            innerShadowRadius: 5 + depth * 6,
            innerShadowX: 2 + depth * 2,
            innerShadowY: 3 + depth * 2,
            highlightOpacity: 0.04,
            scale: material.pressedScale
        )
        let active = GamepadControlStateStyle(
            strokeColor: activeAccent.withAlpha(0.96),
            strokeWidth: 1.5 + gloss * 0.5,
            highlightColor: highlight,
            highlightRadius: surfaceHighlightRadius,
            highlightX: -1 - gloss,
            highlightY: -1 - gloss,
            highlightOpacity: surfaceHighlightOpacity,
            scale: 1
        )
        let disabled = GamepadControlStateStyle(
            fillStyle: .solid(base.mixed(with: shadow, amount: 0.14)),
            foregroundColor: foreground,
            strokeColor: stroke.mixed(with: base, amount: 0.36),
            strokeWidth: 0.8,
            shadows: [],
            highlightOpacity: 0,
            bevelHighlightColor: highlight.withAlpha(0.12),
            bevelShadowColor: shadow.withAlpha(0.20),
            bevelWidth: 0.6,
            opacity: 0.90,
            scale: 1
        )
        let style = GamepadControlVisualStyle(
            normal: normal,
            pressed: pressed,
            active: active,
            disabled: disabled,
            hapticFeedback: material.hapticFeedback
        )
        return GamepadStyleToken(
            id: material.id,
            name: material.name,
            visualStyle: style
        ).normalized
    }

    private static func writeGeneratedPackageDirectory(
        _ package: PocketPadSkinPackage,
        to directory: URL,
        fileManager: FileManager
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(package.manifest).write(
            to: directory.appendingPathComponent("manifest.json"),
            options: .atomic
        )
        if let skin = package.skin {
            try encoder.encode(skin).write(to: directory.appendingPathComponent("skin.json"), options: .atomic)
        }
        for descriptor in package.manifest.assets {
            guard let data = package.assets[descriptor.id] else { continue }
            let url = directory.appendingPathComponent(descriptor.path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
        for descriptor in package.manifest.previews {
            guard let data = package.previews[descriptor.id] else { continue }
            let url = directory.appendingPathComponent(descriptor.path)
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }
    }

    private static func suggestedFilename(_ workspace: PocketPadSkinWorkspace) -> String {
        let slug = workspace.name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { result, character in
                if character == "-", result.last == "-" { return }
                result.append(character)
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(slug)-\(workspace.version).pocketpad"
    }
}
