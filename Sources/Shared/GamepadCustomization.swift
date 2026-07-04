import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private let gamepadMaximumLabelLength = 12

public enum GamepadLayoutMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard
    case southpaw

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: "Nav Left"
        case .southpaw: "Actions Left"
        }
    }

    var description: String {
        switch self {
        case .standard: "Navigation controls left, action keys right"
        case .southpaw: "Action keys left, navigation controls right"
        }
    }
}

public enum GamepadControlScale: String, Codable, CaseIterable, Identifiable, Sendable {
    case compact
    case standard
    case large

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Standard"
        case .large: "Large"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .compact: 0.86
        case .standard: 1.0
        case .large: 1.14
        }
    }
}

public enum GamepadColorSchemePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var description: String {
        switch self {
        case .system: "Match the current device appearance."
        case .light: "Always render the keypad in light mode."
        case .dark: "Always render the keypad in dark mode."
        }
    }

    func resolvedColorScheme(system systemScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .system: systemScheme
        case .light: .light
        case .dark: .dark
        }
    }
}

public enum GamepadAccentStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case monochrome
    case blue
    case green
    case purple
    case pink
    case amber

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monochrome: "Mono"
        case .blue: "Blue"
        case .green: "Green"
        case .purple: "Purple"
        case .pink: "Pink"
        case .amber: "Amber"
        }
    }
}

public struct GamepadRGBAColor: Codable, Equatable, Sendable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init?(hexString: String, alpha: CGFloat = 1) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6 || cleaned.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }

        if cleaned.count == 8 {
            self.red = CGFloat((value >> 24) & 0xff) / 255
            self.green = CGFloat((value >> 16) & 0xff) / 255
            self.blue = CGFloat((value >> 8) & 0xff) / 255
            self.alpha = CGFloat(value & 0xff) / 255
        } else {
            self.red = CGFloat((value >> 16) & 0xff) / 255
            self.green = CGFloat((value >> 8) & 0xff) / 255
            self.blue = CGFloat(value & 0xff) / 255
            self.alpha = alpha
        }
    }

    public init(color: Color, fallback: GamepadRGBAColor = .defaultValue) {
#if os(iOS)
        var red: CGFloat = fallback.red
        var green: CGFloat = fallback.green
        var blue: CGFloat = fallback.blue
        var alpha: CGFloat = fallback.alpha
        if UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        } else {
            self = fallback
        }
#elseif os(macOS)
        let nsColor = NSColor(color)
        let rgbColor = nsColor.usingColorSpace(.deviceRGB) ?? nsColor.usingColorSpace(.sRGB)
        var red: CGFloat = fallback.red
        var green: CGFloat = fallback.green
        var blue: CGFloat = fallback.blue
        var alpha: CGFloat = fallback.alpha
        if let rgbColor {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        } else {
            self = fallback
        }
#else
        self = fallback
#endif
    }

    public static let defaultValue = GamepadRGBAColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1)

    var normalized: GamepadRGBAColor {
        GamepadRGBAColor(
            red: Self.clamp(red),
            green: Self.clamp(green),
            blue: Self.clamp(blue),
            alpha: Self.clamp(alpha)
        )
    }

    var swiftUIColor: Color {
        Color(.sRGB, red: Double(normalized.red), green: Double(normalized.green), blue: Double(normalized.blue), opacity: Double(normalized.alpha))
    }

    var hexString: String {
        let normalized = normalized
        return String(
            format: "#%02X%02X%02X",
            Int((normalized.red * 255).rounded()),
            Int((normalized.green * 255).rounded()),
            Int((normalized.blue * 255).rounded())
        )
    }

    var opacityPercentageText: String {
        "\(Int((normalized.alpha * 100).rounded()))%"
    }

    func adjustedForPress(_ isPressed: Bool) -> GamepadRGBAColor {
        guard isPressed else { return normalized }
        let normalized = normalized
        return GamepadRGBAColor(
            red: max(0, normalized.red * 0.74),
            green: max(0, normalized.green * 0.74),
            blue: max(0, normalized.blue * 0.74),
            alpha: normalized.alpha
        )
    }

    var strokeColor: Color {
        let normalized = normalized
        return Color(
            .sRGB,
            red: Double(min(1, normalized.red * 0.76)),
            green: Double(min(1, normalized.green * 0.76)),
            blue: Double(min(1, normalized.blue * 0.76)),
            opacity: Double(min(1, max(0.32, normalized.alpha + 0.14)))
        )
    }

    var foregroundColor: Color {
        let normalized = normalized
        let luminance = 0.299 * normalized.red + 0.587 * normalized.green + 0.114 * normalized.blue
        return luminance > 0.56 ? Color.black : Color.white
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

public struct GamepadCornerRadii: Codable, Equatable, Sendable {
    public var topLeading: CGFloat
    public var topTrailing: CGFloat
    public var bottomTrailing: CGFloat
    public var bottomLeading: CGFloat

    public init(topLeading: CGFloat, topTrailing: CGFloat, bottomTrailing: CGFloat, bottomLeading: CGFloat) {
        self.topLeading = topLeading
        self.topTrailing = topTrailing
        self.bottomTrailing = bottomTrailing
        self.bottomLeading = bottomLeading
    }

    public static func uniform(_ radius: CGFloat) -> GamepadCornerRadii {
        GamepadCornerRadii(topLeading: radius, topTrailing: radius, bottomTrailing: radius, bottomLeading: radius)
    }

    var normalized: GamepadCornerRadii {
        GamepadCornerRadii(
            topLeading: Self.clamp(topLeading),
            topTrailing: Self.clamp(topTrailing),
            bottomTrailing: Self.clamp(bottomTrailing),
            bottomLeading: Self.clamp(bottomLeading)
        )
    }

    var averageRadius: CGFloat {
        (topLeading + topTrailing + bottomTrailing + bottomLeading) / 4
    }

    var isUniform: Bool {
        abs(topLeading - topTrailing) < 0.001
            && abs(topLeading - bottomTrailing) < 0.001
            && abs(topLeading - bottomLeading) < 0.001
    }

    func isUniform(equalTo radius: CGFloat) -> Bool {
        isUniform && abs(topLeading - radius) < 0.001
    }

    var rectangleCornerRadii: RectangleCornerRadii {
        let normalized = normalized
        return RectangleCornerRadii(
            topLeading: normalized.topLeading,
            bottomLeading: normalized.bottomLeading,
            bottomTrailing: normalized.bottomTrailing,
            topTrailing: normalized.topTrailing
        )
    }

    subscript(_ corner: GamepadCorner) -> CGFloat {
        get {
            switch corner {
            case .topLeading: topLeading
            case .topTrailing: topTrailing
            case .bottomTrailing: bottomTrailing
            case .bottomLeading: bottomLeading
            }
        }
        set {
            let clampedValue = Self.clamp(newValue)
            switch corner {
            case .topLeading: topLeading = clampedValue
            case .topTrailing: topTrailing = clampedValue
            case .bottomTrailing: bottomTrailing = clampedValue
            case .bottomLeading: bottomLeading = clampedValue
            }
        }
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, GamepadButtonCustomization.minimumCornerRadius), GamepadButtonCustomization.maximumCornerRadius)
    }
}

public enum GamepadCorner: String, CaseIterable, Identifiable, Sendable {
    case topLeading
    case topTrailing
    case bottomTrailing
    case bottomLeading

    public var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .topLeading: "TL"
        case .topTrailing: "TR"
        case .bottomTrailing: "BR"
        case .bottomLeading: "BL"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .topLeading: "Top left corner radius"
        case .topTrailing: "Top right corner radius"
        case .bottomTrailing: "Bottom right corner radius"
        case .bottomLeading: "Bottom left corner radius"
        }
    }
}

public enum GamepadButtonShapeStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case roundedRectangle = "rounded_rectangle"
    case rectangle
    case capsule
    case circle
    case ellipse
    case polygon
    case star

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .roundedRectangle: "Rounded"
        case .rectangle: "Rectangle"
        case .capsule: "Capsule"
        case .circle: "Circle"
        case .ellipse: "Ellipse"
        case .polygon: "Polygon"
        case .star: "Star"
        }
    }
}

public enum GamepadCustomControlKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case button
    case joystick

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .button: "Button"
        case .joystick: "Joystick"
        }
    }
}

public enum GamepadJoystickDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case up
    case down
    case left
    case right

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        }
    }

    var shortLabel: String {
        switch self {
        case .up: "↑"
        case .down: "↓"
        case .left: "←"
        case .right: "→"
        }
    }
}

public struct GamepadJoystickMapping: Codable, Equatable, Sendable {
    public var up: GameButton
    public var down: GameButton
    public var left: GameButton
    public var right: GameButton

    public init(
        up: GameButton = .up,
        down: GameButton = .down,
        left: GameButton = .left,
        right: GameButton = .right
    ) {
        self.up = up
        self.down = down
        self.left = left
        self.right = right
    }

    public subscript(direction: GamepadJoystickDirection) -> GameButton {
        get {
            switch direction {
            case .up: up
            case .down: down
            case .left: left
            case .right: right
            }
        }
        set {
            switch direction {
            case .up: up = newValue
            case .down: down = newValue
            case .left: left = newValue
            case .right: right = newValue
            }
        }
    }

    public static let movement = GamepadJoystickMapping(up: .up, down: .down, left: .left, right: .right)
    public static let secondary = GamepadJoystickMapping(up: .custom1, down: .custom2, left: .custom3, right: .custom4)
}

struct GamepadRegularPolygonButtonShape: Shape {
    var sides: Int = 3

    func path(in rect: CGRect) -> Path {
        let sideCount = max(3, sides)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let xRadius = rect.width / 2
        let yRadius = rect.height / 2
        var path = Path()

        for index in 0..<sideCount {
            let angle = (-CGFloat.pi / 2) + (CGFloat(index) * 2 * CGFloat.pi / CGFloat(sideCount))
            let point = CGPoint(
                x: center.x + cos(angle) * xRadius,
                y: center.y + sin(angle) * yRadius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

struct GamepadStarButtonShape: Shape {
    var points: Int = 5
    var innerRadiusRatio: CGFloat = 0.45

    func path(in rect: CGRect) -> Path {
        let pointCount = max(3, points)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerXRadius = rect.width / 2
        let outerYRadius = rect.height / 2
        let innerXRadius = outerXRadius * innerRadiusRatio
        let innerYRadius = outerYRadius * innerRadiusRatio
        var path = Path()

        for index in 0..<(pointCount * 2) {
            let isOuterPoint = index.isMultiple(of: 2)
            let angle = (-CGFloat.pi / 2) + (CGFloat(index) * CGFloat.pi / CGFloat(pointCount))
            let point = CGPoint(
                x: center.x + cos(angle) * (isOuterPoint ? outerXRadius : innerXRadius),
                y: center.y + sin(angle) * (isOuterPoint ? outerYRadius : innerYRadius)
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

public struct GamepadButtonCustomization: Codable, Equatable, Sendable {
    public static let minimumScale: CGFloat = 0.55
    public static let maximumScale: CGFloat = 8.0
    public static let minimumCornerRadius: CGFloat = 0
    public static let maximumCornerRadius: CGFloat = 240
    public static let defaultCornerRadius: CGFloat = 6
    public static let minimumShadowStrength: CGFloat = 0
    public static let maximumShadowStrength: CGFloat = 2
    public static let defaultShadowStrength: CGFloat = 1
    public static let defaultValue = GamepadButtonCustomization()

    public var centerX: CGFloat?
    public var centerY: CGFloat?
    public var widthScale: CGFloat
    public var heightScale: CGFloat
    public var rotationDegrees: CGFloat
    public var shape: GamepadButtonShapeStyle?
    public var accentStyle: GamepadAccentStyle?
    /// Legacy/global fill color used by keypads saved before light/dark-specific colors existed.
    public var fillColor: GamepadRGBAColor?
    public var lightFillColor: GamepadRGBAColor?
    public var darkFillColor: GamepadRGBAColor?
    public var cornerRadius: CGFloat?
    public var cornerRadii: GamepadCornerRadii?
    public var shadowStrength: CGFloat
    public var isLocationLocked: Bool
    public var isHidden: Bool

    public init(
        centerX: CGFloat? = nil,
        centerY: CGFloat? = nil,
        widthScale: CGFloat = 1.0,
        heightScale: CGFloat = 1.0,
        rotationDegrees: CGFloat = 0,
        shape: GamepadButtonShapeStyle? = nil,
        accentStyle: GamepadAccentStyle? = nil,
        fillColor: GamepadRGBAColor? = nil,
        lightFillColor: GamepadRGBAColor? = nil,
        darkFillColor: GamepadRGBAColor? = nil,
        cornerRadius: CGFloat? = nil,
        cornerRadii: GamepadCornerRadii? = nil,
        shadowStrength: CGFloat = GamepadButtonCustomization.defaultShadowStrength,
        isLocationLocked: Bool = false,
        isHidden: Bool = false
    ) {
        self.centerX = centerX
        self.centerY = centerY
        self.widthScale = widthScale
        self.heightScale = heightScale
        self.rotationDegrees = rotationDegrees
        self.shape = shape
        self.accentStyle = accentStyle
        self.fillColor = fillColor
        self.lightFillColor = lightFillColor
        self.darkFillColor = darkFillColor
        self.cornerRadius = cornerRadius
        self.cornerRadii = cornerRadii
        self.shadowStrength = shadowStrength
        self.isLocationLocked = isLocationLocked
        self.isHidden = isHidden
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        centerX = try container.decodeIfPresent(CGFloat.self, forKey: .centerX)
        centerY = try container.decodeIfPresent(CGFloat.self, forKey: .centerY)
        widthScale = try container.decodeIfPresent(CGFloat.self, forKey: .widthScale) ?? 1.0
        heightScale = try container.decodeIfPresent(CGFloat.self, forKey: .heightScale) ?? 1.0
        rotationDegrees = try container.decodeIfPresent(CGFloat.self, forKey: .rotationDegrees) ?? 0
        shape = try container.decodeIfPresent(GamepadButtonShapeStyle.self, forKey: .shape)
        accentStyle = try container.decodeIfPresent(GamepadAccentStyle.self, forKey: .accentStyle)
        fillColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .fillColor)
        lightFillColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .lightFillColor)
        darkFillColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .darkFillColor)
        cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius)
        cornerRadii = try container.decodeIfPresent(GamepadCornerRadii.self, forKey: .cornerRadii)
        shadowStrength = try container.decodeIfPresent(CGFloat.self, forKey: .shadowStrength) ?? Self.defaultShadowStrength
        isLocationLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocationLocked) ?? false
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(centerX, forKey: .centerX)
        try container.encodeIfPresent(centerY, forKey: .centerY)
        try container.encode(widthScale, forKey: .widthScale)
        try container.encode(heightScale, forKey: .heightScale)
        try container.encode(rotationDegrees, forKey: .rotationDegrees)
        try container.encodeIfPresent(shape, forKey: .shape)
        try container.encodeIfPresent(accentStyle, forKey: .accentStyle)
        try container.encodeIfPresent(fillColor, forKey: .fillColor)
        try container.encodeIfPresent(lightFillColor, forKey: .lightFillColor)
        try container.encodeIfPresent(darkFillColor, forKey: .darkFillColor)
        try container.encodeIfPresent(cornerRadius, forKey: .cornerRadius)
        try container.encodeIfPresent(cornerRadii, forKey: .cornerRadii)
        try container.encode(shadowStrength, forKey: .shadowStrength)
        try container.encode(isLocationLocked, forKey: .isLocationLocked)
        try container.encode(isHidden, forKey: .isHidden)
    }

    var normalized: GamepadButtonCustomization {
        var copy = self
        copy.centerX = copy.centerX.map { Self.clamp($0, lower: 0, upper: 1) }
        copy.centerY = copy.centerY.map { Self.clamp($0, lower: 0, upper: 1) }
        copy.widthScale = Self.clamp(copy.widthScale, lower: Self.minimumScale, upper: Self.maximumScale)
        copy.heightScale = Self.clamp(copy.heightScale, lower: Self.minimumScale, upper: Self.maximumScale)
        copy.rotationDegrees = Self.normalizedRotationDegrees(copy.rotationDegrees)
        copy.fillColor = copy.fillColor?.normalized
        copy.lightFillColor = copy.lightFillColor?.normalized
        copy.darkFillColor = copy.darkFillColor?.normalized
        let defaultCornerRadius = Self.defaultCornerRadius(for: copy.shape)
        let usesDynamicCornerRadiusDefault = copy.shape?.usesDynamicEditableCornerRadiusDefault == true
        if let cornerRadii = copy.cornerRadii {
            let normalizedRadii = cornerRadii.normalized
            copy.cornerRadii = !usesDynamicCornerRadiusDefault && normalizedRadii.isUniform(equalTo: defaultCornerRadius) ? nil : normalizedRadii
            copy.cornerRadius = nil
        } else if let cornerRadius = copy.cornerRadius {
            let clampedRadius = Self.clamp(cornerRadius, lower: Self.minimumCornerRadius, upper: Self.maximumCornerRadius)
            copy.cornerRadius = !usesDynamicCornerRadiusDefault && abs(clampedRadius - defaultCornerRadius) < 0.001 ? nil : clampedRadius
        }
        copy.shadowStrength = Self.clamp(copy.shadowStrength, lower: Self.minimumShadowStrength, upper: Self.maximumShadowStrength)
        return copy
    }

    var isDefault: Bool {
        centerX == nil
            && centerY == nil
            && abs(widthScale - 1.0) < 0.001
            && abs(heightScale - 1.0) < 0.001
            && abs(rotationDegrees) < 0.001
            && shape == nil
            && accentStyle == nil
            && fillColor == nil
            && lightFillColor == nil
            && darkFillColor == nil
            && cornerRadius == nil
            && cornerRadii == nil
            && abs(shadowStrength - Self.defaultShadowStrength) < 0.001
            && !isLocationLocked
            && !isHidden
    }

    var hasCustomPosition: Bool {
        centerX != nil || centerY != nil
    }

    var needsFreeformLayout: Bool {
        hasCustomPosition
            || abs(widthScale - 1.0) >= 0.001
            || abs(heightScale - 1.0) >= 0.001
            || abs(rotationDegrees) >= 0.001
            || shape != nil
            || isHidden
    }

    func resolvedShape(defaultShape: GamepadButtonShapeStyle) -> GamepadButtonShapeStyle {
        shape ?? defaultShape
    }

    func resolvedCornerRadii(defaultRadius: CGFloat = GamepadButtonCustomization.defaultCornerRadius) -> GamepadCornerRadii {
        cornerRadii ?? .uniform(cornerRadius ?? defaultRadius)
    }

    func fillColor(for scheme: ColorScheme) -> GamepadRGBAColor? {
        switch scheme {
        case .dark:
            darkFillColor ?? fillColor
        default:
            lightFillColor ?? fillColor
        }
    }

    func hasCustomFillColor(for scheme: ColorScheme) -> Bool {
        fillColor(for: scheme) != nil
    }

    static func defaultCornerRadius(for shape: GamepadButtonShapeStyle?) -> CGFloat {
        switch shape {
        case .some(.rectangle):
            minimumCornerRadius
        case .some(.roundedRectangle), .some(.capsule), .some(.circle), .some(.ellipse), .some(.polygon), .some(.star), .none:
            defaultCornerRadius
        }
    }

    static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    static func normalizedRotationDegrees(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized > 180 { normalized -= 360 }
        if normalized <= -180 { normalized += 360 }
        return abs(normalized) < 0.001 ? 0 : normalized
    }

    private enum CodingKeys: String, CodingKey {
        case centerX
        case centerY
        case widthScale
        case heightScale
        case rotationDegrees
        case shape
        case accentStyle
        case fillColor
        case lightFillColor
        case darkFillColor
        case cornerRadius
        case cornerRadii
        case shadowStrength
        case isLocationLocked
        case isHidden
    }
}

extension GamepadButtonShapeStyle {
    var usesEditableCornerRadii: Bool {
        switch self {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            true
        case .polygon, .star:
            false
        }
    }

    var usesDynamicEditableCornerRadiusDefault: Bool {
        switch self {
        case .capsule, .circle, .ellipse:
            true
        case .roundedRectangle, .rectangle, .polygon, .star:
            false
        }
    }

    var defaultEditableCornerRadius: CGFloat {
        defaultEditableCornerRadius(in: nil)
    }

    func defaultEditableCornerRadius(in size: CGSize?) -> CGFloat {
        switch self {
        case .rectangle:
            return GamepadButtonCustomization.minimumCornerRadius
        case .capsule, .circle, .ellipse:
            guard let size else { return GamepadButtonCustomization.defaultCornerRadius }
            return min(
                GamepadButtonCustomization.maximumCornerRadius,
                max(GamepadButtonCustomization.minimumCornerRadius, min(size.width, size.height) / 2)
            )
        case .roundedRectangle, .polygon, .star:
            return GamepadButtonCustomization.defaultCornerRadius(for: self)
        }
    }
}

public struct GamepadCustomButton: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var mappedButton: GameButton
    public var label: String
    public var layout: GamepadButtonCustomization
    public var controlKind: GamepadCustomControlKind
    public var joystickMapping: GamepadJoystickMapping?

    public init(
        id: UUID = UUID(),
        mappedButton: GameButton = .custom1,
        label: String = "Shape",
        layout: GamepadButtonCustomization = GamepadButtonCustomization(
            centerX: 0.5,
            centerY: 0.5,
            widthScale: 1.0,
            heightScale: 1.0,
            shape: .roundedRectangle
        ),
        controlKind: GamepadCustomControlKind = .button,
        joystickMapping: GamepadJoystickMapping? = nil
    ) {
        self.id = id
        self.mappedButton = mappedButton
        self.label = label
        self.layout = layout
        self.controlKind = controlKind
        self.joystickMapping = joystickMapping
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        mappedButton = try container.decodeIfPresent(GameButton.self, forKey: .mappedButton) ?? .custom1
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? "Shape"
        layout = try container.decodeIfPresent(GamepadButtonCustomization.self, forKey: .layout) ?? GamepadButtonCustomization(
            centerX: 0.5,
            centerY: 0.5,
            widthScale: 1.0,
            heightScale: 1.0,
            shape: .roundedRectangle
        )
        controlKind = try container.decodeIfPresent(GamepadCustomControlKind.self, forKey: .controlKind) ?? .button
        joystickMapping = try container.decodeIfPresent(GamepadJoystickMapping.self, forKey: .joystickMapping)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mappedButton, forKey: .mappedButton)
        try container.encode(label, forKey: .label)
        try container.encode(layout, forKey: .layout)
        try container.encode(controlKind, forKey: .controlKind)
        try container.encodeIfPresent(joystickMapping, forKey: .joystickMapping)
    }

    var normalized: GamepadCustomButton {
        var copy = self
        copy.label = normalizedGamepadLabel(copy.label)
        copy.layout = copy.layout.normalized
        if copy.layout.centerX == nil { copy.layout.centerX = 0.5 }
        if copy.layout.centerY == nil { copy.layout.centerY = 0.5 }
        if copy.controlKind == .joystick {
            copy.joystickMapping = copy.joystickMapping ?? .movement
            copy.layout.shape = .circle
            if copy.label.isEmpty { copy.label = "Joystick" }
        } else {
            copy.joystickMapping = nil
            if copy.layout.shape == nil { copy.layout.shape = .roundedRectangle }
        }
        return copy
    }

    var isJoystick: Bool {
        controlKind == .joystick
    }

    func visualLabel(fallback: String) -> String {
        let normalizedLabel = normalizedGamepadLabel(label)
        return normalizedLabel.isEmpty ? fallback : normalizedLabel
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case mappedButton
        case label
        case layout
        case controlKind
        case joystickMapping
    }
}

public struct GamepadCustomization: Codable, Equatable, Sendable {
    public static let maximumLabelLength = gamepadMaximumLabelLength
    public static let maximumCustomButtons = 8
    public static let maximumJoysticks = 2
    public static let defaultValue = GamepadCustomization()
    public static var blankCanvas: GamepadCustomization {
        var customization = GamepadCustomization.defaultValue
        for button in GameButton.builtInControls {
            var buttonCustomization = GamepadButtonCustomization.defaultValue
            buttonCustomization.isHidden = true
            customization.setButtonCustomization(buttonCustomization, for: button)
        }
        return customization.normalized
    }

    public var layoutMode: GamepadLayoutMode
    public var controlScale: GamepadControlScale
    public var colorSchemePreference: GamepadColorSchemePreference
    public var accentStyle: GamepadAccentStyle
    public var showsButtonLabels: Bool
    public var labelOverrides: [GameButton: String]
    public var buttonCustomizations: [GameButton: GamepadButtonCustomization]
    public var customButtons: [GamepadCustomButton]
    public var updatedAt: Int64

    public init(
        layoutMode: GamepadLayoutMode = .standard,
        controlScale: GamepadControlScale = .standard,
        colorSchemePreference: GamepadColorSchemePreference = .system,
        accentStyle: GamepadAccentStyle = .monochrome,
        showsButtonLabels: Bool = true,
        labelOverrides: [GameButton: String] = [:],
        buttonCustomizations: [GameButton: GamepadButtonCustomization] = [:],
        customButtons: [GamepadCustomButton] = [],
        updatedAt: Int64 = 0
    ) {
        self.layoutMode = layoutMode
        self.controlScale = controlScale
        self.colorSchemePreference = colorSchemePreference
        self.accentStyle = accentStyle
        self.showsButtonLabels = showsButtonLabels
        self.labelOverrides = labelOverrides
        self.buttonCustomizations = buttonCustomizations
        self.customButtons = customButtons
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layoutMode = try container.decodeIfPresent(GamepadLayoutMode.self, forKey: .layoutMode) ?? .standard
        controlScale = try container.decodeIfPresent(GamepadControlScale.self, forKey: .controlScale) ?? .standard
        colorSchemePreference = try container.decodeIfPresent(GamepadColorSchemePreference.self, forKey: .colorSchemePreference) ?? .system
        accentStyle = try container.decodeIfPresent(GamepadAccentStyle.self, forKey: .accentStyle) ?? .monochrome
        showsButtonLabels = try container.decodeIfPresent(Bool.self, forKey: .showsButtonLabels) ?? true
        labelOverrides = try container.decodeIfPresent([GameButton: String].self, forKey: .labelOverrides) ?? [:]
        buttonCustomizations = try container.decodeIfPresent([GameButton: GamepadButtonCustomization].self, forKey: .buttonCustomizations) ?? [:]
        customButtons = try container.decodeIfPresent([GamepadCustomButton].self, forKey: .customButtons) ?? []
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layoutMode, forKey: .layoutMode)
        try container.encode(controlScale, forKey: .controlScale)
        try container.encode(colorSchemePreference, forKey: .colorSchemePreference)
        try container.encode(accentStyle, forKey: .accentStyle)
        try container.encode(showsButtonLabels, forKey: .showsButtonLabels)
        try container.encode(labelOverrides, forKey: .labelOverrides)
        try container.encode(buttonCustomizations, forKey: .buttonCustomizations)
        try container.encode(customButtons, forKey: .customButtons)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    public func visualLabel(for button: GameButton) -> String {
        visualLabel(for: button, defaultLabel: nil)
    }

    public func visualLabel(for button: GameButton, defaultLabel: String?) -> String {
        if let override = labelOverride(for: button) {
            return override
        }
        return Self.resolvedDefaultVisualLabel(for: button, defaultLabel: defaultLabel)
    }

    public func labelOverride(for button: GameButton) -> String? {
        guard let value = labelOverrides[button]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }

    public mutating func setLabel(_ label: String, for button: GameButton) {
        let normalizedLabel = normalizedGamepadLabel(label)
        if normalizedLabel.isEmpty {
            labelOverrides[button] = nil
        } else {
            labelOverrides[button] = normalizedLabel
        }
    }

    public mutating func resetLabels() {
        labelOverrides.removeAll()
    }

    public func buttonCustomization(for button: GameButton) -> GamepadButtonCustomization {
        buttonCustomizations[button]?.normalized ?? .defaultValue
    }

    public mutating func setButtonCustomization(_ customization: GamepadButtonCustomization, for button: GameButton) {
        let normalizedCustomization = customization.normalized
        if normalizedCustomization.isDefault {
            buttonCustomizations[button] = nil
        } else {
            buttonCustomizations[button] = normalizedCustomization
        }
    }

    public mutating func setPosition(_ normalizedPosition: CGPoint, for identity: GamepadControlIdentity) {
        switch identity {
        case .builtin(let button):
            var buttonCustomization = buttonCustomization(for: button)
            buttonCustomization.centerX = normalizedPosition.x
            buttonCustomization.centerY = normalizedPosition.y
            setButtonCustomization(buttonCustomization, for: button)

        case .custom(let id):
            guard let index = customButtons.firstIndex(where: { $0.id == id }) else { return }
            customButtons[index].layout.centerX = normalizedPosition.x
            customButtons[index].layout.centerY = normalizedPosition.y
        }
    }

    public mutating func addCustomButton(id: UUID = UUID(), mappedTo mappedButton: GameButton? = nil) {
        guard customButtons.count < Self.maximumCustomButtons else { return }
        let targetButton = mappedButton ?? firstAvailableCustomSlot() ?? .jump
        customButtons.append(
            GamepadCustomButton(
                id: id,
                mappedButton: targetButton,
                label: "Shape",
                layout: GamepadButtonCustomization(
                    centerX: 0.5,
                    centerY: 0.5,
                    widthScale: 1.0,
                    heightScale: 1.0,
                    shape: .roundedRectangle
                )
            )
        )
    }

    public mutating func addJoystick(id: UUID = UUID()) {
        let joystickCount = customButtons.filter { $0.normalized.isJoystick }.count
        guard customButtons.count < Self.maximumCustomButtons,
              joystickCount < Self.maximumJoysticks
        else { return }

        let isPrimaryJoystick = joystickCount == 0
        customButtons.append(
            GamepadCustomButton(
                id: id,
                mappedButton: isPrimaryJoystick ? .up : .custom1,
                label: isPrimaryJoystick ? "Left Stick" : "Right Stick",
                layout: GamepadButtonCustomization(
                    centerX: isPrimaryJoystick ? 0.22 : 0.78,
                    centerY: 0.64,
                    widthScale: 1.35,
                    heightScale: 1.35,
                    shape: .circle,
                    accentStyle: isPrimaryJoystick ? .blue : .purple
                ),
                controlKind: .joystick,
                joystickMapping: isPrimaryJoystick ? .movement : .secondary
            )
        )
    }

    public mutating func removeCustomButton(id: UUID) {
        customButtons.removeAll { $0.id == id }
    }

    public mutating func resetButtonLayout() {
        buttonCustomizations.removeAll()
        customButtons.removeAll()
    }

    private func firstAvailableCustomSlot() -> GameButton? {
        GameButton.customSlots.first { slot in
            !customButtons.contains { $0.mappedButton == slot }
        }
    }

    public var usesFreeformLayout: Bool {
        customButtons.contains { !$0.layout.isHidden }
            || buttonCustomizations.values.contains { $0.normalized.needsFreeformLayout }
    }

    public var normalized: GamepadCustomization {
        var copy = self
        copy.labelOverrides = Dictionary(uniqueKeysWithValues: labelOverrides.compactMap { button, label in
            let normalizedLabel = normalizedGamepadLabel(label)
            guard !normalizedLabel.isEmpty else { return nil }
            return (button, normalizedLabel)
        })
        copy.buttonCustomizations = Dictionary(uniqueKeysWithValues: buttonCustomizations.compactMap { button, customization in
            let normalizedCustomization = customization.normalized
            guard !normalizedCustomization.isDefault else { return nil }
            return (button, normalizedCustomization)
        })

        var seenCustomButtonIDs = Set<UUID>()
        var normalizedCustomButtons: [GamepadCustomButton] = []
        var joystickCount = 0
        for customButton in customButtons {
            let normalizedCustomButton = customButton.normalized
            guard seenCustomButtonIDs.insert(normalizedCustomButton.id).inserted else { continue }
            if normalizedCustomButton.isJoystick {
                guard joystickCount < Self.maximumJoysticks else { continue }
                joystickCount += 1
            }
            normalizedCustomButtons.append(normalizedCustomButton)
            if normalizedCustomButtons.count >= Self.maximumCustomButtons { break }
        }
        copy.customButtons = normalizedCustomButtons
        return copy
    }

    public var stampedForLocalUpdate: GamepadCustomization {
        var copy = normalized
        copy.updatedAt = Date.currentMilliseconds
        return copy
    }

    public func hasSamePresentation(as other: GamepadCustomization) -> Bool {
        layoutMode == other.layoutMode
            && controlScale == other.controlScale
            && colorSchemePreference == other.colorSchemePreference
            && accentStyle == other.accentStyle
            && showsButtonLabels == other.showsButtonLabels
            && normalized.labelOverrides == other.normalized.labelOverrides
            && normalized.buttonCustomizations == other.normalized.buttonCustomizations
            && normalized.customButtons == other.normalized.customButtons
    }

    public static func defaultVisualLabel(for button: GameButton) -> String {
        switch button {
        case .up: "↑"
        case .down: "↓"
        case .left: "←"
        case .right: "→"
        case .jump: "A"
        case .attack: "B"
        case .dash: "C"
        case .focus: "D"
        case .map: "⇧⌘P"
        case .pause: "Esc"
        case .custom1: "C1"
        case .custom2: "C2"
        case .custom3: "C3"
        case .custom4: "C4"
        case .custom5: "C5"
        case .custom6: "C6"
        case .custom7: "C7"
        case .custom8: "C8"
        }
    }

    private static func resolvedDefaultVisualLabel(for button: GameButton, defaultLabel: String?) -> String {
        let normalizedDefaultLabel = defaultLabel.map(normalizedGamepadLabel) ?? ""
        return normalizedDefaultLabel.isEmpty ? defaultVisualLabel(for: button) : normalizedDefaultLabel
    }

    private enum CodingKeys: String, CodingKey {
        case layoutMode
        case controlScale
        case colorSchemePreference
        case accentStyle
        case showsButtonLabels
        case labelOverrides
        case buttonCustomizations
        case customButtons
        case updatedAt
    }
}

public enum GamepadControlIdentity: Hashable, Identifiable, Sendable {
    case builtin(GameButton)
    case custom(UUID)

    public var id: String {
        switch self {
        case .builtin(let button): "builtin.\(button.rawValue)"
        case .custom(let id): "custom.\(id.uuidString)"
        }
    }
}

struct GamepadResolvedControl: Identifiable, Equatable {
    let id: GamepadControlIdentity
    let mappedButton: GameButton
    let label: String
    let normalizedCenter: CGPoint
    let center: CGPoint
    let size: CGSize
    let shape: GamepadButtonShapeStyle
    let rotationDegrees: CGFloat
    let layoutCustomization: GamepadButtonCustomization
    let isCustom: Bool
    let isLocationLocked: Bool
    let controlKind: GamepadCustomControlKind
    let joystickMapping: GamepadJoystickMapping?

    var isJoystick: Bool {
        controlKind == .joystick
    }

    var frame: CGRect {
        CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    func updatingCenter(_ center: CGPoint, in canvasSize: CGSize) -> GamepadResolvedControl {
        GamepadResolvedControl(
            id: id,
            mappedButton: mappedButton,
            label: label,
            normalizedCenter: CGPoint(
                x: center.x / max(canvasSize.width, 1),
                y: center.y / max(canvasSize.height, 1)
            ),
            center: center,
            size: size,
            shape: shape,
            rotationDegrees: rotationDegrees,
            layoutCustomization: layoutCustomization,
            isCustom: isCustom,
            isLocationLocked: isLocationLocked,
            controlKind: controlKind,
            joystickMapping: joystickMapping
        )
    }
}

extension GamepadCustomization {
    func resolvedControls(
        in canvasSize: CGSize,
        defaultLabelProvider: ((GameButton) -> String?)? = nil
    ) -> [GamepadResolvedControl] {
        GamepadLayoutResolver.resolvedControls(
            for: self,
            in: canvasSize,
            defaultLabelProvider: defaultLabelProvider
        )
    }

    func nudgedControls(
        _ identities: Set<GamepadControlIdentity>,
        by translation: CGSize,
        in canvasSize: CGSize
    ) -> GamepadCustomization? {
        guard !identities.isEmpty,
              canvasSize.width > 1,
              canvasSize.height > 1,
              abs(translation.width) > 0.001 || abs(translation.height) > 0.001
        else {
            return nil
        }

        let controls = resolvedControls(in: canvasSize)
        let snapshots = controls
            .filter { identities.contains($0.id) && !$0.isLocationLocked }
            .map { GamepadControlNudgeSnapshot(control: $0) }
        guard !snapshots.isEmpty else { return nil }

        let movingIDs = Set(snapshots.map(\.identity))
        let adjustedTranslation = GamepadControlNudgeSolver.adjustedTranslation(
            translation,
            snapshots: snapshots,
            movingIDs: movingIDs,
            controls: controls,
            canvasSize: canvasSize
        )
        guard abs(adjustedTranslation.width) > 0.001 || abs(adjustedTranslation.height) > 0.001 else { return nil }

        var next = self
        for snapshot in snapshots {
            let proposedCenter = CGPoint(
                x: snapshot.startCenter.x + adjustedTranslation.width,
                y: snapshot.startCenter.y + adjustedTranslation.height
            )
            let normalizedPosition = GamepadLayoutResolver.normalizedPosition(
                for: proposedCenter,
                visualSize: snapshot.size,
                in: canvasSize
            )
            next.setPosition(normalizedPosition, for: snapshot.identity)
        }

        let normalizedNext = next.normalized
        return normalizedNext == normalized ? nil : normalizedNext
    }

    @discardableResult
    mutating func nudgeControls(
        _ identities: Set<GamepadControlIdentity>,
        by translation: CGSize,
        in canvasSize: CGSize
    ) -> Bool {
        guard let next = nudgedControls(identities, by: translation, in: canvasSize) else { return false }
        self = next
        return true
    }
}

private struct GamepadControlNudgeSnapshot {
    let identity: GamepadControlIdentity
    let startCenter: CGPoint
    let size: CGSize

    init(control: GamepadResolvedControl) {
        identity = control.id
        startCenter = control.center
        size = control.size
    }

