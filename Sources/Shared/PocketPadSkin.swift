import Foundation

/// Semantic roles let a skin style controls without depending on profile-specific UUIDs or labels.
public enum GamepadVisualRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case movement
    case primaryAction = "primary_action"
    case secondaryAction = "secondary_action"
    case utility
    case menu
    case custom
    case joystick
    case trigger
    case trackpad
    case decoration
    case system

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .movement: "Movement"
        case .primaryAction: "Primary Action"
        case .secondaryAction: "Secondary Action"
        case .utility: "Utility"
        case .menu: "Menu"
        case .custom: "Custom Action"
        case .joystick: "Joystick"
        case .trigger: "Trigger"
        case .trackpad: "Trackpad"
        case .decoration: "Decoration"
        case .system: "System"
        }
    }

    public static func inferred(for button: GameButton, controlKind: GamepadCustomControlKind) -> GamepadVisualRole {
        switch controlKind {
        case .joystick: return .joystick
        case .trigger: return .trigger
        case .trackpad: return .trackpad
        case .decoration: return .decoration
        case .button:
            switch button {
            case .up, .down, .left, .right: return .movement
            case .jump, .attack: return .primaryAction
            case .dash, .focus: return .secondaryAction
            case .map: return .utility
            case .pause: return .menu
            case .custom1, .custom2, .custom3, .custom4, .custom5, .custom6, .custom7, .custom8: return .custom
            }
        }
    }
}

public enum PocketPadSkinOrientation: String, Codable, CaseIterable, Identifiable, Sendable {
    case portrait
    case landscape

    public var id: String { rawValue }
}

public enum PocketPadSkinColorScheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case light
    case dark

    public var id: String { rawValue }
}

public enum PocketPadSkinArtworkPlane: String, Codable, CaseIterable, Identifiable, Sendable {
    case underlay
    case overlay

    public var id: String { rawValue }
}

public enum PocketPadSkinArtworkBlendMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case multiply
    case screen
    case overlay
    case softLight = "soft_light"

    public var id: String { rawValue }
}

/// Passive canvas decoration. It has no hit target, output binding, label, or accessibility action.
public struct PocketPadSkinArtworkLayer: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var plane: PocketPadSkinArtworkPlane
    public var frame: PocketPadNormalizedRect?
    public var fillStyle: GamepadFillStyle?
    public var opacity: CGFloat
    public var rotationDegrees: CGFloat
    public var blendMode: PocketPadSkinArtworkBlendMode
    public var zIndex: Int
    public var isHidden: Bool

    public init(
        id: String,
        plane: PocketPadSkinArtworkPlane = .underlay,
        frame: PocketPadNormalizedRect? = nil,
        fillStyle: GamepadFillStyle? = nil,
        opacity: CGFloat = 1,
        rotationDegrees: CGFloat = 0,
        blendMode: PocketPadSkinArtworkBlendMode = .normal,
        zIndex: Int = 0,
        isHidden: Bool = false
    ) {
        self.id = id
        self.plane = plane
        self.frame = frame
        self.fillStyle = fillStyle
        self.opacity = opacity
        self.rotationDegrees = rotationDegrees
        self.blendMode = blendMode
        self.zIndex = zIndex
        self.isHidden = isHidden
    }

    public var normalized: PocketPadSkinArtworkLayer? {
        let id = GamepadStyleToken.normalizedIdentifier(id)
        guard !id.isEmpty else { return nil }
        let rotation = rotationDegrees.isFinite ? rotationDegrees.truncatingRemainder(dividingBy: 360) : 0
        return PocketPadSkinArtworkLayer(
            id: id,
            plane: plane,
            frame: (frame ?? PocketPadNormalizedRect(x: 0, y: 0, width: 1, height: 1)).normalized,
            fillStyle: fillStyle?.normalized,
            opacity: min(max(opacity.isFinite ? opacity : 1, 0), 1),
            rotationDegrees: rotation,
            blendMode: blendMode,
            zIndex: min(max(zIndex, -10_000), 10_000),
            isHidden: isHidden
        )
    }
}

/// Appearance-only properties for one control. Geometry and output bindings deliberately do not live here.
public struct PocketPadSkinControlAppearance: Codable, Equatable, Sendable {
    public var styleID: String?
    public var shape: GamepadButtonShapeStyle?
    public var accentStyle: GamepadAccentStyle?
    public var visualStyle: GamepadControlVisualStyle?
    public var icon: GamepadControlIcon?
    public var hapticFeedback: GamepadHapticFeedback?
    public var cornerRadius: CGFloat?
    public var cornerRadii: GamepadCornerRadii?
    public var shadowStrength: CGFloat?
    public var joystickKnobColor: GamepadRGBAColor?
    public var joystickVisualStyle: GamepadJoystickVisualStyle?

