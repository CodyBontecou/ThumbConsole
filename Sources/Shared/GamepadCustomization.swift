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
    case capsule
    case circle

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .roundedRectangle: "Rounded"
        case .capsule: "Capsule"
        case .circle: "Circle"
        }
    }
}

public struct GamepadButtonCustomization: Codable, Equatable, Sendable {
    public static let minimumScale: CGFloat = 0.55
    public static let maximumScale: CGFloat = 1.8
    public static let minimumCornerRadius: CGFloat = 0
    public static let maximumCornerRadius: CGFloat = 40
    public static let defaultCornerRadius: CGFloat = 6
    public static let minimumShadowStrength: CGFloat = 0
    public static let maximumShadowStrength: CGFloat = 2
    public static let defaultShadowStrength: CGFloat = 1
    public static let defaultValue = GamepadButtonCustomization()

    public var centerX: CGFloat?
    public var centerY: CGFloat?
    public var widthScale: CGFloat
    public var heightScale: CGFloat
    public var shape: GamepadButtonShapeStyle?
    public var accentStyle: GamepadAccentStyle?
    public var fillColor: GamepadRGBAColor?
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
        shape: GamepadButtonShapeStyle? = nil,
        accentStyle: GamepadAccentStyle? = nil,
        fillColor: GamepadRGBAColor? = nil,
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
        self.shape = shape
        self.accentStyle = accentStyle
        self.fillColor = fillColor
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
        shape = try container.decodeIfPresent(GamepadButtonShapeStyle.self, forKey: .shape)
        accentStyle = try container.decodeIfPresent(GamepadAccentStyle.self, forKey: .accentStyle)
        fillColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .fillColor)
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
        try container.encodeIfPresent(shape, forKey: .shape)
        try container.encodeIfPresent(accentStyle, forKey: .accentStyle)
        try container.encodeIfPresent(fillColor, forKey: .fillColor)
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
        copy.fillColor = copy.fillColor?.normalized
        if let cornerRadii = copy.cornerRadii {
            let normalizedRadii = cornerRadii.normalized
            copy.cornerRadii = normalizedRadii.isUniform(equalTo: Self.defaultCornerRadius) ? nil : normalizedRadii
            copy.cornerRadius = nil
        } else if let cornerRadius = copy.cornerRadius {
            let clampedRadius = Self.clamp(cornerRadius, lower: Self.minimumCornerRadius, upper: Self.maximumCornerRadius)
            copy.cornerRadius = abs(clampedRadius - Self.defaultCornerRadius) < 0.001 ? nil : clampedRadius
        }
        copy.shadowStrength = Self.clamp(copy.shadowStrength, lower: Self.minimumShadowStrength, upper: Self.maximumShadowStrength)
        return copy
    }

    var isDefault: Bool {
        centerX == nil
            && centerY == nil
            && abs(widthScale - 1.0) < 0.001
            && abs(heightScale - 1.0) < 0.001
            && shape == nil
            && accentStyle == nil
            && fillColor == nil
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
            || shape != nil
            || isHidden
    }

    func resolvedShape(defaultShape: GamepadButtonShapeStyle) -> GamepadButtonShapeStyle {
        shape ?? defaultShape
    }

    func resolvedCornerRadii(defaultRadius: CGFloat = GamepadButtonCustomization.defaultCornerRadius) -> GamepadCornerRadii {
        cornerRadii ?? .uniform(cornerRadius ?? defaultRadius)
    }

    static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }

    private enum CodingKeys: String, CodingKey {
        case centerX
        case centerY
        case widthScale
        case heightScale
        case shape
        case accentStyle
        case fillColor
        case cornerRadius
        case cornerRadii
        case shadowStrength
        case isLocationLocked
        case isHidden
    }
}

public struct GamepadCustomButton: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var mappedButton: GameButton
    public var label: String
    public var layout: GamepadButtonCustomization

    public init(
        id: UUID = UUID(),
        mappedButton: GameButton = .custom1,
        label: String = "Extra",
        layout: GamepadButtonCustomization = GamepadButtonCustomization(
            centerX: 0.5,
            centerY: 0.5,
            widthScale: 1.0,
            heightScale: 1.0,
            shape: .roundedRectangle
        )
    ) {
        self.id = id
        self.mappedButton = mappedButton
        self.label = label
        self.layout = layout
    }

    var normalized: GamepadCustomButton {
        var copy = self
        copy.label = normalizedGamepadLabel(copy.label)
        copy.layout = copy.layout.normalized
        if copy.layout.centerX == nil { copy.layout.centerX = 0.5 }
        if copy.layout.centerY == nil { copy.layout.centerY = 0.5 }
        if copy.layout.shape == nil { copy.layout.shape = .roundedRectangle }
        return copy
    }

    func visualLabel(fallback: String) -> String {
        let normalizedLabel = normalizedGamepadLabel(label)
        return normalizedLabel.isEmpty ? fallback : normalizedLabel
    }
}

public struct GamepadCustomization: Codable, Equatable, Sendable {
    public static let maximumLabelLength = gamepadMaximumLabelLength
    public static let maximumCustomButtons = 8
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
    public var accentStyle: GamepadAccentStyle
    public var showsButtonLabels: Bool
    public var labelOverrides: [GameButton: String]
    public var buttonCustomizations: [GameButton: GamepadButtonCustomization]
    public var customButtons: [GamepadCustomButton]
    public var updatedAt: Int64