    var startFrame: CGRect {
        CGRect(
            x: startCenter.x - size.width / 2,
            y: startCenter.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

private enum GamepadControlNudgeSolver {
    static func adjustedTranslation(
        _ translation: CGSize,
        snapshots: [GamepadControlNudgeSnapshot],
        movingIDs: Set<GamepadControlIdentity>,
        controls: [GamepadResolvedControl],
        canvasSize: CGSize
    ) -> CGSize {
        let clampedTranslation = clampedTranslation(translation, snapshots: snapshots, canvasSize: canvasSize)
        guard abs(clampedTranslation.width) > 0.001 || abs(clampedTranslation.height) > 0.001 else { return .zero }

        let existingFrames = controls.compactMap { control in
            movingIDs.contains(control.id) ? nil : control.frame
        }
        let candidateFrames = frames(snapshots, offsetBy: clampedTranslation)
        guard candidateFrames.contains(where: { GamepadLayoutResolver.frameOverlapsAny($0, avoiding: existingFrames) }) else {
            return clampedTranslation
        }

        var lowerBound: CGFloat = 0
        var upperBound: CGFloat = 1
        var bestTranslation = CGSize.zero
        for _ in 0..<12 {
            let fraction = (lowerBound + upperBound) / 2
            let candidateTranslation = CGSize(
                width: clampedTranslation.width * fraction,
                height: clampedTranslation.height * fraction
            )
            let overlaps = frames(snapshots, offsetBy: candidateTranslation).contains { frame in
                GamepadLayoutResolver.frameOverlapsAny(frame, avoiding: existingFrames)
            }
            if overlaps {
                upperBound = fraction
            } else {
                bestTranslation = candidateTranslation
                lowerBound = fraction
            }
        }

        return bestTranslation
    }

    private static func clampedTranslation(
        _ translation: CGSize,
        snapshots: [GamepadControlNudgeSnapshot],
        canvasSize: CGSize
    ) -> CGSize {
        guard !snapshots.isEmpty else { return .zero }
        let frames = snapshots.map(\.startFrame)
        let minXOffset = frames.map { -$0.minX }.max() ?? 0
        let maxXOffset = frames.map { canvasSize.width - $0.maxX }.min() ?? 0
        let minYOffset = frames.map { -$0.minY }.max() ?? 0
        let maxYOffset = frames.map { canvasSize.height - $0.maxY }.min() ?? 0
        return CGSize(
            width: GamepadButtonCustomization.clamp(translation.width, lower: minXOffset, upper: maxXOffset),
            height: GamepadButtonCustomization.clamp(translation.height, lower: minYOffset, upper: maxYOffset)
        )
    }

    private static func frames(_ snapshots: [GamepadControlNudgeSnapshot], offsetBy translation: CGSize) -> [CGRect] {
        snapshots.map { snapshot in
            snapshot.startFrame.offsetBy(dx: translation.width, dy: translation.height)
        }
    }
}

private enum GamepadLayoutResolver {
    private static let minimumControlSpacing: CGFloat = 0

    static func resolvedControls(
        for customization: GamepadCustomization,
        in canvasSize: CGSize,
        defaultLabelProvider: ((GameButton) -> String?)? = nil
    ) -> [GamepadResolvedControl] {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return [] }

        let builtinControls = GameButton.builtInControls.compactMap { button -> GamepadResolvedControl? in
            let buttonCustomization = customization.buttonCustomization(for: button)
            guard !buttonCustomization.isHidden else { return nil }

            let defaultShape = defaultShape(for: button)
            let shape = buttonCustomization.resolvedShape(defaultShape: defaultShape)
            let baseSize = baseSize(for: button, controlScale: customization.controlScale, in: canvasSize)
            let scaledSize = effectiveSize(
                CGSize(
                    width: baseSize.width * buttonCustomization.widthScale,
                    height: baseSize.height * buttonCustomization.heightScale
                ),
                shape: shape
            )
            let defaultCenter = defaultNormalizedCenter(for: button, layoutMode: customization.layoutMode, visualSize: scaledSize, in: canvasSize)
            let normalizedCenter = CGPoint(
                x: buttonCustomization.centerX ?? defaultCenter.x,
                y: buttonCustomization.centerY ?? defaultCenter.y
            )
            let center = clampedPixelCenter(normalizedCenter, visualSize: scaledSize, in: canvasSize)

            return GamepadResolvedControl(
                id: .builtin(button),
                mappedButton: button,
                label: customization.visualLabel(for: button, defaultLabel: defaultLabelProvider?(button)),
                normalizedCenter: CGPoint(x: center.x / canvasSize.width, y: center.y / canvasSize.height),
                center: center,
                size: scaledSize,
                shape: shape,
                rotationDegrees: buttonCustomization.rotationDegrees,
                layoutCustomization: buttonCustomization,
                isCustom: false,
                isLocationLocked: buttonCustomization.isLocationLocked,
                controlKind: .button,
                joystickMapping: nil
            )
        }

        let customControls = customization.customButtons.compactMap { customButton -> GamepadResolvedControl? in
            let normalizedButton = customButton.normalized
            guard !normalizedButton.layout.isHidden else { return nil }

            let defaultShape = normalizedButton.isJoystick ? GamepadButtonShapeStyle.circle : defaultShape(for: normalizedButton.mappedButton)
            let shape = normalizedButton.layout.resolvedShape(defaultShape: defaultShape)
            let baseSize = normalizedButton.isJoystick
                ? joystickBaseSize(controlScale: customization.controlScale, in: canvasSize)
                : baseSize(for: normalizedButton.mappedButton, controlScale: customization.controlScale, in: canvasSize)
            let scaledSize = effectiveSize(
                CGSize(
                    width: baseSize.width * normalizedButton.layout.widthScale,
                    height: baseSize.height * normalizedButton.layout.heightScale
                ),
                shape: shape
            )
            let normalizedCenter = CGPoint(
                x: normalizedButton.layout.centerX ?? 0.5,
                y: normalizedButton.layout.centerY ?? 0.5
            )
            let center = clampedPixelCenter(normalizedCenter, visualSize: scaledSize, in: canvasSize)

            let fallbackLabel = customization.visualLabel(
                for: normalizedButton.mappedButton,
                defaultLabel: defaultLabelProvider?(normalizedButton.mappedButton)
            )

            return GamepadResolvedControl(
                id: .custom(normalizedButton.id),
                mappedButton: normalizedButton.mappedButton,
                label: normalizedButton.visualLabel(fallback: fallbackLabel),
                normalizedCenter: CGPoint(x: center.x / canvasSize.width, y: center.y / canvasSize.height),
                center: center,
                size: scaledSize,
                shape: shape,
                rotationDegrees: normalizedButton.layout.rotationDegrees,
                layoutCustomization: normalizedButton.layout,
                isCustom: true,
                isLocationLocked: normalizedButton.layout.isLocationLocked,
                controlKind: normalizedButton.controlKind,
                joystickMapping: normalizedButton.isJoystick ? (normalizedButton.joystickMapping ?? .movement) : nil
            )
        }

        return controlsByAvoidingOverlaps(builtinControls + customControls, in: canvasSize)
    }

    static func defaultShape(for button: GameButton) -> GamepadButtonShapeStyle {
        switch button {
        case .map, .pause: .capsule
        default: .roundedRectangle
        }
    }

    static func normalizedPosition(for point: CGPoint, visualSize: CGSize, in canvasSize: CGSize) -> CGPoint {
        let center = clampedPixelCenter(
            CGPoint(x: point.x / max(canvasSize.width, 1), y: point.y / max(canvasSize.height, 1)),
            visualSize: visualSize,
            in: canvasSize
        )
        return CGPoint(x: center.x / canvasSize.width, y: center.y / canvasSize.height)
    }

    static func nonOverlappingFrame(
        for preferredFrame: CGRect,
        avoiding existingFrames: [CGRect],
        in canvasSize: CGSize,
        minimumSpacing: CGFloat = minimumControlSpacing
    ) -> CGRect? {
        let clampedPreferred = clampedFrame(preferredFrame, in: canvasSize)
        guard frameOverlapsAny(clampedPreferred, avoiding: existingFrames, minimumSpacing: minimumSpacing) else {
            return clampedPreferred
        }

        let xCandidates = candidateOrigins(
            preferred: clampedPreferred.minX,
            length: clampedPreferred.width,
            canvasLength: canvasSize.width,
            existingFrames: existingFrames,
            axis: .horizontal,
            minimumSpacing: minimumSpacing
        )
        let yCandidates = candidateOrigins(
            preferred: clampedPreferred.minY,
            length: clampedPreferred.height,
            canvasLength: canvasSize.height,
            existingFrames: existingFrames,
            axis: .vertical,
            minimumSpacing: minimumSpacing
        )

        var bestFrame: CGRect?
        var bestScore = CGFloat.greatestFiniteMagnitude
        let preferredCenter = CGPoint(x: clampedPreferred.midX, y: clampedPreferred.midY)

        for x in xCandidates {
            for y in yCandidates {
                let candidate = CGRect(
                    x: x,
                    y: y,
                    width: clampedPreferred.width,
                    height: clampedPreferred.height
                )
                guard !frameOverlapsAny(candidate, avoiding: existingFrames, minimumSpacing: minimumSpacing) else { continue }

                let dx = candidate.midX - preferredCenter.x
                let dy = candidate.midY - preferredCenter.y
                let score = dx * dx + dy * dy
                if score < bestScore {
                    bestScore = score
                    bestFrame = candidate
                }
            }
        }

        return bestFrame
    }

    static func frameOverlapsAny(
        _ frame: CGRect,
        avoiding existingFrames: [CGRect],
        minimumSpacing: CGFloat = minimumControlSpacing
    ) -> Bool {
        existingFrames.contains { existingFrame in
            framesOverlap(frame, existingFrame, minimumSpacing: minimumSpacing)
        }
    }

    private static func controlsByAvoidingOverlaps(_ controls: [GamepadResolvedControl], in canvasSize: CGSize) -> [GamepadResolvedControl] {
        var adjustedControls: [GamepadResolvedControl] = []
        var occupiedFrames: [CGRect] = []

        for control in controls {
            let adjustedFrame = nonOverlappingFrame(
                for: control.frame,
                avoiding: occupiedFrames,
                in: canvasSize
            ) ?? clampedFrame(control.frame, in: canvasSize)
            let adjustedCenter = CGPoint(x: adjustedFrame.midX, y: adjustedFrame.midY)
            adjustedControls.append(control.updatingCenter(adjustedCenter, in: canvasSize))
            occupiedFrames.append(adjustedFrame)
        }

        return adjustedControls
    }

    private enum CandidateAxis {
        case horizontal
        case vertical
    }

    private static func candidateOrigins(
        preferred: CGFloat,
        length: CGFloat,
        canvasLength: CGFloat,
        existingFrames: [CGRect],
        axis: CandidateAxis,
        minimumSpacing: CGFloat
    ) -> [CGFloat] {
        var rawValues = [preferred]

        if length >= canvasLength {
            rawValues.append((canvasLength - length) / 2)
        } else {
            rawValues.append(0)
            rawValues.append(canvasLength - length)
        }

        for frame in existingFrames {
            let minValue: CGFloat
            let maxValue: CGFloat
            switch axis {
            case .horizontal:
                minValue = frame.minX
                maxValue = frame.maxX
            case .vertical:
                minValue = frame.minY
                maxValue = frame.maxY
            }

            rawValues.append(minValue - minimumSpacing - length)
            rawValues.append(maxValue + minimumSpacing)
            rawValues.append(minValue)
            rawValues.append(maxValue - length)
        }

        var uniqueValues: [CGFloat] = []
        for rawValue in rawValues {
            let value = clampedOrigin(rawValue, length: length, canvasLength: canvasLength)
            guard !uniqueValues.contains(where: { abs($0 - value) < 0.5 }) else { continue }
            uniqueValues.append(value)
        }

        return uniqueValues
    }

    private static func framesOverlap(_ lhs: CGRect, _ rhs: CGRect, minimumSpacing: CGFloat) -> Bool {
        lhs.minX < rhs.maxX + minimumSpacing
            && lhs.maxX + minimumSpacing > rhs.minX
            && lhs.minY < rhs.maxY + minimumSpacing
            && lhs.maxY + minimumSpacing > rhs.minY
    }

    private static func clampedFrame(_ frame: CGRect, in canvasSize: CGSize) -> CGRect {
        CGRect(
            x: clampedOrigin(frame.minX, length: frame.width, canvasLength: canvasSize.width),
            y: clampedOrigin(frame.minY, length: frame.height, canvasLength: canvasSize.height),
            width: frame.width,
            height: frame.height
        )
    }

    private static func clampedOrigin(_ origin: CGFloat, length: CGFloat, canvasLength: CGFloat) -> CGFloat {
        guard length < canvasLength else { return (canvasLength - length) / 2 }
        return GamepadButtonCustomization.clamp(origin, lower: 0, upper: max(0, canvasLength - length))
    }

    private static func baseSize(for button: GameButton, controlScale: GamepadControlScale, in canvasSize: CGSize) -> CGSize {
        let isLandscape = canvasSize.width >= canvasSize.height
        let shortestSide = max(1, min(canvasSize.width, canvasSize.height))
        let scale = controlScale.multiplier
        let side = min(86 * scale, max(50 * scale, shortestSide * (isLandscape ? 0.24 : 0.20) * scale))

        switch button {
        case .map:
            return CGSize(width: side * 1.48, height: side * 0.72)
        case .pause:
            return CGSize(width: side * 1.66, height: side * 0.72)
        default:
            return CGSize(width: side, height: side)
        }
    }

    private static func joystickBaseSize(controlScale: GamepadControlScale, in canvasSize: CGSize) -> CGSize {
        let isLandscape = canvasSize.width >= canvasSize.height
        let shortestSide = max(1, min(canvasSize.width, canvasSize.height))
        let scale = controlScale.multiplier
        let side = min(128 * scale, max(82 * scale, shortestSide * (isLandscape ? 0.30 : 0.24) * scale))
        return CGSize(width: side, height: side)
    }

    private static func effectiveSize(_ size: CGSize, shape: GamepadButtonShapeStyle) -> CGSize {
        size
    }

    private static func defaultNormalizedCenter(
        for button: GameButton,
        layoutMode: GamepadLayoutMode,
        visualSize: CGSize,
        in canvasSize: CGSize
    ) -> CGPoint {
        let isLandscape = canvasSize.width >= canvasSize.height
        let xStep = min(0.18, max(0.08, (visualSize.width * 1.12) / canvasSize.width))
        let yStep = min(0.26, max(0.10, (visualSize.height * 1.12) / canvasSize.height))

        if isLandscape {
            let dPadCenterX: CGFloat = layoutMode == .standard ? 0.18 : 0.82
            let actionCenterX: CGFloat = layoutMode == .standard ? 0.82 : 0.18
            let groupY: CGFloat = 0.56

            switch button {
            case .up: return CGPoint(x: dPadCenterX, y: groupY - yStep)
            case .down: return CGPoint(x: dPadCenterX, y: groupY + yStep)
            case .left: return CGPoint(x: dPadCenterX - xStep, y: groupY)
            case .right: return CGPoint(x: dPadCenterX + xStep, y: groupY)
            case .focus: return CGPoint(x: actionCenterX - xStep * 0.55, y: groupY - yStep * 0.55)
            case .dash: return CGPoint(x: actionCenterX + xStep * 0.55, y: groupY - yStep * 0.55)
            case .attack: return CGPoint(x: actionCenterX - xStep * 0.55, y: groupY + yStep * 0.55)
            case .jump: return CGPoint(x: actionCenterX + xStep * 0.55, y: groupY + yStep * 0.55)
            case .map: return CGPoint(x: 0.43, y: groupY)
            case .pause: return CGPoint(x: 0.57, y: groupY)
            case .custom1, .custom2, .custom3, .custom4, .custom5, .custom6, .custom7, .custom8:
                return CGPoint(x: 0.5, y: groupY)
            }
        } else {
            let dPadY: CGFloat = layoutMode == .standard ? 0.28 : 0.74
            let actionY: CGFloat = layoutMode == .standard ? 0.74 : 0.28
            let xCenter: CGFloat = 0.5
            let portraitXStep = min(0.22, max(0.13, (visualSize.width * 1.16) / canvasSize.width))
            let portraitYStep = min(0.12, max(0.08, (visualSize.height * 1.10) / canvasSize.height))

            switch button {
            case .up: return CGPoint(x: xCenter, y: dPadY - portraitYStep)
            case .down: return CGPoint(x: xCenter, y: dPadY + portraitYStep)
            case .left: return CGPoint(x: xCenter - portraitXStep, y: dPadY)
            case .right: return CGPoint(x: xCenter + portraitXStep, y: dPadY)
            case .focus: return CGPoint(x: xCenter - portraitXStep * 0.55, y: actionY - portraitYStep * 0.75)
            case .dash: return CGPoint(x: xCenter + portraitXStep * 0.55, y: actionY - portraitYStep * 0.75)
            case .attack: return CGPoint(x: xCenter - portraitXStep * 0.55, y: actionY + portraitYStep * 0.75)
            case .jump: return CGPoint(x: xCenter + portraitXStep * 0.55, y: actionY + portraitYStep * 0.75)
            case .map: return CGPoint(x: 0.36, y: 0.51)
            case .pause: return CGPoint(x: 0.64, y: 0.51)
            case .custom1, .custom2, .custom3, .custom4, .custom5, .custom6, .custom7, .custom8:
                return CGPoint(x: 0.5, y: 0.51)
            }
        }
    }

    private static func clampedPixelCenter(_ normalizedCenter: CGPoint, visualSize: CGSize, in canvasSize: CGSize) -> CGPoint {
        let halfWidth = min(canvasSize.width / 2, max(visualSize.width / 2, 1))
        let halfHeight = min(canvasSize.height / 2, max(visualSize.height / 2, 1))
        return CGPoint(
            x: GamepadButtonCustomization.clamp(normalizedCenter.x * canvasSize.width, lower: halfWidth, upper: max(halfWidth, canvasSize.width - halfWidth)),
            y: GamepadButtonCustomization.clamp(normalizedCenter.y * canvasSize.height, lower: halfHeight, upper: max(halfHeight, canvasSize.height - halfHeight))
        )
    }
}

private func normalizedGamepadLabel(_ label: String) -> String {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    return String(trimmed.prefix(gamepadMaximumLabelLength))
}

extension GamepadCustomization {
    func resolvedColorScheme(system systemScheme: ColorScheme) -> ColorScheme {
        colorSchemePreference.resolvedColorScheme(system: systemScheme)
    }
}

enum GamepadCustomizationPersistence {
    static let defaultsKey = "PocketPad.gamepadCustomization.v1"

    static func load() -> GamepadCustomization {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(GamepadCustomization.self, from: data)
        else {
            return .defaultValue
        }
        return decoded.normalized
    }

    static func save(_ customization: GamepadCustomization) {
        guard let data = try? JSONEncoder().encode(customization.normalized) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

extension GamepadButtonCustomization {
    func buttonFill(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if let fillColor = fillColor(for: scheme) {
            return fillColor.adjustedForPress(isPressed).swiftUIColor
        }
        return accentStyle.buttonFill(isPressed: isPressed, scheme: scheme)
    }

    func buttonForeground(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if let fillColor = fillColor(for: scheme) {
            return fillColor.foregroundColor
        }
        return accentStyle.buttonForeground(isPressed: isPressed, scheme: scheme)
    }

    func buttonStroke(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if let fillColor = fillColor(for: scheme) {
            return fillColor.adjustedForPress(isPressed).strokeColor
        }
        return accentStyle.buttonStroke(isPressed: isPressed, scheme: scheme)
    }
}

extension GamepadAccentStyle {
    func buttonFill(isPressed: Bool, scheme: ColorScheme) -> Color {
        if isPressed {
            strongColor(scheme: scheme)
        } else {
            softColor(scheme: scheme)
        }
    }

    func buttonForeground(isPressed: Bool, scheme: ColorScheme) -> Color {
        if isPressed {
            switch self {
            case .amber:
                scheme == .dark ? Color.black : Geist.color(.background100, scheme: scheme)
            default:
                Geist.color(.background100, scheme: scheme)
            }
        } else if self == .monochrome {
            Geist.color(.gray1000, scheme: scheme)
        } else {
            strongColor(scheme: scheme)
        }
    }

    func buttonStroke(isPressed: Bool, scheme: ColorScheme) -> Color {
        if self == .monochrome {
            return isPressed ? Geist.color(.grayAlpha600, scheme: scheme) : Geist.color(.grayAlpha400, scheme: scheme)
        }
        return isPressed ? strongColor(scheme: scheme) : borderColor(scheme: scheme)
    }

    private func softColor(scheme: ColorScheme) -> Color {
        switch self {
        case .monochrome: Geist.color(.gray100, scheme: scheme)
        case .blue: Geist.color(.blue100, scheme: scheme)
        case .green: Geist.color(.green100, scheme: scheme)
        case .purple: Geist.color(.purple100, scheme: scheme)
        case .pink: Geist.color(.pink100, scheme: scheme)
        case .amber: Geist.color(.amber100, scheme: scheme)
        }
    }

    private func strongColor(scheme: ColorScheme) -> Color {
        switch self {
        case .monochrome: Geist.color(.gray1000, scheme: scheme)
        case .blue: Geist.color(.blue900, scheme: scheme)
        case .green: Geist.color(.green900, scheme: scheme)
        case .purple: Geist.color(.purple900, scheme: scheme)
        case .pink: Geist.color(.pink900, scheme: scheme)
        case .amber: Geist.color(.amber900, scheme: scheme)
        }
    }

    private func borderColor(scheme: ColorScheme) -> Color {
        switch self {
        case .monochrome: Geist.color(.grayAlpha400, scheme: scheme)
        case .blue: Geist.color(.blue400, scheme: scheme)
        case .green: Geist.color(.green400, scheme: scheme)
        case .purple: Geist.color(.purple400, scheme: scheme)
        case .pink: Geist.color(.pink400, scheme: scheme)
        case .amber: Geist.color(.amber400, scheme: scheme)
        }
    }
}

public struct GamepadConfigurationProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var customization: GamepadCustomization
    public var updatedAt: Int64

    public init(
        id: UUID = UUID(),
        name: String,
        customization: GamepadCustomization,
        updatedAt: Int64 = Date.currentMilliseconds
    ) {
        self.id = id
        self.name = name
        self.customization = customization.normalized
        self.updatedAt = updatedAt
    }

    public var normalized: GamepadConfigurationProfile {
        var copy = self
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = trimmedName.isEmpty ? "Untitled" : trimmedName
        copy.customization = customization.normalized
        return copy
    }
}

enum GamepadControllerTemplate: String, CaseIterable, Identifiable {
    case nes
    case snes
    case nintendo64
    case gameCube
    case gameBoy
    case gameBoyAdvance
    case genesisSixButton
    case saturn
    case dreamcast
    case arcadeStick
    case psp
    case playStation
    case xbox

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nes: "NES"
        case .snes: "Super Nintendo"
        case .nintendo64: "Nintendo 64"
        case .gameCube: "GameCube"
        case .gameBoy: "Game Boy"
        case .gameBoyAdvance: "Game Boy Advance"
        case .genesisSixButton: "Genesis 6-Button"
        case .saturn: "Sega Saturn"
        case .dreamcast: "Dreamcast"
        case .arcadeStick: "Arcade Stick"
        case .psp: "PSP"
        case .playStation: "PlayStation"
        case .xbox: "Xbox"
        }
    }

    var description: String {
        switch self {
        case .nes: "Classic console pad: D-pad, A/B, Select, Start"
        case .snes: "Super Nintendo pad: D-pad, ABXY, L/R shoulders, Select, Start"
        case .nintendo64: "Three-prong N64 layout with analog stick, Z trigger, and C-buttons"
        case .gameCube: "GameCube layout with oversized A, C-stick, shoulders, and Z"
        case .gameBoy: "Classic handheld: D-pad, A/B, Select, Start"
        case .gameBoyAdvance: "GBA handheld: D-pad, A/B, L/R shoulders, Select, Start"
        case .genesisSixButton: "Sega Genesis/Mega Drive pad with D-pad, A/B/C, X/Y/Z, Mode, Start"
        case .saturn: "Sega Saturn six-button layout with D-pad, L/R, and Start"
        case .dreamcast: "Dreamcast layout with analog stick, D-pad, ABXY, L/R triggers, Start"
        case .arcadeStick: "MAME/fight-stick layout with joystick, 8 buttons, Coin, and Start"
        case .psp: "Portable emulator pad with D-pad, nub, shoulders, and face buttons"
        case .playStation: "Dual-stick layout with PlayStation face symbols and shoulders"
        case .xbox: "Dual-stick Xbox-style layout with ABXY and triggers"
        }
    }

    var systemImage: String {
        switch self {
        case .nes, .snes: "gamecontroller"
        case .nintendo64: "circle.grid.cross"
        case .gameCube: "gamecontroller.fill"
        case .gameBoy, .gameBoyAdvance: "rectangle.roundedtop"
        case .genesisSixButton, .saturn: "dpad"
        case .dreamcast, .psp: "gamecontroller"
        case .arcadeStick: "circle.grid.3x3.fill"
        case .playStation: "gamecontroller.fill"
        case .xbox: "circle.grid.cross"
        }
    }

    func makeProfile() -> GamepadConfigurationProfile {
        GamepadConfigurationProfile(name: displayName, customization: makeCustomization())
    }

    private func makeCustomization() -> GamepadCustomization {
        switch self {
        case .nes:
            Self.nesCustomization()
        case .snes:
            Self.snesCustomization()
        case .nintendo64:
            Self.nintendo64Customization()
        case .gameCube:
            Self.gameCubeCustomization()
        case .gameBoy:
            Self.gameBoyCustomization()
        case .gameBoyAdvance:
            Self.gameBoyAdvanceCustomization()
        case .genesisSixButton:
            Self.genesisSixButtonCustomization()
        case .saturn:
            Self.saturnCustomization()
        case .dreamcast:
            Self.dreamcastCustomization()
        case .arcadeStick:
            Self.arcadeStickCustomization()
        case .psp:
            Self.pspCustomization()
        case .playStation:
            Self.playStationCustomization()
        case .xbox:
            Self.xboxCustomization()
        }
    }

    private static func baseCustomization(accentStyle: GamepadAccentStyle, controlScale: GamepadControlScale = .compact) -> GamepadCustomization {
        var customization = GamepadCustomization.blankCanvas
        customization.layoutMode = .standard
        customization.controlScale = controlScale
        customization.accentStyle = accentStyle
        customization.showsButtonLabels = true
        return customization
    }

    private static func nesCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .monochrome, controlScale: .standard)
        let dPadFill = "#202124"
        let faceFill = "#B91C1C"
        let utilityFill = "#6B7280"

        setDPad(in: &customization, centerX: 0.18, centerY: 0.58, scale: 0.62, fill: dPadFill)
        setButton(.attack, label: "B", in: &customization, x: 0.76, y: 0.58, width: 0.70, height: 0.70, shape: .circle, fill: faceFill, shadowStrength: 1.25)
        setButton(.jump, label: "A", in: &customization, x: 0.88, y: 0.58, width: 0.70, height: 0.70, shape: .circle, fill: faceFill, shadowStrength: 1.25)
        setButton(.map, label: "Select", in: &customization, x: 0.43, y: 0.80, width: 0.50, height: 0.48, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.57, y: 0.80, width: 0.46, height: 0.48, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        return customization.normalized
    }

    private static func snesCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .purple, controlScale: .standard)
        let dPadFill = "#202124"
        let utilityFill = "#6B7280"
        let shoulderFill = "#374151"

        setDPad(in: &customization, centerX: 0.17, centerY: 0.54, scale: 0.58, fill: dPadFill)
        setButton(.focus, label: "X", in: &customization, x: 0.84, y: 0.36, width: 0.58, height: 0.58, shape: .circle, fill: "#4F46E5")
        setButton(.dash, label: "A", in: &customization, x: 0.93, y: 0.55, width: 0.58, height: 0.58, shape: .circle, fill: "#DC2626")
        setButton(.jump, label: "B", in: &customization, x: 0.84, y: 0.74, width: 0.58, height: 0.58, shape: .circle, fill: "#EAB308")
        setButton(.attack, label: "Y", in: &customization, x: 0.75, y: 0.55, width: 0.58, height: 0.58, shape: .circle, fill: "#16A34A")
        setButton(.map, label: "Select", in: &customization, x: 0.43, y: 0.82, width: 0.48, height: 0.44, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.57, y: 0.82, width: 0.44, height: 0.44, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        addButton(mappedTo: .custom1, label: "L", in: &customization, x: 0.20, y: 0.16, width: 1.12, height: 0.38, shape: .capsule, fill: shoulderFill)
        addButton(mappedTo: .custom2, label: "R", in: &customization, x: 0.80, y: 0.16, width: 1.12, height: 0.38, shape: .capsule, fill: shoulderFill)

        return customization.normalized
    }

    private static func nintendo64Customization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .amber)
        let dPadFill = "#202124"
        let stickFill = "#111827"
        let shoulderFill = "#374151"
        let cButtonFill = "#FACC15"

        setDPad(in: &customization, centerX: 0.15, centerY: 0.58, scale: 0.46, fill: dPadFill)
        addJoystick(label: "Stick", mappedButton: .up, mapping: .movement, in: &customization, x: 0.32, y: 0.63, scale: 0.82, fill: stickFill)

        setButton(.jump, label: "A", in: &customization, x: 0.73, y: 0.63, width: 0.72, height: 0.72, shape: .circle, fill: "#2563EB", shadowStrength: 1.25)
        setButton(.attack, label: "B", in: &customization, x: 0.63, y: 0.75, width: 0.60, height: 0.60, shape: .circle, fill: "#22C55E", shadowStrength: 1.25)
        setButton(.pause, label: "Start", in: &customization, x: 0.50, y: 0.55, width: 0.50, height: 0.50, shape: .circle, fill: "#DC2626", shadowStrength: 0.9)

        addButton(mappedTo: .custom1, label: "C↑", in: &customization, x: 0.87, y: 0.35, width: 0.44, height: 0.44, shape: .circle, fill: cButtonFill)
        addButton(mappedTo: .custom2, label: "C↓", in: &customization, x: 0.87, y: 0.61, width: 0.44, height: 0.44, shape: .circle, fill: cButtonFill)
        addButton(mappedTo: .custom3, label: "C←", in: &customization, x: 0.79, y: 0.48, width: 0.44, height: 0.44, shape: .circle, fill: cButtonFill)
        addButton(mappedTo: .custom4, label: "C→", in: &customization, x: 0.95, y: 0.48, width: 0.44, height: 0.44, shape: .circle, fill: cButtonFill)
        addButton(mappedTo: .custom5, label: "Z", in: &customization, x: 0.43, y: 0.78, width: 0.58, height: 0.44, shape: .capsule, fill: shoulderFill)
        addButton(mappedTo: .custom6, label: "L", in: &customization, x: 0.19, y: 0.14, width: 1.02, height: 0.34, shape: .capsule, fill: shoulderFill)
        addButton(mappedTo: .custom7, label: "R", in: &customization, x: 0.81, y: 0.14, width: 1.02, height: 0.34, shape: .capsule, fill: shoulderFill)