    public init(
        styleID: String? = nil,
        shape: GamepadButtonShapeStyle? = nil,
        accentStyle: GamepadAccentStyle? = nil,
        visualStyle: GamepadControlVisualStyle? = nil,
        icon: GamepadControlIcon? = nil,
        hapticFeedback: GamepadHapticFeedback? = nil,
        cornerRadius: CGFloat? = nil,
        cornerRadii: GamepadCornerRadii? = nil,
        shadowStrength: CGFloat? = nil,
        joystickKnobColor: GamepadRGBAColor? = nil,
        joystickVisualStyle: GamepadJoystickVisualStyle? = nil
    ) {
        self.styleID = styleID
        self.shape = shape
        self.accentStyle = accentStyle
        self.visualStyle = visualStyle
        self.icon = icon
        self.hapticFeedback = hapticFeedback
        self.cornerRadius = cornerRadius
        self.cornerRadii = cornerRadii
        self.shadowStrength = shadowStrength
        self.joystickKnobColor = joystickKnobColor
        self.joystickVisualStyle = joystickVisualStyle
    }

    public static let empty = PocketPadSkinControlAppearance()

    public var normalized: PocketPadSkinControlAppearance {
        let normalizedStyleID = styleID.map(GamepadStyleToken.normalizedIdentifier) ?? ""
        return PocketPadSkinControlAppearance(
            styleID: normalizedStyleID.isEmpty ? nil : normalizedStyleID,
            shape: shape,
            accentStyle: accentStyle,
            visualStyle: visualStyle?.normalized,
            icon: icon?.normalized,
            hapticFeedback: hapticFeedback?.normalized,
            cornerRadius: cornerRadius.map(GamepadButtonCustomization.normalizedCornerRadius),
            cornerRadii: cornerRadii?.normalized,
            shadowStrength: shadowStrength.map {
                GamepadButtonCustomization.clamp(
                    $0,
                    lower: GamepadButtonCustomization.minimumShadowStrength,
                    upper: GamepadButtonCustomization.maximumShadowStrength
                )
            },
            joystickKnobColor: joystickKnobColor?.normalized,
            joystickVisualStyle: joystickVisualStyle
        )
    }

    public var isEmpty: Bool {
        let value = normalized
        return value.styleID == nil
            && value.shape == nil
            && value.accentStyle == nil
            && value.visualStyle == nil
            && value.icon == nil
            && value.hapticFeedback == nil
            && value.cornerRadius == nil
            && value.cornerRadii == nil
            && value.shadowStrength == nil
            && value.joystickKnobColor == nil
            && value.joystickVisualStyle == nil
    }

    /// Returns this appearance layered over a less-specific appearance.
    public func merged(over base: PocketPadSkinControlAppearance) -> PocketPadSkinControlAppearance {
        let base = base.normalized
        let overlay = normalized
        return PocketPadSkinControlAppearance(
            styleID: overlay.styleID ?? base.styleID,
            shape: overlay.shape ?? base.shape,
            accentStyle: overlay.accentStyle ?? base.accentStyle,
            visualStyle: overlay.visualStyle ?? base.visualStyle,
            icon: overlay.icon ?? base.icon,
            hapticFeedback: overlay.hapticFeedback ?? base.hapticFeedback,
            cornerRadius: overlay.cornerRadius ?? base.cornerRadius,
            cornerRadii: overlay.cornerRadii ?? base.cornerRadii,
            shadowStrength: overlay.shadowStrength ?? base.shadowStrength,
            joystickKnobColor: overlay.joystickKnobColor ?? base.joystickKnobColor,
            joystickVisualStyle: overlay.joystickVisualStyle ?? base.joystickVisualStyle
        ).normalized
    }
}

public struct PocketPadSkinRoleRule: Codable, Equatable, Sendable {
    public var role: GamepadVisualRole
    public var appearance: PocketPadSkinControlAppearance

    public init(role: GamepadVisualRole, appearance: PocketPadSkinControlAppearance) {
        self.role = role
        self.appearance = appearance
    }
}

public struct PocketPadSkinButtonRule: Codable, Equatable, Sendable {
    public var button: GameButton
    public var appearance: PocketPadSkinControlAppearance

    public init(button: GameButton, appearance: PocketPadSkinControlAppearance) {
        self.button = button
        self.appearance = appearance
    }
}

