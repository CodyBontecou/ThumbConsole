import Foundation
import SwiftUI

public enum GamepadControlPresentationState: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case pressed
    case active
    case disabled

    public var id: String { rawValue }

    var usesPressedFallback: Bool {
        switch self {
        case .pressed, .active: true
        case .normal, .disabled: false
        }
    }
}

public enum GamepadControlIconSource: String, Codable, Sendable {
    case sfSymbol = "sf_symbol"
    case text
    case asset
}

public enum GamepadControlIconPlacement: String, Codable, CaseIterable, Identifiable, Sendable {
    case leading
    case trailing
    case top
    case bottom
    case center
    case background

    public var id: String { rawValue }
}

public enum GamepadControlIconRenderingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case template
    case multicolor
    case original

    public var id: String { rawValue }
}

public struct GamepadControlIcon: Codable, Equatable, Sendable {
    public var source: GamepadControlIconSource
    public var value: String
    public var placement: GamepadControlIconPlacement
    public var scale: CGFloat
    public var tintColor: GamepadRGBAColor?
    public var renderingMode: GamepadControlIconRenderingMode

    public init(
        source: GamepadControlIconSource,
        value: String,
        placement: GamepadControlIconPlacement = .center,
        scale: CGFloat = 1,
        tintColor: GamepadRGBAColor? = nil,
        renderingMode: GamepadControlIconRenderingMode = .template
    ) {
        self.source = source
        self.value = value
        self.placement = placement
        self.scale = scale
        self.tintColor = tintColor
        self.renderingMode = renderingMode
    }

    public static func sfSymbol(_ name: String, placement: GamepadControlIconPlacement = .center) -> GamepadControlIcon {
        GamepadControlIcon(source: .sfSymbol, value: name, placement: placement)
    }

    public static func text(_ value: String, placement: GamepadControlIconPlacement = .center) -> GamepadControlIcon {
        GamepadControlIcon(source: .text, value: value, placement: placement)
    }

    var normalized: GamepadControlIcon? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return GamepadControlIcon(
            source: source,
            value: String(trimmed.prefix(80)),
            placement: placement,
            scale: Self.clamp(scale, lower: 0.2, upper: 3),
            tintColor: tintColor?.normalized,
            renderingMode: renderingMode
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }
}

public enum GamepadHapticStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case light
    case medium
    case heavy
    case soft
    case rigid

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .light: "Light"
        case .medium: "Medium"
        case .heavy: "Heavy"
        case .soft: "Soft"
        case .rigid: "Rigid"
        }
    }

    var defaultIntensity: CGFloat {
        switch self {
        case .none: 0
        case .light: 0.45
        case .medium: 0.62
        case .heavy: 0.82
        case .soft: 0.38
        case .rigid: 0.70
        }
    }

    var defaultSharpness: CGFloat {
        switch self {
        case .none: 0
        case .light: 0.48
        case .medium: 0.56
        case .heavy: 0.66
        case .soft: 0.24
        case .rigid: 0.92
        }
    }
}

public enum GamepadHapticPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case single
    case double
    case pulse
    case buzz

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single: "Single Tap"
        case .double: "Double Tap"
        case .pulse: "Pulse"
        case .buzz: "Buzz"
        }
    }
}

public struct GamepadHapticFeedback: Codable, Equatable, Sendable {
    public static let minimumIntensity: CGFloat = 0
    public static let maximumIntensity: CGFloat = 1
    public static let minimumSharpness: CGFloat = 0
    public static let maximumSharpness: CGFloat = 1
    public static let minimumDuration: CGFloat = 0.02
    public static let maximumDuration: CGFloat = 0.30
    public static let defaultDuration: CGFloat = 0.06
    public static let defaultValue = GamepadHapticFeedback()

    public var style: GamepadHapticStyle
    public var pattern: GamepadHapticPattern
    public var intensity: CGFloat
    public var sharpness: CGFloat
    public var duration: CGFloat

    public init(
        style: GamepadHapticStyle = .light,
        pattern: GamepadHapticPattern = .single,
        intensity: CGFloat? = nil,
        sharpness: CGFloat? = nil,
        duration: CGFloat = GamepadHapticFeedback.defaultDuration
    ) {
        self.style = style
        self.pattern = pattern
        self.intensity = intensity ?? style.defaultIntensity
        self.sharpness = sharpness ?? style.defaultSharpness
        self.duration = duration
    }