        return customization.normalized
    }

    private static func gameCubeCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .purple)
        let stickFill = "#111827"
        let dPadFill = "#1F2937"
        let utilityFill = "#4B5563"
        let cStickFill = "#F59E0B"

        addJoystick(label: "Stick", mappedButton: .up, mapping: .movement, in: &customization, x: 0.27, y: 0.46, scale: 0.82, fill: stickFill)
        setDPad(in: &customization, centerX: 0.19, centerY: 0.75, scale: 0.44, fill: dPadFill)
        addJoystick(label: "C Stick", mappedButton: .custom1, mapping: .secondary, in: &customization, x: 0.64, y: 0.76, scale: 0.62, fill: cStickFill)

        setButton(.jump, label: "A", in: &customization, x: 0.80, y: 0.56, width: 0.90, height: 0.90, shape: .circle, fill: "#22C55E", shadowStrength: 1.35)
        setButton(.attack, label: "B", in: &customization, x: 0.68, y: 0.69, width: 0.56, height: 0.56, shape: .circle, fill: "#EF4444", shadowStrength: 1.2)
        setButton(.dash, label: "X", in: &customization, x: 0.92, y: 0.46, width: 0.56, height: 0.56, shape: .circle, fill: "#E5E7EB")
        setButton(.focus, label: "Y", in: &customization, x: 0.76, y: 0.33, width: 0.56, height: 0.56, shape: .circle, fill: "#E5E7EB")
        setButton(.pause, label: "Start", in: &customization, x: 0.51, y: 0.51, width: 0.42, height: 0.42, shape: .circle, fill: utilityFill, shadowStrength: 0.85)

        addButton(mappedTo: .custom5, label: "L", in: &customization, x: 0.20, y: 0.13, width: 1.04, height: 0.34, shape: .capsule, fill: utilityFill)
        addButton(mappedTo: .custom6, label: "R", in: &customization, x: 0.80, y: 0.13, width: 1.04, height: 0.34, shape: .capsule, fill: utilityFill)
        addButton(mappedTo: .custom7, label: "Z", in: &customization, x: 0.88, y: 0.25, width: 0.58, height: 0.32, shape: .capsule, fill: "#6B7280")

        return customization.normalized
    }

    private static func gameBoyCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .monochrome, controlScale: .standard)
        let dPadFill = "#202124"
        let faceFill = "#8B1E3F"
        let utilityFill = "#6B7280"

        setButton(.up, label: "↑", in: &customization, x: 0.18, y: 0.37, width: 0.70, height: 0.70, shape: .roundedRectangle, fill: dPadFill, cornerRadius: 9)
        setButton(.down, label: "↓", in: &customization, x: 0.18, y: 0.75, width: 0.70, height: 0.70, shape: .roundedRectangle, fill: dPadFill, cornerRadius: 9)
        setButton(.left, label: "←", in: &customization, x: 0.075, y: 0.56, width: 0.70, height: 0.70, shape: .roundedRectangle, fill: dPadFill, cornerRadius: 9)
        setButton(.right, label: "→", in: &customization, x: 0.285, y: 0.56, width: 0.70, height: 0.70, shape: .roundedRectangle, fill: dPadFill, cornerRadius: 9)

        setButton(.attack, label: "B", in: &customization, x: 0.75, y: 0.62, width: 0.78, height: 0.78, shape: .circle, fill: faceFill, shadowStrength: 1.25)
        setButton(.jump, label: "A", in: &customization, x: 0.88, y: 0.50, width: 0.78, height: 0.78, shape: .circle, fill: faceFill, shadowStrength: 1.25)
        setButton(.map, label: "Select", in: &customization, x: 0.43, y: 0.79, width: 0.50, height: 0.52, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.57, y: 0.79, width: 0.46, height: 0.52, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        return customization.normalized
    }

    private static func gameBoyAdvanceCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .monochrome, controlScale: .standard)
        let dPadFill = "#202124"
        let faceFill = "#6D28D9"
        let utilityFill = "#6B7280"
        let shoulderFill = "#374151"

        setButton(.up, label: "↑", in: &customization, x: 0.17, y: 0.35, width: 0.64, height: 0.64, shape: .roundedRectangle, fill: dPadFill, cornerRadius: 9)
        setButton(.down, label: "↓", in: &customization, x: 0.17, y: 0.69, width: 0.64, height: 0.64, shape: .roundedRectangle, fill: dPadFill, cornerRadius: 9)
        setButton(.left, label: "←", in: &customization, x: 0.075, y: 0.52, width: 0.64, height: 0.64, shape: .roundedRectangle, fill: dPadFill, cornerRadius: 9)
        setButton(.right, label: "→", in: &customization, x: 0.265, y: 0.52, width: 0.64, height: 0.64, shape: .roundedRectangle, fill: dPadFill, cornerRadius: 9)

        setButton(.attack, label: "B", in: &customization, x: 0.75, y: 0.61, width: 0.74, height: 0.74, shape: .circle, fill: faceFill, shadowStrength: 1.25)
        setButton(.jump, label: "A", in: &customization, x: 0.88, y: 0.49, width: 0.74, height: 0.74, shape: .circle, fill: faceFill, shadowStrength: 1.25)
        setButton(.map, label: "Select", in: &customization, x: 0.43, y: 0.79, width: 0.48, height: 0.50, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.57, y: 0.79, width: 0.44, height: 0.50, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        addButton(mappedTo: .custom1, label: "L", in: &customization, x: 0.19, y: 0.16, width: 1.12, height: 0.40, shape: .capsule, fill: shoulderFill)
        addButton(mappedTo: .custom2, label: "R", in: &customization, x: 0.81, y: 0.16, width: 1.12, height: 0.40, shape: .capsule, fill: shoulderFill)

        return customization.normalized
    }

    private static func genesisSixButtonCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .amber, controlScale: .standard)
        let dPadFill = "#202124"
        let faceFill = "#111827"
        let utilityFill = "#374151"

        setDPad(in: &customization, centerX: 0.18, centerY: 0.56, scale: 0.58, fill: dPadFill)

        setButton(.focus, label: "X", in: &customization, x: 0.72, y: 0.43, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        addButton(mappedTo: .custom1, label: "Y", in: &customization, x: 0.83, y: 0.43, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        addButton(mappedTo: .custom2, label: "Z", in: &customization, x: 0.94, y: 0.43, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        setButton(.jump, label: "A", in: &customization, x: 0.72, y: 0.63, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        setButton(.attack, label: "B", in: &customization, x: 0.83, y: 0.63, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        setButton(.dash, label: "C", in: &customization, x: 0.94, y: 0.63, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)

        setButton(.map, label: "Mode", in: &customization, x: 0.44, y: 0.80, width: 0.44, height: 0.42, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.56, y: 0.80, width: 0.44, height: 0.42, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        return customization.normalized
    }

    private static func saturnCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .blue, controlScale: .standard)
        let dPadFill = "#202124"
        let faceFill = "#111827"
        let shoulderFill = "#374151"
        let utilityFill = "#475569"

        setDPad(in: &customization, centerX: 0.18, centerY: 0.56, scale: 0.58, fill: dPadFill)

        setButton(.focus, label: "X", in: &customization, x: 0.72, y: 0.43, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        addButton(mappedTo: .custom1, label: "Y", in: &customization, x: 0.83, y: 0.43, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        addButton(mappedTo: .custom2, label: "Z", in: &customization, x: 0.94, y: 0.43, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        setButton(.jump, label: "A", in: &customization, x: 0.72, y: 0.63, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        setButton(.attack, label: "B", in: &customization, x: 0.83, y: 0.63, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)
        setButton(.dash, label: "C", in: &customization, x: 0.94, y: 0.63, width: 0.54, height: 0.54, shape: .circle, fill: faceFill)

        addButton(mappedTo: .custom3, label: "L", in: &customization, x: 0.18, y: 0.15, width: 1.12, height: 0.38, shape: .capsule, fill: shoulderFill)
        addButton(mappedTo: .custom4, label: "R", in: &customization, x: 0.82, y: 0.15, width: 1.12, height: 0.38, shape: .capsule, fill: shoulderFill)
        setButton(.pause, label: "Start", in: &customization, x: 0.50, y: 0.80, width: 0.48, height: 0.42, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        return customization.normalized
    }

    private static func dreamcastCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .blue)
        let shellFill = "#CBD5E1"
        let triggerFill = "#94A3B8"
        let utilityFill = "#64748B"

        addJoystick(label: "Stick", mappedButton: .up, mapping: .movement, in: &customization, x: 0.18, y: 0.44, scale: 0.72, fill: shellFill)
        setDPad(in: &customization, centerX: 0.33, centerY: 0.72, scale: 0.48, fill: shellFill)

        setButton(.focus, label: "Y", in: &customization, x: 0.84, y: 0.32, width: 0.58, height: 0.58, shape: .circle, fill: "#FACC15")
        setButton(.dash, label: "B", in: &customization, x: 0.93, y: 0.50, width: 0.58, height: 0.58, shape: .circle, fill: "#EF4444")
        setButton(.jump, label: "A", in: &customization, x: 0.84, y: 0.68, width: 0.58, height: 0.58, shape: .circle, fill: "#22C55E")
        setButton(.attack, label: "X", in: &customization, x: 0.75, y: 0.50, width: 0.58, height: 0.58, shape: .circle, fill: "#3B82F6")

        addButton(mappedTo: .custom5, label: "L", in: &customization, x: 0.20, y: 0.13, width: 1.08, height: 0.36, shape: .capsule, fill: triggerFill)
        addButton(mappedTo: .custom6, label: "R", in: &customization, x: 0.80, y: 0.13, width: 1.08, height: 0.36, shape: .capsule, fill: triggerFill)
        setButton(.pause, label: "Start", in: &customization, x: 0.50, y: 0.45, width: 0.44, height: 0.40, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        return customization.normalized
    }

    private static func arcadeStickCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .amber, controlScale: .standard)
        let stickFill = "#111827"
        let utilityFill = "#374151"

        addJoystick(label: "Stick", mappedButton: .up, mapping: .movement, in: &customization, x: 0.22, y: 0.58, scale: 1.08, fill: stickFill)

        setButton(.map, label: "Coin", in: &customization, x: 0.40, y: 0.20, width: 0.52, height: 0.38, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.52, y: 0.20, width: 0.52, height: 0.38, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        setButton(.jump, label: "B1", in: &customization, x: 0.60, y: 0.39, width: 0.60, height: 0.60, shape: .circle, fill: "#EF4444", shadowStrength: 1.25)
        setButton(.attack, label: "B2", in: &customization, x: 0.71, y: 0.36, width: 0.60, height: 0.60, shape: .circle, fill: "#F97316", shadowStrength: 1.25)
        setButton(.dash, label: "B3", in: &customization, x: 0.82, y: 0.36, width: 0.60, height: 0.60, shape: .circle, fill: "#EAB308", shadowStrength: 1.25)
        setButton(.focus, label: "B4", in: &customization, x: 0.93, y: 0.39, width: 0.60, height: 0.60, shape: .circle, fill: "#22C55E", shadowStrength: 1.25)
        addButton(mappedTo: .custom1, label: "B5", in: &customization, x: 0.57, y: 0.62, width: 0.60, height: 0.60, shape: .circle, fill: "#3B82F6")
        addButton(mappedTo: .custom2, label: "B6", in: &customization, x: 0.68, y: 0.59, width: 0.60, height: 0.60, shape: .circle, fill: "#6366F1")
        addButton(mappedTo: .custom3, label: "B7", in: &customization, x: 0.79, y: 0.59, width: 0.60, height: 0.60, shape: .circle, fill: "#A855F7")
        addButton(mappedTo: .custom4, label: "B8", in: &customization, x: 0.90, y: 0.62, width: 0.60, height: 0.60, shape: .circle, fill: "#EC4899")

        return customization.normalized
    }

    private static func pspCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .monochrome)
        let shellFill = "#111827"
        let faceFill = "#1F2937"
        let utilityFill = "#374151"

        setDPad(in: &customization, centerX: 0.16, centerY: 0.50, scale: 0.58, fill: shellFill)
        addJoystick(label: "Nub", mappedButton: .up, mapping: .movement, in: &customization, x: 0.30, y: 0.75, scale: 0.72, fill: shellFill)

        setButton(.focus, label: "△", in: &customization, x: 0.84, y: 0.34, width: 0.60, height: 0.60, shape: .circle, fill: faceFill)
        setButton(.dash, label: "○", in: &customization, x: 0.93, y: 0.52, width: 0.60, height: 0.60, shape: .circle, fill: faceFill)
        setButton(.jump, label: "×", in: &customization, x: 0.84, y: 0.70, width: 0.60, height: 0.60, shape: .circle, fill: faceFill)
        setButton(.attack, label: "□", in: &customization, x: 0.75, y: 0.52, width: 0.60, height: 0.60, shape: .circle, fill: faceFill)

        setButton(.map, label: "Select", in: &customization, x: 0.43, y: 0.84, width: 0.48, height: 0.44, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.57, y: 0.84, width: 0.44, height: 0.44, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        addButton(mappedTo: .custom1, label: "L", in: &customization, x: 0.18, y: 0.16, width: 1.16, height: 0.40, shape: .capsule, fill: utilityFill)
        addButton(mappedTo: .custom2, label: "R", in: &customization, x: 0.82, y: 0.16, width: 1.16, height: 0.40, shape: .capsule, fill: utilityFill)

        return customization.normalized
    }

    private static func playStationCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .purple)
        let darkFill = "#171717"
        let utilityFill = "#374151"

        setDPad(in: &customization, centerX: 0.16, centerY: 0.50, scale: 0.56, fill: darkFill)
        addJoystick(label: "L Stick", mappedButton: .up, mapping: .movement, in: &customization, x: 0.32, y: 0.76, scale: 0.72, fill: darkFill)
        addJoystick(label: "R Stick", mappedButton: .custom1, mapping: .secondary, in: &customization, x: 0.66, y: 0.76, scale: 0.72, fill: darkFill)

        setButton(.focus, label: "△", in: &customization, x: 0.84, y: 0.34, width: 0.58, height: 0.58, shape: .circle, fill: "#22C55E")
        setButton(.dash, label: "○", in: &customization, x: 0.93, y: 0.52, width: 0.58, height: 0.58, shape: .circle, fill: "#EF4444")
        setButton(.jump, label: "×", in: &customization, x: 0.84, y: 0.70, width: 0.58, height: 0.58, shape: .circle, fill: "#3B82F6")
        setButton(.attack, label: "□", in: &customization, x: 0.75, y: 0.52, width: 0.58, height: 0.58, shape: .circle, fill: "#EC4899")

        setButton(.map, label: "Share", in: &customization, x: 0.43, y: 0.32, width: 0.44, height: 0.42, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Options", in: &customization, x: 0.57, y: 0.32, width: 0.44, height: 0.42, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        addButton(mappedTo: .custom5, label: "L2", in: &customization, x: 0.20, y: 0.10, width: 1.02, height: 0.34, shape: .capsule, fill: utilityFill)
        addButton(mappedTo: .custom6, label: "R2", in: &customization, x: 0.80, y: 0.10, width: 1.02, height: 0.34, shape: .capsule, fill: utilityFill)
        addButton(mappedTo: .custom7, label: "L1", in: &customization, x: 0.20, y: 0.21, width: 1.02, height: 0.34, shape: .capsule, fill: darkFill)
        addButton(mappedTo: .custom8, label: "R1", in: &customization, x: 0.80, y: 0.21, width: 1.02, height: 0.34, shape: .capsule, fill: darkFill)

        return customization.normalized
    }

    private static func xboxCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .green)
        let darkFill = "#111827"
        let utilityFill = "#374151"

        addJoystick(label: "L Stick", mappedButton: .up, mapping: .movement, in: &customization, x: 0.19, y: 0.47, scale: 0.72, fill: darkFill)
        setDPad(in: &customization, centerX: 0.34, centerY: 0.70, scale: 0.52, fill: darkFill)
        addJoystick(label: "R Stick", mappedButton: .custom1, mapping: .secondary, in: &customization, x: 0.64, y: 0.74, scale: 0.72, fill: darkFill)

        setButton(.focus, label: "Y", in: &customization, x: 0.84, y: 0.32, width: 0.58, height: 0.58, shape: .circle, fill: "#EAB308")
        setButton(.dash, label: "B", in: &customization, x: 0.93, y: 0.50, width: 0.58, height: 0.58, shape: .circle, fill: "#EF4444")
        setButton(.jump, label: "A", in: &customization, x: 0.84, y: 0.68, width: 0.58, height: 0.58, shape: .circle, fill: "#22C55E")
        setButton(.attack, label: "X", in: &customization, x: 0.75, y: 0.50, width: 0.58, height: 0.58, shape: .circle, fill: "#3B82F6")

        setButton(.map, label: "View", in: &customization, x: 0.44, y: 0.38, width: 0.42, height: 0.40, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Menu", in: &customization, x: 0.56, y: 0.38, width: 0.42, height: 0.40, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        addButton(mappedTo: .custom5, label: "LT", in: &customization, x: 0.20, y: 0.11, width: 1.02, height: 0.34, shape: .capsule, fill: utilityFill)
        addButton(mappedTo: .custom6, label: "RT", in: &customization, x: 0.80, y: 0.11, width: 1.02, height: 0.34, shape: .capsule, fill: utilityFill)
        addButton(mappedTo: .custom7, label: "LB", in: &customization, x: 0.20, y: 0.22, width: 1.02, height: 0.34, shape: .capsule, fill: darkFill)
        addButton(mappedTo: .custom8, label: "RB", in: &customization, x: 0.80, y: 0.22, width: 1.02, height: 0.34, shape: .capsule, fill: darkFill)

        return customization.normalized
    }

    private static func setDPad(
        in customization: inout GamepadCustomization,
        centerX: CGFloat,
        centerY: CGFloat,
        scale: CGFloat,
        fill: String
    ) {
        let xStep: CGFloat = 0.092
        let yStep: CGFloat = 0.17
        setButton(.up, label: "↑", in: &customization, x: centerX, y: centerY - yStep, width: scale, height: scale, shape: .roundedRectangle, fill: fill, cornerRadius: 8)
        setButton(.down, label: "↓", in: &customization, x: centerX, y: centerY + yStep, width: scale, height: scale, shape: .roundedRectangle, fill: fill, cornerRadius: 8)
        setButton(.left, label: "←", in: &customization, x: centerX - xStep, y: centerY, width: scale, height: scale, shape: .roundedRectangle, fill: fill, cornerRadius: 8)
        setButton(.right, label: "→", in: &customization, x: centerX + xStep, y: centerY, width: scale, height: scale, shape: .roundedRectangle, fill: fill, cornerRadius: 8)
    }

    private static func setButton(
        _ button: GameButton,
        label: String,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        fill: String,
        cornerRadius: CGFloat? = nil,
        shadowStrength: CGFloat = 1.0
    ) {
        customization.setButtonCustomization(
            templateButton(
                x: x,
                y: y,
                width: width,
                height: height,
                shape: shape,
                fill: fill,
                cornerRadius: cornerRadius,
                shadowStrength: shadowStrength
            ),
            for: button
        )
        customization.setLabel(label, for: button)
    }

    private static func addButton(
        mappedTo button: GameButton,
        label: String,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        fill: String
    ) {
        customization.customButtons.append(
            GamepadCustomButton(
                mappedButton: button,
                label: label,
                layout: templateButton(x: x, y: y, width: width, height: height, shape: shape, fill: fill)
            )
        )
    }

    private static func addJoystick(
        label: String,
        mappedButton: GameButton,
        mapping: GamepadJoystickMapping,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat,
        fill: String
    ) {
        customization.customButtons.append(
            GamepadCustomButton(
                mappedButton: mappedButton,
                label: label,
                layout: templateButton(x: x, y: y, width: scale, height: scale, shape: .circle, fill: fill, shadowStrength: 1.25),
                controlKind: .joystick,
                joystickMapping: mapping
            )
        )
    }

    private static func templateButton(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        fill: String,
        cornerRadius: CGFloat? = nil,
        shadowStrength: CGFloat = 1.0
    ) -> GamepadButtonCustomization {
        GamepadButtonCustomization(
            centerX: x,
            centerY: y,
            widthScale: width,
            heightScale: height,
            shape: shape,
            fillColor: GamepadRGBAColor(hexString: fill) ?? .defaultValue,
            cornerRadius: cornerRadius ?? defaultCornerRadius(for: shape),
            shadowStrength: shadowStrength,
            isLocationLocked: false,
            isHidden: false
        )
    }

    private static func defaultCornerRadius(for shape: GamepadButtonShapeStyle) -> CGFloat? {
        switch shape {
        case .capsule, .circle, .ellipse:
            nil
        case .rectangle:
            0
        case .roundedRectangle, .polygon, .star:
            12
        }
    }
}

enum GamepadConfigurationProfilePersistence {
    struct LoadedState: Equatable {
        let profiles: [GamepadConfigurationProfile]
        let activeProfileID: UUID
        let defaultProfileID: UUID

        var activeProfile: GamepadConfigurationProfile? {
            profiles.first { $0.id == activeProfileID }
        }

        var defaultProfile: GamepadConfigurationProfile? {
            profiles.first { $0.id == defaultProfileID }
        }
    }

    private struct StoredState: Codable {
        var profiles: [GamepadConfigurationProfile]
        var activeProfileID: UUID?
        var defaultProfileID: UUID?
    }

    static let defaultsKey = "PocketPad.gamepadConfigurationProfiles.v1"

    static func load(activeCustomization: GamepadCustomization) -> LoadedState {
        let activeCustomization = activeCustomization.normalized

        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let stored = try? JSONDecoder().decode(StoredState.self, from: data) {
            var profiles = normalizedUniqueProfiles(stored.profiles)
            if !profiles.isEmpty {
                let preferredActiveID = stored.activeProfileID ?? profiles[0].id
                let activeProfileID: UUID

                if let activeIndex = profiles.firstIndex(where: { $0.id == preferredActiveID }) {
                    profiles[activeIndex].customization = activeCustomization
                    profiles[activeIndex].updatedAt = Date.currentMilliseconds
                    activeProfileID = preferredActiveID
                } else {
                    let currentProfile = GamepadConfigurationProfile(
                        name: "Current Setup",
                        customization: activeCustomization
                    )
                    profiles.insert(currentProfile, at: 0)
                    activeProfileID = currentProfile.id
                }

                let defaultProfileID = validProfileID(stored.defaultProfileID, in: profiles) ?? activeProfileID
                return LoadedState(profiles: profiles, activeProfileID: activeProfileID, defaultProfileID: defaultProfileID)
            }
        }

        let profiles = defaultProfiles(activeCustomization: activeCustomization)
        return LoadedState(profiles: profiles, activeProfileID: profiles[0].id, defaultProfileID: profiles[0].id)
    }

    static func save(_ profiles: [GamepadConfigurationProfile], activeProfileID: UUID, defaultProfileID: UUID) {
        let state = normalizedState(
            profiles: profiles,
            activeProfileID: activeProfileID,
            defaultProfileID: defaultProfileID
        )
        guard let data = try? JSONEncoder().encode(
            StoredState(
                profiles: state.profiles,
                activeProfileID: state.activeProfileID,
                defaultProfileID: state.defaultProfileID
            )
        ) else { return }

        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func normalizedState(
        profiles: [GamepadConfigurationProfile],
        activeProfileID: UUID?,
        defaultProfileID: UUID?,
        fallbackCustomization: GamepadCustomization = .defaultValue
    ) -> LoadedState {
        var normalizedProfiles = normalizedUniqueProfiles(profiles)
        if normalizedProfiles.isEmpty {
            normalizedProfiles = defaultProfiles(activeCustomization: fallbackCustomization.normalized)
        }

        let activeProfileID = validProfileID(activeProfileID, in: normalizedProfiles) ?? normalizedProfiles[0].id
        let defaultProfileID = validProfileID(defaultProfileID, in: normalizedProfiles) ?? activeProfileID
        return LoadedState(
            profiles: normalizedProfiles,
            activeProfileID: activeProfileID,
            defaultProfileID: defaultProfileID
        )
    }

    private static func normalizedUniqueProfiles(_ profiles: [GamepadConfigurationProfile]) -> [GamepadConfigurationProfile] {
        var seenIDs = Set<UUID>()
        return profiles.compactMap { profile in
            let normalizedProfile = profile.normalized
            guard seenIDs.insert(normalizedProfile.id).inserted else { return nil }
            return normalizedProfile
        }
    }

    private static func validProfileID(_ profileID: UUID?, in profiles: [GamepadConfigurationProfile]) -> UUID? {
        guard let profileID,
              profiles.contains(where: { $0.id == profileID })
        else { return nil }
        return profileID
    }

    private static func defaultProfiles(activeCustomization: GamepadCustomization) -> [GamepadConfigurationProfile] {
        var standard = GamepadCustomization.defaultValue
        standard.accentStyle = .monochrome

        var southpaw = GamepadCustomization.defaultValue
        southpaw.layoutMode = .southpaw
        southpaw.accentStyle = .purple

        var largeBlue = GamepadCustomization.defaultValue
        largeBlue.controlScale = .large
        largeBlue.accentStyle = .blue

        var compact = GamepadCustomization.defaultValue
        compact.controlScale = .compact
        compact.showsButtonLabels = false

        var dualStick = GamepadCustomization.blankCanvas
        dualStick.accentStyle = .blue
        dualStick.addJoystick()
        dualStick.addJoystick()
        dualStick.addCustomButton(mappedTo: .jump)
        if let jumpIndex = dualStick.customButtons.indices.last {
            dualStick.customButtons[jumpIndex].label = "Fire"
            dualStick.customButtons[jumpIndex].layout.centerX = 0.50
            dualStick.customButtons[jumpIndex].layout.centerY = 0.78
            dualStick.customButtons[jumpIndex].layout.widthScale = 1.08
            dualStick.customButtons[jumpIndex].layout.heightScale = 1.08
            dualStick.customButtons[jumpIndex].layout.accentStyle = .amber
        }
        dualStick.addCustomButton(mappedTo: .attack)
        if let actionIndex = dualStick.customButtons.indices.last {
            dualStick.customButtons[actionIndex].label = "Action"
            dualStick.customButtons[actionIndex].layout.centerX = 0.50
            dualStick.customButtons[actionIndex].layout.centerY = 0.52
            dualStick.customButtons[actionIndex].layout.widthScale = 0.96
            dualStick.customButtons[actionIndex].layout.heightScale = 0.96
            dualStick.customButtons[actionIndex].layout.accentStyle = .purple
        }

        return [
            GamepadConfigurationProfile(name: "Current Setup", customization: activeCustomization),
            GamepadControllerTemplate.nes.makeProfile(),
            GamepadControllerTemplate.snes.makeProfile(),
            GamepadControllerTemplate.nintendo64.makeProfile(),
            GamepadControllerTemplate.gameCube.makeProfile(),
            GamepadControllerTemplate.gameBoy.makeProfile(),
            GamepadControllerTemplate.gameBoyAdvance.makeProfile(),
            GamepadControllerTemplate.genesisSixButton.makeProfile(),
            GamepadControllerTemplate.saturn.makeProfile(),
            GamepadControllerTemplate.dreamcast.makeProfile(),
            GamepadControllerTemplate.arcadeStick.makeProfile(),
            GamepadControllerTemplate.psp.makeProfile(),
            GamepadControllerTemplate.playStation.makeProfile(),
            GamepadControllerTemplate.xbox.makeProfile(),
            GamepadConfigurationProfile(name: "Navigation Left", customization: standard),
            GamepadConfigurationProfile(name: "Actions Left", customization: southpaw),
            GamepadConfigurationProfile(name: "Dual Stick Shooter", customization: dualStick),
            GamepadConfigurationProfile(name: "Large Blue", customization: largeBlue),
            GamepadConfigurationProfile(name: "Compact Minimal", customization: compact)
        ]
    }
}

#if os(macOS)
private final class GamepadEditorUndoTarget {}

private struct GamepadEditorUndoSnapshot: Equatable {
    var customization: GamepadCustomization
    var selectedControlID: GamepadControlIdentity
    var selectedControlIDs: Set<GamepadControlIdentity>
    var isControlSelectionActive: Bool
}

private struct GamepadEditorComponentItem: Identifiable, Hashable {
    let identity: GamepadControlIdentity
    let title: String
    let subtitle: String
    let systemImage: String
    let isHidden: Bool
    let isLocationLocked: Bool

    var id: GamepadControlIdentity { identity }
}

private enum GamepadFrameMetric {
    case x
    case y
    case width
    case height
}

private enum GamepadCanvasTool: Hashable, Identifiable {
    case select
    case rectangle
    case ellipse
    case polygon
    case star

    var id: String {
        switch self {
        case .select: "select"
        case .rectangle: "rectangle"
        case .ellipse: "ellipse"
        case .polygon: "polygon"
        case .star: "star"
        }
    }

    var displayName: String {
        switch self {
        case .select: "Select"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .polygon: "Polygon"
        case .star: "Star"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .polygon: "triangle"
        case .star: "star"
        }
    }

    var shapeStyle: GamepadButtonShapeStyle? {
        switch self {
        case .select: nil
        case .rectangle: .rectangle
        case .ellipse: .ellipse
        case .polygon: .polygon
        case .star: .star
        }
    }

    var keyboardShortcutText: String? {
        switch self {
        case .select: "V"
        case .rectangle: "R"
        case .ellipse: "O"
        case .polygon, .star: nil
        }
    }

    var isDrawingShape: Bool {
        shapeStyle != nil
    }
}

private struct GamepadShapeDrawState {
    let tool: GamepadCanvasTool
    let startPoint: CGPoint
    var currentPoint: CGPoint
}

private enum GamepadEditorColorScheme: String, CaseIterable, Hashable {
    case light
    case dark

    var displayName: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    var systemImage: String {
        switch self {
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

private struct GeistSegmentedPicker<Option: Hashable>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection

                Button {
                    selection = option
                } label: {
                    Text(label(option))
                        .geistTypography(.button14)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(isSelected ? selectedForeground : Geist.color(.gray900, scheme: colorScheme))
                        .padding(.horizontal, Geist.Spacing.s2)
                        .frame(height: 28)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected ? selectedFill : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(title): \(label(option))"))
            }
        }
        .padding(2)
        .frame(height: Geist.Spacing.s8)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var selectedFill: Color {
        Geist.color(.gray1000, scheme: colorScheme)
    }

    private var selectedForeground: Color {
        Geist.color(.background100, scheme: colorScheme)
    }
}

private struct GamepadShapeSegmentedPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: GamepadButtonShapeStyle

    var body: some View {
        HStack(spacing: 2) {
            ForEach(GamepadButtonShapeStyle.allCases) { shape in
                let isSelected = shape == selection
                let foreground = isSelected ? selectedForeground : Geist.color(.gray900, scheme: colorScheme)

                Button {
                    selection = shape
                } label: {
                    GamepadShapeSegmentedIcon(shape: shape, color: foreground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected ? selectedFill : Color.clear)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Shape: \(shape.displayName)"))
            }
        }
        .padding(2)
        .frame(height: Geist.Spacing.s8)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var selectedFill: Color {
        Geist.color(.gray1000, scheme: colorScheme)
    }

    private var selectedForeground: Color {
        Geist.color(.background100, scheme: colorScheme)
    }
}

private struct GamepadShapeSegmentedIcon: View {
    let shape: GamepadButtonShapeStyle
    let color: Color

    var body: some View {
        ZStack {
            switch shape {
            case .roundedRectangle:
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(color, lineWidth: 1.7)
                    .frame(width: 22, height: 16)
            case .rectangle:
                Rectangle()
                    .stroke(color, lineWidth: 1.7)
                    .frame(width: 22, height: 16)
            case .capsule:
                Capsule()
                    .stroke(color, lineWidth: 1.7)
                    .frame(width: 22, height: 14)
            case .circle:
                Circle()
                    .stroke(color, lineWidth: 1.7)
                    .frame(width: 17, height: 17)
            case .ellipse:
                Ellipse()
                    .stroke(color, lineWidth: 1.7)
                    .frame(width: 24, height: 14)
            case .polygon:
                GamepadRegularPolygonButtonShape(sides: 5)
                    .stroke(color, lineWidth: 1.7)
                    .frame(width: 18, height: 18)
            case .star:
                GamepadStarButtonShape(points: 5, innerRadiusRatio: 0.46)
                    .stroke(color, lineWidth: 1.55)
                    .frame(width: 19, height: 19)
            }
        }
        .frame(width: 26, height: 22)
        .accessibilityHidden(true)
    }
}

private struct GeistMenuPicker<Option: Hashable>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    if option == selection {
                        Label(label(option), systemImage: "checkmark")
                    } else {
                        Text(label(option))
                    }
                }
            }
        } label: {
            HStack(spacing: Geist.Spacing.s2) {
                Text(label(selection))
                    .geistTypography(.button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer(minLength: Geist.Spacing.s2)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .frame(height: Geist.Spacing.s8)
            .frame(minWidth: 120, alignment: .leading)
            .background(Geist.color(.background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(label(selection)))
    }
}

private struct GeistCheckboxToggle: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: Geist.Spacing.s2) {
                checkbox
                Text(title)
                    .geistTypography(.label14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            }
            .padding(.vertical, Geist.Spacing.s1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(isOn ? "On" : "Off"))
    }

    private var checkbox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isOn ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.background100, scheme: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(isOn ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.grayAlpha500, scheme: colorScheme), lineWidth: 1)
                )

            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Geist.color(.background100, scheme: colorScheme))
            }
        }
        .frame(width: 16, height: 16)
    }
}

private enum GamepadEditorDeviceFrame: String, CaseIterable, Identifiable {
    case iPhone17ProLandscape
    case iPhone17ProPortrait

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .iPhone17ProLandscape: "iPhone 17 Pro Landscape"
        case .iPhone17ProPortrait: "iPhone 17 Pro Portrait"
        }
    }

    var shortName: String {
        switch self {
        case .iPhone17ProLandscape: "Landscape"
        case .iPhone17ProPortrait: "Portrait"
        }
    }

    var systemImage: String {
        switch self {
        case .iPhone17ProLandscape: "iphone.landscape"
        case .iPhone17ProPortrait: "iphone"
        }
    }

    var assetName: String {
        switch self {
        case .iPhone17ProLandscape: "iPhone17ProSilverLandscape"
        case .iPhone17ProPortrait: "iPhone17ProSilverPortrait"
        }
    }

    /// Image and screen dimensions are expressed in logical points from the @3x bezel artwork.
    var imageSize: CGSize {
        switch self {
        case .iPhone17ProLandscape: CGSize(width: 920, height: 450)
        case .iPhone17ProPortrait: CGSize(width: 450, height: 920)
        }
    }

    /// Display opening inside the iPhone frame. The editor lays out controls in this rect.
    var screenRect: CGRect {
        switch self {
        case .iPhone17ProLandscape: CGRect(x: 23, y: 24, width: 874, height: 402)
        case .iPhone17ProPortrait: CGRect(x: 24, y: 23, width: 402, height: 874)
        }
    }
}

