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
        var copy = self
        copy.normalizeInPlace()
        return copy
    }

    mutating func normalizeInPlace() {
        normalizeIdentityAndFeedbackInPlace()
        normalizeVisualStyleInPlace()
        normalizeGeometryAndColorInPlace()
    }

    private mutating func normalizeIdentityAndFeedbackInPlace() {
        let normalizedStyleID = styleID.map(GamepadStyleToken.normalizedIdentifier) ?? ""
        styleID = normalizedStyleID.isEmpty ? nil : normalizedStyleID
        icon = icon?.normalized
        hapticFeedback = hapticFeedback?.normalized
    }

    private mutating func normalizeVisualStyleInPlace() {
        visualStyle = visualStyle?.normalized
    }

    private mutating func normalizeGeometryAndColorInPlace() {
        cornerRadius = cornerRadius.map(GamepadButtonCustomization.normalizedCornerRadius)
        cornerRadii = cornerRadii?.normalized
        shadowStrength = shadowStrength.map {
            GamepadButtonCustomization.clamp(
                $0,
                lower: GamepadButtonCustomization.minimumShadowStrength,
                upper: GamepadButtonCustomization.maximumShadowStrength
            )
        }
        joystickKnobColor = joystickKnobColor?.normalized
    }

    public var isEmpty: Bool {
        var value = self
        value.normalizeInPlace()
        return value.isEmptyWithoutNormalization
    }

    fileprivate var isEmptyWithoutNormalization: Bool {
        if styleID != nil { return false }
        if shape != nil { return false }
        if accentStyle != nil { return false }
        if visualStyle != nil { return false }
        if icon != nil { return false }
        if hapticFeedback != nil { return false }
        if cornerRadius != nil { return false }
        if cornerRadii != nil { return false }
        if shadowStrength != nil { return false }
        if joystickKnobColor != nil { return false }
        return joystickVisualStyle == nil
    }

    /// Returns this appearance layered over a less-specific appearance.
    public func merged(over base: PocketPadSkinControlAppearance) -> PocketPadSkinControlAppearance {
        MergeWorkspace(base: base, overlay: self).resolve()
    }

    private final class MergeWorkspace {
        private var base: PocketPadSkinControlAppearance
        private var overlay: PocketPadSkinControlAppearance
        private var result: PocketPadSkinControlAppearance

        init(base: PocketPadSkinControlAppearance, overlay: PocketPadSkinControlAppearance) {
            self.base = base
            self.overlay = overlay
            self.result = base
        }

        func resolve() -> PocketPadSkinControlAppearance {
            base.normalizeInPlace()
            overlay.normalizeInPlace()
            result = base
            applyOverlay()
            result.normalizeInPlace()
            return result
        }

        private func applyOverlay() {
            if let value = overlay.styleID { result.styleID = value }
            if let value = overlay.shape { result.shape = value }
            if let value = overlay.accentStyle { result.accentStyle = value }
            if let value = overlay.visualStyle { result.visualStyle = value }
            if let value = overlay.icon { result.icon = value }
            if let value = overlay.hapticFeedback { result.hapticFeedback = value }
            if let value = overlay.cornerRadius { result.cornerRadius = value }
            if let value = overlay.cornerRadii { result.cornerRadii = value }
            if let value = overlay.shadowStrength { result.shadowStrength = value }
            if let value = overlay.joystickKnobColor { result.joystickKnobColor = value }
            if let value = overlay.joystickVisualStyle { result.joystickVisualStyle = value }
        }
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
        var copy = self
        copy.normalizeInPlace()
        return copy
    }

    mutating func normalizeInPlace() {
        normalizeSurfaceInPlace()
        normalizeDefaultControlInPlace()
        normalizeRoleRulesInPlace()
        normalizeButtonRulesInPlace()
        normalizeLibrariesAndArtworkInPlace()
    }

    private mutating func normalizeSurfaceInPlace() {
        backgroundFillStyle = backgroundFillStyle?.normalized
    }

    private mutating func normalizeDefaultControlInPlace() {
        guard var value = defaultControl else { return }
        value.normalizeInPlace()
        defaultControl = value.isEmptyWithoutNormalization ? nil : value
    }

    private mutating func normalizeRoleRulesInPlace() {
        var byRole: [GamepadVisualRole: PocketPadSkinControlAppearance] = [:]
        for rule in roleRules {
            var appearance = rule.appearance
            appearance.normalizeInPlace()
            if !appearance.isEmptyWithoutNormalization {
                byRole[rule.role] = appearance
            }
        }
        var normalizedRules: [PocketPadSkinRoleRule] = []
        normalizedRules.reserveCapacity(byRole.count)
        for role in GamepadVisualRole.allCases {
            if let appearance = byRole[role] {
                normalizedRules.append(PocketPadSkinRoleRule(role: role, appearance: appearance))
            }
        }
        roleRules = normalizedRules
    }

    private mutating func normalizeButtonRulesInPlace() {
        var byButton: [GameButton: PocketPadSkinControlAppearance] = [:]
        for rule in buttonRules {
            var appearance = rule.appearance
            appearance.normalizeInPlace()
            if !appearance.isEmptyWithoutNormalization {
                byButton[rule.button] = appearance
            }
        }
        var normalizedRules: [PocketPadSkinButtonRule] = []
        normalizedRules.reserveCapacity(byButton.count)
        for button in GameButton.allCases {
            if let appearance = byButton[button] {
                normalizedRules.append(PocketPadSkinButtonRule(button: button, appearance: appearance))
            }
        }
        buttonRules = normalizedRules
    }

    private mutating func normalizeLibrariesAndArtworkInPlace() {
        styleLibrary = styleLibrary.normalized
        artworkLayers = normalizedArtworkLayers(artworkLayers ?? [])
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
        ControlAppearanceResolutionWorkspace(
            appearance: self,
            button: button,
            controlKind: controlKind,
            visualRole: visualRole
        ).resolve()
    }

    public func controlAppearance(for role: GamepadVisualRole) -> PocketPadSkinControlAppearance {
        ControlAppearanceResolutionWorkspace(
            appearance: self,
            visualRole: role
        ).resolve()
    }

    private final class ControlAppearanceResolutionWorkspace {
        private var appearance: PocketPadSkinAppearance
        private let button: GameButton?
        private let controlKind: GamepadCustomControlKind?
        private let requestedRole: GamepadVisualRole?
        private var result = PocketPadSkinControlAppearance.empty

        init(
            appearance: PocketPadSkinAppearance,
            button: GameButton,
            controlKind: GamepadCustomControlKind,
            visualRole: GamepadVisualRole?
        ) {
            self.appearance = appearance
            self.button = button
            self.controlKind = controlKind
            self.requestedRole = visualRole
        }

        init(
            appearance: PocketPadSkinAppearance,
            visualRole: GamepadVisualRole
        ) {
            self.appearance = appearance
            self.button = nil
            self.controlKind = nil
            self.requestedRole = visualRole
        }

        func resolve() -> PocketPadSkinControlAppearance {
            normalizeAppearance()
            selectDefaultAppearance()
            mergeRoleAppearance()
            mergeButtonAppearance()
            return result
        }

        private func normalizeAppearance() {
            appearance.normalizeInPlace()
        }

        private func selectDefaultAppearance() {
            result = appearance.defaultControl ?? .empty
        }

        private func mergeRoleAppearance() {
            guard let role = resolvedRole,
                  let roleAppearance = appearance.roleRules.last(where: { $0.role == role })?.appearance
            else { return }
            result = roleAppearance.merged(over: result)
        }

        private func mergeButtonAppearance() {
            guard let button,
                  let buttonAppearance = appearance.buttonRules.last(where: { $0.button == button })?.appearance
            else { return }
            result = buttonAppearance.merged(over: result)
        }

        private var resolvedRole: GamepadVisualRole? {
            if let requestedRole { return requestedRole }
            guard let button, let controlKind else { return nil }
            return GamepadVisualRole.inferred(for: button, controlKind: controlKind)
        }
    }

    /// Returns this appearance layered over a less-specific appearance.
    public func merged(over base: PocketPadSkinAppearance) -> PocketPadSkinAppearance {
        MergeWorkspace(base: base, overlay: self).resolve()
    }

    private final class MergeWorkspace {
        private var base: PocketPadSkinAppearance
        private var overlay: PocketPadSkinAppearance
        private var result: PocketPadSkinAppearance

        init(base: PocketPadSkinAppearance, overlay: PocketPadSkinAppearance) {
            self.base = base
            self.overlay = overlay
            self.result = base
        }

        func resolve() -> PocketPadSkinAppearance {
            base.normalizeInPlace()
            overlay.normalizeInPlace()
            result = base
            mergeSurface()
            mergeStyles()
            mergeRoleRules()
            mergeButtonRules()
            mergeDefaultControl()
            mergeArtwork()
            result.normalizeInPlace()
            return result
        }

        private func mergeSurface() {
            if let value = overlay.backgroundFillStyle { result.backgroundFillStyle = value }
            if let value = overlay.accentStyle { result.accentStyle = value }
            if let value = overlay.showsButtonLabels { result.showsButtonLabels = value }
        }

        private func mergeStyles() {
            var styles = base.styleLibrary.styles
            for style in overlay.styleLibrary.styles {
                if let index = styles.firstIndex(where: { $0.id == style.id }) {
                    styles[index] = style
                } else {
                    styles.append(style)
                }
            }
            result.styleLibrary = GamepadStyleLibrary(styles: styles)
        }

        private func mergeRoleRules() {
            var rules = base.roleRules
            for rule in overlay.roleRules {
                if let index = rules.firstIndex(where: { $0.role == rule.role }) {
                    rules[index].appearance = rule.appearance.merged(over: rules[index].appearance)
                } else {
                    rules.append(rule)
                }
            }
            result.roleRules = rules
        }

        private func mergeButtonRules() {
            var rules = base.buttonRules
            for rule in overlay.buttonRules {
                if let index = rules.firstIndex(where: { $0.button == rule.button }) {
                    rules[index].appearance = rule.appearance.merged(over: rules[index].appearance)
                } else {
                    rules.append(rule)
                }
            }
            result.buttonRules = rules
        }

        private func mergeDefaultControl() {
            if let overlayDefault = overlay.defaultControl {
                result.defaultControl = overlayDefault.merged(over: base.defaultControl ?? .empty)
            } else {
                result.defaultControl = base.defaultControl
            }
        }

        private func mergeArtwork() {
            var artworkByID: [String: PocketPadSkinArtworkLayer] = [:]
            for layer in base.artworkLayers ?? [] { artworkByID[layer.id] = layer }
            for layer in overlay.artworkLayers ?? [] { artworkByID[layer.id] = layer }
            result.artworkLayers = artworkByID.values
                .filter { !$0.isHidden }
                .sorted {
                    if $0.plane != $1.plane { return $0.plane.rawValue < $1.plane.rawValue }
                    if $0.zIndex != $1.zIndex { return $0.zIndex < $1.zIndex }
                    return $0.id < $1.id
                }
        }
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