    var normalized: GamepadHapticFeedback {
        var copy = self
        copy.intensity = Self.clamp(copy.intensity, lower: Self.minimumIntensity, upper: Self.maximumIntensity)
        copy.sharpness = Self.clamp(copy.sharpness, lower: Self.minimumSharpness, upper: Self.maximumSharpness)
        copy.duration = Self.clamp(copy.duration, lower: Self.minimumDuration, upper: Self.maximumDuration)
        if copy.style == .none {
            copy.pattern = .single
            copy.intensity = 0
            copy.sharpness = 0
        }
        return copy
    }

    var isDefault: Bool {
        let normalized = normalized
        return normalized.style == Self.defaultValue.style
            && normalized.pattern == Self.defaultValue.pattern
            && abs(normalized.intensity - Self.defaultValue.intensity) < 0.001
            && abs(normalized.sharpness - Self.defaultValue.sharpness) < 0.001
            && abs(normalized.duration - Self.defaultValue.duration) < 0.001
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }
}

public struct GamepadControlStateStyle: Codable, Equatable, Sendable {
    public var fillStyle: GamepadFillStyle?
    public var foregroundColor: GamepadRGBAColor?
    public var strokeColor: GamepadRGBAColor?
    public var strokeWidth: CGFloat?
    public var shadowColor: GamepadRGBAColor?
    public var shadowRadius: CGFloat?
    public var shadowX: CGFloat?
    public var shadowY: CGFloat?
    public var glowColor: GamepadRGBAColor?
    public var glowRadius: CGFloat?
    public var opacity: CGFloat?
    public var scale: CGFloat?
    public var blurRadius: CGFloat?

    public init(
        fillStyle: GamepadFillStyle? = nil,
        foregroundColor: GamepadRGBAColor? = nil,
        strokeColor: GamepadRGBAColor? = nil,
        strokeWidth: CGFloat? = nil,
        shadowColor: GamepadRGBAColor? = nil,
        shadowRadius: CGFloat? = nil,
        shadowX: CGFloat? = nil,
        shadowY: CGFloat? = nil,
        glowColor: GamepadRGBAColor? = nil,
        glowRadius: CGFloat? = nil,
        opacity: CGFloat? = nil,
        scale: CGFloat? = nil,
        blurRadius: CGFloat? = nil
    ) {
        self.fillStyle = fillStyle
        self.foregroundColor = foregroundColor
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowX = shadowX
        self.shadowY = shadowY
        self.glowColor = glowColor
        self.glowRadius = glowRadius
        self.opacity = opacity
        self.scale = scale
        self.blurRadius = blurRadius
    }

    public static let empty = GamepadControlStateStyle()

    var normalized: GamepadControlStateStyle {
        GamepadControlStateStyle(
            fillStyle: fillStyle?.normalized,
            foregroundColor: foregroundColor?.normalized,
            strokeColor: strokeColor?.normalized,
            strokeWidth: strokeWidth.map { Self.clamp($0, lower: 0, upper: 12) },
            shadowColor: shadowColor?.normalized,
            shadowRadius: shadowRadius.map { Self.clamp($0, lower: 0, upper: 48) },
            shadowX: shadowX.map { Self.clamp($0, lower: -64, upper: 64) },
            shadowY: shadowY.map { Self.clamp($0, lower: -64, upper: 64) },
            glowColor: glowColor?.normalized,
            glowRadius: glowRadius.map { Self.clamp($0, lower: 0, upper: 64) },
            opacity: opacity.map { Self.clamp($0, lower: 0, upper: 1) },
            scale: scale.map { Self.clamp($0, lower: 0.5, upper: 1.5) },
            blurRadius: blurRadius.map { Self.clamp($0, lower: 0, upper: 24) }
        )
    }

    var isEmpty: Bool {
        fillStyle == nil
            && foregroundColor == nil
            && strokeColor == nil
            && strokeWidth == nil
            && shadowColor == nil
            && shadowRadius == nil
            && shadowX == nil
            && shadowY == nil
            && glowColor == nil
            && glowRadius == nil
            && opacity == nil
            && scale == nil
            && blurRadius == nil
    }

    func merged(over base: GamepadControlStateStyle) -> GamepadControlStateStyle {
        GamepadControlStateStyle(
            fillStyle: fillStyle ?? base.fillStyle,
            foregroundColor: foregroundColor ?? base.foregroundColor,
            strokeColor: strokeColor ?? base.strokeColor,
            strokeWidth: strokeWidth ?? base.strokeWidth,
            shadowColor: shadowColor ?? base.shadowColor,
            shadowRadius: shadowRadius ?? base.shadowRadius,
            shadowX: shadowX ?? base.shadowX,
            shadowY: shadowY ?? base.shadowY,
            glowColor: glowColor ?? base.glowColor,
            glowRadius: glowRadius ?? base.glowRadius,
            opacity: opacity ?? base.opacity,
            scale: scale ?? base.scale,
            blurRadius: blurRadius ?? base.blurRadius
        ).normalized
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }
}