struct GamepadCustomizationEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undoManager
    @Binding private var customization: GamepadCustomization

    private let showsPreview: Bool
    private let externalProfiles: [GamepadConfigurationProfile]?
    private let externalSelectedProfileID: UUID?
    private let externalDefaultProfileID: UUID?
    private let onReset: (() -> Void)?
    private let onProfilesChanged: (([GamepadConfigurationProfile], UUID, UUID) -> Void)?
    private let defaultLabelProvider: ((GameButton) -> String?)?
    private let selectedKeyBindingContent: ((GameButton) -> AnyView)?

    private static let configurationSidebarMinWidth: CGFloat = 180
    private static let configurationSidebarMaxWidth: CGFloat = 360
    private static let inspectorSidebarMinWidth: CGFloat = 280
    private static let inspectorSidebarMaxWidth: CGFloat = 520
    private static let minimumCanvasColumnWidth: CGFloat = 320
    private static let resizeHandleWidth: CGFloat = 10
    // Keep editor coordinates stable; viewport/sidebar changes scale the preview instead of re-laying out keys.
    // The canvas uses the iPhone 17 Pro display opening in points so Mac edits match the physical device.
    private static let defaultDeviceFrame: GamepadEditorDeviceFrame = .iPhone17ProLandscape
    private static let canvasZoomMin: CGFloat = 0.5
    private static let canvasZoomMax: CGFloat = 2.25

    @State private var selectedControlID: GamepadControlIdentity
    @State private var selectedControlIDs: Set<GamepadControlIdentity>
    @State private var isControlSelectionActive: Bool
    @State private var profiles: [GamepadConfigurationProfile]
    @State private var selectedProfileID: UUID
    @State private var defaultProfileID: UUID
    @State private var isSelectedProfileExpanded: Bool
    @State private var selectedProfileNameDraft: String
    @State private var configurationSidebarDragStart: CGFloat?
    @State private var inspectorSidebarDragStart: CGFloat?
    @State private var canvasZoomGestureStart: CGFloat?
    @State private var currentCanvasLayoutSize = GamepadCustomizationEditor.defaultDeviceFrame.screenRect.size
    @State private var activeCanvasTool: GamepadCanvasTool = .select
    @State private var isFillColorPopoverPresented = false
    @State private var fillColorPickerHue: CGFloat = 0
    @State private var undoTarget = GamepadEditorUndoTarget()
    @FocusState private var isProfileNameFieldFocused: Bool
    @AppStorage("PocketPad.GamepadEditor.configurationSidebarWidth") private var configurationSidebarWidthValue: Double = 236
    @AppStorage("PocketPad.GamepadEditor.inspectorSidebarWidth") private var inspectorSidebarWidthValue: Double = 340
    @AppStorage("PocketPad.GamepadEditor.canvasZoom") private var canvasZoomValue: Double = 1.0
    @AppStorage("PocketPad.GamepadEditor.deviceFrame") private var deviceFrameRawValue: String = GamepadCustomizationEditor.defaultDeviceFrame.rawValue
    @AppStorage("PocketPad.GamepadEditor.editingColorScheme") private var editingColorSchemeRawValue: String = GamepadEditorColorScheme.light.rawValue

    init(
        customization: Binding<GamepadCustomization>,
        showsPreview: Bool = true,
        initialProfiles: [GamepadConfigurationProfile]? = nil,
        initialSelectedProfileID: UUID? = nil,
        initialDefaultProfileID: UUID? = nil,
        onReset: (() -> Void)? = nil,
        onProfilesChanged: (([GamepadConfigurationProfile], UUID, UUID) -> Void)? = nil,
        defaultLabelProvider: ((GameButton) -> String?)? = nil,
        selectedKeyBindingContent: ((GameButton) -> AnyView)? = nil
    ) {
        let loadedProfiles: GamepadConfigurationProfilePersistence.LoadedState
        if let initialProfiles {
            loadedProfiles = GamepadConfigurationProfilePersistence.normalizedState(
                profiles: initialProfiles,
                activeProfileID: initialSelectedProfileID,
                defaultProfileID: initialDefaultProfileID,
                fallbackCustomization: customization.wrappedValue
            )
        } else {
            loadedProfiles = GamepadConfigurationProfilePersistence.load(
                activeCustomization: customization.wrappedValue
            )
        }

        self._customization = customization
        self.showsPreview = showsPreview
        self.externalProfiles = initialProfiles
        self.externalSelectedProfileID = initialSelectedProfileID
        self.externalDefaultProfileID = initialDefaultProfileID
        self.onReset = onReset
        self.onProfilesChanged = onProfilesChanged
        self.defaultLabelProvider = defaultLabelProvider
        self.selectedKeyBindingContent = selectedKeyBindingContent
        self._selectedControlID = State(initialValue: .builtin(.jump))
        self._selectedControlIDs = State(initialValue: [.builtin(.jump)])
        self._isControlSelectionActive = State(initialValue: true)
        self._profiles = State(initialValue: loadedProfiles.profiles)
        self._selectedProfileID = State(initialValue: loadedProfiles.activeProfileID)
        self._defaultProfileID = State(initialValue: loadedProfiles.defaultProfileID)
        self._isSelectedProfileExpanded = State(initialValue: true)
        self._selectedProfileNameDraft = State(initialValue: loadedProfiles.activeProfile?.name ?? "Current Setup")
    }

    private var activeDeviceFrame: GamepadEditorDeviceFrame {
        GamepadEditorDeviceFrame(rawValue: deviceFrameRawValue) ?? Self.defaultDeviceFrame
    }

    private var activeDesignCanvasSize: CGSize {
        activeDeviceFrame.screenRect.size
    }

    private var editorColorScheme: GamepadEditorColorScheme {
        GamepadEditorColorScheme(rawValue: editingColorSchemeRawValue) ?? .light
    }

    private var activeKeypadColorScheme: ColorScheme {
        editorColorScheme.colorScheme
    }

    private var editorColorSchemeBinding: Binding<GamepadEditorColorScheme> {
        Binding(
            get: { editorColorScheme },
            set: { editingColorSchemeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            if showsPreview {
                GeometryReader { proxy in
                    if proxy.size.width >= 900 {
                        wideEditor
                    } else {
                        compactEditor
                    }
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    inspectorCompactSection
                        .padding(Geist.Spacing.s4)
                }
            }
        }
        .onChange(of: observedExternalProfiles) { _, _ in
            syncExternalProfileState()
        }
        .onChange(of: externalSelectedProfileID) { _, _ in
            syncExternalProfileState()
        }
        .onChange(of: externalDefaultProfileID) { _, _ in
            syncExternalProfileState()
        }
        .onChange(of: deviceFrameRawValue) { _, _ in
            noteCanvasLayoutSize(width: activeDesignCanvasSize.width, height: activeDesignCanvasSize.height)
        }
        .onChange(of: isProfileNameFieldFocused) { _, isFocused in
            if !isFocused {
                commitSelectedProfileNameDraft()
            }
        }
        .background {
            GamepadEditorKeyboardShortcutBridge(
                onDelete: deleteSelectedControl,
                onUndo: performUndo,
                onRedo: performRedo,
                onNudge: nudgeSelectedControls
            )
            .frame(width: 0, height: 0)
        }
    }

    private var wideEditor: some View {
        GeometryReader { proxy in
            let sidebarWidths = effectiveSidebarWidths(totalWidth: proxy.size.width)

            HStack(spacing: 0) {
                configurationSidebar
                    .frame(width: sidebarWidths.configuration)

                GamepadEditorResizeHandle(
                    accessibilityLabel: "Resize setups sidebar",
                    onDragChanged: { value in
                        resizeConfigurationSidebar(with: value, totalWidth: proxy.size.width)
                    },
                    onDragEnded: {
                        configurationSidebarDragStart = nil
                    }
                )

                canvasStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                GamepadEditorResizeHandle(
                    accessibilityLabel: "Resize inspector sidebar",
                    onDragChanged: { value in
                        resizeInspectorSidebar(with: value, totalWidth: proxy.size.width)
                    },
                    onDragEnded: {
                        inspectorSidebarDragStart = nil
                    }
                )

                inspectorSidebar
                    .frame(width: sidebarWidths.inspector)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Geist.color(.background100, scheme: colorScheme))
        }
    }

    private var compactEditor: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Geist.Spacing.s4) {
                configurationCompactSection
                canvasStage
                    .frame(height: 430)
                inspectorCompactSection
            }
            .padding(Geist.Spacing.s4)
        }
        .background(Geist.color(.background100, scheme: colorScheme))
    }

    private var configurationSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                        Text("Setups")
                            .geistTypography(.heading20)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        Text("Switch keypad setups quickly.")
                            .geistTypography(.copy13)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    }

                    Spacer(minLength: Geist.Spacing.s2)

                    templateMenu(showsTitle: false)

                    Button {
                        createProfile()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 22, height: 22)
                    }
                    .geistButtonStyle(.secondary, size: .small)
                    .accessibilityLabel("New keypad setup")
                }
            }
            .padding(Geist.Spacing.s4)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Geist.Spacing.s2) {
                    ForEach(profiles) { profile in
                        profileRow(profile)
                    }
                }
                .padding(Geist.Spacing.s3)
            }
        }
        .background(Geist.color(.background200, scheme: colorScheme))
    }

    private var configurationCompactSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Setups")
                        .geistTypography(.heading20)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("Choose a saved setup before editing.")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }

                Spacer()

                templateMenu(showsTitle: true)

                Button("New") { createProfile() }
                    .geistButtonStyle(.secondary, size: .small)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Geist.Spacing.s2) {
                    ForEach(profiles) { profile in
                        profileChip(profile)
                    }
                }
                .padding(.vertical, 1)
            }

            selectedSetupNameEditor
            activeSetupComponentsList

            configurationFooter
        }
        .geistPanel(padding: Geist.Spacing.s4, radius: Geist.Radius.md, raised: false)
    }

    private func templateMenu(showsTitle: Bool) -> some View {
        Menu {
            ForEach(GamepadControllerTemplate.allCases) { template in
                Button {
                    createProfile(from: template)
                } label: {
                    Label(template.displayName, systemImage: template.systemImage)
                }
                .help(template.description)
            }
        } label: {
            if showsTitle {
                Label("Templates", systemImage: "gamecontroller.fill")
            } else {
                Image(systemName: "gamecontroller.fill")
                    .frame(width: 22, height: 22)
            }
        }
        .menuStyle(.button)
        .geistButtonStyle(.secondary, size: .small)
        .accessibilityLabel("Keypad templates")
        .help("Create a setup from an emulator controller template")
    }

    @ViewBuilder
    private func profileRow(_ profile: GamepadConfigurationProfile) -> some View {
        let isSelected = profile.id == selectedProfileID
        let isExpanded = isSelected && isSelectedProfileExpanded

        VStack(alignment: .leading, spacing: isExpanded ? Geist.Spacing.s2 : 0) {
            Button {
                toggleProfileRow(profile, isSelected: isSelected)
            } label: {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    HStack(spacing: Geist.Spacing.s2) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                            .frame(width: 12)

                        Text(profile.name)
                            .geistTypography(.heading14)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .lineLimit(1)

                        Spacer(minLength: Geist.Spacing.s1)

                        if profile.id == defaultProfileID {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Geist.color(.amber700, scheme: colorScheme))
                                .help("Default setup")
                        }

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        }
                    }
                }
                .padding(Geist.Spacing.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                        .fill(isSelected ? Geist.color(.background100, scheme: colorScheme) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                        .stroke(isSelected ? Geist.color(.grayAlpha600, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: isSelected ? 1.5 : 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(profile.name) keypad setup"))
            .accessibilityHint(Text(profileRowAccessibilityHint(isSelected: isSelected, isExpanded: isExpanded)))

            if isExpanded {
                selectedSetupNameEditor
                    .padding(.horizontal, Geist.Spacing.s2)
                    .padding(.bottom, Geist.Spacing.s1)

                activeSetupComponentsList
                    .padding(.leading, Geist.Spacing.s2)
                    .padding(.bottom, Geist.Spacing.s1)
            }
        }
        .contextMenu {
            profileContextMenu(for: profile)
        }
    }

    @ViewBuilder
    private func profileContextMenu(for profile: GamepadConfigurationProfile) -> some View {
        Button {
            beginRenamingProfile(profile)
        } label: {
            Label("Rename", systemImage: "pencil")
        }

        Button {
            duplicateProfile(profile)
        } label: {
            Label("Duplicate", systemImage: "doc.on.doc")
        }

        Button(role: .destructive) {
            deleteProfile(profile)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .disabled(profiles.count <= 1)
    }

    private var selectedSetupNameEditor: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            Text("Name")
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .textCase(.uppercase)

            TextField("Setup name", text: $selectedProfileNameDraft)
                .geistInput(size: .small)
                .focused($isProfileNameFieldFocused)
                .onSubmit {
                    commitSelectedProfileNameDraft()
                }
                .accessibilityLabel("Keypad setup name")

            Text("Press Return or click away to save this setup name.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activeSetupComponentsList: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            HStack(spacing: Geist.Spacing.s2) {
                Text("Components")
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .textCase(.uppercase)

                Spacer(minLength: Geist.Spacing.s1)
            }
            .padding(.horizontal, Geist.Spacing.s2)

            if componentListItems.isEmpty {
                emptyComponentsMessage
            } else {
                VStack(spacing: Geist.Spacing.s1) {
                    ForEach(componentListItems) { item in
                        componentRow(item)
                    }
                }
            }
        }
    }

    private var emptyComponentsMessage: some View {
        Text("No components yet. Draw a shape on the canvas, add a joystick, or use Layout tools → Show Default Controls.")
            .geistTypography(.copy13)
            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .padding(Geist.Spacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
            )
    }

    private func componentRow(_ item: GamepadEditorComponentItem) -> some View {
        let isSelected = isControlSelectionActive && selectedControlIDs.contains(item.identity)
        let primaryTextColor = item.isHidden
            ? Geist.color(.gray900, scheme: colorScheme).opacity(0.58)
            : Geist.color(.gray1000, scheme: colorScheme)
        let secondaryTextColor = item.isHidden
            ? Geist.color(.gray900, scheme: colorScheme).opacity(0.48)
            : Geist.color(.gray900, scheme: colorScheme)

        return HStack(spacing: Geist.Spacing.s1) {
            Button {
                selectComponent(item.identity)
            } label: {
                HStack(spacing: Geist.Spacing.s2) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 14)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .geistTypography(.label13)
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                        Text(item.subtitle)
                            .geistTypography(.label12)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Geist.Spacing.s1)
                }
                .padding(.leading, Geist.Spacing.s2)
                .padding(.trailing, Geist.Spacing.s1)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(item.title)")

            componentIconButton(
                systemImage: item.isLocationLocked ? "lock.fill" : "lock.open",
                accessibilityLabel: item.isLocationLocked ? "Unlock \(item.title) location" : "Lock \(item.title) location",
                help: item.isLocationLocked ? "Unlock location" : "Lock location"
            ) {
                toggleComponentLock(item.identity)
            }

            componentIconButton(
                systemImage: item.isHidden ? "eye.slash.fill" : "eye",
                accessibilityLabel: item.isHidden ? "Show \(item.title)" : "Hide \(item.title)",
                help: item.isHidden ? "Show component" : "Hide component"
            ) {
                toggleComponentVisibility(item.identity)
            }
        }
        .padding(.trailing, Geist.Spacing.s1)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .fill(isSelected ? Geist.color(.background100, scheme: colorScheme) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(isSelected ? Geist.color(.blue700, scheme: colorScheme) : Color.clear, lineWidth: 1.5)
        )
    }

    private func componentIconButton(
        systemImage: String,
        accessibilityLabel: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 24, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .help(help)
    }

    @ViewBuilder
    private func profileChip(_ profile: GamepadConfigurationProfile) -> some View {
        let isSelected = profile.id == selectedProfileID

        Button {
            selectProfile(profile)
        } label: {
            HStack(spacing: Geist.Spacing.s1) {
                Text(profile.name)
                    .geistTypography(.heading14)
                    .lineLimit(1)

                if profile.id == defaultProfileID {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Geist.color(.amber700, scheme: colorScheme))
                }
            }
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .frame(width: 148, height: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .fill(isSelected ? Geist.color(.gray100, scheme: colorScheme) : Geist.color(.background100, scheme: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(isSelected ? Geist.color(.grayAlpha600, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            profileContextMenu(for: profile)
        }
    }

    private var configurationFooter: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            setupConfigurationControls

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) {
                    defaultProfileButton
                    profileManagementButtons
                }
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    defaultProfileButton
                    profileManagementButtons
                }
            }

            Button("Reset Current Setup") {
                resetActiveConfiguration()
            }
            .geistButtonStyle(.tertiary, size: .small)
        }
    }

    private var setupConfigurationControls: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Setup")
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Layout")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                GeistSegmentedPicker(title: "Layout", options: GamepadLayoutMode.allCases, selection: binding(\.layoutMode)) { mode in
                    mode.displayName
                }
                Text(customization.layoutMode.description)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Control Size")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                GeistSegmentedPicker(title: "Control Size", options: GamepadControlScale.allCases, selection: binding(\.controlScale)) { scale in
                    scale.displayName
                }
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Saved Appearance")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                GeistSegmentedPicker(title: "Saved Appearance", options: GamepadColorSchemePreference.allCases, selection: binding(\.colorSchemePreference)) { preference in
                    preference.displayName
                }
                Text("\(customization.colorSchemePreference.description) This preference is saved with the selected setup.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Preview & Edit")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                GeistSegmentedPicker(title: "Preview & Edit", options: GamepadEditorColorScheme.allCases, selection: editorColorSchemeBinding) { scheme in
                    scheme.displayName
                }
                Text("The canvas and color inspector are editing the \(editorColorScheme.displayName.lowercased()) palette. Light and dark fills are saved separately in this setup.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Geist.Spacing.s3) {
                Text("Default Color")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Spacer()
                GeistMenuPicker(title: "Default Color", options: GamepadAccentStyle.allCases, selection: binding(\.accentStyle)) { style in
                    style.displayName
                }
                .frame(minWidth: 120)
            }

            GeistCheckboxToggle(title: "Show Key Labels", isOn: binding(\.showsButtonLabels))
        }
    }

    private var defaultProfileButton: some View {
        Button {
            setSelectedProfileAsDefault()
        } label: {
            Label(defaultProfileID == selectedProfileID ? "Default Setup" : "Make Default", systemImage: defaultProfileID == selectedProfileID ? "star.fill" : "star")
        }
        .geistButtonStyle(defaultProfileID == selectedProfileID ? .tertiary : .secondary, size: .small)
        .disabled(defaultProfileID == selectedProfileID)
    }

    @ViewBuilder
    private var profileManagementButtons: some View {
        Button("Rename") {
            beginRenamingSelectedProfile()
        }
        .geistButtonStyle(.secondary, size: .small)

        Button("Duplicate") {
            duplicateProfile()
        }
        .geistButtonStyle(.secondary, size: .small)

        Button("Delete") {
            deleteSelectedProfile()
        }
        .geistButtonStyle(.tertiary, size: .small)
        .disabled(profiles.count <= 1)
    }

    private var canvasStage: some View {
        GeometryReader { proxy in
            let viewportWidth = max(160, proxy.size.width)
            let viewportHeight = max(160, proxy.size.height)
            let deviceFrame = activeDeviceFrame
            let fitWidth = max(120, viewportWidth)
            let fitHeight = max(120, viewportHeight)
            let fitScale = max(
                0.001,
                min(
                    fitWidth / deviceFrame.imageSize.width,
                    fitHeight / deviceFrame.imageSize.height
                )
            )
            let displayScale = fitScale * effectiveCanvasZoom
            let deviceWidth = deviceFrame.imageSize.width * displayScale
            let deviceHeight = deviceFrame.imageSize.height * displayScale

            canvasViewport(
                deviceFrame: deviceFrame,
                deviceWidth: deviceWidth,
                deviceHeight: deviceHeight,
                displayScale: displayScale,
                viewportWidth: viewportWidth,
                viewportHeight: viewportHeight
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Geist.color(.background100, scheme: colorScheme))
            .onAppear {
                noteCanvasLayoutSize(width: deviceFrame.screenRect.width, height: deviceFrame.screenRect.height)
            }
        }
    }

    private func canvasViewport(
        deviceFrame: GamepadEditorDeviceFrame,
        deviceWidth: CGFloat,
        deviceHeight: CGFloat,
        displayScale: CGFloat,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat
    ) -> some View {
        let screenRect = deviceFrame.screenRect
        let screenDisplayRect = CGRect(
            x: screenRect.minX * displayScale,
            y: screenRect.minY * displayScale,
            width: screenRect.width * displayScale,
            height: screenRect.height * displayScale
        )
        let outerWidth = deviceWidth
        let outerHeight = deviceHeight

        return ScrollView([.horizontal, .vertical], showsIndicators: false) {
            ZStack {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard activeCanvasTool == .select else { return }
                        isControlSelectionActive = false
                        selectedControlIDs.removeAll()
                    }

                ZStack(alignment: .topLeading) {
                    GamepadLayoutDesigner(
                        customization: editorBinding,
                        selectedControlID: $selectedControlID,
                        selectedControlIDs: $selectedControlIDs,
                        isControlSelectionActive: $isControlSelectionActive,
                        activeTool: $activeCanvasTool,
                        layoutSize: screenRect.size,
                        displayScale: displayScale,
                        defaultLabelProvider: defaultLabelProvider,
                        onBeginUndoableChange: { actionName in
                            registerUndoSnapshot(actionName: actionName)
                        }
                    )
                    .environment(\.colorScheme, activeKeypadColorScheme)
                    .frame(width: screenDisplayRect.width, height: screenDisplayRect.height)
                    .offset(x: screenDisplayRect.minX, y: screenDisplayRect.minY)

                    Image(deviceFrame.assetName)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .frame(width: deviceWidth, height: deviceHeight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .frame(width: deviceWidth, height: deviceHeight, alignment: .topLeading)
            }
            .frame(width: max(viewportWidth, outerWidth), height: max(viewportHeight, outerHeight))
        }
        .frame(height: viewportHeight)
        .overlay(alignment: .bottom) {
            canvasFloatingCreationToolbar
                .padding(.bottom, Geist.Spacing.s4)
        }
        .overlay(alignment: .topTrailing) {
            canvasAppearanceBadge
                .padding(Geist.Spacing.s4)
        }
        .background(Geist.color(.background200, scheme: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    if canvasZoomGestureStart == nil {
                        canvasZoomGestureStart = effectiveCanvasZoom
                    }

                    setCanvasZoom((canvasZoomGestureStart ?? 1.0) * value)
                }
                .onEnded { _ in
                    canvasZoomGestureStart = nil
                }
        )
    }

    private var canvasAppearanceBadge: some View {
        Label("Editing \(editorColorScheme.displayName)", systemImage: editorColorScheme.systemImage)
            .geistTypography(.label13)
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .padding(.vertical, Geist.Spacing.s2)
            .background(
                Capsule()
                    .fill(Geist.color(.background100, scheme: colorScheme).opacity(0.92))
            )
            .overlay(
                Capsule()
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 8, x: 0, y: 3)
            .accessibilityLabel("Editing \(editorColorScheme.displayName) keypad appearance")
    }

    private var canvasFloatingCreationToolbar: some View {
        HStack(spacing: Geist.Spacing.s2) {
            canvasToolButton(.select)

            toolbarMenu(systemImage: activeDeviceFrame.systemImage, accessibilityLabel: "Device frame") {
                ForEach(GamepadEditorDeviceFrame.allCases) { frame in
                    Button {
                        setDeviceFrame(frame)
                    } label: {
                        Label(frame.displayName, systemImage: frame == activeDeviceFrame ? "checkmark" : frame.systemImage)
                    }
                    .help("Use the \(frame.shortName.lowercased()) iPhone 17 Pro bezel and \(Int(frame.screenRect.width))×\(Int(frame.screenRect.height))pt display canvas.")
                }
            }

            toolbarMenu(systemImage: "square.grid.3x3", accessibilityLabel: "Layout tools") {
                Button("Show Default Controls") {
                    setBuiltInControlsHidden(false)
                }
                Button("Hide Built-in Controls") {
                    setBuiltInControlsHidden(true)
                }
                Divider()
                Button("Add Joystick") {
                    addJoystickControl()
                }
                .disabled(customization.customButtons.filter { $0.normalized.isJoystick }.count >= GamepadCustomization.maximumJoysticks || customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
                Divider()
                Button("Reset Key Layout") {
                    resetKeyLayout()
                }
                .disabled(!customization.usesFreeformLayout)
            }

            shapeDrawingToolMenu

            toolbarMenu(systemImage: "pencil.tip", accessibilityLabel: "Style tools") {
                ForEach(GamepadAccentStyle.allCases) { style in
                    Button(style.displayName) {
                        update { $0.accentStyle = style }
                    }
                }
            }
        }
        .padding(Geist.Spacing.s2)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Geist.color(.background100, scheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.16), radius: 18, x: 0, y: 8)
    }

    private func canvasToolButton(_ tool: GamepadCanvasTool) -> some View {
        let isSelected = activeCanvasTool == tool

        return Button {
            activeCanvasTool = tool
        } label: {
            Image(systemName: tool.systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Geist.color(.gray1000, scheme: colorScheme))
                .frame(width: 32, height: 32)
                .background(isSelected ? Geist.color(.blue700, scheme: colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut("v", modifiers: [])
        .accessibilityLabel("Select controls")
        .help("Select and drag controls (V)")
    }

    private var shapeDrawingToolMenu: some View {
        let activeShapeTool = activeCanvasTool.isDrawingShape ? activeCanvasTool : GamepadCanvasTool.rectangle
        let isShapeToolSelected = activeCanvasTool.isDrawingShape

        return Menu {
            shapeToolMenuButton(.rectangle)
            shapeToolMenuButton(.ellipse)
            shapeToolMenuButton(.polygon)
            shapeToolMenuButton(.star)
        } label: {
            HStack(spacing: Geist.Spacing.s2) {
                Image(systemName: activeShapeTool.systemImage)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(isShapeToolSelected ? Color.white : Geist.color(.gray1000, scheme: colorScheme))
                    .frame(width: 32, height: 32)
                    .background(isShapeToolSelected ? Geist.color(.blue700, scheme: colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isShapeToolSelected ? Color.white : Geist.color(.gray1000, scheme: colorScheme))
                    .frame(width: 12, height: 32)
            }
            .padding(.horizontal, Geist.Spacing.s2)
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Shape tools")
        .help("Draw key shapes on the keypad")
    }

    @ViewBuilder
    private func shapeToolMenuButton(_ tool: GamepadCanvasTool) -> some View {
        let isSelected = activeCanvasTool == tool
        let title = tool.displayName

        if tool == .rectangle {
            Button {
                activeCanvasTool = tool
            } label: {
                Label(title, systemImage: isSelected ? "checkmark" : tool.systemImage)
            }
            .keyboardShortcut("r", modifiers: [])
            .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
        } else if tool == .ellipse {
            Button {
                activeCanvasTool = tool
            } label: {
                Label(title, systemImage: isSelected ? "checkmark" : tool.systemImage)
            }
            .keyboardShortcut("o", modifiers: [])
            .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
        } else {
            Button {
                activeCanvasTool = tool
            } label: {
                Label(title, systemImage: isSelected ? "checkmark" : tool.systemImage)
            }
            .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
        }
    }

    private func toolbarMenu<Content: View>(
        systemImage: String,
        accessibilityLabel: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: Geist.Spacing.s2) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .frame(width: 32, height: 32)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .frame(width: 12, height: 32)
            }
            .padding(.horizontal, Geist.Spacing.s2)
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var inspectorSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            inspectorHeader
                .padding(Geist.Spacing.s4)

            Divider()

            ScrollView(.vertical, showsIndicators: false) {
                inspectorContent
                    .padding(Geist.Spacing.s4)
            }
        }
        .background(Geist.color(.background200, scheme: colorScheme))
    }

    private var inspectorCompactSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            inspectorHeader
            inspectorContent
        }
        .geistPanel(padding: Geist.Spacing.s4, radius: Geist.Radius.md, raised: false)
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s3) {
                Text("Inspector")
                    .geistTypography(.heading20)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Text(canvasZoomPercentageText)
                    .geistTypography(.label13Mono)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .accessibilityLabel("Canvas zoom \(canvasZoomPercentageText)")
            }

            Text("Selected element properties")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

            Label(selectedInspectorTitle, systemImage: selectedControlIsEditable ? "scope" : "rectangle.dashed")
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .padding(.horizontal, Geist.Spacing.s3)
                .padding(.vertical, Geist.Spacing.s2)
                .background(Geist.color(.gray100, scheme: colorScheme), in: Capsule())
                .overlay(Capsule().stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1))
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        selectedElementInspector
    }

    @ViewBuilder
    private var selectedElementInspector: some View {
        if selectedControlIsEditable {
            VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                selectedElementIdentitySection
                Divider()
                selectedElementColorSection
                Divider()
                selectedElementSizeSection
                Divider()
                selectedElementRadiusSection
                Divider()
                selectedElementEffectsSection
            }
        } else {
            emptySelectionInspector
        }
    }

    private var emptySelectionInspector: some View {
        let isBlankSetup = componentListItems.isEmpty

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text(isBlankSetup ? "Blank setup" : "No component selected")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            Text(isBlankSetup ? "Draw a shape on the canvas, add a joystick, or choose Layout tools → Show Default Controls to add keypad components." : "Select a component on the canvas or from the components list to edit its properties.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Geist.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var selectedElementIdentitySection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Element")
                        .geistTypography(.heading14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text(selectedControlTitle)
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }

                Spacer()

                Button("Reset") {
                    resetSelectedControl()
                }
                .geistButtonStyle(.tertiary, size: .small)
            }

            controlSelectionPicker
            selectedElementLabelControls

            if let shortcutButton = selectedShortcutButton,
               let selectedKeyBindingContent {
                selectedKeyBindingContent(shortcutButton)
            }

            componentStateControls

            if case .custom(let id) = selectedControlID,
               let customButton = customButton(id: id)?.normalized {
                Button(customButton.isJoystick ? "Delete Joystick" : "Delete Shape") {
                    _ = deleteCustomButton(id: id)
                }
                .geistButtonStyle(.error, size: .small)
            }
        }
    }

    @ViewBuilder
    private var selectedElementLabelControls: some View {
        switch selectedControlID {
        case .builtin(let button):
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Label")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                TextField(
                    defaultLabel(for: button),
                    text: labelBinding(for: button)
                )
                .geistInput(size: .small)
                Text("Leave blank to use the recorded shortcut label (\(defaultLabel(for: button))).")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }
        case .custom(let id):
            if customButton(id: id) != nil {
                customButtonControls(id: id)
            }
        }
    }

    private var selectedElementColorSection: some View {
        let editingScheme = activeKeypadColorScheme
        let colorValue = selectedFillColorValue(for: selectedControlID, scheme: editingScheme)
        let usesCustomColor = selectedLayoutCustomization(for: selectedControlID).hasCustomFillColor(for: editingScheme)
        let schemeName = Self.displayName(for: editingScheme)

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(alignment: .center, spacing: Geist.Spacing.s2) {
                Text("Fill")
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Button {
                    isFillColorPopoverPresented = true
                } label: {
                    Image(systemName: "circle.grid.2x2")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .accessibilityLabel("Open fill color settings")

                Button {
                    isFillColorPopoverPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .accessibilityLabel("Configure fill color")
            }

            fillColorRow(
                colorValue: colorValue,
                hexValue: fillColorHexPlainBinding(for: selectedControlID, scheme: editingScheme),
                alphaValue: fillColorAlphaTextBinding(for: selectedControlID, scheme: editingScheme),
                usesCustomColor: usesCustomColor,
                editingScheme: editingScheme
            )
            .popover(isPresented: $isFillColorPopoverPresented, arrowEdge: .leading) {
                fillColorDetailPopover(
                    editingScheme: editingScheme,
                    schemeName: schemeName,
                    usesCustomColor: usesCustomColor
                )
            }

            Text(usesCustomColor ? "Custom \(schemeName.lowercased()) fill" : "Using the selected preset for the \(schemeName.lowercased()) palette")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fillColorRow(
        colorValue: GamepadRGBAColor,
        hexValue: Binding<String>,
        alphaValue: Binding<String>,
        usesCustomColor: Bool,
        editingScheme: ColorScheme
    ) -> some View {
        HStack(spacing: Geist.Spacing.s2) {
            HStack(spacing: 0) {
                Button {
                    isFillColorPopoverPresented.toggle()
                } label: {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(colorValue.swiftUIColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Geist.color(.grayAlpha500, scheme: colorScheme), lineWidth: 1)
                        )
                        .frame(width: 28, height: 28)
                        .padding(.leading, Geist.Spacing.s2)
                        .padding(.trailing, Geist.Spacing.s1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open fill color picker")

                TextField("000000", text: hexValue)
                    .textFieldStyle(.plain)
                    .geistTypography(.label14Mono)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .frame(minWidth: 72)
#if os(iOS)
                    .textInputAutocapitalization(.characters)
#endif

                Rectangle()
                    .fill(Geist.color(.grayAlpha300, scheme: colorScheme))
                    .frame(width: 1)

                TextField("100", text: alphaValue)
                    .textFieldStyle(.plain)
                    .geistTypography(.label14Mono)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
#if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
#endif

                Text("%")
                    .geistTypography(.label14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .frame(width: 24)
            }
            .frame(height: Geist.Spacing.s10)
            .background(Geist.color(isFillColorPopoverPresented ? .gray200 : .gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(isFillColorPopoverPresented ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha300, scheme: colorScheme), lineWidth: isFillColorPopoverPresented ? 1.25 : 1)
            )

            Button {
                toggleFillVisibility(for: selectedControlID, scheme: editingScheme)
            } label: {
                Image(systemName: colorValue.alpha > 0.001 ? "eye" : "eye.slash")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .accessibilityLabel(colorValue.alpha > 0.001 ? "Hide fill" : "Show fill")

            Button {
                clearCustomFillColor(for: selectedControlID, scheme: editingScheme)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(usesCustomColor ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.gray700, scheme: colorScheme))
            .disabled(!usesCustomColor)
            .accessibilityLabel("Remove custom fill")
        }
    }

    private func fillColorDetailPopover(
        editingScheme: ColorScheme,
        schemeName: String,
        usesCustomColor: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: Geist.Spacing.s3) {
                Text("Custom")
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .padding(.horizontal, Geist.Spacing.s3)
                    .frame(height: 36)
                    .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

                Text("Libraries")
                    .geistTypography(.label14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Button {
                    isFillColorPopoverPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Button {
                    isFillColorPopoverPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .regular))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            }
            .padding(.horizontal, Geist.Spacing.s3)
            .padding(.vertical, Geist.Spacing.s2)

            Divider()

            HStack(spacing: Geist.Spacing.s2) {
                ForEach(fillColorToolIcons, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .frame(width: 34, height: 34)
                        .background(icon == fillColorToolIcons.first ? Geist.color(.gray100, scheme: colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                }
            }
            .padding(.horizontal, Geist.Spacing.s3)
            .padding(.vertical, Geist.Spacing.s2)

            Divider()

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                GamepadColorPlane(color: fillColorValueBinding(for: selectedControlID, scheme: editingScheme), hue: $fillColorPickerHue)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

                GamepadHueSlider(color: fillColorValueBinding(for: selectedControlID, scheme: editingScheme), hue: $fillColorPickerHue)
                    .frame(height: 26)

                GamepadAlphaSlider(color: fillColorValueBinding(for: selectedControlID, scheme: editingScheme))
                    .frame(height: 26)

                HStack(spacing: Geist.Spacing.s2) {
                    Menu {
                        Button("Hex") {}
                    } label: {
                        HStack(spacing: Geist.Spacing.s2) {
                            Text("Hex")
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .frame(width: 92, height: Geist.Spacing.s10)
                    }
                    .menuStyle(.button)
                    .buttonStyle(.plain)
                    .geistInput(size: .medium)

                    GamepadColorValueField(text: fillColorHexPlainBinding(for: selectedControlID, scheme: editingScheme), placeholder: "000000")

                    GamepadColorValueField(text: fillColorAlphaTextBinding(for: selectedControlID, scheme: editingScheme), placeholder: "100", suffix: "%", width: 96)
                }

                Menu {
                    ForEach(GamepadEditorColorScheme.allCases, id: \.self) { scheme in
                        Button(scheme.displayName) {
                            editorColorSchemeBinding.wrappedValue = scheme
                        }
                    }
                } label: {
                    HStack {
                        Text("On this \(schemeName.lowercased()) palette")
                            .geistTypography(.label14)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .padding(.horizontal, Geist.Spacing.s3)
                    .frame(height: Geist.Spacing.s10)
                    .background(Geist.color(.background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                            .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .menuStyle(.button)

                HStack(spacing: Geist.Spacing.s2) {
                    ForEach(GamepadAccentStyle.allCases) { style in
                        elementColorPresetChip(style, scheme: editingScheme)
                    }
                }

                Button("Use Default \(schemeName) Color") {
                    clearCustomFillColor(for: selectedControlID, scheme: editingScheme)
                }
                .geistButtonStyle(.tertiary, size: .small)
                .disabled(!usesCustomColor)
            }
            .padding(Geist.Spacing.s3)
        }
        .frame(width: 360)
        .background(Geist.color(.background100, scheme: colorScheme))
    }

    private var fillColorToolIcons: [String] {
        ["square.on.square", "circle.grid.2x2", "tablecells", "photo", "play.rectangle", "waveform.path", "drop", "circle.slash"]
    }

    private func elementColorPresetChip(_ style: GamepadAccentStyle, scheme: ColorScheme) -> some View {
        let layoutCustomization = selectedLayoutCustomization(for: selectedControlID)
        let isSelected = !layoutCustomization.hasCustomFillColor(for: scheme) && accentStyleValue(for: selectedControlID) == style

        return Button {
            accentStyleBinding(for: selectedControlID).wrappedValue = style
        } label: {
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .fill(style.buttonFill(isPressed: false, scheme: scheme))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                        .stroke(isSelected ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: isSelected ? 2 : 1)
                )
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.displayName)
    }

    private func colorTextField(title: String, value: Binding<String>, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
            Text(title)
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            HStack(spacing: Geist.Spacing.s1) {
                TextField(title, text: value)
                    .geistTypography(.label12Mono)
#if os(iOS)
                    .textInputAutocapitalization(.characters)
#endif
                if let unit {
                    Text(unit)
                        .geistTypography(.label12Mono)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }
            }
            .geistInput(size: .small)
        }
    }

    private func elementColorSwatch(_ style: GamepadAccentStyle, scheme: ColorScheme) -> some View {
        let layoutCustomization = selectedLayoutCustomization(for: selectedControlID)
        let isSelected = !layoutCustomization.hasCustomFillColor(for: scheme) && accentStyleValue(for: selectedControlID) == style
        let inheritsDefault = layoutCustomization.accentStyle == nil && customization.accentStyle == style && !layoutCustomization.hasCustomFillColor(for: scheme)

        return Button {
            accentStyleBinding(for: selectedControlID).wrappedValue = style
        } label: {
            HStack(spacing: Geist.Spacing.s2) {
                Circle()
                    .fill(style.buttonFill(isPressed: false, scheme: scheme))
                    .overlay(Circle().stroke(style.buttonStroke(isPressed: false, scheme: scheme), lineWidth: 1))
                    .frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 1) {
                    Text(style.displayName)
                        .geistTypography(.label13)
                    if inheritsDefault {
                        Text("Default")
                            .geistTypography(.label12)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    }
                }

                Spacer(minLength: Geist.Spacing.s1)
            }
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s2)
            .frame(height: 40)
            .background(Geist.color(isSelected ? .gray100 : .background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(isSelected ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedElementSizeSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            selectedElementPositionControls

            Divider()

            selectedElementLayoutControls
        }
    }

    private var selectedElementPositionControls: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Position")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Position (px)")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                    inspectorMetricField(title: "X", value: frameMetricBinding(.x), accessibilityLabel: "X position in pixels")
                    inspectorMetricField(title: "Y", value: frameMetricBinding(.y), accessibilityLabel: "Y position in pixels")
                }
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Rotation")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                    inspectorMetricField(title: "R", value: rotationDegreesBinding(for: selectedControlID), unit: "°", accessibilityLabel: "Rotation in degrees")
                }
            }

            Text("X and Y use the component’s top-left point. Rotation happens around the center.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedElementLayoutControls: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Layout")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Dimensions (px)")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                    inspectorMetricField(title: "W", value: frameMetricBinding(.width), accessibilityLabel: "Width in pixels")
                    inspectorMetricField(title: "H", value: frameMetricBinding(.height), accessibilityLabel: "Height in pixels")
                }
            }
        }
    }

    private func inspectorMetricField(
        title: String,
        value: Binding<Double>,
        unit: String? = nil,
        maxFractionDigits: Int = 2,
        accessibilityLabel: String? = nil
    ) -> some View {
        GamepadInspectorMetricField(
            title: title,
            value: value,
            unit: unit,
            maxFractionDigits: maxFractionDigits,
            accessibilityLabel: accessibilityLabel
        )
    }

    private func metricField(title: String, value: Binding<Double>, unit: String) -> some View {
        GamepadMetricField(title: title, value: value, unit: unit)
    }

    private var selectedElementRadiusSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Corners")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            GamepadShapeSegmentedPicker(selection: shapeBinding(for: selectedControlID))

            if shapeValue(for: selectedControlID).usesEditableCornerRadii {
                valueSlider(
                    title: "All",
                    value: uniformCornerRadiusBinding(for: selectedControlID),
                    range: Double(GamepadButtonCustomization.minimumCornerRadius)...Double(maximumCornerRadiusValue(for: selectedControlID)),
                    valueText: "\(Int(uniformCornerRadiusValue(for: selectedControlID).rounded())) pt"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                    ForEach(GamepadCorner.allCases) { corner in
                        metricField(title: corner.shortLabel, value: cornerRadiusBinding(for: selectedControlID, corner: corner), unit: "pt")
                            .accessibilityLabel(corner.accessibilityLabel)
                    }
                }

                Text("Drag the purple dot on the selected component to adjust all corners directly.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Corner controls apply to rectangle-based shapes.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedElementEffectsSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Effects")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            valueSlider(
                title: "Shadow",
                value: shadowStrengthBinding(for: selectedControlID),
                range: Double(GamepadButtonCustomization.minimumShadowStrength)...Double(GamepadButtonCustomization.maximumShadowStrength),
                valueText: "\(Int((shadowStrengthValue(for: selectedControlID) * 100).rounded()))%"
            )
        }
    }

    private var controlSelectionPicker: some View {
        HStack(spacing: Geist.Spacing.s3) {
            Text("Control")
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            Spacer()
            GeistMenuPicker(title: "Control", options: controlSelectionOptions, selection: $selectedControlID) { identity in
                controlSelectionLabel(for: identity)
            }
        }
    }

    private var selectedControlIsEditable: Bool {
        isControlSelectionActive
            && selectedControlIDs.contains(selectedControlID)
            && controlSelectionOptions.contains(selectedControlID)
    }

    private var controlSelectionOptions: [GamepadControlIdentity] {
        controlSelectionOptions(for: customization)
    }

    private func controlSelectionOptions(for customization: GamepadCustomization) -> [GamepadControlIdentity] {
        let builtinItems = shouldListBuiltInComponents(for: customization)
            ? GameButton.builtInControls.map { GamepadControlIdentity.builtin($0) }
            : []
        return builtinItems + customization.customButtons.map { GamepadControlIdentity.custom($0.id) }
    }

    private func shouldListBuiltInComponents(for customization: GamepadCustomization) -> Bool {
        GameButton.builtInControls.contains { !customization.buttonCustomization(for: $0).isHidden }
    }

    private func preferredControlSelection(for customization: GamepadCustomization) -> GamepadControlIdentity? {
        let options = controlSelectionOptions(for: customization)
        let preferred = GamepadControlIdentity.builtin(.jump)
        return options.contains(preferred) ? preferred : options.first
    }

    private var componentListItems: [GamepadEditorComponentItem] {
        let builtinItems: [GamepadEditorComponentItem]
        if shouldListBuiltInComponents(for: customization) {
            builtinItems = GameButton.builtInControls.map { button -> GamepadEditorComponentItem in
                let buttonCustomization = customization.buttonCustomization(for: button)
                return GamepadEditorComponentItem(
                    identity: .builtin(button),
                    title: button.displayName,
                    subtitle: visualLabel(for: button),
                    systemImage: "diamond.fill",
                    isHidden: buttonCustomization.isHidden,
                    isLocationLocked: buttonCustomization.isLocationLocked
                )
            }
        } else {
            builtinItems = []
        }

        let customItems = customization.customButtons.map { customButton -> GamepadEditorComponentItem in
            let normalizedButton = customButton.normalized
            let title = normalizedButton.visualLabel(fallback: visualLabel(for: normalizedButton.mappedButton))
            let subtitle: String
            let systemImage: String
            if normalizedButton.isJoystick {
                subtitle = "Joystick → 4 directions"
                systemImage = "circle.grid.cross"
            } else {
                subtitle = "Shape → \(normalizedButton.mappedButton.displayName)"
                systemImage = "plus.square.fill"
            }
            return GamepadEditorComponentItem(
                identity: .custom(normalizedButton.id),
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                isHidden: normalizedButton.layout.isHidden,
                isLocationLocked: normalizedButton.layout.isLocationLocked
            )
        }

        return builtinItems + customItems
    }

    private var componentStateControls: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            GeistCheckboxToggle(title: "Show on keypad", isOn: visibleBinding(for: selectedControlID))
            GeistCheckboxToggle(title: "Lock position", isOn: locationLockBinding(for: selectedControlID))
            Text("Locked controls stay selectable but cannot be dragged on the canvas.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Geist.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private func controlSelectionLabel(for identity: GamepadControlIdentity) -> String {
        switch identity {
        case .builtin(let button):
            return button.displayName
        case .custom(let id):
            guard let customButton = customButton(id: id)?.normalized else { return "Shape" }
            return customButton.visualLabel(fallback: customButton.isJoystick ? "Joystick" : visualLabel(for: customButton.mappedButton))
        }
    }

    @ViewBuilder
    private func customButtonControls(id: UUID) -> some View {
        if customButton(id: id)?.normalized.isJoystick == true {
            joystickControls(id: id)
        } else {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                HStack(spacing: Geist.Spacing.s3) {
                    Text("Sends")
                        .geistTypography(.label13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    Spacer()
                    GeistMenuPicker(title: "Sends", options: GameButton.allCases, selection: customMappedButtonBinding(id: id)) { button in
                        button.displayName
                    }
                }

                let mappedButton = customButton(id: id)?.mappedButton ?? .jump
                TextField(defaultLabel(for: mappedButton), text: customLabelBinding(id: id))
                    .geistInput(size: .small)

                Text("Shapes send the selected shortcut slot; record that shortcut below.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func joystickControls(id: UUID) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            TextField("Joystick", text: customLabelBinding(id: id))
                .geistInput(size: .small)

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Directions")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                ForEach(GamepadJoystickDirection.allCases) { direction in
                    HStack(spacing: Geist.Spacing.s3) {
                        Text(direction.displayName)
                            .geistTypography(.label13)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        Spacer()
                        GeistMenuPicker(title: "\(direction.displayName) sends", options: GameButton.allCases, selection: joystickDirectionBinding(id: id, direction: direction)) { button in
                            button.displayName
                        }
                    }
                }
            }

            Text("Joysticks hold and release the mapped directional shortcut slots as your thumb crosses the dead zone, including diagonals.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            if let selectedKeyBindingContent {
                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    ForEach(GamepadJoystickDirection.allCases) { direction in
                        let button = joystickMappingValue(id: id)[direction]
                        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                            Text("\(direction.displayName) shortcut")
                                .geistTypography(.label13)
                                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                            selectedKeyBindingContent(button)
                        }
                    }
                }
            }
        }
    }

    private func sizeSlider(title: String, value: Binding<Double>, currentValue: CGFloat) -> some View {
        valueSlider(
            title: title,
            value: value,
            range: Double(GamepadButtonCustomization.minimumScale)...Double(GamepadButtonCustomization.maximumScale),
            valueText: "\(Int((currentValue * 100).rounded()))%"
        )
    }

    private func valueSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, valueText: String) -> some View {
        HStack(spacing: Geist.Spacing.s3) {
            Text(title)
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 58, alignment: .leading)
            Slider(value: value, in: range)
            Text(valueText)
                .geistTypography(.label12Mono)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 56, alignment: .trailing)
        }
    }

    private var configurationSidebarWidth: CGFloat {
        Self.clamp(
            CGFloat(configurationSidebarWidthValue),
            lower: Self.configurationSidebarMinWidth,
            upper: Self.configurationSidebarMaxWidth
        )
    }

    private var inspectorSidebarWidth: CGFloat {
        Self.clamp(
            CGFloat(inspectorSidebarWidthValue),
            lower: Self.inspectorSidebarMinWidth,
            upper: Self.inspectorSidebarMaxWidth
        )
    }

    private var effectiveCanvasZoom: CGFloat {
        Self.clamp(
            CGFloat(canvasZoomValue),
            lower: Self.canvasZoomMin,
            upper: Self.canvasZoomMax
        )
    }

    private var canvasZoomPercentageText: String {
        "\(Int((effectiveCanvasZoom * 100).rounded()))%"
    }

    private func effectiveSidebarWidths(totalWidth: CGFloat) -> (configuration: CGFloat, inspector: CGFloat) {
        var configurationWidth = configurationSidebarWidth
        var inspectorWidth = inspectorSidebarWidth
        let availableSidebarWidth = max(
            Self.configurationSidebarMinWidth + Self.inspectorSidebarMinWidth,
            totalWidth - (Self.resizeHandleWidth * 2) - Self.minimumCanvasColumnWidth
        )

        let currentSidebarWidth = configurationWidth + inspectorWidth
        if currentSidebarWidth > availableSidebarWidth {
            let overflow = currentSidebarWidth - availableSidebarWidth
            let configurationFlex = max(0, configurationWidth - Self.configurationSidebarMinWidth)
            let inspectorFlex = max(0, inspectorWidth - Self.inspectorSidebarMinWidth)
            let totalFlex = configurationFlex + inspectorFlex

            if totalFlex > 0 {
                configurationWidth -= overflow * (configurationFlex / totalFlex)
                inspectorWidth -= overflow * (inspectorFlex / totalFlex)
            }
        }

        configurationWidth = Self.clamp(configurationWidth, lower: Self.configurationSidebarMinWidth, upper: Self.configurationSidebarMaxWidth)
        inspectorWidth = Self.clamp(inspectorWidth, lower: Self.inspectorSidebarMinWidth, upper: Self.inspectorSidebarMaxWidth)

        return (configurationWidth, inspectorWidth)
    }

    private func resizeConfigurationSidebar(with value: DragGesture.Value, totalWidth: CGFloat) {
        let currentWidths = effectiveSidebarWidths(totalWidth: totalWidth)
        if configurationSidebarDragStart == nil {
            configurationSidebarDragStart = currentWidths.configuration
        }

        let maxWidth = max(
            Self.configurationSidebarMinWidth,
            min(
                Self.configurationSidebarMaxWidth,
                totalWidth - currentWidths.inspector - (Self.resizeHandleWidth * 2) - Self.minimumCanvasColumnWidth
            )
        )
        let nextWidth = (configurationSidebarDragStart ?? currentWidths.configuration) + value.translation.width
        configurationSidebarWidthValue = Double(Self.clamp(nextWidth, lower: Self.configurationSidebarMinWidth, upper: maxWidth))
    }

    private func resizeInspectorSidebar(with value: DragGesture.Value, totalWidth: CGFloat) {
        let currentWidths = effectiveSidebarWidths(totalWidth: totalWidth)
        if inspectorSidebarDragStart == nil {
            inspectorSidebarDragStart = currentWidths.inspector
        }

        let maxWidth = max(
            Self.inspectorSidebarMinWidth,
            min(
                Self.inspectorSidebarMaxWidth,
                totalWidth - currentWidths.configuration - (Self.resizeHandleWidth * 2) - Self.minimumCanvasColumnWidth
            )
        )
        let nextWidth = (inspectorSidebarDragStart ?? currentWidths.inspector) - value.translation.width
        inspectorSidebarWidthValue = Double(Self.clamp(nextWidth, lower: Self.inspectorSidebarMinWidth, upper: maxWidth))
    }

    private func setCanvasZoom(_ zoom: CGFloat) {
        canvasZoomValue = Double(Self.clamp(zoom, lower: Self.canvasZoomMin, upper: Self.canvasZoomMax))
    }

    private func setDeviceFrame(_ frame: GamepadEditorDeviceFrame) {
        deviceFrameRawValue = frame.rawValue
        noteCanvasLayoutSize(width: frame.screenRect.width, height: frame.screenRect.height)
    }

    private func noteCanvasLayoutSize(width: CGFloat, height: CGFloat) {
        let nextSize = CGSize(width: max(1, width), height: max(1, height))
        guard abs(currentCanvasLayoutSize.width - nextSize.width) > 0.5
            || abs(currentCanvasLayoutSize.height - nextSize.height) > 0.5
        else { return }
        currentCanvasLayoutSize = nextSize
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private static func displayName(for scheme: ColorScheme) -> String {
        scheme == .dark ? "Dark" : "Light"
    }

    private var selectedInspectorTitle: String {
        if selectedControlIsEditable, selectedControlIDs.count > 1 {
            return "\(selectedControlIDs.count) components selected"
        }

        return selectedControlIsEditable ? selectedControlTitle : "No component selected"
    }

    private var selectedControlTitle: String {
        switch selectedControlID {
        case .builtin(let button):
            return button.displayName
        case .custom(let id):
            guard let customButton = customButton(id: id)?.normalized else { return "Shape" }
            let fallback = customButton.isJoystick ? "Joystick" : visualLabel(for: customButton.mappedButton)
            return "\(customButton.isJoystick ? "Joystick" : "Shape"): \(customButton.visualLabel(fallback: fallback))"
        }
    }

    private var selectedShortcutButton: GameButton? {
        switch selectedControlID {
        case .builtin(let button):
            return button
        case .custom(let id):
            let customButton = customButton(id: id)?.normalized
            return customButton?.isJoystick == true ? nil : customButton?.mappedButton
        }
    }

    private var selectedProfile: GamepadConfigurationProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    private var observedExternalProfiles: [GamepadConfigurationProfile] {
        externalProfiles ?? []
    }

    private var editorBinding: Binding<GamepadCustomization> {
        Binding(
            get: { customization },
            set: { applyCustomization($0) }
        )
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<GamepadCustomization, Value>) -> Binding<Value> {
        Binding(
            get: { customization[keyPath: keyPath] },
            set: { newValue in
                update { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func defaultLabel(for button: GameButton) -> String {
        let providedLabel = defaultLabelProvider?(button).map(normalizedGamepadLabel) ?? ""
        return providedLabel.isEmpty ? GamepadCustomization.defaultVisualLabel(for: button) : providedLabel
    }

    private func visualLabel(for button: GameButton) -> String {
        customization.visualLabel(for: button, defaultLabel: defaultLabel(for: button))
    }

    private func labelBinding(for button: GameButton) -> Binding<String> {
        Binding(
            get: { customization.labelOverride(for: button) ?? "" },
            set: { newValue in
                update { $0.setLabel(newValue, for: button) }
            }
        )
    }

    private func customMappedButtonBinding(id: UUID) -> Binding<GameButton> {
        Binding(
            get: { customButton(id: id)?.mappedButton ?? .jump },
            set: { mappedButton in
                updateCustomButton(id: id) { $0.mappedButton = mappedButton }
            }
        )
    }

    private func customLabelBinding(id: UUID) -> Binding<String> {
        Binding(
            get: { customButton(id: id)?.label ?? "" },
            set: { label in
                updateCustomButton(id: id) { $0.label = normalizedGamepadLabel(label) }
            }
        )
    }

    private func joystickDirectionBinding(id: UUID, direction: GamepadJoystickDirection) -> Binding<GameButton> {
        Binding(
            get: { joystickMappingValue(id: id)[direction] },
            set: { button in
                updateCustomButton(id: id) { customButton in
                    var mapping = customButton.joystickMapping ?? .movement
                    mapping[direction] = button
                    customButton.joystickMapping = mapping
                    if direction == .up {
                        customButton.mappedButton = button
                    }
                }
            }
        )
    }

    private func joystickMappingValue(id: UUID) -> GamepadJoystickMapping {
        customButton(id: id)?.normalized.joystickMapping ?? .movement
    }

    private func visibleBinding(for identity: GamepadControlIdentity) -> Binding<Bool> {
        Binding(
            get: { !isComponentHidden(identity) },
            set: { isVisible in
                setComponentHidden(!isVisible, for: identity)
            }
        )
    }

    private func locationLockBinding(for identity: GamepadControlIdentity) -> Binding<Bool> {
        Binding(
            get: { isComponentLocationLocked(identity) },
            set: { isLocked in
                setComponentLocationLocked(isLocked, for: identity)
            }
        )
    }

    private func selectComponent(_ identity: GamepadControlIdentity) {
        selectedControlID = identity
        selectedControlIDs = [identity]
        isControlSelectionActive = true
    }

    private func selectPreferredComponent(for customization: GamepadCustomization) {
        guard let preferredSelection = preferredControlSelection(for: customization) else {
            selectedControlID = .builtin(.jump)
            isControlSelectionActive = false
            return
        }

        selectComponent(preferredSelection)
    }

    private func toggleComponentVisibility(_ identity: GamepadControlIdentity) {
        setComponentHidden(!isComponentHidden(identity), for: identity)
    }

    private func toggleComponentLock(_ identity: GamepadControlIdentity) {
        setComponentLocationLocked(!isComponentLocationLocked(identity), for: identity)
    }

    private func isComponentHidden(_ identity: GamepadControlIdentity) -> Bool {
        switch identity {
        case .builtin(let button):
            customization.buttonCustomization(for: button).isHidden
        case .custom(let id):
            customButton(id: id)?.layout.isHidden ?? false
        }
    }

    private func isComponentLocationLocked(_ identity: GamepadControlIdentity) -> Bool {
        switch identity {
        case .builtin(let button):
            customization.buttonCustomization(for: button).isLocationLocked
        case .custom(let id):
            customButton(id: id)?.layout.isLocationLocked ?? false
        }
    }

    private func setComponentHidden(_ isHidden: Bool, for identity: GamepadControlIdentity) {
        switch identity {
        case .builtin(let button):
            update {
                var buttonCustomization = $0.buttonCustomization(for: button)
                buttonCustomization.isHidden = isHidden
                $0.setButtonCustomization(buttonCustomization, for: button)
            }
        case .custom(let id):
            updateCustomButton(id: id) { $0.layout.isHidden = isHidden }
        }
    }

    private func setComponentLocationLocked(_ isLocked: Bool, for identity: GamepadControlIdentity) {
        switch identity {
        case .builtin(let button):
            update {
                var buttonCustomization = $0.buttonCustomization(for: button)
                buttonCustomization.isLocationLocked = isLocked
                $0.setButtonCustomization(buttonCustomization, for: button)
            }
        case .custom(let id):
            updateCustomButton(id: id) { $0.layout.isLocationLocked = isLocked }
        }
    }

    private func selectedLayoutCustomization(for identity: GamepadControlIdentity) -> GamepadButtonCustomization {
        switch identity {
        case .builtin(let button):
            return customization.buttonCustomization(for: button)
        case .custom(let id):
            return customButton(id: id)?.layout.normalized ?? .defaultValue
        }
    }

    private func updateLayoutCustomization(for identity: GamepadControlIdentity, mutate: (inout GamepadButtonCustomization) -> Void) {
        switch identity {
        case .builtin(let button):
            update {
                var buttonCustomization = $0.buttonCustomization(for: button)
                mutate(&buttonCustomization)
                $0.setButtonCustomization(buttonCustomization, for: button)
            }
        case .custom(let id):
            updateCustomButton(id: id) { mutate(&$0.layout) }
        }
    }

    private func accentStyleBinding(for identity: GamepadControlIdentity) -> Binding<GamepadAccentStyle> {
        Binding(
            get: { accentStyleValue(for: identity) },
            set: { style in
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.fillColor = nil
                    buttonCustomization.lightFillColor = nil
                    buttonCustomization.darkFillColor = nil
                    buttonCustomization.accentStyle = style == customization.accentStyle ? nil : style
                }
            }
        )
    }

    private func accentStyleValue(for identity: GamepadControlIdentity) -> GamepadAccentStyle {
        selectedLayoutCustomization(for: identity).accentStyle ?? customization.accentStyle
    }

    private func selectedFillColorValue(for identity: GamepadControlIdentity, scheme: ColorScheme) -> GamepadRGBAColor {
        if let fillColor = selectedLayoutCustomization(for: identity).fillColor(for: scheme) {
            return fillColor.normalized
        }
        let fallbackColor = accentStyleValue(for: identity).buttonFill(isPressed: false, scheme: scheme)
        return GamepadRGBAColor(color: fallbackColor, fallback: .defaultValue).normalized
    }

    private func fillColorValueBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<GamepadRGBAColor> {
        Binding(
            get: { selectedFillColorValue(for: identity, scheme: scheme) },
            set: { color in
                setFillColor(color.normalized, for: identity, scheme: scheme)
            }
        )
    }

    private func fillColorHexPlainBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { selectedFillColorValue(for: identity, scheme: scheme).hexString.replacingOccurrences(of: "#", with: "") },
            set: { hexString in
                fillColorHexBinding(for: identity, scheme: scheme).wrappedValue = hexString
            }
        )
    }

    private func toggleFillVisibility(for identity: GamepadControlIdentity, scheme: ColorScheme) {
        var color = selectedFillColorValue(for: identity, scheme: scheme)
        color.alpha = color.alpha > 0.001 ? 0 : 1
        setFillColor(color.normalized, for: identity, scheme: scheme)
    }

    private func fillColorPickerBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<Color> {
        Binding(
            get: { selectedFillColorValue(for: identity, scheme: scheme).swiftUIColor },
            set: { color in
                let fallback = selectedFillColorValue(for: identity, scheme: scheme)
                setFillColor(GamepadRGBAColor(color: color, fallback: fallback).normalized, for: identity, scheme: scheme)
            }
        )
    }

    private func fillColorHexBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { selectedFillColorValue(for: identity, scheme: scheme).hexString },
            set: { hexString in
                let currentColor = selectedFillColorValue(for: identity, scheme: scheme)
                guard let parsedColor = GamepadRGBAColor(hexString: hexString, alpha: currentColor.alpha) else { return }
                setFillColor(parsedColor.normalized, for: identity, scheme: scheme)
            }
        )
    }

    private func fillColorAlphaTextBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { "\(Int((selectedFillColorValue(for: identity, scheme: scheme).alpha * 100).rounded()))" },
            set: { alphaString in
                guard let alphaValue = Double(alphaString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                let normalizedAlpha = Self.clamp(CGFloat(alphaValue / 100), lower: 0, upper: 1)
                var color = selectedFillColorValue(for: identity, scheme: scheme)
                color.alpha = normalizedAlpha
                setFillColor(color.normalized, for: identity, scheme: scheme)
            }
        )
    }

    private func fillColorOpacityBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<Double> {
        Binding(
            get: { Double(selectedFillColorValue(for: identity, scheme: scheme).alpha) },
            set: { opacity in
                var color = selectedFillColorValue(for: identity, scheme: scheme)
                color.alpha = Self.clamp(CGFloat(opacity), lower: 0, upper: 1)
                setFillColor(color.normalized, for: identity, scheme: scheme)
            }
        )
    }

    private func setFillColor(_ color: GamepadRGBAColor, for identity: GamepadControlIdentity, scheme: ColorScheme) {
        updateLayoutCustomization(for: identity) { buttonCustomization in
            if let legacyFillColor = buttonCustomization.fillColor?.normalized {
                if buttonCustomization.lightFillColor == nil {
                    buttonCustomization.lightFillColor = legacyFillColor
                }
                if buttonCustomization.darkFillColor == nil {
                    buttonCustomization.darkFillColor = legacyFillColor
                }
            }
            buttonCustomization.fillColor = nil
            switch scheme {
            case .dark:
                buttonCustomization.darkFillColor = color.normalized
            default:
                buttonCustomization.lightFillColor = color.normalized
            }
        }
    }

    private func clearCustomFillColor(for identity: GamepadControlIdentity, scheme: ColorScheme) {
        updateLayoutCustomization(for: identity) { buttonCustomization in
            if let legacyFillColor = buttonCustomization.fillColor?.normalized {
                switch scheme {
                case .dark:
                    if buttonCustomization.lightFillColor == nil {
                        buttonCustomization.lightFillColor = legacyFillColor
                    }
                default:
                    if buttonCustomization.darkFillColor == nil {
                        buttonCustomization.darkFillColor = legacyFillColor
                    }
                }
            }
            buttonCustomization.fillColor = nil
            switch scheme {
            case .dark:
                buttonCustomization.darkFillColor = nil
            default:
                buttonCustomization.lightFillColor = nil
            }
        }
    }

    private func uniformCornerRadiusBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(uniformCornerRadiusValue(for: identity)) },
            set: { newValue in
                let clampedValue = GamepadButtonCustomization.clamp(
                    CGFloat(newValue),
                    lower: GamepadButtonCustomization.minimumCornerRadius,
                    upper: maximumCornerRadiusValue(for: identity)
                )
                let currentShape = shapeValue(for: identity)
                let defaultRadius = defaultCornerRadiusValue(for: identity)
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    if currentShape.usesDynamicEditableCornerRadiusDefault {
                        buttonCustomization.shape = currentShape
                    }
                    buttonCustomization.cornerRadius = nil
                    buttonCustomization.cornerRadii = abs(clampedValue - defaultRadius) < 0.001 ? nil : .uniform(clampedValue)
                }
            }
        )
    }

    private func uniformCornerRadiusValue(for identity: GamepadControlIdentity) -> CGFloat {
        cornerRadiiValue(for: identity).averageRadius
    }

    private func cornerRadiusBinding(for identity: GamepadControlIdentity, corner: GamepadCorner) -> Binding<Double> {
        Binding(
            get: { Double(cornerRadiiValue(for: identity)[corner]) },
            set: { newValue in
                var radii = cornerRadiiValue(for: identity)
                radii[corner] = GamepadButtonCustomization.clamp(
                    CGFloat(newValue),
                    lower: GamepadButtonCustomization.minimumCornerRadius,
                    upper: maximumCornerRadiusValue(for: identity)
                )
                let currentShape = shapeValue(for: identity)
                let defaultRadius = defaultCornerRadiusValue(for: identity)
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    if currentShape.usesDynamicEditableCornerRadiusDefault {
                        buttonCustomization.shape = currentShape
                    }
                    buttonCustomization.cornerRadius = nil
                    buttonCustomization.cornerRadii = radii.isUniform(equalTo: defaultRadius) ? nil : radii.normalized
                }
            }
        )
    }

    private func cornerRadiiValue(for identity: GamepadControlIdentity) -> GamepadCornerRadii {
        selectedLayoutCustomization(for: identity).resolvedCornerRadii(defaultRadius: defaultCornerRadiusValue(for: identity))
    }

    private func defaultCornerRadiusValue(for identity: GamepadControlIdentity) -> CGFloat {
        shapeValue(for: identity).defaultEditableCornerRadius(in: resolvedControl(for: identity)?.size)
    }

    private func maximumCornerRadiusValue(for identity: GamepadControlIdentity) -> CGFloat {
        guard let size = resolvedControl(for: identity)?.size else {
            return GamepadButtonCustomization.maximumCornerRadius
        }
        return min(GamepadButtonCustomization.maximumCornerRadius, max(GamepadButtonCustomization.minimumCornerRadius, min(size.width, size.height) / 2))
    }

    private func shadowStrengthBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(shadowStrengthValue(for: identity)) },
            set: { newValue in
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.shadowStrength = CGFloat(newValue)
                }
            }
        )
    }

    private func shadowStrengthValue(for identity: GamepadControlIdentity) -> CGFloat {
        selectedLayoutCustomization(for: identity).shadowStrength
    }

    private func rotationDegreesBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(rotationDegreesValue(for: identity)) },
            set: { newValue in
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.rotationDegrees = GamepadButtonCustomization.normalizedRotationDegrees(CGFloat(newValue))
                }
            }
        )
    }

    private func rotationDegreesValue(for identity: GamepadControlIdentity) -> CGFloat {
        selectedLayoutCustomization(for: identity).rotationDegrees
    }

    private func shapeBinding(for identity: GamepadControlIdentity) -> Binding<GamepadButtonShapeStyle> {
        Binding(
            get: { shapeValue(for: identity) },
            set: { shape in
                switch identity {
                case .builtin(let button):
                    update {
                        var buttonCustomization = $0.buttonCustomization(for: button)
                        let defaultShape = GamepadLayoutResolver.defaultShape(for: button)
                        buttonCustomization.shape = shape == defaultShape ? nil : shape
                        buttonCustomization.cornerRadius = nil
                        buttonCustomization.cornerRadii = nil
                        $0.setButtonCustomization(buttonCustomization, for: button)
                    }
                case .custom(let id):
                    updateCustomButton(id: id) {
                        $0.layout.shape = shape
                        $0.layout.cornerRadius = nil
                        $0.layout.cornerRadii = nil
                    }
                }
            }
        )
    }

    private func frameMetricBinding(_ metric: GamepadFrameMetric) -> Binding<Double> {
        Binding(
            get: { Double(frameMetricValue(metric, for: selectedControlID)) },
            set: { newValue in
                setFrameMetric(metric, value: CGFloat(newValue), for: selectedControlID)
            }
        )
    }

    private func frameMetricValue(_ metric: GamepadFrameMetric, for identity: GamepadControlIdentity) -> CGFloat {
        guard let frame = selectedControlFrame(for: identity) else { return 0 }
        switch metric {
        case .x: return frame.minX
        case .y: return frame.minY
        case .width: return frame.width
        case .height: return frame.height
        }
    }

    private func setFrameMetric(_ metric: GamepadFrameMetric, value: CGFloat, for identity: GamepadControlIdentity) {
        guard var frame = selectedControlFrame(for: identity), let control = resolvedControl(for: identity) else { return }

        switch metric {
        case .x:
            frame.origin.x = value
        case .y:
            frame.origin.y = value
        case .width:
            frame.size.width = value
        case .height:
            frame.size.height = value
        }

        setControlFrame(frame, for: control)
    }

    private func selectedControlFrame(for identity: GamepadControlIdentity) -> CGRect? {
        guard let control = resolvedControl(for: identity) else { return nil }
        return CGRect(
            x: control.center.x - control.size.width / 2,
            y: control.center.y - control.size.height / 2,
            width: control.size.width,
            height: control.size.height
        )
    }

    private func resolvedControl(for identity: GamepadControlIdentity) -> GamepadResolvedControl? {
        customization.resolvedControls(in: currentCanvasLayoutSize).first { $0.id == identity }
    }

    private func setControlFrame(_ frame: CGRect, for control: GamepadResolvedControl) {
        let layout = selectedLayoutCustomization(for: control.id)
        let baseSize = baseSize(for: control, layout: layout)
        let minWidth = baseSize.width * GamepadButtonCustomization.minimumScale
        let minHeight = baseSize.height * GamepadButtonCustomization.minimumScale
        let maxWidth = min(currentCanvasLayoutSize.width, baseSize.width * GamepadButtonCustomization.maximumScale)
        let maxHeight = min(currentCanvasLayoutSize.height, baseSize.height * GamepadButtonCustomization.maximumScale)
        var clampedWidth = Self.clamp(frame.width, lower: minWidth, upper: maxWidth)
        var clampedHeight = Self.clamp(frame.height, lower: minHeight, upper: maxHeight)

        let clampedX = Self.clamp(frame.minX, lower: 0, upper: max(0, currentCanvasLayoutSize.width - clampedWidth))
        let clampedY = Self.clamp(frame.minY, lower: 0, upper: max(0, currentCanvasLayoutSize.height - clampedHeight))
        let adjustedFrame = CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
        let center = CGPoint(x: adjustedFrame.midX, y: adjustedFrame.midY)

        updateLayoutCustomization(for: control.id) { buttonCustomization in
            buttonCustomization.widthScale = adjustedFrame.width / baseSize.width
            buttonCustomization.heightScale = adjustedFrame.height / baseSize.height
            buttonCustomization.centerX = center.x / max(currentCanvasLayoutSize.width, 1)
            buttonCustomization.centerY = center.y / max(currentCanvasLayoutSize.height, 1)
        }
    }

    private func baseSize(for control: GamepadResolvedControl, layout: GamepadButtonCustomization) -> CGSize {
        CGSize(
            width: max(1, control.size.width / max(layout.widthScale, 0.001)),
            height: max(1, control.size.height / max(layout.heightScale, 0.001))
        )
    }

    private func widthScaleBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        scaleBinding(for: identity, keyPath: \.widthScale)
    }

    private func heightScaleBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        scaleBinding(for: identity, keyPath: \.heightScale)
    }

    private func scaleBinding(
        for identity: GamepadControlIdentity,
        keyPath: WritableKeyPath<GamepadButtonCustomization, CGFloat>
    ) -> Binding<Double> {
        Binding(
            get: {
                switch identity {
                case .builtin(let button):
                    return Double(customization.buttonCustomization(for: button)[keyPath: keyPath])
                case .custom(let id):
                    return Double(customButton(id: id)?.layout[keyPath: keyPath] ?? 1.0)
                }
            },
            set: { newValue in
                setScaleValue(CGFloat(newValue), for: identity, keyPath: keyPath)
            }
        )
    }

    private func setScaleValue(
        _ value: CGFloat,
        for identity: GamepadControlIdentity,
        keyPath: WritableKeyPath<GamepadButtonCustomization, CGFloat>
    ) {
        guard var frame = selectedControlFrame(for: identity),
              let control = resolvedControl(for: identity)
        else { return }

        let layout = selectedLayoutCustomization(for: identity)
        let baseSize = baseSize(for: control, layout: layout)
        let clampedScale = GamepadButtonCustomization.clamp(
            value,
            lower: GamepadButtonCustomization.minimumScale,
            upper: GamepadButtonCustomization.maximumScale
        )

        if keyPath == \GamepadButtonCustomization.widthScale {
            let width = baseSize.width * clampedScale
            frame.origin.x = control.center.x - width / 2
            frame.size.width = width
        } else {
            let height = baseSize.height * clampedScale
            frame.origin.y = control.center.y - height / 2
            frame.size.height = height
        }

        setControlFrame(frame, for: control)
    }

    private func shapeValue(for identity: GamepadControlIdentity) -> GamepadButtonShapeStyle {
        switch identity {
        case .builtin(let button):
            let buttonCustomization = customization.buttonCustomization(for: button)
            return buttonCustomization.resolvedShape(defaultShape: GamepadLayoutResolver.defaultShape(for: button))
        case .custom(let id):
            guard let customButton = customButton(id: id) else { return .roundedRectangle }
            return customButton.layout.resolvedShape(defaultShape: GamepadLayoutResolver.defaultShape(for: customButton.mappedButton))
        }
    }

    private func widthScaleValue(for identity: GamepadControlIdentity) -> CGFloat {
        switch identity {
        case .builtin(let button): customization.buttonCustomization(for: button).widthScale
        case .custom(let id): customButton(id: id)?.layout.widthScale ?? 1.0
        }
    }

    private func heightScaleValue(for identity: GamepadControlIdentity) -> CGFloat {
        switch identity {
        case .builtin(let button): customization.buttonCustomization(for: button).heightScale
        case .custom(let id): customButton(id: id)?.layout.heightScale ?? 1.0
        }
    }

    private func resetSelectedControl() {
        switch selectedControlID {
        case .builtin(let button):
            update {
                $0.setButtonCustomization(.defaultValue, for: button)
                $0.setLabel("", for: button)
            }
        case .custom(let id):
            let isJoystick = customButton(id: id)?.normalized.isJoystick == true
            updateCustomButton(id: id) {
                if isJoystick {
                    $0.label = "Joystick"
                    $0.layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.5,
                        widthScale: 1.35,
                        heightScale: 1.35,
                        shape: .circle
                    )
                    $0.joystickMapping = $0.joystickMapping ?? .movement
                } else {
                    $0.label = "Shape"
                    $0.layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.5,
                        widthScale: 1.0,
                        heightScale: 1.0,
                        shape: .roundedRectangle
                    )
                }
            }
        }
    }

    private func customButton(id: UUID) -> GamepadCustomButton? {
        customization.customButtons.first { $0.id == id }
    }

    private func updateCustomButton(id: UUID, mutate: (inout GamepadCustomButton) -> Void) {
        update {
            guard let index = $0.customButtons.firstIndex(where: { $0.id == id }) else { return }
            mutate(&$0.customButtons[index])
        }
    }

    private func resetKeyLayout() {
        update { $0.resetButtonLayout() }
        selectComponent(.builtin(.jump))
    }

    private func setBuiltInControlsHidden(_ hidden: Bool) {
        update { next in
            for button in GameButton.builtInControls {
                var buttonCustomization = next.buttonCustomization(for: button)
                buttonCustomization.isHidden = hidden
                next.setButtonCustomization(buttonCustomization, for: button)
            }
        }
        if !hidden {
            selectComponent(.builtin(.jump))
        }
    }

    private func update(_ mutate: (inout GamepadCustomization) -> Void) {
        var next = customization
        mutate(&next)
        applyCustomization(next)
    }

    private func applyCustomization(
        _ nextCustomization: GamepadCustomization,
        selecting nextSelectedControlID: GamepadControlIdentity? = nil,
        selectionSet nextSelectedControlIDs: Set<GamepadControlIdentity>? = nil,
        undoActionName: String? = nil
    ) {
        let normalizedCustomization = nextCustomization.normalized
        let options = controlSelectionOptions(for: normalizedCustomization)
        let optionSet = Set(options)
        let resolvedPrimarySelection = nextSelectedControlID.map { validControlSelection($0, in: normalizedCustomization) }
        let selectionWasExplicit = nextSelectedControlID != nil || nextSelectedControlIDs != nil

        var resolvedSelectionIDs: Set<GamepadControlIdentity>
        if let nextSelectedControlIDs {
            resolvedSelectionIDs = Set(nextSelectedControlIDs.filter { optionSet.contains($0) })
            if let resolvedPrimarySelection {
                resolvedSelectionIDs.insert(resolvedPrimarySelection)
            }
        } else if let resolvedPrimarySelection {
            resolvedSelectionIDs = [resolvedPrimarySelection]
        } else {
            resolvedSelectionIDs = Set(selectedControlIDs.filter { optionSet.contains($0) })
        }

        let nextPrimaryControlID: GamepadControlIdentity
        if let resolvedPrimarySelection, resolvedSelectionIDs.contains(resolvedPrimarySelection) {
            nextPrimaryControlID = resolvedPrimarySelection
        } else if resolvedSelectionIDs.contains(selectedControlID) {
            nextPrimaryControlID = selectedControlID
        } else if let firstSelectedControlID = options.first(where: { resolvedSelectionIDs.contains($0) }) {
            nextPrimaryControlID = firstSelectedControlID
        } else {
            nextPrimaryControlID = preferredControlSelection(for: normalizedCustomization) ?? .builtin(.jump)
        }

        let nextIsControlSelectionActive = selectionWasExplicit
            ? !resolvedSelectionIDs.isEmpty
            : (isControlSelectionActive && !resolvedSelectionIDs.isEmpty)
        let shouldUpdateCustomization = customization.normalized != normalizedCustomization
        let shouldUpdateSelection = nextPrimaryControlID != selectedControlID
            || resolvedSelectionIDs != selectedControlIDs
            || nextIsControlSelectionActive != isControlSelectionActive
        guard shouldUpdateCustomization || shouldUpdateSelection else { return }

        if let undoActionName {
            registerUndoSnapshot(actionName: undoActionName)
        }

        customization = normalizedCustomization
        selectedControlID = nextPrimaryControlID
        selectedControlIDs = resolvedSelectionIDs
        isControlSelectionActive = nextIsControlSelectionActive
        syncSelectedProfile(with: normalizedCustomization)
    }

    private func registerUndoSnapshot(actionName: String) {
        guard let undoManager else { return }
        let snapshot = GamepadEditorUndoSnapshot(
            customization: customization.normalized,
            selectedControlID: selectedControlID,
            selectedControlIDs: selectedControlIDs,
            isControlSelectionActive: isControlSelectionActive
        )
        undoManager.registerUndo(withTarget: undoTarget) { _ in
            applyCustomization(
                snapshot.customization,
                selecting: snapshot.selectedControlID,
                selectionSet: snapshot.selectedControlIDs,
                undoActionName: actionName
            )
            isControlSelectionActive = snapshot.isControlSelectionActive && !selectedControlIDs.isEmpty
        }
        undoManager.setActionName(actionName)
    }

    private func createProfile() {
        commitSelectedProfileNameDraft()
        let profile = GamepadConfigurationProfile(
            name: "Setup \(profiles.count + 1)",
            customization: GamepadCustomization.blankCanvas
        )
        selectNewProfile(profile)
    }

    private func createProfile(from template: GamepadControllerTemplate) {
        commitSelectedProfileNameDraft()
        selectNewProfile(template.makeProfile())
    }

    private func selectNewProfile(_ profile: GamepadConfigurationProfile) {
        profiles.append(profile)
        selectedProfileID = profile.id
        selectedProfileNameDraft = profile.name
        isSelectedProfileExpanded = true
        selectPreferredComponent(for: profile.customization)
        applyCustomization(profile.customization)
        persistProfiles()
    }

    private func addJoystickControl() {
        let id = UUID()
        var next = customization
        next.addJoystick(id: id)
        placeCustomControl(id: id, in: &next)
        applyCustomization(next, selecting: .custom(id), undoActionName: "Add Joystick")
    }

    private func placeCustomControl(id: UUID, in next: inout GamepadCustomization) {
        let identity = GamepadControlIdentity.custom(id)
        let controls = next.resolvedControls(in: currentCanvasLayoutSize)
        guard let control = controls.first(where: { $0.id == identity }),
              let adjustedFrame = GamepadLayoutResolver.nonOverlappingFrame(
                for: control.frame,
                avoiding: controls.compactMap { $0.id == identity ? nil : $0.frame },
                in: currentCanvasLayoutSize
              ),
              let index = next.customButtons.firstIndex(where: { $0.id == id })
        else { return }

        next.customButtons[index].layout.centerX = adjustedFrame.midX / max(currentCanvasLayoutSize.width, 1)
        next.customButtons[index].layout.centerY = adjustedFrame.midY / max(currentCanvasLayoutSize.height, 1)
    }

    @discardableResult
    private func deleteSelectedControl() -> Bool {
        guard selectedControlIsEditable else { return false }

        switch selectedControlID {
        case .builtin(let button):
            return deleteBuiltInControl(button)
        case .custom(let id):
            return deleteCustomButton(id: id)
        }
    }

    @discardableResult
    private func deleteCustomButton(id: UUID) -> Bool {
        guard customization.customButtons.contains(where: { $0.id == id }) else { return false }
        var next = customization
        next.removeCustomButton(id: id)
        applyCustomization(next, selecting: .builtin(.jump), undoActionName: "Delete Key")
        return true
    }

    @discardableResult
    private func deleteBuiltInControl(_ button: GameButton) -> Bool {
        var buttonCustomization = customization.buttonCustomization(for: button)
        guard !buttonCustomization.isHidden else { return false }
        var next = customization
        buttonCustomization.isHidden = true
        next.setButtonCustomization(buttonCustomization, for: button)
        applyCustomization(next, selecting: .builtin(button), undoActionName: "Delete Key")
        return true
    }

    private func performUndo() -> Bool {
        guard let undoManager, undoManager.canUndo else { return false }
        undoManager.undo()
        return true
    }

    private func performRedo() -> Bool {
        guard let undoManager, undoManager.canRedo else { return false }
        undoManager.redo()
        return true
    }

    @discardableResult
    private func nudgeSelectedControls(_ direction: GamepadEditorNudgeDirection, isLargeStep: Bool) -> Bool {
        guard activeCanvasTool == .select,
              isControlSelectionActive,
              !selectedControlIDs.isEmpty
        else {
            return false
        }

        var next = customization
        let step: CGFloat = isLargeStep ? 10 : 1
        let didMove = next.nudgeControls(
            selectedControlIDs,
            by: direction.translation(step: step),
            in: currentCanvasLayoutSize
        )
        if didMove {
            applyCustomization(
                next,
                selecting: selectedControlID,
                selectionSet: selectedControlIDs,
                undoActionName: "Move Selection"
            )
        }
        return true
    }

    private func validControlSelection(_ selection: GamepadControlIdentity, in customization: GamepadCustomization) -> GamepadControlIdentity {
        let options = controlSelectionOptions(for: customization)
        return options.contains(selection) ? selection : preferredControlSelection(for: customization) ?? .builtin(.jump)
    }

    private func reconcileSelection(in customization: GamepadCustomization) {
        let options = controlSelectionOptions(for: customization)
        let optionSet = Set(options)
        let validSelectionIDs = Set(selectedControlIDs.filter { optionSet.contains($0) })
        selectedControlIDs = validSelectionIDs
        if !validSelectionIDs.contains(selectedControlID) {
            selectedControlID = options.first(where: { validSelectionIDs.contains($0) })
                ?? preferredControlSelection(for: customization)
                ?? .builtin(.jump)
        }
        isControlSelectionActive = isControlSelectionActive && !validSelectionIDs.isEmpty
    }

    private func beginRenamingSelectedProfile() {
        guard let selectedProfile else { return }
        beginRenamingProfile(selectedProfile)
    }

    private func beginRenamingProfile(_ profile: GamepadConfigurationProfile) {
        if profile.id != selectedProfileID {
            selectProfile(profile)
        } else {
            isSelectedProfileExpanded = true
        }

        DispatchQueue.main.async {
            isProfileNameFieldFocused = true
        }
    }

    private func syncSelectedProfileNameDraft() {
        selectedProfileNameDraft = selectedProfile?.name ?? "Untitled"
    }

    private func commitSelectedProfileNameDraft() {
        guard let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else {
            syncSelectedProfileNameDraft()
            return
        }

        let trimmedName = selectedProfileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextName = trimmedName.isEmpty ? "Untitled" : trimmedName
        selectedProfileNameDraft = nextName

        guard profiles[index].name != nextName else { return }
        profiles[index].name = nextName
        profiles[index].updatedAt = Date.currentMilliseconds
        persistProfiles()
    }

    private func duplicateProfile() {
        commitSelectedProfileNameDraft()
        guard let selectedProfile else { return }
        duplicateProfile(selectedProfile)
    }

    private func duplicateProfile(_ profile: GamepadConfigurationProfile) {
        let isDuplicatingCurrentSelection = profile.id == selectedProfileID
        if isDuplicatingCurrentSelection {
            commitSelectedProfileNameDraft()
        }

        let sourceProfile = profiles.first { $0.id == profile.id } ?? profile
        let sourceName = sourceProfile.normalized.name
        let sourceCustomization = isDuplicatingCurrentSelection ? customization.normalized : sourceProfile.customization.normalized
        let duplicate = GamepadConfigurationProfile(
            name: "\(sourceName) Copy",
            customization: sourceCustomization
        )
        profiles.append(duplicate)
        selectedProfileID = duplicate.id
        selectedProfileNameDraft = duplicate.name
        isSelectedProfileExpanded = true
        if !isDuplicatingCurrentSelection {
            selectPreferredComponent(for: duplicate.customization)
        }
        applyCustomization(duplicate.customization)
        persistProfiles()
    }

    private func deleteSelectedProfile() {
        guard let selectedProfile else { return }
        deleteProfile(selectedProfile)
    }

    private func deleteProfile(_ profile: GamepadConfigurationProfile) {
        commitSelectedProfileNameDraft()
        guard profiles.count > 1,
              let removedIndex = profiles.firstIndex(where: { $0.id == profile.id })
        else { return }

        let wasSelectedProfile = profile.id == selectedProfileID
        let wasDefaultProfile = profile.id == defaultProfileID
        profiles.remove(at: removedIndex)

        if wasSelectedProfile {
            let nextProfile = profiles[min(removedIndex, profiles.count - 1)]
            selectedProfileID = nextProfile.id
            selectedProfileNameDraft = nextProfile.name
            isSelectedProfileExpanded = true
            selectPreferredComponent(for: nextProfile.customization)
            if wasDefaultProfile {
                defaultProfileID = nextProfile.id
            }
            applyCustomization(nextProfile.customization)
        } else if wasDefaultProfile {
            defaultProfileID = selectedProfileID
        }

        persistProfiles()
    }

    private func selectProfile(_ profile: GamepadConfigurationProfile) {
        commitSelectedProfileNameDraft()
        let nextProfile = profiles.first { $0.id == profile.id } ?? profile
        selectedProfileID = nextProfile.id
        selectedProfileNameDraft = nextProfile.name
        isSelectedProfileExpanded = true
        selectPreferredComponent(for: nextProfile.customization)
        applyCustomization(nextProfile.customization)
        persistProfiles()
    }

    private func toggleProfileRow(_ profile: GamepadConfigurationProfile, isSelected: Bool) {
        if isSelected {
            isSelectedProfileExpanded.toggle()
        } else {
            selectProfile(profile)
        }
    }

    private func profileRowAccessibilityHint(isSelected: Bool, isExpanded: Bool) -> String {
        if isSelected {
            return isExpanded ? "Closes the keypad setup details." : "Opens the keypad setup details."
        }

        return "Selects and opens this keypad setup."
    }

    private func setSelectedProfileAsDefault() {
        commitSelectedProfileNameDraft()
        defaultProfileID = selectedProfileID
        persistProfiles()
    }

    private func resetActiveConfiguration() {
        applyCustomization(.defaultValue)
        selectComponent(.builtin(.jump))
        onReset?()
    }

    private func syncSelectedProfile(with newCustomization: GamepadCustomization) {
        guard let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        let normalizedCustomization = newCustomization.normalized
        guard profiles[index].customization != normalizedCustomization else { return }

        profiles[index].customization = normalizedCustomization
        profiles[index].updatedAt = Date.currentMilliseconds
        persistProfiles()
    }

    private func syncExternalProfileState() {
        guard let externalProfiles,
              let externalSelectedProfileID,
              let externalDefaultProfileID
        else { return }

        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: externalProfiles,
            activeProfileID: externalSelectedProfileID,
            defaultProfileID: externalDefaultProfileID,
            fallbackCustomization: customization
        )
        guard profiles != state.profiles
            || selectedProfileID != state.activeProfileID
            || defaultProfileID != state.defaultProfileID
        else { return }

        let didChangeSelectedProfile = selectedProfileID != state.activeProfileID

        profiles = state.profiles
        selectedProfileID = state.activeProfileID
        defaultProfileID = state.defaultProfileID
        if didChangeSelectedProfile {
            isSelectedProfileExpanded = true
        }
        if didChangeSelectedProfile || !isProfileNameFieldFocused {
            syncSelectedProfileNameDraft()
        }
        if didChangeSelectedProfile {
            selectPreferredComponent(for: customization)
        } else {
            reconcileSelection(in: customization)
        }
    }

    private func persistProfiles() {
        let state = GamepadConfigurationProfilePersistence.normalizedState(
            profiles: profiles,
            activeProfileID: selectedProfileID,
            defaultProfileID: defaultProfileID,
            fallbackCustomization: customization
        )
        profiles = state.profiles
        selectedProfileID = state.activeProfileID
        defaultProfileID = state.defaultProfileID
        if !isProfileNameFieldFocused {
            syncSelectedProfileNameDraft()
        }
        GamepadConfigurationProfilePersistence.save(
            state.profiles,
            activeProfileID: state.activeProfileID,
            defaultProfileID: state.defaultProfileID
        )
        onProfilesChanged?(state.profiles, state.activeProfileID, state.defaultProfileID)
    }
}

