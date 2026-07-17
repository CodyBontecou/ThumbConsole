import CryptoKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

public extension UTType {
    static let pocketPadSkinPackage = UTType(
        exportedAs: "com.codybontecou.pocketpad.skin-package",
        conformingTo: .zip
    )
}

public enum PocketPadPackageKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case skin
    case layout
    case pack

    public var id: String { rawValue }
}

public struct PocketPadSkinAuthor: Codable, Equatable, Sendable {
    public var name: String
    public var url: URL?

    public init(name: String, url: URL? = nil) {
        self.name = name
        self.url = url
    }

    public var normalized: PocketPadSkinAuthor {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return PocketPadSkinAuthor(name: String((trimmed.isEmpty ? "Unknown Creator" : trimmed).prefix(80)), url: url)
    }
}

public struct PocketPadSkinResourceDescriptor: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var path: String
    public var contentType: String
    public var role: GamepadAssetRole
    public var byteCount: Int
    public var sha256: String

    public init(
        id: String,
        path: String,
        contentType: String,
        role: GamepadAssetRole,
        byteCount: Int,
        sha256: String
    ) {
        self.id = id
        self.path = path
        self.contentType = contentType
        self.role = role
        self.byteCount = byteCount
        self.sha256 = sha256
    }

    public var normalized: PocketPadSkinResourceDescriptor {
        PocketPadSkinResourceDescriptor(
            id: GamepadStyleToken.normalizedIdentifier(id),
            path: path.trimmingCharacters(in: .whitespacesAndNewlines),
            contentType: String(contentType.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)),
            role: role,
            byteCount: max(0, byteCount),
            sha256: sha256.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

public struct PocketPadSkinPreviewDescriptor: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var path: String
    public var orientation: PocketPadSkinOrientation
    public var colorScheme: PocketPadSkinColorScheme?
    public var byteCount: Int
    public var sha256: String

    public init(
        id: String,
        path: String,
        orientation: PocketPadSkinOrientation,
        colorScheme: PocketPadSkinColorScheme? = nil,
        byteCount: Int,
        sha256: String
    ) {
        self.id = id
        self.path = path
        self.orientation = orientation
        self.colorScheme = colorScheme
        self.byteCount = byteCount
        self.sha256 = sha256
    }

    public var normalized: PocketPadSkinPreviewDescriptor {
        PocketPadSkinPreviewDescriptor(
            id: GamepadStyleToken.normalizedIdentifier(id),
            path: path.trimmingCharacters(in: .whitespacesAndNewlines),
            orientation: orientation,
            colorScheme: colorScheme,
            byteCount: max(0, byteCount),
            sha256: sha256.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

public struct PocketPadSkinManifest: Codable, Equatable, Sendable {
    public static let schemaIdentifier = "com.codybontecou.pocketpad.skin-package"
    public static let currentSchemaVersion = 2

    public var schema: String
    public var schemaVersion: Int
    public var identifier: String
    public var version: String
    public var kind: PocketPadPackageKind
    public var name: String
    public var author: PocketPadSkinAuthor
    public var summary: String
    public var license: String
    public var homepage: URL?
    public var minimumAppVersion: String?
    public var tags: [String]
    public var skinPath: String?
    public var skinSHA256: String?
    public var profilePath: String?
    public var profileSHA256: String?
    public var assets: [PocketPadSkinResourceDescriptor]
    public var previews: [PocketPadSkinPreviewDescriptor]
    public var compatibility: PocketPadSkinCompatibility?

    public init(
        schema: String = Self.schemaIdentifier,
        schemaVersion: Int = Self.currentSchemaVersion,
        identifier: String,
        version: String,
        kind: PocketPadPackageKind = .skin,
        name: String,
        author: PocketPadSkinAuthor,
        summary: String = "",
        license: String = "All Rights Reserved",
        homepage: URL? = nil,
        minimumAppVersion: String? = nil,
        tags: [String] = [],
        skinPath: String? = "skin.json",
        skinSHA256: String? = nil,
        profilePath: String? = nil,
        profileSHA256: String? = nil,
        assets: [PocketPadSkinResourceDescriptor] = [],
        previews: [PocketPadSkinPreviewDescriptor] = [],
        compatibility: PocketPadSkinCompatibility? = nil
    ) {
        self.schema = schema
        self.schemaVersion = schemaVersion
        self.identifier = identifier
        self.version = version
        self.kind = kind
        self.name = name
        self.author = author
        self.summary = summary
        self.license = license
        self.homepage = homepage
        self.minimumAppVersion = minimumAppVersion
        self.tags = tags
        self.skinPath = skinPath
        self.skinSHA256 = skinSHA256
        self.profilePath = profilePath
        self.profileSHA256 = profileSHA256
        self.assets = assets
        self.previews = previews
        self.compatibility = compatibility
    }

    public var normalized: PocketPadSkinManifest {
        let normalizedTags = Array(Set(tags.compactMap { tag -> String? in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(40))
        })).sorted()
        return PocketPadSkinManifest(
            schema: schema.trimmingCharacters(in: .whitespacesAndNewlines),
            schemaVersion: schemaVersion,
            identifier: identifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            version: version.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            name: String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)),
            author: author.normalized,
            summary: String(summary.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500)),
            license: String(license.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)),
            homepage: homepage,
            minimumAppVersion: minimumAppVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: normalizedTags,
            skinPath: skinPath?.trimmingCharacters(in: .whitespacesAndNewlines),
            skinSHA256: skinSHA256?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            profilePath: profilePath?.trimmingCharacters(in: .whitespacesAndNewlines),
            profileSHA256: profileSHA256?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            assets: assets.map(\.normalized),
            previews: previews.map(\.normalized),
            compatibility: compatibility?.normalized
        )
    }
}