public struct GamepadControlVisualStyle: Codable, Equatable, Sendable {
    public var normal: GamepadControlStateStyle
    public var pressed: GamepadControlStateStyle?
    public var active: GamepadControlStateStyle?
    public var disabled: GamepadControlStateStyle?
    public var icon: GamepadControlIcon?
    public var hapticStyle: GamepadHapticStyle?
    public var hapticFeedback: GamepadHapticFeedback?

    public init(
        normal: GamepadControlStateStyle = .empty,
        pressed: GamepadControlStateStyle? = nil,
        active: GamepadControlStateStyle? = nil,
        disabled: GamepadControlStateStyle? = nil,
        icon: GamepadControlIcon? = nil,
        hapticStyle: GamepadHapticStyle? = nil,
        hapticFeedback: GamepadHapticFeedback? = nil
    ) {
        self.normal = normal
        self.pressed = pressed
        self.active = active
        self.disabled = disabled
        self.icon = icon
        self.hapticStyle = hapticStyle
        self.hapticFeedback = hapticFeedback
    }

    public static let empty = GamepadControlVisualStyle()

    var normalized: GamepadControlVisualStyle? {
        let copy = GamepadControlVisualStyle(
            normal: normal.normalized,
            pressed: pressed?.normalized,
            active: active?.normalized,
            disabled: disabled?.normalized,
            icon: icon?.normalized,
            hapticStyle: hapticStyle,
            hapticFeedback: hapticFeedback?.normalized
        )
        return copy.isEmpty ? nil : copy
    }

    var isEmpty: Bool {
        normal.isEmpty
            && (pressed?.isEmpty ?? true)
            && (active?.isEmpty ?? true)
            && (disabled?.isEmpty ?? true)
            && icon == nil
            && hapticStyle == nil
            && hapticFeedback == nil
    }

    func stateStyle(for state: GamepadControlPresentationState) -> GamepadControlStateStyle {
        let override: GamepadControlStateStyle?
        switch state {
        case .normal:
            override = nil
        case .pressed:
            override = pressed
        case .active:
            override = active ?? pressed
        case .disabled:
            override = disabled
        }
        return (override ?? .empty).merged(over: normal).normalized
    }
}

public struct GamepadStyleToken: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var appliesTo: [GamepadCustomControlKind]
    public var visualStyle: GamepadControlVisualStyle

    public init(
        id: String = UUID().uuidString,
        name: String,
        appliesTo: [GamepadCustomControlKind] = GamepadCustomControlKind.allCases,
        visualStyle: GamepadControlVisualStyle
    ) {
        self.id = id
        self.name = name
        self.appliesTo = appliesTo
        self.visualStyle = visualStyle
    }

    var normalized: GamepadStyleToken? {
        let normalizedID = Self.normalizedIdentifier(id)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty, !normalizedName.isEmpty, let style = visualStyle.normalized else { return nil }
        let kinds = appliesTo.isEmpty ? GamepadCustomControlKind.allCases : Array(Set(appliesTo)).sorted { $0.rawValue < $1.rawValue }
        return GamepadStyleToken(
            id: normalizedID,
            name: String(normalizedName.prefix(48)),
            appliesTo: kinds,
            visualStyle: style
        )
    }

    static func normalizedIdentifier(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let allowedPunctuation = CharacterSet(charactersIn: "-_.")
        let scalars = trimmed.unicodeScalars.map { scalar -> UnicodeScalar in
            if CharacterSet.alphanumerics.contains(scalar) || allowedPunctuation.contains(scalar) {
                return scalar
            }
            return UnicodeScalar("-")
        }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    }
}

public struct GamepadStyleLibrary: Codable, Equatable, Sendable {
    public var styles: [GamepadStyleToken]

    public init(styles: [GamepadStyleToken] = []) {
        self.styles = styles
    }

    public static let empty = GamepadStyleLibrary()

    func style(id: String?) -> GamepadStyleToken? {
        guard let id else { return nil }
        return normalized.styles.first { $0.id == id }
    }

    var normalized: GamepadStyleLibrary {
        var seen = Set<String>()
        let normalizedStyles = styles.compactMap { style -> GamepadStyleToken? in
            guard let normalized = style.normalized, seen.insert(normalized.id).inserted else { return nil }
            return normalized
        }
        return GamepadStyleLibrary(styles: normalizedStyles)
    }

    var isEmpty: Bool { normalized.styles.isEmpty }
}