private struct GamepadColorValueField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String

    var placeholder: String
    var suffix: String? = nil
    var width: CGFloat? = nil

    var body: some View {
        HStack(spacing: Geist.Spacing.s1) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .geistTypography(.label14Mono)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
#if os(iOS)
                .textInputAutocapitalization(.characters)
#endif

            if let suffix {
                Text(suffix)
                    .geistTypography(.label14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .frame(width: width)
        .frame(height: Geist.Spacing.s10)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
    }
}

private struct GamepadColorPlane: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var color: GamepadRGBAColor
    @Binding var hue: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let hsba = GamepadHSBAColor(color)
            let effectiveHue = effectiveHue(for: hsba)
            let markerX = GamepadHSBAColor.clamp(hsba.saturation) * proxy.size.width
            let markerY = (1 - GamepadHSBAColor.clamp(hsba.brightness)) * proxy.size.height

            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        .white,
                        Color(hue: Double(effectiveHue), saturation: 1, brightness: 1)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                LinearGradient(
                    colors: [.clear, .black],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color.clear)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .overlay(Circle().stroke(Color.black.opacity(0.18), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                    .frame(width: 24, height: 24)
                    .position(x: markerX, y: markerY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateColor(at: value.location, size: proxy.size)
                    }
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(Geist.color(.grayAlpha300, scheme: colorScheme), lineWidth: 1)
            )
        }
    }

    private func effectiveHue(for hsba: GamepadHSBAColor) -> CGFloat {
        hsba.saturation > 0.001 ? hsba.hue : hue
    }

    private func updateColor(at location: CGPoint, size: CGSize) {
        var hsba = GamepadHSBAColor(color)
        hsba.hue = effectiveHue(for: hsba)
        hsba.saturation = GamepadHSBAColor.clamp(location.x / max(size.width, 1))
        hsba.brightness = 1 - GamepadHSBAColor.clamp(location.y / max(size.height, 1))
        hue = hsba.hue
        color = hsba.rgba
    }
}