/// A complete appearance layer. Every property is optional so variants can override only what changes.
public struct PocketPadSkinAppearance: Codable, Equatable, Sendable {
    public var backgroundFillStyle: GamepadFillStyle?
    public var accentStyle: GamepadAccentStyle?
    public var showsButtonLabels: Bool?
    public var defaultControl: PocketPadSkinControlAppearance?
    public var roleRules: [PocketPadSkinRoleRule]
    public var buttonRules: [PocketPadSkinButtonRule]
    public var styleLibrary: GamepadStyleLibrary
    /// Optional for schema-1 decoding; normalized values always use a concrete array.
    public var artworkLayers: [PocketPadSkinArtworkLayer]?

    public init(
        backgroundFillStyle: GamepadFillStyle? = nil,
        accentStyle: GamepadAccentStyle? = nil,
        showsButtonLabels: Bool? = nil,
        defaultControl: PocketPadSkinControlAppearance? = nil,
        roleRules: [PocketPadSkinRoleRule] = [],
        buttonRules: [PocketPadSkinButtonRule] = [],
        styleLibrary: GamepadStyleLibrary = .empty,
        artworkLayers: [PocketPadSkinArtworkLayer] = []
    ) {
        self.backgroundFillStyle = backgroundFillStyle
        self.accentStyle = accentStyle
        self.showsButtonLabels = showsButtonLabels
        self.defaultControl = defaultControl
        self.roleRules = roleRules
        self.buttonRules = buttonRules
        self.styleLibrary = styleLibrary
        self.artworkLayers = artworkLayers
    }

    public static let empty = PocketPadSkinAppearance()

    public var normalized: PocketPadSkinAppearance {
        var roleByID: [GamepadVisualRole: PocketPadSkinControlAppearance] = [:]
        for rule in roleRules {
            let appearance = rule.appearance.normalized
            if !appearance.isEmpty { roleByID[rule.role] = appearance }
        }
        var buttonByID: [GameButton: PocketPadSkinControlAppearance] = [:]
        for rule in buttonRules {
            let appearance = rule.appearance.normalized
            if !appearance.isEmpty { buttonByID[rule.button] = appearance }
        }
        let normalizedDefault = defaultControl?.normalized
        return PocketPadSkinAppearance(
            backgroundFillStyle: backgroundFillStyle?.normalized,
            accentStyle: accentStyle,
            showsButtonLabels: showsButtonLabels,
            defaultControl: normalizedDefault?.isEmpty == false ? normalizedDefault : nil,
            roleRules: GamepadVisualRole.allCases.compactMap { role in
                roleByID[role].map { PocketPadSkinRoleRule(role: role, appearance: $0) }
            },
            buttonRules: GameButton.allCases.compactMap { button in
                buttonByID[button].map { PocketPadSkinButtonRule(button: button, appearance: $0) }
            },
            styleLibrary: styleLibrary.normalized,
            artworkLayers: normalizedArtworkLayers(artworkLayers ?? [])
        )
    }

    private func normalizedArtworkLayers(_ layers: [PocketPadSkinArtworkLayer]) -> [PocketPadSkinArtworkLayer] {
        var byID: [String: PocketPadSkinArtworkLayer] = [:]
        for layer in layers {
            if let normalized = layer.normalized { byID[normalized.id] = normalized }
        }
        return byID.values.sorted {
            if $0.plane != $1.plane { return $0.plane.rawValue < $1.plane.rawValue }
            if $0.zIndex != $1.zIndex { return $0.zIndex < $1.zIndex }
            return $0.id < $1.id
        }
    }

    public func controlAppearance(
        for button: GameButton,
        controlKind: GamepadCustomControlKind,
        visualRole: GamepadVisualRole? = nil
    ) -> PocketPadSkinControlAppearance {
        let value = normalized
        let role = visualRole ?? GamepadVisualRole.inferred(for: button, controlKind: controlKind)
        let roleAppearance = value.roleRules.last { $0.role == role }?.appearance ?? .empty
        let buttonAppearance = value.buttonRules.last { $0.button == button }?.appearance ?? .empty
        return buttonAppearance.merged(over: roleAppearance.merged(over: value.defaultControl ?? .empty))
    }

    public func controlAppearance(for role: GamepadVisualRole) -> PocketPadSkinControlAppearance {
        let value = normalized
        let roleAppearance = value.roleRules.last { $0.role == role }?.appearance ?? .empty
        return roleAppearance.merged(over: value.defaultControl ?? .empty)
    }