public enum GamepadAssetRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case background
    case icon
    case texture
    case reference

    public var id: String { rawValue }
}

public struct GamepadAsset: Codable, Equatable, Identifiable, Sendable {
    public static let maximumStoredBytes = GamepadImageFill.maximumStoredBytes

    public var id: String
    public var name: String
    public var fileName: String?
    public var contentType: String
    public var data: Data?
    public var byteCount: Int
    public var hash: String?
    public var role: GamepadAssetRole

    public init(
        id: String = UUID().uuidString,
        name: String,
        fileName: String? = nil,
        contentType: String = "application/octet-stream",
        data: Data? = nil,
        byteCount: Int? = nil,
        hash: String? = nil,
        role: GamepadAssetRole = .reference
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.contentType = contentType
        self.data = data
        self.byteCount = byteCount ?? data?.count ?? 0
        self.hash = hash
        self.role = role
    }

    var normalized: GamepadAsset? {
        let normalizedID = GamepadStyleToken.normalizedIdentifier(id)
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedID.isEmpty, !normalizedName.isEmpty else { return nil }
        let storedData = (data?.count ?? 0) <= Self.maximumStoredBytes ? data : nil
        let type = contentType.trimmingCharacters(in: .whitespacesAndNewlines)
        return GamepadAsset(
            id: normalizedID,
            name: String(normalizedName.prefix(64)),
            fileName: fileName?.trimmingCharacters(in: .whitespacesAndNewlines),
            contentType: type.isEmpty ? "application/octet-stream" : String(type.prefix(80)),
            data: storedData,
            byteCount: storedData?.count ?? max(0, byteCount),
            hash: hash?.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role
        )
    }
}

public struct GamepadAssetLibrary: Codable, Equatable, Sendable {
    public var assets: [GamepadAsset]

    public init(assets: [GamepadAsset] = []) {
        self.assets = assets
    }

    public static let empty = GamepadAssetLibrary()

    public func asset(id: String?) -> GamepadAsset? {
        guard let id else { return nil }
        return normalized.assets.first { $0.id == id }
    }

    var normalized: GamepadAssetLibrary {
        var seen = Set<String>()
        let normalizedAssets = assets.compactMap { asset -> GamepadAsset? in
            guard let normalized = asset.normalized, seen.insert(normalized.id).inserted else { return nil }
            return normalized
        }
        return GamepadAssetLibrary(assets: normalizedAssets)
    }

    var isEmpty: Bool { normalized.assets.isEmpty }
}

public struct GamepadEditorGridSettings: Codable, Equatable, Sendable {
    public var showsGrid: Bool
    public var snapToGrid: Bool
    public var snapToObjects: Bool
    public var gridSize: CGFloat
    public var snapTolerance: CGFloat

    public init(
        showsGrid: Bool = false,
        snapToGrid: Bool = false,
        snapToObjects: Bool = true,
        gridSize: CGFloat = 16,
        snapTolerance: CGFloat = 6
    ) {
        self.showsGrid = showsGrid
        self.snapToGrid = snapToGrid
        self.snapToObjects = snapToObjects
        self.gridSize = gridSize
        self.snapTolerance = snapTolerance
    }

    public static let defaultValue = GamepadEditorGridSettings()

    var normalized: GamepadEditorGridSettings {
        GamepadEditorGridSettings(
            showsGrid: showsGrid,
            snapToGrid: snapToGrid,
            snapToObjects: snapToObjects,
            gridSize: Self.clamp(gridSize, lower: 4, upper: 128),
            snapTolerance: Self.clamp(snapTolerance, lower: 0, upper: 32)
        )
    }

    var isDefault: Bool { normalized == Self.defaultValue }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }
}

public enum GamepadEditorGuideOrientation: String, Codable, CaseIterable, Identifiable, Sendable {
    case horizontal
    case vertical

    public var id: String { rawValue }
}

public struct GamepadEditorGuide: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var orientation: GamepadEditorGuideOrientation
    public var position: CGFloat

    public init(id: UUID = UUID(), orientation: GamepadEditorGuideOrientation, position: CGFloat) {
        self.id = id
        self.orientation = orientation
        self.position = position
    }

    var normalized: GamepadEditorGuide {
        GamepadEditorGuide(
            id: id,
            orientation: orientation,
            position: position.isFinite ? position : 0
        )
    }
}