public struct PocketPadSemanticVersion: Comparable, CustomStringConvertible, Equatable, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?

    public init?(_ value: String) {
        let buildSplit = value.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)
        let releaseSplit = buildSplit[0].split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let core = releaseSplit[0].split(separator: ".", omittingEmptySubsequences: false)
        guard core.count == 3,
              let major = Int(core[0]), major >= 0,
              let minor = Int(core[1]), minor >= 0,
              let patch = Int(core[2]), patch >= 0
        else { return nil }
        let prerelease = releaseSplit.count == 2 ? String(releaseSplit[1]) : nil
        if let prerelease, prerelease.isEmpty { return nil }
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
    }

    public var description: String {
        "\(major).\(minor).\(patch)" + (prerelease.map { "-\($0)" } ?? "")
    }

    public static func < (lhs: PocketPadSemanticVersion, rhs: PocketPadSemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil): return false
        case (nil, .some): return false
        case (.some, nil): return true
        case let (.some(lhs), .some(rhs)): return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }
}

public struct PocketPadSkinPackage: Equatable, Sendable {
    public var manifest: PocketPadSkinManifest
    public var skin: PocketPadSkin?
    public var profile: GamepadConfigurationProfile?
    /// Resource data keyed by manifest asset ID.
    public var assets: [String: Data]
    /// Preview data keyed by manifest preview ID.
    public var previews: [String: Data]

    public init(
        manifest: PocketPadSkinManifest,
        skin: PocketPadSkin? = nil,
        profile: GamepadConfigurationProfile? = nil,
        assets: [String: Data] = [:],
        previews: [String: Data] = [:]
    ) {
        self.manifest = manifest
        self.skin = skin
        self.profile = profile
        self.assets = assets
        self.previews = previews
    }
}

public enum PocketPadSkinValidationSeverity: String, Codable, Sendable {
    case warning
    case error
}

public struct PocketPadSkinValidationIssue: Codable, Equatable, Identifiable, Sendable {
    public var severity: PocketPadSkinValidationSeverity
    public var code: String
    public var message: String
    public var path: String?

    public init(severity: PocketPadSkinValidationSeverity, code: String, message: String, path: String? = nil) {
        self.severity = severity
        self.code = code
        self.message = message
        self.path = path
    }

    public var id: String { [severity.rawValue, code, path ?? "", message].joined(separator: ":") }
}

public struct PocketPadSkinValidationReport: Codable, Equatable, Sendable {
    public var issues: [PocketPadSkinValidationIssue]

    public init(issues: [PocketPadSkinValidationIssue] = []) {
        self.issues = issues
    }