private struct GamepadHueSlider: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var color: GamepadRGBAColor
    @Binding var hue: CGFloat

    private let handleSize: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let hsba = GamepadHSBAColor(color)
            let effectiveHue = hsba.saturation > 0.001 ? hsba.hue : hue
            let x = handlePosition(for: effectiveHue, width: proxy.size.width)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: proxy.size.height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: stride(from: 0.0, through: 1.0, by: 1.0 / 6.0).map {
                                Color(hue: $0, saturation: 1, brightness: 1)
                            },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: proxy.size.height / 2, style: .continuous)
                            .stroke(Geist.color(.grayAlpha300, scheme: colorScheme), lineWidth: 1)
                    )

                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Geist.color(.grayAlpha500, scheme: colorScheme), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                    .frame(width: handleSize, height: handleSize)
                    .position(x: x, y: proxy.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateHue(at: value.location, width: proxy.size.width)
                    }
            )
        }
    }

    private func handlePosition(for hue: CGFloat, width: CGFloat) -> CGFloat {
        let radius = handleSize / 2
        return GamepadHSBAColor.clamp(hue) * max(width - handleSize, 1) + radius
    }

    private func updateHue(at location: CGPoint, width: CGFloat) {
        let radius = handleSize / 2
        let nextHue = GamepadHSBAColor.clamp((location.x - radius) / max(width - handleSize, 1))
        hue = nextHue

        var hsba = GamepadHSBAColor(color)
        hsba.hue = nextHue
        color = hsba.rgba
    }
}

private struct GamepadAlphaSlider: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var color: GamepadRGBAColor

    private let handleSize: CGFloat = 24

    var body: some View {
        GeometryReader { proxy in
            let normalizedColor = color.normalized
            let opaqueColor = GamepadRGBAColor(red: normalizedColor.red, green: normalizedColor.green, blue: normalizedColor.blue, alpha: 1)
            let transparentColor = GamepadRGBAColor(red: normalizedColor.red, green: normalizedColor.green, blue: normalizedColor.blue, alpha: 0)
            let x = handlePosition(for: normalizedColor.alpha, width: proxy.size.width)

            ZStack(alignment: .leading) {
                GamepadAlphaCheckerboard()
                    .clipShape(RoundedRectangle(cornerRadius: proxy.size.height / 2, style: .continuous))

                RoundedRectangle(cornerRadius: proxy.size.height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [transparentColor.swiftUIColor, opaqueColor.swiftUIColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: proxy.size.height / 2, style: .continuous)
                            .stroke(Geist.color(.grayAlpha300, scheme: colorScheme), lineWidth: 1)
                    )

                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Geist.color(.grayAlpha500, scheme: colorScheme), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
                    .frame(width: handleSize, height: handleSize)
                    .position(x: x, y: proxy.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateAlpha(at: value.location, width: proxy.size.width)
                    }
            )
        }
    }

    private func handlePosition(for alpha: CGFloat, width: CGFloat) -> CGFloat {
        let radius = handleSize / 2
        return GamepadHSBAColor.clamp(alpha) * max(width - handleSize, 1) + radius
    }

    private func updateAlpha(at location: CGPoint, width: CGFloat) {
        let radius = handleSize / 2
        var nextColor = color.normalized
        nextColor.alpha = GamepadHSBAColor.clamp((location.x - radius) / max(width - handleSize, 1))
        color = nextColor
    }
}

private struct GamepadAlphaCheckerboard: View {
    var body: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 8
            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))

            for row in 0...rows {
                for column in 0...columns {
                    let isDark = (row + column).isMultiple(of: 2)
                    let rect = CGRect(
                        x: CGFloat(column) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(isDark ? Color.gray.opacity(0.28) : Color.white.opacity(0.72)))
                }
            }
        }
    }
}

private struct GamepadHSBAColor {
    var hue: CGFloat
    var saturation: CGFloat
    var brightness: CGFloat
    var alpha: CGFloat

    init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        self.hue = Self.clamp(hue)
        self.saturation = Self.clamp(saturation)
        self.brightness = Self.clamp(brightness)
        self.alpha = Self.clamp(alpha)
    }

    init(_ color: GamepadRGBAColor) {
        let normalized = color.normalized
        let red = Double(normalized.red)
        let green = Double(normalized.green)
        let blue = Double(normalized.blue)
        let maxValue = max(red, green, blue)
        let minValue = min(red, green, blue)
        let delta = maxValue - minValue

        brightness = CGFloat(maxValue)
        saturation = maxValue <= 0 ? 0 : CGFloat(delta / maxValue)
        alpha = normalized.alpha

        if delta <= 0.000_001 {
            hue = 0
        } else if maxValue == red {
            hue = CGFloat(((green - blue) / delta).truncatingRemainder(dividingBy: 6) / 6)
        } else if maxValue == green {
            hue = CGFloat(((blue - red) / delta + 2) / 6)
        } else {
            hue = CGFloat(((red - green) / delta + 4) / 6)
        }

        if hue < 0 { hue += 1 }
    }

    var rgba: GamepadRGBAColor {
        let normalizedHue = Double(Self.clamp(hue))
        let normalizedSaturation = Double(Self.clamp(saturation))
        let normalizedBrightness = Double(Self.clamp(brightness))
        let chroma = normalizedBrightness * normalizedSaturation
        let huePrime = normalizedHue * 6
        let x = chroma * (1 - abs(huePrime.truncatingRemainder(dividingBy: 2) - 1))
        let m = normalizedBrightness - chroma

        let components: (Double, Double, Double)
        switch Int(floor(huePrime)) % 6 {
        case 0:
            components = (chroma, x, 0)
        case 1:
            components = (x, chroma, 0)
        case 2:
            components = (0, chroma, x)
        case 3:
            components = (0, x, chroma)
        case 4:
            components = (x, 0, chroma)
        default:
            components = (chroma, 0, x)
        }

        return GamepadRGBAColor(
            red: CGFloat(components.0 + m),
            green: CGFloat(components.1 + m),
            blue: CGFloat(components.2 + m),
            alpha: Self.clamp(alpha)
        ).normalized
    }

    static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

private struct GamepadMetricField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var value: Double
    @State private var draftText: String
    @FocusState private var isFocused: Bool

    private let title: String
    private let unit: String

    init(title: String, value: Binding<Double>, unit: String) {
        self.title = title
        self._value = value
        self.unit = unit
        self._draftText = State(initialValue: Self.formatted(value.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
            Text(title)
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            HStack(spacing: Geist.Spacing.s1) {
                TextField(title, text: $draftText)
                    .focused($isFocused)
                    .geistTypography(.label12Mono)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                Text(unit)
                    .geistTypography(.label12Mono)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }
            .geistInput(size: .small)
        }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            draftText = Self.formatted(newValue)
        }
        .onChange(of: draftText) { _, newValue in
            guard isFocused, let parsedValue = Self.parsed(newValue) else { return }
            value = parsedValue
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                draftText = Self.formatted(value)
            } else {
                commitOrResetDraft()
            }
        }
        .onSubmit {
            commitOrResetDraft()
        }
    }

    private func commitOrResetDraft() {
        if let parsedValue = Self.parsed(draftText) {
            value = parsedValue
        }
        draftText = Self.formatted(value)
    }

    private static func parsed(_ text: String) -> Double? {
        let sanitized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
        guard !sanitized.isEmpty else { return nil }
        return Double(sanitized)
    }

    private static func formatted(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        return String(Int(value.rounded()))
    }
}

private struct GamepadInspectorMetricField: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var value: Double
    @State private var draftText: String
    @FocusState private var isFocused: Bool

    private let title: String
    private let unit: String?
    private let maxFractionDigits: Int
    private let accessibilityLabel: String?

    init(
        title: String,
        value: Binding<Double>,
        unit: String? = nil,
        maxFractionDigits: Int = 2,
        accessibilityLabel: String? = nil
    ) {
        self.title = title
        self._value = value
        self.unit = unit
        self.maxFractionDigits = max(0, maxFractionDigits)
        self.accessibilityLabel = accessibilityLabel
        self._draftText = State(initialValue: Self.formatted(value.wrappedValue, maxFractionDigits: max(0, maxFractionDigits)))
    }

    var body: some View {
        HStack(spacing: Geist.Spacing.s2) {
            Text(title)
                .geistTypography(.label14)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(minWidth: 14, alignment: .leading)

            TextField(title, text: $draftText)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .geistTypography(.label14Mono)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
#if os(iOS)
                .keyboardType(.numbersAndPunctuation)
#endif

            if let unit {
                Text(unit)
                    .geistTypography(.label14Mono)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .frame(height: Geist.Spacing.s10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(isFocused ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha300, scheme: colorScheme), lineWidth: isFocused ? 1.25 : 1)
        )
        .accessibilityLabel(Text(accessibilityLabel ?? title))
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            draftText = Self.formatted(newValue, maxFractionDigits: maxFractionDigits)
        }
        .onChange(of: draftText) { _, newValue in
            guard isFocused, let parsedValue = Self.parsed(newValue) else { return }
            value = parsedValue
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                draftText = Self.formatted(value, maxFractionDigits: maxFractionDigits)
            } else {
                commitOrResetDraft()
            }
        }
        .onSubmit {
            commitOrResetDraft()
        }
    }

    private func commitOrResetDraft() {
        if let parsedValue = Self.parsed(draftText) {
            value = parsedValue
        }
        draftText = Self.formatted(value, maxFractionDigits: maxFractionDigits)
    }

    private static func parsed(_ text: String) -> Double? {
        let sanitized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "px", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "pt", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "°", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty, sanitized != "-", sanitized != ".", sanitized != "-." else { return nil }
        return Double(sanitized)
    }

    private static func formatted(_ value: Double, maxFractionDigits: Int) -> String {
        guard value.isFinite else { return "0" }
        let fractionDigits = max(0, maxFractionDigits)
        if fractionDigits == 0 {
            let rounded = Int(value.rounded())
            return rounded == 0 ? "0" : String(rounded)
        }

        let multiplier = pow(10, Double(fractionDigits))
        let roundedValue = (value * multiplier).rounded() / multiplier
        var text = String(format: "%.\(fractionDigits)f", roundedValue)
        while text.contains(".") && text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text == "-0" ? "0" : text
    }
}

private struct GamepadEditorResizeHandle: View {
    @Environment(\.colorScheme) private var colorScheme

    let accessibilityLabel: String
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)

            Rectangle()
                .fill(Geist.color(.grayAlpha400, scheme: colorScheme))
                .frame(width: 1)

            Capsule()
                .fill(Geist.color(.grayAlpha600, scheme: colorScheme))
                .frame(width: 3, height: 34)
                .opacity(0.55)
        }
        .frame(width: 10)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged(onDragChanged)
                .onEnded { _ in onDragEnded() }
        )
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text("Drag horizontally to resize"))
    }
}

private enum GamepadEditorNudgeDirection {
    case left
    case right
    case up
    case down

    func translation(step: CGFloat) -> CGSize {
        switch self {
        case .left:
            CGSize(width: -step, height: 0)
        case .right:
            CGSize(width: step, height: 0)
        case .up:
            CGSize(width: 0, height: -step)
        case .down:
            CGSize(width: 0, height: step)
        }
    }
}

private struct GamepadEditorKeyboardShortcutBridge: NSViewRepresentable {
    var onDelete: () -> Bool
    var onUndo: () -> Bool
    var onRedo: () -> Bool
    var onNudge: (GamepadEditorNudgeDirection, Bool) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onDelete: onDelete, onUndo: onUndo, onRedo: onRedo, onNudge: onNudge)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.view = view
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.view = nsView
        context.coordinator.onDelete = onDelete
        context.coordinator.onUndo = onUndo
        context.coordinator.onRedo = onRedo
        context.coordinator.onNudge = onNudge
        context.coordinator.installMonitor()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.uninstallMonitor()
    }

    final class Coordinator: NSObject {
        var onDelete: () -> Bool
        var onUndo: () -> Bool
        var onRedo: () -> Bool
        var onNudge: (GamepadEditorNudgeDirection, Bool) -> Bool
        weak var view: NSView?
        private var monitor: Any?

        init(
            onDelete: @escaping () -> Bool,
            onUndo: @escaping () -> Bool,
            onRedo: @escaping () -> Bool,
            onNudge: @escaping (GamepadEditorNudgeDirection, Bool) -> Bool
        ) {
            self.onDelete = onDelete
            self.onUndo = onUndo
            self.onRedo = onRedo
            self.onNudge = onNudge
        }

        deinit {
            uninstallMonitor()
        }

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func uninstallMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard let view,
                  let window = view.window,
                  let eventWindow = event.window,
                  eventWindow === window,
                  window.isKeyWindow,
                  !Self.isTextEditing(in: window)
            else { return event }

            if Self.isDeleteEvent(event) {
                return onDelete() ? nil : event
            }

            if Self.isRedoEvent(event) {
                return onRedo() ? nil : event
            }

            if Self.isUndoEvent(event) {
                return onUndo() ? nil : event
            }

            if let nudgeDirection = Self.nudgeDirection(for: event) {
                return onNudge(nudgeDirection, Self.isShiftOnlyModifierEvent(event)) ? nil : event
            }

            return event
        }

        private static func isDeleteEvent(_ event: NSEvent) -> Bool {
            guard !event.isARepeat else { return false }
            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return false }
            return event.keyCode == 51 || event.keyCode == 117
        }

        private static func nudgeDirection(for event: NSEvent) -> GamepadEditorNudgeDirection? {
            guard isNudgeModifierEvent(event) else { return nil }
            switch event.keyCode {
            case 123:
                return .left
            case 124:
                return .right
            case 125:
                return .down
            case 126:
                return .up
            default:
                return nil
            }
        }

        private static func isNudgeModifierEvent(_ event: NSEvent) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return !flags.contains(.command)
                && !flags.contains(.option)
                && !flags.contains(.control)
        }

        private static func isShiftOnlyModifierEvent(_ event: NSEvent) -> Bool {
            event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift)
        }

        private static func isUndoEvent(_ event: NSEvent) -> Bool {
            guard commandZFlagsMatch(event, requiresShift: false) else { return false }
            return event.charactersIgnoringModifiers?.lowercased() == "z"
        }

        private static func isRedoEvent(_ event: NSEvent) -> Bool {
            guard commandZFlagsMatch(event, requiresShift: true) else { return false }
            return event.charactersIgnoringModifiers?.lowercased() == "z"
        }

        private static func commandZFlagsMatch(_ event: NSEvent, requiresShift: Bool) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command),
                  !flags.contains(.option),
                  !flags.contains(.control)
            else { return false }
            return flags.contains(.shift) == requiresShift
        }

        private static func isTextEditing(in window: NSWindow) -> Bool {
            var responder = window.firstResponder
            while let currentResponder = responder {
                if let textView = currentResponder as? NSTextView, textView.isEditable {
                    return true
                }

                if let control = currentResponder as? NSControl,
                   control.currentEditor() != nil {
                    return true
                }

                responder = currentResponder.nextResponder
            }
            return false
        }
    }
}

private struct GamepadModifierKeyMonitor: NSViewRepresentable {
    @Binding var isOptionPressed: Bool
    @Binding var isShiftPressed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isOptionPressed: $isOptionPressed, isShiftPressed: $isShiftPressed)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.start()
        context.coordinator.publish(NSEvent.modifierFlags)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.updateBindings(isOptionPressed: $isOptionPressed, isShiftPressed: $isShiftPressed)
        context.coordinator.publish(NSEvent.modifierFlags)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator {
        private var isOptionPressed: Binding<Bool>
        private var isShiftPressed: Binding<Bool>
        private var localMonitor: Any?

        init(isOptionPressed: Binding<Bool>, isShiftPressed: Binding<Bool>) {
            self.isOptionPressed = isOptionPressed
            self.isShiftPressed = isShiftPressed
        }

        deinit {
            stop()
        }

        func updateBindings(isOptionPressed: Binding<Bool>, isShiftPressed: Binding<Bool>) {
            self.isOptionPressed = isOptionPressed
            self.isShiftPressed = isShiftPressed
        }

        func start() {
            guard localMonitor == nil else { return }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                self?.publish(event.modifierFlags)
                return event
            }
        }

        func stop() {
            if let localMonitor {
                NSEvent.removeMonitor(localMonitor)
                self.localMonitor = nil
            }
        }

        func publish(_ flags: NSEvent.ModifierFlags) {
            let deviceFlags = flags.intersection(.deviceIndependentFlagsMask)
            let nextOptionPressed = deviceFlags.contains(.option)
            let nextShiftPressed = deviceFlags.contains(.shift)

            let assign = { [weak self] in
                guard let self else { return }
                if self.isOptionPressed.wrappedValue != nextOptionPressed {
                    self.isOptionPressed.wrappedValue = nextOptionPressed
                }
                if self.isShiftPressed.wrappedValue != nextShiftPressed {
                    self.isShiftPressed.wrappedValue = nextShiftPressed
                }
            }

            if Thread.isMainThread {
                assign()
            } else {
                DispatchQueue.main.async(execute: assign)
            }
        }
    }
}

private enum GamepadMeasurementTarget {
    case frame(CGRect)
    case canvasEdges
}

private struct GamepadMeasurementOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    let selectedFrame: CGRect
    let target: GamepadMeasurementTarget
    let canvasSize: CGSize
    let displayScale: CGFloat

    private var safeDisplayScale: CGFloat {
        max(displayScale, 0.001)
    }

    private var displaySize: CGSize {
        CGSize(width: canvasSize.width * safeDisplayScale, height: canvasSize.height * safeDisplayScale)
    }

    private var targetFrame: CGRect? {
        switch target {
        case .frame(let frame):
            return frame
        case .canvasEdges:
            return CGRect(origin: .zero, size: canvasSize)
        }
    }

    private var measurementSegments: [GamepadMeasurementSegment] {
        let segments: [GamepadMeasurementSegment]
        switch target {
        case .frame(let hoveredFrame):
            segments = GamepadMeasurementGeometry.segments(
                selectedFrame: selectedFrame,
                hoveredFrame: hoveredFrame,
                canvasSize: canvasSize
            )
        case .canvasEdges:
            segments = GamepadMeasurementGeometry.canvasEdgeSegments(
                selectedFrame: selectedFrame,
                canvasSize: canvasSize
            )
        }
        return segments.map { $0.scaled(by: safeDisplayScale) }
    }

    var body: some View {
        let selectedDisplayFrame = scaledRect(selectedFrame)
        let targetDisplayFrame = targetFrame.map(scaledRect)
        let segments = measurementSegments
        let measurementColor = Geist.color(.red700, scheme: colorScheme)

        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                var guidePath = Path()
                var path = Path()
                path.addRect(selectedDisplayFrame.insetBy(dx: -0.5, dy: -0.5))
                if let targetDisplayFrame {
                    path.addRect(targetDisplayFrame.insetBy(dx: -0.5, dy: -0.5))
                }

                for segment in segments {
                    appendGuideLines(for: segment, to: &guidePath)
                    append(segment, to: &path)
                }

                context.stroke(
                    guidePath,
                    with: .color(measurementColor.opacity(0.72)),
                    style: StrokeStyle(lineWidth: 1, lineCap: .square, lineJoin: .miter, dash: [4, 3])
                )
                context.stroke(
                    path,
                    with: .color(measurementColor),
                    style: StrokeStyle(lineWidth: 1.25, lineCap: .square, lineJoin: .miter)
                )
            }

            ForEach(segments) { segment in
                measurementLabel(segment)
                    .position(labelPosition(for: segment))
            }

            if case .frame(let frame) = target {
                GamepadDimensionBadge(
                    frame: frame,
                    canvasSize: canvasSize,
                    displayScale: displayScale,
                    tone: .measurement
                )
            }
        }
    }

    private func measurementLabel(_ segment: GamepadMeasurementSegment) -> some View {
        Text(segment.labelText)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Geist.color(.red700, scheme: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Geist.color(.red800, scheme: colorScheme), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12), radius: 2, y: 1)
    }

    private func appendGuideLines(for segment: GamepadMeasurementSegment, to path: inout Path) {
        for guideLine in segment.guideLines {
            path.move(to: guideLine.start)
            path.addLine(to: guideLine.end)
        }
    }

    private func append(_ segment: GamepadMeasurementSegment, to path: inout Path) {
        let capLength: CGFloat = 5
        path.move(to: segment.start)
        path.addLine(to: segment.end)

        switch segment.orientation {
        case .horizontal:
            path.move(to: CGPoint(x: segment.start.x, y: segment.start.y - capLength))
            path.addLine(to: CGPoint(x: segment.start.x, y: segment.start.y + capLength))
            path.move(to: CGPoint(x: segment.end.x, y: segment.end.y - capLength))
            path.addLine(to: CGPoint(x: segment.end.x, y: segment.end.y + capLength))
        case .vertical:
            path.move(to: CGPoint(x: segment.start.x - capLength, y: segment.start.y))
            path.addLine(to: CGPoint(x: segment.start.x + capLength, y: segment.start.y))
            path.move(to: CGPoint(x: segment.end.x - capLength, y: segment.end.y))
            path.addLine(to: CGPoint(x: segment.end.x + capLength, y: segment.end.y))
        }
    }

    private func labelPosition(for segment: GamepadMeasurementSegment) -> CGPoint {
        let midpoint = CGPoint(
            x: (segment.start.x + segment.end.x) / 2,
            y: (segment.start.y + segment.end.y) / 2
        )
        return CGPoint(
            x: Self.clamp(midpoint.x, lower: 18, upper: max(18, displaySize.width - 18)),
            y: Self.clamp(midpoint.y, lower: 10, upper: max(10, displaySize.height - 10))
        )
    }

    private func scaledRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX * safeDisplayScale,
            y: rect.minY * safeDisplayScale,
            width: rect.width * safeDisplayScale,
            height: rect.height * safeDisplayScale
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

private enum GamepadDimensionBadgeTone {
    case selection
    case measurement

    func background(scheme: ColorScheme) -> Color {
        switch self {
        case .selection: Geist.color(.blue700, scheme: scheme)
        case .measurement: Geist.color(.red700, scheme: scheme)
        }
    }

    func stroke(scheme: ColorScheme) -> Color {
        switch self {
        case .selection: Geist.color(.blue800, scheme: scheme)
        case .measurement: Geist.color(.red800, scheme: scheme)
        }
    }
}

private struct GamepadDimensionBadge: View {
    @Environment(\.colorScheme) private var colorScheme

    let frame: CGRect
    let canvasSize: CGSize
    let displayScale: CGFloat
    let tone: GamepadDimensionBadgeTone

    private var safeDisplayScale: CGFloat {
        max(displayScale, 0.001)
    }

    private var displaySize: CGSize {
        CGSize(width: canvasSize.width * safeDisplayScale, height: canvasSize.height * safeDisplayScale)
    }

    var body: some View {
        Text(dimensionText)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(tone.background(scheme: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(tone.stroke(scheme: colorScheme), lineWidth: 0.75)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.12), radius: 2, y: 1)
            .position(badgePosition)
    }

    private var dimensionText: String {
        "\(Self.formatted(frame.width)) × \(Self.formatted(frame.height))"
    }

    private var badgePosition: CGPoint {
        let displayFrame = scaledRect(frame.standardized)
        let halfApproximateBadgeWidth = max(28, CGFloat(dimensionText.count) * 3.8)
        let x = Self.clamp(
            displayFrame.midX,
            lower: halfApproximateBadgeWidth,
            upper: max(halfApproximateBadgeWidth, displaySize.width - halfApproximateBadgeWidth)
        )
        let belowY = displayFrame.maxY + 18
        let y: CGFloat
        if belowY <= displaySize.height - 12 {
            y = belowY
        } else {
            y = Self.clamp(displayFrame.minY - 18, lower: 12, upper: max(12, displaySize.height - 12))
        }
        return CGPoint(x: x, y: y)
    }

    private func scaledRect(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX * safeDisplayScale,
            y: rect.minY * safeDisplayScale,
            width: rect.width * safeDisplayScale,
            height: rect.height * safeDisplayScale
        )
    }

    private static func formatted(_ value: CGFloat) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", Double(value))
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}

private enum GamepadMeasurementOrientation {
    case horizontal
    case vertical
}

private struct GamepadMeasurementGuideLine: Equatable {
    let start: CGPoint
    let end: CGPoint

    func scaled(by scale: CGFloat) -> GamepadMeasurementGuideLine {
        GamepadMeasurementGuideLine(
            start: CGPoint(x: start.x * scale, y: start.y * scale),
            end: CGPoint(x: end.x * scale, y: end.y * scale)
        )
    }
}

private struct GamepadMeasurementSegment: Identifiable {
    let id: String
    let orientation: GamepadMeasurementOrientation
    let start: CGPoint
    let end: CGPoint
    let distance: CGFloat
    let guideLines: [GamepadMeasurementGuideLine]

    init(
        id: String,
        orientation: GamepadMeasurementOrientation,
        start: CGPoint,
        end: CGPoint,
        distance: CGFloat,
        guideLines: [GamepadMeasurementGuideLine] = []
    ) {
        self.id = id
        self.orientation = orientation
        self.start = start
        self.end = end
        self.distance = distance
        self.guideLines = guideLines
    }

    var labelText: String {
        Self.formatted(distance)
    }

    func scaled(by scale: CGFloat) -> GamepadMeasurementSegment {
        GamepadMeasurementSegment(
            id: id,
            orientation: orientation,
            start: CGPoint(x: start.x * scale, y: start.y * scale),
            end: CGPoint(x: end.x * scale, y: end.y * scale),
            distance: distance,
            guideLines: guideLines.map { $0.scaled(by: scale) }
        )
    }

    private static func formatted(_ value: CGFloat) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", Double(value))
    }
}

private enum GamepadMeasurementGeometry {
    private enum ExteriorSide: Equatable {
        case minimum
        case maximum
    }

    private struct ExteriorPlacement {
        let coordinate: CGFloat
        let side: ExteriorSide
    }

    private static let exteriorOffset: CGFloat = 14
    private static let exteriorInset: CGFloat = 8
    private static let minimumGuideLength: CGFloat = 0.5

    static func segments(selectedFrame: CGRect, hoveredFrame: CGRect, canvasSize: CGSize) -> [GamepadMeasurementSegment] {
        let selected = selectedFrame.standardized
        let hovered = hoveredFrame.standardized
        guard selected.width > 0,
              selected.height > 0,
              hovered.width > 0,
              hovered.height > 0,
              canvasSize.width > 1,
              canvasSize.height > 1
        else {
            return []
        }

        var segments: [GamepadMeasurementSegment] = []
        if let verticalGap = verticalGapSegment(selected: selected, hovered: hovered, canvasSize: canvasSize) {
            segments.append(verticalGap)
        } else {
            segments.append(contentsOf: verticalEdgeOffsetSegments(selected: selected, hovered: hovered, canvasSize: canvasSize))
        }

        if let horizontalGap = horizontalGapSegment(selected: selected, hovered: hovered, canvasSize: canvasSize) {
            segments.append(horizontalGap)
        } else {
            segments.append(contentsOf: horizontalEdgeOffsetSegments(selected: selected, hovered: hovered, canvasSize: canvasSize))
        }

        return segments.filter { $0.distance >= 0.5 }
    }

    static func canvasEdgeSegments(selectedFrame: CGRect, canvasSize: CGSize) -> [GamepadMeasurementSegment] {
        let selected = selectedFrame.standardized
        guard selected.width > 0,
              selected.height > 0,
              canvasSize.width > 1,
              canvasSize.height > 1
        else {
            return []
        }

        let selectedMinX = clamped(selected.minX, lower: 0, upper: canvasSize.width)
        let selectedMaxX = clamped(selected.maxX, lower: 0, upper: canvasSize.width)
        let selectedMinY = clamped(selected.minY, lower: 0, upper: canvasSize.height)
        let selectedMaxY = clamped(selected.maxY, lower: 0, upper: canvasSize.height)
        let measurementX = clamped(selected.midX, lower: 6, upper: canvasSize.width - 6)
        let measurementY = clamped(selected.midY, lower: 6, upper: canvasSize.height - 6)

        return [
            GamepadMeasurementSegment(
                id: "canvas-leading-edge",
                orientation: .horizontal,
                start: CGPoint(x: 0, y: measurementY),
                end: CGPoint(x: selectedMinX, y: measurementY),
                distance: selectedMinX
            ),
            GamepadMeasurementSegment(
                id: "canvas-trailing-edge",
                orientation: .horizontal,
                start: CGPoint(x: selectedMaxX, y: measurementY),
                end: CGPoint(x: canvasSize.width, y: measurementY),
                distance: canvasSize.width - selectedMaxX
            ),
            GamepadMeasurementSegment(
                id: "canvas-top-edge",
                orientation: .vertical,
                start: CGPoint(x: measurementX, y: 0),
                end: CGPoint(x: measurementX, y: selectedMinY),
                distance: selectedMinY
            ),
            GamepadMeasurementSegment(
                id: "canvas-bottom-edge",
                orientation: .vertical,
                start: CGPoint(x: measurementX, y: selectedMaxY),
                end: CGPoint(x: measurementX, y: canvasSize.height),
                distance: canvasSize.height - selectedMaxY
            )
        ]
        .filter { $0.distance >= 0.5 }
    }

    private static func verticalGapSegment(selected: CGRect, hovered: CGRect, canvasSize: CGSize) -> GamepadMeasurementSegment? {
        let upper: CGRect
        let lower: CGRect
        let id: String

        if selected.maxY <= hovered.minY {
            upper = selected
            lower = hovered
            id = "vertical-gap-selected-above"
        } else if hovered.maxY <= selected.minY {
            upper = hovered
            lower = selected
            id = "vertical-gap-hovered-above"
        } else {
            return nil
        }

        let placement = exteriorPlacement(
            minimumEdge: min(selected.minX, hovered.minX),
            maximumEdge: max(selected.maxX, hovered.maxX),
            canvasExtent: canvasSize.width
        )
        let guideLines = [
            horizontalGuideLine(from: upper, side: placement.side, y: upper.maxY, toX: placement.coordinate),
            horizontalGuideLine(from: lower, side: placement.side, y: lower.minY, toX: placement.coordinate)
        ].compactMap { $0 }

        return GamepadMeasurementSegment(
            id: id,
            orientation: .vertical,
            start: CGPoint(x: placement.coordinate, y: upper.maxY),
            end: CGPoint(x: placement.coordinate, y: lower.minY),
            distance: lower.minY - upper.maxY,
            guideLines: guideLines
        )
    }

    private static func horizontalGapSegment(selected: CGRect, hovered: CGRect, canvasSize: CGSize) -> GamepadMeasurementSegment? {
        let left: CGRect
        let right: CGRect
        let id: String

        if selected.maxX <= hovered.minX {
            left = selected
            right = hovered
            id = "horizontal-gap-selected-left"
        } else if hovered.maxX <= selected.minX {
            left = hovered
            right = selected
            id = "horizontal-gap-hovered-left"
        } else {
            return nil
        }

        let placement = exteriorPlacement(
            minimumEdge: min(selected.minY, hovered.minY),
            maximumEdge: max(selected.maxY, hovered.maxY),
            canvasExtent: canvasSize.height
        )
        let guideLines = [
            verticalGuideLine(from: left, side: placement.side, x: left.maxX, toY: placement.coordinate),
            verticalGuideLine(from: right, side: placement.side, x: right.minX, toY: placement.coordinate)
        ].compactMap { $0 }

        return GamepadMeasurementSegment(
            id: id,
            orientation: .horizontal,
            start: CGPoint(x: left.maxX, y: placement.coordinate),
            end: CGPoint(x: right.minX, y: placement.coordinate),
            distance: right.minX - left.maxX,
            guideLines: guideLines
        )
    }

    private static func horizontalEdgeOffsetSegments(selected: CGRect, hovered: CGRect, canvasSize: CGSize) -> [GamepadMeasurementSegment] {
        let leadingPlacement = exteriorPlacement(
            minimumEdge: min(selected.minY, hovered.minY),
            maximumEdge: max(selected.maxY, hovered.maxY),
            canvasExtent: canvasSize.height,
            preferredSide: .minimum
        )
        let trailingPlacement = exteriorPlacement(
            minimumEdge: min(selected.minY, hovered.minY),
            maximumEdge: max(selected.maxY, hovered.maxY),
            canvasExtent: canvasSize.height,
            preferredSide: .maximum
        )
        var segments: [GamepadMeasurementSegment] = []

        if abs(selected.minX - hovered.minX) >= 0.5 {
            let y = leadingPlacement.coordinate
            let guideLines = [
                verticalGuideLine(from: selected, side: leadingPlacement.side, x: selected.minX, toY: y),
                verticalGuideLine(from: hovered, side: leadingPlacement.side, x: hovered.minX, toY: y)
            ].compactMap { $0 }

            segments.append(
                GamepadMeasurementSegment(
                    id: "horizontal-leading-offset",
                    orientation: .horizontal,
                    start: CGPoint(x: selected.minX, y: y),
                    end: CGPoint(x: hovered.minX, y: y),
                    distance: abs(selected.minX - hovered.minX),
                    guideLines: guideLines
                )
            )
        }

        if abs(selected.maxX - hovered.maxX) >= 0.5 {
            let y = trailingPlacement.coordinate
            let guideLines = [
                verticalGuideLine(from: selected, side: trailingPlacement.side, x: selected.maxX, toY: y),
                verticalGuideLine(from: hovered, side: trailingPlacement.side, x: hovered.maxX, toY: y)
            ].compactMap { $0 }

            segments.append(
                GamepadMeasurementSegment(
                    id: "horizontal-trailing-offset",
                    orientation: .horizontal,
                    start: CGPoint(x: selected.maxX, y: y),
                    end: CGPoint(x: hovered.maxX, y: y),
                    distance: abs(selected.maxX - hovered.maxX),
                    guideLines: guideLines
                )
            )
        }

        return segments
    }