public struct GamepadLayerGroup: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var children: [GamepadControlIdentity]
    public var isLocked: Bool
    public var isHidden: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        children: [GamepadControlIdentity] = [],
        isLocked: Bool = false,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.children = children
        self.isLocked = isLocked
        self.isHidden = isHidden
    }

    func normalized(availableControls: Set<GamepadControlIdentity>) -> GamepadLayerGroup? {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var seen = Set<GamepadControlIdentity>()
        let normalizedChildren = children.filter { availableControls.contains($0) && seen.insert($0).inserted }
        guard !normalizedChildren.isEmpty else { return nil }
        return GamepadLayerGroup(
            id: id,
            name: String((normalizedName.isEmpty ? "Group" : normalizedName).prefix(48)),
            children: normalizedChildren,
            isLocked: isLocked,
            isHidden: isHidden
        )
    }
}

public struct GamepadDesignMetadata: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var layerOrder: [GamepadControlIdentity]
    public var groups: [GamepadLayerGroup]
    public var grid: GamepadEditorGridSettings
    public var guides: [GamepadEditorGuide]
    public var notes: String?
    public var tags: [String]

    public init(
        schemaVersion: Int = 1,
        layerOrder: [GamepadControlIdentity] = [],
        groups: [GamepadLayerGroup] = [],
        grid: GamepadEditorGridSettings = .defaultValue,
        guides: [GamepadEditorGuide] = [],
        notes: String? = nil,
        tags: [String] = []
    ) {
        self.schemaVersion = schemaVersion
        self.layerOrder = layerOrder
        self.groups = groups
        self.grid = grid
        self.guides = guides
        self.notes = notes
        self.tags = tags
    }

    public static let empty = GamepadDesignMetadata()

    func normalized(availableControls: [GamepadControlIdentity]) -> GamepadDesignMetadata? {
        let availableSet = Set(availableControls)
        var seen = Set<GamepadControlIdentity>()
        var normalizedLayerOrder = layerOrder.filter { availableSet.contains($0) && seen.insert($0).inserted }
        for identity in availableControls where !seen.contains(identity) {
            normalizedLayerOrder.append(identity)
            seen.insert(identity)
        }
        let normalizedGroups = groups.compactMap { $0.normalized(availableControls: availableSet) }
        let normalizedGuides = guides.map(\.normalized)
        let normalizedTags = Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        let normalizedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let copy = GamepadDesignMetadata(
            schemaVersion: max(1, schemaVersion),
            layerOrder: normalizedLayerOrder,
            groups: normalizedGroups,
            grid: grid.normalized,
            guides: normalizedGuides,
            notes: normalizedNotes?.isEmpty == false ? String(normalizedNotes!.prefix(500)) : nil,
            tags: normalizedTags.map { String($0.prefix(32)) }
        )
        return copy.isDefault(availableControls: availableControls) ? nil : copy
    }

    func isDefault(availableControls: [GamepadControlIdentity]) -> Bool {
        let implicitOrder = availableControls
        let explicitOrderMatches = layerOrder.isEmpty || layerOrder == implicitOrder
        return schemaVersion <= 1
            && explicitOrderMatches
            && groups.isEmpty
            && grid.normalized.isDefault
            && guides.isEmpty
            && (notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && tags.isEmpty
    }
}

extension GamepadControlIdentity: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case button
        case id
    }

    private enum Kind: String, Codable {
        case builtin
        case custom
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let raw = try? single.decode(String.self) {
            if raw.hasPrefix("builtin.") {
                let buttonRaw = String(raw.dropFirst("builtin.".count))
                if let button = GameButton(rawValue: buttonRaw) {
                    self = .builtin(button)
                    return
                }
            } else if raw.hasPrefix("custom.") {
                let idRaw = String(raw.dropFirst("custom.".count))
                if let id = UUID(uuidString: idRaw) {
                    self = .custom(id)
                    return
                }
            } else if let button = GameButton(rawValue: raw) {
                self = .builtin(button)
                return
            } else if let id = UUID(uuidString: raw) {
                self = .custom(id)
                return
            }
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .builtin:
            self = .builtin(try container.decode(GameButton.self, forKey: .button))
        case .custom:
            self = .custom(try container.decode(UUID.self, forKey: .id))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .builtin(let button):
            try container.encode(Kind.builtin, forKey: .kind)
            try container.encode(button, forKey: .button)
        case .custom(let id):
            try container.encode(Kind.custom, forKey: .kind)
            try container.encode(id, forKey: .id)
        }
    }
}

