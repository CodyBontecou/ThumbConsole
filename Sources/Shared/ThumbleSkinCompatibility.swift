import Foundation

public enum ThumbleSkinCompatibilityMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case universal
    case templateAligned = "template_aligned"

    public var id: String { rawValue }
}

public struct ThumbleSkinTemplateRequirement: Codable, Equatable, Sendable {
    public var templateID: String
    public var minimumRevision: Int
    public var maximumRevision: Int?

    public init(templateID: String, minimumRevision: Int = 1, maximumRevision: Int? = nil) {
        self.templateID = templateID
        self.minimumRevision = minimumRevision
        self.maximumRevision = maximumRevision
    }

    public var normalized: ThumbleSkinTemplateRequirement {
        let templateID = templateID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let minimum = max(1, minimumRevision)
        return ThumbleSkinTemplateRequirement(
            templateID: String(templateID.prefix(80)),
            minimumRevision: minimum,
            maximumRevision: maximumRevision.map { max(minimum, $0) }
        )
    }

    public func matches(templateID requestedID: String, revision: Int) -> Bool {
        let value = normalized
        guard value.templateID == requestedID.lowercased(), revision >= value.minimumRevision else { return false }
        return value.maximumRevision.map { revision <= $0 } ?? true
    }
}

public enum ThumbleSkinRenderingFeature: String, Codable, CaseIterable, Identifiable, Sendable {
    case artworkLayers = "artwork_layers"
    case nineSliceImages = "nine_slice_images"
    case bitmapControlStates = "bitmap_control_states"

    public var id: String { rawValue }
}

public struct ThumbleSkinCompatibility: Codable, Equatable, Sendable {
    public var mode: ThumbleSkinCompatibilityMode
    public var templates: [ThumbleSkinTemplateRequirement]
    public var orientations: [ThumbleSkinOrientation]
    public var minimumAspectRatio: CGFloat?
    public var maximumAspectRatio: CGFloat?
    public var requiredRoles: [GamepadVisualRole]
    public var requiredFeatures: [ThumbleSkinRenderingFeature]

    public init(
        mode: ThumbleSkinCompatibilityMode = .universal,
        templates: [ThumbleSkinTemplateRequirement] = [],
        orientations: [ThumbleSkinOrientation] = ThumbleSkinOrientation.allCases,
        minimumAspectRatio: CGFloat? = nil,
        maximumAspectRatio: CGFloat? = nil,
        requiredRoles: [GamepadVisualRole] = [],
        requiredFeatures: [ThumbleSkinRenderingFeature] = []
    ) {
        self.mode = mode
        self.templates = templates
        self.orientations = orientations
        self.minimumAspectRatio = minimumAspectRatio
        self.maximumAspectRatio = maximumAspectRatio
        self.requiredRoles = requiredRoles
        self.requiredFeatures = requiredFeatures
    }

    public var normalized: ThumbleSkinCompatibility {
        var seenTemplates = Set<String>()
        let templates = templates.map(\.normalized).filter {
            !$0.templateID.isEmpty && seenTemplates.insert("\($0.templateID):\($0.minimumRevision):\($0.maximumRevision ?? Int.max)").inserted
        }
        let orientations = unique(self.orientations)
        let roles = unique(requiredRoles)
        let features = unique(requiredFeatures)
        let minimum = minimumAspectRatio.map { Self.clamp($0, lower: 0.25, upper: 4) }
        let maximum = maximumAspectRatio.map { Self.clamp($0, lower: minimum ?? 0.25, upper: 4) }
        return ThumbleSkinCompatibility(
            mode: mode,
            templates: templates,
            orientations: orientations,
            minimumAspectRatio: minimum,
            maximumAspectRatio: maximum,
            requiredRoles: roles,
            requiredFeatures: features
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }

    private func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        return values.filter { seen.insert($0).inserted }
    }
}

public enum ThumbleSkinCompatibilityStatus: String, Codable, Equatable, Sendable {
    case compatible
    case degraded
    case incompatible
}

public struct ThumbleSkinCompatibilityIssue: Codable, Equatable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ThumbleSkinCompatibilityEvaluation: Codable, Equatable, Sendable {
    public var status: ThumbleSkinCompatibilityStatus
    public var issues: [ThumbleSkinCompatibilityIssue]

    public init(status: ThumbleSkinCompatibilityStatus, issues: [ThumbleSkinCompatibilityIssue] = []) {
        self.status = status
        self.issues = issues
    }

    public var allowsTemplateArtwork: Bool { status == .compatible }
}

public enum ThumbleSkinCompatibilityEvaluator {
    public static let supportedFeatures = Set(ThumbleSkinRenderingFeature.allCases)

    public static func evaluate(
        _ compatibility: ThumbleSkinCompatibility?,
        customization: GamepadCustomization,
        orientation: ThumbleSkinOrientation
    ) -> ThumbleSkinCompatibilityEvaluation {
        guard let compatibility else { return .init(status: .compatible) }
        let value = compatibility.normalized
        var issues: [ThumbleSkinCompatibilityIssue] = []
        var incompatible = false

        if !value.orientations.isEmpty, !value.orientations.contains(orientation) {
            issues.append(.init(code: "unsupported-orientation", message: "The skin does not provide \(orientation.rawValue) artwork."))
            incompatible = true
        }

        let size = customization.deviceCanvas.editorDeviceFrame.screenRect.size
        let aspect = max(size.width, 1) / max(size.height, 1)
        if let minimum = value.minimumAspectRatio, aspect < minimum {
            issues.append(.init(code: "aspect-ratio-too-small", message: "The keypad aspect ratio is below the skin's artwork range."))
            incompatible = true
        }
        if let maximum = value.maximumAspectRatio, aspect > maximum {
            issues.append(.init(code: "aspect-ratio-too-large", message: "The keypad aspect ratio is above the skin's artwork range."))
            incompatible = true
        }

        let controls = customization.resolvedControls(in: size).filter { !$0.layoutCustomization.isHidden }
        let roles = Set(controls.map(\.visualRole))
        for role in value.requiredRoles where !roles.contains(role) {
            issues.append(.init(code: "missing-role", message: "The keypad has no \(role.displayName.lowercased()) control required by the artwork."))
            incompatible = true
        }
        for feature in value.requiredFeatures where !supportedFeatures.contains(feature) {
            issues.append(.init(code: "missing-rendering-feature", message: "This app does not support \(feature.rawValue)."))
            incompatible = true
        }

        if value.mode == .templateAligned {
            let metadata = customization.designMetadata
            guard let templateID = metadata?.sourceTemplateID, let revision = metadata?.sourceTemplateRevision else {
                issues.append(.init(code: "unknown-template", message: "The keypad has no canonical template identity; semantic styling remains available but aligned artwork is hidden."))
                return .init(status: incompatible ? .incompatible : .degraded, issues: issues)
            }
            if !value.templates.isEmpty,
               !value.templates.contains(where: { $0.matches(templateID: templateID, revision: revision) }) {
                issues.append(.init(code: "template-mismatch", message: "The skin artwork targets a different canonical keypad template."))
                incompatible = true
            }
        }

        return .init(
            status: incompatible ? .incompatible : .compatible,
            issues: issues
        )
    }
}