    private static func verticalEdgeOffsetSegments(selected: CGRect, hovered: CGRect, canvasSize: CGSize) -> [GamepadMeasurementSegment] {
        let topPlacement = exteriorPlacement(
            minimumEdge: min(selected.minX, hovered.minX),
            maximumEdge: max(selected.maxX, hovered.maxX),
            canvasExtent: canvasSize.width,
            preferredSide: .minimum
        )
        let bottomPlacement = exteriorPlacement(
            minimumEdge: min(selected.minX, hovered.minX),
            maximumEdge: max(selected.maxX, hovered.maxX),
            canvasExtent: canvasSize.width,
            preferredSide: .maximum
        )
        var segments: [GamepadMeasurementSegment] = []

        if abs(selected.minY - hovered.minY) >= 0.5 {
            let x = topPlacement.coordinate
            let guideLines = [
                horizontalGuideLine(from: selected, side: topPlacement.side, y: selected.minY, toX: x),
                horizontalGuideLine(from: hovered, side: topPlacement.side, y: hovered.minY, toX: x)
            ].compactMap { $0 }

            segments.append(
                GamepadMeasurementSegment(
                    id: "vertical-top-offset",
                    orientation: .vertical,
                    start: CGPoint(x: x, y: selected.minY),
                    end: CGPoint(x: x, y: hovered.minY),
                    distance: abs(selected.minY - hovered.minY),
                    guideLines: guideLines
                )
            )
        }

        if abs(selected.maxY - hovered.maxY) >= 0.5 {
            let x = bottomPlacement.coordinate
            let guideLines = [
                horizontalGuideLine(from: selected, side: bottomPlacement.side, y: selected.maxY, toX: x),
                horizontalGuideLine(from: hovered, side: bottomPlacement.side, y: hovered.maxY, toX: x)
            ].compactMap { $0 }

            segments.append(
                GamepadMeasurementSegment(
                    id: "vertical-bottom-offset",
                    orientation: .vertical,
                    start: CGPoint(x: x, y: selected.maxY),
                    end: CGPoint(x: x, y: hovered.maxY),
                    distance: abs(selected.maxY - hovered.maxY),
                    guideLines: guideLines
                )
            )
        }

        return segments
    }

    private static func exteriorPlacement(
        minimumEdge: CGFloat,
        maximumEdge: CGFloat,
        canvasExtent: CGFloat,
        preferredSide: ExteriorSide? = nil
    ) -> ExteriorPlacement {
        let minimumSpace = max(0, minimumEdge - exteriorInset)
        let maximumSpace = max(0, canvasExtent - exteriorInset - maximumEdge)
        let side: ExteriorSide

        switch preferredSide {
        case .some(.minimum) where minimumSpace >= exteriorOffset || minimumSpace >= maximumSpace:
            side = .minimum
        case .some(.maximum) where maximumSpace >= exteriorOffset || maximumSpace >= minimumSpace:
            side = .maximum
        default:
            side = maximumSpace > minimumSpace ? .maximum : .minimum
        }

        let rawCoordinate = side == .minimum ? minimumEdge - exteriorOffset : maximumEdge + exteriorOffset
        return ExteriorPlacement(
            coordinate: clamped(rawCoordinate, lower: exteriorInset, upper: canvasExtent - exteriorInset),
            side: side
        )
    }

    private static func horizontalGuideLine(from frame: CGRect, side: ExteriorSide, y: CGFloat, toX x: CGFloat) -> GamepadMeasurementGuideLine? {
        let edgeX = side == .minimum ? frame.minX : frame.maxX
        return guideLine(from: CGPoint(x: edgeX, y: y), to: CGPoint(x: x, y: y))
    }

    private static func verticalGuideLine(from frame: CGRect, side: ExteriorSide, x: CGFloat, toY y: CGFloat) -> GamepadMeasurementGuideLine? {
        let edgeY = side == .minimum ? frame.minY : frame.maxY
        return guideLine(from: CGPoint(x: x, y: edgeY), to: CGPoint(x: x, y: y))
    }

    private static func guideLine(from start: CGPoint, to end: CGPoint) -> GamepadMeasurementGuideLine? {
        guard abs(start.x - end.x) + abs(start.y - end.y) >= minimumGuideLength else { return nil }
        return GamepadMeasurementGuideLine(start: start, end: end)
    }

    private static func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}

private enum GamepadAlignmentLineOrientation: Equatable {
    case vertical
    case horizontal
}

private struct GamepadAlignmentLine: Identifiable, Equatable {
    let id: String
    let orientation: GamepadAlignmentLineOrientation
    let coordinate: CGFloat
    let targetFrame: CGRect
}

private struct GamepadAlignmentGuide: Equatable {
    let selectedFrame: CGRect
    let primaryTargetFrame: CGRect
    let lines: [GamepadAlignmentLine]
}

private struct GamepadAlignmentGuideOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    let guide: GamepadAlignmentGuide
    let canvasSize: CGSize
    let displayScale: CGFloat

    private var safeDisplayScale: CGFloat {
        max(displayScale, 0.001)
    }

    var body: some View {
        let guideColor = Geist.color(.red700, scheme: colorScheme)

        Canvas { context, _ in
            var path = Path()
            for line in guide.lines {
                append(line, to: &path)
            }

            context.stroke(
                path,
                with: .color(guideColor),
                style: StrokeStyle(lineWidth: 1.25, lineCap: .square, lineJoin: .miter)
            )
        }
    }

    private func append(_ line: GamepadAlignmentLine, to path: inout Path) {
        let margin: CGFloat = 8

        switch line.orientation {
        case .vertical:
            let x = line.coordinate * safeDisplayScale
            let startY = Self.clamp(
                min(guide.selectedFrame.minY, line.targetFrame.minY) - margin,
                lower: 0,
                upper: canvasSize.height
            ) * safeDisplayScale
            let endY = Self.clamp(
                max(guide.selectedFrame.maxY, line.targetFrame.maxY) + margin,
                lower: 0,
                upper: canvasSize.height
            ) * safeDisplayScale
            path.move(to: CGPoint(x: x, y: startY))
            path.addLine(to: CGPoint(x: x, y: endY))

        case .horizontal:
            let y = line.coordinate * safeDisplayScale
            let startX = Self.clamp(
                min(guide.selectedFrame.minX, line.targetFrame.minX) - margin,
                lower: 0,
                upper: canvasSize.width
            ) * safeDisplayScale
            let endX = Self.clamp(
                max(guide.selectedFrame.maxX, line.targetFrame.maxX) + margin,
                lower: 0,
                upper: canvasSize.width
            ) * safeDisplayScale
            path.move(to: CGPoint(x: startX, y: y))
            path.addLine(to: CGPoint(x: endX, y: y))
        }
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }
}

private struct GamepadAlignmentSnapResult {
    let frame: CGRect
    let guide: GamepadAlignmentGuide?
}

private enum GamepadAlignmentSnapSolver {
    private static let snapToleranceInScreenPoints: CGFloat = 7
    private static let alignmentEpsilon: CGFloat = 0.5

    static func snappedFrame(
        for frame: CGRect,
        targetFrames: [CGRect],
        canvasSize: CGSize,
        displayScale: CGFloat
    ) -> GamepadAlignmentSnapResult {
        let initialFrame = clampedFrame(frame.standardized, canvasSize: canvasSize)
        guard !targetFrames.isEmpty else {
            return GamepadAlignmentSnapResult(frame: initialFrame, guide: nil)
        }

        let tolerance = max(2, snapToleranceInScreenPoints / max(displayScale, 0.001))
        let xCandidate = bestCandidate(for: initialFrame, axis: .x, targetFrames: targetFrames, tolerance: tolerance)
        let yCandidate = bestCandidate(for: initialFrame, axis: .y, targetFrames: targetFrames, tolerance: tolerance)

        var snappedFrame = initialFrame
        if let xCandidate {
            snappedFrame = snappedFrame.offsetBy(dx: xCandidate.delta, dy: 0)
        }
        if let yCandidate {
            snappedFrame = snappedFrame.offsetBy(dx: 0, dy: yCandidate.delta)
        }
        snappedFrame = clampedFrame(snappedFrame, canvasSize: canvasSize)

        return GamepadAlignmentSnapResult(
            frame: snappedFrame,
            guide: guide(for: snappedFrame, xCandidate: xCandidate, yCandidate: yCandidate)
        )
    }

    static func framesAreEquivalent(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = alignmentEpsilon) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }

    private static func bestCandidate(
        for frame: CGRect,
        axis: GamepadAlignmentSnapAxis,
        targetFrames: [CGRect],
        tolerance: CGFloat
    ) -> GamepadAlignmentSnapCandidate? {
        var bestCandidate: GamepadAlignmentSnapCandidate?

        for movingAnchor in GamepadAlignmentAnchor.allCases {
            let movingValue = movingAnchor.value(in: frame, axis: axis)
            for targetFrame in targetFrames {
                for targetAnchor in GamepadAlignmentAnchor.allCases {
                    let targetValue = targetAnchor.value(in: targetFrame, axis: axis)
                    let delta = targetValue - movingValue
                    guard abs(delta) <= tolerance else { continue }

                    let candidate = GamepadAlignmentSnapCandidate(
                        axis: axis,
                        movingAnchor: movingAnchor,
                        targetAnchor: targetAnchor,
                        targetFrame: targetFrame,
                        targetCoordinate: targetValue,
                        delta: delta
                    )
                    if candidate.isBetter(than: bestCandidate) {
                        bestCandidate = candidate
                    }
                }
            }
        }

        return bestCandidate
    }

    private static func guide(
        for selectedFrame: CGRect,
        xCandidate: GamepadAlignmentSnapCandidate?,
        yCandidate: GamepadAlignmentSnapCandidate?
    ) -> GamepadAlignmentGuide? {
        let candidates = [xCandidate, yCandidate]
            .compactMap { $0 }
            .sorted { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.001 {
                    return lhs.score < rhs.score
                }
                return lhs.axis.sortOrder < rhs.axis.sortOrder
            }
        var lines: [GamepadAlignmentLine] = []

        for candidate in candidates {
            let alignedValue = candidate.movingAnchor.value(in: selectedFrame, axis: candidate.axis)
            guard abs(alignedValue - candidate.targetCoordinate) <= alignmentEpsilon else { continue }
            lines.append(
                GamepadAlignmentLine(
                    id: "\(candidate.axis.id)-\(candidate.movingAnchor.id)-\(candidate.targetAnchor.id)-\(lines.count)",
                    orientation: candidate.axis.lineOrientation,
                    coordinate: candidate.targetCoordinate,
                    targetFrame: candidate.targetFrame
                )
            )
        }

        guard let primaryTargetFrame = lines.first?.targetFrame else { return nil }
        return GamepadAlignmentGuide(
            selectedFrame: selectedFrame,
            primaryTargetFrame: primaryTargetFrame,
            lines: lines
        )
    }

    private static func clampedFrame(_ frame: CGRect, canvasSize: CGSize) -> CGRect {
        CGRect(
            x: clampedOrigin(frame.minX, length: frame.width, canvasLength: canvasSize.width),
            y: clampedOrigin(frame.minY, length: frame.height, canvasLength: canvasSize.height),
            width: frame.width,
            height: frame.height
        )
    }

    private static func clampedOrigin(_ origin: CGFloat, length: CGFloat, canvasLength: CGFloat) -> CGFloat {
        guard length < canvasLength else { return (canvasLength - length) / 2 }
        return min(max(origin, 0), max(0, canvasLength - length))
    }
}

private enum GamepadAlignmentSnapAxis {
    case x
    case y

    var id: String {
        switch self {
        case .x: "x"
        case .y: "y"
        }
    }

    var sortOrder: Int {
        switch self {
        case .x: 0
        case .y: 1
        }
    }

    var lineOrientation: GamepadAlignmentLineOrientation {
        switch self {
        case .x: .vertical
        case .y: .horizontal
        }
    }
}

private enum GamepadAlignmentAnchor: CaseIterable {
    case minimum
    case center
    case maximum

    var id: String {
        switch self {
        case .minimum: "minimum"
        case .center: "center"
        case .maximum: "maximum"
        }
    }

    func value(in rect: CGRect, axis: GamepadAlignmentSnapAxis) -> CGFloat {
        switch (self, axis) {
        case (.minimum, .x): rect.minX
        case (.center, .x): rect.midX
        case (.maximum, .x): rect.maxX
        case (.minimum, .y): rect.minY
        case (.center, .y): rect.midY
        case (.maximum, .y): rect.maxY
        }
    }
}

private struct GamepadAlignmentSnapCandidate {
    let axis: GamepadAlignmentSnapAxis
    let movingAnchor: GamepadAlignmentAnchor
    let targetAnchor: GamepadAlignmentAnchor
    let targetFrame: CGRect
    let targetCoordinate: CGFloat
    let delta: CGFloat

    var score: CGFloat {
        abs(delta) + (movingAnchor == targetAnchor ? 0 : 0.15)
    }

    func isBetter(than other: GamepadAlignmentSnapCandidate?) -> Bool {
        guard let other else { return true }
        if abs(score - other.score) > 0.001 {
            return score < other.score
        }
        if movingAnchor == targetAnchor, other.movingAnchor != other.targetAnchor {
            return true
        }
        if axis.sortOrder != other.axis.sortOrder {
            return axis.sortOrder < other.axis.sortOrder
        }
        return false
    }
}