    public var errors: [PocketPadSkinValidationIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [PocketPadSkinValidationIssue] { issues.filter { $0.severity == .warning } }
    public var isValid: Bool { errors.isEmpty }
}

public enum PocketPadSkinPackageValidator {
    public static func validate(_ package: PocketPadSkinPackage) -> PocketPadSkinValidationReport {
        let manifest = package.manifest.normalized
        var issues: [PocketPadSkinValidationIssue] = []

        func error(_ code: String, _ message: String, path: String? = nil) {
            issues.append(PocketPadSkinValidationIssue(severity: .error, code: code, message: message, path: path))
        }
        func warning(_ code: String, _ message: String, path: String? = nil) {
            issues.append(PocketPadSkinValidationIssue(severity: .warning, code: code, message: message, path: path))
        }

        if manifest.schema != PocketPadSkinManifest.schemaIdentifier {
            error("unsupported-schema", "Unsupported package schema \(manifest.schema).", path: "manifest.json")
        }
        if manifest.schemaVersion < 1 || manifest.schemaVersion > PocketPadSkinManifest.currentSchemaVersion {
            error("unsupported-schema-version", "Unsupported schema version \(manifest.schemaVersion).", path: "manifest.json")
        }
        if !isValidReverseDNSIdentifier(manifest.identifier) {
            error("invalid-identifier", "Identifier must use reverse-DNS form, for example com.creator.skin-name.", path: "manifest.identifier")
        }
        if PocketPadSemanticVersion(manifest.version) == nil {
            error("invalid-version", "Package version must be semantic versioning in major.minor.patch form.", path: "manifest.version")
        }
        if manifest.name.isEmpty {
            error("missing-name", "Package name cannot be empty.", path: "manifest.name")
        }
        if manifest.author.name.isEmpty {
            error("missing-author", "Package author cannot be empty.", path: "manifest.author.name")
        }
        if manifest.license.isEmpty {
            warning("missing-license", "Add a license so community members know how the skin may be shared.", path: "manifest.license")
        }
        if let rawCompatibility = package.manifest.compatibility {
            let compatibility = rawCompatibility.normalized
            if manifest.schemaVersion < 2 {
                error("compatibility-requires-v2", "Compatibility declarations require package schema version 2.", path: "manifest.compatibility")
            }
            if compatibility.mode == .templateAligned, compatibility.templates.isEmpty {
                error("missing-template-requirement", "Template-aligned skins must name at least one canonical template.", path: "manifest.compatibility.templates")
            }
            if compatibility.orientations.isEmpty {
                error("missing-compatible-orientation", "Compatibility must declare at least one orientation.", path: "manifest.compatibility.orientations")
            }
            let minimumAspect = rawCompatibility.minimumAspectRatio
            let maximumAspect = rawCompatibility.maximumAspectRatio
            let hasInvalidAspect = minimumAspect.map { !$0.isFinite || !(0.25...4).contains($0) } == true
                || maximumAspect.map { !$0.isFinite || !(0.25...4).contains($0) } == true
                || (minimumAspect != nil && maximumAspect != nil && minimumAspect! > maximumAspect!)
            if hasInvalidAspect {
                error("invalid-aspect-range", "Aspect ratios must be finite values from 0.25 through 4, and minimum cannot exceed maximum.", path: "manifest.compatibility")
            }
            var templateIDs = Set<String>()
            for (index, requirement) in rawCompatibility.templates.enumerated() {
                let templateID = requirement.templateID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if templateID.isEmpty {
                    error("invalid-template-requirement", "Template IDs cannot be empty.", path: "manifest.compatibility.templates[\(index)]")
                }
                if requirement.minimumRevision < 1
                    || requirement.maximumRevision.map({ $0 < requirement.minimumRevision }) == true {
                    error("invalid-template-revision-range", "Template revision ranges must begin at 1 or later and maximum cannot precede minimum.", path: "manifest.compatibility.templates[\(index)]")
                }
                if !templateID.isEmpty, !templateIDs.insert(templateID).inserted {
                    error("duplicate-template-requirement", "Each canonical template may appear only once.", path: "manifest.compatibility.templates[\(index)]")
                }
            }
        }

        switch manifest.kind {
        case .skin:
            if package.skin == nil { error("missing-skin", "Skin packages must contain skin.json.", path: manifest.skinPath) }
            if package.profile != nil { error("unexpected-profile", "Appearance-only skins cannot contain keypad profiles or executable bindings.", path: manifest.profilePath) }
        case .layout:
            if package.profile == nil { error("missing-profile", "Layout packages must contain profile.json.", path: manifest.profilePath) }
        case .pack:
            if package.skin == nil { error("missing-skin", "Full packs must contain skin.json.", path: manifest.skinPath) }
            if package.profile == nil { error("missing-profile", "Full packs must contain profile.json.", path: manifest.profilePath) }
        }

        validateResources(manifest.assets, data: package.assets, root: "assets", issues: &issues)
        validatePreviews(manifest.previews, data: package.previews, issues: &issues)

        if manifest.previews.isEmpty {
            warning("missing-preview", "Add portrait or landscape previews to make the skin discoverable.", path: "manifest.previews")
        }

        if let skin = package.skin {
            let referencedAssets = referencedAssetIDs(in: skin.normalized)
            let declaredAssets = Set(manifest.assets.map(\.id))
            for assetID in referencedAssets.subtracting(declaredAssets).sorted() {
                error("missing-asset-reference", "Skin references undeclared asset \(assetID).", path: "skin.json")
            }
            for assetID in declaredAssets.subtracting(referencedAssets).sorted() {
                warning("unused-asset", "Asset \(assetID) is not referenced by this skin.", path: "manifest.assets")
            }
            validateStyleReferences(in: skin.normalized, issues: &issues)
        }

        return PocketPadSkinValidationReport(issues: issues)
    }