public struct GamepadResolvedControlPresentation: Equatable, Sendable {
    public var fillStyle: GamepadFillStyle
    public var foregroundColor: GamepadRGBAColor
    public var strokeColor: GamepadRGBAColor
    public var strokeWidth: CGFloat
    public var shadowColor: GamepadRGBAColor
    public var shadowRadius: CGFloat
    public var shadowX: CGFloat
    public var shadowY: CGFloat
    public var glowColor: GamepadRGBAColor?
    public var glowRadius: CGFloat
    public var opacity: CGFloat
    public var scale: CGFloat
    public var blurRadius: CGFloat
    public var icon: GamepadControlIcon?
    public var hapticStyle: GamepadHapticStyle
    public var hapticFeedback: GamepadHapticFeedback

    public init(
        fillStyle: GamepadFillStyle,
        foregroundColor: GamepadRGBAColor,
        strokeColor: GamepadRGBAColor,
        strokeWidth: CGFloat,
        shadowColor: GamepadRGBAColor,
        shadowRadius: CGFloat,
        shadowX: CGFloat = 0,
        shadowY: CGFloat,
        glowColor: GamepadRGBAColor? = nil,
        glowRadius: CGFloat = 0,
        opacity: CGFloat = 1,
        scale: CGFloat = 1,
        blurRadius: CGFloat = 0,
        icon: GamepadControlIcon? = nil,
        hapticStyle: GamepadHapticStyle = .light,
        hapticFeedback: GamepadHapticFeedback? = nil
    ) {
        self.fillStyle = fillStyle.normalized
        self.foregroundColor = foregroundColor.normalized
        self.strokeColor = strokeColor.normalized
        self.strokeWidth = Self.clamp(strokeWidth, lower: 0, upper: 12)
        self.shadowColor = shadowColor.normalized
        self.shadowRadius = Self.clamp(shadowRadius, lower: 0, upper: 64)
        self.shadowX = Self.clamp(shadowX, lower: -64, upper: 64)
        self.shadowY = Self.clamp(shadowY, lower: -64, upper: 64)
        self.glowColor = glowColor?.normalized
        self.glowRadius = Self.clamp(glowRadius, lower: 0, upper: 64)
        self.opacity = Self.clamp(opacity, lower: 0, upper: 1)
        self.scale = Self.clamp(scale, lower: 0.5, upper: 1.5)
        self.blurRadius = Self.clamp(blurRadius, lower: 0, upper: 24)
        self.icon = icon?.normalized
        let resolvedHapticFeedback = (hapticFeedback ?? GamepadHapticFeedback(style: hapticStyle)).normalized
        self.hapticFeedback = resolvedHapticFeedback
        self.hapticStyle = resolvedHapticFeedback.style
    }

    public var foregroundSwiftUIColor: Color { foregroundColor.swiftUIColor }
    public var strokeSwiftUIColor: Color { strokeColor.swiftUIColor }
    public var shadowSwiftUIColor: Color { shadowColor.swiftUIColor }
    public var glowSwiftUIColor: Color? { glowColor?.swiftUIColor }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }
}

extension GamepadButtonCustomization {
    var hasRichDesignOverrides: Bool {
        styleID != nil || visualStyle != nil || icon != nil || hapticStyle != nil || hapticFeedback != nil
    }

    var styleSnapshot: GamepadButtonCustomization {
        GamepadButtonCustomization(
            shape: shape,
            accentStyle: accentStyle,
            fillColor: fillColor,
            lightFillColor: lightFillColor,
            darkFillColor: darkFillColor,
            fillStyle: fillStyle,
            lightFillStyle: lightFillStyle,
            darkFillStyle: darkFillStyle,
            joystickKnobColor: joystickKnobColor,
            lightJoystickKnobColor: lightJoystickKnobColor,
            darkJoystickKnobColor: darkJoystickKnobColor,
            styleID: styleID,
            visualStyle: visualStyle,
            icon: icon,
            hapticStyle: hapticStyle,
            hapticFeedback: hapticFeedback,
            cornerRadius: cornerRadius,
            cornerRadii: cornerRadii,
            shadowStrength: shadowStrength
        ).normalized
    }

    mutating func applyStyleSnapshot(_ snapshot: GamepadButtonCustomization) {
        shape = snapshot.shape
        accentStyle = snapshot.accentStyle
        fillColor = snapshot.fillColor
        lightFillColor = snapshot.lightFillColor
        darkFillColor = snapshot.darkFillColor
        fillStyle = snapshot.fillStyle
        lightFillStyle = snapshot.lightFillStyle
        darkFillStyle = snapshot.darkFillStyle
        joystickKnobColor = snapshot.joystickKnobColor
        lightJoystickKnobColor = snapshot.lightJoystickKnobColor
        darkJoystickKnobColor = snapshot.darkJoystickKnobColor
        styleID = snapshot.styleID
        visualStyle = snapshot.visualStyle
        icon = snapshot.icon
        hapticStyle = snapshot.hapticStyle
        hapticFeedback = snapshot.hapticFeedback
        cornerRadius = snapshot.cornerRadius
        cornerRadii = snapshot.cornerRadii
        shadowStrength = snapshot.shadowStrength
    }
}