    public init(
        layoutMode: GamepadLayoutMode = .standard,
        controlScale: GamepadControlScale = .standard,
        accentStyle: GamepadAccentStyle = .monochrome,
        showsButtonLabels: Bool = true,
        labelOverrides: [GameButton: String] = [:],
        buttonCustomizations: [GameButton: GamepadButtonCustomization] = [:],
        customButtons: [GamepadCustomButton] = [],
        updatedAt: Int64 = 0
    ) {
        self.layoutMode = layoutMode
        self.controlScale = controlScale
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
        try container.encode(accentStyle, forKey: .accentStyle)
        try container.encode(showsButtonLabels, forKey: .showsButtonLabels)
        try container.encode(labelOverrides, forKey: .labelOverrides)
        try container.encode(buttonCustomizations, forKey: .buttonCustomizations)
        try container.encode(customButtons, forKey: .customButtons)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    public func visualLabel(for button: GameButton) -> String {
        if let override = labelOverride(for: button) {
            return override
        }
        return Self.defaultVisualLabel(for: button)
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
                label: "Extra",
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
        for customButton in customButtons {
            let normalizedCustomButton = customButton.normalized
            guard seenCustomButtonIDs.insert(normalizedCustomButton.id).inserted else { continue }
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

    private enum CodingKeys: String, CodingKey {
        case layoutMode
        case controlScale
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
    let layoutCustomization: GamepadButtonCustomization
    let isCustom: Bool
    let isLocationLocked: Bool
}

extension GamepadCustomization {
    func resolvedControls(in canvasSize: CGSize) -> [GamepadResolvedControl] {
        GamepadLayoutResolver.resolvedControls(for: self, in: canvasSize)
    }
}

private enum GamepadLayoutResolver {
    static func resolvedControls(for customization: GamepadCustomization, in canvasSize: CGSize) -> [GamepadResolvedControl] {
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
                label: customization.visualLabel(for: button),
                normalizedCenter: CGPoint(x: center.x / canvasSize.width, y: center.y / canvasSize.height),
                center: center,
                size: scaledSize,
                shape: shape,
                layoutCustomization: buttonCustomization,
                isCustom: false,
                isLocationLocked: buttonCustomization.isLocationLocked
            )
        }

        let customControls = customization.customButtons.compactMap { customButton -> GamepadResolvedControl? in
            let normalizedButton = customButton.normalized
            guard !normalizedButton.layout.isHidden else { return nil }

            let defaultShape = defaultShape(for: normalizedButton.mappedButton)
            let shape = normalizedButton.layout.resolvedShape(defaultShape: defaultShape)
            let baseSize = baseSize(for: normalizedButton.mappedButton, controlScale: customization.controlScale, in: canvasSize)
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

            return GamepadResolvedControl(
                id: .custom(normalizedButton.id),
                mappedButton: normalizedButton.mappedButton,
                label: normalizedButton.visualLabel(fallback: customization.visualLabel(for: normalizedButton.mappedButton)),
                normalizedCenter: CGPoint(x: center.x / canvasSize.width, y: center.y / canvasSize.height),
                center: center,
                size: scaledSize,
                shape: shape,
                layoutCustomization: normalizedButton.layout,
                isCustom: true,
                isLocationLocked: normalizedButton.layout.isLocationLocked
            )
        }

        return builtinControls + customControls
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

    private static func effectiveSize(_ size: CGSize, shape: GamepadButtonShapeStyle) -> CGSize {
        guard shape == .circle else { return size }
        let side = min(size.width, size.height)
        return CGSize(width: side, height: side)
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

enum GamepadCustomizationPersistence {
    private static let defaultsKey = "PocketPad.gamepadCustomization.v1"

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
        if let fillColor {
            return fillColor.adjustedForPress(isPressed).swiftUIColor
        }
        return accentStyle.buttonFill(isPressed: isPressed, scheme: scheme)
    }

    func buttonForeground(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if let fillColor {
            return fillColor.foregroundColor
        }
        return accentStyle.buttonForeground(isPressed: isPressed, scheme: scheme)
    }

    func buttonStroke(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if let fillColor {
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

    private static let defaultsKey = "PocketPad.gamepadConfigurationProfiles.v1"

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

        return [
            GamepadConfigurationProfile(name: "Current Setup", customization: activeCustomization),
            GamepadConfigurationProfile(name: "Navigation Left", customization: standard),
            GamepadConfigurationProfile(name: "Actions Left", customization: southpaw),
            GamepadConfigurationProfile(name: "Large Blue", customization: largeBlue),
            GamepadConfigurationProfile(name: "Compact Minimal", customization: compact)
        ]
    }
}

#if os(macOS)
private struct GamepadEditorComponentItem: Identifiable, Hashable {
    let identity: GamepadControlIdentity
    let title: String
    let subtitle: String
    let isCustom: Bool
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

struct GamepadCustomizationEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var customization: GamepadCustomization

    private let showsPreview: Bool
    private let externalProfiles: [GamepadConfigurationProfile]?
    private let externalSelectedProfileID: UUID?
    private let externalDefaultProfileID: UUID?
    private let onReset: (() -> Void)?
    private let onProfilesChanged: (([GamepadConfigurationProfile], UUID, UUID) -> Void)?
    private let selectedKeyBindingContent: ((GameButton) -> AnyView)?

    private static let configurationSidebarMinWidth: CGFloat = 180
    private static let configurationSidebarMaxWidth: CGFloat = 360
    private static let inspectorSidebarMinWidth: CGFloat = 280
    private static let inspectorSidebarMaxWidth: CGFloat = 520
    private static let minimumCanvasColumnWidth: CGFloat = 320
    private static let resizeHandleWidth: CGFloat = 10
    private static let canvasZoomMin: CGFloat = 0.5
    private static let canvasZoomMax: CGFloat = 2.25

    @State private var selectedControlID: GamepadControlIdentity
    @State private var profiles: [GamepadConfigurationProfile]
    @State private var selectedProfileID: UUID
    @State private var defaultProfileID: UUID
    @State private var isSelectedProfileExpanded: Bool
    @State private var configurationSidebarDragStart: CGFloat?
    @State private var inspectorSidebarDragStart: CGFloat?
    @State private var canvasZoomGestureStart: CGFloat?
    @State private var currentCanvasLayoutSize = CGSize(width: 640, height: 360)
    @AppStorage("PocketPad.GamepadEditor.configurationSidebarWidth") private var configurationSidebarWidthValue: Double = 236
    @AppStorage("PocketPad.GamepadEditor.inspectorSidebarWidth") private var inspectorSidebarWidthValue: Double = 340
    @AppStorage("PocketPad.GamepadEditor.canvasZoom") private var canvasZoomValue: Double = 1.0

    init(
        customization: Binding<GamepadCustomization>,
        showsPreview: Bool = true,
        initialProfiles: [GamepadConfigurationProfile]? = nil,
        initialSelectedProfileID: UUID? = nil,
        initialDefaultProfileID: UUID? = nil,
        onReset: (() -> Void)? = nil,
        onProfilesChanged: (([GamepadConfigurationProfile], UUID, UUID) -> Void)? = nil,
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
        self.selectedKeyBindingContent = selectedKeyBindingContent
        self._selectedControlID = State(initialValue: .builtin(.jump))
        self._profiles = State(initialValue: loadedProfiles.profiles)
        self._selectedProfileID = State(initialValue: loadedProfiles.activeProfileID)
        self._defaultProfileID = State(initialValue: loadedProfiles.defaultProfileID)
        self._isSelectedProfileExpanded = State(initialValue: true)
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
                ScrollView {
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
        ScrollView {
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

            ScrollView {
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

            activeSetupComponentsList

            configurationFooter
        }
        .geistPanel(padding: Geist.Spacing.s4, radius: Geist.Radius.md, raised: false)
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

                    Text(profileSubtitle(for: profile.customization))
                        .geistTypography(.label12)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .lineLimit(2)
                        .padding(.leading, 20)
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
                activeSetupComponentsList
                    .padding(.leading, Geist.Spacing.s2)
                    .padding(.bottom, Geist.Spacing.s1)
            }
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

            VStack(spacing: Geist.Spacing.s1) {
                ForEach(componentListItems) { item in
                    componentRow(item)
                }
            }
        }
    }

    private func componentRow(_ item: GamepadEditorComponentItem) -> some View {
        let isSelected = selectedControlID == item.identity
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
                    Image(systemName: item.isCustom ? "plus.square.fill" : "diamond.fill")
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
            VStack(alignment: .leading, spacing: 2) {
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
                Text(profile.customization.layoutMode.displayName)
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .lineLimit(1)
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
            let canvasChrome = Geist.Spacing.s2 * 2
            let fitWidth = max(120, viewportWidth - canvasChrome)
            let fitHeight = max(120, viewportHeight - canvasChrome)
            let baseCanvasWidth = min(fitWidth, fitHeight * 16 / 9)
            let baseCanvasHeight = min(fitHeight, baseCanvasWidth * 9 / 16)
            let canvasWidth = baseCanvasWidth * effectiveCanvasZoom
            let canvasHeight = baseCanvasHeight * effectiveCanvasZoom

            canvasViewport(
                layoutCanvasWidth: baseCanvasWidth,
                layoutCanvasHeight: baseCanvasHeight,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                viewportWidth: viewportWidth,
                viewportHeight: viewportHeight
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Geist.color(.background100, scheme: colorScheme))
            .onAppear {
                noteCanvasLayoutSize(width: baseCanvasWidth, height: baseCanvasHeight)
            }
            .onChange(of: baseCanvasWidth) { _, _ in
                noteCanvasLayoutSize(width: baseCanvasWidth, height: baseCanvasHeight)
            }
            .onChange(of: baseCanvasHeight) { _, _ in
                noteCanvasLayoutSize(width: baseCanvasWidth, height: baseCanvasHeight)
            }
        }
    }

    private func canvasViewport(
        layoutCanvasWidth: CGFloat,
        layoutCanvasHeight: CGFloat,
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        viewportWidth: CGFloat,
        viewportHeight: CGFloat
    ) -> some View {
        let outerWidth = canvasWidth + Geist.Spacing.s4
        let outerHeight = canvasHeight + Geist.Spacing.s4

        return ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack {
                GamepadLayoutDesigner(
                    customization: editorBinding,
                    selectedControlID: $selectedControlID,
                    layoutSize: CGSize(width: layoutCanvasWidth, height: layoutCanvasHeight),
                    displayScale: effectiveCanvasZoom
                )
                    .frame(width: canvasWidth, height: canvasHeight)
                    .padding(Geist.Spacing.s2)
                    .background(
                        RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                            .fill(Geist.color(.gray100, scheme: colorScheme))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                            .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.16 : 0.04), radius: 2, x: 0, y: colorScheme == .dark ? 1 : 2)
            }
            .frame(width: max(viewportWidth, outerWidth), height: max(viewportHeight, outerHeight))
        }
        .frame(height: viewportHeight)
        .overlay(alignment: .bottom) {
            canvasFloatingCreationToolbar
                .padding(.bottom, Geist.Spacing.s4)
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

    private var canvasFloatingCreationToolbar: some View {
        HStack(spacing: Geist.Spacing.s2) {
            Button {
                // Selection is the default canvas tool.
            } label: {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.white)
                    .frame(width: 32, height: 32)
                    .background(Geist.color(.blue700, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select controls")
            .help("Select and drag controls")

            toolbarMenu(systemImage: "square.grid.3x3", accessibilityLabel: "Layout tools") {
                Button("Show Default Controls") {
                    setBuiltInControlsHidden(false)
                }
                Button("Hide Built-in Controls") {
                    setBuiltInControlsHidden(true)
                }
                Divider()
                Button("Reset Key Layout") {
                    resetKeyLayout()
                }
                .disabled(!customization.usesFreeformLayout)
            }

            toolbarMenu(systemImage: "square", accessibilityLabel: "Add button") {
                Button("Add Custom Key") {
                    addCustomKeyButton()
                }
                .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)

                Divider()

                ForEach(GameButton.customSlots) { button in
                    Button("Add \(button.displayName)") {
                        addCustomKeyButton(mappedTo: button, label: GamepadCustomization.defaultVisualLabel(for: button))
                    }
                    .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
                }
            }

            toolbarMenu(systemImage: "pencil.tip", accessibilityLabel: "Style tools") {
                ForEach(GamepadAccentStyle.allCases) { style in
                    Button(style.displayName) {
                        update { $0.accentStyle = style }
                    }
                }
            }

            toolbarMenu(systemImage: "textformat", accessibilityLabel: "Text tools") {
                Button("Add Labeled Key") {
                    addCustomKeyButton(label: "Label")
                }
                .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)

                if case .custom = selectedControlID {
                    Button("Edit Label in Inspector") {}
                        .disabled(true)
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

            ScrollView {
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

            Label(selectedControlTitle, systemImage: "scope")
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

    private var selectedElementInspector: some View {
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

            if let shortcutButton = selectedShortcutButton,
               let selectedKeyBindingContent {
                Divider()
                selectedKeyBindingContent(shortcutButton)
            }
        }
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
            componentStateControls

            if case .custom(let id) = selectedControlID,
               customButton(id: id) != nil {
                Button("Delete Custom Key") {
                    update { $0.removeCustomButton(id: id) }
                    selectedControlID = .builtin(.jump)
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
                    GamepadCustomization.defaultVisualLabel(for: button),
                    text: labelBinding(for: button)
                )
                .geistInput(size: .small)
                Text("Leave blank to use the default keypad label.")
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
        let colorValue = selectedFillColorValue(for: selectedControlID)
        let usesCustomColor = selectedLayoutCustomization(for: selectedControlID).fillColor != nil

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Color")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            HStack(spacing: Geist.Spacing.s3) {
                ColorPicker("Fill", selection: fillColorPickerBinding(for: selectedControlID), supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Fill")
                        .geistTypography(.label13)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text(usesCustomColor ? "Custom color" : "Using selected preset")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }

                Spacer(minLength: Geist.Spacing.s2)

                Circle()
                    .fill(colorValue.swiftUIColor)
                    .overlay(Circle().stroke(Geist.color(.grayAlpha500, scheme: colorScheme), lineWidth: 1))
                    .frame(width: 28, height: 28)
            }

            HStack(spacing: Geist.Spacing.s2) {
                colorTextField(title: "Hex", value: fillColorHexBinding(for: selectedControlID), unit: nil)
                colorTextField(title: "Alpha", value: fillColorAlphaTextBinding(for: selectedControlID), unit: "%")
            }

            valueSlider(
                title: "Opacity",
                value: fillColorOpacityBinding(for: selectedControlID),
                range: 0...1,
                valueText: colorValue.opacityPercentageText
            )

            Button("Use Default Color") {
                clearCustomFillColor(for: selectedControlID)
            }
            .geistButtonStyle(.tertiary, size: .small)
            .disabled(!usesCustomColor)

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Presets")
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .textCase(.uppercase)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: Geist.Spacing.s2)], alignment: .leading, spacing: Geist.Spacing.s2) {
                    ForEach(GamepadAccentStyle.allCases) { style in
                        elementColorSwatch(style)
                    }
                }
            }
        }
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

    private func elementColorSwatch(_ style: GamepadAccentStyle) -> some View {
        let layoutCustomization = selectedLayoutCustomization(for: selectedControlID)
        let isSelected = layoutCustomization.fillColor == nil && accentStyleValue(for: selectedControlID) == style
        let inheritsDefault = layoutCustomization.accentStyle == nil && customization.accentStyle == style && layoutCustomization.fillColor == nil

        return Button {
            accentStyleBinding(for: selectedControlID).wrappedValue = style
        } label: {
            HStack(spacing: Geist.Spacing.s2) {
                Circle()
                    .fill(style.buttonFill(isPressed: false, scheme: colorScheme))
                    .overlay(Circle().stroke(style.buttonStroke(isPressed: false, scheme: colorScheme), lineWidth: 1))
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
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Position & Size")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                metricField(title: "X", value: frameMetricBinding(.x), unit: "pt")
                metricField(title: "Y", value: frameMetricBinding(.y), unit: "pt")
                metricField(title: "W", value: frameMetricBinding(.width), unit: "pt")
                metricField(title: "H", value: frameMetricBinding(.height), unit: "pt")
            }

            Text("X and Y use the component’s top-left point on the canvas.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            sizeSlider(title: "Width", value: widthScaleBinding(for: selectedControlID), currentValue: widthScaleValue(for: selectedControlID))
            sizeSlider(title: "Height", value: heightScaleBinding(for: selectedControlID), currentValue: heightScaleValue(for: selectedControlID))
        }
    }

    private func metricField(title: String, value: Binding<Double>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
            Text(title)
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            HStack(spacing: Geist.Spacing.s1) {
                TextField(title, value: value, format: .number.precision(.fractionLength(0)))
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
    }

    private var selectedElementRadiusSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Corners")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            GeistSegmentedPicker(title: "Shape", options: GamepadButtonShapeStyle.allCases, selection: shapeBinding(for: selectedControlID)) { shape in
                shape.displayName
            }

            if shapeValue(for: selectedControlID) == .roundedRectangle {
                valueSlider(
                    title: "All",
                    value: uniformCornerRadiusBinding(for: selectedControlID),
                    range: Double(GamepadButtonCustomization.minimumCornerRadius)...Double(GamepadButtonCustomization.maximumCornerRadius),
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
                Text("Capsule and circle presets calculate their radius automatically.")
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

    private var controlSelectionOptions: [GamepadControlIdentity] {
        GameButton.builtInControls.map { GamepadControlIdentity.builtin($0) }
            + customization.customButtons.map { GamepadControlIdentity.custom($0.id) }
    }

    private var componentListItems: [GamepadEditorComponentItem] {
        let builtinItems = GameButton.builtInControls.map { button -> GamepadEditorComponentItem in
            let buttonCustomization = customization.buttonCustomization(for: button)
            return GamepadEditorComponentItem(
                identity: .builtin(button),
                title: button.displayName,
                subtitle: customization.visualLabel(for: button),
                isCustom: false,
                isHidden: buttonCustomization.isHidden,
                isLocationLocked: buttonCustomization.isLocationLocked
            )
        }

        let customItems = customization.customButtons.map { customButton -> GamepadEditorComponentItem in
            let normalizedButton = customButton.normalized
            return GamepadEditorComponentItem(
                identity: .custom(normalizedButton.id),
                title: normalizedButton.visualLabel(fallback: customization.visualLabel(for: normalizedButton.mappedButton)),
                subtitle: "Custom → \(normalizedButton.mappedButton.displayName)",
                isCustom: true,
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
            guard let customButton = customButton(id: id) else { return "Custom Key" }
            return customButton.visualLabel(fallback: customization.visualLabel(for: customButton.mappedButton))
        }
    }

    @ViewBuilder
    private func customButtonControls(id: UUID) -> some View {
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

            TextField("Custom label", text: customLabelBinding(id: id))
                .geistInput(size: .small)

            Text("Custom slots are mapped to shortcuts in PocketPad Mac → Keypad.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
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

    private var selectedControlTitle: String {
        switch selectedControlID {
        case .builtin(let button):
            return button.displayName
        case .custom(let id):
            guard let customButton = customButton(id: id) else { return "Custom key" }
            return "Custom \(customButton.visualLabel(fallback: customization.visualLabel(for: customButton.mappedButton)))"
        }
    }

    private var selectedShortcutButton: GameButton? {
        switch selectedControlID {
        case .builtin(let button):
            return button
        case .custom(let id):
            return customButton(id: id)?.mappedButton
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
                    buttonCustomization.accentStyle = style == customization.accentStyle ? nil : style
                }
            }
        )
    }

    private func accentStyleValue(for identity: GamepadControlIdentity) -> GamepadAccentStyle {
        selectedLayoutCustomization(for: identity).accentStyle ?? customization.accentStyle
    }

    private func selectedFillColorValue(for identity: GamepadControlIdentity) -> GamepadRGBAColor {
        if let fillColor = selectedLayoutCustomization(for: identity).fillColor {
            return fillColor.normalized
        }
        let fallbackColor = accentStyleValue(for: identity).buttonFill(isPressed: false, scheme: colorScheme)
        return GamepadRGBAColor(color: fallbackColor, fallback: .defaultValue).normalized
    }

    private func fillColorPickerBinding(for identity: GamepadControlIdentity) -> Binding<Color> {
        Binding(
            get: { selectedFillColorValue(for: identity).swiftUIColor },
            set: { color in
                let fallback = selectedFillColorValue(for: identity)
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.fillColor = GamepadRGBAColor(color: color, fallback: fallback).normalized
                }
            }
        )
    }

    private func fillColorHexBinding(for identity: GamepadControlIdentity) -> Binding<String> {
        Binding(
            get: { selectedFillColorValue(for: identity).hexString },
            set: { hexString in
                let currentColor = selectedFillColorValue(for: identity)
                guard let parsedColor = GamepadRGBAColor(hexString: hexString, alpha: currentColor.alpha) else { return }
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.fillColor = parsedColor.normalized
                }
            }
        )
    }

    private func fillColorAlphaTextBinding(for identity: GamepadControlIdentity) -> Binding<String> {
        Binding(
            get: { "\(Int((selectedFillColorValue(for: identity).alpha * 100).rounded()))" },
            set: { alphaString in
                guard let alphaValue = Double(alphaString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                let normalizedAlpha = Self.clamp(CGFloat(alphaValue / 100), lower: 0, upper: 1)
                var color = selectedFillColorValue(for: identity)
                color.alpha = normalizedAlpha
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.fillColor = color.normalized
                }
            }
        )
    }

    private func fillColorOpacityBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(selectedFillColorValue(for: identity).alpha) },
            set: { opacity in
                var color = selectedFillColorValue(for: identity)
                color.alpha = Self.clamp(CGFloat(opacity), lower: 0, upper: 1)
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.fillColor = color.normalized
                }
            }
        )
    }

    private func clearCustomFillColor(for identity: GamepadControlIdentity) {
        updateLayoutCustomization(for: identity) { buttonCustomization in
            buttonCustomization.fillColor = nil
        }
    }

    private func uniformCornerRadiusBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(uniformCornerRadiusValue(for: identity)) },
            set: { newValue in
                let clampedValue = GamepadButtonCustomization.clamp(
                    CGFloat(newValue),
                    lower: GamepadButtonCustomization.minimumCornerRadius,
                    upper: GamepadButtonCustomization.maximumCornerRadius
                )
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.shape = .roundedRectangle
                    buttonCustomization.cornerRadius = nil
                    buttonCustomization.cornerRadii = abs(clampedValue - GamepadButtonCustomization.defaultCornerRadius) < 0.001 ? nil : .uniform(clampedValue)
                }
            }
        )
    }

    private func uniformCornerRadiusValue(for identity: GamepadControlIdentity) -> CGFloat {
        selectedLayoutCustomization(for: identity).resolvedCornerRadii().averageRadius
    }

    private func cornerRadiusBinding(for identity: GamepadControlIdentity, corner: GamepadCorner) -> Binding<Double> {
        Binding(
            get: { Double(cornerRadiiValue(for: identity)[corner]) },
            set: { newValue in
                var radii = cornerRadiiValue(for: identity)
                radii[corner] = CGFloat(newValue)
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.shape = .roundedRectangle
                    buttonCustomization.cornerRadius = nil
                    buttonCustomization.cornerRadii = radii.isUniform(equalTo: GamepadButtonCustomization.defaultCornerRadius) ? nil : radii.normalized
                }
            }
        )
    }

    private func cornerRadiiValue(for identity: GamepadControlIdentity) -> GamepadCornerRadii {
        selectedLayoutCustomization(for: identity).resolvedCornerRadii()
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
                        $0.setButtonCustomization(buttonCustomization, for: button)
                    }
                case .custom(let id):
                    updateCustomButton(id: id) { $0.layout.shape = shape }
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
        let baseWidth = max(1, control.size.width / max(layout.widthScale, 0.001))
        let baseHeight = max(1, control.size.height / max(layout.heightScale, 0.001))
        let minWidth = baseWidth * GamepadButtonCustomization.minimumScale
        let minHeight = baseHeight * GamepadButtonCustomization.minimumScale
        let maxWidth = min(currentCanvasLayoutSize.width, baseWidth * GamepadButtonCustomization.maximumScale)
        let maxHeight = min(currentCanvasLayoutSize.height, baseHeight * GamepadButtonCustomization.maximumScale)
        let clampedWidth = Self.clamp(frame.width, lower: minWidth, upper: maxWidth)
        let clampedHeight = Self.clamp(frame.height, lower: minHeight, upper: maxHeight)
        let clampedX = Self.clamp(frame.minX, lower: 0, upper: max(0, currentCanvasLayoutSize.width - clampedWidth))
        let clampedY = Self.clamp(frame.minY, lower: 0, upper: max(0, currentCanvasLayoutSize.height - clampedHeight))
        let center = CGPoint(x: clampedX + clampedWidth / 2, y: clampedY + clampedHeight / 2)

        updateLayoutCustomization(for: control.id) { buttonCustomization in
            buttonCustomization.widthScale = clampedWidth / baseWidth
            buttonCustomization.heightScale = clampedHeight / baseHeight
            buttonCustomization.centerX = center.x / max(currentCanvasLayoutSize.width, 1)
            buttonCustomization.centerY = center.y / max(currentCanvasLayoutSize.height, 1)
        }
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
                switch identity {
                case .builtin(let button):
                    update {
                        var buttonCustomization = $0.buttonCustomization(for: button)
                        buttonCustomization[keyPath: keyPath] = CGFloat(newValue)
                        $0.setButtonCustomization(buttonCustomization, for: button)
                    }
                case .custom(let id):
                    updateCustomButton(id: id) { $0.layout[keyPath: keyPath] = CGFloat(newValue) }
                }
            }
        )
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
            updateCustomButton(id: id) {
                $0.label = "Extra"
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

    private func customButton(id: UUID) -> GamepadCustomButton? {
        customization.customButtons.first { $0.id == id }
    }

    private func updateCustomButton(id: UUID, mutate: (inout GamepadCustomButton) -> Void) {
        update {
            guard let index = $0.customButtons.firstIndex(where: { $0.id == id }) else { return }
            mutate(&$0.customButtons[index])
        }
    }

    private func addCustomKeyButton(mappedTo mappedButton: GameButton? = nil, label: String? = nil) {
        guard customization.customButtons.count < GamepadCustomization.maximumCustomButtons else { return }
        let id = UUID()
        update { next in
            next.addCustomButton(id: id, mappedTo: mappedButton)
            guard let index = next.customButtons.firstIndex(where: { $0.id == id }) else { return }
            if let label {
                next.customButtons[index].label = label
            }
        }
        selectedControlID = .custom(id)
    }

    private func resetKeyLayout() {
        update { $0.resetButtonLayout() }
        selectedControlID = .builtin(.jump)
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
            selectedControlID = .builtin(.jump)
        }
    }

    private func update(_ mutate: (inout GamepadCustomization) -> Void) {
        var next = customization
        mutate(&next)
        applyCustomization(next)
    }

    private func applyCustomization(_ nextCustomization: GamepadCustomization) {
        let normalizedCustomization = nextCustomization.normalized
        customization = normalizedCustomization
        syncSelectedProfile(with: normalizedCustomization)
    }

    private func createProfile() {
        let profile = GamepadConfigurationProfile(
            name: "Setup \(profiles.count + 1)",
            customization: GamepadCustomization.blankCanvas
        )
        profiles.append(profile)
        selectedProfileID = profile.id
        isSelectedProfileExpanded = true
        selectedControlID = .builtin(.jump)
        applyCustomization(profile.customization)
        persistProfiles()
    }

    private func duplicateProfile() {
        let sourceName = selectedProfile?.name ?? "Setup"
        let duplicate = GamepadConfigurationProfile(
            name: "\(sourceName) Copy",
            customization: customization.normalized
        )
        profiles.append(duplicate)
        selectedProfileID = duplicate.id
        isSelectedProfileExpanded = true
        persistProfiles()
    }

    private func deleteSelectedProfile() {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == selectedProfileID }

        guard let nextProfile = profiles.first else { return }
        selectedProfileID = nextProfile.id
        isSelectedProfileExpanded = true
        selectedControlID = .builtin(.jump)
        applyCustomization(nextProfile.customization)
        persistProfiles()
    }

    private func selectProfile(_ profile: GamepadConfigurationProfile) {
        selectedProfileID = profile.id
        isSelectedProfileExpanded = true
        selectedControlID = .builtin(.jump)
        applyCustomization(profile.customization)
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
        defaultProfileID = selectedProfileID
        persistProfiles()
    }

    private func resetActiveConfiguration() {
        applyCustomization(.defaultValue)
        selectedControlID = .builtin(.jump)
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
        if !controlSelectionOptions.contains(selectedControlID) {
            selectedControlID = .builtin(.jump)
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
        GamepadConfigurationProfilePersistence.save(
            state.profiles,
            activeProfileID: state.activeProfileID,
            defaultProfileID: state.defaultProfileID
        )
        onProfilesChanged?(state.profiles, state.activeProfileID, state.defaultProfileID)
    }

    private func profileSubtitle(for customization: GamepadCustomization) -> String {
        var components = [
            customization.layoutMode.displayName,
            customization.controlScale.displayName,
            customization.accentStyle.displayName
        ]

        if customization.usesFreeformLayout {
            components.append("Freeform")
        }

        return components.joined(separator: " · ")
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

private struct GamepadLayoutDesigner: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var customization: GamepadCustomization
    @Binding var selectedControlID: GamepadControlIdentity
    var layoutSize: CGSize?
    var displayScale: CGFloat = 1
    @State private var activeDrag: GamepadControlDragState?
    @State private var activeResize: GamepadControlResizeState?
    @State private var activeRadiusDrag: GamepadControlRadiusDragState?

    private static let dragActivationDistance: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let resolvedLayoutSize = resolvedLayoutSize(for: proxy.size)
            let resolvedDisplayScale = max(displayScale, 0.001)
            let controls = customization.resolvedControls(in: resolvedLayoutSize)

            ZStack {
                RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                    .fill(Geist.color(.gray100, scheme: colorScheme))
                layoutGrid

                ForEach(controls) { control in
                    let isSelected = selectedControlID == control.id

                    GamepadDesignerButton(
                        control: control,
                        customization: customization,
                        isSelected: isSelected,
                        displayScale: resolvedDisplayScale,
                        onResizeChanged: { corner, value in
                            selectedControlID = control.id
                            guard !control.isLocationLocked else { return }
                            updateResize(corner, value: value, control: control, canvasSize: resolvedLayoutSize, displayScale: resolvedDisplayScale)
                        },
                        onResizeEnded: {
                            activeResize = nil
                        },
                        onRadiusChanged: { value in
                            selectedControlID = control.id
                            updateRadius(value, control: control, displayScale: resolvedDisplayScale)
                        },
                        onRadiusEnded: {
                            activeRadiusDrag = nil
                        }
                    )
                    .scaleEffect(resolvedDisplayScale)
                    .position(
                        x: control.center.x * resolvedDisplayScale,
                        y: control.center.y * resolvedDisplayScale
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
                            .onChanged { value in
                                selectedControlID = control.id
                                guard !control.isLocationLocked else { return }

                                if activeDrag?.identity != control.id {
                                    activeDrag = GamepadControlDragState(identity: control.id, startCenter: control.center)
                                }

                                guard Self.isExplicitDrag(value.translation) else { return }

                                let startCenter = activeDrag?.startCenter ?? control.center
                                let proposedCenter = CGPoint(
                                    x: startCenter.x + value.translation.width / resolvedDisplayScale,
                                    y: startCenter.y + value.translation.height / resolvedDisplayScale
                                )
                                updatePosition(proposedCenter, control: control, canvasSize: resolvedLayoutSize)
                            }
                            .onEnded { _ in
                                activeDrag = nil
                            }
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
            )
            .coordinateSpace(name: "gamepadLayoutDesigner")
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

    private func updatePosition(_ point: CGPoint, control: GamepadResolvedControl, canvasSize: CGSize) {
        let normalizedPosition = GamepadLayoutResolver.normalizedPosition(for: point, visualSize: control.size, in: canvasSize)
        var next = customization
        next.setPosition(normalizedPosition, for: control.id)
        customization = next.normalized
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

        guard let activeResize else { return }

        let baseWidth = max(1, activeResize.startSize.width / max(activeResize.startWidthScale, 0.001))
        let baseHeight = max(1, activeResize.startSize.height / max(activeResize.startHeightScale, 0.001))
        let minWidth = baseWidth * GamepadButtonCustomization.minimumScale
        let minHeight = baseHeight * GamepadButtonCustomization.minimumScale
        let maxWidth = min(canvasSize.width, baseWidth * GamepadButtonCustomization.maximumScale)
        let maxHeight = min(canvasSize.height, baseHeight * GamepadButtonCustomization.maximumScale)
        let translation = CGSize(
            width: value.translation.width / max(displayScale, 0.001),
            height: value.translation.height / max(displayScale, 0.001)
        )
        let startRect = CGRect(
            x: activeResize.startCenter.x - activeResize.startSize.width / 2,
            y: activeResize.startCenter.y - activeResize.startSize.height / 2,
            width: activeResize.startSize.width,
            height: activeResize.startSize.height
        )
        let resizedRect = resizedFrame(
            from: startRect,
            corner: corner,
            translation: translation,
            minSize: CGSize(width: minWidth, height: minHeight),
            maxSize: CGSize(width: maxWidth, height: maxHeight),
            canvasSize: canvasSize
        )
        let newSize: CGSize
        if activeResize.shape == .circle {
            let side = min(resizedRect.width, resizedRect.height)
            newSize = CGSize(width: side, height: side)
        } else {
            newSize = resizedRect.size
        }
        let newCenter = CGPoint(x: resizedRect.midX, y: resizedRect.midY)

        updateLayoutCustomization(for: control.id) { layout in
            layout.widthScale = newSize.width / baseWidth
            layout.heightScale = newSize.height / baseHeight
            layout.centerX = newCenter.x / max(canvasSize.width, 1)
            layout.centerY = newCenter.y / max(canvasSize.height, 1)
        }
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

    private func updateRadius(_ value: DragGesture.Value, control: GamepadResolvedControl, displayScale: CGFloat) {
        guard control.shape == .roundedRectangle else { return }
        let currentRadii = layoutCustomization(for: control.id).resolvedCornerRadii()
        if activeRadiusDrag?.identity != control.id {
            activeRadiusDrag = GamepadControlRadiusDragState(identity: control.id, startRadius: currentRadii.averageRadius)
        }

        guard let activeRadiusDrag else { return }
        let diagonalDelta = (value.translation.width + value.translation.height) / 2 / max(displayScale, 0.001)
        let maximumRadius = min(GamepadButtonCustomization.maximumCornerRadius, min(control.size.width, control.size.height) / 2)
        let nextRadius = Self.clamp(activeRadiusDrag.startRadius + diagonalDelta, lower: GamepadButtonCustomization.minimumCornerRadius, upper: maximumRadius)

        updateLayoutCustomization(for: control.id) { layout in
            layout.shape = .roundedRectangle
            layout.cornerRadius = nil
            layout.cornerRadii = abs(nextRadius - GamepadButtonCustomization.defaultCornerRadius) < 0.001 ? nil : .uniform(nextRadius)
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

private struct GamepadControlDragState {
    let identity: GamepadControlIdentity
    let startCenter: CGPoint
}

private struct GamepadControlResizeState {
    let identity: GamepadControlIdentity
    let startCenter: CGPoint
    let startSize: CGSize
    let startWidthScale: CGFloat
    let startHeightScale: CGFloat
    let shape: GamepadButtonShapeStyle
}

private struct GamepadControlRadiusDragState {
    let identity: GamepadControlIdentity
    let startRadius: CGFloat
}

private struct GamepadDesignerButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let control: GamepadResolvedControl
    let customization: GamepadCustomization
    let isSelected: Bool
    let displayScale: CGFloat
    let onResizeChanged: (GamepadResizeHandleCorner, DragGesture.Value) -> Void
    let onResizeEnded: () -> Void
    let onRadiusChanged: (DragGesture.Value) -> Void
    let onRadiusEnded: () -> Void

    var body: some View {
        ZStack {
            background(isSelected: false)

            if customization.showsButtonLabels {
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
            if isSelected {
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
        control.layoutCustomization.resolvedCornerRadii()
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

            if control.shape == .roundedRectangle {
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

    @ViewBuilder
    private func background(isSelected: Bool) -> some View {
        let fillColor = isSelected ? Color.clear : control.layoutCustomization.buttonFill(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let strokeColor = isSelected ? Geist.color(.blue700, scheme: colorScheme) : control.layoutCustomization.buttonStroke(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let lineWidth: CGFloat = isSelected ? 3 : 1

        switch control.shape {
        case .roundedRectangle:
            UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)
                .fill(fillColor)
                .overlay(UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous).stroke(strokeColor, lineWidth: lineWidth))
        case .capsule:
            Capsule()
                .fill(fillColor)
                .overlay(Capsule().stroke(strokeColor, lineWidth: lineWidth))
        case .circle:
            Circle()
                .fill(fillColor)
                .overlay(Circle().stroke(strokeColor, lineWidth: lineWidth))
        }
    }
}

private struct GamepadCustomizationPreview: View {
    let customization: GamepadCustomization

    var body: some View {
        GamepadLayoutDesigner(
            customization: .constant(customization),
            selectedControlID: .constant(.builtin(.jump))
        )
    }
}
#endif