    public static func isValidReverseDNSIdentifier(_ value: String) -> Bool {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count >= 3 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return components.allSatisfy { component in
            !component.isEmpty
                && component.unicodeScalars.allSatisfy { allowed.contains($0) }
                && component.unicodeScalars.first.map { CharacterSet.letters.contains($0) } == true
        }
    }

    private static func validateResources(
        _ descriptors: [PocketPadSkinResourceDescriptor],
        data: [String: Data],
        root: String,
        issues: inout [PocketPadSkinValidationIssue]
    ) {
        var ids = Set<String>()
        var paths = Set<String>()
        for descriptor in descriptors.map(\.normalized) {
            if descriptor.id.isEmpty || !ids.insert(descriptor.id).inserted {
                issues.append(.init(severity: .error, code: "duplicate-asset-id", message: "Asset IDs must be non-empty and unique.", path: descriptor.path))
            }
            if !paths.insert(descriptor.path).inserted {
                issues.append(.init(severity: .error, code: "duplicate-asset-path", message: "Asset paths must be unique.", path: descriptor.path))
            }
            if !PocketPadSkinPackageCodec.isSafePackagePath(descriptor.path, requiredRoot: root) {
                issues.append(.init(severity: .error, code: "unsafe-asset-path", message: "Asset path must stay inside \(root)/.", path: descriptor.path))
            }
            if !isAllowedVisualResource(path: descriptor.path, contentType: descriptor.contentType) {
                issues.append(.init(severity: .error, code: "executable-asset", message: "Skin assets must be non-executable visual media.", path: descriptor.path))
            }
            guard let payload = data[descriptor.id] else {
                issues.append(.init(severity: .error, code: "missing-asset-data", message: "Missing data for asset \(descriptor.id).", path: descriptor.path))
                continue
            }
            if descriptor.byteCount != payload.count {
                issues.append(.init(severity: .error, code: "asset-size-mismatch", message: "Asset byte count does not match its manifest entry.", path: descriptor.path))
            }
            if descriptor.sha256 != payload.pocketPadSHA256 {
                issues.append(.init(severity: .error, code: "asset-hash-mismatch", message: "Asset hash does not match its manifest entry.", path: descriptor.path))
            }
        }
        for extraID in Set(data.keys).subtracting(ids).sorted() {
            issues.append(.init(severity: .error, code: "undeclared-asset-data", message: "Asset data \(extraID) is not declared in the manifest."))
        }
    }