extension GamepadCustomization {
    var allControlIdentitiesForDesign: [GamepadControlIdentity] {
        GameButton.builtInControls.map { .builtin($0) } + customButtons.map { .custom($0.id) }
    }

    var orderedControlIdentitiesForDesign: [GamepadControlIdentity] {
        if let metadata = designMetadata?.normalized(availableControls: allControlIdentitiesForDesign) {
            return metadata.layerOrder
        }
        return allControlIdentitiesForDesign
    }

    func resolvedPresentation(
        for control: GamepadResolvedControl,
        state: GamepadControlPresentationState = .normal,
        scheme: ColorScheme
    ) -> GamepadResolvedControlPresentation {
        resolvedPresentation(
            for: control.layoutCustomization,
            fallbackAccentStyle: control.layoutCustomization.accentStyle ?? accentStyle,
            controlKind: control.controlKind,
            state: state,
            scheme: scheme
        )
    }

    func resolvedPresentation(
        for layout: GamepadButtonCustomization,
        fallbackAccentStyle: GamepadAccentStyle? = nil,
        controlKind: GamepadCustomControlKind = .button,
        state: GamepadControlPresentationState = .normal,
        scheme: ColorScheme
    ) -> GamepadResolvedControlPresentation {
        let isPressed = state.usesPressedFallback
        let accent = layout.accentStyle ?? fallbackAccentStyle ?? accentStyle
        let baselineFill = layout.buttonFillStyle(accentStyle: accent, isPressed: isPressed, scheme: scheme)
        let baselineForeground = GamepadRGBAColor(
            color: layout.buttonForeground(accentStyle: accent, isPressed: isPressed, scheme: scheme),
            fallback: baselineFill.representativeColor.contrastingForegroundRGBAColor()
        )
        let baselineStroke = GamepadRGBAColor(
            color: layout.buttonStroke(accentStyle: accent, isPressed: isPressed, scheme: scheme),
            fallback: baselineFill.representativeColor.strokeRGBAColor()
        )
        var presentation = GamepadResolvedControlPresentation(
            fillStyle: baselineFill,
            foregroundColor: baselineForeground,
            strokeColor: baselineStroke,
            strokeWidth: isPressed ? 2 : 1,
            shadowColor: GamepadRGBAColor(red: 0, green: 0, blue: 0, alpha: (isPressed ? 0.16 : 0.04) * layout.shadowStrength),
            shadowRadius: (isPressed ? 2 : 1) * max(0.25, layout.shadowStrength),
            shadowY: (isPressed ? 1 : 2) * layout.shadowStrength,
            opacity: state == .disabled ? 0.45 : 1,
            scale: isPressed ? 0.96 : 1,
            icon: layout.icon,
            hapticStyle: layout.hapticStyle ?? .light,
            hapticFeedback: layout.resolvedHapticFeedback
        )

        if let token = styleLibrary.style(id: layout.styleID), token.appliesTo.contains(controlKind) {
            presentation.apply(style: token.visualStyle, state: state)
        }
        if let inline = layout.visualStyle {
            presentation.apply(style: inline, state: state)
        }
        if let icon = layout.icon?.normalized { presentation.icon = icon }
        if let hapticFeedback = layout.hapticFeedback?.normalized {
            presentation.hapticFeedback = hapticFeedback
            presentation.hapticStyle = hapticFeedback.style
        } else if let hapticStyle = layout.hapticStyle {
            presentation.hapticFeedback = GamepadHapticFeedback(style: hapticStyle).normalized
            presentation.hapticStyle = hapticStyle
        }

        return presentation
    }

    mutating func ensureLayerOrderContainsAllControls() {
        let controls = allControlIdentitiesForDesign
        var metadata = designMetadata ?? .empty
        metadata.layerOrder = (metadata.normalized(availableControls: controls)?.layerOrder ?? controls)
        designMetadata = metadata.normalized(availableControls: controls)
    }

    mutating func moveLayer(_ identity: GamepadControlIdentity, to index: Int) {
        let controls = allControlIdentitiesForDesign
        guard controls.contains(identity) else { return }
        var order = designMetadata?.normalized(availableControls: controls)?.layerOrder ?? controls
        order.removeAll { $0 == identity }
        let clampedIndex = min(max(0, index), order.count)
        order.insert(identity, at: clampedIndex)
        var metadata = designMetadata ?? .empty
        metadata.layerOrder = order
        designMetadata = metadata.normalized(availableControls: controls)
    }