    /// Returns this appearance layered over a less-specific appearance.
    public func merged(over base: PocketPadSkinAppearance) -> PocketPadSkinAppearance {
        let base = base.normalized
        let overlay = normalized

        var styles = base.styleLibrary.styles
        for style in overlay.styleLibrary.styles {
            if let index = styles.firstIndex(where: { $0.id == style.id }) {
                styles[index] = style
            } else {
                styles.append(style)
            }
        }

        var roleRules = base.roleRules
        for rule in overlay.roleRules {
            if let index = roleRules.firstIndex(where: { $0.role == rule.role }) {
                roleRules[index].appearance = rule.appearance.merged(over: roleRules[index].appearance)
            } else {
                roleRules.append(rule)
            }
        }

        var buttonRules = base.buttonRules
        for rule in overlay.buttonRules {
            if let index = buttonRules.firstIndex(where: { $0.button == rule.button }) {
                buttonRules[index].appearance = rule.appearance.merged(over: buttonRules[index].appearance)
            } else {
                buttonRules.append(rule)
            }
        }

        let defaultControl: PocketPadSkinControlAppearance?
        if let overlayDefault = overlay.defaultControl {
            defaultControl = overlayDefault.merged(over: base.defaultControl ?? .empty)
        } else {
            defaultControl = base.defaultControl
        }

        var artworkByID = Dictionary(uniqueKeysWithValues: (base.artworkLayers ?? []).map { ($0.id, $0) })
        for layer in overlay.artworkLayers ?? [] { artworkByID[layer.id] = layer }
        let artworkLayers = artworkByID.values
            .filter { !$0.isHidden }
            .sorted {
                if $0.plane != $1.plane { return $0.plane.rawValue < $1.plane.rawValue }
                if $0.zIndex != $1.zIndex { return $0.zIndex < $1.zIndex }
                return $0.id < $1.id
            }

        return PocketPadSkinAppearance(
            backgroundFillStyle: overlay.backgroundFillStyle ?? base.backgroundFillStyle,
            accentStyle: overlay.accentStyle ?? base.accentStyle,
            showsButtonLabels: overlay.showsButtonLabels ?? base.showsButtonLabels,
            defaultControl: defaultControl,
            roleRules: roleRules,
            buttonRules: buttonRules,
            styleLibrary: GamepadStyleLibrary(styles: styles),
            artworkLayers: artworkLayers
        ).normalized
    }
}

public struct PocketPadSkinVariant: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var orientation: PocketPadSkinOrientation?
    public var colorScheme: PocketPadSkinColorScheme?
    public var appearance: PocketPadSkinAppearance

    public init(
        id: String,
        orientation: PocketPadSkinOrientation? = nil,
        colorScheme: PocketPadSkinColorScheme? = nil,
        appearance: PocketPadSkinAppearance
    ) {
        self.id = id
        self.orientation = orientation
        self.colorScheme = colorScheme
        self.appearance = appearance
    }

    public var specificity: Int {
        (orientation == nil ? 0 : 1) + (colorScheme == nil ? 0 : 1)
    }

    public func matches(
        orientation requestedOrientation: PocketPadSkinOrientation,
        colorScheme requestedColorScheme: PocketPadSkinColorScheme
    ) -> Bool {
        (orientation == nil || orientation == requestedOrientation)
            && (colorScheme == nil || colorScheme == requestedColorScheme)
    }

    public var normalized: PocketPadSkinVariant? {
        let normalizedID = GamepadStyleToken.normalizedIdentifier(id)
        guard !normalizedID.isEmpty else { return nil }
        return PocketPadSkinVariant(
            id: normalizedID,
            orientation: orientation,
            colorScheme: colorScheme,
            appearance: appearance.normalized
        )
    }
}

public struct PocketPadSkin: Codable, Equatable, Sendable {
    public var base: PocketPadSkinAppearance
    public var variants: [PocketPadSkinVariant]

    public init(base: PocketPadSkinAppearance, variants: [PocketPadSkinVariant] = []) {
        self.base = base
        self.variants = variants
    }

    public var normalized: PocketPadSkin {
        var seen = Set<String>()
        let variants = variants.compactMap { variant -> PocketPadSkinVariant? in
            guard let normalized = variant.normalized, seen.insert(normalized.id).inserted else { return nil }
            return normalized
        }
        return PocketPadSkin(base: base.normalized, variants: variants)
    }

    public func appearance(
        orientation: PocketPadSkinOrientation,
        colorScheme: PocketPadSkinColorScheme
    ) -> PocketPadSkinAppearance {
        let value = normalized
        return value.variants
            .filter { $0.matches(orientation: orientation, colorScheme: colorScheme) }
            .sorted { lhs, rhs in
                if lhs.specificity == rhs.specificity { return lhs.id < rhs.id }
                return lhs.specificity < rhs.specificity
            }
            .reduce(value.base) { appearance, variant in
                variant.appearance.merged(over: appearance)
            }
            .normalized
    }
}