    private static func validatePreviews(
        _ descriptors: [PocketPadSkinPreviewDescriptor],
        data: [String: Data],
        issues: inout [PocketPadSkinValidationIssue]
    ) {
        var ids = Set<String>()
        var paths = Set<String>()
        for descriptor in descriptors.map(\.normalized) {
            if descriptor.id.isEmpty || !ids.insert(descriptor.id).inserted {
                issues.append(.init(severity: .error, code: "duplicate-preview-id", message: "Preview IDs must be non-empty and unique.", path: descriptor.path))
            }
            if !paths.insert(descriptor.path).inserted {
                issues.append(.init(severity: .error, code: "duplicate-preview-path", message: "Preview paths must be unique.", path: descriptor.path))
            }
            if !PocketPadSkinPackageCodec.isSafePackagePath(descriptor.path, requiredRoot: "previews") {
                issues.append(.init(severity: .error, code: "unsafe-preview-path", message: "Preview path must stay inside previews/.", path: descriptor.path))
            }
            if !isAllowedPreviewPath(descriptor.path) {
                issues.append(.init(severity: .error, code: "invalid-preview-content", message: "Preview files must use a supported image extension.", path: descriptor.path))
            }
            guard let payload = data[descriptor.id] else {
                issues.append(.init(severity: .error, code: "missing-preview-data", message: "Missing data for preview \(descriptor.id).", path: descriptor.path))
                continue
            }
            if descriptor.byteCount != payload.count || descriptor.sha256 != payload.pocketPadSHA256 {
                issues.append(.init(severity: .error, code: "preview-integrity-mismatch", message: "Preview size or hash does not match its manifest entry.", path: descriptor.path))
            }
        }
        for extraID in Set(data.keys).subtracting(ids).sorted() {
            issues.append(.init(severity: .error, code: "undeclared-preview-data", message: "Preview data \(extraID) is not declared in the manifest."))
        }
    }

    private static func isAllowedVisualResource(path: String, contentType: String) -> Bool {
        let contentType = contentType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard contentType.hasPrefix("image/") || contentType == "application/pdf" else { return false }
        let forbiddenExtensions: Set<String> = [
            "app", "appex", "bundle", "command", "dylib", "exe", "js", "mach-o", "node",
            "o", "out", "plugin", "py", "sh", "so", "swift"
        ]
        return !forbiddenExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }

    private static func isAllowedPreviewPath(_ path: String) -> Bool {
        let allowedExtensions: Set<String> = ["avif", "gif", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp"]
        return allowedExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }

    private static func validateStyleReferences(
        in skin: PocketPadSkin,
        issues: inout [PocketPadSkinValidationIssue]
    ) {
        let combinations: [(PocketPadSkinOrientation, PocketPadSkinColorScheme)] = [
            (.portrait, .light), (.portrait, .dark), (.landscape, .light), (.landscape, .dark)
        ]
        for (orientation, scheme) in combinations {
            let appearance = skin.appearance(orientation: orientation, colorScheme: scheme)
            let styleIDs = Set(appearance.styleLibrary.styles.map(\.id))
            let controlAppearances = [appearance.defaultControl].compactMap { $0 }
                + appearance.roleRules.map(\.appearance)
                + appearance.buttonRules.map(\.appearance)
            for control in controlAppearances {
                if let styleID = control.styleID, !styleIDs.contains(styleID) {
                    issues.append(.init(
                        severity: .error,
                        code: "missing-style-reference",
                        message: "Control references missing style \(styleID) for \(orientation.rawValue)/\(scheme.rawValue).",
                        path: "skin.json"
                    ))
                }
            }
        }
    }

    private static func referencedAssetIDs(in skin: PocketPadSkin) -> Set<String> {
        var ids = Set<String>()
        let appearances = [skin.base] + skin.variants.map(\.appearance)
        for appearance in appearances {
            collectAssets(from: appearance.backgroundFillStyle, into: &ids)
            for layer in appearance.artworkLayers ?? [] {
                collectAssets(from: layer.fillStyle, into: &ids)
            }
            let controls = [appearance.defaultControl].compactMap { $0 }
                + appearance.roleRules.map(\.appearance)
                + appearance.buttonRules.map(\.appearance)
            for control in controls {
                collectAssets(from: control.icon, into: &ids)
                collectAssets(from: control.visualStyle, into: &ids)
            }
            for style in appearance.styleLibrary.styles {
                collectAssets(from: style.visualStyle, into: &ids)
            }
        }
        return ids
    }

    private static func collectAssets(from visualStyle: GamepadControlVisualStyle?, into ids: inout Set<String>) {
        guard let visualStyle else { return }
        collectAssets(from: visualStyle.icon, into: &ids)
        collectAssets(from: visualStyle.normal.fillStyle, into: &ids)
        collectAssets(from: visualStyle.pressed?.fillStyle, into: &ids)
        collectAssets(from: visualStyle.active?.fillStyle, into: &ids)
        collectAssets(from: visualStyle.disabled?.fillStyle, into: &ids)
    }

    private static func collectAssets(from icon: GamepadControlIcon?, into ids: inout Set<String>) {
        guard let icon, icon.source == .asset else { return }
        let id = GamepadStyleToken.normalizedIdentifier(icon.value)
        if !id.isEmpty { ids.insert(id) }
    }

    private static func collectAssets(from fillStyle: GamepadFillStyle?, into ids: inout Set<String>) {
        guard let fillStyle, case .image(let image) = fillStyle.normalized, let assetID = image.assetID else { return }
        ids.insert(assetID)
    }
}

public enum PocketPadSkinPackageCodecError: LocalizedError, Equatable {
    case archiveTooLarge
    case invalidArchive
    case unsafeEntry(String)
    case duplicateEntry(String)
    case unsupportedEntry(String)
    case tooManyEntries
    case entryTooLarge(String)
    case compressionRatioTooHigh(String)
    case missingEntry(String)
    case unexpectedEntry(String)
    case corruptEntry(String)
    case invalidPackage([PocketPadSkinValidationIssue])