private struct GamepadLayoutDesigner: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var customization: GamepadCustomization
    @Binding var selectedControlID: GamepadControlIdentity
    @Binding var selectedControlIDs: Set<GamepadControlIdentity>
    @Binding var isControlSelectionActive: Bool
    @Binding var activeTool: GamepadCanvasTool
    var layoutSize: CGSize?
    var displayScale: CGFloat = 1
    var defaultLabelProvider: ((GameButton) -> String?)? = nil
    var onBeginUndoableChange: (String) -> Void = { _ in }
    @State private var activeDrag: GamepadControlDragState?
    @State private var activeResize: GamepadControlResizeState?
    @State private var activeGroupResize: GamepadGroupResizeState?
    @State private var activeRotation: GamepadControlRotationState?
    @State private var activeRadiusDrag: GamepadControlRadiusDragState?
    @State private var activeDraw: GamepadShapeDrawState?
    @State private var hoveredControlID: GamepadControlIdentity?
    @State private var isHoveringCanvasBackground = false
    @State private var activeAlignmentGuide: GamepadAlignmentGuide?
    @State private var isOptionKeyPressed = false
    @State private var isShiftKeyPressed = false

    private static let dragActivationDistance: CGFloat = 4
    private static let minimumDrawnButtonSize: CGFloat = 44
    private static let defaultDrawnButtonSize = CGSize(width: 76, height: 76)

    var body: some View {
        GeometryReader { proxy in
            let resolvedLayoutSize = resolvedLayoutSize(for: proxy.size)
            let resolvedDisplayScale = max(displayScale, 0.001)
            let controls = customization.resolvedControls(
                in: resolvedLayoutSize,
                defaultLabelProvider: defaultLabelProvider
            )
            let selectedDesignerControls = currentSelectedControls(in: controls)
            let isMultiSelection = selectedDesignerControls.count > 1

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                    .fill(Geist.color(.gray100, scheme: colorScheme))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard activeTool == .select else { return }
                        clearSelection()
                    }
                layoutGrid

                ForEach(controls) { control in
                    let isSelected = isControlSelectionActive && selectedControlIDs.contains(control.id)

                    GamepadDesignerButton(
                        control: control,
                        customization: customization,
                        isSelected: isSelected,
                        showsSelectionHandles: !isMultiSelection,
                        displayScale: resolvedDisplayScale,
                        onResizeChanged: { corner, value in
                            selectOnly(control.id)
                            guard !control.isLocationLocked else { return }
                            updateResize(corner, value: value, control: control, canvasSize: resolvedLayoutSize, displayScale: resolvedDisplayScale)
                        },
                        onResizeEnded: {
                            activeResize = nil
                        },
                        onRadiusChanged: { value in
                            selectOnly(control.id)
                            updateRadius(value, control: control, displayScale: resolvedDisplayScale)
                        },
                        onRadiusEnded: {
                            activeRadiusDrag = nil
                        }
                    )
                    .rotationEffect(.degrees(control.rotationDegrees))
                    .scaleEffect(resolvedDisplayScale)
                    .position(
                        x: control.center.x * resolvedDisplayScale,
                        y: control.center.y * resolvedDisplayScale
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
                            .onChanged { value in
                                let interactionSelectionIDs: Set<GamepadControlIdentity>
                                if activeDrag?.identity != control.id {
                                    interactionSelectionIDs = selectForPointerDown(control.id, additive: isShiftKeyPressed)
                                    activeAlignmentGuide = nil
                                } else {
                                    interactionSelectionIDs = selectedControlIDs
                                }

                                guard !control.isLocationLocked else {
                                    activeAlignmentGuide = nil
                                    return
                                }

                                if activeDrag?.identity != control.id {
                                    beginDrag(for: control.id, selectionIDs: interactionSelectionIDs, controls: controls)
                                }

                                guard Self.isExplicitDrag(value.translation), var dragState = activeDrag else {
                                    activeAlignmentGuide = nil
                                    return
                                }

                                dragState.didMove = true
                                activeDrag = dragState

                                let translation = CGSize(
                                    width: value.translation.width / resolvedDisplayScale,
                                    height: value.translation.height / resolvedDisplayScale
                                )

                                if dragState.snapshots.count <= 1,
                                   let snapshot = dragState.snapshots.first {
                                    let proposedCenter = CGPoint(
                                        x: snapshot.startCenter.x + translation.width,
                                        y: snapshot.startCenter.y + translation.height
                                    )
                                    updatePosition(
                                        proposedCenter,
                                        control: control,
                                        controls: controls,
                                        canvasSize: resolvedLayoutSize,
                                        displayScale: resolvedDisplayScale
                                    )
                                } else {
                                    updateGroupPosition(
                                        translation,
                                        dragState: dragState,
                                        controls: controls,
                                        canvasSize: resolvedLayoutSize,
                                        displayScale: resolvedDisplayScale
                                    )
                                }
                            }
                            .onEnded { _ in
                                activeDrag = nil
                                activeAlignmentGuide = nil
                            }
                    )
                    .allowsHitTesting(activeTool == .select)
                }

                if activeTool == .select,
                   isControlSelectionActive,
                   let selectionFrame = measurementSelectionFrame(for: selectedDesignerControls) {
                    GamepadDimensionBadge(
                        frame: selectionFrame,
                        canvasSize: resolvedLayoutSize,
                        displayScale: resolvedDisplayScale,
                        tone: .selection
                    )
                    .frame(
                        width: resolvedLayoutSize.width * resolvedDisplayScale,
                        height: resolvedLayoutSize.height * resolvedDisplayScale,
                        alignment: .topLeading
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                if activeTool == .select,
                   !shouldShowMeasurementOverlay,
                   let hoveredControlID,
                   let hoveredControl = controls.first(where: { $0.id == hoveredControlID }) {
                    GamepadDimensionBadge(
                        frame: hoveredControl.frame,
                        canvasSize: resolvedLayoutSize,
                        displayScale: resolvedDisplayScale,
                        tone: .selection
                    )
                    .frame(
                        width: resolvedLayoutSize.width * resolvedDisplayScale,
                        height: resolvedLayoutSize.height * resolvedDisplayScale,
                        alignment: .topLeading
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                if activeTool == .select,
                   isControlSelectionActive,
                   selectedDesignerControls.count == 1,
                   let selectedDesignerControl = selectedDesignerControls.first,
                   !selectedDesignerControl.isLocationLocked {
                    GamepadControlRotationOverlay(
                        control: selectedDesignerControl,
                        displayScale: resolvedDisplayScale,
                        onRotationChanged: { value in
                            selectOnly(selectedDesignerControl.id)
                            updateRotation(value, control: selectedDesignerControl, displayScale: resolvedDisplayScale)
                        },
                        onRotationEnded: {
                            activeRotation = nil
                        }
                    )
                    .position(
                        x: selectedDesignerControl.center.x * resolvedDisplayScale,
                        y: selectedDesignerControl.center.y * resolvedDisplayScale
                    )
                }

                if isMultiSelection,
                   let selectionFrame = selectionBounds(for: selectedDesignerControls) {
                    GamepadGroupSelectionOverlay(
                        onResizeChanged: { corner, value in
                            updateGroupResize(corner, value: value, selectedControls: selectedDesignerControls, canvasSize: resolvedLayoutSize, displayScale: resolvedDisplayScale)
                        },
                        onResizeEnded: {
                            activeGroupResize = nil
                        }
                    )
                    .frame(width: selectionFrame.width * resolvedDisplayScale, height: selectionFrame.height * resolvedDisplayScale)
                    .position(x: selectionFrame.midX * resolvedDisplayScale, y: selectionFrame.midY * resolvedDisplayScale)
                }

                if let activeAlignmentGuide {
                    GamepadMeasurementOverlay(
                        selectedFrame: activeAlignmentGuide.selectedFrame,
                        target: .frame(activeAlignmentGuide.primaryTargetFrame),
                        canvasSize: resolvedLayoutSize,
                        displayScale: resolvedDisplayScale
                    )
                    .frame(
                        width: resolvedLayoutSize.width * resolvedDisplayScale,
                        height: resolvedLayoutSize.height * resolvedDisplayScale,
                        alignment: .topLeading
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    GamepadAlignmentGuideOverlay(
                        guide: activeAlignmentGuide,
                        canvasSize: resolvedLayoutSize,
                        displayScale: resolvedDisplayScale
                    )
                    .frame(
                        width: resolvedLayoutSize.width * resolvedDisplayScale,
                        height: resolvedLayoutSize.height * resolvedDisplayScale,
                        alignment: .topLeading
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                if shouldShowMeasurementOverlay {
                    if let measurementPair = measurementControlPair(in: controls) {
                        GamepadMeasurementOverlay(
                            selectedFrame: measurementPair.selected.frame,
                            target: .frame(measurementPair.hovered.frame),
                            canvasSize: resolvedLayoutSize,
                            displayScale: resolvedDisplayScale
                        )
                        .frame(
                            width: resolvedLayoutSize.width * resolvedDisplayScale,
                            height: resolvedLayoutSize.height * resolvedDisplayScale,
                            alignment: .topLeading
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    } else if isHoveringCanvasBackground,
                              let selectedFrame = measurementSelectionFrame(for: selectedDesignerControls) {
                        GamepadMeasurementOverlay(
                            selectedFrame: selectedFrame,
                            target: .canvasEdges,
                            canvasSize: resolvedLayoutSize,
                            displayScale: resolvedDisplayScale
                        )
                        .frame(
                            width: resolvedLayoutSize.width * resolvedDisplayScale,
                            height: resolvedLayoutSize.height * resolvedDisplayScale,
                            alignment: .topLeading
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }

                if let activeDraw {
                    drawingPreview(activeDraw, canvasSize: resolvedLayoutSize, displayScale: resolvedDisplayScale)
                }

                if activeTool.isDrawingShape {
                    drawingToolHint
                }
            }
            .contentShape(Rectangle())
            .gesture(
                drawingGesture(canvasSize: resolvedLayoutSize, displayScale: resolvedDisplayScale),
                including: activeTool.isDrawingShape ? .gesture : .none
            )
            .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
            )
            .background {
                GamepadModifierKeyMonitor(isOptionPressed: $isOptionKeyPressed, isShiftPressed: $isShiftKeyPressed)
                    .frame(width: 0, height: 0)
            }
            .onChange(of: activeTool) { _, newTool in
                if newTool != .select {
                    hoveredControlID = nil
                    isHoveringCanvasBackground = false
                    activeAlignmentGuide = nil
                    activeRotation = nil
                }
            }
            .onDisappear {
                hoveredControlID = nil
                isHoveringCanvasBackground = false
                activeAlignmentGuide = nil
                isOptionKeyPressed = false
                isShiftKeyPressed = false
                activeGroupResize = nil
                activeRotation = nil
            }
            .coordinateSpace(name: "gamepadLayoutDesigner")
            .onContinuousHover(coordinateSpace: .named("gamepadLayoutDesigner")) { phase in
                switch phase {
                case .active(let location):
                    let pointerIsInsideCanvas = isPointerInsideCanvas(
                        at: location,
                        canvasSize: resolvedLayoutSize,
                        displayScale: resolvedDisplayScale
                    )
                    let hoveredAnyControlID = controlIDUnderPointer(
                        at: location,
                        in: controls,
                        canvasSize: resolvedLayoutSize,
                        displayScale: resolvedDisplayScale,
                        excludesSelectedControls: false
                    )
                    hoveredControlID = controlIDUnderPointer(
                        at: location,
                        in: controls,
                        canvasSize: resolvedLayoutSize,
                        displayScale: resolvedDisplayScale
                    )
                    isHoveringCanvasBackground = pointerIsInsideCanvas && hoveredAnyControlID == nil
                case .ended:
                    hoveredControlID = nil
                    isHoveringCanvasBackground = false
                }
            }
        }
    }

    private var shouldShowMeasurementOverlay: Bool {
        activeTool == .select
            && isOptionKeyPressed
            && isControlSelectionActive
            && activeDrag == nil
            && activeResize == nil
            && activeGroupResize == nil
            && activeRotation == nil
            && activeRadiusDrag == nil
            && activeDraw == nil
    }

    private func measurementControlPair(in controls: [GamepadResolvedControl]) -> (selected: GamepadResolvedControl, hovered: GamepadResolvedControl)? {
        guard let hoveredControlID,
              !selectedControlIDs.contains(hoveredControlID),
              let selected = controls.first(where: { $0.id == selectedControlID }),
              let hovered = controls.first(where: { $0.id == hoveredControlID })
        else {
            return nil
        }

        return (selected, hovered)
    }

    private func measurementSelectionFrame(for selectedControls: [GamepadResolvedControl]) -> CGRect? {
        if selectedControls.count > 1 {
            return selectionBounds(for: selectedControls)
        }
        return selectedControls.first?.frame
    }

    private func isPointerInsideCanvas(
        at displayPoint: CGPoint,
        canvasSize: CGSize,
        displayScale: CGFloat
    ) -> Bool {
        let scale = max(displayScale, 0.001)
        let logicalPoint = CGPoint(x: displayPoint.x / scale, y: displayPoint.y / scale)
        return CGRect(origin: .zero, size: canvasSize).contains(logicalPoint)
    }

    private func controlIDUnderPointer(
        at displayPoint: CGPoint,
        in controls: [GamepadResolvedControl],
        canvasSize: CGSize,
        displayScale: CGFloat,
        excludesSelectedControls: Bool = true
    ) -> GamepadControlIdentity? {
        let scale = max(displayScale, 0.001)
        let logicalPoint = CGPoint(x: displayPoint.x / scale, y: displayPoint.y / scale)
        guard CGRect(origin: .zero, size: canvasSize).contains(logicalPoint) else { return nil }

        let hitSlop = 4 / scale
        return controls.reversed().first { control in
            (!excludesSelectedControls || !selectedControlIDs.contains(control.id))
                && control.frame.insetBy(dx: -hitSlop, dy: -hitSlop).contains(logicalPoint)
        }?.id
    }

    private func currentSelectedControls(in controls: [GamepadResolvedControl]) -> [GamepadResolvedControl] {
        guard isControlSelectionActive else { return [] }
        return controls.filter { selectedControlIDs.contains($0.id) }
    }

    private func selectionBounds(for controls: [GamepadResolvedControl]) -> CGRect? {
        guard var bounds = controls.first?.frame else { return nil }
        for control in controls.dropFirst() {
            bounds = bounds.union(control.frame)
        }
        return bounds.standardized
    }

    private func clearSelection() {
        isControlSelectionActive = false
        selectedControlIDs.removeAll()
    }

    private func selectOnly(_ identity: GamepadControlIdentity) {
        selectedControlID = identity
        selectedControlIDs = [identity]
        isControlSelectionActive = true
    }

    @discardableResult
    private func selectForPointerDown(_ identity: GamepadControlIdentity, additive: Bool) -> Set<GamepadControlIdentity> {
        let nextSelectionIDs: Set<GamepadControlIdentity>
        if additive {
            var additiveSelection = isControlSelectionActive ? selectedControlIDs : []
            additiveSelection.insert(identity)
            nextSelectionIDs = additiveSelection
        } else if isControlSelectionActive,
                  selectedControlIDs.count > 1,
                  selectedControlIDs.contains(identity) {
            nextSelectionIDs = selectedControlIDs
        } else {
            nextSelectionIDs = [identity]
        }

        selectedControlID = identity
        selectedControlIDs = nextSelectionIDs
        isControlSelectionActive = true
        return nextSelectionIDs
    }

    private func beginDrag(
        for identity: GamepadControlIdentity,
        selectionIDs: Set<GamepadControlIdentity>,
        controls: [GamepadResolvedControl]
    ) {
        let snapshots = controls
            .filter { selectionIDs.contains($0.id) && !$0.isLocationLocked }
            .map { GamepadControlDragSnapshot(control: $0) }
        activeDrag = snapshots.isEmpty ? nil : GamepadControlDragState(identity: identity, snapshots: snapshots)
    }

    private var drawingToolHint: some View {
        HStack(spacing: Geist.Spacing.s2) {
            Image(systemName: activeTool.systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text("Drag to draw \(activeTool.displayName)")
                .geistTypography(.label12)
        }
        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .background(Geist.color(.background100, scheme: colorScheme), in: Capsule())
        .overlay(Capsule().stroke(Geist.color(.blue700, scheme: colorScheme), lineWidth: 1))
        .padding(Geist.Spacing.s3)
        .allowsHitTesting(false)
    }

    private func drawingGesture(canvasSize: CGSize, displayScale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
            .onChanged { value in
                guard activeTool.isDrawingShape else { return }
                let startPoint = logicalPoint(from: value.startLocation, canvasSize: canvasSize, displayScale: displayScale)
                let currentPoint = logicalPoint(from: value.location, canvasSize: canvasSize, displayScale: displayScale)
                activeDraw = GamepadShapeDrawState(tool: activeTool, startPoint: startPoint, currentPoint: currentPoint)
            }
            .onEnded { value in
                guard activeTool.isDrawingShape else {
                    activeDraw = nil
                    return
                }

                let startPoint = logicalPoint(from: value.startLocation, canvasSize: canvasSize, displayScale: displayScale)
                let currentPoint = logicalPoint(from: value.location, canvasSize: canvasSize, displayScale: displayScale)
                let drawState = activeDraw ?? GamepadShapeDrawState(tool: activeTool, startPoint: startPoint, currentPoint: currentPoint)
                let finalDrawState = GamepadShapeDrawState(tool: drawState.tool, startPoint: drawState.startPoint, currentPoint: currentPoint)
                let rect = finalizedDrawRect(for: finalDrawState, in: canvasSize)
                createCustomButton(from: rect, tool: finalDrawState.tool, canvasSize: canvasSize)
                activeDraw = nil
            }
    }

    private func logicalPoint(from displayPoint: CGPoint, canvasSize: CGSize, displayScale: CGFloat) -> CGPoint {
        CGPoint(
            x: Self.clamp(displayPoint.x / max(displayScale, 0.001), lower: 0, upper: canvasSize.width),
            y: Self.clamp(displayPoint.y / max(displayScale, 0.001), lower: 0, upper: canvasSize.height)
        )
    }

    private func finalizedDrawRect(for draw: GamepadShapeDrawState, in canvasSize: CGSize) -> CGRect {
        let rawRect = CGRect(
            x: min(draw.startPoint.x, draw.currentPoint.x),
            y: min(draw.startPoint.y, draw.currentPoint.y),
            width: abs(draw.currentPoint.x - draw.startPoint.x),
            height: abs(draw.currentPoint.y - draw.startPoint.y)
        )

        let dragDistance = hypot(draw.currentPoint.x - draw.startPoint.x, draw.currentPoint.y - draw.startPoint.y)
        let desiredWidth = dragDistance < Self.dragActivationDistance ? Self.defaultDrawnButtonSize.width : max(rawRect.width, Self.minimumDrawnButtonSize)
        let desiredHeight = dragDistance < Self.dragActivationDistance ? Self.defaultDrawnButtonSize.height : max(rawRect.height, Self.minimumDrawnButtonSize)
        let width = min(desiredWidth, canvasSize.width)
        let height = min(desiredHeight, canvasSize.height)
        let center = dragDistance < Self.dragActivationDistance ? draw.startPoint : CGPoint(x: rawRect.midX, y: rawRect.midY)
        let origin = CGPoint(
            x: Self.clamp(center.x - width / 2, lower: 0, upper: max(0, canvasSize.width - width)),
            y: Self.clamp(center.y - height / 2, lower: 0, upper: max(0, canvasSize.height - height))
        )

        return CGRect(origin: origin, size: CGSize(width: width, height: height))
    }

    private func createCustomButton(from rect: CGRect, tool: GamepadCanvasTool, canvasSize: CGSize) {
        guard let shape = tool.shapeStyle,
              customization.customButtons.count < GamepadCustomization.maximumCustomButtons,
              let placementRect = GamepadLayoutResolver.nonOverlappingFrame(
                for: rect,
                avoiding: customization.resolvedControls(in: canvasSize).map(\.frame),
                in: canvasSize
              )
        else {
            activeTool = .select
            return
        }

        let id = UUID()
        var next = customization
        next.addCustomButton(id: id)
        guard let index = next.customButtons.firstIndex(where: { $0.id == id }) else { return }

        let baseControl = next.resolvedControls(in: canvasSize).first { $0.id == .custom(id) }
        let baseSize = baseControl?.size ?? Self.defaultDrawnButtonSize
        next.customButtons[index].label = tool.displayName
        next.customButtons[index].layout = GamepadButtonCustomization(
            centerX: placementRect.midX / max(canvasSize.width, 1),
            centerY: placementRect.midY / max(canvasSize.height, 1),
            widthScale: placementRect.width / max(baseSize.width, 1),
            heightScale: placementRect.height / max(baseSize.height, 1),
            shape: shape
        )

        customization = next.normalized
        selectedControlID = .custom(id)
        selectedControlIDs = [.custom(id)]
        isControlSelectionActive = true
        activeTool = .select
    }

    private func drawingPreview(_ draw: GamepadShapeDrawState, canvasSize: CGSize, displayScale: CGFloat) -> some View {
        let rect = finalizedDrawRect(for: draw, in: canvasSize)
        let lineWidth = max(1, 2 / max(displayScale, 0.001))
        let previewWidth = max(1, rect.width * displayScale)
        let previewHeight = max(1, rect.height * displayScale)

        return drawingPreviewShape(for: draw.tool, lineWidth: lineWidth)
            .frame(width: previewWidth, height: previewHeight)
            .position(x: rect.midX * displayScale, y: rect.midY * displayScale)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func drawingPreviewShape(for tool: GamepadCanvasTool, lineWidth: CGFloat) -> some View {
        let fill = Geist.color(.blue200, scheme: colorScheme).opacity(0.28)
        let stroke = Geist.color(.blue700, scheme: colorScheme)

        switch tool.shapeStyle ?? .rectangle {
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: GamepadButtonCustomization.defaultCornerRadius, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: GamepadButtonCustomization.defaultCornerRadius, style: .continuous).stroke(stroke, lineWidth: lineWidth))
        case .rectangle:
            Rectangle()
                .fill(fill)
                .overlay(Rectangle().stroke(stroke, lineWidth: lineWidth))
        case .capsule, .circle, .ellipse:
            RoundedRectangle(cornerRadius: GamepadButtonCustomization.maximumCornerRadius, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: GamepadButtonCustomization.maximumCornerRadius, style: .continuous).stroke(stroke, lineWidth: lineWidth))
        case .polygon:
            GamepadRegularPolygonButtonShape(sides: 3)
                .fill(fill)
                .overlay(GamepadRegularPolygonButtonShape(sides: 3).stroke(stroke, lineWidth: lineWidth))
        case .star:
            GamepadStarButtonShape(points: 5)
                .fill(fill)
                .overlay(GamepadStarButtonShape(points: 5).stroke(stroke, lineWidth: lineWidth))
        }
    }

    private var layoutGrid: some View {
        ZStack {
            HStack(spacing: 0) {
                Spacer()
                Rectangle().fill(Geist.color(.grayAlpha400, scheme: colorScheme)).frame(width: 1)
                Spacer()
            }
            VStack(spacing: 0) {
                Spacer()
                Rectangle().fill(Geist.color(.grayAlpha400, scheme: colorScheme)).frame(height: 1)
                Spacer()
            }
        }
        .opacity(0.45)
        .allowsHitTesting(false)
    }

    private func resolvedLayoutSize(for fallbackSize: CGSize) -> CGSize {
        guard let layoutSize,
              layoutSize.width > 1,
              layoutSize.height > 1
        else {
            return fallbackSize
        }

        return layoutSize
    }

    private static func isExplicitDrag(_ translation: CGSize) -> Bool {
        hypot(translation.width, translation.height) >= dragActivationDistance
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private func alignmentTargetFrames(excluding identities: Set<GamepadControlIdentity>, in controls: [GamepadResolvedControl]) -> [CGRect] {
        controls.compactMap { control in
            identities.contains(control.id) ? nil : control.frame
        }
    }

    private func updatePosition(
        _ point: CGPoint,
        control: GamepadResolvedControl,
        controls: [GamepadResolvedControl],
        canvasSize: CGSize,
        displayScale: CGFloat
    ) {
        let normalizedPosition = GamepadLayoutResolver.normalizedPosition(for: point, visualSize: control.size, in: canvasSize)
        let clampedCenter = CGPoint(
            x: normalizedPosition.x * canvasSize.width,
            y: normalizedPosition.y * canvasSize.height
        )
        let preferredFrame = CGRect(
            x: clampedCenter.x - control.size.width / 2,
            y: clampedCenter.y - control.size.height / 2,
            width: control.size.width,
            height: control.size.height
        )
        let snapResult = GamepadAlignmentSnapSolver.snappedFrame(
            for: preferredFrame,
            targetFrames: alignmentTargetFrames(excluding: selectedControlIDs, in: controls),
            canvasSize: canvasSize,
            displayScale: displayScale
        )
        let adjustedFrame = nonOverlappingFrame(for: snapResult.frame, excluding: control.id, canvasSize: canvasSize) ?? control.frame
        activeAlignmentGuide = GamepadAlignmentSnapSolver.framesAreEquivalent(adjustedFrame, snapResult.frame) ? snapResult.guide : nil
        let adjustedPosition = CGPoint(x: adjustedFrame.midX / max(canvasSize.width, 1), y: adjustedFrame.midY / max(canvasSize.height, 1))
        var next = customization
        next.setPosition(adjustedPosition, for: control.id)
        customization = next.normalized
    }

    private func updateGroupPosition(
        _ translation: CGSize,
        dragState: GamepadControlDragState,
        controls: [GamepadResolvedControl],
        canvasSize: CGSize,
        displayScale: CGFloat
    ) {
        guard !dragState.snapshots.isEmpty else { return }
        let selectedIDs = Set(dragState.snapshots.map(\.identity))
        let adjustedTranslation = adjustedGroupTranslation(
            translation,
            snapshots: dragState.snapshots,
            selectedIDs: selectedIDs,
            controls: controls,
            canvasSize: canvasSize,
            displayScale: displayScale
        )
        var next = customization
        for snapshot in dragState.snapshots {
            let proposedCenter = CGPoint(
                x: snapshot.startCenter.x + adjustedTranslation.width,
                y: snapshot.startCenter.y + adjustedTranslation.height
            )
            let normalizedPosition = GamepadLayoutResolver.normalizedPosition(
                for: proposedCenter,
                visualSize: snapshot.size,
                in: canvasSize
            )
            next.setPosition(normalizedPosition, for: snapshot.identity)
        }
        customization = next.normalized
    }

    private func adjustedGroupTranslation(
        _ translation: CGSize,
        snapshots: [GamepadControlDragSnapshot],
        selectedIDs: Set<GamepadControlIdentity>,
        controls: [GamepadResolvedControl],
        canvasSize: CGSize,
        displayScale: CGFloat
    ) -> CGSize {
        let clampedTranslation = clampedGroupTranslation(translation, snapshots: snapshots, canvasSize: canvasSize)
        guard var startBounds = snapshots.first?.startFrame else {
            activeAlignmentGuide = nil
            return .zero
        }
        for snapshot in snapshots.dropFirst() {
            startBounds = startBounds.union(snapshot.startFrame)
        }

        let proposedBounds = startBounds.offsetBy(dx: clampedTranslation.width, dy: clampedTranslation.height)
        let snapResult = GamepadAlignmentSnapSolver.snappedFrame(
            for: proposedBounds,
            targetFrames: alignmentTargetFrames(excluding: selectedIDs, in: controls),
            canvasSize: canvasSize,
            displayScale: displayScale
        )
        let snappedTranslation = clampedGroupTranslation(
            CGSize(width: snapResult.frame.minX - startBounds.minX, height: snapResult.frame.minY - startBounds.minY),
            snapshots: snapshots,
            canvasSize: canvasSize
        )
        let snappedBounds = startBounds.offsetBy(dx: snappedTranslation.width, dy: snappedTranslation.height)
        let snapGuide = GamepadAlignmentSnapSolver.framesAreEquivalent(snappedBounds, snapResult.frame) ? snapResult.guide : nil
        let existingFrames = existingControlFrames(excluding: selectedIDs, canvasSize: canvasSize)
        guard groupFrames(snapshots, offsetBy: snappedTranslation).contains(where: { GamepadLayoutResolver.frameOverlapsAny($0, avoiding: existingFrames) }) else {
            activeAlignmentGuide = snapGuide
            return snappedTranslation
        }

        var lowerBound: CGFloat = 0
        var upperBound: CGFloat = 1
        var bestTranslation = CGSize.zero
        for _ in 0..<12 {
            let fraction = (lowerBound + upperBound) / 2
            let candidate = CGSize(width: snappedTranslation.width * fraction, height: snappedTranslation.height * fraction)
            let overlaps = groupFrames(snapshots, offsetBy: candidate).contains { frame in
                GamepadLayoutResolver.frameOverlapsAny(frame, avoiding: existingFrames)
            }
            if overlaps {
                upperBound = fraction
            } else {
                bestTranslation = candidate
                lowerBound = fraction
            }
        }
        activeAlignmentGuide = nil
        return bestTranslation
    }

    private func clampedGroupTranslation(_ translation: CGSize, snapshots: [GamepadControlDragSnapshot], canvasSize: CGSize) -> CGSize {
        guard !snapshots.isEmpty else { return .zero }
        let frames = snapshots.map(\.startFrame)
        let minXOffset = frames.map { -$0.minX }.max() ?? 0
        let maxXOffset = frames.map { canvasSize.width - $0.maxX }.min() ?? 0
        let minYOffset = frames.map { -$0.minY }.max() ?? 0
        let maxYOffset = frames.map { canvasSize.height - $0.maxY }.min() ?? 0
        return CGSize(
            width: Self.clamp(translation.width, lower: minXOffset, upper: maxXOffset),
            height: Self.clamp(translation.height, lower: minYOffset, upper: maxYOffset)
        )
    }

    private func groupFrames(_ snapshots: [GamepadControlDragSnapshot], offsetBy translation: CGSize) -> [CGRect] {
        snapshots.map { snapshot in
            snapshot.startFrame.offsetBy(dx: translation.width, dy: translation.height)
        }
    }

    private func existingControlFrames(excluding identity: GamepadControlIdentity, canvasSize: CGSize) -> [CGRect] {
        existingControlFrames(excluding: [identity], canvasSize: canvasSize)
    }

    private func existingControlFrames(excluding identities: Set<GamepadControlIdentity>, canvasSize: CGSize) -> [CGRect] {
        customization.resolvedControls(in: canvasSize).compactMap { control in
            identities.contains(control.id) ? nil : control.frame
        }
    }

    private func nonOverlappingFrame(for preferredFrame: CGRect, excluding identity: GamepadControlIdentity, canvasSize: CGSize) -> CGRect? {
        GamepadLayoutResolver.nonOverlappingFrame(
            for: preferredFrame,
            avoiding: existingControlFrames(excluding: identity, canvasSize: canvasSize),
            in: canvasSize
        )
    }

    private func rectDidChange(from original: CGRect, to updated: CGRect) -> Bool {
        abs(original.minX - updated.minX) > 0.1
            || abs(original.minY - updated.minY) > 0.1
            || abs(original.width - updated.width) > 0.1
            || abs(original.height - updated.height) > 0.1
    }

    private func updateResize(
        _ corner: GamepadResizeHandleCorner,
        value: DragGesture.Value,
        control: GamepadResolvedControl,
        canvasSize: CGSize,
        displayScale: CGFloat
    ) {
        let currentLayout = layoutCustomization(for: control.id)
        if activeResize?.identity != control.id {
            activeResize = GamepadControlResizeState(
                identity: control.id,
                startCenter: control.center,
                startSize: control.size,
                startWidthScale: currentLayout.widthScale,
                startHeightScale: currentLayout.heightScale,
                shape: control.shape
            )
        }

        guard var resizeState = activeResize else { return }

        let baseWidth = max(1, resizeState.startSize.width / max(resizeState.startWidthScale, 0.001))
        let baseHeight = max(1, resizeState.startSize.height / max(resizeState.startHeightScale, 0.001))
        let minWidth = baseWidth * GamepadButtonCustomization.minimumScale
        let minHeight = baseHeight * GamepadButtonCustomization.minimumScale
        let maxWidth = min(canvasSize.width, baseWidth * GamepadButtonCustomization.maximumScale)
        let maxHeight = min(canvasSize.height, baseHeight * GamepadButtonCustomization.maximumScale)
        let translation = CGSize(
            width: value.translation.width / max(displayScale, 0.001),
            height: value.translation.height / max(displayScale, 0.001)
        )
        let startRect = CGRect(
            x: resizeState.startCenter.x - resizeState.startSize.width / 2,
            y: resizeState.startCenter.y - resizeState.startSize.height / 2,
            width: resizeState.startSize.width,
            height: resizeState.startSize.height
        )
        let minSize = CGSize(width: minWidth, height: minHeight)
        let maxSize = CGSize(width: maxWidth, height: maxHeight)
        let resizedRect = resizedFrameAvoidingOverlaps(
            from: startRect,
            corner: corner,
            translation: translation,
            minSize: minSize,
            maxSize: maxSize,
            canvasSize: canvasSize,
            avoiding: existingControlFrames(excluding: control.id, canvasSize: canvasSize)
        )
        let newSize = resizedRect.size
        let newCenter = CGPoint(x: resizedRect.midX, y: resizedRect.midY)
        guard rectDidChange(from: startRect, to: CGRect(x: newCenter.x - newSize.width / 2, y: newCenter.y - newSize.height / 2, width: newSize.width, height: newSize.height)) else { return }
        if !resizeState.didRegisterUndo {
            onBeginUndoableChange("Resize Key")
            resizeState.didRegisterUndo = true
            activeResize = resizeState
        }

        updateLayoutCustomization(for: control.id) { layout in
            layout.widthScale = newSize.width / baseWidth
            layout.heightScale = newSize.height / baseHeight
            layout.centerX = newCenter.x / max(canvasSize.width, 1)
            layout.centerY = newCenter.y / max(canvasSize.height, 1)
        }
    }

    private func updateGroupResize(
        _ corner: GamepadResizeHandleCorner,
        value: DragGesture.Value,
        selectedControls: [GamepadResolvedControl],
        canvasSize: CGSize,
        displayScale: CGFloat
    ) {
        let selectedIDs = Set(selectedControls.map(\.id))
        if activeGroupResize?.selectionIDs != selectedIDs || activeGroupResize?.corner != corner {
            activeGroupResize = makeGroupResizeState(corner: corner, selectedControls: selectedControls, canvasSize: canvasSize)
        }

        guard var groupResizeState = activeGroupResize else { return }
        let translation = CGSize(
            width: value.translation.width / max(displayScale, 0.001),
            height: value.translation.height / max(displayScale, 0.001)
        )
        let resizedBounds = resizedGroupFrameAvoidingOverlaps(
            state: groupResizeState,
            translation: translation,
            canvasSize: canvasSize
        )
        guard rectDidChange(from: groupResizeState.startBounds, to: resizedBounds) else { return }
        if !groupResizeState.didRegisterUndo {
            onBeginUndoableChange("Resize Selection")
            groupResizeState.didRegisterUndo = true
            activeGroupResize = groupResizeState
        }
        applyGroupResize(state: groupResizeState, resizedBounds: resizedBounds, canvasSize: canvasSize)
    }

    private func makeGroupResizeState(
        corner: GamepadResizeHandleCorner,
        selectedControls: [GamepadResolvedControl],
        canvasSize: CGSize
    ) -> GamepadGroupResizeState? {
        guard selectedControls.count > 1,
              selectedControls.allSatisfy({ !$0.isLocationLocked }),
              let startBounds = selectionBounds(for: selectedControls)
        else { return nil }

        let controlStates = selectedControls.map { control -> GamepadGroupResizeControlState in
            let currentLayout = layoutCustomization(for: control.id)
            let baseWidth = max(1, control.size.width / max(currentLayout.widthScale, 0.001))
            let baseHeight = max(1, control.size.height / max(currentLayout.heightScale, 0.001))
            let minSize = CGSize(
                width: baseWidth * GamepadButtonCustomization.minimumScale,
                height: baseHeight * GamepadButtonCustomization.minimumScale
            )
            let maxSize = CGSize(
                width: min(canvasSize.width, baseWidth * GamepadButtonCustomization.maximumScale),
                height: min(canvasSize.height, baseHeight * GamepadButtonCustomization.maximumScale)
            )
            return GamepadGroupResizeControlState(
                identity: control.id,
                startFrame: control.frame,
                baseSize: CGSize(width: baseWidth, height: baseHeight),
                minSize: minSize,
                maxSize: maxSize,
                shape: control.shape
            )
        }

        return GamepadGroupResizeState(
            selectionIDs: Set(selectedControls.map(\.id)),
            corner: corner,
            startBounds: startBounds,
            controls: controlStates
        )
    }

    private func resizedGroupFrameAvoidingOverlaps(
        state: GamepadGroupResizeState,
        translation: CGSize,
        canvasSize: CGSize
    ) -> CGRect {
        let limits = groupResizeLimits(for: state, canvasSize: canvasSize)
        let desiredBounds = resizedFrame(
            from: state.startBounds,
            corner: state.corner,
            translation: translation,
            minSize: limits.minSize,
            maxSize: limits.maxSize,
            canvasSize: canvasSize
        )
        let existingFrames = existingControlFrames(excluding: state.selectionIDs, canvasSize: canvasSize)
        guard !groupResizeFrames(state: state, resizedBounds: desiredBounds).contains(where: { GamepadLayoutResolver.frameOverlapsAny($0, avoiding: existingFrames) }) else {
            var lowerBound: CGFloat = 0
            var upperBound: CGFloat = 1
            var bestBounds = state.startBounds
            for _ in 0..<12 {
                let fraction = (lowerBound + upperBound) / 2
                let candidateTranslation = CGSize(width: translation.width * fraction, height: translation.height * fraction)
                let candidateBounds = resizedFrame(
                    from: state.startBounds,
                    corner: state.corner,
                    translation: candidateTranslation,
                    minSize: limits.minSize,
                    maxSize: limits.maxSize,
                    canvasSize: canvasSize
                )
                let overlaps = groupResizeFrames(state: state, resizedBounds: candidateBounds).contains { frame in
                    GamepadLayoutResolver.frameOverlapsAny(frame, avoiding: existingFrames)
                }
                if overlaps {
                    upperBound = fraction
                } else {
                    bestBounds = candidateBounds
                    lowerBound = fraction
                }
            }
            return bestBounds
        }

        return desiredBounds
    }

    private func groupResizeLimits(for state: GamepadGroupResizeState, canvasSize: CGSize) -> (minSize: CGSize, maxSize: CGSize) {
        let startWidth = max(state.startBounds.width, 1)
        let startHeight = max(state.startBounds.height, 1)
        var minimumScaleX: CGFloat = 0.001
        var minimumScaleY: CGFloat = 0.001
        var maximumScaleX: CGFloat = CGFloat.greatestFiniteMagnitude
        var maximumScaleY: CGFloat = CGFloat.greatestFiniteMagnitude

        for control in state.controls {
            minimumScaleX = max(minimumScaleX, control.minSize.width / max(control.startFrame.width, 1))
            minimumScaleY = max(minimumScaleY, control.minSize.height / max(control.startFrame.height, 1))
            maximumScaleX = min(maximumScaleX, control.maxSize.width / max(control.startFrame.width, 1))
            maximumScaleY = min(maximumScaleY, control.maxSize.height / max(control.startFrame.height, 1))
        }

        let minWidth = min(canvasSize.width, startWidth * minimumScaleX)
        let minHeight = min(canvasSize.height, startHeight * minimumScaleY)
        let maxWidth = max(minWidth, min(canvasSize.width, startWidth * maximumScaleX))
        let maxHeight = max(minHeight, min(canvasSize.height, startHeight * maximumScaleY))
        return (CGSize(width: minWidth, height: minHeight), CGSize(width: maxWidth, height: maxHeight))
    }

    private func groupResizeFrames(state: GamepadGroupResizeState, resizedBounds: CGRect) -> [CGRect] {
        state.controls.map { transformedFrame(for: $0, from: state.startBounds, to: resizedBounds) }
    }

    private func transformedFrame(
        for control: GamepadGroupResizeControlState,
        from startBounds: CGRect,
        to resizedBounds: CGRect
    ) -> CGRect {
        let scaleX = resizedBounds.width / max(startBounds.width, 1)
        let scaleY = resizedBounds.height / max(startBounds.height, 1)
        let transformedCenter = CGPoint(
            x: resizedBounds.minX + (control.startFrame.midX - startBounds.minX) * scaleX,
            y: resizedBounds.minY + (control.startFrame.midY - startBounds.minY) * scaleY
        )
        var newSize = CGSize(width: control.startFrame.width * scaleX, height: control.startFrame.height * scaleY)
        newSize.width = Self.clamp(newSize.width, lower: control.minSize.width, upper: control.maxSize.width)
        newSize.height = Self.clamp(newSize.height, lower: control.minSize.height, upper: control.maxSize.height)
        return CGRect(
            x: transformedCenter.x - newSize.width / 2,
            y: transformedCenter.y - newSize.height / 2,
            width: newSize.width,
            height: newSize.height
        )
    }

    private func applyGroupResize(state: GamepadGroupResizeState, resizedBounds: CGRect, canvasSize: CGSize) {
        var next = customization
        for control in state.controls {
            let frame = transformedFrame(for: control, from: state.startBounds, to: resizedBounds)
            let center = CGPoint(x: frame.midX, y: frame.midY)
            switch control.identity {
            case .builtin(let button):
                var layout = next.buttonCustomization(for: button)
                layout.widthScale = frame.width / control.baseSize.width
                layout.heightScale = frame.height / control.baseSize.height
                layout.centerX = center.x / max(canvasSize.width, 1)
                layout.centerY = center.y / max(canvasSize.height, 1)
                next.setButtonCustomization(layout, for: button)
            case .custom(let id):
                guard let index = next.customButtons.firstIndex(where: { $0.id == id }) else { continue }
                next.customButtons[index].layout.widthScale = frame.width / control.baseSize.width
                next.customButtons[index].layout.heightScale = frame.height / control.baseSize.height
                next.customButtons[index].layout.centerX = center.x / max(canvasSize.width, 1)
                next.customButtons[index].layout.centerY = center.y / max(canvasSize.height, 1)
            }
        }
        customization = next.normalized
    }

    private func resizedFrame(
        from rect: CGRect,
        corner: GamepadResizeHandleCorner,
        translation: CGSize,
        minSize: CGSize,
        maxSize: CGSize,
        canvasSize: CGSize
    ) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch corner {
        case .topLeading:
            minX += translation.width
            minY += translation.height
        case .topTrailing:
            maxX += translation.width
            minY += translation.height
        case .bottomTrailing:
            maxX += translation.width
            maxY += translation.height
        case .bottomLeading:
            minX += translation.width
            maxY += translation.height
        }

        if corner.movesLeadingEdge {
            minX = Self.clamp(minX, lower: 0, upper: maxX - minSize.width)
            let width = Self.clamp(maxX - minX, lower: minSize.width, upper: maxSize.width)
            minX = maxX - width
        } else {
            maxX = Self.clamp(maxX, lower: minX + minSize.width, upper: canvasSize.width)
            let width = Self.clamp(maxX - minX, lower: minSize.width, upper: maxSize.width)
            maxX = minX + width
        }

        if corner.movesTopEdge {
            minY = Self.clamp(minY, lower: 0, upper: maxY - minSize.height)
            let height = Self.clamp(maxY - minY, lower: minSize.height, upper: maxSize.height)
            minY = maxY - height
        } else {
            maxY = Self.clamp(maxY, lower: minY + minSize.height, upper: canvasSize.height)
            let height = Self.clamp(maxY - minY, lower: minSize.height, upper: maxSize.height)
            maxY = minY + height
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func resizedFrameAvoidingOverlaps(
        from rect: CGRect,
        corner: GamepadResizeHandleCorner,
        translation: CGSize,
        minSize: CGSize,
        maxSize: CGSize,
        canvasSize: CGSize,
        avoiding existingFrames: [CGRect]
    ) -> CGRect {
        let desiredFrame = resizedFrame(
            from: rect,
            corner: corner,
            translation: translation,
            minSize: minSize,
            maxSize: maxSize,
            canvasSize: canvasSize
        )
        guard GamepadLayoutResolver.frameOverlapsAny(desiredFrame, avoiding: existingFrames) else {
            return desiredFrame
        }

        var lowerBound: CGFloat = 0
        var upperBound: CGFloat = 1
        var bestFrame = rect

        for _ in 0..<12 {
            let fraction = (lowerBound + upperBound) / 2
            let candidateTranslation = CGSize(
                width: translation.width * fraction,
                height: translation.height * fraction
            )
            let candidateFrame = resizedFrame(
                from: rect,
                corner: corner,
                translation: candidateTranslation,
                minSize: minSize,
                maxSize: maxSize,
                canvasSize: canvasSize
            )

            if GamepadLayoutResolver.frameOverlapsAny(candidateFrame, avoiding: existingFrames) {
                upperBound = fraction
            } else {
                bestFrame = candidateFrame
                lowerBound = fraction
            }
        }

        return bestFrame
    }

    private func updateRotation(_ value: DragGesture.Value, control: GamepadResolvedControl, displayScale: CGFloat) {
        let scale = max(displayScale, 0.001)
        let pointer = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
        let pointerAngle = Self.angleInDegrees(from: control.center, to: pointer)

        if activeRotation?.identity != control.id {
            activeRotation = GamepadControlRotationState(
                identity: control.id,
                startRotationDegrees: layoutCustomization(for: control.id).rotationDegrees,
                startPointerAngleDegrees: pointerAngle
            )
        }

        guard var rotationState = activeRotation else { return }
        let delta = GamepadButtonCustomization.normalizedRotationDegrees(pointerAngle - rotationState.startPointerAngleDegrees)
        var nextRotation = GamepadButtonCustomization.normalizedRotationDegrees(rotationState.startRotationDegrees + delta)
        if isShiftKeyPressed {
            nextRotation = GamepadButtonCustomization.normalizedRotationDegrees((nextRotation / 15).rounded() * 15)
        }

        let currentRotation = layoutCustomization(for: control.id).rotationDegrees
        guard abs(GamepadButtonCustomization.normalizedRotationDegrees(nextRotation - currentRotation)) > 0.05 else { return }
        if !rotationState.didRegisterUndo {
            onBeginUndoableChange("Rotate Key")
            rotationState.didRegisterUndo = true
            activeRotation = rotationState
        }

        updateLayoutCustomization(for: control.id) { layout in
            layout.rotationDegrees = nextRotation
        }
    }

    private static func angleInDegrees(from center: CGPoint, to point: CGPoint) -> CGFloat {
        atan2(point.y - center.y, point.x - center.x) * 180 / .pi
    }

    private func updateRadius(_ value: DragGesture.Value, control: GamepadResolvedControl, displayScale: CGFloat) {
        guard control.shape.usesEditableCornerRadii else { return }
        let defaultRadius = control.shape.defaultEditableCornerRadius(in: control.size)
        let currentRadii = layoutCustomization(for: control.id).resolvedCornerRadii(defaultRadius: defaultRadius)
        if activeRadiusDrag?.identity != control.id {
            activeRadiusDrag = GamepadControlRadiusDragState(identity: control.id, startRadius: currentRadii.averageRadius)
        }

        guard let activeRadiusDrag else { return }
        let diagonalDelta = (value.translation.width + value.translation.height) / 2 / max(displayScale, 0.001)
        let maximumRadius = min(GamepadButtonCustomization.maximumCornerRadius, min(control.size.width, control.size.height) / 2)
        let nextRadius = Self.clamp(activeRadiusDrag.startRadius + diagonalDelta, lower: GamepadButtonCustomization.minimumCornerRadius, upper: maximumRadius)

        updateLayoutCustomization(for: control.id) { layout in
            if control.shape.usesDynamicEditableCornerRadiusDefault {
                layout.shape = control.shape
            }
            layout.cornerRadius = nil
            layout.cornerRadii = abs(nextRadius - defaultRadius) < 0.001 ? nil : .uniform(nextRadius)
        }
    }

    private func layoutCustomization(for identity: GamepadControlIdentity) -> GamepadButtonCustomization {
        switch identity {
        case .builtin(let button):
            customization.buttonCustomization(for: button)
        case .custom(let id):
            customization.customButtons.first { $0.id == id }?.layout.normalized ?? .defaultValue
        }
    }

    private func updateLayoutCustomization(for identity: GamepadControlIdentity, mutate: (inout GamepadButtonCustomization) -> Void) {
        var next = customization
        switch identity {
        case .builtin(let button):
            var buttonCustomization = next.buttonCustomization(for: button)
            mutate(&buttonCustomization)
            next.setButtonCustomization(buttonCustomization, for: button)
        case .custom(let id):
            guard let index = next.customButtons.firstIndex(where: { $0.id == id }) else { return }
            mutate(&next.customButtons[index].layout)
        }
        customization = next.normalized
    }
}

private enum GamepadResizeHandleCorner: CaseIterable, Identifiable {
    case topLeading
    case topTrailing
    case bottomTrailing
    case bottomLeading

    var id: String {
        switch self {
        case .topLeading: "topLeading"
        case .topTrailing: "topTrailing"
        case .bottomTrailing: "bottomTrailing"
        case .bottomLeading: "bottomLeading"
        }
    }

    var movesLeadingEdge: Bool {
        switch self {
        case .topLeading, .bottomLeading: true
        case .topTrailing, .bottomTrailing: false
        }
    }

    var movesTopEdge: Bool {
        switch self {
        case .topLeading, .topTrailing: true
        case .bottomLeading, .bottomTrailing: false
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .topLeading: "Resize from top left"
        case .topTrailing: "Resize from top right"
        case .bottomTrailing: "Resize from bottom right"
        case .bottomLeading: "Resize from bottom left"
        }
    }
}

private struct GamepadControlDragSnapshot {
    let identity: GamepadControlIdentity
    let startCenter: CGPoint
    let size: CGSize

    init(control: GamepadResolvedControl) {
        self.identity = control.id
        self.startCenter = control.center
        self.size = control.size
    }

    var startFrame: CGRect {
        CGRect(
            x: startCenter.x - size.width / 2,
            y: startCenter.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}

private struct GamepadControlDragState {
    let identity: GamepadControlIdentity
    let snapshots: [GamepadControlDragSnapshot]
    var didMove = false
}

private struct GamepadControlResizeState {
    let identity: GamepadControlIdentity
    let startCenter: CGPoint
    let startSize: CGSize
    let startWidthScale: CGFloat
    let startHeightScale: CGFloat
    let shape: GamepadButtonShapeStyle
    var didRegisterUndo = false
}

private struct GamepadControlRotationState {
    let identity: GamepadControlIdentity
    let startRotationDegrees: CGFloat
    let startPointerAngleDegrees: CGFloat
    var didRegisterUndo = false
}

private struct GamepadControlRadiusDragState {
    let identity: GamepadControlIdentity
    let startRadius: CGFloat
}

private struct GamepadGroupResizeControlState {
    let identity: GamepadControlIdentity
    let startFrame: CGRect
    let baseSize: CGSize
    let minSize: CGSize
    let maxSize: CGSize
    let shape: GamepadButtonShapeStyle
}

private struct GamepadGroupResizeState {
    let selectionIDs: Set<GamepadControlIdentity>
    let corner: GamepadResizeHandleCorner
    let startBounds: CGRect
    let controls: [GamepadGroupResizeControlState]
    var didRegisterUndo = false
}

private struct GamepadGroupSelectionOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let onResizeChanged: (GamepadResizeHandleCorner, DragGesture.Value) -> Void
    let onResizeEnded: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .stroke(Geist.color(.blue700, scheme: colorScheme), lineWidth: 2)
                    .allowsHitTesting(false)

                ForEach(GamepadResizeHandleCorner.allCases) { corner in
                    resizeHandle(corner)
                        .position(handlePosition(for: corner, in: proxy.size))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Selected component group"))
    }

    private func resizeHandle(_ corner: GamepadResizeHandleCorner) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Geist.color(.background100, scheme: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Geist.color(.blue700, scheme: colorScheme), lineWidth: 1.5)
            )
            .frame(width: 11, height: 11)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
                    .onChanged { value in onResizeChanged(corner, value) }
                    .onEnded { _ in onResizeEnded() }
            )
            .accessibilityLabel(Text(corner.accessibilityLabel))
            .accessibilityHint(Text("Drag to resize all selected components"))
    }

    private func handlePosition(for corner: GamepadResizeHandleCorner, in size: CGSize) -> CGPoint {
        switch corner {
        case .topLeading:
            CGPoint(x: 0, y: 0)
        case .topTrailing:
            CGPoint(x: size.width, y: 0)
        case .bottomTrailing:
            CGPoint(x: size.width, y: size.height)
        case .bottomLeading:
            CGPoint(x: 0, y: size.height)
        }
    }
}

private enum GamepadRotationHandleZone: CaseIterable, Identifiable {
    case top
    case topTrailing
    case trailing
    case bottomTrailing
    case bottom
    case bottomLeading
    case leading
    case topLeading

    var id: String {
        switch self {
        case .top: "top"
        case .topTrailing: "topTrailing"
        case .trailing: "trailing"
        case .bottomTrailing: "bottomTrailing"
        case .bottom: "bottom"
        case .bottomLeading: "bottomLeading"
        case .leading: "leading"
        case .topLeading: "topLeading"
        }
    }
}

private struct GamepadControlRotationOverlay: View {
    let control: GamepadResolvedControl
    let displayScale: CGFloat
    let onRotationChanged: (DragGesture.Value) -> Void
    let onRotationEnded: () -> Void

    private static let hitOutset: CGFloat = 22

    private var safeDisplayScale: CGFloat {
        max(displayScale, 0.001)
    }

    private var visualSize: CGSize {
        CGSize(width: max(1, control.size.width * safeDisplayScale), height: max(1, control.size.height * safeDisplayScale))
    }

    private var overlaySize: CGSize {
        CGSize(width: visualSize.width + Self.hitOutset * 2, height: visualSize.height + Self.hitOutset * 2)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(GamepadRotationHandleZone.allCases) { zone in
                rotationHitZone(zone)
                    .frame(width: zoneSize(zone).width, height: zoneSize(zone).height)
                    .position(zonePosition(zone))
            }
        }
        .frame(width: overlaySize.width, height: overlaySize.height)
        .rotationEffect(.degrees(control.rotationDegrees))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rotate selected component"))
        .accessibilityHint(Text("Drag just outside the selected component edge to rotate it"))
    }

    private func rotationHitZone(_ zone: GamepadRotationHandleZone) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gamepadRotationCursor()
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
                    .onChanged(onRotationChanged)
                    .onEnded { _ in onRotationEnded() }
            )
    }

    private func zoneSize(_ zone: GamepadRotationHandleZone) -> CGSize {
        switch zone {
        case .top, .bottom:
            CGSize(width: visualSize.width, height: Self.hitOutset)
        case .leading, .trailing:
            CGSize(width: Self.hitOutset, height: visualSize.height)
        case .topLeading, .topTrailing, .bottomTrailing, .bottomLeading:
            CGSize(width: Self.hitOutset, height: Self.hitOutset)
        }
    }

    private func zonePosition(_ zone: GamepadRotationHandleZone) -> CGPoint {
        let left = Self.hitOutset / 2
        let centerX = Self.hitOutset + visualSize.width / 2
        let right = Self.hitOutset + visualSize.width + Self.hitOutset / 2
        let top = Self.hitOutset / 2
        let centerY = Self.hitOutset + visualSize.height / 2
        let bottom = Self.hitOutset + visualSize.height + Self.hitOutset / 2

        switch zone {
        case .top:
            return CGPoint(x: centerX, y: top)
        case .topTrailing:
            return CGPoint(x: right, y: top)
        case .trailing:
            return CGPoint(x: right, y: centerY)
        case .bottomTrailing:
            return CGPoint(x: right, y: bottom)
        case .bottom:
            return CGPoint(x: centerX, y: bottom)
        case .bottomLeading:
            return CGPoint(x: left, y: bottom)
        case .leading:
            return CGPoint(x: left, y: centerY)
        case .topLeading:
            return CGPoint(x: left, y: top)
        }
    }
}

private extension View {
    @ViewBuilder
    func gamepadRotationCursor() -> some View {
#if os(macOS)
        modifier(GamepadCursorModifier(cursor: .gamepadRotation))
#else
        self
#endif
    }
}

#if os(macOS)
private struct GamepadCursorModifier: ViewModifier {
    let cursor: NSCursor
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                if hovering, !isHovering {
                    cursor.push()
                    isHovering = true
                } else if !hovering, isHovering {
                    NSCursor.pop()
                    isHovering = false
                }
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pop()
                    isHovering = false
                }
            }
    }
}

private extension NSCursor {
    static let gamepadRotation: NSCursor = {
        let size = NSSize(width: 24, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let color = NSColor.labelColor
        color.setStroke()
        color.setFill()

        let arc = NSBezierPath()
        arc.lineWidth = 2
        arc.lineCapStyle = .round
        arc.appendArc(
            withCenter: NSPoint(x: 12, y: 12),
            radius: 7,
            startAngle: 205,
            endAngle: 30,
            clockwise: false
        )
        arc.stroke()

        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: 19.2, y: 14.4))
        arrow.line(to: NSPoint(x: 21.3, y: 7.3))
        arrow.line(to: NSPoint(x: 14.1, y: 8.9))
        arrow.close()
        arrow.fill()

        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 12, y: 12))
    }()
}
#endif

private struct GamepadDesignerButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let control: GamepadResolvedControl
    let customization: GamepadCustomization
    let isSelected: Bool
    let showsSelectionHandles: Bool
    let displayScale: CGFloat
    let onResizeChanged: (GamepadResizeHandleCorner, DragGesture.Value) -> Void
    let onResizeEnded: () -> Void
    let onRadiusChanged: (DragGesture.Value) -> Void
    let onRadiusEnded: () -> Void

    var body: some View {
        ZStack {
            background(isSelected: false)

            if control.isJoystick {
                joystickFace
            } else if customization.showsButtonLabels {
                Text(control.label)
                    .geistTypography(control.size.width <= 44 ? .button12 : .button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(control.layoutCustomization.buttonForeground(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme))
                    .padding(.horizontal, 4)
            }
        }
        .frame(width: control.size.width, height: control.size.height)
        .overlay {
            if isSelected {
                background(isSelected: true)
                    .foregroundStyle(.clear)
            }
        }
        .overlay {
            if isSelected && showsSelectionHandles {
                selectionHandles
            }
        }
        .shadow(
            color: Color.black.opacity((isSelected ? 0.12 : 0.04) * resolvedShadowStrength),
            radius: (isSelected ? 5 : 1) * max(0.25, resolvedShadowStrength),
            y: (isSelected ? 3 : 1) * resolvedShadowStrength
        )
        .accessibilityLabel(control.label)
    }

    private var resolvedAccentStyle: GamepadAccentStyle {
        control.layoutCustomization.accentStyle ?? customization.accentStyle
    }

    private var resolvedCornerRadii: GamepadCornerRadii {
        control.layoutCustomization.resolvedCornerRadii(defaultRadius: control.shape.defaultEditableCornerRadius(in: control.size))
    }

    private var resolvedShadowStrength: CGFloat {
        control.layoutCustomization.shadowStrength
    }

    private var inverseDisplayScale: CGFloat {
        1 / max(displayScale, 0.001)
    }

    private var selectionHandles: some View {
        ZStack {
            ForEach(GamepadResizeHandleCorner.allCases) { corner in
                resizeHandle(corner)
                    .position(handlePosition(for: corner))
            }

            if control.shape.usesEditableCornerRadii {
                radiusHandle
                    .position(radiusHandlePosition)
            }
        }
        .allowsHitTesting(true)
    }

    private func resizeHandle(_ corner: GamepadResizeHandleCorner) -> some View {
        RoundedRectangle(cornerRadius: 3 * inverseDisplayScale, style: .continuous)
            .fill(Geist.color(.background100, scheme: colorScheme))
            .overlay(
                RoundedRectangle(cornerRadius: 3 * inverseDisplayScale, style: .continuous)
                    .stroke(Geist.color(.blue700, scheme: colorScheme), lineWidth: 1.5 * inverseDisplayScale)
            )
            .frame(width: 11 * inverseDisplayScale, height: 11 * inverseDisplayScale)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
                    .onChanged { value in onResizeChanged(corner, value) }
                    .onEnded { _ in onResizeEnded() }
            )
            .accessibilityLabel(Text(corner.accessibilityLabel))
            .accessibilityHint(Text("Drag to resize this component"))
    }

    private var radiusHandle: some View {
        Circle()
            .fill(Geist.color(.purple900, scheme: colorScheme))
            .overlay(
                Circle()
                    .stroke(Geist.color(.background100, scheme: colorScheme), lineWidth: 1.5 * inverseDisplayScale)
            )
            .frame(width: 10 * inverseDisplayScale, height: 10 * inverseDisplayScale)
            .contentShape(Circle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
                    .onChanged(onRadiusChanged)
                    .onEnded { _ in onRadiusEnded() }
            )
            .accessibilityLabel(Text("Adjust border radius"))
            .accessibilityHint(Text("Drag diagonally to round all corners"))
    }

    private func handlePosition(for corner: GamepadResizeHandleCorner) -> CGPoint {
        switch corner {
        case .topLeading:
            CGPoint(x: 0, y: 0)
        case .topTrailing:
            CGPoint(x: control.size.width, y: 0)
        case .bottomTrailing:
            CGPoint(x: control.size.width, y: control.size.height)
        case .bottomLeading:
            CGPoint(x: 0, y: control.size.height)
        }
    }

    private var radiusHandlePosition: CGPoint {
        let radius = min(resolvedCornerRadii.averageRadius, min(control.size.width, control.size.height) / 2)
        let inset = max(13 * inverseDisplayScale, radius)
        return CGPoint(x: min(control.size.width - 10 * inverseDisplayScale, inset), y: min(control.size.height - 10 * inverseDisplayScale, inset))
    }

    private var joystickFace: some View {
        ZStack {
            Circle()
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1 * inverseDisplayScale)
                .frame(width: control.size.width * 0.70, height: control.size.height * 0.70)
            Circle()
                .fill(control.layoutCustomization.buttonForeground(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme).opacity(0.16))
                .overlay(Circle().stroke(Geist.color(.grayAlpha500, scheme: colorScheme), lineWidth: 1 * inverseDisplayScale))
                .frame(width: min(control.size.width, control.size.height) * 0.34, height: min(control.size.width, control.size.height) * 0.34)

            if customization.showsButtonLabels {
                Text(control.label)
                    .geistTypography(control.size.width <= 72 ? .button12 : .button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .foregroundStyle(control.layoutCustomization.buttonForeground(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme))
                    .padding(.horizontal, 4)
                    .offset(y: control.size.height * 0.34)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func background(isSelected: Bool) -> some View {
        let fillColor = isSelected ? Color.clear : control.layoutCustomization.buttonFill(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let strokeColor = isSelected ? Geist.color(.blue700, scheme: colorScheme) : control.layoutCustomization.buttonStroke(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let lineWidth: CGFloat = isSelected ? 3 : 1

        switch control.shape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)
                .fill(fillColor)
                .overlay(UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous).stroke(strokeColor, lineWidth: lineWidth))
        case .polygon:
            GamepadRegularPolygonButtonShape(sides: 3)
                .fill(fillColor)
                .overlay(GamepadRegularPolygonButtonShape(sides: 3).stroke(strokeColor, lineWidth: lineWidth))
        case .star:
            GamepadStarButtonShape(points: 5)
                .fill(fillColor)
                .overlay(GamepadStarButtonShape(points: 5).stroke(strokeColor, lineWidth: lineWidth))
        }
    }
}

private struct GamepadCustomizationPreview: View {
    let customization: GamepadCustomization

    var body: some View {
        GamepadLayoutDesigner(
            customization: .constant(customization),
            selectedControlID: .constant(.builtin(.jump)),
            selectedControlIDs: .constant([.builtin(.jump)]),
            isControlSelectionActive: .constant(true),
            activeTool: .constant(.select)
        )
    }
}
#endif