    mutating func bringLayerForward(_ identity: GamepadControlIdentity) {
        var order = orderedControlIdentitiesForDesign
        guard let index = order.firstIndex(of: identity), index < order.count - 1 else { return }
        order.swapAt(index, index + 1)
        var metadata = designMetadata ?? .empty
        metadata.layerOrder = order
        designMetadata = metadata.normalized(availableControls: allControlIdentitiesForDesign)
    }

    mutating func sendLayerBackward(_ identity: GamepadControlIdentity) {
        var order = orderedControlIdentitiesForDesign
        guard let index = order.firstIndex(of: identity), index > 0 else { return }
        order.swapAt(index, index - 1)
        var metadata = designMetadata ?? .empty
        metadata.layerOrder = order
        designMetadata = metadata.normalized(availableControls: allControlIdentitiesForDesign)
    }

    mutating func bringLayerToFront(_ identity: GamepadControlIdentity) {
        var order = orderedControlIdentitiesForDesign.filter { $0 != identity }
        guard allControlIdentitiesForDesign.contains(identity) else { return }
        order.append(identity)
        var metadata = designMetadata ?? .empty
        metadata.layerOrder = order
        designMetadata = metadata.normalized(availableControls: allControlIdentitiesForDesign)
    }

    mutating func sendLayerToBack(_ identity: GamepadControlIdentity) {
        var order = orderedControlIdentitiesForDesign.filter { $0 != identity }
        guard allControlIdentitiesForDesign.contains(identity) else { return }
        order.insert(identity, at: 0)
        var metadata = designMetadata ?? .empty
        metadata.layerOrder = order
        designMetadata = metadata.normalized(availableControls: allControlIdentitiesForDesign)
    }
}

private extension GamepadResolvedControlPresentation {
    mutating func apply(style: GamepadControlVisualStyle, state: GamepadControlPresentationState) {
        let normalizedStyle = style.normalized ?? .empty
        let stateStyle = normalizedStyle.stateStyle(for: state).normalized
        if let fillStyle = stateStyle.fillStyle { self.fillStyle = fillStyle.normalized }
        if let foregroundColor = stateStyle.foregroundColor { self.foregroundColor = foregroundColor.normalized }
        if let strokeColor = stateStyle.strokeColor { self.strokeColor = strokeColor.normalized }
        if let strokeWidth = stateStyle.strokeWidth { self.strokeWidth = strokeWidth }
        if let shadowColor = stateStyle.shadowColor { self.shadowColor = shadowColor.normalized }
        if let shadowRadius = stateStyle.shadowRadius { self.shadowRadius = shadowRadius }
        if let shadowX = stateStyle.shadowX { self.shadowX = shadowX }
        if let shadowY = stateStyle.shadowY { self.shadowY = shadowY }
        if let glowColor = stateStyle.glowColor { self.glowColor = glowColor.normalized }
        if let glowRadius = stateStyle.glowRadius { self.glowRadius = glowRadius }
        if let opacity = stateStyle.opacity { self.opacity = opacity }
        if let scale = stateStyle.scale { self.scale = scale }
        if let blurRadius = stateStyle.blurRadius { self.blurRadius = blurRadius }
        if let icon = normalizedStyle.icon?.normalized { self.icon = icon }
        if let hapticFeedback = normalizedStyle.hapticFeedback?.normalized {
            self.hapticFeedback = hapticFeedback
            self.hapticStyle = hapticFeedback.style
        } else if let hapticStyle = normalizedStyle.hapticStyle {
            self.hapticFeedback = GamepadHapticFeedback(style: hapticStyle).normalized
            self.hapticStyle = hapticStyle
        }
    }
}

extension GamepadRGBAColor {
    func contrastingForegroundRGBAColor(alpha: CGFloat = 1) -> GamepadRGBAColor {
        let normalized = normalized
        let luminance = 0.299 * normalized.red + 0.587 * normalized.green + 0.114 * normalized.blue
        if luminance > 0.56 {
            return GamepadRGBAColor(red: 0, green: 0, blue: 0, alpha: alpha).normalized
        }
        return GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: alpha).normalized
    }

    func strokeRGBAColor() -> GamepadRGBAColor {
        let normalized = normalized
        return GamepadRGBAColor(
            red: min(1, normalized.red * 0.76),
            green: min(1, normalized.green * 0.76),
            blue: min(1, normalized.blue * 0.76),
            alpha: min(1, max(0.32, normalized.alpha + 0.14))
        ).normalized
    }
}