    public var errorDescription: String? {
        switch self {
        case .archiveTooLarge: "PocketPad package exceeds the compressed size limit."
        case .invalidArchive: "The file is not a readable PocketPad ZIP package."
        case .unsafeEntry(let path): "Package contains an unsafe path: \(path)."
        case .duplicateEntry(let path): "Package contains a duplicate entry: \(path)."
        case .unsupportedEntry(let path): "Package contains an unsupported entry type: \(path)."
        case .tooManyEntries: "Package contains too many files."
        case .entryTooLarge(let path): "Package entry is too large: \(path)."
        case .compressionRatioTooHigh(let path): "Package entry has an unsafe compression ratio: \(path)."
        case .missingEntry(let path): "Package is missing required entry: \(path)."
        case .unexpectedEntry(let path): "Package contains an undeclared entry: \(path)."
        case .corruptEntry(let path): "Package entry failed integrity validation: \(path)."
        case .invalidPackage(let issues): issues.first?.message ?? "PocketPad package is invalid."
        }
    }
}

public enum PocketPadSkinPackageCodec {
    public static let maximumArchiveBytes = 40 * 1024 * 1024
    public static let maximumEntryCount = 256
    public static let maximumEntryBytes = 10 * 1024 * 1024
    public static let maximumTotalUncompressedBytes = 50 * 1024 * 1024
    public static let maximumCompressionRatio: UInt64 = 200

    public static func encode(_ package: PocketPadSkinPackage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        var prepared = package
        prepared.skin = prepared.skin?.normalized
        prepared.profile = prepared.profile?.normalized
        var manifest = prepared.manifest.normalized

        let skinData = try prepared.skin.map { try encoder.encode($0) }
        let profileData = try prepared.profile.map { try encoder.encode($0) }
        if let skinData {
            manifest.skinPath = manifest.skinPath ?? "skin.json"
            manifest.skinSHA256 = skinData.pocketPadSHA256
        } else {
            manifest.skinPath = nil
            manifest.skinSHA256 = nil
        }
        if let profileData {
            manifest.profilePath = manifest.profilePath ?? "profile.json"
            manifest.profileSHA256 = profileData.pocketPadSHA256
        } else {
            manifest.profilePath = nil
            manifest.profileSHA256 = nil
        }

        manifest.assets = manifest.assets.map { descriptor in
            var descriptor = descriptor.normalized
            if let data = prepared.assets[descriptor.id] {
                descriptor.byteCount = data.count
                descriptor.sha256 = data.pocketPadSHA256
            }
            return descriptor
        }
        manifest.previews = manifest.previews.map { descriptor in
            var descriptor = descriptor.normalized
            if let data = prepared.previews[descriptor.id] {
                descriptor.byteCount = data.count
                descriptor.sha256 = data.pocketPadSHA256
            }
            return descriptor
        }
        // Validate compatibility before its normalizer can repair malformed author input
        // (for example a reversed aspect or template-revision range). Other manifest
        // fields stay prepared so canonical hashes and byte counts are validated.
        let normalizedCompatibility = manifest.compatibility
        prepared.manifest = manifest
        prepared.manifest.compatibility = package.manifest.compatibility
        let report = PocketPadSkinPackageValidator.validate(prepared)
        guard report.isValid else { throw PocketPadSkinPackageCodecError.invalidPackage(report.errors) }
        manifest.compatibility = normalizedCompatibility
        prepared.manifest = manifest

        let archive: Archive
        do {
            archive = try Archive(accessMode: .create)
        } catch {
            throw PocketPadSkinPackageCodecError.invalidArchive
        }

        try add(try encoder.encode(manifest), path: "manifest.json", to: archive)
        if let skinData, let path = manifest.skinPath { try add(skinData, path: path, to: archive) }
        if let profileData, let path = manifest.profilePath { try add(profileData, path: path, to: archive) }
        for descriptor in manifest.assets {
            guard let data = prepared.assets[descriptor.id] else { throw PocketPadSkinPackageCodecError.missingEntry(descriptor.path) }
            try add(data, path: descriptor.path, to: archive)
        }
        for descriptor in manifest.previews {
            guard let data = prepared.previews[descriptor.id] else { throw PocketPadSkinPackageCodecError.missingEntry(descriptor.path) }
            try add(data, path: descriptor.path, to: archive)
        }
        guard let data = archive.data else { throw PocketPadSkinPackageCodecError.invalidArchive }
        guard data.count <= maximumArchiveBytes else { throw PocketPadSkinPackageCodecError.archiveTooLarge }
        return data
    }

    public static func decode(_ data: Data) throws -> PocketPadSkinPackage {
        guard data.count <= maximumArchiveBytes else { throw PocketPadSkinPackageCodecError.archiveTooLarge }
        let archive: Archive
        do {
            archive = try Archive(data: data, accessMode: .read)
        } catch {
            throw PocketPadSkinPackageCodecError.invalidArchive
        }

        var entries: [String: Entry] = [:]
        var totalUncompressed: UInt64 = 0
        for entry in archive {
            guard entries.count < maximumEntryCount else { throw PocketPadSkinPackageCodecError.tooManyEntries }
            let path = entry.path
            guard isSafePackagePath(path) else { throw PocketPadSkinPackageCodecError.unsafeEntry(path) }
            guard entries[path] == nil else { throw PocketPadSkinPackageCodecError.duplicateEntry(path) }
            switch entry.type {
            case .file:
                guard entry.uncompressedSize <= UInt64(maximumEntryBytes) else { throw PocketPadSkinPackageCodecError.entryTooLarge(path) }
                totalUncompressed += entry.uncompressedSize
                guard totalUncompressed <= UInt64(maximumTotalUncompressedBytes) else { throw PocketPadSkinPackageCodecError.archiveTooLarge }
                if entry.compressedSize > 0, entry.uncompressedSize / entry.compressedSize > maximumCompressionRatio {
                    throw PocketPadSkinPackageCodecError.compressionRatioTooHigh(path)
                }
                entries[path] = entry
            case .directory:
                continue
            case .symlink:
                throw PocketPadSkinPackageCodecError.unsupportedEntry(path)
            }
        }

        guard let manifestEntry = entries["manifest.json"] else { throw PocketPadSkinPackageCodecError.missingEntry("manifest.json") }
        let decoder = JSONDecoder()
        let manifestData = try extract(manifestEntry, from: archive, maximumBytes: 1_000_000)
        let manifest: PocketPadSkinManifest
        do {
            manifest = try decoder.decode(PocketPadSkinManifest.self, from: manifestData).normalized
        } catch {
            throw PocketPadSkinPackageCodecError.corruptEntry("manifest.json")
        }

        var allowedPaths: Set<String> = ["manifest.json", "README.md", "LICENSE", "LICENSE.txt"]
        if let path = manifest.skinPath { allowedPaths.insert(path) }
        if let path = manifest.profilePath { allowedPaths.insert(path) }
        allowedPaths.formUnion(manifest.assets.map(\.path))
        allowedPaths.formUnion(manifest.previews.map(\.path))
        for path in entries.keys where !allowedPaths.contains(path) {
            throw PocketPadSkinPackageCodecError.unexpectedEntry(path)
        }

        let skin: PocketPadSkin?
        if let path = manifest.skinPath {
            guard let entry = entries[path] else { throw PocketPadSkinPackageCodecError.missingEntry(path) }
            let payload = try extract(entry, from: archive, maximumBytes: 4_000_000)
            guard manifest.skinSHA256 == payload.pocketPadSHA256 else { throw PocketPadSkinPackageCodecError.corruptEntry(path) }
            do {
                skin = try decoder.decode(PocketPadSkin.self, from: payload).normalized
            } catch {
                throw PocketPadSkinPackageCodecError.corruptEntry(path)
            }
        } else {
            skin = nil
        }

        let profile: GamepadConfigurationProfile?
        if let path = manifest.profilePath {
            guard let entry = entries[path] else { throw PocketPadSkinPackageCodecError.missingEntry(path) }
            let payload = try extract(entry, from: archive, maximumBytes: 8_000_000)
            guard manifest.profileSHA256 == payload.pocketPadSHA256 else { throw PocketPadSkinPackageCodecError.corruptEntry(path) }
            do {
                profile = try decoder.decode(GamepadConfigurationProfile.self, from: payload).normalized
            } catch {
                throw PocketPadSkinPackageCodecError.corruptEntry(path)
            }
        } else {
            profile = nil
        }

        var assets: [String: Data] = [:]
        for descriptor in manifest.assets {
            guard let entry = entries[descriptor.path] else { throw PocketPadSkinPackageCodecError.missingEntry(descriptor.path) }
            let payload = try extract(entry, from: archive, maximumBytes: maximumEntryBytes)
            guard payload.count == descriptor.byteCount, payload.pocketPadSHA256 == descriptor.sha256 else {
                throw PocketPadSkinPackageCodecError.corruptEntry(descriptor.path)
            }
            assets[descriptor.id] = payload
        }

        var previews: [String: Data] = [:]
        for descriptor in manifest.previews {
            guard let entry = entries[descriptor.path] else { throw PocketPadSkinPackageCodecError.missingEntry(descriptor.path) }
            let payload = try extract(entry, from: archive, maximumBytes: maximumEntryBytes)
            guard payload.count == descriptor.byteCount, payload.pocketPadSHA256 == descriptor.sha256 else {
                throw PocketPadSkinPackageCodecError.corruptEntry(descriptor.path)
            }
            previews[descriptor.id] = payload
        }

        let package = PocketPadSkinPackage(manifest: manifest, skin: skin, profile: profile, assets: assets, previews: previews)
        let report = PocketPadSkinPackageValidator.validate(package)
        guard report.isValid else { throw PocketPadSkinPackageCodecError.invalidPackage(report.errors) }
        return package
    }

    public static func read(from url: URL) throws -> PocketPadSkinPackage {
        try decode(Data(contentsOf: url, options: [.mappedIfSafe]))
    }

    public static func write(_ package: PocketPadSkinPackage, to url: URL) throws {
        let data = try encode(package)
        try data.write(to: url, options: .atomic)
    }

    public static func isSafePackagePath(_ path: String, requiredRoot: String? = nil) -> Bool {
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasPrefix("~"),
              !path.contains("\\"),
              !path.unicodeScalars.contains(where: { $0.value == 0 })
        else { return false }
        let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else { return false }
        if let requiredRoot {
            guard components.first == Substring(requiredRoot), components.count >= 2 else { return false }
        }
        return true
    }

    private static func add(_ data: Data, path: String, to archive: Archive) throws {
        guard isSafePackagePath(path) else { throw PocketPadSkinPackageCodecError.unsafeEntry(path) }
        guard data.count <= maximumEntryBytes else { throw PocketPadSkinPackageCodecError.entryTooLarge(path) }
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            modificationDate: Date(timeIntervalSince1970: 315_532_800),
            permissions: 0o644,
            compressionMethod: .deflate
        ) { position, size in
            let start = Int(position)
            return data.subdata(in: start..<(start + size))
        }
    }

    private static func extract(_ entry: Entry, from archive: Archive, maximumBytes: Int) throws -> Data {
        guard entry.uncompressedSize <= UInt64(maximumBytes) else { throw PocketPadSkinPackageCodecError.entryTooLarge(entry.path) }
        var data = Data()
        data.reserveCapacity(Int(entry.uncompressedSize))
        do {
            _ = try archive.extract(entry) { chunk in
                guard data.count + chunk.count <= maximumBytes else {
                    throw PocketPadSkinPackageCodecError.entryTooLarge(entry.path)
                }
                data.append(chunk)
            }
        } catch let error as PocketPadSkinPackageCodecError {
            throw error
        } catch {
            throw PocketPadSkinPackageCodecError.corruptEntry(entry.path)
        }
        return data
    }
}

public struct PocketPadSkinPackageDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.pocketPadSkinPackage] }
    public static var writableContentTypes: [UTType] { [.pocketPadSkinPackage] }

    public var package: PocketPadSkinPackage

    public init(package: PocketPadSkinPackage) {
        self.package = package
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        package = try PocketPadSkinPackageCodec.decode(data)
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try PocketPadSkinPackageCodec.encode(package))
    }
}

extension Data {
    var pocketPadSHA256: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}
