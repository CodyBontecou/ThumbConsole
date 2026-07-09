import Foundation
import SwiftUI
import UniformTypeIdentifiers

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
        case .amber: "Slate"
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
        let clamped = GamepadRGBAColor(
            red: Self.clamp(red),
            green: Self.clamp(green),
            blue: Self.clamp(blue),
            alpha: Self.clamp(alpha)
        )
        return Self.replacingLegacyAmberWithGreyscale(clamped)
    }

    private static func replacingLegacyAmberWithGreyscale(_ color: GamepadRGBAColor) -> GamepadRGBAColor {
        let key = rgbKey(red: color.red, green: color.green, blue: color.blue)
        guard var replacement = legacyAmberGreyscaleColors[key] else { return color }
        replacement.alpha = color.alpha
        return replacement
    }

    private static func rgbKey(red: CGFloat, green: CGFloat, blue: CGFloat) -> UInt32 {
        let redByte = UInt32((Self.clamp(red) * 255).rounded())
        let greenByte = UInt32((Self.clamp(green) * 255).rounded())
        let blueByte = UInt32((Self.clamp(blue) * 255).rounded())
        return (redByte << 16) | (greenByte << 8) | blueByte
    }

    private static func rgbColor(_ rgb: UInt32) -> GamepadRGBAColor {
        GamepadRGBAColor(
            red: CGFloat((rgb >> 16) & 0xff) / 255,
            green: CGFloat((rgb >> 8) & 0xff) / 255,
            blue: CGFloat(rgb & 0xff) / 255,
            alpha: 1
        )
    }

    private static let legacyAmberGreyscaleColors: [UInt32: GamepadRGBAColor] = [
        0xFFF6DE: rgbColor(0xF5F5F5),
        0xFFF4CF: rgbColor(0xF5F5F5),
        0xFFF1C1: rgbColor(0xF5F5F5),
        0xFFDC73: rgbColor(0xD4D4D4),
        0xFFC543: rgbColor(0xD4D4D4),
        0xFFA600: rgbColor(0xA3A3A3),
        0xFFAE00: rgbColor(0xA3A3A3),
        0xFF9300: rgbColor(0x737373),
        0xAA4D00: rgbColor(0x525252),
        0x561900: rgbColor(0x262626),
        0x2A1700: rgbColor(0x1A1A1A),
        0x361900: rgbColor(0x1F1F1F),
        0x502800: rgbColor(0x292929),
        0x5B3000: rgbColor(0x2E2E2E),
        0x703E00: rgbColor(0x454545),
        0xED9A00: rgbColor(0x878787),
        0xFFF3D5: rgbColor(0xEDEDED),
        0xFDE68A: rgbColor(0xE5E7EB),
        0xD97706: rgbColor(0x9CA3AF),
        0x78350F: rgbColor(0x374151),
        0xFCD34D: rgbColor(0xF3F4F6),
        0xF59E0B: rgbColor(0xD1D5DB),
        0x451A03: rgbColor(0x111827),
        0xFACC15: rgbColor(0xD1D5DB),
        0xF97316: rgbColor(0x9CA3AF),
        0xEAB308: rgbColor(0xD1D5DB)
    ]

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

public enum GamepadGradientType: String, Codable, CaseIterable, Identifiable, Sendable {
    case linear
    case radial

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .linear: "Linear"
        case .radial: "Radial"
        }
    }
}

public struct GamepadGradientStop: Codable, Equatable, Sendable {
    public var offset: CGFloat
    public var color: GamepadRGBAColor

    public init(offset: CGFloat, color: GamepadRGBAColor) {
        self.offset = offset
        self.color = color
    }

    var normalized: GamepadGradientStop {
        GamepadGradientStop(offset: Self.clamp(offset), color: color.normalized)
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

public struct GamepadGradientFill: Codable, Equatable, Sendable {
    public var type: GamepadGradientType
    public var angleDegrees: CGFloat
    public var stops: [GamepadGradientStop]

    public init(
        type: GamepadGradientType = .linear,
        angleDegrees: CGFloat = 0,
        stops: [GamepadGradientStop]
    ) {
        self.type = type
        self.angleDegrees = angleDegrees
        self.stops = stops
    }

    static func defaultValue(baseColor: GamepadRGBAColor) -> GamepadGradientFill {
        let start = baseColor.normalized
        let end = start.mixed(with: GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: start.alpha), amount: 0.42)
        return GamepadGradientFill(
            type: .linear,
            angleDegrees: 0,
            stops: [
                GamepadGradientStop(offset: 0, color: start),
                GamepadGradientStop(offset: 1, color: end)
            ]
        )
    }

    var normalized: GamepadGradientFill {
        var normalizedStops = stops.map(\.normalized).sorted { lhs, rhs in lhs.offset < rhs.offset }
        if normalizedStops.isEmpty {
            normalizedStops = Self.defaultValue(baseColor: .defaultValue).stops
        } else if normalizedStops.count == 1 {
            let onlyStop = normalizedStops[0]
            normalizedStops = [
                GamepadGradientStop(offset: 0, color: onlyStop.color),
                GamepadGradientStop(offset: 1, color: onlyStop.color)
            ]
        }

        return GamepadGradientFill(
            type: type,
            angleDegrees: Self.normalizedAngle(angleDegrees),
            stops: normalizedStops
        )
    }

    var representativeColor: GamepadRGBAColor {
        let normalizedStops = normalized.stops
        guard !normalizedStops.isEmpty else { return .defaultValue }
        let total = normalizedStops.reduce(GamepadRGBAColor(red: 0, green: 0, blue: 0, alpha: 0)) { partial, stop in
            GamepadRGBAColor(
                red: partial.red + stop.color.normalized.red,
                green: partial.green + stop.color.normalized.green,
                blue: partial.blue + stop.color.normalized.blue,
                alpha: partial.alpha + stop.color.normalized.alpha
            )
        }
        let count = CGFloat(normalizedStops.count)
        return GamepadRGBAColor(red: total.red / count, green: total.green / count, blue: total.blue / count, alpha: total.alpha / count).normalized
    }

    private static func normalizedAngle(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized < 0 { normalized += 360 }
        return normalized
    }
}

public enum GamepadTilePattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case dots
    case grid
    case checker
    case diagonal

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dots: "Dots"
        case .grid: "Grid"
        case .checker: "Checker"
        case .diagonal: "Diagonal"
        }
    }

    var systemImage: String {
        switch self {
        case .dots: "circle.grid.3x3"
        case .grid: "tablecells"
        case .checker: "checkerboard.rectangle"
        case .diagonal: "line.diagonal"
        }
    }
}

public enum GamepadTileAlignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case topLeading
    case top
    case topTrailing
    case leading
    case center
    case trailing
    case bottomLeading
    case bottom
    case bottomTrailing

    public var id: String { rawValue }
}

public struct GamepadTileFill: Codable, Equatable, Sendable {
    public var pattern: GamepadTilePattern
    public var foregroundColor: GamepadRGBAColor
    public var backgroundColor: GamepadRGBAColor
    public var scale: CGFloat
    public var spacingX: CGFloat
    public var spacingY: CGFloat
    public var alignment: GamepadTileAlignment
    public var opacity: CGFloat

    public init(
        pattern: GamepadTilePattern = .dots,
        foregroundColor: GamepadRGBAColor = GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: 1),
        backgroundColor: GamepadRGBAColor = GamepadRGBAColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1),
        scale: CGFloat = 1,
        spacingX: CGFloat = 0,
        spacingY: CGFloat = 0,
        alignment: GamepadTileAlignment = .topLeading,
        opacity: CGFloat = 1
    ) {
        self.pattern = pattern
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.scale = scale
        self.spacingX = spacingX
        self.spacingY = spacingY
        self.alignment = alignment
        self.opacity = opacity
    }

    static func defaultValue(baseColor: GamepadRGBAColor) -> GamepadTileFill {
        let base = baseColor.normalized
        return GamepadTileFill(
            pattern: .dots,
            foregroundColor: base.foregroundRGBAColor(alpha: 0.78),
            backgroundColor: base,
            scale: 1,
            spacingX: 0,
            spacingY: 0,
            alignment: .topLeading,
            opacity: 1
        )
    }

    var normalized: GamepadTileFill {
        GamepadTileFill(
            pattern: pattern,
            foregroundColor: foregroundColor.normalized,
            backgroundColor: backgroundColor.normalized,
            scale: Self.clamp(scale, lower: 0.25, upper: 4),
            spacingX: Self.clamp(spacingX, lower: 0, upper: 2),
            spacingY: Self.clamp(spacingY, lower: 0, upper: 2),
            alignment: alignment,
            opacity: Self.clamp(opacity, lower: 0, upper: 1)
        )
    }

    var representativeColor: GamepadRGBAColor {
        backgroundColor.normalized.mixed(with: foregroundColor.normalized, amount: 0.28).withAlpha(opacity)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }
}

public enum GamepadImageContentMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case fill
    case fit
    case tile

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fill: "Fill"
        case .fit: "Fit"
        case .tile: "Tile"
        }
    }
}

public struct GamepadImageFill: Codable, Equatable, Sendable {
    public static let maximumStoredBytes = 2_500_000

    public var data: Data?
    public var fileName: String?
    public var contentMode: GamepadImageContentMode
    public var opacity: CGFloat
    public var exposure: CGFloat
    public var contrast: CGFloat
    public var saturation: CGFloat
    public var temperature: CGFloat
    public var tint: CGFloat
    public var highlights: CGFloat
    public var shadows: CGFloat

    public init(
        data: Data? = nil,
        fileName: String? = nil,
        contentMode: GamepadImageContentMode = .fill,
        opacity: CGFloat = 1,
        exposure: CGFloat = 0,
        contrast: CGFloat = 0,
        saturation: CGFloat = 0,
        temperature: CGFloat = 0,
        tint: CGFloat = 0,
        highlights: CGFloat = 0,
        shadows: CGFloat = 0
    ) {
        self.data = data
        self.fileName = fileName
        self.contentMode = contentMode
        self.opacity = opacity
        self.exposure = exposure
        self.contrast = contrast
        self.saturation = saturation
        self.temperature = temperature
        self.tint = tint
        self.highlights = highlights
        self.shadows = shadows
    }

    var normalized: GamepadImageFill {
        var copy = self
        if let data, data.count > Self.maximumStoredBytes {
            copy.data = nil
        }
        copy.opacity = Self.clamp(opacity, lower: 0, upper: 1)
        copy.exposure = Self.clamp(exposure, lower: -1, upper: 1)
        copy.contrast = Self.clamp(contrast, lower: -1, upper: 1)
        copy.saturation = Self.clamp(saturation, lower: -1, upper: 1)
        copy.temperature = Self.clamp(temperature, lower: -1, upper: 1)
        copy.tint = Self.clamp(tint, lower: -1, upper: 1)
        copy.highlights = Self.clamp(highlights, lower: -1, upper: 1)
        copy.shadows = Self.clamp(shadows, lower: -1, upper: 1)
        return copy
    }

    var representativeColor: GamepadRGBAColor {
        GamepadRGBAColor(red: 0.12, green: 0.12, blue: 0.14, alpha: opacity).normalized
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
    }
}

public enum GamepadFillStyle: Equatable, Sendable {
    case solid(GamepadRGBAColor)
    case gradient(GamepadGradientFill)
    case tile(GamepadTileFill)
    case image(GamepadImageFill)

    var normalized: GamepadFillStyle {
        switch self {
        case .solid(let color): .solid(color.normalized)
        case .gradient(let gradient): .gradient(gradient.normalized)
        case .tile(let tile): .tile(tile.normalized)
        case .image(let image): .image(image.normalized)
        }
    }

    var displayName: String {
        switch self {
        case .solid: "Solid"
        case .gradient(let gradient): gradient.type.displayName
        case .tile(let tile): tile.pattern.displayName
        case .image(let image): image.fileName?.isEmpty == false ? image.fileName! : "Image"
        }
    }

    var representativeColor: GamepadRGBAColor {
        switch normalized {
        case .solid(let color): color
        case .gradient(let gradient): gradient.representativeColor
        case .tile(let tile): tile.representativeColor
        case .image(let image): image.representativeColor
        }
    }

    func withOpacity(_ opacity: CGFloat) -> GamepadFillStyle {
        let opacity = min(max(opacity, 0), 1)
        switch normalized {
        case .solid(var color):
            color.alpha = opacity
            return .solid(color.normalized)
        case .gradient(var gradient):
            gradient.stops = gradient.stops.map { stop in
                var color = stop.color
                color.alpha = opacity
                return GamepadGradientStop(offset: stop.offset, color: color.normalized)
            }
            return .gradient(gradient.normalized)
        case .tile(var tile):
            tile.opacity = opacity
            return .tile(tile.normalized)
        case .image(var image):
            image.opacity = opacity
            return .image(image.normalized)
        }
    }

    func adjustedForPress(_ isPressed: Bool) -> GamepadFillStyle {
        guard isPressed else { return normalized }
        switch normalized {
        case .solid(let color):
            return .solid(color.adjustedForPress(true))
        case .gradient(var gradient):
            gradient.stops = gradient.stops.map { GamepadGradientStop(offset: $0.offset, color: $0.color.adjustedForPress(true)) }
            return .gradient(gradient.normalized)
        case .tile(var tile):
            tile.foregroundColor = tile.foregroundColor.adjustedForPress(true)
            tile.backgroundColor = tile.backgroundColor.adjustedForPress(true)
            return .tile(tile.normalized)
        case .image(let image):
            return .image(image.normalized)
        }
    }
}

extension GamepadFillStyle: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case color
        case gradient
        case tile
        case image
    }

    private enum Kind: String, Codable {
        case solid
        case gradient
        case tile
        case image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .solid:
            self = .solid(try container.decode(GamepadRGBAColor.self, forKey: .color).normalized)
        case .gradient:
            self = .gradient(try container.decode(GamepadGradientFill.self, forKey: .gradient).normalized)
        case .tile:
            self = .tile(try container.decode(GamepadTileFill.self, forKey: .tile).normalized)
        case .image:
            self = .image(try container.decode(GamepadImageFill.self, forKey: .image).normalized)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .solid(let color):
            try container.encode(Kind.solid, forKey: .kind)
            try container.encode(color, forKey: .color)
        case .gradient(let gradient):
            try container.encode(Kind.gradient, forKey: .kind)
            try container.encode(gradient, forKey: .gradient)
        case .tile(let tile):
            try container.encode(Kind.tile, forKey: .kind)
            try container.encode(tile, forKey: .tile)
        case .image(let image):
            try container.encode(Kind.image, forKey: .kind)
            try container.encode(image, forKey: .image)
        }
    }
}

private extension GamepadRGBAColor {
    func mixed(with other: GamepadRGBAColor, amount: CGFloat) -> GamepadRGBAColor {
        let amount = min(max(amount, 0), 1)
        let lhs = normalized
        let rhs = other.normalized
        return GamepadRGBAColor(
            red: lhs.red + (rhs.red - lhs.red) * amount,
            green: lhs.green + (rhs.green - lhs.green) * amount,
            blue: lhs.blue + (rhs.blue - lhs.blue) * amount,
            alpha: lhs.alpha + (rhs.alpha - lhs.alpha) * amount
        ).normalized
    }

    func withAlpha(_ alpha: CGFloat) -> GamepadRGBAColor {
        GamepadRGBAColor(red: normalized.red, green: normalized.green, blue: normalized.blue, alpha: min(max(alpha, 0), 1))
    }

    func foregroundRGBAColor(alpha: CGFloat = 1) -> GamepadRGBAColor {
        let normalized = normalized
        let luminance = 0.299 * normalized.red + 0.587 * normalized.green + 0.114 * normalized.blue
        if luminance > 0.56 {
            return GamepadRGBAColor(red: 0, green: 0, blue: 0, alpha: alpha).normalized
        }
        return GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: alpha).normalized
    }
}

public struct GamepadDeviceCanvas: Codable, Equatable, Sendable {
    public static let defaultFrameID = "iphone-17-pro-landscape"
    public static let defaultValue = GamepadDeviceCanvas()

    public var frameID: String

    public init(frameID: String = GamepadDeviceCanvas.defaultFrameID) {
        self.frameID = frameID
    }

    var normalized: GamepadDeviceCanvas {
        let trimmedFrameID = frameID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let frame = GamepadEditorDeviceCatalog.frame(forStoredID: trimmedFrameID),
              !trimmedFrameID.isEmpty
        else {
            return .defaultValue
        }
        return GamepadDeviceCanvas(frameID: frame.id)
    }

    var editorDeviceFrame: GamepadEditorDeviceFrame {
        GamepadEditorDeviceCatalog.frame(forStoredID: frameID) ?? GamepadEditorDeviceCatalog.defaultFrame
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
        GamepadButtonCustomization.normalizedCornerRadius(value)
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
    case trigger
    case trackpad
    case decoration

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .button: "Button"
        case .joystick: "Joystick"
        case .trigger: "Trigger"
        case .trackpad: "Trackpad"
        case .decoration: "Decoration"
        }
    }
}

public struct GamepadTrackpadSettings: Codable, Equatable, Sendable {
    public static let minimumSensitivity: CGFloat = 0.2
    public static let maximumSensitivity: CGFloat = 4.0
    public static let minimumScrollSensitivity: CGFloat = 0.1
    public static let maximumScrollSensitivity: CGFloat = 4.0
    public static let defaultValue = GamepadTrackpadSettings()

    public var sensitivity: CGFloat
    public var scrollSensitivity: CGFloat
    public var tapToClick: Bool
    public var twoFingerScroll: Bool
    public var naturalScrolling: Bool

    public init(
        sensitivity: CGFloat = 1.2,
        scrollSensitivity: CGFloat = 0.85,
        tapToClick: Bool = true,
        twoFingerScroll: Bool = true,
        naturalScrolling: Bool = true
    ) {
        self.sensitivity = sensitivity
        self.scrollSensitivity = scrollSensitivity
        self.tapToClick = tapToClick
        self.twoFingerScroll = twoFingerScroll
        self.naturalScrolling = naturalScrolling
    }

    public var normalized: GamepadTrackpadSettings {
        GamepadTrackpadSettings(
            sensitivity: Self.clamp(sensitivity, lower: Self.minimumSensitivity, upper: Self.maximumSensitivity),
            scrollSensitivity: Self.clamp(scrollSensitivity, lower: Self.minimumScrollSensitivity, upper: Self.maximumScrollSensitivity),
            tapToClick: tapToClick,
            twoFingerScroll: twoFingerScroll,
            naturalScrolling: naturalScrolling
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), upper)
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

public enum GamepadJoystickVisualStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case pad
    case thumbstick

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pad: "Full pad"
        case .thumbstick: "Thumbstick"
        }
    }

    var description: String {
        switch self {
        case .pad: "A fixed joystick pad with a visible travel well."
        case .thumbstick: "A compact center nub with an invisible drag range, like the small ball between face buttons."
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
    public static let minimumDimension: CGFloat = 1
    public static let minimumScale: CGFloat = 0.001
    public static let maximumScale: CGFloat = 12.0
    public static let minimumCornerRadius: CGFloat = 0
    public static let capsulePreviewCornerRadius: CGFloat = 240
    @available(*, deprecated, message: "Corner radii are unbounded; use capsulePreviewCornerRadius only for fixed-size capsule previews.")
    public static let maximumCornerRadius: CGFloat = capsulePreviewCornerRadius
    public static let defaultCornerRadius: CGFloat = 6
    public static let minimumShadowStrength: CGFloat = 0
    public static let maximumShadowStrength: CGFloat = 2
    public static let defaultShadowStrength: CGFloat = 1
    public static let minimumZIndex = -100
    public static let maximumZIndex = 100
    public static let defaultValue = GamepadButtonCustomization()

    public var centerX: CGFloat?
    public var centerY: CGFloat?
    public var widthScale: CGFloat
    public var heightScale: CGFloat
    public var rotationDegrees: CGFloat
    public var zIndex: Int
    public var shape: GamepadButtonShapeStyle?
    public var accentStyle: GamepadAccentStyle?
    /// Legacy/global fill color used by keypads saved before light/dark-specific colors existed.
    public var fillColor: GamepadRGBAColor?
    public var lightFillColor: GamepadRGBAColor?
    public var darkFillColor: GamepadRGBAColor?
    /// Global non-solid fill used when a profile wants one fill across color schemes.
    public var fillStyle: GamepadFillStyle?
    public var lightFillStyle: GamepadFillStyle?
    public var darkFillStyle: GamepadFillStyle?
    /// Optional joystick thumb/knob color. When unset, joystick thumbs use the element foreground color.
    public var joystickKnobColor: GamepadRGBAColor?
    public var lightJoystickKnobColor: GamepadRGBAColor?
    public var darkJoystickKnobColor: GamepadRGBAColor?
    /// Joystick-only visual style. `nil` keeps the legacy full-pad appearance.
    public var joystickVisualStyle: GamepadJoystickVisualStyle?
    public var styleID: String?
    public var visualStyle: GamepadControlVisualStyle?
    public var icon: GamepadControlIcon?
    public var hapticStyle: GamepadHapticStyle?
    public var hapticFeedback: GamepadHapticFeedback?
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
        zIndex: Int = 0,
        shape: GamepadButtonShapeStyle? = nil,
        accentStyle: GamepadAccentStyle? = nil,
        fillColor: GamepadRGBAColor? = nil,
        lightFillColor: GamepadRGBAColor? = nil,
        darkFillColor: GamepadRGBAColor? = nil,
        fillStyle: GamepadFillStyle? = nil,
        lightFillStyle: GamepadFillStyle? = nil,
        darkFillStyle: GamepadFillStyle? = nil,
        joystickKnobColor: GamepadRGBAColor? = nil,
        lightJoystickKnobColor: GamepadRGBAColor? = nil,
        darkJoystickKnobColor: GamepadRGBAColor? = nil,
        joystickVisualStyle: GamepadJoystickVisualStyle? = nil,
        styleID: String? = nil,
        visualStyle: GamepadControlVisualStyle? = nil,
        icon: GamepadControlIcon? = nil,
        hapticStyle: GamepadHapticStyle? = nil,
        hapticFeedback: GamepadHapticFeedback? = nil,
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
        self.zIndex = Self.normalizedZIndex(zIndex)
        self.shape = shape
        self.accentStyle = accentStyle
        self.fillColor = fillColor
        self.lightFillColor = lightFillColor
        self.darkFillColor = darkFillColor
        self.fillStyle = fillStyle
        self.lightFillStyle = lightFillStyle
        self.darkFillStyle = darkFillStyle
        self.joystickKnobColor = joystickKnobColor
        self.lightJoystickKnobColor = lightJoystickKnobColor
        self.darkJoystickKnobColor = darkJoystickKnobColor
        self.joystickVisualStyle = joystickVisualStyle
        self.styleID = styleID
        self.visualStyle = visualStyle
        self.icon = icon
        self.hapticStyle = hapticStyle
        self.hapticFeedback = hapticFeedback
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
        zIndex = Self.normalizedZIndex(try container.decodeIfPresent(Int.self, forKey: .zIndex) ?? 0)
        shape = try container.decodeIfPresent(GamepadButtonShapeStyle.self, forKey: .shape)
        accentStyle = try container.decodeIfPresent(GamepadAccentStyle.self, forKey: .accentStyle)
        fillColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .fillColor)
        lightFillColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .lightFillColor)
        darkFillColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .darkFillColor)
        fillStyle = try container.decodeIfPresent(GamepadFillStyle.self, forKey: .fillStyle)
        lightFillStyle = try container.decodeIfPresent(GamepadFillStyle.self, forKey: .lightFillStyle)
        darkFillStyle = try container.decodeIfPresent(GamepadFillStyle.self, forKey: .darkFillStyle)
        joystickKnobColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .joystickKnobColor)
        lightJoystickKnobColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .lightJoystickKnobColor)
        darkJoystickKnobColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .darkJoystickKnobColor)
        joystickVisualStyle = try container.decodeIfPresent(GamepadJoystickVisualStyle.self, forKey: .joystickVisualStyle)
        styleID = try container.decodeIfPresent(String.self, forKey: .styleID)
        visualStyle = try container.decodeIfPresent(GamepadControlVisualStyle.self, forKey: .visualStyle)
        icon = try container.decodeIfPresent(GamepadControlIcon.self, forKey: .icon)
        hapticStyle = try container.decodeIfPresent(GamepadHapticStyle.self, forKey: .hapticStyle)
        hapticFeedback = try container.decodeIfPresent(GamepadHapticFeedback.self, forKey: .hapticFeedback)
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
        try container.encode(zIndex, forKey: .zIndex)
        try container.encodeIfPresent(shape, forKey: .shape)
        try container.encodeIfPresent(accentStyle, forKey: .accentStyle)
        try container.encodeIfPresent(fillColor, forKey: .fillColor)
        try container.encodeIfPresent(lightFillColor, forKey: .lightFillColor)
        try container.encodeIfPresent(darkFillColor, forKey: .darkFillColor)
        try container.encodeIfPresent(fillStyle, forKey: .fillStyle)
        try container.encodeIfPresent(lightFillStyle, forKey: .lightFillStyle)
        try container.encodeIfPresent(darkFillStyle, forKey: .darkFillStyle)
        try container.encodeIfPresent(joystickKnobColor?.normalized, forKey: .joystickKnobColor)
        try container.encodeIfPresent(lightJoystickKnobColor?.normalized, forKey: .lightJoystickKnobColor)
        try container.encodeIfPresent(darkJoystickKnobColor?.normalized, forKey: .darkJoystickKnobColor)
        try container.encodeIfPresent(joystickVisualStyle, forKey: .joystickVisualStyle)
        try container.encodeIfPresent(styleID, forKey: .styleID)
        try container.encodeIfPresent(visualStyle, forKey: .visualStyle)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(hapticStyle, forKey: .hapticStyle)
        try container.encodeIfPresent(hapticFeedback, forKey: .hapticFeedback)
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
        copy.zIndex = Self.normalizedZIndex(copy.zIndex)
        copy.fillColor = copy.fillColor?.normalized
        copy.lightFillColor = copy.lightFillColor?.normalized
        copy.darkFillColor = copy.darkFillColor?.normalized
        copy.fillStyle = copy.fillStyle?.normalized
        copy.lightFillStyle = copy.lightFillStyle?.normalized
        copy.darkFillStyle = copy.darkFillStyle?.normalized
        copy.joystickKnobColor = copy.joystickKnobColor?.normalized
        copy.lightJoystickKnobColor = copy.lightJoystickKnobColor?.normalized
        copy.darkJoystickKnobColor = copy.darkJoystickKnobColor?.normalized
        if copy.joystickVisualStyle == .pad { copy.joystickVisualStyle = nil }
        let normalizedStyleID = copy.styleID.map(GamepadStyleToken.normalizedIdentifier) ?? ""
        copy.styleID = normalizedStyleID.isEmpty ? nil : normalizedStyleID
        copy.visualStyle = copy.visualStyle?.normalized
        copy.icon = copy.icon?.normalized
        copy.hapticFeedback = copy.hapticFeedback?.normalized
        if copy.hapticFeedback?.isDefault == true {
            copy.hapticFeedback = nil
        }
        let defaultCornerRadius = Self.defaultCornerRadius(for: copy.shape)
        let usesDynamicCornerRadiusDefault = copy.shape?.usesDynamicEditableCornerRadiusDefault == true
        if let cornerRadii = copy.cornerRadii {
            let normalizedRadii = cornerRadii.normalized
            copy.cornerRadii = !usesDynamicCornerRadiusDefault && normalizedRadii.isUniform(equalTo: defaultCornerRadius) ? nil : normalizedRadii
            copy.cornerRadius = nil
        } else if let cornerRadius = copy.cornerRadius {
            let normalizedRadius = Self.normalizedCornerRadius(cornerRadius)
            copy.cornerRadius = !usesDynamicCornerRadiusDefault && abs(normalizedRadius - defaultCornerRadius) < 0.001 ? nil : normalizedRadius
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
            && zIndex == 0
            && shape == nil
            && accentStyle == nil
            && fillColor == nil
            && lightFillColor == nil
            && darkFillColor == nil
            && fillStyle == nil
            && lightFillStyle == nil
            && darkFillStyle == nil
            && joystickKnobColor == nil
            && lightJoystickKnobColor == nil
            && darkJoystickKnobColor == nil
            && joystickVisualStyle == nil
            && styleID == nil
            && visualStyle == nil
            && icon == nil
            && hapticStyle == nil
            && hapticFeedback == nil
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
            || zIndex != 0
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
        if let explicitFillStyle = fillStyle(for: scheme), case .solid(let color) = explicitFillStyle {
            return color.normalized
        }
        return nil
    }

    func fillStyle(for scheme: ColorScheme) -> GamepadFillStyle? {
        switch scheme {
        case .dark:
            if let darkFillStyle { return darkFillStyle.normalized }
            if let fillStyle { return fillStyle.normalized }
            if let darkFillColor { return .solid(darkFillColor.normalized) }
            if let fillColor { return .solid(fillColor.normalized) }
            return nil
        default:
            if let lightFillStyle { return lightFillStyle.normalized }
            if let fillStyle { return fillStyle.normalized }
            if let lightFillColor { return .solid(lightFillColor.normalized) }
            if let fillColor { return .solid(fillColor.normalized) }
            return nil
        }
    }

    func hasCustomFillColor(for scheme: ColorScheme) -> Bool {
        fillStyle(for: scheme) != nil
    }

    func joystickKnobColor(for scheme: ColorScheme) -> GamepadRGBAColor? {
        switch scheme {
        case .dark:
            darkJoystickKnobColor?.normalized ?? joystickKnobColor?.normalized
        default:
            lightJoystickKnobColor?.normalized ?? joystickKnobColor?.normalized
        }
    }

    func hasCustomJoystickKnobColor(for scheme: ColorScheme) -> Bool {
        joystickKnobColor(for: scheme) != nil
    }

    var resolvedHapticFeedback: GamepadHapticFeedback {
        if let hapticFeedback {
            return hapticFeedback.normalized
        }
        return GamepadHapticFeedback(style: hapticStyle ?? .light).normalized
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

    static func minimumDimension(forBaseDimension baseDimension: CGFloat) -> CGFloat {
        max(Self.minimumDimension, baseDimension * Self.minimumScale)
    }

    static func normalizedCornerRadius(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return minimumCornerRadius }
        return max(value, minimumCornerRadius)
    }

    static func normalizedRotationDegrees(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        var normalized = value.truncatingRemainder(dividingBy: 360)
        if normalized > 180 { normalized -= 360 }
        if normalized <= -180 { normalized += 360 }
        return abs(normalized) < 0.001 ? 0 : normalized
    }

    static func normalizedZIndex(_ value: Int) -> Int {
        min(max(value, minimumZIndex), maximumZIndex)
    }

    static func normalizedZIndex(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return normalizedZIndex(Int(value.rounded()))
    }

    private enum CodingKeys: String, CodingKey {
        case centerX
        case centerY
        case widthScale
        case heightScale
        case rotationDegrees
        case zIndex
        case shape
        case accentStyle
        case fillColor
        case lightFillColor
        case darkFillColor
        case fillStyle
        case lightFillStyle
        case darkFillStyle
        case joystickKnobColor
        case lightJoystickKnobColor
        case darkJoystickKnobColor
        case joystickVisualStyle
        case styleID
        case visualStyle
        case icon
        case hapticStyle
        case hapticFeedback
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
            return max(GamepadButtonCustomization.minimumCornerRadius, min(size.width, size.height) / 2)
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
    public var joystickOutputSettings: GamepadJoystickOutputSettings?
    public var triggerSettings: GamepadTriggerSettings?
    public var trackpadSettings: GamepadTrackpadSettings?

    public init(
        id: UUID = UUID(),
        mappedButton: GameButton = .custom1,
        label: String = "Button",
        layout: GamepadButtonCustomization = GamepadButtonCustomization(
            centerX: 0.5,
            centerY: 0.5,
            widthScale: 1.0,
            heightScale: 1.0,
            shape: .roundedRectangle
        ),
        controlKind: GamepadCustomControlKind = .button,
        joystickMapping: GamepadJoystickMapping? = nil,
        joystickOutputSettings: GamepadJoystickOutputSettings? = nil,
        triggerSettings: GamepadTriggerSettings? = nil,
        trackpadSettings: GamepadTrackpadSettings? = nil
    ) {
        self.id = id
        self.mappedButton = mappedButton
        self.label = label
        self.layout = layout
        self.controlKind = controlKind
        self.joystickMapping = joystickMapping
        self.joystickOutputSettings = joystickOutputSettings
        self.triggerSettings = triggerSettings
        self.trackpadSettings = trackpadSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        mappedButton = try container.decodeIfPresent(GameButton.self, forKey: .mappedButton) ?? .custom1
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? "Button"
        layout = try container.decodeIfPresent(GamepadButtonCustomization.self, forKey: .layout) ?? GamepadButtonCustomization(
            centerX: 0.5,
            centerY: 0.5,
            widthScale: 1.0,
            heightScale: 1.0,
            shape: .roundedRectangle
        )
        controlKind = try container.decodeIfPresent(GamepadCustomControlKind.self, forKey: .controlKind) ?? .button
        joystickMapping = try container.decodeIfPresent(GamepadJoystickMapping.self, forKey: .joystickMapping)
        joystickOutputSettings = try container.decodeIfPresent(GamepadJoystickOutputSettings.self, forKey: .joystickOutputSettings)
        triggerSettings = try container.decodeIfPresent(GamepadTriggerSettings.self, forKey: .triggerSettings)
        trackpadSettings = try container.decodeIfPresent(GamepadTrackpadSettings.self, forKey: .trackpadSettings)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(mappedButton, forKey: .mappedButton)
        try container.encode(label, forKey: .label)
        try container.encode(layout, forKey: .layout)
        try container.encode(controlKind, forKey: .controlKind)
        try container.encodeIfPresent(joystickMapping, forKey: .joystickMapping)
        try container.encodeIfPresent(joystickOutputSettings?.normalized, forKey: .joystickOutputSettings)
        try container.encodeIfPresent(triggerSettings?.normalized, forKey: .triggerSettings)
        try container.encodeIfPresent(trackpadSettings?.normalized, forKey: .trackpadSettings)
    }

    var normalized: GamepadCustomButton {
        var copy = self
        copy.label = normalizedGamepadLabel(copy.label)
        copy.layout = copy.layout.normalized
        if copy.layout.centerX == nil { copy.layout.centerX = 0.5 }
        if copy.layout.centerY == nil { copy.layout.centerY = 0.5 }
        switch copy.controlKind {
        case .joystick:
            copy.joystickMapping = copy.joystickMapping ?? .movement
            copy.joystickOutputSettings = (copy.joystickOutputSettings ?? .defaultValue).normalized
            copy.triggerSettings = nil
            copy.trackpadSettings = nil
            copy.layout.shape = .circle
            if copy.label.isEmpty { copy.label = "Joystick" }
        case .trigger:
            copy.joystickMapping = nil
            copy.joystickOutputSettings = nil
            copy.triggerSettings = (copy.triggerSettings ?? .defaultValue).normalized
            copy.trackpadSettings = nil
            if copy.layout.shape == nil { copy.layout.shape = .capsule }
            if copy.label.isEmpty { copy.label = copy.triggerSettings?.target.shortName ?? "Trigger" }
        case .trackpad:
            copy.joystickMapping = nil
            copy.joystickOutputSettings = nil
            copy.triggerSettings = nil
            copy.trackpadSettings = (copy.trackpadSettings ?? .defaultValue).normalized
            if copy.layout.shape == nil { copy.layout.shape = .roundedRectangle }
            if copy.label.isEmpty { copy.label = "Trackpad" }
        case .button:
            copy.joystickMapping = nil
            copy.joystickOutputSettings = nil
            copy.triggerSettings = nil
            copy.trackpadSettings = nil
            if copy.layout.shape == nil { copy.layout.shape = .roundedRectangle }
        case .decoration:
            copy.joystickMapping = nil
            copy.joystickOutputSettings = nil
            copy.triggerSettings = nil
            copy.trackpadSettings = nil
            if copy.layout.shape == nil { copy.layout.shape = .roundedRectangle }
            if copy.label.isEmpty { copy.label = "Decoration" }
        }
        return copy
    }

    var isJoystick: Bool {
        controlKind == .joystick
    }

    var isTrigger: Bool {
        controlKind == .trigger
    }

    var isTrackpad: Bool {
        controlKind == .trackpad
    }

    var isDecoration: Bool {
        controlKind == .decoration
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
        case joystickOutputSettings
        case triggerSettings
        case trackpadSettings
    }
}

public struct KeypadElement: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var label: String
    public var kind: GamepadCustomControlKind
    public var layout: GamepadButtonCustomization
    public var builtInButton: GameButton?
    public var legacySlot: GameButton?
    public var output: KeypadElementOutputBinding?
    public var partOutputs: [KeypadElementInputPart: KeypadElementOutputBinding]
    public var joystickMapping: GamepadJoystickMapping?
    public var joystickOutputSettings: GamepadJoystickOutputSettings?
    public var triggerSettings: GamepadTriggerSettings?
    public var trackpadSettings: GamepadTrackpadSettings?

    public init(
        id: UUID = UUID(),
        label: String = "Button",
        kind: GamepadCustomControlKind = .button,
        layout: GamepadButtonCustomization = GamepadButtonCustomization(
            centerX: 0.5,
            centerY: 0.5,
            widthScale: 1.0,
            heightScale: 1.0,
            shape: .roundedRectangle
        ),
        builtInButton: GameButton? = nil,
        legacySlot: GameButton? = nil,
        output: KeypadElementOutputBinding? = nil,
        partOutputs: [KeypadElementInputPart: KeypadElementOutputBinding] = [:],
        joystickMapping: GamepadJoystickMapping? = nil,
        joystickOutputSettings: GamepadJoystickOutputSettings? = nil,
        triggerSettings: GamepadTriggerSettings? = nil,
        trackpadSettings: GamepadTrackpadSettings? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.layout = layout
        self.builtInButton = builtInButton
        self.legacySlot = legacySlot
        self.output = output
        self.partOutputs = partOutputs
        self.joystickMapping = joystickMapping
        self.joystickOutputSettings = joystickOutputSettings
        self.triggerSettings = triggerSettings
        self.trackpadSettings = trackpadSettings
    }

    public var normalized: KeypadElement {
        normalized(layoutIsAlreadyNormalized: false)
    }

    fileprivate func normalized(layoutIsAlreadyNormalized: Bool) -> KeypadElement {
        var copy = self
        copy.label = normalizedGamepadLabel(label)
        if !layoutIsAlreadyNormalized {
            copy.layout = layout.normalized
        }
        copy.output = output?.isEmpty == true ? nil : output
        copy.partOutputs = partOutputs.compactMapValues { $0.isEmpty ? nil : $0 }

        switch copy.kind {
        case .joystick:
            copy.joystickMapping = copy.joystickMapping ?? .movement
            copy.joystickOutputSettings = (copy.joystickOutputSettings ?? .defaultValue).normalized
            copy.triggerSettings = nil
            copy.trackpadSettings = nil
            copy.layout.shape = .circle
            if copy.label.isEmpty { copy.label = "Joystick" }
        case .trigger:
            copy.joystickMapping = nil
            copy.joystickOutputSettings = nil
            copy.triggerSettings = (copy.triggerSettings ?? .defaultValue).normalized
            copy.trackpadSettings = nil
            if copy.layout.shape == nil { copy.layout.shape = .capsule }
            if copy.label.isEmpty { copy.label = copy.triggerSettings?.target.shortName ?? "Trigger" }
        case .trackpad:
            copy.joystickMapping = nil
            copy.joystickOutputSettings = nil
            copy.triggerSettings = nil
            copy.trackpadSettings = (copy.trackpadSettings ?? .defaultValue).normalized
            if copy.layout.shape == nil { copy.layout.shape = .roundedRectangle }
            if copy.label.isEmpty { copy.label = "Trackpad" }
        case .button:
            copy.joystickMapping = nil
            copy.joystickOutputSettings = nil
            copy.triggerSettings = nil
            copy.trackpadSettings = nil
            if copy.layout.shape == nil { copy.layout.shape = .roundedRectangle }
            if copy.label.isEmpty { copy.label = copy.legacySlot.map(GamepadCustomization.defaultVisualLabel(for:)) ?? "Button" }
        case .decoration:
            copy.output = nil
            copy.partOutputs.removeAll()
            copy.joystickMapping = nil
            copy.joystickOutputSettings = nil
            copy.triggerSettings = nil
            copy.trackpadSettings = nil
            if copy.layout.shape == nil { copy.layout.shape = .roundedRectangle }
            if copy.label.isEmpty { copy.label = "Decoration" }
        }

        return copy
    }

    fileprivate var synchronizationMetadata: KeypadElement {
        KeypadElement(
            id: id,
            label: normalizedGamepadLabel(label),
            kind: kind,
            layout: .defaultValue,
            builtInButton: builtInButton,
            legacySlot: legacySlot,
            output: output?.isEmpty == true ? nil : output,
            partOutputs: partOutputs.compactMapValues { $0.isEmpty ? nil : $0 },
            joystickMapping: joystickMapping,
            joystickOutputSettings: joystickOutputSettings,
            triggerSettings: triggerSettings,
            trackpadSettings: trackpadSettings
        )
    }

    public func outputBinding(for part: KeypadElementInputPart = .primary) -> KeypadElementOutputBinding? {
        part == .primary ? output : partOutputs[part]
    }

    public mutating func setOutputBinding(_ binding: KeypadElementOutputBinding?, for part: KeypadElementInputPart = .primary) {
        let normalizedBinding = binding?.isEmpty == true ? nil : binding
        if part == .primary {
            output = normalizedBinding
        } else {
            partOutputs[part] = normalizedBinding
        }
    }

    public static func builtInID(for button: GameButton) -> UUID {
        switch button {
        case .up: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        case .down: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        case .left: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
        case .right: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
        case .jump: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!
        case .attack: UUID(uuidString: "00000000-0000-0000-0000-000000000106")!
        case .dash: UUID(uuidString: "00000000-0000-0000-0000-000000000107")!
        case .focus: UUID(uuidString: "00000000-0000-0000-0000-000000000108")!
        case .map: UUID(uuidString: "00000000-0000-0000-0000-000000000109")!
        case .pause: UUID(uuidString: "00000000-0000-0000-0000-000000000110")!
        case .custom1: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
        case .custom2: UUID(uuidString: "00000000-0000-0000-0000-000000000112")!
        case .custom3: UUID(uuidString: "00000000-0000-0000-0000-000000000113")!
        case .custom4: UUID(uuidString: "00000000-0000-0000-0000-000000000114")!
        case .custom5: UUID(uuidString: "00000000-0000-0000-0000-000000000115")!
        case .custom6: UUID(uuidString: "00000000-0000-0000-0000-000000000116")!
        case .custom7: UUID(uuidString: "00000000-0000-0000-0000-000000000117")!
        case .custom8: UUID(uuidString: "00000000-0000-0000-0000-000000000118")!
        }
    }
}

public enum GamepadControlBarItem: String, Codable, CaseIterable, Identifiable, Sendable {
    case connectionStatus = "status"
    case profileMenu = "profile_menu"
    case launchTarget = "launch_target"
    case spacer
    case editLayout = "edit_layout"
    case settings
    case home
    case connectionAction = "connection"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .connectionStatus: "Connection Status"
        case .profileMenu: "Profile Picker"
        case .launchTarget: "Launch App"
        case .spacer: "Flexible Space"
        case .editLayout: "Edit Layout"
        case .settings: "Settings"
        case .home: "Home"
        case .connectionAction: "Connect / Disconnect"
        }
    }

    var shortName: String {
        switch self {
        case .connectionStatus: "Status"
        case .profileMenu: "Profiles"
        case .launchTarget: "Launch"
        case .spacer: "Spacer"
        case .editLayout: "Edit"
        case .settings: "Settings"
        case .home: "Home"
        case .connectionAction: "Connection"
        }
    }

    var subtitle: String {
        switch self {
        case .connectionStatus: "Shows whether the iPhone is paired with the Mac."
        case .profileMenu: "Lets users switch keypad setups from the iPhone."
        case .launchTarget: "Opens the Mac app attached to the selected setup."
        case .spacer: "Pushes the following controls to the far edge of the bar."
        case .editLayout: "Unlocks the on-device layout editor."
        case .settings: "Opens keypad appearance, feedback, and reset options."
        case .home: "Returns to the connection page."
        case .connectionAction: "Connects to or disconnects from the paired Mac."
        }
    }

    var systemImage: String {
        switch self {
        case .connectionStatus: "dot.radiowaves.left.and.right"
        case .profileMenu: "rectangle.grid.2x2"
        case .launchTarget: "app.badge.fill"
        case .spacer: "arrow.left.and.right"
        case .editLayout: "lock.open.fill"
        case .settings: "gearshape.fill"
        case .home: "house.fill"
        case .connectionAction: "link"
        }
    }
}

/// The visible control-bar chrome shared by the iPhone runtime and Mac editor preview.
/// Item content stays at the call site so the runtime can provide live menus and actions.
struct GamepadControlBarLayout<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let items: [GamepadControlBarItem]
    let isLandscape: Bool
    private let content: (GamepadControlBarItem, Bool) -> Content

    init(
        items: [GamepadControlBarItem],
        isLandscape: Bool,
        @ViewBuilder content: @escaping (GamepadControlBarItem, Bool) -> Content
    ) {
        self.items = items
        self.isLandscape = isLandscape
        self.content = content
    }

    @ViewBuilder
    var body: some View {
        if isLandscape {
            HStack(spacing: Geist.Spacing.s3) {
                ForEach(items) { item in
                    content(item, false)
                }
            }
            .padding(Geist.Spacing.s2)
            .background(Geist.color(.background100, scheme: colorScheme), in: Capsule())
            .overlay(Capsule().stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1))
        } else {
            HStack(spacing: Geist.Spacing.s2) {
                ForEach(items) { item in
                    content(item, true)
                }
            }
            .padding(Geist.Spacing.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Geist.color(.background100, scheme: colorScheme),
                in: RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
            )
        }
    }
}

private struct GamepadControlBarItemSurface<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let customization: GamepadCustomization
    let item: GamepadControlBarItem
    let state: GamepadControlPresentationState
    let baseHeight: CGFloat
    let baseHorizontalPadding: CGFloat
    let fallbackForeground: Color
    let fallbackBackground: Color
    let fallbackBorder: Color
    let fallbackBorderWidth: CGFloat
    let defaultCornerRadius: CGFloat
    let content: Content

    init(
        customization: GamepadCustomization,
        item: GamepadControlBarItem,
        state: GamepadControlPresentationState,
        baseHeight: CGFloat,
        baseHorizontalPadding: CGFloat,
        fallbackForeground: Color,
        fallbackBackground: Color,
        fallbackBorder: Color,
        fallbackBorderWidth: CGFloat,
        defaultCornerRadius: CGFloat = Geist.Radius.sm,
        @ViewBuilder content: () -> Content
    ) {
        self.customization = customization
        self.item = item
        self.state = state
        self.baseHeight = baseHeight
        self.baseHorizontalPadding = baseHorizontalPadding
        self.fallbackForeground = fallbackForeground
        self.fallbackBackground = fallbackBackground
        self.fallbackBorder = fallbackBorder
        self.fallbackBorderWidth = fallbackBorderWidth
        self.defaultCornerRadius = defaultCornerRadius
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        let appearance = customization.controlBarItemCustomization(for: item)
        let widthScale = GamepadButtonCustomization.clamp(appearance.widthScale, lower: 0.25, upper: 3)
        let heightScale = GamepadButtonCustomization.clamp(appearance.heightScale, lower: 0.5, upper: 2)
        let height = max(22, baseHeight * heightScale)
        let horizontalPadding = baseHorizontalPadding * widthScale

        if appearance.hasControlBarSurfaceOverrides {
            let presentation = customization.resolvedPresentation(
                for: appearance,
                fallbackAccentStyle: appearance.accentStyle ?? customization.accentStyle,
                controlKind: .button,
                state: state,
                scheme: colorScheme
            )
            let shape = resolvedShape(for: appearance, height: height, widthScale: widthScale)

            content
                .foregroundStyle(presentation.foregroundSwiftUIColor)
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .background(GamepadFillShapeLayer(shape: shape, fillStyle: presentation.fillStyle))
                .overlay(shape.stroke(presentation.strokeSwiftUIColor, lineWidth: presentation.strokeWidth))
                .overlay(GamepadControlEffectOverlay(shape: shape, presentation: presentation))
                .gamepadOuterShadows(presentation)
                .opacity(presentation.opacity)
                .blur(radius: presentation.blurRadius)
                .scaleEffect(presentation.scale)
                .contentShape(shape)
        } else {
            let shape = AnyShape(RoundedRectangle(cornerRadius: defaultCornerRadius, style: .continuous))
            content
                .foregroundStyle(fallbackForeground)
                .padding(.horizontal, horizontalPadding)
                .frame(height: height)
                .background(shape.fill(fallbackBackground))
                .overlay(shape.stroke(fallbackBorder, lineWidth: fallbackBorderWidth))
                .contentShape(shape)
        }
    }

    private func resolvedShape(
        for appearance: GamepadButtonCustomization,
        height: CGFloat,
        widthScale: CGFloat
    ) -> AnyShape {
        let shape = appearance.resolvedShape(defaultShape: .roundedRectangle)
        let estimatedSize = CGSize(width: max(32, 44 * widthScale), height: height)
        let radii = appearance.resolvedCornerRadii(defaultRadius: shape.defaultEditableCornerRadius(in: estimatedSize))
        switch shape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            return AnyShape(UnevenRoundedRectangle(cornerRadii: radii.rectangleCornerRadii, style: .continuous))
        case .polygon:
            return AnyShape(GamepadRegularPolygonButtonShape(sides: 3))
        case .star:
            return AnyShape(GamepadStarButtonShape(points: 5))
        }
    }
}

struct GamepadControlBarButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    let customization: GamepadCustomization
    let item: GamepadControlBarItem
    var variant: Geist.ButtonVariant = .secondary
    var size: Geist.ControlSize = .small

    func makeBody(configuration: Configuration) -> some View {
        let state: GamepadControlPresentationState = !isEnabled ? .disabled : (configuration.isPressed ? .pressed : .normal)
        return GamepadControlBarItemSurface(
            customization: customization,
            item: item,
            state: state,
            baseHeight: size.height,
            baseHorizontalPadding: size.horizontalPadding,
            fallbackForeground: fallbackForeground,
            fallbackBackground: fallbackBackground(isPressed: configuration.isPressed),
            fallbackBorder: fallbackBorder(isPressed: configuration.isPressed),
            fallbackBorderWidth: fallbackBorderWidth,
            defaultCornerRadius: item == .connectionAction && variant == .error ? 100 : Geist.Radius.sm
        ) {
            configuration.label
                .geistTypography(size.buttonTypography)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .gamepadControlBarHapticFeedback(
            customization.controlBarItemCustomization(for: item).resolvedHapticFeedback,
            isPressed: configuration.isPressed,
            isEnabled: isEnabled
        )
    }

    private var fallbackForeground: Color {
        guard isEnabled else { return Geist.color(.gray700, scheme: colorScheme) }
        return switch variant {
        case .primary: Geist.color(.background100, scheme: colorScheme)
        case .secondary, .tertiary: Geist.color(.gray1000, scheme: colorScheme)
        case .error: Color.white
        }
    }

    private func fallbackBackground(isPressed: Bool) -> Color {
        guard isEnabled else { return Geist.color(.gray100, scheme: colorScheme) }
        return switch variant {
        case .primary: isPressed ? Geist.color(.gray900, scheme: colorScheme) : Geist.color(.gray1000, scheme: colorScheme)
        case .secondary: isPressed ? Geist.color(.grayAlpha200, scheme: colorScheme) : Geist.color(.background100, scheme: colorScheme)
        case .tertiary: isPressed ? Geist.color(.grayAlpha200, scheme: colorScheme) : Color.clear
        case .error: isPressed ? Geist.color(.red900, scheme: colorScheme) : Geist.color(.red800, scheme: colorScheme)
        }
    }

    private var fallbackBorderWidth: CGFloat {
        variant == .secondary || !isEnabled ? 1 : 0
    }

    private func fallbackBorder(isPressed: Bool) -> Color {
        guard isEnabled else { return Geist.color(.grayAlpha400, scheme: colorScheme) }
        guard variant == .secondary else { return .clear }
        return isPressed ? Geist.color(.grayAlpha600, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme)
    }
}

#if os(iOS)
private struct GamepadControlBarHapticModifier: ViewModifier {
    let feedback: GamepadHapticFeedback
    let isPressed: Bool
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                if isEnabled { KeypadHapticPlayer.shared.prepare(feedback) }
            }
            .onChange(of: isPressed) { _, pressed in
                guard pressed, isEnabled else { return }
                KeypadHapticPlayer.shared.play(feedback)
            }
    }
}
#endif

private extension View {
    @ViewBuilder
    func gamepadControlBarHapticFeedback(
        _ feedback: GamepadHapticFeedback,
        isPressed: Bool,
        isEnabled: Bool
    ) -> some View {
#if os(iOS)
        modifier(GamepadControlBarHapticModifier(feedback: feedback, isPressed: isPressed, isEnabled: isEnabled))
#else
        self
#endif
    }
}

struct GamepadControlBarStatusPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let customization: GamepadCustomization
    let title: String
    let systemImage: String
    let tone: GeistInterfaceTone

    var body: some View {
        GamepadControlBarItemSurface(
            customization: customization,
            item: .connectionStatus,
            state: .normal,
            baseHeight: Geist.ControlSize.small.height,
            baseHorizontalPadding: Geist.Spacing.s3,
            fallbackForeground: tone.foreground(scheme: colorScheme),
            fallbackBackground: tone.background(scheme: colorScheme),
            fallbackBorder: tone.border(scheme: colorScheme),
            fallbackBorderWidth: 1,
            defaultCornerRadius: 100
        ) {
            Label {
                Text(title)
            } icon: {
                GamepadControlBarItemIcon(
                    customization: customization,
                    item: .connectionStatus,
                    defaultSystemImage: systemImage,
                    fontSize: 13
                )
            }
            .geistTypography(.label13)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }
}

struct GamepadControlBarItemIcon: View {
    let customization: GamepadCustomization
    let item: GamepadControlBarItem
    let defaultSystemImage: String
    var fontSize: CGFloat = 13
    var weight: Font.Weight = .semibold
    var frameWidth: CGFloat? = nil

    @ViewBuilder
    var body: some View {
        let icon = customization.controlBarItemCustomization(for: item).icon?.normalized
        if let tint = icon?.tintColor?.swiftUIColor {
            iconContent(icon)
                .foregroundStyle(tint)
        } else {
            iconContent(icon)
        }
    }

    @ViewBuilder
    private func iconContent(_ icon: GamepadControlIcon?) -> some View {
        Group {
            if let icon {
                switch icon.source {
                case .sfSymbol:
                    Image(systemName: icon.value)
                        .symbolRenderingMode(icon.renderingMode == .multicolor ? .multicolor : .monochrome)
                case .text:
                    Text(icon.value)
                case .asset:
                    Image(systemName: "photo")
                }
            } else {
                Image(systemName: defaultSystemImage)
            }
        }
        .font(.system(size: fontSize * (icon?.scale ?? 1), weight: weight))
        .frame(width: frameWidth)
    }
}

extension View {
    func gamepadControlBarButtonStyle(
        customization: GamepadCustomization,
        item: GamepadControlBarItem,
        variant: Geist.ButtonVariant = .secondary,
        size: Geist.ControlSize = .small
    ) -> some View {
        buttonStyle(GamepadControlBarButtonStyle(customization: customization, item: item, variant: variant, size: size))
    }
}

public struct GamepadControlBarItemCustomization: Codable, Equatable, Identifiable, Sendable {
    public var item: GamepadControlBarItem
    public var appearance: GamepadButtonCustomization

    public var id: GamepadControlBarItem { item }

    public init(item: GamepadControlBarItem, appearance: GamepadButtonCustomization = .defaultValue) {
        self.item = item
        self.appearance = appearance
    }

    var normalized: GamepadControlBarItemCustomization {
        var normalizedAppearance = appearance.normalized
        // Control-bar children are constrained by the bar layout rather than the
        // freeform canvas. Keep their visual and sizing properties, but discard
        // coordinates and layer-only properties that cannot affect the output.
        normalizedAppearance.centerX = nil
        normalizedAppearance.centerY = nil
        normalizedAppearance.rotationDegrees = 0
        normalizedAppearance.zIndex = 0
        normalizedAppearance.isLocationLocked = false
        normalizedAppearance.joystickKnobColor = nil
        normalizedAppearance.lightJoystickKnobColor = nil
        normalizedAppearance.darkJoystickKnobColor = nil
        normalizedAppearance.joystickVisualStyle = nil
        if item == .spacer {
            normalizedAppearance = GamepadButtonCustomization(
                widthScale: normalizedAppearance.widthScale,
                isHidden: normalizedAppearance.isHidden
            )
        }
        return GamepadControlBarItemCustomization(item: item, appearance: normalizedAppearance)
    }
}

private extension GamepadButtonCustomization {
    var hasControlBarSurfaceOverrides: Bool {
        shape != nil
            || accentStyle != nil
            || fillColor != nil
            || lightFillColor != nil
            || darkFillColor != nil
            || fillStyle != nil
            || lightFillStyle != nil
            || darkFillStyle != nil
            || styleID != nil
            || visualStyle != nil
            || cornerRadius != nil
            || cornerRadii != nil
            || abs(shadowStrength - GamepadButtonCustomization.defaultShadowStrength) > 0.001
    }
}

public struct GamepadCustomization: Codable, Equatable, Sendable {
    public static let maximumLabelLength = gamepadMaximumLabelLength
    public static let maximumCustomButtons = 64
    public static let maximumJoysticks = 2
    public static let maximumTriggers = 2
    public static let maximumTrackpads = 1
    public static let defaultTopBarActivationRegion = GamepadButtonCustomization(
        centerX: 0.5,
        centerY: 0.115,
        widthScale: 1.0,
        heightScale: 1.0,
        zIndex: GamepadButtonCustomization.maximumZIndex,
        shape: .capsule,
        accentStyle: .blue,
        icon: GamepadControlIcon.sfSymbol("chevron.down"),
        cornerRadius: 18,
        shadowStrength: 0.35
    )
    public static let defaultControlBarItems: [GamepadControlBarItem] = [
        .connectionStatus,
        .profileMenu,
        .launchTarget,
        .spacer,
        .editLayout,
        .settings,
        .home,
        .connectionAction
    ]
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
    public var deviceCanvas: GamepadDeviceCanvas
    public var backgroundLightColor: GamepadRGBAColor?
    public var backgroundDarkColor: GamepadRGBAColor?
    /// Global background fill used when one fill should apply across color schemes.
    public var backgroundFillStyle: GamepadFillStyle?
    public var backgroundLightFillStyle: GamepadFillStyle?
    public var backgroundDarkFillStyle: GamepadFillStyle?
    public var accentStyle: GamepadAccentStyle
    public var showsButtonLabels: Bool
    public var labelOverrides: [GameButton: String]
    public var buttonCustomizations: [GameButton: GamepadButtonCustomization]
    public var customButtons: [GamepadCustomButton]
    public var elements: [KeypadElement]
    public var topBarActivationRegion: GamepadButtonCustomization
    public var controlBarItems: [GamepadControlBarItem]
    public var controlBarItemCustomizations: [GamepadControlBarItemCustomization]
    public var designMetadata: GamepadDesignMetadata?
    public var styleLibrary: GamepadStyleLibrary
    public var assetLibrary: GamepadAssetLibrary
    public var updatedAt: Int64

    public init(
        layoutMode: GamepadLayoutMode = .standard,
        controlScale: GamepadControlScale = .standard,
        colorSchemePreference: GamepadColorSchemePreference = .system,
        deviceCanvas: GamepadDeviceCanvas = .defaultValue,
        backgroundLightColor: GamepadRGBAColor? = nil,
        backgroundDarkColor: GamepadRGBAColor? = nil,
        backgroundFillStyle: GamepadFillStyle? = nil,
        backgroundLightFillStyle: GamepadFillStyle? = nil,
        backgroundDarkFillStyle: GamepadFillStyle? = nil,
        accentStyle: GamepadAccentStyle = .monochrome,
        showsButtonLabels: Bool = true,
        labelOverrides: [GameButton: String] = [:],
        buttonCustomizations: [GameButton: GamepadButtonCustomization] = [:],
        customButtons: [GamepadCustomButton] = [],
        elements: [KeypadElement] = [],
        topBarActivationRegion: GamepadButtonCustomization = GamepadCustomization.defaultTopBarActivationRegion,
        controlBarItems: [GamepadControlBarItem] = GamepadCustomization.defaultControlBarItems,
        controlBarItemCustomizations: [GamepadControlBarItemCustomization] = [],
        designMetadata: GamepadDesignMetadata? = nil,
        styleLibrary: GamepadStyleLibrary = .empty,
        assetLibrary: GamepadAssetLibrary = .empty,
        updatedAt: Int64 = 0
    ) {
        self.layoutMode = layoutMode
        self.controlScale = controlScale
        self.colorSchemePreference = colorSchemePreference
        self.deviceCanvas = deviceCanvas
        self.backgroundLightColor = backgroundLightColor
        self.backgroundDarkColor = backgroundDarkColor
        self.backgroundFillStyle = backgroundFillStyle
        self.backgroundLightFillStyle = backgroundLightFillStyle
        self.backgroundDarkFillStyle = backgroundDarkFillStyle
        self.accentStyle = accentStyle
        self.showsButtonLabels = showsButtonLabels
        self.labelOverrides = labelOverrides
        self.buttonCustomizations = buttonCustomizations
        self.customButtons = customButtons
        self.elements = elements
        self.topBarActivationRegion = topBarActivationRegion
        self.controlBarItems = controlBarItems
        self.controlBarItemCustomizations = controlBarItemCustomizations
        self.designMetadata = designMetadata
        self.styleLibrary = styleLibrary
        self.assetLibrary = assetLibrary
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        layoutMode = try container.decodeIfPresent(GamepadLayoutMode.self, forKey: .layoutMode) ?? .standard
        controlScale = try container.decodeIfPresent(GamepadControlScale.self, forKey: .controlScale) ?? .standard
        colorSchemePreference = try container.decodeIfPresent(GamepadColorSchemePreference.self, forKey: .colorSchemePreference) ?? .system
        deviceCanvas = try container.decodeIfPresent(GamepadDeviceCanvas.self, forKey: .deviceCanvas) ?? .defaultValue
        backgroundLightColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .backgroundLightColor)
        backgroundDarkColor = try container.decodeIfPresent(GamepadRGBAColor.self, forKey: .backgroundDarkColor)
        backgroundFillStyle = try container.decodeIfPresent(GamepadFillStyle.self, forKey: .backgroundFillStyle)
        backgroundLightFillStyle = try container.decodeIfPresent(GamepadFillStyle.self, forKey: .backgroundLightFillStyle)
        backgroundDarkFillStyle = try container.decodeIfPresent(GamepadFillStyle.self, forKey: .backgroundDarkFillStyle)
        accentStyle = try container.decodeIfPresent(GamepadAccentStyle.self, forKey: .accentStyle) ?? .monochrome
        showsButtonLabels = try container.decodeIfPresent(Bool.self, forKey: .showsButtonLabels) ?? true
        labelOverrides = try container.decodeIfPresent([GameButton: String].self, forKey: .labelOverrides) ?? [:]
        buttonCustomizations = try container.decodeIfPresent([GameButton: GamepadButtonCustomization].self, forKey: .buttonCustomizations) ?? [:]
        customButtons = try container.decodeIfPresent([GamepadCustomButton].self, forKey: .customButtons) ?? []
        elements = try container.decodeIfPresent([KeypadElement].self, forKey: .elements) ?? []
        topBarActivationRegion = try container.decodeIfPresent(GamepadButtonCustomization.self, forKey: .topBarActivationRegion) ?? Self.defaultTopBarActivationRegion
        controlBarItems = try container.decodeIfPresent([GamepadControlBarItem].self, forKey: .controlBarItems) ?? Self.defaultControlBarItems
        controlBarItemCustomizations = try container.decodeIfPresent([GamepadControlBarItemCustomization].self, forKey: .controlBarItemCustomizations) ?? []
        designMetadata = try container.decodeIfPresent(GamepadDesignMetadata.self, forKey: .designMetadata)
        styleLibrary = try container.decodeIfPresent(GamepadStyleLibrary.self, forKey: .styleLibrary) ?? .empty
        assetLibrary = try container.decodeIfPresent(GamepadAssetLibrary.self, forKey: .assetLibrary) ?? .empty
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layoutMode, forKey: .layoutMode)
        try container.encode(controlScale, forKey: .controlScale)
        try container.encode(colorSchemePreference, forKey: .colorSchemePreference)
        try container.encode(deviceCanvas.normalized, forKey: .deviceCanvas)
        try container.encodeIfPresent(backgroundLightColor?.normalized, forKey: .backgroundLightColor)
        try container.encodeIfPresent(backgroundDarkColor?.normalized, forKey: .backgroundDarkColor)
        try container.encodeIfPresent(backgroundFillStyle?.normalized, forKey: .backgroundFillStyle)
        try container.encodeIfPresent(backgroundLightFillStyle?.normalized, forKey: .backgroundLightFillStyle)
        try container.encodeIfPresent(backgroundDarkFillStyle?.normalized, forKey: .backgroundDarkFillStyle)
        try container.encode(accentStyle, forKey: .accentStyle)
        try container.encode(showsButtonLabels, forKey: .showsButtonLabels)
        try container.encode(labelOverrides, forKey: .labelOverrides)
        try container.encode(buttonCustomizations, forKey: .buttonCustomizations)
        try container.encode(customButtons, forKey: .customButtons)
        let normalizedElements = synchronizedElements(migratesLegacySlots: elements.isEmpty, controlsAreNormalized: true)
        if !normalizedElements.isEmpty { try container.encode(normalizedElements, forKey: .elements) }
        let normalizedTopBarActivationRegion = topBarActivationRegion.normalized
        if normalizedTopBarActivationRegion != Self.defaultTopBarActivationRegion.normalized {
            try container.encode(normalizedTopBarActivationRegion, forKey: .topBarActivationRegion)
        }
        let normalizedControlBarItems = Self.normalizedControlBarItems(controlBarItems)
        if normalizedControlBarItems != Self.defaultControlBarItems {
            try container.encode(normalizedControlBarItems, forKey: .controlBarItems)
        }
        let normalizedControlBarItemCustomizations = normalized.controlBarItemCustomizations
        if !normalizedControlBarItemCustomizations.isEmpty {
            try container.encode(normalizedControlBarItemCustomizations, forKey: .controlBarItemCustomizations)
        }
        try container.encodeIfPresent(designMetadata?.normalized(availableControls: allControlIdentitiesForDesign), forKey: .designMetadata)
        if !styleLibrary.normalized.isEmpty { try container.encode(styleLibrary.normalized, forKey: .styleLibrary) }
        if !assetLibrary.normalized.isEmpty { try container.encode(assetLibrary.normalized, forKey: .assetLibrary) }
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
        if let index = elements.firstIndex(where: { $0.builtInButton == button }) {
            elements[index].label = normalizedLabel.isEmpty ? Self.defaultVisualLabel(for: button) : normalizedLabel
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
        if let index = elements.firstIndex(where: { $0.builtInButton == button }) {
            elements[index].layout = normalizedCustomization
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

        case .system(.topBarActivation):
            topBarActivationRegion.centerX = normalizedPosition.x
            topBarActivationRegion.centerY = normalizedPosition.y
        case .controlBarItem:
            break
        }
    }

    public mutating func addCustomButton(id: UUID = UUID(), mappedTo mappedButton: GameButton? = nil) {
        guard customButtons.count < Self.maximumCustomButtons else { return }
        let targetButton = mappedButton ?? firstAvailableCustomSlot() ?? .jump
        let customButton = GamepadCustomButton(
            id: id,
            mappedButton: targetButton,
            label: "Button",
            layout: GamepadButtonCustomization(
                centerX: 0.5,
                centerY: 0.5,
                widthScale: 1.0,
                heightScale: 1.0,
                shape: .roundedRectangle
            )
        )
        customButtons.append(customButton)
        upsertElementMirror(for: customButton, migratesLegacySlot: mappedButton != nil)
    }

    public mutating func addJoystick(
        id: UUID = UUID(),
        label: String? = nil,
        mapping: GamepadJoystickMapping? = nil,
        outputSettings: GamepadJoystickOutputSettings? = nil
    ) {
        let joystickCount = customButtons.filter { $0.normalized.isJoystick }.count
        guard customButtons.count < Self.maximumCustomButtons,
              joystickCount < Self.maximumJoysticks
        else { return }

        let isPrimaryJoystick = joystickCount == 0
        let resolvedMapping = mapping ?? (isPrimaryJoystick ? .movement : .secondary)
        let resolvedOutputSettings = (outputSettings ?? .defaultValue).normalized
        let resolvedLabel = label ?? Self.defaultJoystickLabel(
            isPrimaryJoystick: isPrimaryJoystick,
            outputSettings: resolvedOutputSettings
        )
        let customButton = GamepadCustomButton(
            id: id,
            mappedButton: resolvedMapping.up,
            label: resolvedLabel,
            layout: GamepadButtonCustomization(
                centerX: isPrimaryJoystick ? 0.22 : 0.78,
                centerY: 0.64,
                widthScale: 1.35,
                heightScale: 1.35,
                shape: .circle,
                accentStyle: isPrimaryJoystick ? .blue : .purple
            ),
            controlKind: .joystick,
            joystickMapping: resolvedMapping,
            joystickOutputSettings: resolvedOutputSettings
        )
        customButtons.append(customButton)
        upsertElementMirror(for: customButton, migratesLegacySlot: false)
    }

    private static func defaultJoystickLabel(
        isPrimaryJoystick: Bool,
        outputSettings: GamepadJoystickOutputSettings
    ) -> String {
        switch outputSettings.normalized.analogTarget {
        case .none:
            return isPrimaryJoystick ? "Arrow Keys" : "Directions"
        case .leftStick:
            return "Left Stick"
        case .rightStick:
            return "Right Stick"
        }
    }

    public mutating func addTrigger(id: UUID = UUID(), target: VirtualGamepadTrigger? = nil, mappedTo mappedButton: GameButton? = nil) {
        let triggerCount = customButtons.filter { $0.normalized.isTrigger }.count
        guard customButtons.count < Self.maximumCustomButtons,
              triggerCount < Self.maximumTriggers
        else { return }

        let resolvedTarget = target ?? (triggerCount == 0 ? .left : .right)
        let customButton = GamepadCustomButton(
            id: id,
            mappedButton: mappedButton ?? firstAvailableCustomSlot() ?? .custom1,
            label: resolvedTarget.shortName,
            layout: GamepadButtonCustomization(
                centerX: resolvedTarget == .left ? 0.20 : 0.80,
                centerY: 0.14,
                widthScale: 1.08,
                heightScale: 0.42,
                shape: .capsule,
                accentStyle: .monochrome
            ),
            controlKind: .trigger,
            triggerSettings: GamepadTriggerSettings(target: resolvedTarget, orientation: .horizontal)
        )
        customButtons.append(customButton)
        upsertElementMirror(for: customButton, migratesLegacySlot: mappedButton != nil)
    }

    public mutating func addTrackpad(id: UUID = UUID(), mappedTo mappedButton: GameButton? = nil) {
        let trackpadCount = customButtons.filter { $0.normalized.isTrackpad }.count
        guard customButtons.count < Self.maximumCustomButtons,
              trackpadCount < Self.maximumTrackpads
        else { return }

        let customButton = GamepadCustomButton(
            id: id,
            mappedButton: mappedButton ?? firstAvailableCustomSlot() ?? .custom1,
            label: "Trackpad",
            layout: GamepadButtonCustomization(
                centerX: 0.50,
                centerY: 0.58,
                widthScale: 1.25,
                heightScale: 1.0,
                shape: .roundedRectangle,
                accentStyle: .monochrome,
                cornerRadius: 18
            ),
            controlKind: .trackpad,
            trackpadSettings: .defaultValue
        )
        customButtons.append(customButton)
        upsertElementMirror(for: customButton, migratesLegacySlot: mappedButton != nil)
    }

    public mutating func addDecoration(
        id: UUID = UUID(),
        label: String = "Decoration",
        centerX: CGFloat = 0.5,
        centerY: CGFloat = 0.5,
        widthScale: CGFloat = 2.2,
        heightScale: CGFloat = 1.2,
        shape: GamepadButtonShapeStyle = .roundedRectangle,
        cornerRadius: CGFloat? = 28,
        visualStyle: GamepadControlVisualStyle? = .softWhitePlate()
    ) {
        guard customButtons.count < Self.maximumCustomButtons else { return }
        let customButton = GamepadCustomButton(
            id: id,
            mappedButton: .custom8,
            label: label,
            layout: GamepadButtonCustomization(
                centerX: centerX,
                centerY: centerY,
                widthScale: widthScale,
                heightScale: heightScale,
                shape: shape,
                fillColor: GamepadRGBAColor(hexString: "#F2EEF5"),
                visualStyle: visualStyle,
                cornerRadius: cornerRadius,
                shadowStrength: 0
            ),
            controlKind: .decoration
        )
        customButtons.append(customButton)
        upsertElementMirror(for: customButton, migratesLegacySlot: false)
    }

    public mutating func removeCustomButton(id: UUID) {
        customButtons.removeAll { $0.id == id }
        elements.removeAll { $0.id == id }
    }

    public mutating func resetButtonLayout() {
        buttonCustomizations.removeAll()
        customButtons.removeAll()
        elements.removeAll()
    }

    private func firstAvailableCustomSlot() -> GameButton? {
        GameButton.customSlots.first { slot in
            !customButtons.contains { $0.mappedButton == slot }
        }
    }

    public var usesFreeformLayout: Bool {
        !elements.isEmpty
            || customButtons.contains { !$0.layout.isHidden }
            || buttonCustomizations.values.contains { $0.normalized.needsFreeformLayout }
    }

    public func element(for id: UUID) -> KeypadElement? {
        normalized.elements.first { $0.id == id }
    }

    public func element(for identity: GamepadControlIdentity) -> KeypadElement? {
        switch identity {
        case .builtin(let button):
            return normalized.elements.first { $0.builtInButton == button }
        case .custom(let id):
            return normalized.elements.first { $0.id == id }
        case .system, .controlBarItem:
            return nil
        }
    }

    public func elementID(for identity: GamepadControlIdentity) -> UUID? {
        element(for: identity)?.id
    }

    public func identity(forElementID elementID: UUID) -> GamepadControlIdentity? {
        guard let element = element(for: elementID) else { return nil }
        if let builtInButton = element.builtInButton { return .builtin(builtInButton) }
        return .custom(element.id)
    }

    public func topBarActivationFrame(in canvasSize: CGSize) -> CGRect {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return .null }
        let controls = GamepadLayoutResolver.preferredControls(for: normalized, in: canvasSize)
        return controls.first { $0.id == .system(.topBarActivation) }?.frame ?? .null
    }

    public static func normalizedControlBarItems(_ items: [GamepadControlBarItem]) -> [GamepadControlBarItem] {
        var seen = Set<GamepadControlBarItem>()
        var normalizedItems: [GamepadControlBarItem] = []
        normalizedItems.reserveCapacity(items.count)
        for item in items where seen.insert(item).inserted {
            normalizedItems.append(item)
        }
        return normalizedItems
    }

    public func controlBarItemCustomization(for item: GamepadControlBarItem) -> GamepadButtonCustomization {
        controlBarItemCustomizations.last { $0.item == item }?.normalized.appearance ?? .defaultValue
    }

    public mutating func setControlBarItemCustomization(_ appearance: GamepadButtonCustomization, for item: GamepadControlBarItem) {
        controlBarItemCustomizations.removeAll { $0.item == item }
        let normalizedAppearance = GamepadControlBarItemCustomization(item: item, appearance: appearance).normalized.appearance
        if !normalizedAppearance.isDefault {
            controlBarItemCustomizations.append(GamepadControlBarItemCustomization(item: item, appearance: normalizedAppearance))
        }
    }

    public mutating func addControlBarItem(_ item: GamepadControlBarItem, at index: Int? = nil) {
        var items = Self.normalizedControlBarItems(controlBarItems)
        guard !items.contains(item) else { return }
        let insertionIndex = min(max(index ?? items.count, 0), items.count)
        items.insert(item, at: insertionIndex)
        controlBarItems = items
    }

    public mutating func removeControlBarItem(_ item: GamepadControlBarItem) {
        controlBarItems.removeAll { $0 == item }
        controlBarItemCustomizations.removeAll { $0.item == item }
    }

    public mutating func moveControlBarItem(_ item: GamepadControlBarItem, to index: Int) {
        var items = Self.normalizedControlBarItems(controlBarItems)
        guard let sourceIndex = items.firstIndex(of: item) else { return }
        items.remove(at: sourceIndex)
        items.insert(item, at: min(max(index, 0), items.count))
        controlBarItems = items
    }

    public mutating func resetControlBarItemAppearance(_ item: GamepadControlBarItem) {
        controlBarItemCustomizations.removeAll { $0.item == item }
    }

    public mutating func resetControlBar() {
        controlBarItems = Self.defaultControlBarItems
        controlBarItemCustomizations.removeAll()
    }

    private mutating func upsertElementMirror(for customButton: GamepadCustomButton, migratesLegacySlot: Bool) {
        let normalizedButton = customButton.normalized
        let existing = elements.first { $0.id == normalizedButton.id }?.normalized
        let element = KeypadElement(
            id: normalizedButton.id,
            label: normalizedButton.visualLabel(fallback: visualLabel(for: normalizedButton.mappedButton)),
            kind: normalizedButton.controlKind,
            layout: normalizedButton.layout,
            builtInButton: nil,
            legacySlot: migratesLegacySlot ? normalizedButton.mappedButton : existing?.legacySlot,
            output: existing?.output,
            partOutputs: existing?.partOutputs ?? [:],
            joystickMapping: normalizedButton.joystickMapping,
            joystickOutputSettings: normalizedButton.joystickOutputSettings,
            triggerSettings: normalizedButton.triggerSettings,
            trackpadSettings: normalizedButton.trackpadSettings
        ).normalized(layoutIsAlreadyNormalized: true)
        if let index = elements.firstIndex(where: { $0.id == element.id }) {
            elements[index] = element
        } else {
            elements.append(element)
        }
    }

    private func synchronizedElements(migratesLegacySlots: Bool, controlsAreNormalized: Bool = false) -> [KeypadElement] {
        var existingByID: [UUID: KeypadElement] = [:]
        var existingByBuiltIn: [GameButton: KeypadElement] = [:]
        for element in elements {
            let normalizedElement: KeypadElement
            if controlsAreNormalized {
                normalizedElement = element.synchronizationMetadata
            } else {
                normalizedElement = element.normalized
            }
            existingByID[normalizedElement.id] = normalizedElement
            if let builtInButton = normalizedElement.builtInButton {
                existingByBuiltIn[builtInButton] = normalizedElement
            }
        }
        var next: [KeypadElement] = []
        var seenIDs = Set<UUID>()

        for button in GameButton.builtInControls {
            let layout = controlsAreNormalized ? (buttonCustomizations[button] ?? .defaultValue) : buttonCustomization(for: button)
            guard !layout.isHidden else { continue }
            let existing = existingByBuiltIn[button]
            let id = existing?.id ?? KeypadElement.builtInID(for: button)
            guard seenIDs.insert(id).inserted else { continue }
            next.append(
                KeypadElement(
                    id: id,
                    label: visualLabel(for: button),
                    kind: .button,
                    layout: layout,
                    builtInButton: button,
                    legacySlot: existing?.legacySlot ?? button,
                    output: existing?.output,
                    partOutputs: existing?.partOutputs ?? [:]
                ).normalized(layoutIsAlreadyNormalized: true)
            )
        }

        for customButton in customButtons {
            let normalizedButton = controlsAreNormalized ? customButton : customButton.normalized
            let existing = existingByID[normalizedButton.id]
            guard seenIDs.insert(normalizedButton.id).inserted else { continue }
            next.append(
                KeypadElement(
                    id: normalizedButton.id,
                    label: normalizedButton.visualLabel(fallback: visualLabel(for: normalizedButton.mappedButton)),
                    kind: normalizedButton.controlKind,
                    layout: normalizedButton.layout,
                    builtInButton: nil,
                    legacySlot: migratesLegacySlots ? normalizedButton.mappedButton : existing?.legacySlot,
                    output: existing?.output,
                    partOutputs: existing?.partOutputs ?? [:],
                    joystickMapping: normalizedButton.joystickMapping,
                    joystickOutputSettings: normalizedButton.joystickOutputSettings,
                    triggerSettings: normalizedButton.triggerSettings,
                    trackpadSettings: normalizedButton.trackpadSettings
                ).normalized(layoutIsAlreadyNormalized: true)
            )
        }

        return next
    }

    public var normalized: GamepadCustomization {
        var copy = self
        copy.deviceCanvas = deviceCanvas.normalized
        copy.backgroundLightColor = backgroundLightColor?.normalized
        copy.backgroundDarkColor = backgroundDarkColor?.normalized
        copy.backgroundFillStyle = backgroundFillStyle?.normalized
        copy.backgroundLightFillStyle = backgroundLightFillStyle?.normalized
        copy.backgroundDarkFillStyle = backgroundDarkFillStyle?.normalized
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
        var triggerCount = 0
        var trackpadCount = 0
        for customButton in customButtons {
            let normalizedCustomButton = customButton.normalized
            guard seenCustomButtonIDs.insert(normalizedCustomButton.id).inserted else { continue }
            if normalizedCustomButton.isJoystick {
                guard joystickCount < Self.maximumJoysticks else { continue }
                joystickCount += 1
            } else if normalizedCustomButton.isTrigger {
                guard triggerCount < Self.maximumTriggers else { continue }
                triggerCount += 1
            } else if normalizedCustomButton.isTrackpad {
                guard trackpadCount < Self.maximumTrackpads else { continue }
                trackpadCount += 1
            }
            normalizedCustomButtons.append(normalizedCustomButton)
            if normalizedCustomButtons.count >= Self.maximumCustomButtons { break }
        }
        copy.customButtons = normalizedCustomButtons
        copy.elements = copy.synchronizedElements(migratesLegacySlots: elements.isEmpty, controlsAreNormalized: true)
        copy.topBarActivationRegion = topBarActivationRegion.normalized
        if copy.topBarActivationRegion.centerX == nil { copy.topBarActivationRegion.centerX = Self.defaultTopBarActivationRegion.centerX }
        if copy.topBarActivationRegion.centerY == nil { copy.topBarActivationRegion.centerY = Self.defaultTopBarActivationRegion.centerY }
        if copy.topBarActivationRegion.shape == nil { copy.topBarActivationRegion.shape = .capsule }
        copy.controlBarItems = Self.normalizedControlBarItems(controlBarItems)
        var latestControlBarAppearance: [GamepadControlBarItem: GamepadControlBarItemCustomization] = [:]
        for customization in controlBarItemCustomizations {
            latestControlBarAppearance[customization.item] = customization.normalized
        }
        copy.controlBarItemCustomizations = copy.controlBarItems.compactMap { item in
            guard let customization = latestControlBarAppearance[item], !customization.appearance.isDefault else { return nil }
            return customization
        }
        copy.styleLibrary = styleLibrary.normalized
        copy.assetLibrary = assetLibrary.normalized
        copy.designMetadata = designMetadata?.normalized(availableControls: copy.allControlIdentitiesForDesign)
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
            && deviceCanvas.normalized == other.deviceCanvas.normalized
            && backgroundLightColor?.normalized == other.backgroundLightColor?.normalized
            && backgroundDarkColor?.normalized == other.backgroundDarkColor?.normalized
            && backgroundFillStyle?.normalized == other.backgroundFillStyle?.normalized
            && backgroundLightFillStyle?.normalized == other.backgroundLightFillStyle?.normalized
            && backgroundDarkFillStyle?.normalized == other.backgroundDarkFillStyle?.normalized
            && accentStyle == other.accentStyle
            && showsButtonLabels == other.showsButtonLabels
            && normalized.labelOverrides == other.normalized.labelOverrides
            && normalized.buttonCustomizations == other.normalized.buttonCustomizations
            && normalized.customButtons == other.normalized.customButtons
            && normalized.elements == other.normalized.elements
            && normalized.topBarActivationRegion == other.normalized.topBarActivationRegion
            && normalized.controlBarItems == other.normalized.controlBarItems
            && normalized.controlBarItemCustomizations == other.normalized.controlBarItemCustomizations
            && normalized.designMetadata == other.normalized.designMetadata
            && normalized.styleLibrary == other.normalized.styleLibrary
            && normalized.assetLibrary == other.normalized.assetLibrary
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
        case deviceCanvas
        case backgroundLightColor
        case backgroundDarkColor
        case backgroundFillStyle
        case backgroundLightFillStyle
        case backgroundDarkFillStyle
        case accentStyle
        case showsButtonLabels
        case labelOverrides
        case buttonCustomizations
        case customButtons
        case elements
        case topBarActivationRegion
        case controlBarItems
        case controlBarItemCustomizations
        case designMetadata
        case styleLibrary
        case assetLibrary
        case updatedAt
    }
}

public enum GamepadSystemControl: String, Codable, CaseIterable, Identifiable, Sendable {
    case topBarActivation = "top_bar_activation"

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topBarActivation: "Control Bar"
        }
    }

    var subtitle: String {
        switch self {
        case .topBarActivation: "iPhone control bar hotspot & contents"
        }
    }

    var systemImage: String {
        switch self {
        case .topBarActivation: "arrow.down.to.line.compact"
        }
    }
}

public enum GamepadControlIdentity: Hashable, Identifiable, Sendable {
    case builtin(GameButton)
    case custom(UUID)
    case system(GamepadSystemControl)
    case controlBarItem(GamepadControlBarItem)

    public var id: String {
        switch self {
        case .builtin(let button): "builtin.\(button.rawValue)"
        case .custom(let id): "custom.\(id.uuidString)"
        case .system(let control): "system.\(control.rawValue)"
        case .controlBarItem(let item): "control_bar_item.\(item.rawValue)"
        }
    }
}

struct GamepadResolvedControl: Identifiable, Equatable {
    let id: GamepadControlIdentity
    let elementID: UUID?
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
    let joystickOutputSettings: GamepadJoystickOutputSettings?
    let triggerSettings: GamepadTriggerSettings?
    let trackpadSettings: GamepadTrackpadSettings?

    var isJoystick: Bool {
        controlKind == .joystick
    }

    var isTrigger: Bool {
        controlKind == .trigger
    }

    var isTrackpad: Bool {
        controlKind == .trackpad
    }

    var isDecoration: Bool {
        controlKind == .decoration
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
            elementID: elementID,
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
            joystickMapping: joystickMapping,
            joystickOutputSettings: joystickOutputSettings,
            triggerSettings: triggerSettings,
            trackpadSettings: trackpadSettings
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

enum GamepadLayoutResolver {
    private static let minimumControlSpacing: CGFloat = 0

    static func resolvedControls(
        for customization: GamepadCustomization,
        in canvasSize: CGSize,
        defaultLabelProvider: ((GameButton) -> String?)? = nil
    ) -> [GamepadResolvedControl] {
        let resolved = controlsByAvoidingOverlaps(
            preferredControls(
                for: customization,
                in: canvasSize,
                defaultLabelProvider: defaultLabelProvider
            ),
            in: canvasSize
        )
        let layerOrder = customization.orderedControlIdentitiesForDesign
        guard !layerOrder.isEmpty else { return resolved }
        let orderLookup = Dictionary(uniqueKeysWithValues: layerOrder.enumerated().map { ($0.element, $0.offset) })
        return resolved.sorted { lhs, rhs in
            if lhs.layoutCustomization.zIndex != rhs.layoutCustomization.zIndex {
                return lhs.layoutCustomization.zIndex < rhs.layoutCustomization.zIndex
            }
            let lhsIndex = orderLookup[lhs.id] ?? Int.max
            let rhsIndex = orderLookup[rhs.id] ?? Int.max
            if lhsIndex == rhsIndex { return lhs.id.id < rhs.id.id }
            return lhsIndex < rhsIndex
        }
    }

    static func preferredControls(
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
                elementID: KeypadElement.builtInID(for: button),
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
                joystickMapping: nil,
                joystickOutputSettings: nil,
                triggerSettings: nil,
                trackpadSettings: nil
            )
        }

        let customControls = customization.customButtons.compactMap { customButton -> GamepadResolvedControl? in
            let normalizedButton = customButton.normalized
            guard !normalizedButton.layout.isHidden else { return nil }

            let defaultShape: GamepadButtonShapeStyle = if normalizedButton.isJoystick {
                .circle
            } else if normalizedButton.isDecoration {
                .roundedRectangle
            } else {
                defaultShape(for: normalizedButton.mappedButton)
            }
            let shape = normalizedButton.layout.resolvedShape(defaultShape: defaultShape)
            let baseControlSize: CGSize
            if normalizedButton.isJoystick {
                baseControlSize = joystickBaseSize(controlScale: customization.controlScale, in: canvasSize)
            } else if normalizedButton.isTrigger {
                baseControlSize = triggerBaseSize(controlScale: customization.controlScale, in: canvasSize)
            } else if normalizedButton.isTrackpad {
                baseControlSize = trackpadBaseSize(controlScale: customization.controlScale, in: canvasSize)
            } else if normalizedButton.isDecoration {
                baseControlSize = baseSize(for: .jump, controlScale: customization.controlScale, in: canvasSize)
            } else {
                baseControlSize = baseSize(for: normalizedButton.mappedButton, controlScale: customization.controlScale, in: canvasSize)
            }
            let scaledSize = effectiveSize(
                CGSize(
                    width: baseControlSize.width * normalizedButton.layout.widthScale,
                    height: baseControlSize.height * normalizedButton.layout.heightScale
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
                elementID: normalizedButton.id,
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
                joystickMapping: normalizedButton.isJoystick ? (normalizedButton.joystickMapping ?? .movement) : nil,
                joystickOutputSettings: normalizedButton.isJoystick ? (normalizedButton.joystickOutputSettings ?? .defaultValue).normalized : nil,
                triggerSettings: normalizedButton.isTrigger ? (normalizedButton.triggerSettings ?? .defaultValue).normalized : nil,
                trackpadSettings: normalizedButton.isTrackpad ? (normalizedButton.trackpadSettings ?? .defaultValue).normalized : nil
            )
        }

        let systemControls = systemControls(for: customization, in: canvasSize)
        return builtinControls + customControls + systemControls
    }

    private static func systemControls(for customization: GamepadCustomization, in canvasSize: CGSize) -> [GamepadResolvedControl] {
        let layout = customization.topBarActivationRegion.normalized
        guard !layout.isHidden else { return [] }

        let shape = layout.resolvedShape(defaultShape: .capsule)
        let baseControlSize = topBarActivationBaseSize(for: customization, in: canvasSize)
        let scaledSize = effectiveSize(
            CGSize(
                width: baseControlSize.width * layout.widthScale,
                height: baseControlSize.height * layout.heightScale
            ),
            shape: shape
        )
        let defaultCenter = CGPoint(
            x: GamepadCustomization.defaultTopBarActivationRegion.centerX ?? 0.5,
            y: GamepadCustomization.defaultTopBarActivationRegion.centerY ?? 0.075
        )
        let normalizedCenter = CGPoint(
            x: layout.centerX ?? defaultCenter.x,
            y: layout.centerY ?? defaultCenter.y
        )
        let center = clampedPixelCenter(normalizedCenter, visualSize: scaledSize, in: canvasSize)

        return [
            GamepadResolvedControl(
                id: .system(.topBarActivation),
                elementID: nil,
                mappedButton: .pause,
                label: GamepadSystemControl.topBarActivation.displayName,
                normalizedCenter: CGPoint(x: center.x / canvasSize.width, y: center.y / canvasSize.height),
                center: center,
                size: scaledSize,
                shape: shape,
                rotationDegrees: layout.rotationDegrees,
                layoutCustomization: layout,
                isCustom: false,
                isLocationLocked: layout.isLocationLocked,
                controlKind: .decoration,
                joystickMapping: nil,
                joystickOutputSettings: nil,
                triggerSettings: nil,
                trackpadSettings: nil
            )
        ]
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
            let dx = (x + clampedPreferred.width / 2) - preferredCenter.x
            let xScore = dx * dx
            guard xScore < bestScore else { break }

            for y in yCandidates {
                let dy = (y + clampedPreferred.height / 2) - preferredCenter.y
                let score = xScore + dy * dy
                guard score < bestScore else { break }

                let candidate = CGRect(
                    x: x,
                    y: y,
                    width: clampedPreferred.width,
                    height: clampedPreferred.height
                )
                guard !frameOverlapsAny(candidate, avoiding: existingFrames, minimumSpacing: minimumSpacing) else { continue }

                bestScore = score
                bestFrame = candidate
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
            if control.isDecoration {
                adjustedControls.append(control)
                continue
            }

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

        let clampedValues = rawValues
            .map { clampedOrigin($0, length: length, canvasLength: canvasLength) }
            .sorted()
        var uniqueValues: [CGFloat] = []
        uniqueValues.reserveCapacity(clampedValues.count)
        for value in clampedValues {
            guard let lastValue = uniqueValues.last else {
                uniqueValues.append(value)
                continue
            }
            guard abs(lastValue - value) >= 0.5 else { continue }
            uniqueValues.append(value)
        }

        return uniqueValues.sorted { lhs, rhs in
            let lhsDistance = abs(lhs - preferred)
            let rhsDistance = abs(rhs - preferred)
            if abs(lhsDistance - rhsDistance) > 0.001 { return lhsDistance < rhsDistance }
            return lhs < rhs
        }
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

    private static func triggerBaseSize(controlScale: GamepadControlScale, in canvasSize: CGSize) -> CGSize {
        let isLandscape = canvasSize.width >= canvasSize.height
        let shortestSide = max(1, min(canvasSize.width, canvasSize.height))
        let scale = controlScale.multiplier
        let width = min(148 * scale, max(86 * scale, shortestSide * (isLandscape ? 0.30 : 0.24) * scale))
        let height = min(58 * scale, max(34 * scale, shortestSide * (isLandscape ? 0.11 : 0.09) * scale))
        return CGSize(width: width, height: height)
    }

    private static func trackpadBaseSize(controlScale: GamepadControlScale, in canvasSize: CGSize) -> CGSize {
        let isLandscape = canvasSize.width >= canvasSize.height
        let shortestSide = max(1, min(canvasSize.width, canvasSize.height))
        let scale = controlScale.multiplier
        let width = min(230 * scale, max(142 * scale, shortestSide * (isLandscape ? 0.48 : 0.42) * scale))
        let height = min(150 * scale, max(92 * scale, shortestSide * (isLandscape ? 0.28 : 0.24) * scale))
        return CGSize(width: width, height: height)
    }

    private static func topBarActivationBaseSize(for customization: GamepadCustomization, in canvasSize: CGSize) -> CGSize {
        let isLandscape = canvasSize.width >= canvasSize.height
        let horizontalPadding: CGFloat
        if isLandscape {
            let estimatedSafeSideInset: CGFloat = switch customization.deviceCanvas.editorDeviceFrame.frameStyle {
            case .dynamicIsland: 59
            case .notch: 44
            case .homeButton: 0
            }
            horizontalPadding = max(Geist.Spacing.s6, estimatedSafeSideInset + Geist.Spacing.s3)
        } else {
            horizontalPadding = Geist.Spacing.s4
        }

        // Match ControllerTopBarDrawer's available width. Height follows the
        // tallest visible child (32pt at 100%), bar padding, spacing, and handle.
        let width = max(120, canvasSize.width - horizontalPadding * 2)
        let tallestItemScale = customization.normalized.controlBarItems
            .filter { $0 != .spacer && !customization.controlBarItemCustomization(for: $0).isHidden }
            .map { customization.controlBarItemCustomization(for: $0).heightScale }
            .max() ?? 1
        let height = 41 + (32 * GamepadButtonCustomization.clamp(tallestItemScale, lower: 0.5, upper: 2))
        return CGSize(width: width, height: height)
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

    func backgroundColorValue(for scheme: ColorScheme) -> GamepadRGBAColor {
        keypadBackgroundFillStyle(scheme: scheme).representativeColor.normalized
    }

    func keypadBackgroundColor(scheme: ColorScheme) -> Color {
        backgroundColorValue(for: scheme).swiftUIColor
    }

    func keypadBackgroundFillStyle(scheme: ColorScheme) -> GamepadFillStyle {
        backgroundFillStyle(for: scheme) ?? .solid(Self.defaultBackgroundColor(for: scheme))
    }

    func backgroundFillStyle(for scheme: ColorScheme) -> GamepadFillStyle? {
        switch scheme {
        case .dark:
            if let backgroundDarkFillStyle { return backgroundDarkFillStyle.normalized }
            if let backgroundFillStyle { return backgroundFillStyle.normalized }
            if let backgroundDarkColor { return .solid(backgroundDarkColor.normalized) }
            return nil
        default:
            if let backgroundLightFillStyle { return backgroundLightFillStyle.normalized }
            if let backgroundFillStyle { return backgroundFillStyle.normalized }
            if let backgroundLightColor { return .solid(backgroundLightColor.normalized) }
            return nil
        }
    }

    func hasCustomBackgroundColor(for scheme: ColorScheme) -> Bool {
        hasCustomBackgroundFill(for: scheme)
    }

    func hasCustomBackgroundFill(for scheme: ColorScheme) -> Bool {
        switch scheme {
        case .dark:
            backgroundDarkFillStyle != nil || backgroundFillStyle != nil || backgroundDarkColor != nil
        default:
            backgroundLightFillStyle != nil || backgroundFillStyle != nil || backgroundLightColor != nil
        }
    }

    mutating func setBackgroundColor(_ color: GamepadRGBAColor?, for scheme: ColorScheme) {
        prepareSchemeSpecificBackgroundFillStorage()
        switch scheme {
        case .dark:
            backgroundDarkColor = color?.normalized
            backgroundDarkFillStyle = nil
        default:
            backgroundLightColor = color?.normalized
            backgroundLightFillStyle = nil
        }
    }

    mutating func setBackgroundFillStyle(_ style: GamepadFillStyle, for scheme: ColorScheme) {
        prepareSchemeSpecificBackgroundFillStorage()
        switch scheme {
        case .dark:
            backgroundDarkFillStyle = style.normalized
            backgroundDarkColor = nil
        default:
            backgroundLightFillStyle = style.normalized
            backgroundLightColor = nil
        }
    }

    mutating func clearBackgroundFill(for scheme: ColorScheme) {
        prepareSchemeSpecificBackgroundFillStorage()
        switch scheme {
        case .dark:
            backgroundDarkColor = nil
            backgroundDarkFillStyle = nil
        default:
            backgroundLightColor = nil
            backgroundLightFillStyle = nil
        }
    }

    mutating func prepareSchemeSpecificBackgroundFillStorage() {
        if let globalFillStyle = backgroundFillStyle?.normalized {
            if backgroundLightFillStyle == nil {
                backgroundLightFillStyle = globalFillStyle
            }
            if backgroundDarkFillStyle == nil {
                backgroundDarkFillStyle = globalFillStyle
            }
            backgroundFillStyle = nil
        }
    }

    static func defaultBackgroundColor(for scheme: ColorScheme) -> GamepadRGBAColor {
        switch scheme {
        case .dark:
            GamepadRGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
        default:
            GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
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
    func buttonFillStyle(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> GamepadFillStyle {
        if let fillStyle = fillStyle(for: scheme) {
            return fillStyle.adjustedForPress(isPressed)
        }
        return .solid(GamepadRGBAColor(color: accentStyle.buttonFill(isPressed: isPressed, scheme: scheme), fallback: .defaultValue).normalized)
    }

    func buttonFill(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        buttonFillStyle(accentStyle: accentStyle, isPressed: isPressed, scheme: scheme).representativeColor.swiftUIColor
    }

    func buttonForeground(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if fillStyle(for: scheme) != nil {
            return buttonFillStyle(accentStyle: accentStyle, isPressed: isPressed, scheme: scheme).representativeColor.foregroundColor
        }
        return accentStyle.buttonForeground(isPressed: isPressed, scheme: scheme)
    }

    func buttonStroke(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if fillStyle(for: scheme) != nil {
            return buttonFillStyle(accentStyle: accentStyle, isPressed: isPressed, scheme: scheme).representativeColor.strokeColor
        }
        return accentStyle.buttonStroke(isPressed: isPressed, scheme: scheme)
    }

    func joystickKnobFill(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if let color = joystickKnobColor(for: scheme) {
            return color.adjustedForPress(isPressed).swiftUIColor
        }
        return buttonForeground(accentStyle: accentStyle, isPressed: isPressed, scheme: scheme)
            .opacity(scheme == .dark ? 0.30 : 0.18)
    }

    func joystickKnobStroke(accentStyle: GamepadAccentStyle, isPressed: Bool, scheme: ColorScheme) -> Color {
        if let color = joystickKnobColor(for: scheme) {
            let adjustedColor = color.adjustedForPress(isPressed)
            return adjustedColor.alpha > 0.001 ? adjustedColor.strokeColor : .clear
        }
        return buttonForeground(accentStyle: accentStyle, isPressed: isPressed, scheme: scheme)
            .opacity(0.34)
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
            Geist.color(.background100, scheme: scheme)
        } else if self == .monochrome || self == .amber {
            Geist.color(.gray1000, scheme: scheme)
        } else {
            strongColor(scheme: scheme)
        }
    }

    func buttonStroke(isPressed: Bool, scheme: ColorScheme) -> Color {
        if self == .monochrome || self == .amber {
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
        case .amber: Geist.color(.gray100, scheme: scheme)
        }
    }

    private func strongColor(scheme: ColorScheme) -> Color {
        switch self {
        case .monochrome: Geist.color(.gray1000, scheme: scheme)
        case .blue: Geist.color(.blue900, scheme: scheme)
        case .green: Geist.color(.green900, scheme: scheme)
        case .purple: Geist.color(.purple900, scheme: scheme)
        case .pink: Geist.color(.pink900, scheme: scheme)
        case .amber: Geist.color(.gray1000, scheme: scheme)
        }
    }

    private func borderColor(scheme: ColorScheme) -> Color {
        switch self {
        case .monochrome: Geist.color(.grayAlpha400, scheme: scheme)
        case .blue: Geist.color(.blue400, scheme: scheme)
        case .green: Geist.color(.green400, scheme: scheme)
        case .purple: Geist.color(.purple400, scheme: scheme)
        case .pink: Geist.color(.pink400, scheme: scheme)
        case .amber: Geist.color(.grayAlpha400, scheme: scheme)
        }
    }
}

public enum GamepadProfileOutputMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case keyboard
    case controller
    case custom

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keyboard: "Keyboard"
        case .controller: "Controller"
        case .custom: "Custom"
        }
    }

    var description: String {
        switch self {
        case .keyboard:
            "Send this keypad as Mac keyboard shortcuts. Virtual controller output stays off for this setup."
        case .controller:
            "Send this keypad as a virtual Xbox-style controller using PocketPad’s default controller map."
        case .custom:
            "Use per-element output bindings. This can mix keyboard shortcuts and virtual controller buttons."
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public struct GamepadProfileLaunchTarget: Codable, Equatable, Sendable {
    public enum TargetKind: String, Codable, Sendable {
        case application
    }

    public var kind: TargetKind
    public var displayName: String
    public static let maximumIconBytes = 200_000

    public var bundleIdentifier: String?
    public var filePath: String?
    public var bookmarkData: Data?
    public var iconPNGData: Data?
    public var attachedAt: Int64

    public init(
        kind: TargetKind = .application,
        displayName: String,
        bundleIdentifier: String? = nil,
        filePath: String? = nil,
        bookmarkData: Data? = nil,
        iconPNGData: Data? = nil,
        attachedAt: Int64 = Date.currentMilliseconds
    ) {
        self.kind = kind
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.filePath = filePath
        self.bookmarkData = bookmarkData
        self.iconPNGData = iconPNGData
        self.attachedAt = attachedAt
    }

    public var normalized: GamepadProfileLaunchTarget {
        var copy = self
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.displayName = trimmedDisplayName.isEmpty ? "Application" : trimmedDisplayName
        copy.bundleIdentifier = bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        copy.filePath = filePath?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
        if let iconPNGData, iconPNGData.count <= Self.maximumIconBytes {
            copy.iconPNGData = iconPNGData
        } else {
            copy.iconPNGData = nil
        }
#if os(macOS)
        if copy.iconPNGData == nil, let applicationURL = copy.resolvedApplicationURL() {
            copy.iconPNGData = Self.applicationIconPNGData(for: applicationURL)
        }
#endif
        return copy
    }

    var detailText: String {
        if let bundleIdentifier = bundleIdentifier?.nilIfBlank {
            return bundleIdentifier
        }
        if let filePath = filePath?.nilIfBlank {
            return (filePath as NSString).abbreviatingWithTildeInPath
        }
        return "Mac application"
    }
}

#if os(macOS)
extension GamepadProfileLaunchTarget {
    static func application(url: URL, bookmarkData: Data? = nil) -> GamepadProfileLaunchTarget {
        let standardizedURL = url.standardizedFileURL
        let bundle = Bundle(url: standardizedURL)
        let bundleDisplayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let displayName = bundleDisplayName?.nilIfBlank
            ?? bundleName?.nilIfBlank
            ?? standardizedURL.deletingPathExtension().lastPathComponent

        return GamepadProfileLaunchTarget(
            kind: .application,
            displayName: displayName,
            bundleIdentifier: bundle?.bundleIdentifier?.nilIfBlank,
            filePath: standardizedURL.path,
            bookmarkData: bookmarkData,
            iconPNGData: applicationIconPNGData(for: standardizedURL)
        ).normalized
    }

    static func applicationIconPNGData(for url: URL) -> Data? {
        let pixelSize = 128
        let image = NSWorkspace.shared.icon(forFile: url.path)
        let targetSize = NSSize(width: pixelSize, height: pixelSize)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        representation.size = targetSize

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: representation) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size == .zero ? targetSize : image.size),
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let data = representation.representation(using: .png, properties: [:]),
              data.count <= maximumIconBytes
        else {
            return nil
        }
        return data
    }

    func resolvedApplicationURL() -> URL? {
        if let bookmarkData {
            var isStale = false
            if let bookmarkedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return bookmarkedURL
            }
        }

        if let filePath = filePath?.nilIfBlank {
            let fileURL = URL(fileURLWithPath: (filePath as NSString).expandingTildeInPath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }

        if let bundleIdentifier = bundleIdentifier?.nilIfBlank {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        }

        return nil
    }
}
#endif

public struct GamepadConfigurationProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    /// Legacy/current layout. This remains the fallback for older saved profiles and
    /// clients, while orientation-specific variants below can override it on iPhone.
    public var customization: GamepadCustomization
    public var landscapeCustomization: GamepadCustomization?
    public var portraitCustomization: GamepadCustomization?
    public var outputMode: GamepadProfileOutputMode
    public var launchTarget: GamepadProfileLaunchTarget?
    public var updatedAt: Int64

    public init(
        id: UUID = UUID(),
        name: String,
        customization: GamepadCustomization,
        landscapeCustomization: GamepadCustomization? = nil,
        portraitCustomization: GamepadCustomization? = nil,
        outputMode: GamepadProfileOutputMode = .keyboard,
        launchTarget: GamepadProfileLaunchTarget? = nil,
        updatedAt: Int64 = Date.currentMilliseconds
    ) {
        self.id = id
        self.name = name
        self.customization = customization.normalized
        self.landscapeCustomization = landscapeCustomization?.normalized
        self.portraitCustomization = portraitCustomization?.normalized
        self.outputMode = outputMode
        self.launchTarget = launchTarget?.normalized
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        customization = (try container.decodeIfPresent(GamepadCustomization.self, forKey: .customization) ?? .defaultValue).normalized
        landscapeCustomization = try container.decodeIfPresent(GamepadCustomization.self, forKey: .landscapeCustomization)?.normalized
        portraitCustomization = try container.decodeIfPresent(GamepadCustomization.self, forKey: .portraitCustomization)?.normalized
        // Profiles saved before output modes had their Mac output bindings stored next
        // to the profile, not inside it. Treat legacy profiles as custom so any
        // existing mixed keyboard/controller bindings keep working after migration.
        outputMode = try container.decodeIfPresent(GamepadProfileOutputMode.self, forKey: .outputMode) ?? .custom
        launchTarget = try container.decodeIfPresent(GamepadProfileLaunchTarget.self, forKey: .launchTarget)?.normalized
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? Date.currentMilliseconds
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(customization, forKey: .customization)
        try container.encodeIfPresent(landscapeCustomization, forKey: .landscapeCustomization)
        try container.encodeIfPresent(portraitCustomization, forKey: .portraitCustomization)
        try container.encode(outputMode, forKey: .outputMode)
        try container.encodeIfPresent(launchTarget?.normalized, forKey: .launchTarget)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    public var normalized: GamepadConfigurationProfile {
        var copy = self
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = trimmedName.isEmpty ? "Untitled" : trimmedName
        copy.customization = customization.normalized
        copy.landscapeCustomization = landscapeCustomization?.normalized
        copy.portraitCustomization = portraitCustomization?.normalized
        copy.launchTarget = launchTarget?.normalized
        return copy
    }

    func customization(for orientation: GamepadEditorDeviceOrientation) -> GamepadCustomization {
        var resolved = switch orientation {
        case .landscape:
            (landscapeCustomization ?? customization).normalized
        case .portrait:
            (portraitCustomization ?? customization).normalized
        }
        // Saved Mode is a setup-level preference, not a per-orientation design choice.
        resolved.colorSchemePreference = customization.colorSchemePreference
        return resolved.normalized
    }

    func hasCustomizationVariant(for orientation: GamepadEditorDeviceOrientation) -> Bool {
        switch orientation {
        case .landscape: landscapeCustomization != nil
        case .portrait: portraitCustomization != nil
        }
    }

    mutating func setCustomization(_ customization: GamepadCustomization, for orientation: GamepadEditorDeviceOrientation) {
        let previousCustomization = self.customization.normalized
        let previousOrientation = previousCustomization.deviceCanvas.editorDeviceFrame.orientation
        if previousOrientation != orientation, !hasCustomizationVariant(for: previousOrientation) {
            switch previousOrientation {
            case .landscape:
                landscapeCustomization = previousCustomization
            case .portrait:
                portraitCustomization = previousCustomization
            }
        }

        let normalizedCustomization = customization.normalized
        self.customization = normalizedCustomization
        switch orientation {
        case .landscape:
            landscapeCustomization = normalizedCustomization
        case .portrait:
            portraitCustomization = normalizedCustomization
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case customization
        case landscapeCustomization
        case portraitCustomization
        case outputMode
        case launchTarget
        case updatedAt
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
    case softWhite

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
        case .softWhite: "Soft White Pro"
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
        case .softWhite: "Premium soft-white neumorphic controller with layered shell, rings, plates, dual sticks, D-pad, ABXY, and shoulder controls"
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
        case .softWhite: "sparkles"
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
        case .softWhite:
            Self.softWhiteCustomization()
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

    private static func softWhiteCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .purple, controlScale: .standard)
        customization.colorSchemePreference = .light
        customization.showsButtonLabels = false
        customization.backgroundLightFillStyle = .solid(GamepadRGBAColor(hexString: "#000000") ?? .defaultValue)
        customization.backgroundDarkFillStyle = customization.backgroundLightFillStyle
        customization.styleLibrary = GamepadStyleLibrary(styles: [
            GamepadStyleToken(id: "soft-white-raised", name: "Soft White Raised", visualStyle: .softWhiteRaised()),
            GamepadStyleToken(id: "soft-white-inset", name: "Soft White Inset", visualStyle: .softWhiteInset()),
            GamepadStyleToken(id: "soft-white-plate", name: "Soft White Plate", appliesTo: GamepadCustomControlKind.allCases, visualStyle: .softWhitePlate()),
            GamepadStyleToken(id: "reference-white-raised", name: "Reference White Raised", visualStyle: referenceRaisedStyle())
        ].compactMap { $0.normalized }).normalized

        hideButton(.up, in: &customization)
        hideButton(.down, in: &customization)
        hideButton(.left, in: &customization)
        hideButton(.right, in: &customization)
        hideButton(.map, in: &customization)
        hideButton(.pause, in: &customization)

        let shellID = addDecoration(label: "", in: &customization, x: 0.50, y: 0.50, width: 9.62, height: 4.28, shape: .roundedRectangle, cornerRadius: 30, style: referenceShellStyle())
        let leftWellID = addDecoration(label: "", in: &customization, x: 0.195, y: 0.565, width: 2.12, height: 2.12, shape: .circle, cornerRadius: nil, style: referenceInsetStyle())
        let stickID = addReferenceJoystick(label: "Move", mappedButton: .custom1, mapping: .movement, in: &customization, x: 0.195, y: 0.585, scale: 1.38)
        let stickTextureID = addDecoration(label: "", in: &customization, x: 0.195, y: 0.585, width: 1.06, height: 1.06, shape: .circle, cornerRadius: nil, style: referenceGridStyle())
        let markerUpID = addIconDecoration(label: "", icon: "⌃", in: &customization, x: 0.195, y: 0.432, width: 0.30, height: 0.30, shape: .circle, cornerRadius: nil, style: referenceMarkerStyle(), iconScale: 1.18)
        let markerDownID = addIconDecoration(label: "", icon: "⌄", in: &customization, x: 0.195, y: 0.737, width: 0.30, height: 0.30, shape: .circle, cornerRadius: nil, style: referenceMarkerStyle(), iconScale: 1.18)
        let markerLeftID = addIconDecoration(label: "", icon: "‹", in: &customization, x: 0.106, y: 0.585, width: 0.30, height: 0.30, shape: .circle, cornerRadius: nil, style: referenceMarkerStyle(), iconScale: 1.18)
        let markerRightID = addIconDecoration(label: "", icon: "›", in: &customization, x: 0.284, y: 0.585, width: 0.30, height: 0.30, shape: .circle, cornerRadius: nil, style: referenceMarkerStyle(), iconScale: 1.18)
        let badgeID = addIconDecoration(label: "Variant", icon: "5", in: &customization, x: 0.034, y: 0.054, width: 0.48, height: 0.48, shape: .circle, cornerRadius: nil, style: referenceBadgeStyle(), iconScale: 1.85)

        let minusID = addReferenceButton(mappedTo: .custom6, label: "−", in: &customization, x: 0.35, y: 0.125, width: 0.56, height: 0.56, shape: .circle, cornerRadius: nil, iconScale: 1.45)
        let plusID = addReferenceButton(mappedTo: .custom7, label: "+", in: &customization, x: 0.65, y: 0.125, width: 0.56, height: 0.56, shape: .circle, cornerRadius: nil, iconScale: 1.45)

        let zlID = addReferenceButton(mappedTo: .custom2, label: "ZL", in: &customization, x: 0.135, y: 0.285, width: 0.80, height: 0.52, shape: .roundedRectangle, cornerRadius: 9, iconScale: 1.28)
        let lID = addReferenceButton(mappedTo: .custom3, label: "L", in: &customization, x: 0.245, y: 0.285, width: 0.80, height: 0.52, shape: .roundedRectangle, cornerRadius: 9, iconScale: 1.34)
        let rID = addReferenceButton(mappedTo: .custom4, label: "R", in: &customization, x: 0.755, y: 0.285, width: 0.80, height: 0.52, shape: .roundedRectangle, cornerRadius: 9, iconScale: 1.34)
        let zrID = addReferenceButton(mappedTo: .custom5, label: "ZR", in: &customization, x: 0.865, y: 0.285, width: 0.80, height: 0.52, shape: .roundedRectangle, cornerRadius: 9, iconScale: 1.28)

        setReferenceButton(.focus, label: "Y", in: &customization, x: 0.642, y: 0.525, width: 0.92, height: 0.92, shape: .circle, iconScale: 1.28)
        setReferenceButton(.attack, label: "X", in: &customization, x: 0.785, y: 0.430, width: 0.64, height: 0.64, shape: .circle, iconScale: 1.36)
        setReferenceButton(.jump, label: "A", in: &customization, x: 0.875, y: 0.560, width: 0.70, height: 0.70, shape: .circle, iconScale: 1.32)
        setReferenceButton(.dash, label: "B", in: &customization, x: 0.735, y: 0.725, width: 0.92, height: 0.92, shape: .circle, iconScale: 1.28)

        var metadata = customization.designMetadata ?? .empty
        metadata.layerOrder = [
            .custom(shellID),
            .custom(leftWellID),
            .custom(minusID),
            .custom(plusID),
            .custom(zlID),
            .custom(lID),
            .custom(rID),
            .custom(zrID),
            .builtin(.focus),
            .builtin(.attack),
            .builtin(.jump),
            .builtin(.dash),
            .custom(stickID),
            .custom(stickTextureID),
            .custom(markerUpID),
            .custom(markerDownID),
            .custom(markerLeftID),
            .custom(markerRightID),
            .custom(badgeID)
        ] + GameButton.builtInControls.map { .builtin($0) } + customization.customButtons.map { .custom($0.id) }
        metadata.tags = ["showcase", "soft-white", "neumorphic", "variant-5", "reference-quality"]
        metadata.notes = "A layered profile built to resemble gamepad_redesign_variant_5.png: black outer canvas, rounded white controller shell, top +/- buttons, ZL/L/R/ZR shoulders, a textured left movement pad, and offset X/Y/A/B face buttons."
        customization.designMetadata = metadata.normalized(availableControls: customization.allControlIdentitiesForDesign)
        return customization.normalized
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
        setButton(.jump, label: "B", in: &customization, x: 0.84, y: 0.74, width: 0.58, height: 0.58, shape: .circle, fill: "#D1D5DB")
        setButton(.attack, label: "Y", in: &customization, x: 0.75, y: 0.55, width: 0.58, height: 0.58, shape: .circle, fill: "#16A34A")
        setButton(.map, label: "Select", in: &customization, x: 0.43, y: 0.82, width: 0.48, height: 0.44, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.57, y: 0.82, width: 0.44, height: 0.44, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        addButton(mappedTo: .custom1, label: "L", in: &customization, x: 0.20, y: 0.16, width: 1.12, height: 0.38, shape: .capsule, fill: shoulderFill)
        addButton(mappedTo: .custom2, label: "R", in: &customization, x: 0.80, y: 0.16, width: 1.12, height: 0.38, shape: .capsule, fill: shoulderFill)

        return customization.normalized
    }

    private static func nintendo64Customization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .monochrome)
        let dPadFill = "#202124"
        let stickFill = "#111827"
        let shoulderFill = "#374151"
        let cButtonFill = "#D1D5DB"

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
        let cStickFill = "#6B7280"

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
        var customization = baseCustomization(accentStyle: .monochrome, controlScale: .standard)
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

        setButton(.focus, label: "Y", in: &customization, x: 0.84, y: 0.32, width: 0.58, height: 0.58, shape: .circle, fill: "#D1D5DB")
        setButton(.dash, label: "B", in: &customization, x: 0.93, y: 0.50, width: 0.58, height: 0.58, shape: .circle, fill: "#EF4444")
        setButton(.jump, label: "A", in: &customization, x: 0.84, y: 0.68, width: 0.58, height: 0.58, shape: .circle, fill: "#22C55E")
        setButton(.attack, label: "X", in: &customization, x: 0.75, y: 0.50, width: 0.58, height: 0.58, shape: .circle, fill: "#3B82F6")

        addButton(mappedTo: .custom5, label: "L", in: &customization, x: 0.20, y: 0.13, width: 1.08, height: 0.36, shape: .capsule, fill: triggerFill)
        addButton(mappedTo: .custom6, label: "R", in: &customization, x: 0.80, y: 0.13, width: 1.08, height: 0.36, shape: .capsule, fill: triggerFill)
        setButton(.pause, label: "Start", in: &customization, x: 0.50, y: 0.45, width: 0.44, height: 0.40, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        return customization.normalized
    }

    private static func arcadeStickCustomization() -> GamepadCustomization {
        var customization = baseCustomization(accentStyle: .monochrome, controlScale: .standard)
        let stickFill = "#111827"
        let utilityFill = "#374151"

        addJoystick(label: "Stick", mappedButton: .up, mapping: .movement, in: &customization, x: 0.22, y: 0.58, scale: 1.08, fill: stickFill)

        setButton(.map, label: "Coin", in: &customization, x: 0.40, y: 0.20, width: 0.52, height: 0.38, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)
        setButton(.pause, label: "Start", in: &customization, x: 0.52, y: 0.20, width: 0.52, height: 0.38, shape: .capsule, fill: utilityFill, shadowStrength: 0.75)

        setButton(.jump, label: "B1", in: &customization, x: 0.60, y: 0.39, width: 0.60, height: 0.60, shape: .circle, fill: "#EF4444", shadowStrength: 1.25)
        setButton(.attack, label: "B2", in: &customization, x: 0.71, y: 0.36, width: 0.60, height: 0.60, shape: .circle, fill: "#9CA3AF", shadowStrength: 1.25)
        setButton(.dash, label: "B3", in: &customization, x: 0.82, y: 0.36, width: 0.60, height: 0.60, shape: .circle, fill: "#D1D5DB", shadowStrength: 1.25)
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

        setButton(.focus, label: "Y", in: &customization, x: 0.84, y: 0.32, width: 0.58, height: 0.58, shape: .circle, fill: "#D1D5DB")
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

    @discardableResult
    private static func addDecoration(
        label: String,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        cornerRadius: CGFloat?,
        style: GamepadControlVisualStyle
    ) -> UUID {
        let control = GamepadCustomButton(
            mappedButton: .custom8,
            label: label,
            layout: GamepadButtonCustomization(
                centerX: x,
                centerY: y,
                widthScale: width,
                heightScale: height,
                shape: shape,
                fillColor: GamepadRGBAColor(hexString: "#F2EEF5") ?? .defaultValue,
                visualStyle: style,
                cornerRadius: cornerRadius,
                shadowStrength: 0
            ),
            controlKind: .decoration
        )
        customization.customButtons.append(control)
        return control.id
    }

    @discardableResult
    private static func addIconDecoration(
        label: String,
        icon: String,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        cornerRadius: CGFloat?,
        style: GamepadControlVisualStyle,
        iconScale: CGFloat
    ) -> UUID {
        let controlID = addDecoration(
            label: label,
            in: &customization,
            x: x,
            y: y,
            width: width,
            height: height,
            shape: shape,
            cornerRadius: cornerRadius,
            style: style
        )
        guard let index = customization.customButtons.firstIndex(where: { $0.id == controlID }) else { return controlID }
        customization.customButtons[index].layout.icon = GamepadControlIcon(
            source: .text,
            value: icon,
            placement: .center,
            scale: iconScale,
            tintColor: style.normal.foregroundColor,
            renderingMode: .template
        ).normalized
        return controlID
    }

    private static func hideButton(_ button: GameButton, in customization: inout GamepadCustomization) {
        var layout = customization.buttonCustomization(for: button)
        layout.isHidden = true
        customization.setButtonCustomization(layout, for: button)
    }

    private static func setReferenceButton(
        _ button: GameButton,
        label: String,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        iconScale: CGFloat,
        cornerRadius: CGFloat? = nil
    ) {
        customization.setButtonCustomization(
            referenceButtonLayout(label: label, x: x, y: y, width: width, height: height, shape: shape, cornerRadius: cornerRadius, iconScale: iconScale),
            for: button
        )
        customization.setLabel(label, for: button)
    }

    @discardableResult
    private static func addReferenceButton(
        mappedTo button: GameButton,
        label: String,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        cornerRadius: CGFloat?,
        iconScale: CGFloat
    ) -> UUID {
        let control = GamepadCustomButton(
            mappedButton: button,
            label: label,
            layout: referenceButtonLayout(label: label, x: x, y: y, width: width, height: height, shape: shape, cornerRadius: cornerRadius, iconScale: iconScale),
            controlKind: .button
        )
        customization.customButtons.append(control)
        return control.id
    }

    @discardableResult
    private static func addReferenceJoystick(
        label: String,
        mappedButton: GameButton,
        mapping: GamepadJoystickMapping,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat
    ) -> UUID {
        var layout = GamepadButtonCustomization(
            centerX: x,
            centerY: y,
            widthScale: scale,
            heightScale: scale,
            shape: .circle,
            fillColor: GamepadRGBAColor(hexString: "#ECE8F0") ?? .defaultValue,
            visualStyle: referenceInsetStyle(),
            shadowStrength: 0,
            isLocationLocked: false,
            isHidden: false
        )
        layout.joystickVisualStyle = .pad
        layout.joystickKnobColor = GamepadRGBAColor(hexString: "#DAD3E2")
        let control = GamepadCustomButton(
            mappedButton: mappedButton,
            label: label,
            layout: layout,
            controlKind: .joystick,
            joystickMapping: mapping
        )
        customization.customButtons.append(control)
        return control.id
    }

    private static func referenceButtonLayout(
        label: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        cornerRadius: CGFloat?,
        iconScale: CGFloat
    ) -> GamepadButtonCustomization {
        var layout = GamepadButtonCustomization(
            centerX: x,
            centerY: y,
            widthScale: width,
            heightScale: height,
            shape: shape,
            fillColor: GamepadRGBAColor(hexString: "#F5F2F7") ?? .defaultValue,
            styleID: "reference-white-raised",
            visualStyle: referenceRaisedStyle(),
            cornerRadius: cornerRadius,
            shadowStrength: 0,
            isLocationLocked: false,
            isHidden: false
        )
        layout.icon = GamepadControlIcon(
            source: .text,
            value: label,
            placement: .center,
            scale: iconScale,
            tintColor: GamepadRGBAColor(hexString: "#7A62A2"),
            renderingMode: .template
        ).normalized
        return layout
    }

    private static func referenceShellStyle() -> GamepadControlVisualStyle {
        GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(
                fillStyle: .gradient(
                    GamepadGradientFill(
                        type: .linear,
                        angleDegrees: 135,
                        stops: [
                            GamepadGradientStop(offset: 0.0, color: GamepadRGBAColor(hexString: "#FAF9FB") ?? .defaultValue),
                            GamepadGradientStop(offset: 0.55, color: GamepadRGBAColor(hexString: "#F0EDF3") ?? .defaultValue),
                            GamepadGradientStop(offset: 1.0, color: GamepadRGBAColor(hexString: "#E8E3ED") ?? .defaultValue)
                        ]
                    )
                ),
                foregroundColor: GamepadRGBAColor(hexString: "#7860A0"),
                strokeColor: GamepadRGBAColor(hexString: "#18131E", alpha: 0.82),
                strokeWidth: 2,
                shadows: [
                    .outer("#000000", alpha: 0.38, radius: 10, x: 0, y: 6),
                    .outer("#FFFFFF", alpha: 0.36, radius: 6, x: -2, y: -2)
                ],
                highlightColor: GamepadRGBAColor(hexString: "#FFFFFF"),
                highlightRadius: 18,
                highlightX: -7,
                highlightY: -7,
                highlightOpacity: 0.26,
                bevelHighlightColor: GamepadRGBAColor(hexString: "#FFFFFF", alpha: 0.72),
                bevelShadowColor: GamepadRGBAColor(hexString: "#BDB5C6", alpha: 0.50),
                bevelWidth: 1.0
            )
        )
    }

    private static func referenceRaisedStyle(
        fill: GamepadRGBAColor = GamepadRGBAColor(hexString: "#F7F4F8") ?? .defaultValue,
        foreground: GamepadRGBAColor = GamepadRGBAColor(hexString: "#7A62A2") ?? .defaultValue
    ) -> GamepadControlVisualStyle {
        GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(
                fillStyle: .solid(fill),
                foregroundColor: foreground,
                strokeColor: GamepadRGBAColor(hexString: "#FFFFFF", alpha: 0.76),
                strokeWidth: 1.2,
                shadows: [
                    .outer("#FFFFFF", alpha: 0.90, radius: 5, x: -2, y: -2),
                    .outer("#776C84", alpha: 0.34, radius: 5, x: 0, y: 3),
                    .outer("#A99FB4", alpha: 0.20, radius: 12, x: 5, y: 7)
                ],
                highlightColor: GamepadRGBAColor(hexString: "#FFFFFF"),
                highlightRadius: 6,
                highlightX: -3,
                highlightY: -3,
                highlightOpacity: 0.28,
                bevelHighlightColor: GamepadRGBAColor(hexString: "#FFFFFF", alpha: 0.78),
                bevelShadowColor: GamepadRGBAColor(hexString: "#AFA6B9", alpha: 0.58),
                bevelWidth: 1.0
            ),
            pressed: GamepadControlStateStyle(
                fillStyle: .solid(GamepadRGBAColor(hexString: "#EDE8F1") ?? fill),
                shadows: [
                    .outer("#FFFFFF", alpha: 0.54, radius: 3, x: -1, y: -1),
                    .outer("#7B7188", alpha: 0.24, radius: 4, x: 1, y: 2)
                ],
                innerShadowColor: GamepadRGBAColor(hexString: "#9E94AB", alpha: 0.32),
                innerShadowRadius: 4,
                innerShadowX: 1,
                innerShadowY: 2,
                scale: 0.975
            ),
            hapticFeedback: GamepadHapticFeedback(style: .soft, pattern: .single, intensity: 0.42, sharpness: 0.22)
        )
    }

    private static func referenceInsetStyle() -> GamepadControlVisualStyle {
        GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(
                fillStyle: .solid(GamepadRGBAColor(hexString: "#ECE8F0") ?? .defaultValue),
                foregroundColor: GamepadRGBAColor(hexString: "#7A62A2"),
                strokeColor: GamepadRGBAColor(hexString: "#FFFFFF", alpha: 0.56),
                strokeWidth: 1,
                shadows: [
                    .outer("#FFFFFF", alpha: 0.72, radius: 6, x: -3, y: -3),
                    .outer("#8D819A", alpha: 0.28, radius: 8, x: 3, y: 5)
                ],
                innerShadowColor: GamepadRGBAColor(hexString: "#9D94AA", alpha: 0.38),
                innerShadowRadius: 7,
                innerShadowX: 3,
                innerShadowY: 3,
                highlightColor: GamepadRGBAColor(hexString: "#FFFFFF"),
                highlightRadius: 7,
                highlightX: -3,
                highlightY: -3,
                highlightOpacity: 0.18,
                bevelHighlightColor: GamepadRGBAColor(hexString: "#FFFFFF", alpha: 0.64),
                bevelShadowColor: GamepadRGBAColor(hexString: "#AAA0B7", alpha: 0.48),
                bevelWidth: 1
            )
        )
    }

    private static func referenceGridStyle() -> GamepadControlVisualStyle {
        GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(
                fillStyle: .tile(
                    GamepadTileFill(
                        pattern: .grid,
                        foregroundColor: GamepadRGBAColor(hexString: "#BFB7CA", alpha: 0.48) ?? .defaultValue,
                        backgroundColor: GamepadRGBAColor(hexString: "#D7D0DF") ?? .defaultValue,
                        scale: 0.55,
                        spacingX: 0,
                        spacingY: 0,
                        alignment: .center,
                        opacity: 1
                    )
                ),
                foregroundColor: GamepadRGBAColor(hexString: "#7A62A2"),
                strokeColor: GamepadRGBAColor(hexString: "#EEEAF3", alpha: 0.88),
                strokeWidth: 1,
                shadows: [
                    .outer("#FFFFFF", alpha: 0.42, radius: 3, x: -1, y: -1),
                    .outer("#81758E", alpha: 0.18, radius: 5, x: 1, y: 2)
                ],
                bevelHighlightColor: GamepadRGBAColor(hexString: "#FFFFFF", alpha: 0.54),
                bevelShadowColor: GamepadRGBAColor(hexString: "#AFA6B9", alpha: 0.36),
                bevelWidth: 0.75
            )
        )
    }

    private static func referenceMarkerStyle() -> GamepadControlVisualStyle {
        GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(
                fillStyle: .solid(GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: 0.001)),
                foregroundColor: GamepadRGBAColor(hexString: "#8A72B0"),
                strokeColor: GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: 0.001),
                strokeWidth: 0,
                opacity: 0.92
            )
        )
    }

    private static func referenceBadgeStyle() -> GamepadControlVisualStyle {
        GamepadControlVisualStyle(
            normal: GamepadControlStateStyle(
                fillStyle: .solid(GamepadRGBAColor(hexString: "#111111") ?? .defaultValue),
                foregroundColor: GamepadRGBAColor(hexString: "#FFFFFF"),
                strokeColor: GamepadRGBAColor(hexString: "#FFFFFF"),
                strokeWidth: 2,
                shadows: [
                    .outer("#000000", alpha: 0.42, radius: 4, x: 0, y: 2)
                ]
            )
        )
    }

    private static func setSoftButton(
        _ button: GameButton,
        label: String,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        cornerRadius: CGFloat?
    ) {
        customization.setButtonCustomization(
            softButtonLayout(x: x, y: y, width: width, height: height, shape: shape, cornerRadius: cornerRadius),
            for: button
        )
        customization.setLabel(label, for: button)
    }

    private static func addSoftButton(
        mappedTo button: GameButton,
        label: String,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle
    ) {
        customization.customButtons.append(
            GamepadCustomButton(
                mappedButton: button,
                label: label,
                layout: softButtonLayout(x: x, y: y, width: width, height: height, shape: shape, cornerRadius: nil),
                controlKind: .button
            )
        )
    }

    private static func addSoftJoystick(
        label: String,
        mappedButton: GameButton,
        mapping: GamepadJoystickMapping,
        in customization: inout GamepadCustomization,
        x: CGFloat,
        y: CGFloat,
        scale: CGFloat
    ) {
        var layout = softButtonLayout(x: x, y: y, width: scale, height: scale, shape: .circle, cornerRadius: nil)
        layout.visualStyle = .softWhiteInset()
        layout.joystickKnobColor = GamepadRGBAColor(hexString: "#FAF8FB")
        layout.joystickVisualStyle = .thumbstick
        customization.customButtons.append(
            GamepadCustomButton(
                mappedButton: mappedButton,
                label: label,
                layout: layout,
                controlKind: .joystick,
                joystickMapping: mapping
            )
        )
    }

    private static func softButtonLayout(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        shape: GamepadButtonShapeStyle,
        cornerRadius: CGFloat?
    ) -> GamepadButtonCustomization {
        GamepadButtonCustomization(
            centerX: x,
            centerY: y,
            widthScale: width,
            heightScale: height,
            shape: shape,
            fillColor: GamepadRGBAColor(hexString: "#F8F6FA") ?? .defaultValue,
            styleID: "soft-white-raised",
            visualStyle: .softWhiteRaised(),
            cornerRadius: cornerRadius,
            shadowStrength: 0,
            isLocationLocked: false,
            isHidden: false
        )
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
    private static let legacySeededDefaultProfileNames = [
        "Current Setup",
        "NES",
        "Super Nintendo",
        "Nintendo 64",
        "GameCube",
        "Game Boy",
        "Game Boy Advance",
        "Genesis 6-Button",
        "Sega Saturn",
        "Dreamcast",
        "Arcade Stick",
        "PSP",
        "PlayStation",
        "Xbox",
        "Soft White Pro",
        "Navigation Left",
        "Actions Left",
        "Dual Stick Shooter",
        "Large Blue",
        "Compact Minimal"
    ]

    static func load(activeCustomization: GamepadCustomization) -> LoadedState {
        let activeCustomization = activeCustomization.normalized

        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let stored = try? JSONDecoder().decode(StoredState.self, from: data) {
            var profiles = normalizedUniqueProfiles(stored.profiles)
            if let migratedState = migratedLegacySeededDefaultStateIfNeeded(
                profiles: profiles,
                activeProfileID: stored.activeProfileID,
                activeCustomization: activeCustomization
            ) {
                return migratedState
            }

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

    private static func migratedLegacySeededDefaultStateIfNeeded(
        profiles: [GamepadConfigurationProfile],
        activeProfileID: UUID?,
        activeCustomization: GamepadCustomization
    ) -> LoadedState? {
        guard isLegacySeededDefaultProfileList(profiles) else { return nil }

        let selectedProfileID = validProfileID(activeProfileID, in: profiles) ?? profiles[0].id
        var starterProfile = profiles.first { $0.id == selectedProfileID } ?? profiles[0]
        let normalizedActiveCustomization = activeCustomization.normalized
        let activeLooksLikeOldDefault = normalizedActiveCustomization.hasSamePresentation(as: GamepadCustomization.defaultValue.normalized)
            || normalizedActiveCustomization.hasSamePresentation(as: GamepadCustomization.blankCanvas)

        if starterProfile.name == "Current Setup", activeLooksLikeOldDefault {
            starterProfile.name = "My First Keypad"
            starterProfile.customization = GamepadCustomization.blankCanvas
        } else {
            starterProfile.customization = normalizedActiveCustomization
        }

        starterProfile.landscapeCustomization = nil
        starterProfile.portraitCustomization = nil
        starterProfile.updatedAt = Date.currentMilliseconds
        let normalizedProfile = starterProfile.normalized
        return LoadedState(
            profiles: [normalizedProfile],
            activeProfileID: normalizedProfile.id,
            defaultProfileID: normalizedProfile.id
        )
    }

    private static func isLegacySeededDefaultProfileList(_ profiles: [GamepadConfigurationProfile]) -> Bool {
        profiles.map(\.name) == legacySeededDefaultProfileNames
    }

    private static func defaultProfiles(activeCustomization: GamepadCustomization) -> [GamepadConfigurationProfile] {
        let normalizedActiveCustomization = activeCustomization.normalized
        let defaultCustomization = GamepadCustomization.defaultValue.normalized
        let blankCustomization = GamepadCustomization.blankCanvas
        let hasLegacyCustomization = !normalizedActiveCustomization.hasSamePresentation(as: defaultCustomization)
            && !normalizedActiveCustomization.hasSamePresentation(as: blankCustomization)
        let starterCustomization = hasLegacyCustomization
            ? normalizedActiveCustomization
            : GamepadCustomization.blankCanvas
        let starterName = hasLegacyCustomization ? "Current Setup" : "My First Keypad"

        return [
            GamepadConfigurationProfile(name: starterName, customization: starterCustomization)
        ]
    }
}

enum GamepadProfileSelectionLogic {
    static func normalizedExplicitSelection(_ selection: Set<UUID>, validProfileIDs: Set<UUID>) -> Set<UUID> {
        selection.intersection(validProfileIDs)
    }

    static func actionIDs(
        explicitSelection: Set<UUID>,
        activeID: UUID,
        orderedProfileIDs: [UUID]
    ) -> Set<UUID> {
        let validProfileIDs = Set(orderedProfileIDs)
        let normalizedSelection = normalizedExplicitSelection(explicitSelection, validProfileIDs: validProfileIDs)
        if !normalizedSelection.isEmpty {
            return normalizedSelection
        }
        if validProfileIDs.contains(activeID) {
            return [activeID]
        }
        if let fallbackID = orderedProfileIDs.first {
            return [fallbackID]
        }
        return []
    }

    static func toggledExplicitSelection(
        _ profileID: UUID,
        currentExplicitSelection: Set<UUID>,
        orderedProfileIDs: [UUID]
    ) -> Set<UUID> {
        let validProfileIDs = Set(orderedProfileIDs)
        var selection = normalizedExplicitSelection(currentExplicitSelection, validProfileIDs: validProfileIDs)
        guard validProfileIDs.contains(profileID) else { return selection }

        if selection.contains(profileID) {
            selection.remove(profileID)
        } else {
            selection.insert(profileID)
        }
        return selection
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

struct GamepadControlEffectOverlay<S: Shape>: View {
    let shape: S
    let presentation: GamepadResolvedControlPresentation

    var body: some View {
        ZStack {
            highlightLayer
            bevelLayer
            innerShadowLayer
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var highlightLayer: some View {
        if let color = effectiveHighlightColor, effectiveHighlightOpacity > 0 {
            shape
                .fill(color.opacity(effectiveHighlightOpacity))
                .blur(radius: presentation.highlightRadius)
                .offset(x: presentation.highlightX, y: presentation.highlightY)
                .mask(shape)
        }
    }

    @ViewBuilder
    private var bevelLayer: some View {
        if presentation.bevelWidth > 0 {
            shape.stroke(
                LinearGradient(
                    colors: [effectiveBevelHighlightColor, effectiveBevelShadowColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: presentation.bevelWidth
            )
        }
    }

    @ViewBuilder
    private var innerShadowLayer: some View {
        if let color = effectiveInnerShadowColor, presentation.innerShadowRadius > 0 {
            shape
                .stroke(color, lineWidth: max(1, presentation.innerShadowRadius * 2.0))
                .blur(radius: presentation.innerShadowRadius)
                .offset(x: presentation.innerShadowX, y: presentation.innerShadowY)
                .mask(shape)
        }
    }

    private var effectiveInnerShadowColor: Color? {
        if let color = presentation.innerShadowSwiftUIColor { return color }
        return presentation.innerShadowRadius > 0 ? Color.black.opacity(0.22) : nil
    }

    private var effectiveHighlightColor: Color? {
        guard presentation.highlightOpacity > 0 else { return nil }
        return presentation.highlightSwiftUIColor ?? Color.white
    }

    private var effectiveHighlightOpacity: Double {
        Double(min(max(presentation.highlightOpacity, 0), 1))
    }

    private var effectiveBevelHighlightColor: Color {
        presentation.bevelHighlightSwiftUIColor ?? Color.white.opacity(0.62)
    }

    private var effectiveBevelShadowColor: Color {
        presentation.bevelShadowSwiftUIColor ?? Color.black.opacity(0.24)
    }
}

struct GamepadFillShapeLayer<S: Shape>: View {
    let shape: S
    let fillStyle: GamepadFillStyle

    var body: some View {
        GeometryReader { proxy in
            fillContent(size: proxy.size)
        }
    }

    @ViewBuilder
    private func fillContent(size: CGSize) -> some View {
        switch fillStyle.normalized {
        case .solid(let color):
            shape.fill(color.swiftUIColor)
        case .gradient(let gradient):
            switch gradient.type {
            case .linear:
                shape.fill(
                    LinearGradient(
                        stops: gradient.stops.map { Gradient.Stop(color: $0.color.swiftUIColor, location: $0.offset) },
                        startPoint: gradient.linearStartPoint,
                        endPoint: gradient.linearEndPoint
                    )
                )
            case .radial:
                shape.fill(
                    RadialGradient(
                        stops: gradient.stops.map { Gradient.Stop(color: $0.color.swiftUIColor, location: $0.offset) },
                        center: .center,
                        startRadius: 0,
                        endRadius: max(size.width, size.height)
                    )
                )
            }
        case .tile(let tile):
            GamepadTilePatternFillView(fill: tile)
                .clipShape(shape)
        case .image(let image):
            GamepadImageFillView(fill: image)
                .clipShape(shape)
        }
    }
}

private extension GamepadGradientFill {
    var linearStartPoint: UnitPoint {
        let vector = linearVector
        return UnitPoint(x: 0.5 - vector.dx, y: 0.5 - vector.dy)
    }

    var linearEndPoint: UnitPoint {
        let vector = linearVector
        return UnitPoint(x: 0.5 + vector.dx, y: 0.5 + vector.dy)
    }

    private var linearVector: CGVector {
        let radians = normalized.angleDegrees * .pi / 180
        return CGVector(dx: cos(radians) * 0.5, dy: sin(radians) * 0.5)
    }
}

private struct GamepadTilePatternFillView: View {
    let fill: GamepadTileFill

    var body: some View {
        let normalized = fill.normalized
        ZStack {
            normalized.backgroundColor.swiftUIColor
            Canvas { context, size in
                drawPattern(normalized, context: &context, size: size)
            }
        }
    }

    private func drawPattern(_ fill: GamepadTileFill, context: inout GraphicsContext, size: CGSize) {
        let spacingX = max(5, 13 * fill.scale + fill.spacingX * 18)
        let spacingY = max(5, 13 * fill.scale + fill.spacingY * 18)
        let foreground = fill.foregroundColor.withAlpha(fill.foregroundColor.alpha * fill.opacity).swiftUIColor

        switch fill.pattern {
        case .dots:
            let radius = max(1.2, 2.1 * fill.scale)
            for x in stride(from: alignmentOffset(fill.alignment, axisLength: size.width, spacing: spacingX, isHorizontal: true), through: size.width + spacingX, by: spacingX) {
                for y in stride(from: alignmentOffset(fill.alignment, axisLength: size.height, spacing: spacingY, isHorizontal: false), through: size.height + spacingY, by: spacingY) {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(foreground))
                }
            }
        case .grid:
            var path = Path()
            for x in stride(from: alignmentOffset(fill.alignment, axisLength: size.width, spacing: spacingX, isHorizontal: true), through: size.width + spacingX, by: spacingX) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: alignmentOffset(fill.alignment, axisLength: size.height, spacing: spacingY, isHorizontal: false), through: size.height + spacingY, by: spacingY) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(foreground), lineWidth: max(1, fill.scale))
        case .checker:
            let square = max(6, 12 * fill.scale)
            let columns = Int(ceil(size.width / square)) + 2
            let rows = Int(ceil(size.height / square)) + 2
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(x: CGFloat(column) * square - square, y: CGFloat(row) * square - square, width: square, height: square)
                    context.fill(Path(rect), with: .color(foreground))
                }
            }
        case .diagonal:
            var path = Path()
            let spacing = max(7, 14 * fill.scale + max(fill.spacingX, fill.spacingY) * 18)
            for offset in stride(from: -size.height, through: size.width + size.height, by: spacing) {
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
            }
            context.stroke(path, with: .color(foreground), lineWidth: max(1.5, 2 * fill.scale))
        }
    }

    private func alignmentOffset(_ alignment: GamepadTileAlignment, axisLength: CGFloat, spacing: CGFloat, isHorizontal: Bool) -> CGFloat {
        let isLeading: Bool
        let isTrailing: Bool
        if isHorizontal {
            isLeading = [.topLeading, .leading, .bottomLeading].contains(alignment)
            isTrailing = [.topTrailing, .trailing, .bottomTrailing].contains(alignment)
        } else {
            isLeading = [.topLeading, .top, .topTrailing].contains(alignment)
            isTrailing = [.bottomLeading, .bottom, .bottomTrailing].contains(alignment)
        }
        if isLeading { return 0 }
        if isTrailing { return axisLength.truncatingRemainder(dividingBy: spacing) }
        return (axisLength.truncatingRemainder(dividingBy: spacing)) / 2
    }
}

private enum GamepadImageDecodeCache {
#if os(macOS)
    private static let cache: NSCache<NSData, NSImage> = {
        let cache = NSCache<NSData, NSImage>()
        cache.countLimit = 32
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func image(for data: Data) -> NSImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = NSImage(data: data) else { return nil }
        cache.setObject(image, forKey: key, cost: data.count)
        return image
    }
#elseif os(iOS)
    private static let cache: NSCache<NSData, UIImage> = {
        let cache = NSCache<NSData, UIImage>()
        cache.countLimit = 32
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    static func image(for data: Data) -> UIImage? {
        let key = data as NSData
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key, cost: data.count)
        return image
    }
#endif
}

private struct GamepadImageFillView: View {
    let fill: GamepadImageFill

    var body: some View {
        let normalized = fill.normalized
        ZStack {
            GamepadAlphaCheckerboard()
            if let data = normalized.data {
                platformImage(data: data, contentMode: normalized.contentMode)
                    .opacity(Double(normalized.opacity))
                    .brightness(Double(normalized.exposure) * 0.22 + Double(normalized.shadows) * 0.08 - Double(normalized.highlights) * 0.04)
                    .contrast(1 + Double(normalized.contrast) * 0.55)
                    .saturation(max(0, 1 + Double(normalized.saturation) * 0.8))
                    .hueRotation(.degrees(Double(normalized.tint + normalized.temperature) * 10))
            } else {
                VStack(spacing: Geist.Spacing.s2) {
                    Image(systemName: "photo")
                        .font(.system(size: 22, weight: .medium))
                    Text("No image")
                        .geistTypography(.label12)
                }
                .foregroundStyle(Color.white.opacity(0.74))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.72))
            }
        }
    }

    @ViewBuilder
    private func platformImage(data: Data, contentMode: GamepadImageContentMode) -> some View {
#if os(macOS)
        if let image = GamepadImageDecodeCache.image(for: data) {
            resizableImage(Image(nsImage: image), contentMode: contentMode)
        }
#elseif os(iOS)
        if let image = GamepadImageDecodeCache.image(for: data) {
            resizableImage(Image(uiImage: image), contentMode: contentMode)
        }
#endif
    }

    @ViewBuilder
    private func resizableImage(_ image: Image, contentMode: GamepadImageContentMode) -> some View {
        switch contentMode {
        case .fill:
            image
                .resizable()
                .scaledToFill()
        case .fit:
            image
                .resizable()
                .scaledToFit()
        case .tile:
            image
                .resizable(resizingMode: .tile)
        }
    }
}

private struct GamepadFillPreview<S: Shape>: View {
    let shape: S
    let fillStyle: GamepadFillStyle

    var body: some View {
        GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
            .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 1))
    }
}

private extension View {
    func gamepadOuterShadows(_ presentation: GamepadResolvedControlPresentation) -> some View {
        modifier(GamepadOuterShadowModifier(presentation: presentation))
    }
}

private struct GamepadOuterShadowModifier: ViewModifier {
    let presentation: GamepadResolvedControlPresentation

    func body(content: Content) -> some View {
        var view = AnyView(content)
        if presentation.shadows.isEmpty {
            view = AnyView(
                view.shadow(
                    color: presentation.shadowSwiftUIColor,
                    radius: presentation.shadowRadius,
                    x: presentation.shadowX,
                    y: presentation.shadowY
                )
            )
        } else {
            for shadow in presentation.shadows {
                let normalized = shadow.normalized
                view = AnyView(
                    view.shadow(
                        color: normalized.swiftUIColor,
                        radius: normalized.radius,
                        x: normalized.x,
                        y: normalized.y
                    )
                )
            }
        }
        return view
    }
}

private struct GamepadControlBarPreviewContext: Equatable {
    var profileName: String
    var hasProfiles: Bool
    var isSelectedProfileDefault: Bool
    var launchTarget: GamepadProfileLaunchTarget?
    var isConnected: Bool

    static let placeholder = GamepadControlBarPreviewContext(
        profileName: "Current Setup",
        hasProfiles: true,
        isSelectedProfileDefault: false,
        launchTarget: nil,
        isConnected: false
    )
}

private struct GamepadControlBarPreviewContextKey: EnvironmentKey {
    static let defaultValue = GamepadControlBarPreviewContext.placeholder
}

private extension EnvironmentValues {
    var gamepadControlBarPreviewContext: GamepadControlBarPreviewContext {
        get { self[GamepadControlBarPreviewContextKey.self] }
        set { self[GamepadControlBarPreviewContextKey.self] = newValue }
    }
}

struct GamepadRenderedControlFace: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.gamepadControlBarPreviewContext) private var controlBarPreviewContext
    let control: GamepadResolvedControl
    let customization: GamepadCustomization
    var state: GamepadControlPresentationState = .normal
    var selectedControlBarItem: GamepadControlBarItem? = nil
    var onSelectControlBarItem: ((GamepadControlBarItem) -> Void)? = nil
    var onMoveControlBarItem: ((GamepadControlBarItem, Int) -> Void)? = nil

    @ViewBuilder
    var body: some View {
        if control.id == .system(.topBarActivation) {
            GamepadControlBarOutputPreview(
                customization: customization,
                items: customization.normalized.controlBarItems,
                isLandscape: customization.deviceCanvas.editorDeviceFrame.isLandscape,
                context: controlBarPreviewContext,
                selectedItem: selectedControlBarItem,
                onSelectItem: onSelectControlBarItem,
                onMoveItem: onMoveControlBarItem
            )
            .frame(width: control.size.width, height: control.size.height, alignment: .top)
            .accessibilityLabel(control.label)
        } else {
            let presentation = resolvedPresentation

            ZStack {
                if let glowColor = presentation.glowSwiftUIColor, presentation.glowRadius > 0 {
                    controlSilhouette(fill: glowColor)
                        .blur(radius: presentation.glowRadius)
                        .opacity(0.68)
                        .allowsHitTesting(false)
                }

                controlBackground(presentation: presentation)
                    .gamepadOuterShadows(presentation)

                if control.isDecoration {
                    if let icon = presentation.icon {
                        controlIcon(icon, presentation: presentation)
                            .padding(.horizontal, 4)
                    }
                } else if control.isJoystick {
                    joystickFace(presentation: presentation)
                } else if control.isTrackpad {
                    trackpadFace(presentation: presentation)
                } else {
                    buttonContent(presentation: presentation)
                }
            }
            .opacity(presentation.opacity)
            .blur(radius: presentation.blurRadius)
            .scaleEffect(presentation.scale)
            .frame(width: control.size.width, height: control.size.height)
            .accessibilityLabel(control.label)
        }
    }

    private var resolvedPresentation: GamepadResolvedControlPresentation {
        customization.resolvedPresentation(for: control, state: state, scheme: colorScheme)
    }

    private var resolvedAccentStyle: GamepadAccentStyle {
        control.layoutCustomization.accentStyle ?? customization.accentStyle
    }

    private var resolvedCornerRadii: GamepadCornerRadii {
        control.layoutCustomization.resolvedCornerRadii(defaultRadius: control.shape.defaultEditableCornerRadius(in: control.size))
    }

    @ViewBuilder
    private func controlBackground(presentation: GamepadResolvedControlPresentation) -> some View {
        let fillStyle = presentation.fillStyle
        let strokeColor = presentation.strokeSwiftUIColor
        let lineWidth = presentation.strokeWidth

        switch control.shape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            let shape = UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay(GamepadControlEffectOverlay(shape: shape, presentation: presentation))
        case .polygon:
            let shape = GamepadRegularPolygonButtonShape(sides: 3)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay(GamepadControlEffectOverlay(shape: shape, presentation: presentation))
        case .star:
            let shape = GamepadStarButtonShape(points: 5)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay(GamepadControlEffectOverlay(shape: shape, presentation: presentation))
        }
    }

    @ViewBuilder
    private func controlSilhouette(fill color: Color) -> some View {
        switch control.shape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)
                .fill(color)
        case .polygon:
            GamepadRegularPolygonButtonShape(sides: 3)
                .fill(color)
        case .star:
            GamepadStarButtonShape(points: 5)
                .fill(color)
        }
    }

    @ViewBuilder
    private func buttonContent(presentation: GamepadResolvedControlPresentation) -> some View {
        if let icon = presentation.icon {
            controlIcon(icon, presentation: presentation)
                .padding(.horizontal, 4)
        }

        if customization.showsButtonLabels && (presentation.icon?.placement != .center || control.label.count <= 2) {
            Text(control.label)
                .geistTypography(control.label.count <= 2 ? .heading32 : .button16)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(presentation.foregroundSwiftUIColor)
                .padding(.horizontal, 4)
                .offset(labelOffset(for: presentation.icon?.placement))
        }
    }

    private func controlIcon(_ icon: GamepadControlIcon, presentation: GamepadResolvedControlPresentation) -> some View {
        let tint = icon.tintColor?.swiftUIColor ?? presentation.foregroundSwiftUIColor
        let baseSize = max(12, min(control.size.width, control.size.height) * 0.34 * icon.scale)

        return Group {
            switch icon.source {
            case .sfSymbol:
                Image(systemName: icon.value)
                    .font(.system(size: baseSize, weight: .semibold))
                    .symbolRenderingMode(icon.renderingMode == .multicolor ? .multicolor : .monochrome)
                    .foregroundStyle(tint)
            case .text:
                Text(icon.value)
                    .font(.system(size: baseSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            case .asset:
                Text("▧")
                    .font(.system(size: baseSize, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.72))
            }
        }
        .offset(iconOffset(for: icon.placement))
    }

    private func iconOffset(for placement: GamepadControlIconPlacement) -> CGSize {
        switch placement {
        case .leading: CGSize(width: -control.size.width * 0.20, height: 0)
        case .trailing: CGSize(width: control.size.width * 0.20, height: 0)
        case .top: CGSize(width: 0, height: -control.size.height * 0.18)
        case .bottom: CGSize(width: 0, height: control.size.height * 0.18)
        case .center, .background: .zero
        }
    }

    private func labelOffset(for placement: GamepadControlIconPlacement?) -> CGSize {
        switch placement {
        case .leading: CGSize(width: control.size.width * 0.11, height: 0)
        case .trailing: CGSize(width: -control.size.width * 0.11, height: 0)
        case .top: CGSize(width: 0, height: control.size.height * 0.15)
        case .bottom: CGSize(width: 0, height: -control.size.height * 0.15)
        case .center, .background, nil: .zero
        }
    }

    private func joystickFace(presentation: GamepadResolvedControlPresentation) -> some View {
        let knobFillColor = control.layoutCustomization.joystickKnobFill(accentStyle: resolvedAccentStyle, isPressed: state.usesPressedFallback, scheme: colorScheme)
        let knobStrokeColor = control.layoutCustomization.joystickKnobStroke(accentStyle: resolvedAccentStyle, isPressed: state.usesPressedFallback, scheme: colorScheme)
        let visualSide = min(control.size.width, control.size.height)
        let isThumbstick = control.layoutCustomization.joystickVisualStyle == .thumbstick
        let knobRatio: CGFloat = isThumbstick ? 0.72 : 0.34

        return ZStack {
            if !isThumbstick {
                Circle()
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                    .frame(width: visualSide * 0.70, height: visualSide * 0.70)
            }

            Circle()
                .fill(knobFillColor)
                .overlay(Circle().stroke(knobStrokeColor, lineWidth: 1))
                .frame(width: visualSide * knobRatio, height: visualSide * knobRatio)

            if customization.showsButtonLabels && !isThumbstick {
                Text(control.label)
                    .geistTypography(visualSide <= 88 ? .button12 : .button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .foregroundStyle(presentation.foregroundSwiftUIColor)
                    .padding(.horizontal, 4)
                    .offset(y: control.size.height * (isThumbstick ? 0.58 : 0.34))
            }
        }
        .allowsHitTesting(false)
    }

    private func trackpadFace(presentation: GamepadResolvedControlPresentation) -> some View {
        let foreground = presentation.foregroundSwiftUIColor

        return ZStack {
            RoundedRectangle(cornerRadius: max(5, min(control.size.width, control.size.height) * 0.08), style: .continuous)
                .stroke(foreground.opacity(0.24), lineWidth: 1)
                .padding(max(5, min(control.size.width, control.size.height) * 0.08))

            HStack(spacing: 9) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: max(12, min(control.size.width, control.size.height) * 0.18), weight: .semibold))
                if customization.showsButtonLabels {
                    Text(control.label)
                        .geistTypography(control.size.width <= 96 ? .button12 : .button14)
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                }
            }
            .foregroundStyle(foreground.opacity(0.82))

            HStack(spacing: 7) {
                Capsule().fill(foreground.opacity(0.34))
                Capsule().fill(foreground.opacity(0.18))
            }
            .frame(width: control.size.width * 0.34, height: 5)
            .offset(y: control.size.height * 0.36)
        }
        .allowsHitTesting(false)
    }
}

private struct GamepadControlBarEditorItem<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let item: GamepadControlBarItem
    let isSelected: Bool
    let onSelect: ((GamepadControlBarItem) -> Void)?
    let onMove: ((GamepadControlBarItem, Int) -> Void)?
    @ViewBuilder let content: Content

    init(
        item: GamepadControlBarItem,
        isSelected: Bool,
        onSelect: ((GamepadControlBarItem) -> Void)?,
        onMove: ((GamepadControlBarItem, Int) -> Void)?,
        @ViewBuilder content: () -> Content
    ) {
        self.item = item
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onMove = onMove
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if let onSelect {
            content
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                            .stroke(Geist.color(.blue700, scheme: colorScheme), lineWidth: 2)
                            .padding(-3)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in onSelect(item) }
                        .onEnded { value in
                            let stepWidth: CGFloat = 44
                            let offset = Int((value.translation.width / stepWidth).rounded())
                            if offset != 0 {
                                onMove?(item, offset)
                            }
                        }
                )
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint("Select and drag horizontally to reorder this control-bar item")
        } else {
            content
                .allowsHitTesting(false)
        }
    }
}

private struct GamepadControlBarOutputPreview: View {
    @Environment(\.colorScheme) private var colorScheme
    let customization: GamepadCustomization
    let items: [GamepadControlBarItem]
    let isLandscape: Bool
    let context: GamepadControlBarPreviewContext
    let selectedItem: GamepadControlBarItem?
    let onSelectItem: ((GamepadControlBarItem) -> Void)?
    let onMoveItem: ((GamepadControlBarItem, Int) -> Void)?

    var body: some View {
        VStack(spacing: Geist.Spacing.s1) {
            GamepadControlBarLayout(
                items: visibleItems,
                isLandscape: isLandscape
            ) { item, isCompact in
                GamepadControlBarEditorItem(
                    item: item,
                    isSelected: selectedItem == item,
                    onSelect: onSelectItem,
                    onMove: onMoveItem
                ) {
                    previewItem(item, isCompact: isCompact)
                }
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 10, y: 4)

            revealHandle
                .allowsHitTesting(onSelectItem == nil)
        }
    }

    private var visibleItems: [GamepadControlBarItem] {
        items.filter { !customization.controlBarItemCustomization(for: $0).isHidden }
    }

    @ViewBuilder
    private func previewItem(_ item: GamepadControlBarItem, isCompact: Bool) -> some View {
        switch item {
        case .connectionStatus:
            GamepadControlBarStatusPill(
                customization: customization,
                title: context.isConnected ? "Connected" : "Saved Keypad",
                systemImage: context.isConnected ? "wifi" : "rectangle.grid.2x2",
                tone: context.isConnected ? .success : .neutral
            )
        case .profileMenu:
            if context.hasProfiles {
                if isCompact {
                    compactProfileButton
                } else {
                    profileButton
                }
            }
        case .launchTarget:
            if let launchTarget = context.launchTarget {
                launchTargetButton(launchTarget, isCompact: isCompact)
            }
        case .spacer:
            Spacer(minLength: (isCompact ? 2 : Geist.Spacing.s2) * customization.controlBarItemCustomization(for: .spacer).widthScale)
        case .editLayout:
            iconButton(item: .editLayout, systemImage: "lock.fill")
        case .settings:
            iconButton(item: .settings, systemImage: "gearshape.fill")
        case .home:
            iconButton(item: .home, systemImage: "house.fill")
        case .connectionAction:
            connectionButton(isCompact: isCompact)
        }
    }

    private var profileButton: some View {
        Button(action: {}) {
            HStack(spacing: Geist.Spacing.s1) {
                GamepadControlBarItemIcon(
                    customization: customization,
                    item: .profileMenu,
                    defaultSystemImage: context.isSelectedProfileDefault ? "star.fill" : "rectangle.grid.2x2",
                    fontSize: 11
                )
                Text(context.profileName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: 160)
        }
        .gamepadControlBarButtonStyle(customization: customization, item: .profileMenu)
    }

    private var compactProfileButton: some View {
        Button(action: {}) {
            GamepadControlBarItemIcon(
                customization: customization,
                item: .profileMenu,
                defaultSystemImage: context.isSelectedProfileDefault ? "star.fill" : "rectangle.grid.2x2",
                fontSize: 13,
                frameWidth: 28
            )
        }
        .gamepadControlBarButtonStyle(customization: customization, item: .profileMenu)
    }

    private func launchTargetButton(_ launchTarget: GamepadProfileLaunchTarget, isCompact: Bool) -> some View {
        Button(action: {}) {
            if customization.controlBarItemCustomization(for: .launchTarget).icon != nil {
                GamepadControlBarItemIcon(
                    customization: customization,
                    item: .launchTarget,
                    defaultSystemImage: "app.badge.fill",
                    fontSize: isCompact ? 18 : 20,
                    frameWidth: 28
                )
            } else {
                launchTargetIcon(launchTarget, size: isCompact ? 18 : 20)
                    .frame(width: 28, height: 28)
            }
        }
        .gamepadControlBarButtonStyle(customization: customization, item: .launchTarget)
        .disabled(!context.isConnected)
    }

    @ViewBuilder
    private func launchTargetIcon(_ launchTarget: GamepadProfileLaunchTarget, size: CGFloat) -> some View {
#if os(macOS)
        if let data = launchTarget.iconPNGData, let image = GamepadImageDecodeCache.image(for: data) {
            Image(nsImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous))
        } else {
            fallbackLaunchTargetIcon(size: size)
        }
#elseif os(iOS)
        if let data = launchTarget.iconPNGData, let image = GamepadImageDecodeCache.image(for: data) {
            Image(uiImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous))
        } else {
            fallbackLaunchTargetIcon(size: size)
        }
#endif
    }

    private func fallbackLaunchTargetIcon(size: CGFloat) -> some View {
        Image(systemName: "app.badge.fill")
            .font(.system(size: size, weight: .semibold))
            .frame(width: size, height: size)
    }

    private func iconButton(item: GamepadControlBarItem, systemImage: String) -> some View {
        Button(action: {}) {
            GamepadControlBarItemIcon(
                customization: customization,
                item: item,
                defaultSystemImage: systemImage,
                fontSize: 13,
                frameWidth: 28
            )
        }
        .gamepadControlBarButtonStyle(customization: customization, item: item)
    }

    @ViewBuilder
    private func connectionButton(isCompact: Bool) -> some View {
        if context.isConnected {
            Button(action: {}) {
                if isCompact {
                    GamepadControlBarItemIcon(
                        customization: customization,
                        item: .connectionAction,
                        defaultSystemImage: "wifi.slash",
                        fontSize: 13,
                        frameWidth: 28
                    )
                } else if customization.controlBarItemCustomization(for: .connectionAction).icon != nil {
                    HStack(spacing: Geist.Spacing.s1) {
                        GamepadControlBarItemIcon(
                            customization: customization,
                            item: .connectionAction,
                            defaultSystemImage: "wifi.slash",
                            fontSize: 13
                        )
                        Text("Disconnect")
                    }
                } else {
                    Text("Disconnect")
                }
            }
            .gamepadControlBarButtonStyle(customization: customization, item: .connectionAction, variant: .error)
        } else {
            Button(action: {}) {
                if isCompact {
                    GamepadControlBarItemIcon(
                        customization: customization,
                        item: .connectionAction,
                        defaultSystemImage: "link",
                        fontSize: 13,
                        frameWidth: 28
                    )
                } else if customization.controlBarItemCustomization(for: .connectionAction).icon != nil {
                    HStack(spacing: Geist.Spacing.s1) {
                        GamepadControlBarItemIcon(
                            customization: customization,
                            item: .connectionAction,
                            defaultSystemImage: "link",
                            fontSize: 13
                        )
                        Text("Connect Mac")
                    }
                } else {
                    Text("Connect Mac")
                }
            }
            .gamepadControlBarButtonStyle(customization: customization, item: .connectionAction)
        }
    }

    private var revealHandle: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Geist.color(.grayAlpha700, scheme: colorScheme))
                .frame(width: 36, height: 5)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .background(
            Capsule()
                .fill(Geist.color(.background100, scheme: colorScheme).opacity(0.74))
        )
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

private struct GamepadEditorProfileUndoSnapshot: Equatable {
    var profiles: [GamepadConfigurationProfile]
    var selectedProfileID: UUID
    var selectedProfileIDs: Set<UUID>
    var defaultProfileID: UUID
    var selectedProfileOrientation: GamepadEditorDeviceOrientation
    var isSelectedProfileExpanded: Bool
    var selectedProfileNameDraft: String
    var editorSnapshot: GamepadEditorUndoSnapshot
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

private struct GamepadEditorLayerGroupItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let children: [GamepadEditorComponentItem]
    let isHidden: Bool
    let isLocationLocked: Bool

    var childIdentities: [GamepadControlIdentity] {
        children.map(\.identity)
    }

    var childIdentitySet: Set<GamepadControlIdentity> {
        Set(childIdentities)
    }
}

private enum GamepadEditorLayerListItem: Identifiable, Hashable {
    case group(GamepadEditorLayerGroupItem)
    case component(GamepadEditorComponentItem)

    var id: String {
        switch self {
        case .group(let group): "group.\(group.id.uuidString)"
        case .component(let component): "component.\(component.identity.id)"
        }
    }
}

private struct GamepadEditorLayerModel {
    let controlSelectionOptions: [GamepadControlIdentity]
    let componentItems: [GamepadEditorComponentItem]
    let normalizedLayerGroups: [GamepadLayerGroup]
    let layerGroupItems: [GamepadEditorLayerGroupItem]
    let layerListItems: [GamepadEditorLayerListItem]

    var layerSelectionControlIdentities: [GamepadControlIdentity] {
        componentItems.map(\.identity)
    }

    init(
        customization: GamepadCustomization,
        defaultLabelProvider: ((GameButton) -> String?)? = nil
    ) {
        let builtInControls = GameButton.builtInControls
        var builtInLayouts: [GameButton: GamepadButtonCustomization] = [:]
        builtInLayouts.reserveCapacity(builtInControls.count)
        for button in builtInControls {
            builtInLayouts[button] = customization.buttonCustomization(for: button)
        }

        let normalizedCustomButtons = customization.customButtons.map(\.normalized)
        let systemControls = GamepadSystemControl.allCases
        let allControlIdentities = systemControls.map { GamepadControlIdentity.system($0) }
            + builtInControls.map { GamepadControlIdentity.builtin($0) }
            + normalizedCustomButtons.map { GamepadControlIdentity.custom($0.id) }
        let normalizedMetadata = customization.designMetadata?.normalized(availableControls: allControlIdentities)
        let orderedControlIdentities = normalizedMetadata?.layerOrder ?? allControlIdentities

        var zIndexLookup: [GamepadControlIdentity: Int] = [:]
        zIndexLookup.reserveCapacity(allControlIdentities.count)
        for control in systemControls {
            switch control {
            case .topBarActivation:
                zIndexLookup[.system(control)] = customization.topBarActivationRegion.normalized.zIndex
            }
        }
        for button in builtInControls {
            zIndexLookup[.builtin(button)] = builtInLayouts[button]?.zIndex ?? 0
        }
        for customButton in normalizedCustomButtons {
            zIndexLookup[.custom(customButton.id)] = customButton.layout.zIndex
        }

        let orderLookup = Dictionary(uniqueKeysWithValues: orderedControlIdentities.enumerated().map { ($0.element, $0.offset) })
        let zOrderedControlIdentities = orderedControlIdentities.sorted { lhs, rhs in
            let lhsZIndex = zIndexLookup[lhs] ?? 0
            let rhsZIndex = zIndexLookup[rhs] ?? 0
            if lhsZIndex == rhsZIndex {
                let lhsIndex = orderLookup[lhs] ?? Int.max
                let rhsIndex = orderLookup[rhs] ?? Int.max
                if lhsIndex == rhsIndex { return lhs.id < rhs.id }
                return lhsIndex < rhsIndex
            }
            return lhsZIndex < rhsZIndex
        }
        let shouldListBuiltInComponents = builtInControls.contains { builtInLayouts[$0]?.isHidden == false }
        self.controlSelectionOptions = systemControls.map { .system($0) }
            + customization.normalized.controlBarItems.map { .controlBarItem($0) }
            + (shouldListBuiltInComponents ? builtInControls.map { .builtin($0) } : [])
            + normalizedCustomButtons.map { .custom($0.id) }

        let visualLabelForButton: (GameButton) -> String = { button in
            let providedLabel = defaultLabelProvider?(button).map(normalizedGamepadLabel) ?? ""
            let defaultLabel = providedLabel.isEmpty ? GamepadCustomization.defaultVisualLabel(for: button) : providedLabel
            return customization.visualLabel(for: button, defaultLabel: defaultLabel)
        }

        let systemItems = systemControls.map { control -> GamepadEditorComponentItem in
            let layout: GamepadButtonCustomization = switch control {
            case .topBarActivation: customization.topBarActivationRegion.normalized
            }
            return GamepadEditorComponentItem(
                identity: .system(control),
                title: control.displayName,
                subtitle: control.subtitle,
                systemImage: control.systemImage,
                isHidden: layout.isHidden,
                isLocationLocked: layout.isLocationLocked
            )
        }

        let controlBarItems = customization.normalized.controlBarItems.map { item in
            let appearance = customization.controlBarItemCustomization(for: item)
            return GamepadEditorComponentItem(
                identity: .controlBarItem(item),
                title: item.displayName,
                subtitle: "Control Bar Item",
                systemImage: item.systemImage,
                isHidden: appearance.isHidden,
                isLocationLocked: true
            )
        }

        let builtInItems: [GamepadEditorComponentItem]
        if shouldListBuiltInComponents {
            builtInItems = builtInControls.map { button in
                let layout = builtInLayouts[button] ?? .defaultValue
                return GamepadEditorComponentItem(
                    identity: .builtin(button),
                    title: visualLabelForButton(button),
                    subtitle: "Button",
                    systemImage: "diamond.fill",
                    isHidden: layout.isHidden,
                    isLocationLocked: layout.isLocationLocked
                )
            }
        } else {
            builtInItems = []
        }

        let customItems = normalizedCustomButtons.map { customButton -> GamepadEditorComponentItem in
            let title = customButton.visualLabel(fallback: Self.fallbackLabel(for: customButton))
            let subtitle: String
            let systemImage: String
            if customButton.isJoystick {
                let analogTarget = (customButton.joystickOutputSettings ?? .defaultValue).normalized.analogTarget
                subtitle = analogTarget == .none ? "Joystick → 4 directions" : "Joystick → \(analogTarget.displayName)"
                systemImage = "circle.grid.cross"
            } else if customButton.isDecoration {
                subtitle = "Decoration layer"
                systemImage = "square.3.layers.3d.down.right"
            } else if customButton.isTrigger {
                let target = (customButton.triggerSettings ?? .defaultValue).normalized.target
                subtitle = "Trigger → \(target.displayName)"
                systemImage = "slider.horizontal.3"
            } else if customButton.isTrackpad {
                subtitle = "Trackpad → cursor, click, scroll"
                systemImage = "rectangle.and.hand.point.up.left"
            } else {
                subtitle = "Button"
                systemImage = "plus.square.fill"
            }
            return GamepadEditorComponentItem(
                identity: .custom(customButton.id),
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                isHidden: customButton.layout.isHidden,
                isLocationLocked: customButton.layout.isLocationLocked
            )
        }

        let zOrderLookup = Dictionary(uniqueKeysWithValues: zOrderedControlIdentities.enumerated().map { ($0.element, $0.offset) })
        let componentItems = (systemItems + controlBarItems + builtInItems + customItems).sorted { lhs, rhs in
            let lhsIndex = zOrderLookup[lhs.identity] ?? Int.max
            let rhsIndex = zOrderLookup[rhs.identity] ?? Int.max
            if lhsIndex == rhsIndex { return lhs.title < rhs.title }
            return lhsIndex < rhsIndex
        }

        var componentItemByIdentity: [GamepadControlIdentity: GamepadEditorComponentItem] = [:]
        componentItemByIdentity.reserveCapacity(componentItems.count)
        for item in componentItems {
            componentItemByIdentity[item.identity] = item
        }

        let normalizedLayerGroups = normalizedMetadata?.groups ?? []
        let layerGroupItems = Self.makeLayerGroupItems(
            groups: normalizedLayerGroups,
            componentItemByIdentity: componentItemByIdentity,
            orderLookup: zOrderLookup
        )
        let layerListItems = Self.makeLayerListItems(
            groups: layerGroupItems,
            componentItems: componentItems,
            componentItemByIdentity: componentItemByIdentity,
            zOrderedControlIdentities: zOrderedControlIdentities
        )

        self.componentItems = componentItems
        self.normalizedLayerGroups = normalizedLayerGroups
        self.layerGroupItems = layerGroupItems
        self.layerListItems = layerListItems
    }

    private static func fallbackLabel(for customButton: GamepadCustomButton) -> String {
        if customButton.isJoystick { return "Joystick" }
        if customButton.isTrigger { return (customButton.triggerSettings ?? .defaultValue).normalized.target.shortName }
        if customButton.isTrackpad { return "Trackpad" }
        if customButton.isDecoration { return "Decoration" }
        return "Button"
    }

    private static func makeLayerGroupItems(
        groups: [GamepadLayerGroup],
        componentItemByIdentity: [GamepadControlIdentity: GamepadEditorComponentItem],
        orderLookup: [GamepadControlIdentity: Int]
    ) -> [GamepadEditorLayerGroupItem] {
        var groupedIdentities = Set<GamepadControlIdentity>()
        let groupItems = groups.compactMap { group -> GamepadEditorLayerGroupItem? in
            let children = group.children.compactMap { identity -> GamepadEditorComponentItem? in
                guard !groupedIdentities.contains(identity), let item = componentItemByIdentity[identity] else { return nil }
                groupedIdentities.insert(identity)
                return item
            }
            guard !children.isEmpty else { return nil }
            return GamepadEditorLayerGroupItem(
                id: group.id,
                name: group.name,
                children: children.sorted { lhs, rhs in
                    let lhsIndex = orderLookup[lhs.identity] ?? Int.max
                    let rhsIndex = orderLookup[rhs.identity] ?? Int.max
                    if lhsIndex == rhsIndex { return lhs.title < rhs.title }
                    return lhsIndex < rhsIndex
                },
                isHidden: group.isHidden || children.allSatisfy(\.isHidden),
                isLocationLocked: group.isLocked || children.allSatisfy(\.isLocationLocked)
            )
        }

        return groupItems.sorted { lhs, rhs in
            let lhsIndex = lhs.childIdentities.compactMap { orderLookup[$0] }.min() ?? Int.max
            let rhsIndex = rhs.childIdentities.compactMap { orderLookup[$0] }.min() ?? Int.max
            if lhsIndex == rhsIndex { return lhs.name < rhs.name }
            return lhsIndex < rhsIndex
        }
    }

    private static func makeLayerListItems(
        groups: [GamepadEditorLayerGroupItem],
        componentItems: [GamepadEditorComponentItem],
        componentItemByIdentity: [GamepadControlIdentity: GamepadEditorComponentItem],
        zOrderedControlIdentities: [GamepadControlIdentity]
    ) -> [GamepadEditorLayerListItem] {
        var groupByChild: [GamepadControlIdentity: GamepadEditorLayerGroupItem] = [:]
        for group in groups {
            for identity in group.childIdentities {
                groupByChild[identity] = group
            }
        }

        var emittedGroups = Set<UUID>()
        var emittedComponents = Set<GamepadControlIdentity>()
        var listItems: [GamepadEditorLayerListItem] = []
        listItems.reserveCapacity(componentItems.count)

        for identity in zOrderedControlIdentities {
            if let group = groupByChild[identity] {
                if emittedGroups.insert(group.id).inserted {
                    listItems.append(.group(group))
                    emittedComponents.formUnion(group.childIdentitySet)
                }
            } else if let item = componentItemByIdentity[identity], emittedComponents.insert(identity).inserted {
                listItems.append(.component(item))
            }
        }

        for group in groups where !emittedGroups.contains(group.id) {
            listItems.append(.group(group))
            emittedGroups.insert(group.id)
            emittedComponents.formUnion(group.childIdentitySet)
        }

        for item in componentItems where !emittedComponents.contains(item.identity) {
            listItems.append(.component(item))
            emittedComponents.insert(item.identity)
        }

        return listItems
    }
}

private enum GamepadFrameMetric {
    case x
    case y
    case width
    case height
}

private enum GamepadEditorAlignmentAxis: Equatable {
    case horizontalCenter
    case verticalCenter
}

private enum GamepadEditorDistributionAxis: Equatable {
    case horizontal
    case vertical
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

private enum GamepadDecorationTemplateKind {
    case plate
    case ring
}

private enum GamepadEditorColorScheme: String, CaseIterable, Hashable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    func resolvedColorScheme(system systemScheme: ColorScheme) -> ColorScheme {
        switch self {
        case .system: systemScheme
        case .light: .light
        case .dark: .dark
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }
}

private enum GamepadFillPopoverTab: String, CaseIterable, Identifiable {
    case solid
    case gradient
    case tile
    case image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: "Solid"
        case .gradient: "Gradient"
        case .tile: "Tile"
        case .image: "Image"
        }
    }

    var systemImage: String {
        switch self {
        case .solid: "square.on.square"
        case .gradient: "circle.grid.2x2"
        case .tile: "tablecells"
        case .image: "photo"
        }
    }
}

private enum GamepadFillEditorTarget: Hashable {
    case element(GamepadControlIdentity)
    case background

    var defaultResetNoun: String {
        switch self {
        case .element: "Color"
        case .background: "Background"
        }
    }

    var showsElementColorPresets: Bool {
        if case .element = self { return true }
        return false
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
                    guard selection != option else { return }
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection = option
                    }
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

private struct GamepadEditorDeviceFrameView: View {
    @Environment(\.colorScheme) private var colorScheme
    let deviceFrame: GamepadEditorDeviceFrame
    let displayScale: CGFloat

    var body: some View {
        let outerRect = CGRect(origin: .zero, size: scaled(deviceFrame.imageSize))
        let screenRect = scaled(deviceFrame.screenRect)
        let bodyRadius = deviceFrame.bodyCornerRadius * displayScale
        let screenRadius = deviceFrame.screenCornerRadius * displayScale

        ZStack(alignment: .topLeading) {
            if hasExternalChrome(outerRect: outerRect, screenRect: screenRect) {
                frameMask(outerRect: outerRect, screenRect: screenRect, bodyRadius: bodyRadius, screenRadius: screenRadius)
                    .fill(deviceBodyColor, style: FillStyle(eoFill: true, antialiased: true))

                RoundedRectangle(cornerRadius: bodyRadius, style: .continuous)
                    .strokeBorder(deviceOuterStrokeColor, lineWidth: max(1, 1.2 * displayScale))
                    .frame(width: outerRect.width, height: outerRect.height)
            }

            RoundedRectangle(cornerRadius: screenRadius, style: .continuous)
                .strokeBorder(deviceInnerStrokeColor, lineWidth: max(1, 0.8 * displayScale))
                .frame(width: screenRect.width, height: screenRect.height)
                .offset(x: screenRect.minX, y: screenRect.minY)

            sensorOrHomeIndicator(screenRect: screenRect)
        }
        .frame(width: outerRect.width, height: outerRect.height)
        .drawingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var deviceBodyColor: Color {
        colorScheme == .dark ? Color(red: 0.018, green: 0.019, blue: 0.022) : Color(red: 0.055, green: 0.058, blue: 0.064)
    }

    private var deviceOuterStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.22)
    }

    private var deviceInnerStrokeColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.18)
    }

    private func scaled(_ size: CGSize) -> CGSize {
        CGSize(width: size.width * displayScale, height: size.height * displayScale)
    }

    private func scaled(_ rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX * displayScale,
            y: rect.minY * displayScale,
            width: rect.width * displayScale,
            height: rect.height * displayScale
        )
    }

    private func frameMask(outerRect: CGRect, screenRect: CGRect, bodyRadius: CGFloat, screenRadius: CGFloat) -> Path {
        var path = Path()
        path.addRoundedRect(in: outerRect, cornerSize: CGSize(width: bodyRadius, height: bodyRadius), style: .continuous)
        path.addRoundedRect(in: screenRect, cornerSize: CGSize(width: screenRadius, height: screenRadius), style: .continuous)
        return path
    }

    private func hasExternalChrome(outerRect: CGRect, screenRect: CGRect) -> Bool {
        abs(screenRect.minX - outerRect.minX) > 0.5
            || abs(screenRect.minY - outerRect.minY) > 0.5
            || abs(screenRect.maxX - outerRect.maxX) > 0.5
            || abs(screenRect.maxY - outerRect.maxY) > 0.5
    }

    @ViewBuilder
    private func sensorOrHomeIndicator(screenRect: CGRect) -> some View {
        switch deviceFrame.frameStyle {
        case .dynamicIsland:
            RoundedRectangle(cornerRadius: dynamicIslandCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .frame(width: dynamicIslandSize.width, height: dynamicIslandSize.height)
                .offset(x: dynamicIslandOrigin(in: screenRect).x, y: dynamicIslandOrigin(in: screenRect).y)
        case .notch:
            RoundedRectangle(cornerRadius: notchCornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.92))
                .frame(width: notchSize.width, height: notchSize.height)
                .offset(x: notchOrigin(in: screenRect).x, y: notchOrigin(in: screenRect).y)
        case .homeButton:
            EmptyView()
        }
    }

    private var dynamicIslandSize: CGSize {
        if deviceFrame.isLandscape {
            CGSize(width: max(18, 30 * displayScale), height: max(58, 112 * displayScale))
        } else {
            CGSize(width: max(58, 112 * displayScale), height: max(18, 30 * displayScale))
        }
    }

    private var dynamicIslandCornerRadius: CGFloat {
        min(dynamicIslandSize.width, dynamicIslandSize.height) / 2
    }

    private func dynamicIslandOrigin(in screenRect: CGRect) -> CGPoint {
        if deviceFrame.isLandscape {
            return CGPoint(x: screenRect.minX + 12 * displayScale, y: screenRect.midY - dynamicIslandSize.height / 2)
        }
        return CGPoint(x: screenRect.midX - dynamicIslandSize.width / 2, y: screenRect.minY + 12 * displayScale)
    }

    private var notchSize: CGSize {
        if deviceFrame.isLandscape {
            CGSize(width: max(24, 34 * displayScale), height: max(86, 154 * displayScale))
        } else {
            CGSize(width: max(86, 154 * displayScale), height: max(24, 34 * displayScale))
        }
    }

    private var notchCornerRadius: CGFloat {
        min(notchSize.width, notchSize.height) * 0.45
    }

    private func notchOrigin(in screenRect: CGRect) -> CGPoint {
        if deviceFrame.isLandscape {
            return CGPoint(x: screenRect.minX, y: screenRect.midY - notchSize.height / 2)
        }
        return CGPoint(x: screenRect.midX - notchSize.width / 2, y: screenRect.minY)
    }
}

private enum GamepadInspectorAccordionSection: Hashable {
    case output
    case selectedElementIdentity
    case selectedElementControlBar
    case selectedElementArrangement
    case selectedElementStyle
    case selectedElementHaptic
    case selectedElementFill
    case selectedElementPosition
    case selectedElementLayout
    case selectedElementCorners
    case selectedElementEffects
    case keypadIdentity
    case keypadApplication
    case keypadDevice
    case keypadAppearance
    case keypadBackground
    case keypadEditor
    case keypadComponents
}

private enum GamepadEditorOnboardingTarget: Hashable {
    case setups
    case canvas
    case toolbar
    case inspector
}

private enum GamepadEditorFirstKeypadStep: Int, CaseIterable, Identifiable, Equatable {
    case setups
    case canvas
    case toolbar
    case inspector

    var id: Int { rawValue }

    var target: GamepadEditorOnboardingTarget {
        switch self {
        case .setups: .setups
        case .canvas: .canvas
        case .toolbar: .toolbar
        case .inspector: .inspector
        }
    }

    var eyebrow: String {
        "Step \(rawValue + 1) of \(Self.allCases.count)"
    }

    var title: String {
        switch self {
        case .setups:
            "Start with one blank setup"
        case .canvas:
            "Build the keypad on the canvas"
        case .toolbar:
            "Add controls from the toolbar"
        case .inspector:
            "Tune shortcuts in the inspector"
        }
    }

    var message: String {
        switch self {
        case .setups:
            "PocketPad no longer preloads every controller template. Your first setup starts empty so you can name it, duplicate it, or add templates only when you need them."
        case .canvas:
            "This iPhone canvas is where your controls will live. Use the starter card to show default controls, add a joystick, or switch into draw mode for a custom button."
        case .toolbar:
            "The floating toolbar is the fastest path: choose Layout tools for default controls, joysticks, triggers, or trackpads; choose Shape tools to draw your own keys."
        case .inspector:
            "Select any control to edit its label, shortcut output, fill, size, haptics, and positioning. Keypad-level settings live here while nothing is selected."
        }
    }

    var nextTitle: String {
        next == nil ? "Finish" : "Next"
    }

    var next: GamepadEditorFirstKeypadStep? {
        switch self {
        case .setups:
            .canvas
        case .canvas:
            .toolbar
        case .toolbar:
            .inspector
        case .inspector:
            nil
        }
    }
}

private struct GamepadEditorOnboardingTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [GamepadEditorOnboardingTarget: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [GamepadEditorOnboardingTarget: Anchor<CGRect>],
        nextValue: () -> [GamepadEditorOnboardingTarget: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, new in new }
    }
}

private extension View {
    func gamepadEditorOnboardingTarget(_ target: GamepadEditorOnboardingTarget) -> some View {
        anchorPreference(key: GamepadEditorOnboardingTargetPreferenceKey.self, value: .bounds) { anchor in
            [target: anchor]
        }
    }
}

struct GamepadCustomizationEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.undoManager) private var undoManager
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Binding private var externalCustomization: GamepadCustomization
    @State private var customization: GamepadCustomization
    @State private var editorLayerModel: GamepadEditorLayerModel

    private let showsPreview: Bool
    private let externalProfiles: [GamepadConfigurationProfile]?
    private let externalSelectedProfileID: UUID?
    private let externalDefaultProfileID: UUID?
    private let onReset: (() -> Void)?
    private let onProfilesChanged: (([GamepadConfigurationProfile], UUID, UUID) -> Void)?
    private let onRegisterProfileUndoSnapshot: ((String) -> Void)?
    private let onLaunchProfileTarget: ((UUID) -> Void)?
    private let defaultLabelProvider: ((GameButton) -> String?)?
    private let profileOutputModeContent: (() -> AnyView)?
    private let selectedElementOutputContent: ((KeypadElementInputID) -> AnyView)?
    private let connectedDeviceInfo: ControllerClientDeviceInfo?

    private static let configurationSidebarMinWidth: CGFloat = 180
    private static let configurationSidebarMaxWidth: CGFloat = 360
    private static let inspectorSidebarMinWidth: CGFloat = 280
    private static let inspectorSidebarMaxWidth: CGFloat = 520
    private static let minimumCanvasColumnWidth: CGFloat = 320
    private static let resizeHandleWidth: CGFloat = 10
    // Keep editor coordinates stable; viewport/sidebar changes scale the preview instead of re-laying out keys.
    // The canvas uses a selected iPhone display opening in points so Mac edits match the physical device.
    private static let defaultDeviceFrame: GamepadEditorDeviceFrame = GamepadEditorDeviceCatalog.defaultFrame
    private static let canvasZoomMin: CGFloat = 0.5
    private static let canvasZoomMax: CGFloat = 2.25
    private static let deviceFrameSpringAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86, blendDuration: 0.08)
    private static let deviceFrameMotionSettleDelay: TimeInterval = 0.12
    private static let externalCommitDebounceDelay: TimeInterval = 0.20
    private static let profileDragUTType = UTType(exportedAs: "com.codybontecou.pocketpad.profile-selection")

    @State private var selectedControlID: GamepadControlIdentity
    @State private var selectedControlIDs: Set<GamepadControlIdentity>
    @State private var isControlSelectionActive: Bool
    @State private var profiles: [GamepadConfigurationProfile]
    @State private var selectedProfileID: UUID
    // Explicit command-click setup selection. When empty, profile actions target selectedProfileID.
    @State private var selectedProfileIDs: Set<UUID>
    @State private var draggingProfileIDs: [UUID]
    @State private var defaultProfileID: UUID
    @State private var selectedProfileOrientation: GamepadEditorDeviceOrientation
    @State private var isSelectedProfileExpanded: Bool
    @State private var selectedProfileNameDraft: String
    @State private var expandedLayerGroupIDs: Set<UUID>
    @State private var layerSelectionAnchorID: GamepadControlIdentity?
    @State private var configurationSidebarDragStart: CGFloat?
    @State private var inspectorSidebarDragStart: CGFloat?
    @State private var canvasZoomGestureStart: CGFloat?
    @State private var expandedInspectorSections: Set<GamepadInspectorAccordionSection> = []
    @State private var currentCanvasLayoutSize = GamepadCustomizationEditor.defaultDeviceFrame.screenRect.size
    @State private var deviceFrameMotionRotationDegrees: Double = 0
    @State private var deviceFrameMotionOffset: CGSize = .zero
    @State private var activeCanvasTool: GamepadCanvasTool = .select
    @State private var isFillColorPopoverPresented = false
    @State private var isJoystickKnobColorPopoverPresented = false
    @State private var isBackgroundColorPopoverPresented = false
    @State private var activeFillPopoverTab: GamepadFillPopoverTab = .solid
    @State private var isFillImageImporterPresented = false
    @State private var fillImageImportError: String?
    @State private var fillColorPickerHue: CGFloat = 0
    @State private var copiedElementStyle: GamepadButtonCustomization?
    @State private var attachedApplicationStatus: String?
    @State private var pendingExternalCommitWorkItem: DispatchWorkItem?
    @State private var hasPendingExternalEditorCommit = false
    @State private var draftConfigurationSidebarWidth: CGFloat?
    @State private var draftInspectorSidebarWidth: CGFloat?
    @State private var draftCanvasZoom: CGFloat?
    @State private var undoTarget = GamepadEditorUndoTarget()
    @State private var activeFirstKeypadOnboardingStep: GamepadEditorFirstKeypadStep?
    @FocusState private var isProfileNameFieldFocused: Bool
    @AppStorage(PocketPadMacIPC.editorFirstKeypadOnboardingCompletedDefaultsKey) private var hasCompletedFirstKeypadOnboarding = false
    @AppStorage(PocketPadMacIPC.editorFirstKeypadOnboardingReplayRequestedDefaultsKey) private var isFirstKeypadOnboardingReplayRequested = false
    @AppStorage("PocketPad.GamepadEditor.configurationSidebarWidth") private var configurationSidebarWidthValue: Double = 236
    @AppStorage("PocketPad.GamepadEditor.inspectorSidebarWidth") private var inspectorSidebarWidthValue: Double = 340
    @AppStorage("PocketPad.GamepadEditor.configurationSidebarVisible") private var isConfigurationSidebarVisible = true
    @AppStorage("PocketPad.GamepadEditor.inspectorSidebarVisible") private var isInspectorSidebarVisible = true
    @AppStorage("PocketPad.GamepadEditor.canvasZoom") private var canvasZoomValue: Double = 1.0
    @AppStorage(GamepadEditorDeviceCatalog.selectedFrameDefaultsKey) private var deviceFrameRawValue: String = GamepadEditorDeviceCatalog.defaultFrameID
    @AppStorage(GamepadEditorDeviceCatalog.didChooseFrameDefaultsKey) private var didChooseDeviceFrameManually = false
    @AppStorage("PocketPad.GamepadEditor.editingColorScheme") private var editingColorSchemeRawValue: String = GamepadEditorColorScheme.system.rawValue

    init(
        customization: Binding<GamepadCustomization>,
        showsPreview: Bool = true,
        initialProfiles: [GamepadConfigurationProfile]? = nil,
        initialSelectedProfileID: UUID? = nil,
        initialDefaultProfileID: UUID? = nil,
        onReset: (() -> Void)? = nil,
        onProfilesChanged: (([GamepadConfigurationProfile], UUID, UUID) -> Void)? = nil,
        onRegisterProfileUndoSnapshot: ((String) -> Void)? = nil,
        onLaunchProfileTarget: ((UUID) -> Void)? = nil,
        defaultLabelProvider: ((GameButton) -> String?)? = nil,
        profileOutputModeContent: (() -> AnyView)? = nil,
        selectedElementOutputContent: ((KeypadElementInputID) -> AnyView)? = nil,
        connectedDeviceInfo: ControllerClientDeviceInfo? = nil
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

        let initialCustomization = customization.wrappedValue.normalized

        self._externalCustomization = customization
        self._customization = State(initialValue: initialCustomization)
        self._editorLayerModel = State(initialValue: GamepadEditorLayerModel(customization: initialCustomization, defaultLabelProvider: defaultLabelProvider))
        self.showsPreview = showsPreview
        self.externalProfiles = initialProfiles
        self.externalSelectedProfileID = initialSelectedProfileID
        self.externalDefaultProfileID = initialDefaultProfileID
        self.onReset = onReset
        self.onProfilesChanged = onProfilesChanged
        self.onRegisterProfileUndoSnapshot = onRegisterProfileUndoSnapshot
        self.onLaunchProfileTarget = onLaunchProfileTarget
        self.defaultLabelProvider = defaultLabelProvider
        self.profileOutputModeContent = profileOutputModeContent
        self.selectedElementOutputContent = selectedElementOutputContent
        self.connectedDeviceInfo = connectedDeviceInfo
        self._selectedControlID = State(initialValue: .builtin(.jump))
        self._selectedControlIDs = State(initialValue: [])
        self._isControlSelectionActive = State(initialValue: false)
        self._profiles = State(initialValue: loadedProfiles.profiles)
        self._selectedProfileID = State(initialValue: loadedProfiles.activeProfileID)
        self._selectedProfileIDs = State(initialValue: [])
        self._draggingProfileIDs = State(initialValue: [])
        self._defaultProfileID = State(initialValue: loadedProfiles.defaultProfileID)
        self._selectedProfileOrientation = State(initialValue: loadedProfiles.activeProfile?.customization.deviceCanvas.editorDeviceFrame.orientation ?? .landscape)
        self._isSelectedProfileExpanded = State(initialValue: true)
        self._selectedProfileNameDraft = State(initialValue: loadedProfiles.activeProfile?.name ?? "Current Setup")
        self._expandedLayerGroupIDs = State(initialValue: [])
        self._layerSelectionAnchorID = State(initialValue: nil)
    }

    private var activeDeviceFrame: GamepadEditorDeviceFrame {
        customization.deviceCanvas.editorDeviceFrame
    }

    private var activeDesignCanvasSize: CGSize {
        activeDeviceFrame.screenRect.size
    }

    private var connectedDeviceFrame: GamepadEditorDeviceFrame? {
        guard let connectedDeviceInfo else { return nil }
        return GamepadEditorDeviceCatalog.suggestedFrame(
            for: connectedDeviceInfo,
            preferredOrientation: activeDeviceFrame.orientation
        )
    }

    private var editorColorScheme: GamepadEditorColorScheme {
        GamepadEditorColorScheme(rawValue: editingColorSchemeRawValue) ?? .system
    }

    private var activeKeypadColorScheme: ColorScheme {
        switch editorColorScheme {
        case .system:
            return customization.resolvedColorScheme(system: connectedDeviceSystemColorScheme ?? colorScheme)
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private var connectedDeviceSystemColorScheme: ColorScheme? {
        switch connectedDeviceInfo?.interfaceStyle?.lowercased() {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var controlBarPreviewContext: GamepadControlBarPreviewContext {
        let trimmedProfileName = selectedProfileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        return GamepadControlBarPreviewContext(
            profileName: trimmedProfileName.isEmpty ? (selectedProfile?.name ?? "Current Setup") : trimmedProfileName,
            hasProfiles: !profiles.isEmpty,
            isSelectedProfileDefault: selectedProfileID == defaultProfileID,
            launchTarget: selectedProfile?.launchTarget,
            isConnected: connectedDeviceInfo != nil
        )
    }

    private var editorColorSchemeBinding: Binding<GamepadEditorColorScheme> {
        Binding(
            get: { editorColorScheme },
            set: { editingColorSchemeRawValue = $0.rawValue }
        )
    }

    private func makeEditorLayerModel(for customization: GamepadCustomization) -> GamepadEditorLayerModel {
        GamepadEditorLayerModel(customization: customization, defaultLabelProvider: defaultLabelProvider)
    }

    private func setEditorCustomization(_ normalizedCustomization: GamepadCustomization) {
        customization = normalizedCustomization
        editorLayerModel = makeEditorLayerModel(for: normalizedCustomization)
    }

    private var deviceFrameAnimation: Animation? {
        accessibilityReduceMotion ? .easeInOut(duration: 0.16) : Self.deviceFrameSpringAnimation
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
        .overlayPreferenceValue(GamepadEditorOnboardingTargetPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                if let step = activeFirstKeypadOnboardingStep {
                    GamepadEditorFirstKeypadOverlay(
                        step: step,
                        targetRect: anchors[step.target].map { proxy[$0] },
                        containerSize: proxy.size,
                        onNext: advanceFirstKeypadOnboarding,
                        onSkip: completeFirstKeypadOnboarding
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .allowsHitTesting(activeFirstKeypadOnboardingStep != nil)
        }
        .animation(accessibilityReduceMotion ? .easeInOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.88), value: activeFirstKeypadOnboardingStep)
        .onChange(of: observedExternalProfiles) { _, _ in
            syncExternalProfileState()
        }
        .onChange(of: externalSelectedProfileID) { _, _ in
            syncExternalProfileState()
        }
        .onChange(of: externalDefaultProfileID) { _, _ in
            syncExternalProfileState()
        }
        .onChange(of: externalCustomization) { _, newValue in
            syncExternalCustomizationState(newValue)
        }
        .onAppear {
            applyConnectedDeviceFrameIfAvailable()
            applySelectedProfileCustomizationForCurrentOrientation()
            presentFirstKeypadOnboardingIfNeeded()
        }
        .onChange(of: isFirstKeypadOnboardingReplayRequested) { _, requested in
            if requested {
                hasCompletedFirstKeypadOnboarding = false
                presentFirstKeypadOnboardingIfNeeded()
            }
        }
        .onChange(of: customization.deviceCanvas) { _, _ in
            selectedProfileOrientation = activeDeviceFrame.orientation
            noteCanvasLayoutSize(width: activeDesignCanvasSize.width, height: activeDesignCanvasSize.height)
        }
        .onChange(of: connectedDeviceInfo) { _, _ in
            applyConnectedDeviceFrameIfAvailable()
        }
        .onChange(of: componentListItems.count) { _, newCount in
            if newCount > 0 {
                completeFirstKeypadOnboarding()
            } else {
                presentFirstKeypadOnboardingIfNeeded()
            }
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
                onGroup: performGroupShortcut,
                onNudge: nudgeSelectedControls
            )
            .frame(width: 0, height: 0)
        }
        .onDisappear {
            commitPendingEditorChanges()
        }
    }

    private var wideEditor: some View {
        GeometryReader { proxy in
            let sidebarWidths = effectiveSidebarWidths(totalWidth: proxy.size.width)

            HStack(spacing: 0) {
                if isConfigurationSidebarVisible {
                    configurationSidebar
                        .frame(width: sidebarWidths.configuration)

                    GamepadEditorResizeHandle(
                        accessibilityLabel: "Resize setups sidebar",
                        onDragChanged: { value in
                            resizeConfigurationSidebar(with: value, totalWidth: proxy.size.width)
                        },
                        onDragEnded: {
                            configurationSidebarDragStart = nil
                            commitConfigurationSidebarWidthDraft()
                        }
                    )
                }

                canvasStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isInspectorSidebarVisible {
                    GamepadEditorResizeHandle(
                        accessibilityLabel: "Resize inspector sidebar",
                        onDragChanged: { value in
                            resizeInspectorSidebar(with: value, totalWidth: proxy.size.width)
                        },
                        onDragEnded: {
                            inspectorSidebarDragStart = nil
                            commitInspectorSidebarWidthDraft()
                        }
                    )

                    inspectorSidebar
                        .frame(width: sidebarWidths.inspector)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Geist.color(.background100, scheme: colorScheme))
        }
    }

    private var compactEditor: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Geist.Spacing.s4) {
                if isConfigurationSidebarVisible {
                    configurationCompactSection
                }
                canvasStage
                    .frame(height: 430)
                if isInspectorSidebarVisible {
                    inspectorCompactSection
                }
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
                        Text("Create and organize keypad setups.")
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
                LazyVStack(spacing: Geist.Spacing.s2) {
                    ForEach(profiles) { profile in
                        profileRow(profile)
                    }
                }
                .padding(Geist.Spacing.s3)
                .onDrop(
                    of: [Self.profileDragUTType],
                    delegate: GamepadProfileDropDelegate(
                        targetProfileID: nil,
                        draggingProfileIDs: $draggingProfileIDs,
                        onMove: moveDraggedProfiles,
                        onDropEnded: finishProfileDrag
                    )
                )
            }
        }
        .background(Geist.color(.background200, scheme: colorScheme))
        .gamepadEditorOnboardingTarget(.setups)
    }

    private var configurationCompactSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Setups")
                        .geistTypography(.heading20)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("Create a setup, then add the controls you need.")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }

                Spacer()

                templateMenu(showsTitle: true)

                Button("New") { createProfile() }
                    .geistButtonStyle(.secondary, size: .small)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Geist.Spacing.s2) {
                    ForEach(profiles) { profile in
                        profileChip(profile)
                    }
                }
                .padding(.vertical, 1)
                .onDrop(
                    of: [Self.profileDragUTType],
                    delegate: GamepadProfileDropDelegate(
                        targetProfileID: nil,
                        draggingProfileIDs: $draggingProfileIDs,
                        onMove: moveDraggedProfiles,
                        onDropEnded: finishProfileDrag
                    )
                )
            }

            selectedSetupNameEditor
            activeSetupComponentsList

            configurationFooter
        }
        .geistPanel(padding: Geist.Spacing.s4, radius: Geist.Radius.md, raised: false)
        .gamepadEditorOnboardingTarget(.setups)
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
        let isActive = profile.id == selectedProfileID
        let isSelected = selectedProfileIDs.contains(profile.id)
        let isExpanded = isActive && isSelectedProfileExpanded

        VStack(alignment: .leading, spacing: isExpanded ? Geist.Spacing.s2 : 0) {
            HStack(spacing: 0) {
                Button {
                    toggleProfileRow(profile, isSelected: isActive)
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .frame(width: 12, height: 22)
                        .padding(.leading, Geist.Spacing.s3)
                        .padding(.trailing, Geist.Spacing.s2)
                        .padding(.vertical, Geist.Spacing.s3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(isExpanded ? "Collapse" : "Expand") \(profile.name) setup details"))
                .accessibilityHint(Text(profileDisclosureAccessibilityHint(isSelected: isActive, isExpanded: isExpanded)))
                .help(isExpanded ? "Hide setup details" : "Show setup details")

                Button {
                    handleProfileClick(profile, expandsDetails: false)
                } label: {
                    HStack(spacing: Geist.Spacing.s2) {
                        Text(profile.name)
                            .geistTypography(.heading14)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .lineLimit(1)

                        Spacer(minLength: Geist.Spacing.s1)

                        if profile.launchTarget != nil {
                            Image(systemName: "app.badge.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                                .help("Attached application")
                        }

                        if profile.id == defaultProfileID {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                                .help("Default")
                        }

                        if isActive {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                                .help("Active")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                    .padding(.vertical, Geist.Spacing.s3)
                    .padding(.trailing, Geist.Spacing.s3)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(profile.name) keypad setup"))
                .accessibilityHint(Text(profileRowAccessibilityHint(isSelected: isActive, isExpanded: isExpanded)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .fill(profileSelectionFill(isActive: isActive, isSelected: isSelected))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(profileSelectionStroke(isActive: isActive, isSelected: isSelected), lineWidth: isSelected ? 1.5 : 1)
            )

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
        .onDrag {
            profileDragItemProvider(for: profile)
        }
        .onDrop(
            of: [Self.profileDragUTType],
            delegate: GamepadProfileDropDelegate(
                targetProfileID: profile.id,
                draggingProfileIDs: $draggingProfileIDs,
                onMove: moveDraggedProfiles,
                onDropEnded: finishProfileDrag
            )
        )
    }

    @ViewBuilder
    private func profileContextMenu(for profile: GamepadConfigurationProfile) -> some View {
        let contextIDs = profileContextSelectionIDs(for: profile)
        let count = contextIDs.count

        if count == 1 {
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
        } else {
            Button {
                duplicateProfiles(ids: contextIDs)
            } label: {
                Label("Duplicate \(count) Setups", systemImage: "doc.on.doc")
            }
        }

        Divider()

        Button(role: .destructive) {
            deleteProfiles(contextIDs)
        } label: {
            Label(count == 1 ? "Delete" : "Delete \(count) Setups", systemImage: "trash")
        }
        .disabled(!canDeleteProfiles(contextIDs))
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
                Text("Layers")
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .textCase(.uppercase)

                Spacer(minLength: Geist.Spacing.s1)

                if let selectedLayerGroup {
                    Button("Ungroup") {
                        ungroupLayerGroup(selectedLayerGroup.id)
                    }
                    .geistButtonStyle(.tertiary, size: .small)
                    .help("Remove this group while keeping its children on the canvas")
                } else if canGroupSelectedControls {
                    Button("Group") {
                        groupSelectedControls()
                    }
                    .geistButtonStyle(.secondary, size: .small)
                    .help("Create a Figma-style group from the selected layers (⌘G)")
                }
            }
            .padding(.horizontal, Geist.Spacing.s2)

            if componentListItems.isEmpty {
                emptyComponentsMessage
            } else {
                LazyVStack(spacing: Geist.Spacing.s1) {
                    ForEach(layerListItems) { listItem in
                        switch listItem {
                        case .group(let group):
                            layerGroupSection(group)
                        case .component(let item):
                            componentRow(item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func layerGroupSection(_ group: GamepadEditorLayerGroupItem) -> some View {
        layerGroupRow(group)

        if isLayerGroupExpanded(group.id) {
            ForEach(group.children.indices, id: \.self) { index in
                componentRow(group.children[index], indentation: Geist.Spacing.s4)
            }
        }
    }

    private var emptyComponentsMessage: some View {
        Text("No components yet. Draw a shape on the canvas, add a joystick, trigger, or trackpad, or use Layout tools → Show Default Controls.")
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

    private func layerGroupRow(_ group: GamepadEditorLayerGroupItem) -> some View {
        let isSelected = isLayerGroupSelected(group)
        let primaryTextColor = group.isHidden
            ? Geist.color(.gray900, scheme: colorScheme).opacity(0.58)
            : Geist.color(.gray1000, scheme: colorScheme)
        let secondaryTextColor = group.isHidden
            ? Geist.color(.gray900, scheme: colorScheme).opacity(0.48)
            : Geist.color(.gray900, scheme: colorScheme)

        return HStack(spacing: Geist.Spacing.s1) {
            Button {
                toggleLayerGroupExpansion(group.id)
            } label: {
                Image(systemName: isLayerGroupExpanded(group.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .frame(width: 18, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(isLayerGroupExpanded(group.id) ? "Collapse" : "Expand") \(group.name) group")

            Button {
                handleSidebarGroupClick(group)
            } label: {
                HStack(spacing: Geist.Spacing.s2) {
                    Image(systemName: "rectangle.3.group")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(primaryTextColor)
                        .frame(width: 14)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(group.name)
                            .geistTypography(.label13)
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)
                        Text("Group • \(group.children.count) layer\(group.children.count == 1 ? "" : "s")")
                            .geistTypography(.label12)
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Geist.Spacing.s1)
                }
                .padding(.trailing, Geist.Spacing.s1)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(group.name) group")
            .help("Select the group to move or resize all nested layers together")

            componentIconButton(
                systemImage: "arrow.down",
                accessibilityLabel: "Send \(group.name) group backward",
                help: "Send group backward"
            ) {
                sendLayerGroupBackward(group)
            }

            componentIconButton(
                systemImage: "arrow.up",
                accessibilityLabel: "Bring \(group.name) group forward",
                help: "Bring group forward"
            ) {
                bringLayerGroupForward(group)
            }

            componentIconButton(
                systemImage: group.isLocationLocked ? "lock.fill" : "lock.open",
                accessibilityLabel: group.isLocationLocked ? "Unlock \(group.name) group" : "Lock \(group.name) group",
                help: group.isLocationLocked ? "Unlock group" : "Lock group"
            ) {
                setLayerGroupLocked(!group.isLocationLocked, groupID: group.id)
            }

            componentIconButton(
                systemImage: group.isHidden ? "eye.slash.fill" : "eye",
                accessibilityLabel: group.isHidden ? "Show \(group.name) group" : "Hide \(group.name) group",
                help: group.isHidden ? "Show group" : "Hide group"
            ) {
                setLayerGroupHidden(!group.isHidden, groupID: group.id)
            }
        }
        .padding(.leading, Geist.Spacing.s1)
        .padding(.trailing, Geist.Spacing.s1)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .fill(isSelected ? Geist.color(.background100, scheme: colorScheme) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(isSelected ? Geist.color(.blue700, scheme: colorScheme) : Color.clear, lineWidth: 1.5)
        )
        .contextMenu {
            Button("Ungroup") {
                ungroupLayerGroup(group.id)
            }
            Button(group.isLocationLocked ? "Unlock Group" : "Lock Group") {
                setLayerGroupLocked(!group.isLocationLocked, groupID: group.id)
            }
            Button(group.isHidden ? "Show Group" : "Hide Group") {
                setLayerGroupHidden(!group.isHidden, groupID: group.id)
            }
        }
    }

    private func componentRow(_ item: GamepadEditorComponentItem, indentation: CGFloat = 0) -> some View {
        let isSelected = isControlSelectionActive && selectedControlIDs.contains(item.identity)
        let primaryTextColor = item.isHidden
            ? Geist.color(.gray900, scheme: colorScheme).opacity(0.58)
            : Geist.color(.gray1000, scheme: colorScheme)
        let secondaryTextColor = item.isHidden
            ? Geist.color(.gray900, scheme: colorScheme).opacity(0.48)
            : Geist.color(.gray900, scheme: colorScheme)

        return HStack(spacing: Geist.Spacing.s1) {
            Button {
                handleSidebarComponentClick(item.identity)
            } label: {
                HStack(spacing: Geist.Spacing.s2) {
                    if indentation > 0 {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme).opacity(0.72))
                            .frame(width: 14)
                    }

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
                .padding(.leading, Geist.Spacing.s2 + indentation)
                .padding(.trailing, Geist.Spacing.s1)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(item.title)")

            componentIconButton(
                systemImage: "arrow.down",
                accessibilityLabel: "Send \(item.title) backward",
                help: "Send backward"
            ) {
                sendLayerBackward(item.identity)
            }

            componentIconButton(
                systemImage: "arrow.up",
                accessibilityLabel: "Bring \(item.title) forward",
                help: "Bring forward"
            ) {
                bringLayerForward(item.identity)
            }

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
        let isActive = profile.id == selectedProfileID
        let isSelected = selectedProfileIDs.contains(profile.id)

        Button {
            handleProfileClick(profile)
        } label: {
            HStack(spacing: Geist.Spacing.s1) {
                Text(profile.name)
                    .geistTypography(.heading14)
                    .lineLimit(1)

                if profile.launchTarget != nil {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .help("Attached application")
                }

                if profile.id == defaultProfileID {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .help("Default")
                }

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .help("Active")
                }
            }
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .frame(width: 148, height: 58, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .fill(profileSelectionFill(isActive: isActive, isSelected: isSelected, defaultFill: Geist.color(.background100, scheme: colorScheme)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(profileSelectionStroke(isActive: isActive, isSelected: isSelected), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            profileContextMenu(for: profile)
        }
        .onDrag {
            profileDragItemProvider(for: profile)
        }
        .onDrop(
            of: [Self.profileDragUTType],
            delegate: GamepadProfileDropDelegate(
                targetProfileID: profile.id,
                draggingProfileIDs: $draggingProfileIDs,
                onMove: moveDraggedProfiles,
                onDropEnded: finishProfileDrag
            )
        )
    }

    private var configurationFooter: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
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

    private var isFirstKeypadBlank: Bool {
        profiles.count == 1 && componentListItems.isEmpty
    }

    private var shouldOfferFirstKeypadOnboarding: Bool {
        showsPreview && !hasCompletedFirstKeypadOnboarding && (isFirstKeypadBlank || isFirstKeypadOnboardingReplayRequested)
    }

    private var shouldShowBlankSetupCanvasCard: Bool {
        componentListItems.isEmpty && activeCanvasTool == .select
    }

    private var blankSetupCanvasCard: some View {
        GamepadEditorBlankSetupCard(
            onShowDefaultControls: {
                setBuiltInControlsHidden(false)
                completeFirstKeypadOnboarding()
            },
            onAddJoystick: {
                addJoystickControl()
                completeFirstKeypadOnboarding()
            },
            onDrawButton: {
                activeCanvasTool = .rectangle
                completeFirstKeypadOnboarding()
            },
            onShowTour: {
                restartFirstKeypadOnboarding()
            }
        )
    }

    private func presentFirstKeypadOnboardingIfNeeded() {
        guard shouldOfferFirstKeypadOnboarding, activeFirstKeypadOnboardingStep == nil else { return }
        DispatchQueue.main.async {
            guard shouldOfferFirstKeypadOnboarding, activeFirstKeypadOnboardingStep == nil else { return }
            activeFirstKeypadOnboardingStep = .setups
        }
    }

    private func restartFirstKeypadOnboarding() {
        isFirstKeypadOnboardingReplayRequested = true
        hasCompletedFirstKeypadOnboarding = false
        activeFirstKeypadOnboardingStep = .setups
    }

    private func advanceFirstKeypadOnboarding() {
        guard let currentStep = activeFirstKeypadOnboardingStep else {
            presentFirstKeypadOnboardingIfNeeded()
            return
        }

        if let nextStep = currentStep.next {
            activeFirstKeypadOnboardingStep = nextStep
        } else {
            completeFirstKeypadOnboarding()
        }
    }

    private func completeFirstKeypadOnboarding() {
        guard activeFirstKeypadOnboardingStep != nil || !hasCompletedFirstKeypadOnboarding || isFirstKeypadOnboardingReplayRequested else { return }
        hasCompletedFirstKeypadOnboarding = true
        isFirstKeypadOnboardingReplayRequested = false
        activeFirstKeypadOnboardingStep = nil
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
        let actionIDs = selectedProfileActionIDs
        let selectedCount = actionIDs.count

        Button("Rename") {
            beginRenamingSelectedProfile()
        }
        .geistButtonStyle(.secondary, size: .small)
        .disabled(selectedCount != 1)

        Button(selectedCount > 1 ? "Duplicate Selected" : "Duplicate") {
            duplicateProfiles(ids: actionIDs)
        }
        .geistButtonStyle(.secondary, size: .small)

        Button(selectedCount > 1 ? "Delete Selected" : "Delete") {
            deleteProfiles(actionIDs)
        }
        .geistButtonStyle(.tertiary, size: .small)
        .disabled(!canDeleteProfiles(actionIDs))
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
            .animation(deviceFrameAnimation, value: deviceFrame.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Geist.color(.background100, scheme: colorScheme))
            .onAppear {
                noteCanvasLayoutSize(width: deviceFrame.screenRect.width, height: deviceFrame.screenRect.height)
            }
        }
        .gamepadEditorOnboardingTarget(.canvas)
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
                        groupedSelectionForControl: groupedSelectionIDs(for:),
                        onBeginUndoableChange: { actionName in
                            registerUndoSnapshot(actionName: actionName)
                        },
                        onEndEditingGesture: {
                            commitPendingEditorChanges()
                        }
                    )
                    .environment(\.colorScheme, activeKeypadColorScheme)
                    .environment(\.gamepadControlBarPreviewContext, controlBarPreviewContext)
                    .frame(width: screenDisplayRect.width, height: screenDisplayRect.height)
                    .offset(x: screenDisplayRect.minX, y: screenDisplayRect.minY)

                    GamepadEditorDeviceFrameView(deviceFrame: deviceFrame, displayScale: displayScale)
                        .frame(width: deviceWidth, height: deviceHeight)
                }
                .frame(width: deviceWidth, height: deviceHeight, alignment: .topLeading)
                .rotationEffect(.degrees(deviceFrameMotionRotationDegrees))
                .offset(deviceFrameMotionOffset)
            }
            .frame(width: max(viewportWidth, outerWidth), height: max(viewportHeight, outerHeight))
        }
        .frame(height: viewportHeight)
        .overlay {
            if shouldShowBlankSetupCanvasCard {
                blankSetupCanvasCard
                    .padding(Geist.Spacing.s6)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .overlay(alignment: .bottom) {
            canvasFloatingCreationToolbar
                .padding(.bottom, Geist.Spacing.s4)
        }
        .overlay(alignment: .topLeading) {
            canvasSidebarToggleBar
                .padding(Geist.Spacing.s4)
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
                    commitCanvasZoomDraft()
                }
        )
    }

    private var canvasSidebarToggleBar: some View {
        HStack(spacing: Geist.Spacing.s1) {
            canvasSidebarToggleButton(
                title: "Setups",
                systemImage: "sidebar.left",
                isVisible: isConfigurationSidebarVisible,
                shortcut: "1",
                shortcutLabel: "⌥⌘1",
                action: toggleConfigurationSidebarVisibility
            )

            canvasSidebarToggleButton(
                title: "Inspector",
                systemImage: "sidebar.right",
                isVisible: isInspectorSidebarVisible,
                shortcut: "2",
                shortcutLabel: "⌥⌘2",
                action: toggleInspectorSidebarVisibility
            )
        }
        .padding(Geist.Spacing.s1)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .fill(Geist.color(.background100, scheme: colorScheme).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 8, x: 0, y: 3)
    }

    private func canvasSidebarToggleButton(
        title: String,
        systemImage: String,
        isVisible: Bool,
        shortcut: KeyEquivalent,
        shortcutLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isVisible ? Color.white : Geist.color(.gray1000, scheme: colorScheme))
                .frame(width: 30, height: 30)
                .background(
                    isVisible ? Geist.color(.blue700, scheme: colorScheme) : Color.clear,
                    in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(shortcut, modifiers: [.command, .option])
        .accessibilityLabel("\(isVisible ? "Hide" : "Show") \(title) sidebar")
        .help("\(isVisible ? "Hide" : "Show") \(title) sidebar (\(shortcutLabel))")
    }

    private var canvasAppearanceBadge: some View {
        VStack(alignment: .trailing, spacing: Geist.Spacing.s2) {
            Label(activeDeviceFrame.displayName, systemImage: activeDeviceFrame.systemImage)
            Label("Editing \(editorColorScheme.displayName)", systemImage: editorColorScheme.systemImage)
        }
        .geistTypography(.label13)
        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .fill(Geist.color(.background100, scheme: colorScheme).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 8, x: 0, y: 3)
        .accessibilityLabel("Editing \(editorColorScheme.displayName) keypad appearance for \(activeDeviceFrame.displayName)")
    }

    private var canvasFloatingCreationToolbar: some View {
        HStack(spacing: Geist.Spacing.s2) {
            canvasToolButton(.select)

            toolbarMenu(systemImage: activeDeviceFrame.systemImage, accessibilityLabel: "Device frame") {
                if let connectedDeviceFrame {
                    Button {
                        setDeviceFrame(connectedDeviceFrame)
                    } label: {
                        Label("Use Connected iPhone (\(connectedDeviceFrame.displayName))", systemImage: connectedDeviceFrame.id == activeDeviceFrame.id ? "checkmark" : "iphone.gen3.radiowaves.left.and.right")
                    }
                    .help("Match the editor canvas to the currently connected iPhone.")

                    Divider()
                }

                ForEach(GamepadEditorDeviceCatalog.specs) { spec in
                    Menu(spec.displayName) {
                        ForEach(GamepadEditorDeviceOrientation.allCases) { orientation in
                            let frame = GamepadEditorDeviceFrame(spec: spec, orientation: orientation)
                            Button {
                                setDeviceFrame(frame)
                            } label: {
                                Label(frame.shortName, systemImage: frame.id == activeDeviceFrame.id ? "checkmark" : frame.systemImage)
                            }
                            .help(frame.helpText)
                        }
                    }
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
                Button("Add Trigger") {
                    addTriggerControl()
                }
                .disabled(customization.customButtons.filter { $0.normalized.isTrigger }.count >= GamepadCustomization.maximumTriggers || customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
                Button("Add Trackpad") {
                    addTrackpadControl()
                }
                .disabled(customization.customButtons.filter { $0.normalized.isTrackpad }.count >= GamepadCustomization.maximumTrackpads || customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
                Divider()
                Button("Add Soft Plate") {
                    addDecorationControl(kind: .plate)
                }
                .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
                Button("Add Ring") {
                    addDecorationControl(kind: .ring)
                }
                .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)
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
                Divider()
                Button("Apply Soft White Theme") {
                    update(actionName: "Apply Soft White Theme") { GamepadThemePreset.softWhiteController.apply(to: &$0) }
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
        .gamepadEditorOnboardingTarget(.toolbar)
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
        .gamepadEditorOnboardingTarget(.inspector)
    }

    private var inspectorCompactSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            inspectorHeader
            inspectorContent
        }
        .geistPanel(padding: Geist.Spacing.s4, radius: Geist.Radius.md, raised: false)
        .gamepadEditorOnboardingTarget(.inspector)
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

            Text(selectedControlIsEditable ? "Selected element properties" : "Keypad-level properties")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

            Label(selectedInspectorTitle, systemImage: selectedControlIsEditable ? "scope" : "iphone")
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
        if case .controlBarItem(let item) = selectedControlID, selectedControlIsEditable {
            controlBarItemInspector(item)
        } else if selectedControlIsEditable {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let profileOutputModeContent {
                    inspectorAccordionSection(.output, title: "Output") {
                        profileOutputModeContent()
                    }
                    Divider()
                }

                inspectorAccordionSection(.selectedElementIdentity, title: "Element", subtitle: selectedControlTitle) {
                    selectedElementIdentitySection
                }
                if selectedControlID == .system(.topBarActivation) {
                    Divider()
                    inspectorAccordionSection(.selectedElementControlBar, title: "Control Bar Contents", subtitle: controlBarItemsSummary) {
                        controlBarContentsSection
                    }
                }
                if shouldShowSelectedElementArrangementSection {
                    Divider()
                    inspectorAccordionSection(.selectedElementArrangement, title: "Arrangement") {
                        selectedElementArrangementSection
                    }
                }
                Divider()
                inspectorAccordionSection(.selectedElementStyle, title: "Reusable Style") {
                    selectedElementStyleFoundationSection
                }
                Divider()
                inspectorAccordionSection(.selectedElementHaptic, title: "Haptic") {
                    selectedElementHapticControls
                }
                Divider()
                inspectorAccordionSection(.selectedElementFill, title: "Fill") {
                    selectedElementColorSection
                }
                Divider()
                inspectorAccordionSection(.selectedElementPosition, title: "Position") {
                    selectedElementPositionControls
                }
                Divider()
                inspectorAccordionSection(.selectedElementLayout, title: "Layout") {
                    selectedElementLayoutControls
                }
                Divider()
                inspectorAccordionSection(.selectedElementCorners, title: "Corners") {
                    selectedElementRadiusSection
                }
                Divider()
                inspectorAccordionSection(.selectedElementEffects, title: "Effects") {
                    selectedElementEffectsSection
                }
            }
        } else {
            keypadLevelInspector
        }
    }

    private func controlBarItemInspector(_ item: GamepadControlBarItem) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            inspectorAccordionSection(.selectedElementIdentity, title: "Control Bar Item", subtitle: item.displayName) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    selectedElementLabelControls

                    GeistCheckboxToggle(title: "Show in control bar", isOn: visibleBinding(for: .controlBarItem(item)))

                    HStack(spacing: Geist.Spacing.s2) {
                        Button {
                            moveControlBarItem(item, by: -1)
                        } label: {
                            Label("Earlier", systemImage: "chevron.left")
                        }
                        .geistButtonStyle(.secondary, size: .small)
                        .disabled(customization.normalized.controlBarItems.first == item)

                        Button {
                            moveControlBarItem(item, by: 1)
                        } label: {
                            Label("Later", systemImage: "chevron.right")
                        }
                        .geistButtonStyle(.secondary, size: .small)
                        .disabled(customization.normalized.controlBarItems.last == item)
                    }

                    HStack(spacing: Geist.Spacing.s2) {
                        Button("Reset Appearance") {
                            resetSelectedControl()
                        }
                        .geistButtonStyle(.tertiary, size: .small)

                        Button("Remove") {
                            _ = deleteSelectedControl()
                        }
                        .geistButtonStyle(.error, size: .small)
                    }
                }
            }
            if item != .spacer {
                Divider()
                inspectorAccordionSection(.selectedElementStyle, title: "Reusable Style") {
                    selectedElementStyleFoundationSection
                }
                Divider()
                inspectorAccordionSection(.selectedElementHaptic, title: "Haptic") {
                    selectedElementHapticControls
                }
                Divider()
                inspectorAccordionSection(.selectedElementFill, title: "Fill") {
                    selectedElementColorSection
                }
            }
            Divider()
            inspectorAccordionSection(.selectedElementLayout, title: "Size") {
                controlBarItemSizeSection(item)
            }
            if item != .spacer {
                Divider()
                inspectorAccordionSection(.selectedElementCorners, title: "Shape & Corners") {
                    selectedElementRadiusSection
                }
                Divider()
                inspectorAccordionSection(.selectedElementEffects, title: "Effects") {
                    selectedElementEffectsSection
                }
            }
        }
    }

    private func controlBarItemSizeSection(_ item: GamepadControlBarItem) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            valueSlider(
                title: "Width",
                value: widthScaleBinding(for: .controlBarItem(item)),
                range: 0.25...3,
                valueText: "\(Int((widthScaleValue(for: .controlBarItem(item)) * 100).rounded()))%"
            )

            if item != .spacer {
                valueSlider(
                    title: "Height",
                    value: heightScaleBinding(for: .controlBarItem(item)),
                    range: 0.5...2,
                    valueText: "\(Int((heightScaleValue(for: .controlBarItem(item)) * 100).rounded()))%"
                )
            }

            Text(item == .spacer ? "The spacer width controls how much flexible room separates neighboring items." : "Control-bar items remain constrained to the bar while their width and height can be customized independently.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keypadLevelInspector: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if let profileOutputModeContent {
                inspectorAccordionSection(.output, title: "Output") {
                    profileOutputModeContent()
                }
                Divider()
            }

            inspectorAccordionSection(.keypadIdentity, title: "Keypad", subtitle: selectedProfile?.name ?? "Current Setup") {
                keypadIdentitySection
            }
            Divider()
#if os(macOS)
            inspectorAccordionSection(.keypadApplication, title: "Attached Application", subtitle: selectedProfile?.launchTarget?.displayName ?? "None") {
                attachedApplicationSection
            }
            Divider()
#endif
            inspectorAccordionSection(.keypadDevice, title: "Device & Canvas", subtitle: activeDeviceFrame.displayName) {
                keypadDeviceSection
            }
            Divider()
            inspectorAccordionSection(.keypadAppearance, title: "Appearance") {
                keypadAppearanceSection
            }
            Divider()
            inspectorAccordionSection(.keypadBackground, title: "Device Background") {
                keypadBackgroundSection
            }
            Divider()
            inspectorAccordionSection(.keypadEditor, title: "Editor Grid") {
                keypadEditorFoundationSection
            }
            Divider()
            inspectorAccordionSection(.keypadComponents, title: componentListItems.isEmpty ? "Blank setup" : "Component editing") {
                keypadComponentsHintSection
            }
        }
    }

    private func inspectorAccordionSection<Content: View>(
        _ section: GamepadInspectorAccordionSection,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedInspectorSections.contains(section)

        return VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleInspectorAccordionSection(section)
            } label: {
                HStack(alignment: .center, spacing: Geist.Spacing.s2) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .frame(width: 14, height: 18)

                    VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                        Text(title)
                            .geistTypography(.heading14)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .geistTypography(.copy13)
                                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: Geist.Spacing.s2)
                }
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .padding(.vertical, Geist.Spacing.s2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(isExpanded ? "Collapse" : "Expand") \(title) inspector section"))
            .accessibilityValue(Text(isExpanded ? "Expanded" : "Collapsed"))
            .help(isExpanded ? "Hide \(title) options" : "Show \(title) options")

            // Keep accordion content from sliding through neighboring rows as it
            // appears/disappears. The height still animates with the section, but
            // the body only fades inside its own clipped container.
            ZStack(alignment: .topLeading) {
                if isExpanded {
                    VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                        content()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, Geist.Spacing.s4)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .clipped()
        }
    }

    private func toggleInspectorAccordionSection(_ section: GamepadInspectorAccordionSection) {
        let animation: Animation? = accessibilityReduceMotion ? nil : .easeInOut(duration: 0.16)
        withAnimation(animation) {
            if expandedInspectorSections.contains(section) {
                expandedInspectorSections.remove(section)
            } else {
                expandedInspectorSections.insert(section)
            }
        }
    }

    private var keypadIdentitySection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack {
                Spacer(minLength: Geist.Spacing.s2)
                defaultProfileButton
            }

            selectedSetupNameEditor
        }
    }

#if os(macOS)
    private var attachedApplicationSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Attach a Mac application to this setup so the paired iPhone can launch or refocus it from the keypad.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            if let launchTarget = selectedProfile?.launchTarget {
                HStack(alignment: .center, spacing: Geist.Spacing.s3) {
                    attachedApplicationIcon(for: launchTarget)

                    VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                        Text(launchTarget.displayName)
                            .geistTypography(.heading14)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .lineLimit(1)
                        Text(launchTarget.detailText)
                            .geistTypography(.copy13)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                            .lineLimit(2)
                    }

                    Spacer(minLength: Geist.Spacing.s2)
                }
                .padding(Geist.Spacing.s3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                        .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                )

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Geist.Spacing.s2) {
                        attachedApplicationButtons(hasLaunchTarget: true)
                    }
                    VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                        attachedApplicationButtons(hasLaunchTarget: true)
                    }
                }
            } else {
                Text("No application is attached to this setup yet.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                attachedApplicationButtons(hasLaunchTarget: false)
            }

            if let attachedApplicationStatus {
                Text(attachedApplicationStatus)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func attachedApplicationButtons(hasLaunchTarget: Bool) -> some View {
        Button {
            chooseApplicationForSelectedProfile()
        } label: {
            Label(hasLaunchTarget ? "Change…" : "Choose Application…", systemImage: "folder")
        }
        .geistButtonStyle(.secondary, size: .small)

        if hasLaunchTarget {
            Button {
                launchSelectedProfileApplication()
            } label: {
                Label("Launch", systemImage: "play.fill")
            }
            .geistButtonStyle(.secondary, size: .small)

            Button {
                revealSelectedProfileApplication()
            } label: {
                Label("Reveal", systemImage: "finder")
            }
            .geistButtonStyle(.tertiary, size: .small)

            Button {
                clearSelectedProfileApplication()
            } label: {
                Label("Remove", systemImage: "xmark.circle")
            }
            .geistButtonStyle(.tertiary, size: .small)
        }
    }

    @ViewBuilder
    private func attachedApplicationIcon(for launchTarget: GamepadProfileLaunchTarget) -> some View {
        if let data = launchTarget.iconPNGData, let image = GamepadImageDecodeCache.image(for: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        } else if let url = launchTarget.resolvedApplicationURL() {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 32, height: 32)
        }
    }

    private func chooseApplicationForSelectedProfile() {
        commitSelectedProfileNameDraft()
        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.message = "Choose the Mac application to attach to this keypad setup."
        panel.prompt = "Attach"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        attachApplication(url)
    }

    private func attachApplication(_ url: URL) {
        guard let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let launchTarget = GamepadProfileLaunchTarget.application(url: url, bookmarkData: bookmarkData)
        var profile = profiles[index]
        profile.launchTarget = launchTarget
        profile.updatedAt = Date.currentMilliseconds
        profiles[index] = profile.normalized
        attachedApplicationStatus = "Attached \(launchTarget.displayName)."
        persistProfiles()
    }

    private func clearSelectedProfileApplication() {
        guard let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        let name = profiles[index].launchTarget?.displayName ?? "application"
        profiles[index].launchTarget = nil
        profiles[index].updatedAt = Date.currentMilliseconds
        attachedApplicationStatus = "Removed \(name)."
        persistProfiles()
    }

    private func launchSelectedProfileApplication() {
        guard let profile = selectedProfile,
              let launchTarget = profile.launchTarget
        else { return }

        if let onLaunchProfileTarget {
            onLaunchProfileTarget(profile.id)
            attachedApplicationStatus = "Sent launch request for \(launchTarget.displayName)."
            return
        }

        guard let url = launchTarget.resolvedApplicationURL() else {
            attachedApplicationStatus = "Couldn’t find \(launchTarget.displayName). Choose the application again."
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error {
                    attachedApplicationStatus = "Couldn’t launch \(launchTarget.displayName): \(error.localizedDescription)"
                } else {
                    attachedApplicationStatus = "Launched \(launchTarget.displayName)."
                }
            }
        }
    }

    private func revealSelectedProfileApplication() {
        guard let launchTarget = selectedProfile?.launchTarget else { return }
        guard let url = launchTarget.resolvedApplicationURL() else {
            attachedApplicationStatus = "Couldn’t find \(launchTarget.displayName). Choose the application again."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
#endif

    private var keypadDeviceSection: some View {
        let frame = activeDeviceFrame

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Menu {
                if let connectedDeviceFrame {
                    Button {
                        setDeviceFrame(connectedDeviceFrame)
                    } label: {
                        Label("Use Connected iPhone (\(connectedDeviceFrame.displayName))", systemImage: connectedDeviceFrame.id == frame.id ? "checkmark" : "iphone.gen3.radiowaves.left.and.right")
                    }

                    Divider()
                }

                ForEach(GamepadEditorDeviceCatalog.specs) { spec in
                    Menu(spec.displayName) {
                        ForEach(GamepadEditorDeviceOrientation.allCases) { orientation in
                            let presetFrame = GamepadEditorDeviceFrame(spec: spec, orientation: orientation)
                            Button {
                                setDeviceFrame(presetFrame)
                            } label: {
                                Label(presetFrame.shortName, systemImage: presetFrame.id == frame.id ? "checkmark" : presetFrame.systemImage)
                            }
                            .help(presetFrame.helpText)
                        }
                    }
                }

                Divider()

                Button {
                    setCustomDeviceCanvas(width: frame.screenRect.width, height: frame.screenRect.height, orientation: frame.orientation)
                } label: {
                    Label("Use Current Size as Custom", systemImage: frame.spec.id.hasPrefix(GamepadEditorDeviceCatalog.customFrameIDPrefix) ? "checkmark" : "rectangle.dashed")
                }
            } label: {
                HStack(spacing: Geist.Spacing.s2) {
                    Image(systemName: frame.systemImage)
                    Text(frame.displayName)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .geistTypography(.label14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .padding(.horizontal, Geist.Spacing.s3)
                .frame(height: Geist.Spacing.s10)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                        .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .menuStyle(.button)
            .accessibilityLabel("Device preset")

            GeistSegmentedPicker(title: "Orientation", options: GamepadEditorDeviceOrientation.allCases, selection: deviceOrientationBinding) { orientation in
                orientation.displayName
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                inspectorMetricField(title: "Width", value: deviceCanvasWidthBinding, unit: "pt", maxFractionDigits: 0, accessibilityLabel: "Device screen width in points")
                inspectorMetricField(title: "Height", value: deviceCanvasHeightBinding, unit: "pt", maxFractionDigits: 0, accessibilityLabel: "Device screen height in points")
            }

            Text("Choose an iPhone preset or type a custom screen size. Portrait and landscape canvases are saved separately for this setup and the iPhone swaps between them automatically as it rotates.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keypadAppearanceSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Saved Mode")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                GeistSegmentedPicker(title: "Saved Mode", options: GamepadColorSchemePreference.allCases, selection: binding(\.colorSchemePreference)) { preference in
                    preference.displayName
                }
                Text(customization.colorSchemePreference.description)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("View Mode")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                GeistSegmentedPicker(title: "View Mode", options: GamepadEditorColorScheme.allCases, selection: editorColorSchemeBinding) { scheme in
                    scheme.displayName
                }
                Text("The canvas is viewing \(editorColorScheme.displayName.lowercased()) mode and editing the \(Self.displayName(for: activeKeypadColorScheme).lowercased()) color palette.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var keypadBackgroundSection: some View {
        let editingScheme = activeKeypadColorScheme
        let colorValue = customization.backgroundColorValue(for: editingScheme)
        let fillStyle = customization.keypadBackgroundFillStyle(scheme: editingScheme)
        let usesCustomColor = customization.hasCustomBackgroundFill(for: editingScheme)
        let schemeName = Self.displayName(for: editingScheme)

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text(usesCustomColor ? "Custom \(schemeName.lowercased()) background" : "Using the default \(schemeName.lowercased()) background")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            backgroundColorRow(
                colorValue: colorValue,
                hexValue: fillColorHexPlainBinding(for: .background, scheme: editingScheme),
                alphaValue: fillColorAlphaTextBinding(for: .background, scheme: editingScheme),
                usesCustomColor: usesCustomColor,
                editingScheme: editingScheme,
                fillStyle: fillStyle
            )
            .popover(isPresented: $isBackgroundColorPopoverPresented, arrowEdge: .leading) {
                fillDetailPopover(
                    for: .background,
                    editingScheme: editingScheme,
                    schemeName: schemeName,
                    usesCustomColor: usesCustomColor
                )
            }
        }
    }

    private var keypadEditorFoundationSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            GeistCheckboxToggle(title: "Show grid", isOn: gridShowsBinding)
            GeistCheckboxToggle(title: "Snap to grid", isOn: gridSnapBinding)
            GeistCheckboxToggle(title: "Snap to objects", isOn: objectSnapBinding)
            inspectorMetricField(title: "Grid", value: gridSizeBinding, unit: "pt", maxFractionDigits: 0, accessibilityLabel: "Editor grid size")

            Text("These settings are saved with the keypad design metadata so a shared profile opens with the same editor feel.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var keypadComponentsHintSection: some View {
        let isBlankSetup = componentListItems.isEmpty

        return Text(isBlankSetup ? "Draw a shape on the canvas, add a joystick, trigger, or trackpad, or choose Layout tools → Show Default Controls to add keypad components." : "Select a component on the canvas or from the components list to edit its label, shortcut, fill, size, and shape.")
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

    private var controlBarItemsSummary: String {
        let items = customization.normalized.controlBarItems.filter { $0 != .spacer }
        guard !items.isEmpty else { return "No controls" }
        return items.map(\.shortName).joined(separator: ", ")
    }

    private var controlBarContentsSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Choose which controls appear when the iPhone control bar is open. Drag the Control Bar element on the canvas to move the activation hotspot; use this list to set the bar’s contents and order.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            let items = customization.normalized.controlBarItems
            if items.isEmpty {
                Text("No controls are pinned to the bar.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .padding(Geist.Spacing.s3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                            .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                    )
            } else {
                VStack(spacing: Geist.Spacing.s2) {
                    ForEach(items) { item in
                        controlBarItemRow(item)
                    }
                }
            }

            HStack(spacing: Geist.Spacing.s2) {
                Menu {
                    ForEach(GamepadControlBarItem.allCases.filter { !items.contains($0) }) { item in
                        Button {
                            addControlBarItem(item)
                        } label: {
                            Label(item.displayName, systemImage: item.systemImage)
                        }
                    }
                } label: {
                    Label("Add Control", systemImage: "plus")
                }
                .geistButtonStyle(.secondary, size: .small)
                .disabled(GamepadControlBarItem.allCases.allSatisfy { items.contains($0) })

                Button("Reset") {
                    resetControlBarItems()
                }
                .geistButtonStyle(.tertiary, size: .small)
            }
        }
    }

    private func controlBarItemRow(_ item: GamepadControlBarItem) -> some View {
        let items = customization.normalized.controlBarItems
        let index = items.firstIndex(of: item) ?? 0

        return HStack(spacing: Geist.Spacing.s2) {
            Image(systemName: item.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .geistTypography(.label14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(item.subtitle)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .lineLimit(2)
            }

            Spacer(minLength: Geist.Spacing.s2)

            HStack(spacing: 4) {
                Button {
                    moveControlBarItem(item, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .disabled(index == 0)
                .accessibilityLabel("Move \(item.displayName) up")

                Button {
                    moveControlBarItem(item, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .disabled(index >= items.count - 1)
                .accessibilityLabel("Move \(item.displayName) down")

                Button {
                    removeControlBarItem(item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.displayName)")
            }
            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
        }
        .padding(Geist.Spacing.s2)
        .background(
            Geist.color(isControlSelectionActive && selectedControlID == .controlBarItem(item) ? .blue100 : .gray100, scheme: colorScheme),
            in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(
                    Geist.color(isControlSelectionActive && selectedControlID == .controlBarItem(item) ? .blue700 : .grayAlpha400, scheme: colorScheme),
                    lineWidth: isControlSelectionActive && selectedControlID == .controlBarItem(item) ? 1.5 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectComponent(.controlBarItem(item))
        }
    }

    private func addControlBarItem(_ item: GamepadControlBarItem) {
        update { customization in
            customization.addControlBarItem(item)
        }
        selectComponent(.controlBarItem(item))
    }

    private func removeControlBarItem(_ item: GamepadControlBarItem) {
        update { customization in
            customization.removeControlBarItem(item)
        }
        if selectedControlID == .controlBarItem(item) {
            selectComponent(.system(.topBarActivation))
        }
    }

    private func moveControlBarItem(_ item: GamepadControlBarItem, by offset: Int) {
        update { customization in
            let items = GamepadCustomization.normalizedControlBarItems(customization.controlBarItems)
            guard let index = items.firstIndex(of: item) else { return }
            let destination = min(max(index + offset, 0), max(items.count - 1, 0))
            guard destination != index else { return }
            customization.moveControlBarItem(item, to: destination)
        }
    }

    private func resetControlBarItems() {
        update { customization in
            customization.resetControlBar()
        }
    }

    @ViewBuilder
    private var selectedElementIdentitySection: some View {
        if let selectedLayerGroup,
           let groupItem = layerGroupItems.first(where: { $0.id == selectedLayerGroup.id }) {
            selectedGroupIdentitySection(groupItem)
        } else {
            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                HStack {
                    Spacer(minLength: Geist.Spacing.s2)

                    Button("Reset") {
                        resetSelectedControl()
                    }
                    .geistButtonStyle(.tertiary, size: .small)
                }

                controlSelectionPicker
                selectedElementLabelControls
                selectedElementOutputControls

                componentStateControls

                if case .custom(let id) = selectedControlID,
                   let customButton = customButton(id: id)?.normalized {
                    Button(deleteTitle(for: customButton)) {
                        _ = deleteCustomButton(id: id)
                    }
                    .geistButtonStyle(.error, size: .small)
                }
            }
        }
    }

    private func selectedGroupIdentitySection(_ group: GamepadEditorLayerGroupItem) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(spacing: Geist.Spacing.s2) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.name)
                        .geistTypography(.heading14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("\(group.children.count) nested layer\(group.children.count == 1 ? "" : "s")")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }
                Spacer(minLength: Geist.Spacing.s2)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) { selectedGroupStateButtons(group) }
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) { selectedGroupStateButtons(group) }
            }

            Button("Ungroup") {
                ungroupLayerGroup(group.id)
            }
            .geistButtonStyle(.tertiary, size: .small)

            Text("Group selection mirrors Figma: drag or resize any selected child on the canvas to transform the whole group. Select a nested layer in the sidebar to edit one child.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func selectedGroupStateButtons(_ group: GamepadEditorLayerGroupItem) -> some View {
        Button(group.isHidden ? "Show Group" : "Hide Group") {
            setLayerGroupHidden(!group.isHidden, groupID: group.id)
        }
        .geistButtonStyle(.secondary, size: .small)

        Button(group.isLocationLocked ? "Unlock Group" : "Lock Group") {
            setLayerGroupLocked(!group.isLocationLocked, groupID: group.id)
        }
        .geistButtonStyle(.secondary, size: .small)
    }

    private var shouldShowSelectedElementArrangementSection: Bool {
        selectedControlIDs.count > 1 || selectedLayerGroup != nil
    }

    private var selectedElementArrangementSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) { groupingButtons }
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) { groupingButtons }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) { alignmentButtons }
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) { alignmentButtons }
            }

            Text(selectedLayerGroup == nil ? "Alignment, distribution, and grouping apply to the current multi-selection." : "This group behaves like one layer: drag or resize any selected child to move the whole group.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var groupingButtons: some View {
        if let selectedLayerGroup {
            Button("Ungroup") { ungroupLayerGroup(selectedLayerGroup.id) }
                .geistButtonStyle(.tertiary, size: .small)
        } else {
            Button("Group") { groupSelectedControls() }
                .geistButtonStyle(.secondary, size: .small)
                .disabled(!canGroupSelectedControls)
                .help("Create a Figma-style group from the selected layers (⌘G)")
        }
    }

    @ViewBuilder
    private var alignmentButtons: some View {
        Button("Align H") { alignSelectedControls(.horizontalCenter) }
            .geistButtonStyle(.secondary, size: .small)
        Button("Align V") { alignSelectedControls(.verticalCenter) }
            .geistButtonStyle(.secondary, size: .small)
        Button("Distribute H") { distributeSelectedControls(axis: .horizontal) }
            .geistButtonStyle(.secondary, size: .small)
        Button("Distribute V") { distributeSelectedControls(axis: .vertical) }
            .geistButtonStyle(.secondary, size: .small)
    }

    private var selectedElementStyleFoundationSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(spacing: Geist.Spacing.s2) {
                Button("Copy Style") { copySelectedElementStyle() }
                    .geistButtonStyle(.secondary, size: .small)
                Button("Paste Style") { pasteStyleToSelectedElements() }
                    .geistButtonStyle(.secondary, size: .small)
                    .disabled(copiedElementStyle == nil)
            }

            if !customization.styleLibrary.normalized.styles.isEmpty {
                GeistMenuPicker(title: "Style", options: [""] + customization.styleLibrary.normalized.styles.map(\.id), selection: styleIDBinding(for: selectedControlID)) { id in
                    id.isEmpty ? "Local overrides" : (customization.styleLibrary.style(id: id)?.name ?? id)
                }
            } else {
                Text("Create named styles from the CLI for now, then apply them here or paste visual overrides between elements.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("SF Symbol or text icon", text: iconTextBinding(for: selectedControlID))
                .geistInput(size: .small)
        }
    }

    private var selectedElementHapticControls: some View {
        let feedback = hapticFeedbackValue(for: selectedControlID)
        return VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            HStack(spacing: Geist.Spacing.s3) {
                Text("Style")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Spacer()
                GeistMenuPicker(title: "Haptic", options: GamepadHapticStyle.allCases, selection: hapticStyleBinding(for: selectedControlID)) { style in
                    style.displayName
                }
            }

            if feedback.style != .none {
                HStack(spacing: Geist.Spacing.s3) {
                    Text("Pattern")
                        .geistTypography(.label13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    Spacer()
                    GeistMenuPicker(title: "Haptic Pattern", options: GamepadHapticPattern.allCases, selection: hapticPatternBinding(for: selectedControlID)) { pattern in
                        pattern.displayName
                    }
                }

                valueSlider(
                    title: "Power",
                    value: hapticIntensityBinding(for: selectedControlID),
                    range: Double(GamepadHapticFeedback.minimumIntensity)...Double(GamepadHapticFeedback.maximumIntensity),
                    valueText: "\(Int((feedback.intensity * 100).rounded()))%"
                )
                valueSlider(
                    title: "Sharp",
                    value: hapticSharpnessBinding(for: selectedControlID),
                    range: Double(GamepadHapticFeedback.minimumSharpness)...Double(GamepadHapticFeedback.maximumSharpness),
                    valueText: "\(Int((feedback.sharpness * 100).rounded()))%"
                )
                valueSlider(
                    title: "Length",
                    value: hapticDurationBinding(for: selectedControlID),
                    range: Double(GamepadHapticFeedback.minimumDuration)...Double(GamepadHapticFeedback.maximumDuration),
                    valueText: "\(Int((feedback.duration * 1_000).rounded())) ms"
                )
            }

            Text("Haptics are device-wide on iPhone. Use different strength and rhythm to distinguish controls.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
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
                Text("Leave blank to use the element’s output label (\(defaultLabel(for: button))).")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }
        case .custom(let id):
            if customButton(id: id) != nil {
                customButtonControls(id: id)
            }
        case .system(let control):
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text(control.displayName)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("Drag this hotspot to choose where swiping down reveals the iPhone control bar. Resize it to make the activation area easier or harder to hit.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .controlBarItem(let item):
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text(item.displayName)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(item.subtitle)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var selectedElementOutputControls: some View {
        if let selectedElementOutputContent,
           let input = selectedPrimaryElementInputID {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Output")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                selectedElementOutputContent(input)
                Text("This output is saved directly on the selected element. It can be a keyboard shortcut, a virtual controller button, or both.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedElementColorSection: some View {
        let editingScheme = activeKeypadColorScheme
        let colorValue = selectedFillColorValue(for: selectedControlID, scheme: editingScheme)
        let fillStyle = selectedLayoutCustomization(for: selectedControlID).fillStyle(for: editingScheme) ?? .solid(colorValue)
        let usesCustomColor = selectedLayoutCustomization(for: selectedControlID).hasCustomFillColor(for: editingScheme)
        let schemeName = Self.displayName(for: editingScheme)

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            fillColorRow(
                colorValue: colorValue,
                hexValue: fillColorHexPlainBinding(for: selectedControlID, scheme: editingScheme),
                alphaValue: fillColorAlphaTextBinding(for: selectedControlID, scheme: editingScheme),
                usesCustomColor: usesCustomColor,
                editingScheme: editingScheme,
                fillStyle: fillStyle
            )
            .popover(isPresented: $isFillColorPopoverPresented, arrowEdge: .leading) {
                fillDetailPopover(
                    for: .element(selectedControlID),
                    editingScheme: editingScheme,
                    schemeName: schemeName,
                    usesCustomColor: usesCustomColor
                )
            }

            if selectedControlIsJoystick(selectedControlID) {
                joystickKnobColorControls(for: selectedControlID, editingScheme: editingScheme, schemeName: schemeName)
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
        editingScheme: ColorScheme,
        fillStyle: GamepadFillStyle
    ) -> some View {
        colorFillRow(
            colorValue: colorValue,
            hexValue: hexValue,
            alphaValue: alphaValue,
            usesCustomColor: usesCustomColor,
            fillStyle: fillStyle,
            isPresented: $isFillColorPopoverPresented,
            openAccessibilityLabel: "Open fill color picker",
            visibilityAccessibilityPrefix: "fill",
            clearAccessibilityLabel: "Remove custom fill",
            onToggleVisibility: { toggleFillVisibility(for: selectedControlID, scheme: editingScheme) },
            onClear: { clearCustomFillColor(for: selectedControlID, scheme: editingScheme) }
        )
    }

    private func joystickKnobColorControls(
        for identity: GamepadControlIdentity,
        editingScheme: ColorScheme,
        schemeName: String
    ) -> some View {
        let colorValue = joystickKnobColorValue(for: identity, scheme: editingScheme)
        let usesCustomColor = selectedLayoutCustomization(for: identity).hasCustomJoystickKnobColor(for: editingScheme)

        return VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            Text("Thumbstick")
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

            colorFillRow(
                colorValue: colorValue,
                hexValue: joystickKnobColorHexPlainBinding(for: identity, scheme: editingScheme),
                alphaValue: joystickKnobColorAlphaTextBinding(for: identity, scheme: editingScheme),
                usesCustomColor: usesCustomColor,
                fillStyle: .solid(colorValue),
                isPresented: $isJoystickKnobColorPopoverPresented,
                openAccessibilityLabel: "Open thumbstick color picker",
                visibilityAccessibilityPrefix: "thumbstick",
                clearAccessibilityLabel: "Use automatic thumbstick color",
                onToggleVisibility: { toggleJoystickKnobColorVisibility(for: identity, scheme: editingScheme) },
                onClear: { clearJoystickKnobColor(for: identity, scheme: editingScheme) }
            )
            .popover(isPresented: $isJoystickKnobColorPopoverPresented, arrowEdge: .leading) {
                joystickKnobColorPopover(
                    for: identity,
                    editingScheme: editingScheme,
                    schemeName: schemeName,
                    usesCustomColor: usesCustomColor
                )
            }

            Text(usesCustomColor ? "Custom \(schemeName.lowercased()) thumbstick color" : "Using automatic contrast for the \(schemeName.lowercased()) thumbstick")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func backgroundColorRow(
        colorValue: GamepadRGBAColor,
        hexValue: Binding<String>,
        alphaValue: Binding<String>,
        usesCustomColor: Bool,
        editingScheme: ColorScheme,
        fillStyle: GamepadFillStyle
    ) -> some View {
        colorFillRow(
            colorValue: colorValue,
            hexValue: hexValue,
            alphaValue: alphaValue,
            usesCustomColor: usesCustomColor,
            fillStyle: fillStyle,
            isPresented: $isBackgroundColorPopoverPresented,
            openAccessibilityLabel: "Open background fill picker",
            visibilityAccessibilityPrefix: "background",
            clearAccessibilityLabel: "Reset custom background",
            onToggleVisibility: { toggleBackgroundVisibility(for: editingScheme) },
            onClear: { clearBackgroundColor(for: editingScheme) }
        )
    }

    private func colorFillRow(
        colorValue: GamepadRGBAColor,
        hexValue: Binding<String>,
        alphaValue: Binding<String>,
        usesCustomColor: Bool,
        fillStyle: GamepadFillStyle? = nil,
        isPresented: Binding<Bool>,
        openAccessibilityLabel: String,
        visibilityAccessibilityPrefix: String,
        clearAccessibilityLabel: String,
        onToggleVisibility: @escaping () -> Void,
        onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Geist.Spacing.s2) {
            HStack(spacing: 0) {
                Button {
                    isPresented.wrappedValue.toggle()
                } label: {
                    GamepadFillPreview(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fillStyle: fillStyle ?? .solid(colorValue))
                        .frame(width: 28, height: 28)
                        .padding(.leading, Geist.Spacing.s2)
                        .padding(.trailing, Geist.Spacing.s1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(openAccessibilityLabel)

                if let fillStyle, case .solid = fillStyle.normalized {
                    TextField("000000", text: hexValue)
                        .textFieldStyle(.plain)
                        .geistTypography(.label14Mono)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .frame(minWidth: 72)
#if os(iOS)
                        .textInputAutocapitalization(.characters)
#endif
                } else if let fillStyle {
                    Text(fillStyle.displayName)
                        .geistTypography(.label14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .frame(minWidth: 72, alignment: .leading)
                } else {
                    TextField("000000", text: hexValue)
                        .textFieldStyle(.plain)
                        .geistTypography(.label14Mono)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .frame(minWidth: 72)
#if os(iOS)
                        .textInputAutocapitalization(.characters)
#endif
                }

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
            .background(Geist.color(isPresented.wrappedValue ? .gray200 : .gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(isPresented.wrappedValue ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha300, scheme: colorScheme), lineWidth: isPresented.wrappedValue ? 1.25 : 1)
            )

            Button(action: onToggleVisibility) {
                Image(systemName: colorValue.alpha > 0.001 ? "eye" : "eye.slash")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .accessibilityLabel(colorValue.alpha > 0.001 ? "Hide \(visibilityAccessibilityPrefix)" : "Show \(visibilityAccessibilityPrefix)")

            Button(action: onClear) {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 28, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(usesCustomColor ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.gray700, scheme: colorScheme))
            .disabled(!usesCustomColor)
            .accessibilityLabel(clearAccessibilityLabel)
        }
    }

    private func joystickKnobColorPopover(
        for identity: GamepadControlIdentity,
        editingScheme: ColorScheme,
        schemeName: String,
        usesCustomColor: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(spacing: Geist.Spacing.s3) {
                Text("Thumbstick Color")
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Button {
                    isJoystickKnobColorPopoverPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .regular))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            }

            GamepadColorPlane(color: joystickKnobColorValueBinding(for: identity, scheme: editingScheme), hue: $fillColorPickerHue)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

            GamepadHueSlider(color: joystickKnobColorValueBinding(for: identity, scheme: editingScheme), hue: $fillColorPickerHue)
                .frame(height: 26)

            GamepadAlphaSlider(color: joystickKnobColorValueBinding(for: identity, scheme: editingScheme))
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

                GamepadColorValueField(text: joystickKnobColorHexPlainBinding(for: identity, scheme: editingScheme), placeholder: "000000")

                GamepadColorValueField(text: joystickKnobColorAlphaTextBinding(for: identity, scheme: editingScheme), placeholder: "100", suffix: "%", width: 96)
            }

            fillPaletteScopeMenu(schemeName: schemeName)

            Button("Use Automatic \(schemeName) Thumbstick") {
                clearJoystickKnobColor(for: identity, scheme: editingScheme)
            }
            .geistButtonStyle(.tertiary, size: .small)
            .disabled(!usesCustomColor)
        }
        .padding(Geist.Spacing.s3)
        .frame(width: 360)
        .background(Geist.color(.background100, scheme: colorScheme))
    }

    private func fillDetailPopover(
        for target: GamepadFillEditorTarget,
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
                    setFillPopoverPresented(true, for: target)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Button {
                    setFillPopoverPresented(false, for: target)
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
            fillPopoverTabBar
            Divider()

            Group {
                switch activeFillPopoverTab {
                case .solid:
                    fillSolidPanel(for: target, editingScheme: editingScheme, schemeName: schemeName, usesCustomColor: usesCustomColor)
                case .gradient:
                    fillGradientPanel(for: target, editingScheme: editingScheme, schemeName: schemeName, usesCustomColor: usesCustomColor)
                case .tile:
                    fillTilePanel(for: target, editingScheme: editingScheme, schemeName: schemeName, usesCustomColor: usesCustomColor)
                case .image:
                    fillImagePanel(for: target, editingScheme: editingScheme, schemeName: schemeName, usesCustomColor: usesCustomColor)
                }
            }
        }
        .frame(width: 360)
        .background(Geist.color(.background100, scheme: colorScheme))
        .fileImporter(isPresented: $isFillImageImporterPresented, allowedContentTypes: [.image]) { result in
            handleFillImageImport(result, for: target, scheme: editingScheme)
        }
        .onAppear {
            activeFillPopoverTab = fillPopoverTab(for: target, scheme: editingScheme)
            fillImageImportError = nil
        }
    }

    private func setFillPopoverPresented(_ isPresented: Bool, for target: GamepadFillEditorTarget) {
        switch target {
        case .element:
            isFillColorPopoverPresented = isPresented
        case .background:
            isBackgroundColorPopoverPresented = isPresented
        }
    }

    private var fillPopoverTabBar: some View {
        HStack(spacing: Geist.Spacing.s2) {
            ForEach(GamepadFillPopoverTab.allCases) { tab in
                Button {
                    activeFillPopoverTab = tab
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .frame(width: 34, height: 34)
                        .background(activeFillPopoverTab == tab ? Geist.color(.gray100, scheme: colorScheme) : Color.clear, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(tab.title)
                .accessibilityLabel(tab.title)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
    }

    private func fillSolidPanel(
        for target: GamepadFillEditorTarget,
        editingScheme: ColorScheme,
        schemeName: String,
        usesCustomColor: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            GamepadColorPlane(color: fillColorValueBinding(for: target, scheme: editingScheme), hue: $fillColorPickerHue)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

            GamepadHueSlider(color: fillColorValueBinding(for: target, scheme: editingScheme), hue: $fillColorPickerHue)
                .frame(height: 26)

            GamepadAlphaSlider(color: fillColorValueBinding(for: target, scheme: editingScheme))
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

                GamepadColorValueField(text: fillColorHexPlainBinding(for: target, scheme: editingScheme), placeholder: "000000")

                GamepadColorValueField(text: fillColorAlphaTextBinding(for: target, scheme: editingScheme), placeholder: "100", suffix: "%", width: 96)
            }

            fillPaletteScopeMenu(schemeName: schemeName)

            if target.showsElementColorPresets {
                HStack(spacing: Geist.Spacing.s2) {
                    ForEach(GamepadAccentStyle.allCases) { style in
                        elementColorPresetChip(style, scheme: editingScheme)
                    }
                }
            }

            Button("Use Default \(schemeName) \(target.defaultResetNoun)") {
                clearCustomFill(for: target, scheme: editingScheme)
            }
            .geistButtonStyle(.tertiary, size: .small)
            .disabled(!usesCustomColor)
        }
        .padding(Geist.Spacing.s3)
        .onAppear {
            if case .solid = selectedFillStyleValue(for: target, scheme: editingScheme) {
                return
            }
            setFillColor(selectedFillColorValue(for: target, scheme: editingScheme), for: target, scheme: editingScheme)
        }
    }

    private func fillGradientPanel(
        for target: GamepadFillEditorTarget,
        editingScheme: ColorScheme,
        schemeName: String,
        usesCustomColor: Bool
    ) -> some View {
        let gradient = gradientFillBinding(for: target, scheme: editingScheme).wrappedValue.normalized

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(spacing: Geist.Spacing.s2) {
                Menu {
                    ForEach(GamepadGradientType.allCases) { type in
                        Button(type.displayName) {
                            var next = gradient
                            next.type = type
                            gradientFillBinding(for: target, scheme: editingScheme).wrappedValue = next
                        }
                    }
                } label: {
                    HStack(spacing: Geist.Spacing.s2) {
                        Text(gradient.type.displayName)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(height: Geist.Spacing.s10)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .geistInput(size: .medium)

                Button {
                    reverseGradientStops(for: target, scheme: editingScheme)
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .frame(width: 30, height: Geist.Spacing.s10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Button {
                    var next = gradient
                    next.angleDegrees += 45
                    gradientFillBinding(for: target, scheme: editingScheme).wrappedValue = next.normalized
                } label: {
                    Image(systemName: "rotate.right")
                        .frame(width: 30, height: Geist.Spacing.s10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            }

            GamepadFillPreview(shape: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous), fillStyle: .gradient(gradient))
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                HStack {
                    Text("Angle")
                        .geistTypography(.label13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    Spacer()
                    Text("\(Int(gradient.angleDegrees.rounded()))°")
                        .geistTypography(.label13Mono)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                }
                Slider(value: gradientAngleBinding(for: target, scheme: editingScheme), in: 0...360)
            }
            .opacity(gradient.type == .linear ? 1 : 0.42)
            .disabled(gradient.type != .linear)

            HStack {
                Text("Stops")
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Spacer()
                Button {
                    addGradientStop(for: target, scheme: editingScheme)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .regular))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            }

            VStack(spacing: Geist.Spacing.s2) {
                ForEach(gradient.stops.indices, id: \.self) { index in
                    gradientStopRow(index: index, target: target, editingScheme: editingScheme)
                }
            }

            fillPaletteScopeMenu(schemeName: schemeName)

            Button("Use Default \(schemeName) \(target.defaultResetNoun)") {
                clearCustomFill(for: target, scheme: editingScheme)
            }
            .geistButtonStyle(.tertiary, size: .small)
            .disabled(!usesCustomColor)
        }
        .padding(Geist.Spacing.s3)
        .onAppear {
            if case .gradient = selectedFillStyleValue(for: target, scheme: editingScheme) {
                return
            }
            setFillStyle(.gradient(gradient), for: target, scheme: editingScheme)
        }
    }

    private func gradientStopRow(index: Int, target: GamepadFillEditorTarget, editingScheme: ColorScheme) -> some View {
        let gradient = gradientFillBinding(for: target, scheme: editingScheme).wrappedValue.normalized
        let stop = gradient.stops[index]

        return HStack(spacing: Geist.Spacing.s2) {
            GamepadColorValueField(text: gradientStopOffsetTextBinding(for: target, scheme: editingScheme, index: index), placeholder: "0", suffix: "%", width: 64)

            GamepadFillPreview(shape: RoundedRectangle(cornerRadius: 4, style: .continuous), fillStyle: .solid(stop.color))
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

            GamepadColorValueField(text: gradientStopHexBinding(for: target, scheme: editingScheme, index: index), placeholder: "000000")

            GamepadColorValueField(text: gradientStopAlphaTextBinding(for: target, scheme: editingScheme, index: index), placeholder: "100", suffix: "%", width: 82)

            Button {
                removeGradientStop(index: index, for: target, scheme: editingScheme)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .regular))
                    .frame(width: 24, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(gradient.stops.count > 2 ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.gray700, scheme: colorScheme))
            .disabled(gradient.stops.count <= 2)
        }
    }

    private func fillTilePanel(
        for target: GamepadFillEditorTarget,
        editingScheme: ColorScheme,
        schemeName: String,
        usesCustomColor: Bool
    ) -> some View {
        let tile = tileFillBinding(for: target, scheme: editingScheme).wrappedValue.normalized

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            ZStack {
                GamepadFillPreview(shape: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous), fillStyle: .tile(tile))
                    .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                Button {
                    activeFillPopoverTab = .image
                    isFillImageImporterPresented = true
                } label: {
                    Label("Select source...", systemImage: "rectangle.and.cursorarrow")
                        .geistTypography(.label14)
                        .padding(.horizontal, Geist.Spacing.s3)
                        .frame(height: 38)
                        .background(Geist.color(.gray100, scheme: colorScheme).opacity(0.94), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous).stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            }
            .frame(height: 220)

            HStack {
                Text("Tile type")
                    .geistTypography(.label14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Spacer()
                Picker("Tile type", selection: tilePatternBinding(for: target, scheme: editingScheme)) {
                    ForEach(GamepadTilePattern.allCases) { pattern in
                        Image(systemName: pattern.systemImage).tag(pattern)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }

            fillSliderRow(title: "Scale", value: tileScaleBinding(for: target, scheme: editingScheme), range: 0.25...4, percent: true)
            fillSliderRow(title: "Spacing X", value: tileSpacingBinding(for: target, scheme: editingScheme, keyPath: \.spacingX), range: 0...2, percent: true)
            fillSliderRow(title: "Spacing Y", value: tileSpacingBinding(for: target, scheme: editingScheme, keyPath: \.spacingY), range: 0...2, percent: true)

            HStack(alignment: .top, spacing: Geist.Spacing.s3) {
                Text("Alignment")
                    .geistTypography(.label14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .frame(width: 84, alignment: .leading)
                tileAlignmentGrid(target: target, editingScheme: editingScheme)
            }

            fillPaletteScopeMenu(schemeName: schemeName)

            Button("Use Default \(schemeName) \(target.defaultResetNoun)") {
                clearCustomFill(for: target, scheme: editingScheme)
            }
            .geistButtonStyle(.tertiary, size: .small)
            .disabled(!usesCustomColor)
        }
        .padding(Geist.Spacing.s3)
        .onAppear {
            if case .tile = selectedFillStyleValue(for: target, scheme: editingScheme) {
                return
            }
            setFillStyle(.tile(tile), for: target, scheme: editingScheme)
        }
    }

    private func fillImagePanel(
        for target: GamepadFillEditorTarget,
        editingScheme: ColorScheme,
        schemeName: String,
        usesCustomColor: Bool
    ) -> some View {
        let imageFill = imageFillBinding(for: target, scheme: editingScheme).wrappedValue.normalized

        return VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            ZStack {
                GamepadFillPreview(shape: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous), fillStyle: .image(imageFill))
                    .clipShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

                VStack(spacing: Geist.Spacing.s2) {
                    Button("Upload from computer") {
                        isFillImageImporterPresented = true
                    }
                    .geistButtonStyle(.primary, size: .medium)

                    Button {
                        makeGeneratedFillImage(for: target, scheme: editingScheme)
                    } label: {
                        Label("Make an image", systemImage: "photo.badge.plus")
                    }
                    .geistButtonStyle(.secondary, size: .medium)
                }
            }
            .frame(height: 300)

            if let fillImageImportError {
                Text(fillImageImportError)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.red900, scheme: colorScheme))
            }

            Menu {
                ForEach(GamepadImageContentMode.allCases) { mode in
                    Button(mode.displayName) {
                        var next = imageFill
                        next.contentMode = mode
                        imageFillBinding(for: target, scheme: editingScheme).wrappedValue = next
                    }
                }
            } label: {
                HStack {
                    Text(imageFill.contentMode.displayName)
                        .geistTypography(.label14)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .padding(.horizontal, Geist.Spacing.s3)
                .frame(height: Geist.Spacing.s10)
                .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
            .menuStyle(.button)

            fillSliderRow(title: "Exposure", value: imageAdjustmentBinding(for: target, scheme: editingScheme, keyPath: \.exposure), range: -1...1)
            fillSliderRow(title: "Contrast", value: imageAdjustmentBinding(for: target, scheme: editingScheme, keyPath: \.contrast), range: -1...1)
            fillSliderRow(title: "Saturation", value: imageAdjustmentBinding(for: target, scheme: editingScheme, keyPath: \.saturation), range: -1...1)
            fillSliderRow(title: "Temperat...", value: imageAdjustmentBinding(for: target, scheme: editingScheme, keyPath: \.temperature), range: -1...1)
            fillSliderRow(title: "Tint", value: imageAdjustmentBinding(for: target, scheme: editingScheme, keyPath: \.tint), range: -1...1)
            fillSliderRow(title: "Highlights", value: imageAdjustmentBinding(for: target, scheme: editingScheme, keyPath: \.highlights), range: -1...1)
            fillSliderRow(title: "Shadows", value: imageAdjustmentBinding(for: target, scheme: editingScheme, keyPath: \.shadows), range: -1...1)

            fillPaletteScopeMenu(schemeName: schemeName)

            Button("Use Default \(schemeName) \(target.defaultResetNoun)") {
                clearCustomFill(for: target, scheme: editingScheme)
            }
            .geistButtonStyle(.tertiary, size: .small)
            .disabled(!usesCustomColor)
        }
        .padding(Geist.Spacing.s3)
        .onAppear {
            if case .image = selectedFillStyleValue(for: target, scheme: editingScheme) {
                return
            }
            setFillStyle(.image(imageFill), for: target, scheme: editingScheme)
        }
    }

    private func fillPaletteScopeMenu(schemeName: String) -> some View {
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
    }

    private func fillSliderRow(title: String, value: Binding<Double>, range: ClosedRange<Double>, percent: Bool = false) -> some View {
        HStack(spacing: Geist.Spacing.s3) {
            Text(title)
                .geistTypography(.label14)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 84, alignment: .leading)
            Slider(value: value, in: range)
            Text(percent ? "\(Int((value.wrappedValue * 100).rounded()))%" : "\(Int((value.wrappedValue * 100).rounded()))")
                .geistTypography(.label13Mono)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .frame(width: 52, alignment: .trailing)
        }
    }

    private func tileAlignmentGrid(target: GamepadFillEditorTarget, editingScheme: ColorScheme) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 3)
        return LazyVGrid(columns: columns, spacing: 0) {
            ForEach(GamepadTileAlignment.allCases) { alignment in
                Button {
                    var tile = tileFillBinding(for: target, scheme: editingScheme).wrappedValue
                    tile.alignment = alignment
                    tileFillBinding(for: target, scheme: editingScheme).wrappedValue = tile
                } label: {
                    Circle()
                        .fill(tileFillBinding(for: target, scheme: editingScheme).wrappedValue.alignment == alignment ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha600, scheme: colorScheme))
                        .frame(width: 5, height: 5)
                        .frame(width: 44, height: 34)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 132, height: 102)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
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
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Position")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                    inspectorMetricField(title: "X", value: frameMetricBinding(.x), unit: "pt", accessibilityLabel: "X position in points")
                    inspectorMetricField(title: "Y", value: frameMetricBinding(.y), unit: "pt", accessibilityLabel: "Y position in points")
                    inspectorMetricField(title: "Z", value: zIndexBinding(for: selectedControlID), maxFractionDigits: 0, accessibilityLabel: "Z-index from minus 100 to 100")
                }

                Text("X and Y place the component’s top-left corner on the canvas. Z controls stack order from -100 (back) to 100 (front).")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Rotation")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                inspectorMetricField(title: "Rotation", value: rotationDegreesBinding(for: selectedControlID), unit: "°", accessibilityLabel: "Rotation in degrees")

                Text("Rotation uses degrees and turns the component around its center. Enter 0° to keep it upright.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var selectedElementLayoutControls: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Dimensions (pt)")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                    inspectorMetricField(title: "Width", value: frameMetricBinding(.width), unit: "pt", accessibilityLabel: "Width in points")
                    inspectorMetricField(title: "Height", value: frameMetricBinding(.height), unit: "pt", accessibilityLabel: "Height in points")
                }

                Text("Width sets the horizontal size. Height sets the vertical size. Both use canvas points and stay within the phone screen.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
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
            GamepadShapeSegmentedPicker(selection: shapeBinding(for: selectedControlID))

            if shapeValue(for: selectedControlID).usesEditableCornerRadii {
                inspectorMetricField(
                    title: "All",
                    value: uniformCornerRadiusBinding(for: selectedControlID),
                    unit: "pt",
                    maxFractionDigits: 0,
                    accessibilityLabel: "All corner radii in points"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                    ForEach(GamepadCorner.allCases) { corner in
                        metricField(title: corner.shortLabel, value: cornerRadiusBinding(for: selectedControlID, corner: corner), unit: "pt")
                            .accessibilityLabel(corner.accessibilityLabel)
                    }
                }

                Text("Corner values can exceed the current component size; the rendered radius clamps to the component bounds. Drag the purple dot to adjust all corners visually.")
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
            valueSlider(
                title: "Shadow",
                value: shadowStrengthBinding(for: selectedControlID),
                range: Double(GamepadButtonCustomization.minimumShadowStrength)...Double(GamepadButtonCustomization.maximumShadowStrength),
                valueText: "\(Int((shadowStrengthValue(for: selectedControlID) * 100).rounded()))%"
            )

            Divider()

            Text("Text & material")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                colorTextField(title: "Text", value: visualStyleColorHexBinding(for: selectedControlID, keyPath: \.foregroundColor), unit: nil)
                colorTextField(title: "Inner", value: visualStyleColorHexBinding(for: selectedControlID, keyPath: \.innerShadowColor), unit: nil)
                colorTextField(title: "Highlight", value: visualStyleColorHexBinding(for: selectedControlID, keyPath: \.highlightColor), unit: nil)
                colorTextField(title: "Bevel top", value: visualStyleColorHexBinding(for: selectedControlID, keyPath: \.bevelHighlightColor), unit: nil)
                colorTextField(title: "Bevel bottom", value: visualStyleColorHexBinding(for: selectedControlID, keyPath: \.bevelShadowColor), unit: nil)
            }

            valueSlider(
                title: "Inner",
                value: visualStyleNumberBinding(for: selectedControlID, keyPath: \.innerShadowRadius),
                range: 0...32,
                valueText: "\(Int((normalVisualStyleValue(for: selectedControlID).innerShadowRadius ?? 0).rounded())) pt"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                inspectorMetricField(title: "Inner X", value: visualStyleNumberBinding(for: selectedControlID, keyPath: \.innerShadowX), unit: "pt", maxFractionDigits: 0, accessibilityLabel: "Inner shadow X offset")
                inspectorMetricField(title: "Inner Y", value: visualStyleNumberBinding(for: selectedControlID, keyPath: \.innerShadowY), unit: "pt", maxFractionDigits: 0, accessibilityLabel: "Inner shadow Y offset")
            }

            valueSlider(
                title: "Hi Op",
                value: visualStyleNumberBinding(for: selectedControlID, keyPath: \.highlightOpacity),
                range: 0...1,
                valueText: "\(Int(((normalVisualStyleValue(for: selectedControlID).highlightOpacity ?? 0) * 100).rounded()))%"
            )
            valueSlider(
                title: "Blur",
                value: visualStyleNumberBinding(for: selectedControlID, keyPath: \.highlightRadius),
                range: 0...40,
                valueText: "\(Int((normalVisualStyleValue(for: selectedControlID).highlightRadius ?? 0).rounded())) pt"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: Geist.Spacing.s2) {
                inspectorMetricField(title: "Hi X", value: visualStyleNumberBinding(for: selectedControlID, keyPath: \.highlightX), unit: "pt", maxFractionDigits: 0, accessibilityLabel: "Highlight X offset")
                inspectorMetricField(title: "Hi Y", value: visualStyleNumberBinding(for: selectedControlID, keyPath: \.highlightY), unit: "pt", maxFractionDigits: 0, accessibilityLabel: "Highlight Y offset")
            }

            valueSlider(
                title: "Bevel",
                value: visualStyleNumberBinding(for: selectedControlID, keyPath: \.bevelWidth),
                range: 0...12,
                valueText: String(format: "%.1f pt", Double(normalVisualStyleValue(for: selectedControlID).bevelWidth ?? 0))
            )

            HStack(spacing: Geist.Spacing.s2) {
                Button("Soft White") {
                    applyMaterial(.softWhiteRaised(), to: selectedControlID)
                }
                .geistButtonStyle(.secondary, size: .small)
                Button("Inset") {
                    applyMaterial(.softWhiteInset(), to: selectedControlID)
                }
                .geistButtonStyle(.secondary, size: .small)
                Button("Plate") {
                    applyMaterial(.softWhitePlate(), to: selectedControlID)
                }
                .geistButtonStyle(.secondary, size: .small)
            }

            Button("Clear material effects") {
                clearMaterialEffects(for: selectedControlID)
            }
            .geistButtonStyle(.tertiary, size: .small)

            Text("These controls add label color, inset shadows, highlights, and bevel strokes for soft/neumorphic controller surfaces.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controlSelectionPicker: some View {
        HStack(spacing: Geist.Spacing.s3) {
            Text("Element")
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            Spacer()
            GeistMenuPicker(title: "Element", options: controlSelectionOptions, selection: $selectedControlID) { identity in
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
        editorLayerModel.controlSelectionOptions
    }

    private func controlSelectionOptions(for customization: GamepadCustomization) -> [GamepadControlIdentity] {
        let systemItems = GamepadSystemControl.allCases.map { GamepadControlIdentity.system($0) }
        let controlBarItems = customization.normalized.controlBarItems.map { GamepadControlIdentity.controlBarItem($0) }
        let builtinItems = shouldListBuiltInComponents(for: customization)
            ? GameButton.builtInControls.map { GamepadControlIdentity.builtin($0) }
            : []
        return systemItems + controlBarItems + builtinItems + customization.customButtons.map { GamepadControlIdentity.custom($0.id) }
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
        editorLayerModel.componentItems
    }

    private var normalizedLayerGroups: [GamepadLayerGroup] {
        editorLayerModel.normalizedLayerGroups
    }

    private var layerGroupItems: [GamepadEditorLayerGroupItem] {
        editorLayerModel.layerGroupItems
    }

    private var layerListItems: [GamepadEditorLayerListItem] {
        editorLayerModel.layerListItems
    }

    private var layerSelectionControlIdentities: [GamepadControlIdentity] {
        editorLayerModel.layerSelectionControlIdentities
    }

    private var sidebarSelectionClickModifiers: (command: Bool, shift: Bool) {
#if os(macOS)
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return (flags.contains(.command), flags.contains(.shift))
#else
        return (false, false)
#endif
    }

    private func handleSidebarComponentClick(_ identity: GamepadControlIdentity) {
        let modifiers = sidebarSelectionClickModifiers
        if modifiers.shift {
            selectLayerRange(through: [identity], preferredPrimary: identity) {
                selectComponent(identity)
            }
        } else if modifiers.command {
            toggleLayerSelection([identity], preferredPrimary: identity)
        } else {
            selectComponent(identity)
        }
    }

    private func handleSidebarGroupClick(_ group: GamepadEditorLayerGroupItem) {
        let modifiers = sidebarSelectionClickModifiers
        if modifiers.shift {
            selectLayerRange(through: group.childIdentitySet, preferredPrimary: group.childIdentities.first ?? selectedControlID) {
                selectLayerGroup(group)
            }
        } else if modifiers.command {
            toggleLayerSelection(group.childIdentitySet, preferredPrimary: group.childIdentities.first ?? selectedControlID)
            expandedLayerGroupIDs.insert(group.id)
        } else {
            selectLayerGroup(group)
        }
    }

    private func toggleLayerSelection(_ identities: Set<GamepadControlIdentity>, preferredPrimary: GamepadControlIdentity) {
        let validIdentities = Set(layerSelectionControlIdentities)
        let targetIdentities = identities.intersection(validIdentities)
        guard !targetIdentities.isEmpty else { return }

        var nextSelection = isControlSelectionActive ? selectedControlIDs.intersection(validIdentities) : []
        if targetIdentities.isSubset(of: nextSelection) {
            nextSelection.subtract(targetIdentities)
        } else {
            nextSelection.formUnion(targetIdentities)
        }

        layerSelectionAnchorID = preferredPrimary
        selectedControlIDs = nextSelection
        isControlSelectionActive = !nextSelection.isEmpty
        guard !nextSelection.isEmpty else { return }

        if nextSelection.contains(preferredPrimary) {
            selectedControlID = preferredPrimary
        } else if !nextSelection.contains(selectedControlID), let firstSelected = firstLayerSelectionIdentity(in: nextSelection) {
            selectedControlID = firstSelected
        }
    }

    private func selectLayerRange(
        through targetIdentities: Set<GamepadControlIdentity>,
        preferredPrimary: GamepadControlIdentity,
        fallback: () -> Void
    ) {
        let order = layerSelectionControlIdentities
        guard !order.isEmpty,
              let anchor = layerSelectionAnchorID ?? (isControlSelectionActive ? selectedControlID : nil),
              let anchorIndex = order.firstIndex(of: anchor)
        else {
            fallback()
            return
        }

        let targetIndices = targetIdentities.compactMap { order.firstIndex(of: $0) }
        guard let firstTargetIndex = targetIndices.min(),
              let lastTargetIndex = targetIndices.max()
        else {
            fallback()
            return
        }

        let lowerBound: Int
        let upperBound: Int
        if anchorIndex < firstTargetIndex {
            lowerBound = anchorIndex
            upperBound = lastTargetIndex
        } else if anchorIndex > lastTargetIndex {
            lowerBound = firstTargetIndex
            upperBound = anchorIndex
        } else {
            lowerBound = firstTargetIndex
            upperBound = lastTargetIndex
        }

        let rangeSelection = Set(order[lowerBound...upperBound])
        guard !rangeSelection.isEmpty else {
            fallback()
            return
        }

        selectedControlIDs = rangeSelection
        selectedControlID = rangeSelection.contains(preferredPrimary) ? preferredPrimary : (order[upperBound])
        isControlSelectionActive = true
    }

    private func firstLayerSelectionIdentity(in selection: Set<GamepadControlIdentity>) -> GamepadControlIdentity? {
        layerSelectionControlIdentities.first { selection.contains($0) }
    }

    private var selectedLayerGroup: GamepadLayerGroup? {
        guard isControlSelectionActive, selectedControlIDs.count > 1 else { return nil }
        return normalizedLayerGroups.first { group in
            Set(group.children) == selectedControlIDs
        }
    }

    private var canGroupSelectedControls: Bool {
        isControlSelectionActive
            && selectedControlIDs.count > 1
            && selectedLayerGroup == nil
            && selectedControlIDs.allSatisfy { identity in
                controlSelectionOptions.contains(identity) && {
                    if case .controlBarItem = identity { return false }
                    return true
                }()
            }
    }

    private func isLayerGroupExpanded(_ groupID: UUID) -> Bool {
        expandedLayerGroupIDs.contains(groupID) || isLayerGroupSelected(groupID: groupID)
    }

    private func toggleLayerGroupExpansion(_ groupID: UUID) {
        if expandedLayerGroupIDs.contains(groupID) {
            expandedLayerGroupIDs.remove(groupID)
        } else {
            expandedLayerGroupIDs.insert(groupID)
        }
    }

    private func isLayerGroupSelected(_ group: GamepadEditorLayerGroupItem) -> Bool {
        isControlSelectionActive && selectedControlIDs == group.childIdentitySet
    }

    private func isLayerGroupSelected(groupID: UUID) -> Bool {
        guard let group = layerGroupItems.first(where: { $0.id == groupID }) else { return false }
        return isLayerGroupSelected(group)
    }

    private func selectLayerGroup(_ group: GamepadEditorLayerGroupItem) {
        guard let primary = group.childIdentities.first else { return }
        selectedControlID = primary
        selectedControlIDs = group.childIdentitySet
        isControlSelectionActive = true
        layerSelectionAnchorID = primary
        expandedLayerGroupIDs.insert(group.id)
    }

    private func groupedSelectionIDs(for identity: GamepadControlIdentity) -> Set<GamepadControlIdentity>? {
        guard let group = layerGroupItems.first(where: { $0.childIdentitySet.contains(identity) }) else { return nil }
        expandedLayerGroupIDs.insert(group.id)
        return group.childIdentitySet
    }

    private func groupSelectedControls() {
        guard canGroupSelectedControls else { return }
        let selectedItems = componentListItems.filter { selectedControlIDs.contains($0.identity) }
        let children = selectedItems.map(\.identity)
        guard children.count > 1 else { return }

        let nextIndex = (normalizedLayerGroups.count + 1)
        let group = GamepadLayerGroup(name: "Group \(nextIndex)", children: children)
        let childSet = Set(children)
        update(actionName: "Group Components") { next in
            var metadata = next.designMetadata ?? .empty
            for index in metadata.groups.indices {
                metadata.groups[index].children.removeAll { childSet.contains($0) }
            }
            metadata.groups.removeAll { $0.children.isEmpty }
            metadata.groups.append(group)
            next.moveLayers(childSet, to: insertionIndexForGroupedSelection(children: children, in: next.orderedControlIdentitiesForDesign))
            metadata.layerOrder = next.orderedControlIdentitiesForDesign
            next.designMetadata = metadata.normalized(availableControls: next.allControlIdentitiesForDesign)
        }
        expandedLayerGroupIDs.insert(group.id)
    }

    private func insertionIndexForGroupedSelection(children: [GamepadControlIdentity], in order: [GamepadControlIdentity]) -> Int {
        let childSet = Set(children)
        return order.indices.first(where: { childSet.contains(order[$0]) }) ?? order.count
    }

    private func ungroupLayerGroup(_ groupID: UUID) {
        update(actionName: "Ungroup Components") { next in
            var metadata = next.designMetadata ?? .empty
            metadata.groups.removeAll { $0.id == groupID }
            next.designMetadata = metadata.normalized(availableControls: next.allControlIdentitiesForDesign)
        }
        expandedLayerGroupIDs.remove(groupID)
    }

    private func bringLayerGroupForward(_ group: GamepadEditorLayerGroupItem) {
        update(actionName: "Bring Group Forward") { $0.bringLayersForward(group.childIdentitySet) }
        selectLayerGroup(group)
    }

    private func sendLayerGroupBackward(_ group: GamepadEditorLayerGroupItem) {
        update(actionName: "Send Group Backward") { $0.sendLayersBackward(group.childIdentitySet) }
        selectLayerGroup(group)
    }

    private func setLayerGroupHidden(_ isHidden: Bool, groupID: UUID) {
        update(actionName: isHidden ? "Hide Group" : "Show Group") { next in
            var metadata = next.designMetadata ?? .empty
            guard let index = metadata.groups.firstIndex(where: { $0.id == groupID }) else { return }
            let children = metadata.groups[index].children
            metadata.groups[index].isHidden = isHidden
            next.designMetadata = metadata.normalized(availableControls: next.allControlIdentitiesForDesign)
            for child in children {
                setComponentHidden(isHidden, for: child, in: &next)
            }
        }
    }

    private func setLayerGroupLocked(_ isLocked: Bool, groupID: UUID) {
        update(actionName: isLocked ? "Lock Group" : "Unlock Group") { next in
            var metadata = next.designMetadata ?? .empty
            guard let index = metadata.groups.firstIndex(where: { $0.id == groupID }) else { return }
            let children = metadata.groups[index].children
            metadata.groups[index].isLocked = isLocked
            next.designMetadata = metadata.normalized(availableControls: next.allControlIdentitiesForDesign)
            for child in children {
                setComponentLocationLocked(isLocked, for: child, in: &next)
            }
        }
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
            return visualLabel(for: button)
        case .custom(let id):
            guard let customButton = customButton(id: id)?.normalized else { return "Button" }
            return customButton.visualLabel(fallback: customButtonFallbackLabel(for: customButton))
        case .system(let control):
            return control.displayName
        case .controlBarItem(let item):
            return item.displayName
        }
    }

    @ViewBuilder
    private func customButtonControls(id: UUID) -> some View {
        if customButton(id: id)?.normalized.isJoystick == true {
            joystickControls(id: id)
        } else if customButton(id: id)?.normalized.isDecoration == true {
            decorationControls(id: id)
        } else if customButton(id: id)?.normalized.isTrigger == true {
            triggerControls(id: id)
        } else if customButton(id: id)?.normalized.isTrackpad == true {
            trackpadControls(id: id)
        } else {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Label")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))

                let fallbackLabel = customButton(id: id).map { customButtonFallbackLabel(for: $0.normalized) } ?? "Button"
                TextField(fallbackLabel, text: customLabelBinding(id: id))
                    .geistInput(size: .small)

                Text("Use Output to assign the keyboard shortcut or virtual controller button this element sends.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func decorationControls(id: UUID) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            Text("Decoration label")
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            TextField("Decoration", text: customLabelBinding(id: id))
                .geistInput(size: .small)
            Text("Decoration layers render on the keypad but never send keyboard, mouse, or gamepad input. Use them for shells, rings, plates, highlights, and visual grouping behind controls.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func joystickControls(id: UUID) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            TextField("Joystick", text: customLabelBinding(id: id))
                .geistInput(size: .small)

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                HStack(spacing: Geist.Spacing.s3) {
                    Text("Look")
                        .geistTypography(.label13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    Spacer()
                    GeistMenuPicker(title: "Joystick look", options: GamepadJoystickVisualStyle.allCases, selection: joystickVisualStyleBinding(id: id)) { style in
                        style.displayName
                    }
                }
                Text(joystickVisualStyleValue(id: id).description)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                HStack(spacing: Geist.Spacing.s3) {
                    Text("Analog")
                        .geistTypography(.label13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    Spacer()
                    GeistMenuPicker(title: "Analog stick", options: GamepadJoystickAnalogTarget.allCases, selection: joystickAnalogTargetBinding(id: id)) { target in
                        target.displayName
                    }
                }
                GeistCheckboxToggle(title: "Also send directional outputs", isOn: joystickSendsDigitalDirectionsBinding(id: id))
                valueSlider(
                    title: "Dead zone",
                    value: joystickDeadZoneBinding(id: id),
                    range: 0...0.85,
                    valueText: "\(Int((joystickOutputSettingsValue(id: id).deadZone * 100).rounded()))%"
                )
                valueSlider(
                    title: "Sensitivity",
                    value: joystickSensitivityBinding(id: id),
                    range: 0.2...3.0,
                    valueText: String(format: "%.1fx", Double(joystickOutputSettingsValue(id: id).sensitivity))
                )
                GeistCheckboxToggle(title: "Invert X", isOn: joystickInvertXBinding(id: id))
                GeistCheckboxToggle(title: "Invert Y", isOn: joystickInvertYBinding(id: id))
                GeistCheckboxToggle(title: "Snap to cardinal directions", isOn: joystickSnapToCardinalBinding(id: id))
            }

            Text("Joysticks can send real analog stick values, directional outputs, or both. Neutral is sent automatically when your thumb lifts.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            if joystickOutputSettingsValue(id: id).sendsDigitalDirections,
               let selectedElementOutputContent {
                VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                    ForEach(GamepadJoystickDirection.allCases) { direction in
                        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                            Text("\(direction.displayName) output")
                                .geistTypography(.label13)
                                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                            selectedElementOutputContent(
                                KeypadElementInputID(
                                    elementID: id,
                                    part: KeypadElementInputPart(direction: direction)
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    private func triggerControls(id: UUID) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            TextField(triggerSettingsValue(id: id).target.shortName, text: customLabelBinding(id: id))
                .geistInput(size: .small)

            HStack(spacing: Geist.Spacing.s3) {
                Text("Trigger")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Spacer()
                GeistMenuPicker(title: "Trigger target", options: VirtualGamepadTrigger.allCases, selection: triggerTargetBinding(id: id)) { target in
                    target.displayName
                }
            }

            HStack(spacing: Geist.Spacing.s3) {
                Text("Orientation")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Spacer()
                GeistMenuPicker(title: "Trigger orientation", options: GamepadTriggerOrientation.allCases, selection: triggerOrientationBinding(id: id)) { orientation in
                    orientation.displayName
                }
            }

            valueSlider(
                title: "Dead zone",
                value: triggerDeadZoneBinding(id: id),
                range: 0...0.85,
                valueText: "\(Int((triggerSettingsValue(id: id).deadZone * 100).rounded()))%"
            )

            valueSlider(
                title: "Sensitivity",
                value: triggerSensitivityBinding(id: id),
                range: 0.2...3.0,
                valueText: String(format: "%.1fx", Double(triggerSettingsValue(id: id).sensitivity))
            )

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                GeistCheckboxToggle(title: "Also send a digital output", isOn: triggerSendsDigitalBinding(id: id))
                if triggerSettingsValue(id: id).sendsDigitalButton {
                    valueSlider(
                        title: "Threshold",
                        value: triggerDigitalThresholdBinding(id: id),
                        range: 0.01...1.0,
                        valueText: "\(Int((triggerSettingsValue(id: id).digitalThreshold * 100).rounded()))%"
                    )
                    if let selectedElementOutputContent {
                        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                            Text("Digital output")
                                .geistTypography(.label13)
                                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                            selectedElementOutputContent(
                                KeypadElementInputID(elementID: id, part: .triggerDigital)
                            )
                        }
                    }
                }
            }

            Text("Triggers send real analog LT/RT values to the Mac virtual controller. Optional digital output fires when the value crosses the threshold.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func trackpadControls(id: UUID) -> some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            TextField("Trackpad", text: customLabelBinding(id: id))
                .geistInput(size: .small)

            valueSlider(
                title: "Cursor",
                value: trackpadSensitivityBinding(id: id),
                range: Double(GamepadTrackpadSettings.minimumSensitivity)...Double(GamepadTrackpadSettings.maximumSensitivity),
                valueText: String(format: "%.1fx", Double(trackpadSettingsValue(id: id).sensitivity))
            )

            valueSlider(
                title: "Scroll",
                value: trackpadScrollSensitivityBinding(id: id),
                range: Double(GamepadTrackpadSettings.minimumScrollSensitivity)...Double(GamepadTrackpadSettings.maximumScrollSensitivity),
                valueText: String(format: "%.1fx", Double(trackpadSettingsValue(id: id).scrollSensitivity))
            )

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                GeistCheckboxToggle(title: "Tap to click", isOn: trackpadTapToClickBinding(id: id))
                GeistCheckboxToggle(title: "Two-finger scroll", isOn: trackpadTwoFingerScrollBinding(id: id))
                GeistCheckboxToggle(title: "Natural scrolling", isOn: trackpadNaturalScrollingBinding(id: id))
            }

            Text("Trackpads send relative cursor movement to the Mac. Tap for left click, two-finger tap for right click, and drag two fingers to scroll.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
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
            draftConfigurationSidebarWidth ?? CGFloat(configurationSidebarWidthValue),
            lower: Self.configurationSidebarMinWidth,
            upper: Self.configurationSidebarMaxWidth
        )
    }

    private var inspectorSidebarWidth: CGFloat {
        Self.clamp(
            draftInspectorSidebarWidth ?? CGFloat(inspectorSidebarWidthValue),
            lower: Self.inspectorSidebarMinWidth,
            upper: Self.inspectorSidebarMaxWidth
        )
    }

    private var effectiveCanvasZoom: CGFloat {
        Self.clamp(
            draftCanvasZoom ?? CGFloat(canvasZoomValue),
            lower: Self.canvasZoomMin,
            upper: Self.canvasZoomMax
        )
    }

    private var canvasZoomPercentageText: String {
        "\(Int((effectiveCanvasZoom * 100).rounded()))%"
    }

    private func toggleConfigurationSidebarVisibility() {
        let animation: Animation? = accessibilityReduceMotion ? nil : .easeInOut(duration: 0.18)
        withAnimation(animation) {
            isConfigurationSidebarVisible.toggle()
            configurationSidebarDragStart = nil
            draftConfigurationSidebarWidth = nil
        }
    }

    private func toggleInspectorSidebarVisibility() {
        let animation: Animation? = accessibilityReduceMotion ? nil : .easeInOut(duration: 0.18)
        withAnimation(animation) {
            isInspectorSidebarVisible.toggle()
            inspectorSidebarDragStart = nil
            draftInspectorSidebarWidth = nil
        }
    }

    private func effectiveSidebarWidths(totalWidth: CGFloat) -> (configuration: CGFloat, inspector: CGFloat) {
        var configurationWidth = configurationSidebarWidth
        var inspectorWidth = inspectorSidebarWidth
        let visibleHandleCount = (isConfigurationSidebarVisible ? 1 : 0) + (isInspectorSidebarVisible ? 1 : 0)
        let minimumVisibleSidebarWidth = (isConfigurationSidebarVisible ? Self.configurationSidebarMinWidth : 0)
            + (isInspectorSidebarVisible ? Self.inspectorSidebarMinWidth : 0)
        let availableSidebarWidth = max(
            minimumVisibleSidebarWidth,
            totalWidth - (Self.resizeHandleWidth * CGFloat(visibleHandleCount)) - Self.minimumCanvasColumnWidth
        )

        let currentSidebarWidth = (isConfigurationSidebarVisible ? configurationWidth : 0)
            + (isInspectorSidebarVisible ? inspectorWidth : 0)
        if currentSidebarWidth > availableSidebarWidth {
            let overflow = currentSidebarWidth - availableSidebarWidth
            let configurationFlex = isConfigurationSidebarVisible ? max(0, configurationWidth - Self.configurationSidebarMinWidth) : 0
            let inspectorFlex = isInspectorSidebarVisible ? max(0, inspectorWidth - Self.inspectorSidebarMinWidth) : 0
            let totalFlex = configurationFlex + inspectorFlex

            if totalFlex > 0 {
                if isConfigurationSidebarVisible {
                    configurationWidth -= overflow * (configurationFlex / totalFlex)
                }
                if isInspectorSidebarVisible {
                    inspectorWidth -= overflow * (inspectorFlex / totalFlex)
                }
            } else if isConfigurationSidebarVisible && !isInspectorSidebarVisible {
                configurationWidth = availableSidebarWidth
            } else if isInspectorSidebarVisible && !isConfigurationSidebarVisible {
                inspectorWidth = availableSidebarWidth
            }
        }

        let configurationMaxWidth = isConfigurationSidebarVisible ? min(Self.configurationSidebarMaxWidth, max(Self.configurationSidebarMinWidth, availableSidebarWidth)) : Self.configurationSidebarMaxWidth
        let inspectorMaxWidth = isInspectorSidebarVisible ? min(Self.inspectorSidebarMaxWidth, max(Self.inspectorSidebarMinWidth, availableSidebarWidth)) : Self.inspectorSidebarMaxWidth
        configurationWidth = Self.clamp(configurationWidth, lower: Self.configurationSidebarMinWidth, upper: configurationMaxWidth)
        inspectorWidth = Self.clamp(inspectorWidth, lower: Self.inspectorSidebarMinWidth, upper: inspectorMaxWidth)

        return (configurationWidth, inspectorWidth)
    }

    private func resizeConfigurationSidebar(with value: DragGesture.Value, totalWidth: CGFloat) {
        let currentWidths = effectiveSidebarWidths(totalWidth: totalWidth)
        if configurationSidebarDragStart == nil {
            configurationSidebarDragStart = currentWidths.configuration
        }

        let reservedInspectorWidth = isInspectorSidebarVisible ? currentWidths.inspector : 0
        let visibleHandleCount = 1 + (isInspectorSidebarVisible ? 1 : 0)
        let maxWidth = max(
            Self.configurationSidebarMinWidth,
            min(
                Self.configurationSidebarMaxWidth,
                totalWidth - reservedInspectorWidth - (Self.resizeHandleWidth * CGFloat(visibleHandleCount)) - Self.minimumCanvasColumnWidth
            )
        )
        let nextWidth = (configurationSidebarDragStart ?? currentWidths.configuration) + value.translation.width
        draftConfigurationSidebarWidth = Self.clamp(nextWidth, lower: Self.configurationSidebarMinWidth, upper: maxWidth)
    }

    private func commitConfigurationSidebarWidthDraft() {
        guard let draftConfigurationSidebarWidth else { return }
        configurationSidebarWidthValue = Double(draftConfigurationSidebarWidth)
        self.draftConfigurationSidebarWidth = nil
    }

    private func resizeInspectorSidebar(with value: DragGesture.Value, totalWidth: CGFloat) {
        let currentWidths = effectiveSidebarWidths(totalWidth: totalWidth)
        if inspectorSidebarDragStart == nil {
            inspectorSidebarDragStart = currentWidths.inspector
        }

        let reservedConfigurationWidth = isConfigurationSidebarVisible ? currentWidths.configuration : 0
        let visibleHandleCount = 1 + (isConfigurationSidebarVisible ? 1 : 0)
        let maxWidth = max(
            Self.inspectorSidebarMinWidth,
            min(
                Self.inspectorSidebarMaxWidth,
                totalWidth - reservedConfigurationWidth - (Self.resizeHandleWidth * CGFloat(visibleHandleCount)) - Self.minimumCanvasColumnWidth
            )
        )
        let nextWidth = (inspectorSidebarDragStart ?? currentWidths.inspector) - value.translation.width
        draftInspectorSidebarWidth = Self.clamp(nextWidth, lower: Self.inspectorSidebarMinWidth, upper: maxWidth)
    }

    private func commitInspectorSidebarWidthDraft() {
        guard let draftInspectorSidebarWidth else { return }
        inspectorSidebarWidthValue = Double(draftInspectorSidebarWidth)
        self.draftInspectorSidebarWidth = nil
    }

    private func setCanvasZoom(_ zoom: CGFloat) {
        draftCanvasZoom = Self.clamp(zoom, lower: Self.canvasZoomMin, upper: Self.canvasZoomMax)
    }

    private func commitCanvasZoomDraft() {
        guard let draftCanvasZoom else { return }
        canvasZoomValue = Double(draftCanvasZoom)
        self.draftCanvasZoom = nil
    }

    private func setDeviceFrame(_ frame: GamepadEditorDeviceFrame) {
        let animatesOrientationChange = frame.orientation != activeDeviceFrame.orientation
        let applyFrameChange = {
            didChooseDeviceFrameManually = true
            deviceFrameRawValue = frame.id
            if frame.orientation != selectedProfileOrientation {
                switchSelectedProfileOrientation(to: frame.orientation, deviceFrame: frame)
            } else {
                update { $0.deviceCanvas = GamepadDeviceCanvas(frameID: frame.id) }
                noteCanvasLayoutSize(width: frame.screenRect.width, height: frame.screenRect.height)
            }
        }

        if animatesOrientationChange {
            withAnimation(deviceFrameAnimation) {
                applyFrameChange()
                applyDeviceFrameMotionKick(toward: frame.orientation)
            }
            settleDeviceFrameMotion(after: Self.deviceFrameMotionSettleDelay)
        } else {
            applyFrameChange()
        }
    }

    private func applyDeviceFrameMotionKick(toward orientation: GamepadEditorDeviceOrientation) {
        guard !accessibilityReduceMotion else {
            deviceFrameMotionRotationDegrees = 0
            deviceFrameMotionOffset = .zero
            return
        }

        let direction: CGFloat = orientation == .landscape ? 1 : -1
        deviceFrameMotionRotationDegrees = Double(direction * -4)
        deviceFrameMotionOffset = CGSize(width: direction * 10, height: orientation == .landscape ? -6 : 6)
    }

    private func settleDeviceFrameMotion(after delay: TimeInterval = 0) {
        guard !accessibilityReduceMotion else { return }
        let animation = deviceFrameAnimation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(animation) {
                deviceFrameMotionRotationDegrees = 0
                deviceFrameMotionOffset = .zero
            }
        }
    }

    private func applyConnectedDeviceFrameIfAvailable() {
        guard !didChooseDeviceFrameManually,
              customization.deviceCanvas.normalized == GamepadDeviceCanvas.defaultValue,
              let connectedDeviceFrame,
              connectedDeviceFrame.id != activeDeviceFrame.id
        else { return }

        deviceFrameRawValue = connectedDeviceFrame.id
        if connectedDeviceFrame.orientation != selectedProfileOrientation {
            switchSelectedProfileOrientation(to: connectedDeviceFrame.orientation, deviceFrame: connectedDeviceFrame)
        } else {
            update(registersUndo: false) { $0.deviceCanvas = GamepadDeviceCanvas(frameID: connectedDeviceFrame.id) }
            noteCanvasLayoutSize(width: connectedDeviceFrame.screenRect.width, height: connectedDeviceFrame.screenRect.height)
        }
    }

    private func switchSelectedProfileOrientation(to orientation: GamepadEditorDeviceOrientation, deviceFrame frame: GamepadEditorDeviceFrame) {
        guard let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else {
            selectedProfileOrientation = orientation
            var next = customization
            next.deviceCanvas = GamepadDeviceCanvas(frameID: frame.id)
            applyCustomization(next)
            noteCanvasLayoutSize(width: frame.screenRect.width, height: frame.screenRect.height)
            return
        }

        var profile = profiles[index]
        profile.setCustomization(customization, for: selectedProfileOrientation)

        var nextCustomization = profile.hasCustomizationVariant(for: orientation)
            ? profile.customization(for: orientation)
            : customization.normalized
        nextCustomization.deviceCanvas = GamepadDeviceCanvas(frameID: frame.id)
        profile.setCustomization(nextCustomization, for: orientation)
        profiles[index] = profile.normalized
        selectedProfileOrientation = orientation
        applyCustomization(nextCustomization)
        persistProfiles()
        noteCanvasLayoutSize(width: frame.screenRect.width, height: frame.screenRect.height)
    }

    private func applySelectedProfileCustomizationForCurrentOrientation() {
        guard let profile = selectedProfile else { return }
        let orientation = customization.deviceCanvas.editorDeviceFrame.orientation
        selectedProfileOrientation = orientation
        let orientedCustomization = profile.customization(for: orientation)
        if orientedCustomization != customization.normalized {
            applyCustomization(orientedCustomization)
        }
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
        if selectedControlIsEditable, let selectedLayerGroup {
            return "Group: \(selectedLayerGroup.name)"
        }
        if selectedControlIsEditable, selectedControlIDs.count > 1 {
            return "\(selectedControlIDs.count) components selected"
        }

        return selectedControlIsEditable ? selectedControlTitle : "Keypad: \(selectedProfile?.name ?? "Current Setup")"
    }

    private var selectedControlTitle: String {
        switch selectedControlID {
        case .builtin(let button):
            return "Button: \(visualLabel(for: button))"
        case .custom(let id):
            guard let customButton = customButton(id: id)?.normalized else { return "Button" }
            let kindLabel = customControlKindLabel(for: customButton)
            let fallback = customButtonFallbackLabel(for: customButton)
            return "\(kindLabel): \(customButton.visualLabel(fallback: fallback))"
        case .system(let control):
            return control.displayName
        case .controlBarItem(let item):
            return "Control Bar: \(item.shortName)"
        }
    }

    private func customControlKindLabel(for customButton: GamepadCustomButton) -> String {
        if customButton.isJoystick { return "Joystick" }
        if customButton.isTrigger { return "Trigger" }
        if customButton.isTrackpad { return "Trackpad" }
        if customButton.isDecoration { return "Decoration" }
        return "Button"
    }

    private func customButtonFallbackLabel(for customButton: GamepadCustomButton) -> String {
        if customButton.isJoystick { return "Joystick" }
        if customButton.isTrigger { return (customButton.triggerSettings ?? .defaultValue).normalized.target.shortName }
        if customButton.isTrackpad { return "Trackpad" }
        if customButton.isDecoration { return "Decoration" }
        return "Button"
    }

    private func deleteTitle(for customButton: GamepadCustomButton) -> String {
        "Delete \(customControlKindLabel(for: customButton))"
    }

    private var selectedPrimaryElementInputID: KeypadElementInputID? {
        if case .custom(let id) = selectedControlID,
           customButton(id: id)?.normalized.isDecoration == true {
            return nil
        }
        return customization.elementID(for: selectedControlID).map { KeypadElementInputID(elementID: $0, part: .primary) }
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

    private func syncExternalCustomizationState(_ newCustomization: GamepadCustomization) {
        let normalized = newCustomization.normalized
        guard !normalized.hasSamePresentation(as: customization) else { return }
        pendingExternalCommitWorkItem?.cancel()
        pendingExternalCommitWorkItem = nil
        hasPendingExternalEditorCommit = false
        setEditorCustomization(normalized)
        reconcileSelection(in: normalized)
        syncSelectedProfile(with: normalized, persistsImmediately: false)
    }

    private func scheduleExternalEditorCommit(after delay: TimeInterval = Self.externalCommitDebounceDelay) {
        hasPendingExternalEditorCommit = true
        pendingExternalCommitWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            commitEditorChangesExternally()
        }
        pendingExternalCommitWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func commitPendingEditorChanges() {
        pendingExternalCommitWorkItem?.cancel()
        pendingExternalCommitWorkItem = nil
        commitEditorChangesExternally()
    }

    private func commitEditorChangesExternally() {
        guard hasPendingExternalEditorCommit else { return }
        hasPendingExternalEditorCommit = false
        let normalized = customization.normalized
        syncSelectedProfile(with: normalized, persistsImmediately: false)
        persistProfiles()

        if onProfilesChanged == nil,
           !normalized.hasSamePresentation(as: externalCustomization) {
            externalCustomization = normalized
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<GamepadCustomization, Value>) -> Binding<Value> {
        Binding(
            get: { customization[keyPath: keyPath] },
            set: { newValue in
                update { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var deviceOrientationBinding: Binding<GamepadEditorDeviceOrientation> {
        Binding(
            get: { activeDeviceFrame.orientation },
            set: { orientation in
                let frame = activeDeviceFrame
                if frame.spec.id.hasPrefix(GamepadEditorDeviceCatalog.customFrameIDPrefix) {
                    setCustomDeviceCanvas(width: frame.screenRect.width, height: frame.screenRect.height, orientation: orientation)
                } else {
                    setDeviceFrame(GamepadEditorDeviceFrame(spec: frame.spec, orientation: orientation))
                }
            }
        )
    }

    private var deviceCanvasWidthBinding: Binding<Double> {
        Binding(
            get: { Double(activeDeviceFrame.screenRect.width) },
            set: { width in
                setCustomDeviceCanvas(width: CGFloat(width), height: activeDeviceFrame.screenRect.height, orientation: activeDeviceFrame.orientation)
            }
        )
    }

    private var deviceCanvasHeightBinding: Binding<Double> {
        Binding(
            get: { Double(activeDeviceFrame.screenRect.height) },
            set: { height in
                setCustomDeviceCanvas(width: activeDeviceFrame.screenRect.width, height: CGFloat(height), orientation: activeDeviceFrame.orientation)
            }
        )
    }

    private func setCustomDeviceCanvas(width: CGFloat, height: CGFloat, orientation: GamepadEditorDeviceOrientation? = nil) {
        guard let frame = GamepadEditorDeviceCatalog.customFrame(width: width, height: height, preferredOrientation: orientation) else { return }
        setDeviceFrame(frame)
    }

    private func defaultLabel(for button: GameButton) -> String {
        let providedLabel = defaultLabelProvider?(button).map(normalizedGamepadLabel) ?? ""
        return providedLabel.isEmpty ? GamepadCustomization.defaultVisualLabel(for: button) : providedLabel
    }

    private func visualLabel(for button: GameButton) -> String {
        customization.visualLabel(for: button, defaultLabel: defaultLabel(for: button))
    }

    private var gridShowsBinding: Binding<Bool> {
        Binding(
            get: { customization.designMetadata?.grid.showsGrid ?? GamepadEditorGridSettings.defaultValue.showsGrid },
            set: { value in updateGridSettings { $0.showsGrid = value } }
        )
    }

    private var gridSnapBinding: Binding<Bool> {
        Binding(
            get: { customization.designMetadata?.grid.snapToGrid ?? GamepadEditorGridSettings.defaultValue.snapToGrid },
            set: { value in updateGridSettings { $0.snapToGrid = value } }
        )
    }

    private var objectSnapBinding: Binding<Bool> {
        Binding(
            get: { customization.designMetadata?.grid.snapToObjects ?? GamepadEditorGridSettings.defaultValue.snapToObjects },
            set: { value in updateGridSettings { $0.snapToObjects = value } }
        )
    }

    private var gridSizeBinding: Binding<Double> {
        Binding(
            get: { Double(customization.designMetadata?.grid.gridSize ?? GamepadEditorGridSettings.defaultValue.gridSize) },
            set: { value in updateGridSettings { $0.gridSize = CGFloat(value) } }
        )
    }

    private func updateGridSettings(_ mutate: (inout GamepadEditorGridSettings) -> Void) {
        update { customization in
            var metadata = customization.designMetadata ?? .empty
            var grid = metadata.grid
            mutate(&grid)
            metadata.grid = grid.normalized
            customization.designMetadata = metadata.normalized(availableControls: customization.allControlIdentitiesForDesign)
        }
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

    private func joystickVisualStyleValue(id: UUID) -> GamepadJoystickVisualStyle {
        customButton(id: id)?.normalized.layout.joystickVisualStyle ?? .pad
    }

    private func joystickVisualStyleBinding(id: UUID) -> Binding<GamepadJoystickVisualStyle> {
        Binding(
            get: { joystickVisualStyleValue(id: id) },
            set: { value in
                updateCustomButton(id: id) { customButton in
                    customButton.layout.joystickVisualStyle = value == .pad ? nil : value
                }
            }
        )
    }

    private func joystickOutputSettingsValue(id: UUID) -> GamepadJoystickOutputSettings {
        (customButton(id: id)?.normalized.joystickOutputSettings ?? .defaultValue).normalized
    }

    private func updateJoystickOutputSettings(id: UUID, mutate: (inout GamepadJoystickOutputSettings) -> Void) {
        updateCustomButton(id: id) { customButton in
            var settings = (customButton.joystickOutputSettings ?? .defaultValue).normalized
            mutate(&settings)
            customButton.joystickOutputSettings = settings.normalized
        }
    }

    private func joystickAnalogTargetBinding(id: UUID) -> Binding<GamepadJoystickAnalogTarget> {
        Binding(
            get: { joystickOutputSettingsValue(id: id).analogTarget },
            set: { value in
                updateJoystickOutputSettings(id: id) { $0.analogTarget = value }
            }
        )
    }

    private func joystickSendsDigitalDirectionsBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { joystickOutputSettingsValue(id: id).sendsDigitalDirections },
            set: { value in
                updateJoystickOutputSettings(id: id) { $0.sendsDigitalDirections = value }
            }
        )
    }

    private func joystickDeadZoneBinding(id: UUID) -> Binding<Double> {
        Binding(
            get: { Double(joystickOutputSettingsValue(id: id).deadZone) },
            set: { value in
                updateJoystickOutputSettings(id: id) { $0.deadZone = CGFloat(value) }
            }
        )
    }

    private func joystickSensitivityBinding(id: UUID) -> Binding<Double> {
        Binding(
            get: { Double(joystickOutputSettingsValue(id: id).sensitivity) },
            set: { value in
                updateJoystickOutputSettings(id: id) { $0.sensitivity = CGFloat(value) }
            }
        )
    }

    private func joystickInvertXBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { joystickOutputSettingsValue(id: id).invertX },
            set: { value in
                updateJoystickOutputSettings(id: id) { $0.invertX = value }
            }
        )
    }

    private func joystickInvertYBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { joystickOutputSettingsValue(id: id).invertY },
            set: { value in
                updateJoystickOutputSettings(id: id) { $0.invertY = value }
            }
        )
    }

    private func joystickSnapToCardinalBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { joystickOutputSettingsValue(id: id).snapToCardinal },
            set: { value in
                updateJoystickOutputSettings(id: id) { $0.snapToCardinal = value }
            }
        )
    }

    private func triggerSettingsValue(id: UUID) -> GamepadTriggerSettings {
        (customButton(id: id)?.normalized.triggerSettings ?? .defaultValue).normalized
    }

    private func updateTriggerSettings(id: UUID, mutate: (inout GamepadTriggerSettings) -> Void) {
        updateCustomButton(id: id) { customButton in
            var settings = (customButton.triggerSettings ?? .defaultValue).normalized
            mutate(&settings)
            customButton.triggerSettings = settings.normalized
        }
    }

    private func triggerTargetBinding(id: UUID) -> Binding<VirtualGamepadTrigger> {
        Binding(
            get: { triggerSettingsValue(id: id).target },
            set: { value in
                updateTriggerSettings(id: id) { $0.target = value }
            }
        )
    }

    private func triggerOrientationBinding(id: UUID) -> Binding<GamepadTriggerOrientation> {
        Binding(
            get: { triggerSettingsValue(id: id).orientation },
            set: { value in
                updateTriggerSettings(id: id) { $0.orientation = value }
            }
        )
    }

    private func triggerDeadZoneBinding(id: UUID) -> Binding<Double> {
        Binding(
            get: { Double(triggerSettingsValue(id: id).deadZone) },
            set: { value in
                updateTriggerSettings(id: id) { $0.deadZone = CGFloat(value) }
            }
        )
    }

    private func triggerSensitivityBinding(id: UUID) -> Binding<Double> {
        Binding(
            get: { Double(triggerSettingsValue(id: id).sensitivity) },
            set: { value in
                updateTriggerSettings(id: id) { $0.sensitivity = CGFloat(value) }
            }
        )
    }

    private func triggerSendsDigitalBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { triggerSettingsValue(id: id).sendsDigitalButton },
            set: { value in
                updateTriggerSettings(id: id) { $0.sendsDigitalButton = value }
            }
        )
    }

    private func triggerDigitalThresholdBinding(id: UUID) -> Binding<Double> {
        Binding(
            get: { Double(triggerSettingsValue(id: id).digitalThreshold) },
            set: { value in
                updateTriggerSettings(id: id) { $0.digitalThreshold = CGFloat(value) }
            }
        )
    }

    private func trackpadSettingsValue(id: UUID) -> GamepadTrackpadSettings {
        (customButton(id: id)?.normalized.trackpadSettings ?? .defaultValue).normalized
    }

    private func updateTrackpadSettings(id: UUID, mutate: (inout GamepadTrackpadSettings) -> Void) {
        updateCustomButton(id: id) { customButton in
            var settings = (customButton.trackpadSettings ?? .defaultValue).normalized
            mutate(&settings)
            customButton.trackpadSettings = settings.normalized
        }
    }

    private func trackpadSensitivityBinding(id: UUID) -> Binding<Double> {
        Binding(
            get: { Double(trackpadSettingsValue(id: id).sensitivity) },
            set: { value in
                updateTrackpadSettings(id: id) { $0.sensitivity = CGFloat(value) }
            }
        )
    }

    private func trackpadScrollSensitivityBinding(id: UUID) -> Binding<Double> {
        Binding(
            get: { Double(trackpadSettingsValue(id: id).scrollSensitivity) },
            set: { value in
                updateTrackpadSettings(id: id) { $0.scrollSensitivity = CGFloat(value) }
            }
        )
    }

    private func trackpadTapToClickBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { trackpadSettingsValue(id: id).tapToClick },
            set: { value in
                updateTrackpadSettings(id: id) { $0.tapToClick = value }
            }
        )
    }

    private func trackpadTwoFingerScrollBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { trackpadSettingsValue(id: id).twoFingerScroll },
            set: { value in
                updateTrackpadSettings(id: id) { $0.twoFingerScroll = value }
            }
        )
    }

    private func trackpadNaturalScrollingBinding(id: UUID) -> Binding<Bool> {
        Binding(
            get: { trackpadSettingsValue(id: id).naturalScrolling },
            set: { value in
                updateTrackpadSettings(id: id) { $0.naturalScrolling = value }
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
        selectedControlIDs = [identity]
        isControlSelectionActive = true
        layerSelectionAnchorID = identity
    }

    private func selectKeypadInspector() {
        selectedControlIDs.removeAll()
        isControlSelectionActive = false
        layerSelectionAnchorID = nil
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

    private func bringLayerForward(_ identity: GamepadControlIdentity) {
        update { $0.bringLayerForward(identity) }
    }

    private func sendLayerBackward(_ identity: GamepadControlIdentity) {
        update { $0.sendLayerBackward(identity) }
    }

    private func bringLayerToFront(_ identity: GamepadControlIdentity) {
        update { $0.bringLayerToFront(identity) }
    }

    private func sendLayerToBack(_ identity: GamepadControlIdentity) {
        update { $0.sendLayerToBack(identity) }
    }

    private var selectedLayerActionIDs: Set<GamepadControlIdentity> {
        selectedControlIDs.count > 1 ? selectedControlIDs : [selectedControlID]
    }

    private func bringSelectedLayersForward() {
        update(actionName: selectedLayerActionIDs.count > 1 ? "Bring Selection Forward" : "Bring Layer Forward") { $0.bringLayersForward(selectedLayerActionIDs) }
    }

    private func sendSelectedLayersBackward() {
        update(actionName: selectedLayerActionIDs.count > 1 ? "Send Selection Backward" : "Send Layer Backward") { $0.sendLayersBackward(selectedLayerActionIDs) }
    }

    private func bringSelectedLayersToFront() {
        update(actionName: selectedLayerActionIDs.count > 1 ? "Bring Selection To Front" : "Bring Layer To Front") { $0.bringLayersToFront(selectedLayerActionIDs) }
    }

    private func sendSelectedLayersToBack() {
        update(actionName: selectedLayerActionIDs.count > 1 ? "Send Selection To Back" : "Send Layer To Back") { $0.sendLayersToBack(selectedLayerActionIDs) }
    }

    private func performGroupShortcut() -> Bool {
        guard canGroupSelectedControls else { return false }
        groupSelectedControls()
        return true
    }

    private func isComponentHidden(_ identity: GamepadControlIdentity) -> Bool {
        switch identity {
        case .builtin(let button):
            customization.buttonCustomization(for: button).isHidden
        case .custom(let id):
            customButton(id: id)?.layout.isHidden ?? false
        case .system(.topBarActivation):
            customization.topBarActivationRegion.isHidden
        case .controlBarItem(let item):
            customization.controlBarItemCustomization(for: item).isHidden
        }
    }

    private func isComponentLocationLocked(_ identity: GamepadControlIdentity) -> Bool {
        switch identity {
        case .builtin(let button):
            customization.buttonCustomization(for: button).isLocationLocked
        case .custom(let id):
            customButton(id: id)?.layout.isLocationLocked ?? false
        case .system(.topBarActivation):
            customization.topBarActivationRegion.isLocationLocked
        case .controlBarItem:
            true
        }
    }

    private func setComponentHidden(_ isHidden: Bool, for identity: GamepadControlIdentity) {
        update { next in setComponentHidden(isHidden, for: identity, in: &next) }
    }

    private func setComponentHidden(_ isHidden: Bool, for identity: GamepadControlIdentity, in customization: inout GamepadCustomization) {
        switch identity {
        case .builtin(let button):
            var buttonCustomization = customization.buttonCustomization(for: button)
            buttonCustomization.isHidden = isHidden
            customization.setButtonCustomization(buttonCustomization, for: button)
        case .custom(let id):
            guard let index = customization.customButtons.firstIndex(where: { $0.id == id }) else { return }
            customization.customButtons[index].layout.isHidden = isHidden
        case .system(.topBarActivation):
            customization.topBarActivationRegion.isHidden = isHidden
        case .controlBarItem(let item):
            var appearance = customization.controlBarItemCustomization(for: item)
            appearance.isHidden = isHidden
            customization.setControlBarItemCustomization(appearance, for: item)
        }
    }

    private func setComponentLocationLocked(_ isLocked: Bool, for identity: GamepadControlIdentity) {
        update { next in setComponentLocationLocked(isLocked, for: identity, in: &next) }
    }

    private func setComponentLocationLocked(_ isLocked: Bool, for identity: GamepadControlIdentity, in customization: inout GamepadCustomization) {
        switch identity {
        case .builtin(let button):
            var buttonCustomization = customization.buttonCustomization(for: button)
            buttonCustomization.isLocationLocked = isLocked
            customization.setButtonCustomization(buttonCustomization, for: button)
        case .custom(let id):
            guard let index = customization.customButtons.firstIndex(where: { $0.id == id }) else { return }
            customization.customButtons[index].layout.isLocationLocked = isLocked
        case .system(.topBarActivation):
            customization.topBarActivationRegion.isLocationLocked = isLocked
        case .controlBarItem:
            break
        }
    }

    private func selectedLayoutCustomization(for identity: GamepadControlIdentity) -> GamepadButtonCustomization {
        switch identity {
        case .builtin(let button):
            return customization.buttonCustomization(for: button)
        case .custom(let id):
            return customButton(id: id)?.layout.normalized ?? .defaultValue
        case .system(.topBarActivation):
            return customization.topBarActivationRegion.normalized
        case .controlBarItem(let item):
            return customization.controlBarItemCustomization(for: item)
        }
    }

    private func styleIDBinding(for identity: GamepadControlIdentity) -> Binding<String> {
        Binding(
            get: { selectedLayoutCustomization(for: identity).styleID ?? "" },
            set: { value in
                updateLayoutCustomization(for: identity) { layout in
                    let normalized = GamepadStyleToken.normalizedIdentifier(value)
                    layout.styleID = normalized.isEmpty ? nil : normalized
                }
            }
        )
    }

    private func iconTextBinding(for identity: GamepadControlIdentity) -> Binding<String> {
        Binding(
            get: { selectedLayoutCustomization(for: identity).icon?.value ?? "" },
            set: { value in
                updateLayoutCustomization(for: identity) { layout in
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        layout.icon = nil
                    } else if trimmed.count <= 2 {
                        layout.icon = GamepadControlIcon.text(trimmed)
                    } else {
                        layout.icon = GamepadControlIcon.sfSymbol(trimmed)
                    }
                }
            }
        )
    }

    private func hapticFeedbackValue(for identity: GamepadControlIdentity) -> GamepadHapticFeedback {
        selectedLayoutCustomization(for: identity).resolvedHapticFeedback
    }

    private func hapticStyleBinding(for identity: GamepadControlIdentity) -> Binding<GamepadHapticStyle> {
        Binding(
            get: { hapticFeedbackValue(for: identity).style },
            set: { value in
                var feedback = hapticFeedbackValue(for: identity)
                let hasExplicitFeedback = selectedLayoutCustomization(for: identity).hapticFeedback != nil
                feedback.style = value
                if !hasExplicitFeedback {
                    feedback.intensity = value.defaultIntensity
                    feedback.sharpness = value.defaultSharpness
                }
                setHapticFeedback(feedback, for: identity)
            }
        )
    }

    private func hapticPatternBinding(for identity: GamepadControlIdentity) -> Binding<GamepadHapticPattern> {
        Binding(
            get: { hapticFeedbackValue(for: identity).pattern },
            set: { value in
                var feedback = hapticFeedbackValue(for: identity)
                feedback.pattern = value
                setHapticFeedback(feedback, for: identity)
            }
        )
    }

    private func hapticIntensityBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(hapticFeedbackValue(for: identity).intensity) },
            set: { value in
                var feedback = hapticFeedbackValue(for: identity)
                feedback.intensity = CGFloat(value)
                setHapticFeedback(feedback, for: identity)
            }
        )
    }

    private func hapticSharpnessBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(hapticFeedbackValue(for: identity).sharpness) },
            set: { value in
                var feedback = hapticFeedbackValue(for: identity)
                feedback.sharpness = CGFloat(value)
                setHapticFeedback(feedback, for: identity)
            }
        )
    }

    private func hapticDurationBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(hapticFeedbackValue(for: identity).duration) },
            set: { value in
                var feedback = hapticFeedbackValue(for: identity)
                feedback.duration = CGFloat(value)
                setHapticFeedback(feedback, for: identity)
            }
        )
    }

    private func setHapticFeedback(_ feedback: GamepadHapticFeedback, for identity: GamepadControlIdentity) {
        updateLayoutCustomization(for: identity) { layout in
            let normalized = feedback.normalized
            if normalized.isDefault {
                layout.hapticStyle = nil
                layout.hapticFeedback = nil
            } else {
                layout.hapticStyle = normalized.style
                layout.hapticFeedback = normalized
            }
        }
    }

    private func copySelectedElementStyle() {
        copiedElementStyle = selectedLayoutCustomization(for: selectedControlID).styleSnapshot
    }

    private func pasteStyleToSelectedElements() {
        guard let copiedElementStyle else { return }
        let targets = selectedControlIDs.isEmpty ? [selectedControlID] : Array(selectedControlIDs)
        update { customization in
            for identity in targets {
                Self.applyStyleSnapshot(copiedElementStyle, to: identity, in: &customization)
            }
        }
    }

    private static func applyStyleSnapshot(_ snapshot: GamepadButtonCustomization, to identity: GamepadControlIdentity, in customization: inout GamepadCustomization) {
        switch identity {
        case .builtin(let button):
            var layout = customization.buttonCustomization(for: button)
            layout.applyStyleSnapshot(snapshot)
            customization.setButtonCustomization(layout, for: button)
        case .custom(let id):
            guard let index = customization.customButtons.firstIndex(where: { $0.id == id }) else { return }
            customization.customButtons[index].layout.applyStyleSnapshot(snapshot)
        case .system(.topBarActivation):
            customization.topBarActivationRegion.applyStyleSnapshot(snapshot)
        case .controlBarItem(let item):
            var appearance = customization.controlBarItemCustomization(for: item)
            appearance.applyStyleSnapshot(snapshot)
            customization.setControlBarItemCustomization(appearance, for: item)
        }
    }

    private func alignSelectedControls(_ axis: GamepadEditorAlignmentAxis) {
        let controls = selectedResolvedControls()
        guard controls.count > 1 else { return }
        let target: CGFloat = switch axis {
        case .horizontalCenter: controls.map(\.center.x).reduce(0, +) / CGFloat(controls.count)
        case .verticalCenter: controls.map(\.center.y).reduce(0, +) / CGFloat(controls.count)
        }
        update { customization in
            for control in controls where !control.isLocationLocked {
                let nextCenter = CGPoint(
                    x: axis == .horizontalCenter ? target : control.center.x,
                    y: axis == .verticalCenter ? target : control.center.y
                )
                customization.setPosition(GamepadLayoutResolver.normalizedPosition(for: nextCenter, visualSize: control.size, in: currentCanvasLayoutSize), for: control.id)
            }
        }
    }

    private func distributeSelectedControls(axis: GamepadEditorDistributionAxis) {
        let controls = selectedResolvedControls().sorted { lhs, rhs in
            axis == .horizontal ? lhs.center.x < rhs.center.x : lhs.center.y < rhs.center.y
        }
        guard controls.count > 2, let first = controls.first, let last = controls.last else { return }
        let start = axis == .horizontal ? first.center.x : first.center.y
        let end = axis == .horizontal ? last.center.x : last.center.y
        let step = (end - start) / CGFloat(controls.count - 1)
        update { customization in
            for (index, control) in controls.enumerated() where !control.isLocationLocked {
                let coordinate = start + CGFloat(index) * step
                let nextCenter = CGPoint(
                    x: axis == .horizontal ? coordinate : control.center.x,
                    y: axis == .vertical ? coordinate : control.center.y
                )
                customization.setPosition(GamepadLayoutResolver.normalizedPosition(for: nextCenter, visualSize: control.size, in: currentCanvasLayoutSize), for: control.id)
            }
        }
    }

    private func selectedResolvedControls() -> [GamepadResolvedControl] {
        let selected = selectedControlIDs.isEmpty ? Set([selectedControlID]) : selectedControlIDs
        return customization.resolvedControls(in: currentCanvasLayoutSize).filter { selected.contains($0.id) }
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
        case .system(.topBarActivation):
            update { mutate(&$0.topBarActivationRegion) }
        case .controlBarItem(let item):
            update {
                var appearance = $0.controlBarItemCustomization(for: item)
                mutate(&appearance)
                $0.setControlBarItemCustomization(appearance, for: item)
            }
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
                    buttonCustomization.fillStyle = nil
                    buttonCustomization.lightFillStyle = nil
                    buttonCustomization.darkFillStyle = nil
                    buttonCustomization.accentStyle = style == customization.accentStyle ? nil : style
                }
            }
        )
    }

    private func accentStyleValue(for identity: GamepadControlIdentity) -> GamepadAccentStyle {
        selectedLayoutCustomization(for: identity).accentStyle ?? customization.accentStyle
    }

    private func selectedControlIsJoystick(_ identity: GamepadControlIdentity) -> Bool {
        guard case .custom(let id) = identity else { return false }
        return customButton(id: id)?.normalized.isJoystick == true
    }

    private func joystickKnobColorValue(for identity: GamepadControlIdentity, scheme: ColorScheme) -> GamepadRGBAColor {
        let layout = selectedLayoutCustomization(for: identity)
        if let color = layout.joystickKnobColor(for: scheme) {
            return color.normalized
        }
        let accentStyle = accentStyleValue(for: identity)
        let fallback = layout.buttonForeground(accentStyle: accentStyle, isPressed: false, scheme: scheme)
        return GamepadRGBAColor(color: fallback, fallback: .defaultValue).normalized
    }

    private func joystickKnobColorValueBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<GamepadRGBAColor> {
        Binding(
            get: { joystickKnobColorValue(for: identity, scheme: scheme) },
            set: { color in
                setJoystickKnobColor(color.normalized, for: identity, scheme: scheme)
            }
        )
    }

    private func joystickKnobColorHexPlainBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { joystickKnobColorValue(for: identity, scheme: scheme).hexString.replacingOccurrences(of: "#", with: "") },
            set: { hexString in
                joystickKnobColorHexBinding(for: identity, scheme: scheme).wrappedValue = hexString
            }
        )
    }

    private func selectedFillColorValue(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> GamepadRGBAColor {
        switch target {
        case .element(let identity):
            return selectedFillColorValue(for: identity, scheme: scheme)
        case .background:
            return customization.backgroundColorValue(for: scheme)
        }
    }

    private func fillColorValueBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<GamepadRGBAColor> {
        Binding(
            get: { selectedFillColorValue(for: target, scheme: scheme) },
            set: { color in
                setFillColor(color.normalized, for: target, scheme: scheme)
            }
        )
    }

    private func fillColorHexPlainBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { selectedFillColorValue(for: target, scheme: scheme).hexString.replacingOccurrences(of: "#", with: "") },
            set: { hexString in
                fillColorHexBinding(for: target, scheme: scheme).wrappedValue = hexString
            }
        )
    }

    private func fillPopoverTab(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> GamepadFillPopoverTab {
        switch selectedFillStyleValue(for: target, scheme: scheme).normalized {
        case .solid: return .solid
        case .gradient: return .gradient
        case .tile: return .tile
        case .image: return .image
        }
    }

    private func selectedFillStyleValue(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> GamepadFillStyle {
        switch target {
        case .element(let identity):
            return selectedFillStyleValue(for: identity, scheme: scheme)
        case .background:
            return customization.keypadBackgroundFillStyle(scheme: scheme)
        }
    }

    private func gradientFillBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<GamepadGradientFill> {
        Binding(
            get: {
                if case .gradient(let gradient) = selectedFillStyleValue(for: target, scheme: scheme) {
                    return gradient.normalized
                }
                return GamepadGradientFill.defaultValue(baseColor: selectedFillColorValue(for: target, scheme: scheme))
            },
            set: { gradient in
                setFillStyle(.gradient(gradient.normalized), for: target, scheme: scheme)
            }
        )
    }

    private func tileFillBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<GamepadTileFill> {
        Binding(
            get: {
                if case .tile(let tile) = selectedFillStyleValue(for: target, scheme: scheme) {
                    return tile.normalized
                }
                return GamepadTileFill.defaultValue(baseColor: selectedFillColorValue(for: target, scheme: scheme))
            },
            set: { tile in
                setFillStyle(.tile(tile.normalized), for: target, scheme: scheme)
            }
        )
    }

    private func imageFillBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<GamepadImageFill> {
        Binding(
            get: {
                if case .image(let image) = selectedFillStyleValue(for: target, scheme: scheme) {
                    return image.normalized
                }
                return GamepadImageFill()
            },
            set: { image in
                setFillStyle(.image(image.normalized), for: target, scheme: scheme)
            }
        )
    }

    private func selectedFillColorValue(for identity: GamepadControlIdentity, scheme: ColorScheme) -> GamepadRGBAColor {
        if let fillStyle = selectedLayoutCustomization(for: identity).fillStyle(for: scheme) {
            return fillStyle.representativeColor.normalized
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

    private func fillPopoverTab(for identity: GamepadControlIdentity, scheme: ColorScheme) -> GamepadFillPopoverTab {
        guard let fillStyle = selectedLayoutCustomization(for: identity).fillStyle(for: scheme) else { return .solid }
        switch fillStyle {
        case .solid: return .solid
        case .gradient: return .gradient
        case .tile: return .tile
        case .image: return .image
        }
    }

    private func selectedFillStyleValue(for identity: GamepadControlIdentity, scheme: ColorScheme) -> GamepadFillStyle {
        selectedLayoutCustomization(for: identity).fillStyle(for: scheme) ?? .solid(selectedFillColorValue(for: identity, scheme: scheme))
    }

    private func gradientFillBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<GamepadGradientFill> {
        Binding(
            get: {
                if case .gradient(let gradient) = selectedFillStyleValue(for: identity, scheme: scheme) {
                    return gradient.normalized
                }
                return GamepadGradientFill.defaultValue(baseColor: selectedFillColorValue(for: identity, scheme: scheme))
            },
            set: { gradient in
                setFillStyle(.gradient(gradient.normalized), for: identity, scheme: scheme)
            }
        )
    }

    private func tileFillBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<GamepadTileFill> {
        Binding(
            get: {
                if case .tile(let tile) = selectedFillStyleValue(for: identity, scheme: scheme) {
                    return tile.normalized
                }
                return GamepadTileFill.defaultValue(baseColor: selectedFillColorValue(for: identity, scheme: scheme))
            },
            set: { tile in
                setFillStyle(.tile(tile.normalized), for: identity, scheme: scheme)
            }
        )
    }

    private func imageFillBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<GamepadImageFill> {
        Binding(
            get: {
                if case .image(let image) = selectedFillStyleValue(for: identity, scheme: scheme) {
                    return image.normalized
                }
                return GamepadImageFill()
            },
            set: { image in
                setFillStyle(.image(image.normalized), for: identity, scheme: scheme)
            }
        )
    }

    private func setBackgroundColor(_ color: GamepadRGBAColor, for scheme: ColorScheme) {
        update { $0.setBackgroundColor(color.normalized, for: scheme) }
    }

    private func setBackgroundFillStyle(_ style: GamepadFillStyle, for scheme: ColorScheme) {
        update { $0.setBackgroundFillStyle(style.normalized, for: scheme) }
    }

    private func clearBackgroundColor(for scheme: ColorScheme) {
        update { $0.clearBackgroundFill(for: scheme) }
    }

    private func toggleBackgroundVisibility(for scheme: ColorScheme) {
        let fillStyle = customization.keypadBackgroundFillStyle(scheme: scheme)
        let nextOpacity: CGFloat = fillStyle.representativeColor.alpha > 0.001 ? 0 : 1
        setBackgroundFillStyle(fillStyle.withOpacity(nextOpacity), for: scheme)
    }

    private func toggleFillVisibility(for identity: GamepadControlIdentity, scheme: ColorScheme) {
        toggleFillVisibility(for: .element(identity), scheme: scheme)
    }

    private func toggleFillVisibility(for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        let fillStyle = selectedFillStyleValue(for: target, scheme: scheme)
        let nextOpacity: CGFloat = fillStyle.representativeColor.alpha > 0.001 ? 0 : 1
        setFillStyle(fillStyle.withOpacity(nextOpacity), for: target, scheme: scheme)
    }

    private func toggleJoystickKnobColorVisibility(for identity: GamepadControlIdentity, scheme: ColorScheme) {
        var color = joystickKnobColorValue(for: identity, scheme: scheme)
        color.alpha = color.alpha > 0.001 ? 0 : 1
        setJoystickKnobColor(color.normalized, for: identity, scheme: scheme)
    }

    private func joystickKnobColorHexBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { joystickKnobColorValue(for: identity, scheme: scheme).hexString },
            set: { hexString in
                let currentColor = joystickKnobColorValue(for: identity, scheme: scheme)
                guard let parsedColor = GamepadRGBAColor(hexString: hexString, alpha: currentColor.alpha) else { return }
                setJoystickKnobColor(parsedColor.normalized, for: identity, scheme: scheme)
            }
        )
    }

    private func joystickKnobColorAlphaTextBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { "\(Int((joystickKnobColorValue(for: identity, scheme: scheme).alpha * 100).rounded()))" },
            set: { alphaString in
                guard let alphaValue = Double(alphaString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                let normalizedAlpha = Self.clamp(CGFloat(alphaValue / 100), lower: 0, upper: 1)
                var color = joystickKnobColorValue(for: identity, scheme: scheme)
                color.alpha = normalizedAlpha
                setJoystickKnobColor(color.normalized, for: identity, scheme: scheme)
            }
        )
    }

    private func fillColorHexBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { selectedFillColorValue(for: target, scheme: scheme).hexString },
            set: { hexString in
                let currentColor = selectedFillColorValue(for: target, scheme: scheme)
                guard let parsedColor = GamepadRGBAColor(hexString: hexString, alpha: currentColor.alpha) else { return }
                setFillColor(parsedColor.normalized, for: target, scheme: scheme)
            }
        )
    }

    private func fillColorAlphaTextBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<String> {
        Binding(
            get: { "\(Int((selectedFillColorValue(for: target, scheme: scheme).alpha * 100).rounded()))" },
            set: { alphaString in
                guard let alphaValue = Double(alphaString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                let normalizedAlpha = Self.clamp(CGFloat(alphaValue / 100), lower: 0, upper: 1)
                var color = selectedFillColorValue(for: target, scheme: scheme)
                color.alpha = normalizedAlpha
                setFillColor(color.normalized, for: target, scheme: scheme)
            }
        )
    }

    private func gradientAngleBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<Double> {
        Binding(
            get: { Double(gradientFillBinding(for: target, scheme: scheme).wrappedValue.angleDegrees) },
            set: { angle in
                var gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue
                gradient.angleDegrees = CGFloat(angle)
                gradientFillBinding(for: target, scheme: scheme).wrappedValue = gradient.normalized
            }
        )
    }

    private func gradientStopOffsetTextBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme, index: Int) -> Binding<String> {
        Binding(
            get: {
                let gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue.normalized
                guard gradient.stops.indices.contains(index) else { return "0" }
                return "\(Int((gradient.stops[index].offset * 100).rounded()))"
            },
            set: { text in
                guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                updateGradientStop(index: index, for: target, scheme: scheme) { stop in
                    stop.offset = Self.clamp(CGFloat(value / 100), lower: 0, upper: 1)
                }
            }
        )
    }

    private func gradientStopHexBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme, index: Int) -> Binding<String> {
        Binding(
            get: {
                let gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue.normalized
                guard gradient.stops.indices.contains(index) else { return "000000" }
                return gradient.stops[index].color.hexString.replacingOccurrences(of: "#", with: "")
            },
            set: { text in
                let gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue.normalized
                guard gradient.stops.indices.contains(index) else { return }
                let currentColor = gradient.stops[index].color
                guard let color = GamepadRGBAColor(hexString: text, alpha: currentColor.alpha) else { return }
                updateGradientStop(index: index, for: target, scheme: scheme) { stop in
                    stop.color = color.normalized
                }
            }
        )
    }

    private func gradientStopAlphaTextBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme, index: Int) -> Binding<String> {
        Binding(
            get: {
                let gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue.normalized
                guard gradient.stops.indices.contains(index) else { return "100" }
                return "\(Int((gradient.stops[index].color.alpha * 100).rounded()))"
            },
            set: { text in
                guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                updateGradientStop(index: index, for: target, scheme: scheme) { stop in
                    stop.color.alpha = Self.clamp(CGFloat(value / 100), lower: 0, upper: 1)
                }
            }
        )
    }

    private func tilePatternBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<GamepadTilePattern> {
        Binding(
            get: { tileFillBinding(for: target, scheme: scheme).wrappedValue.pattern },
            set: { pattern in
                var tile = tileFillBinding(for: target, scheme: scheme).wrappedValue
                tile.pattern = pattern
                tileFillBinding(for: target, scheme: scheme).wrappedValue = tile
            }
        )
    }

    private func tileScaleBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme) -> Binding<Double> {
        Binding(
            get: { Double(tileFillBinding(for: target, scheme: scheme).wrappedValue.scale) },
            set: { scale in
                var tile = tileFillBinding(for: target, scheme: scheme).wrappedValue
                tile.scale = CGFloat(scale)
                tileFillBinding(for: target, scheme: scheme).wrappedValue = tile
            }
        )
    }

    private func tileSpacingBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme, keyPath: WritableKeyPath<GamepadTileFill, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(tileFillBinding(for: target, scheme: scheme).wrappedValue[keyPath: keyPath]) },
            set: { value in
                var tile = tileFillBinding(for: target, scheme: scheme).wrappedValue
                tile[keyPath: keyPath] = CGFloat(value)
                tileFillBinding(for: target, scheme: scheme).wrappedValue = tile
            }
        )
    }

    private func imageAdjustmentBinding(for target: GamepadFillEditorTarget, scheme: ColorScheme, keyPath: WritableKeyPath<GamepadImageFill, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(imageFillBinding(for: target, scheme: scheme).wrappedValue[keyPath: keyPath]) },
            set: { value in
                var image = imageFillBinding(for: target, scheme: scheme).wrappedValue
                image[keyPath: keyPath] = CGFloat(value)
                imageFillBinding(for: target, scheme: scheme).wrappedValue = image
            }
        )
    }

    private func updateGradientStop(index: Int, for target: GamepadFillEditorTarget, scheme: ColorScheme, mutate: (inout GamepadGradientStop) -> Void) {
        var gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue.normalized
        guard gradient.stops.indices.contains(index) else { return }
        mutate(&gradient.stops[index])
        gradientFillBinding(for: target, scheme: scheme).wrappedValue = gradient.normalized
    }

    private func addGradientStop(for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        var gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue.normalized
        let midpoint = gradient.stops.count >= 2 ? gradient.stops[0].color.mixed(with: gradient.stops[gradient.stops.count - 1].color, amount: 0.5) : selectedFillColorValue(for: target, scheme: scheme)
        gradient.stops.append(GamepadGradientStop(offset: 0.5, color: midpoint))
        gradientFillBinding(for: target, scheme: scheme).wrappedValue = gradient.normalized
    }

    private func removeGradientStop(index: Int, for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        var gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue.normalized
        guard gradient.stops.count > 2, gradient.stops.indices.contains(index) else { return }
        gradient.stops.remove(at: index)
        gradientFillBinding(for: target, scheme: scheme).wrappedValue = gradient.normalized
    }

    private func reverseGradientStops(for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        var gradient = gradientFillBinding(for: target, scheme: scheme).wrappedValue.normalized
        gradient.stops = gradient.stops.map { GamepadGradientStop(offset: 1 - $0.offset, color: $0.color) }
        gradientFillBinding(for: target, scheme: scheme).wrappedValue = gradient.normalized
    }

    private func setFillColor(_ color: GamepadRGBAColor, for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        switch target {
        case .element(let identity):
            setFillColor(color, for: identity, scheme: scheme)
        case .background:
            setBackgroundColor(color.normalized, for: scheme)
        }
    }

    private func setFillStyle(_ style: GamepadFillStyle, for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        switch target {
        case .element(let identity):
            setFillStyle(style, for: identity, scheme: scheme)
        case .background:
            setBackgroundFillStyle(style.normalized, for: scheme)
        }
    }

    private func clearCustomFill(for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        switch target {
        case .element(let identity):
            clearCustomFillColor(for: identity, scheme: scheme)
        case .background:
            clearBackgroundColor(for: scheme)
        }
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

    private func gradientAngleBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<Double> {
        Binding(
            get: { Double(gradientFillBinding(for: identity, scheme: scheme).wrappedValue.angleDegrees) },
            set: { angle in
                var gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue
                gradient.angleDegrees = CGFloat(angle)
                gradientFillBinding(for: identity, scheme: scheme).wrappedValue = gradient.normalized
            }
        )
    }

    private func gradientStopOffsetTextBinding(for identity: GamepadControlIdentity, scheme: ColorScheme, index: Int) -> Binding<String> {
        Binding(
            get: {
                let gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue.normalized
                guard gradient.stops.indices.contains(index) else { return "0" }
                return "\(Int((gradient.stops[index].offset * 100).rounded()))"
            },
            set: { text in
                guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                updateGradientStop(index: index, for: identity, scheme: scheme) { stop in
                    stop.offset = Self.clamp(CGFloat(value / 100), lower: 0, upper: 1)
                }
            }
        )
    }

    private func gradientStopHexBinding(for identity: GamepadControlIdentity, scheme: ColorScheme, index: Int) -> Binding<String> {
        Binding(
            get: {
                let gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue.normalized
                guard gradient.stops.indices.contains(index) else { return "000000" }
                return gradient.stops[index].color.hexString.replacingOccurrences(of: "#", with: "")
            },
            set: { text in
                let gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue.normalized
                guard gradient.stops.indices.contains(index) else { return }
                let currentColor = gradient.stops[index].color
                guard let color = GamepadRGBAColor(hexString: text, alpha: currentColor.alpha) else { return }
                updateGradientStop(index: index, for: identity, scheme: scheme) { stop in
                    stop.color = color.normalized
                }
            }
        )
    }

    private func gradientStopAlphaTextBinding(for identity: GamepadControlIdentity, scheme: ColorScheme, index: Int) -> Binding<String> {
        Binding(
            get: {
                let gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue.normalized
                guard gradient.stops.indices.contains(index) else { return "100" }
                return "\(Int((gradient.stops[index].color.alpha * 100).rounded()))"
            },
            set: { text in
                guard let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                updateGradientStop(index: index, for: identity, scheme: scheme) { stop in
                    stop.color.alpha = Self.clamp(CGFloat(value / 100), lower: 0, upper: 1)
                }
            }
        )
    }

    private func tilePatternBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<GamepadTilePattern> {
        Binding(
            get: { tileFillBinding(for: identity, scheme: scheme).wrappedValue.pattern },
            set: { pattern in
                var tile = tileFillBinding(for: identity, scheme: scheme).wrappedValue
                tile.pattern = pattern
                tileFillBinding(for: identity, scheme: scheme).wrappedValue = tile
            }
        )
    }

    private func tileScaleBinding(for identity: GamepadControlIdentity, scheme: ColorScheme) -> Binding<Double> {
        Binding(
            get: { Double(tileFillBinding(for: identity, scheme: scheme).wrappedValue.scale) },
            set: { scale in
                var tile = tileFillBinding(for: identity, scheme: scheme).wrappedValue
                tile.scale = CGFloat(scale)
                tileFillBinding(for: identity, scheme: scheme).wrappedValue = tile
            }
        )
    }

    private func tileSpacingBinding(for identity: GamepadControlIdentity, scheme: ColorScheme, keyPath: WritableKeyPath<GamepadTileFill, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(tileFillBinding(for: identity, scheme: scheme).wrappedValue[keyPath: keyPath]) },
            set: { value in
                var tile = tileFillBinding(for: identity, scheme: scheme).wrappedValue
                tile[keyPath: keyPath] = CGFloat(value)
                tileFillBinding(for: identity, scheme: scheme).wrappedValue = tile
            }
        )
    }

    private func imageAdjustmentBinding(for identity: GamepadControlIdentity, scheme: ColorScheme, keyPath: WritableKeyPath<GamepadImageFill, CGFloat>) -> Binding<Double> {
        Binding(
            get: { Double(imageFillBinding(for: identity, scheme: scheme).wrappedValue[keyPath: keyPath]) },
            set: { value in
                var image = imageFillBinding(for: identity, scheme: scheme).wrappedValue
                image[keyPath: keyPath] = CGFloat(value)
                imageFillBinding(for: identity, scheme: scheme).wrappedValue = image
            }
        )
    }

    private func updateGradientStop(index: Int, for identity: GamepadControlIdentity, scheme: ColorScheme, mutate: (inout GamepadGradientStop) -> Void) {
        var gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue.normalized
        guard gradient.stops.indices.contains(index) else { return }
        mutate(&gradient.stops[index])
        gradientFillBinding(for: identity, scheme: scheme).wrappedValue = gradient.normalized
    }

    private func addGradientStop(for identity: GamepadControlIdentity, scheme: ColorScheme) {
        var gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue.normalized
        let midpoint = gradient.stops.count >= 2 ? (gradient.stops[0].color.mixed(with: gradient.stops[gradient.stops.count - 1].color, amount: 0.5)) : selectedFillColorValue(for: identity, scheme: scheme)
        gradient.stops.append(GamepadGradientStop(offset: 0.5, color: midpoint))
        gradientFillBinding(for: identity, scheme: scheme).wrappedValue = gradient.normalized
    }

    private func removeGradientStop(index: Int, for identity: GamepadControlIdentity, scheme: ColorScheme) {
        var gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue.normalized
        guard gradient.stops.count > 2, gradient.stops.indices.contains(index) else { return }
        gradient.stops.remove(at: index)
        gradientFillBinding(for: identity, scheme: scheme).wrappedValue = gradient.normalized
    }

    private func reverseGradientStops(for identity: GamepadControlIdentity, scheme: ColorScheme) {
        var gradient = gradientFillBinding(for: identity, scheme: scheme).wrappedValue.normalized
        gradient.stops = gradient.stops.map { GamepadGradientStop(offset: 1 - $0.offset, color: $0.color) }
        gradientFillBinding(for: identity, scheme: scheme).wrappedValue = gradient.normalized
    }

    private func setJoystickKnobColor(_ color: GamepadRGBAColor, for identity: GamepadControlIdentity, scheme: ColorScheme) {
        updateLayoutCustomization(for: identity) { buttonCustomization in
            prepareSchemeSpecificJoystickKnobColorStorage(&buttonCustomization)
            switch scheme {
            case .dark:
                buttonCustomization.darkJoystickKnobColor = color.normalized
            default:
                buttonCustomization.lightJoystickKnobColor = color.normalized
            }
        }
    }

    private func clearJoystickKnobColor(for identity: GamepadControlIdentity, scheme: ColorScheme) {
        updateLayoutCustomization(for: identity) { buttonCustomization in
            prepareSchemeSpecificJoystickKnobColorStorage(&buttonCustomization)
            switch scheme {
            case .dark:
                buttonCustomization.darkJoystickKnobColor = nil
            default:
                buttonCustomization.lightJoystickKnobColor = nil
            }
        }
    }

    private func prepareSchemeSpecificJoystickKnobColorStorage(_ buttonCustomization: inout GamepadButtonCustomization) {
        if let legacyColor = buttonCustomization.joystickKnobColor?.normalized {
            if buttonCustomization.lightJoystickKnobColor == nil {
                buttonCustomization.lightJoystickKnobColor = legacyColor
            }
            if buttonCustomization.darkJoystickKnobColor == nil {
                buttonCustomization.darkJoystickKnobColor = legacyColor
            }
        }
        buttonCustomization.joystickKnobColor = nil
    }

    private func setFillColor(_ color: GamepadRGBAColor, for identity: GamepadControlIdentity, scheme: ColorScheme) {
        updateLayoutCustomization(for: identity) { buttonCustomization in
            prepareSchemeSpecificFillStorage(&buttonCustomization)
            switch scheme {
            case .dark:
                buttonCustomization.darkFillColor = color.normalized
                buttonCustomization.darkFillStyle = nil
            default:
                buttonCustomization.lightFillColor = color.normalized
                buttonCustomization.lightFillStyle = nil
            }
        }
    }

    private func setFillStyle(_ style: GamepadFillStyle, for identity: GamepadControlIdentity, scheme: ColorScheme) {
        updateLayoutCustomization(for: identity) { buttonCustomization in
            prepareSchemeSpecificFillStorage(&buttonCustomization)
            switch scheme {
            case .dark:
                buttonCustomization.darkFillStyle = style.normalized
                buttonCustomization.darkFillColor = nil
            default:
                buttonCustomization.lightFillStyle = style.normalized
                buttonCustomization.lightFillColor = nil
            }
        }
    }

    private func clearCustomFillColor(for identity: GamepadControlIdentity, scheme: ColorScheme) {
        updateLayoutCustomization(for: identity) { buttonCustomization in
            prepareSchemeSpecificFillStorage(&buttonCustomization)
            switch scheme {
            case .dark:
                buttonCustomization.darkFillColor = nil
                buttonCustomization.darkFillStyle = nil
            default:
                buttonCustomization.lightFillColor = nil
                buttonCustomization.lightFillStyle = nil
            }
        }
    }

    private func prepareSchemeSpecificFillStorage(_ buttonCustomization: inout GamepadButtonCustomization) {
        if let legacyFillColor = buttonCustomization.fillColor?.normalized {
            if buttonCustomization.lightFillColor == nil {
                buttonCustomization.lightFillColor = legacyFillColor
            }
            if buttonCustomization.darkFillColor == nil {
                buttonCustomization.darkFillColor = legacyFillColor
            }
        }
        if let legacyFillStyle = buttonCustomization.fillStyle?.normalized {
            if buttonCustomization.lightFillStyle == nil {
                buttonCustomization.lightFillStyle = legacyFillStyle
            }
            if buttonCustomization.darkFillStyle == nil {
                buttonCustomization.darkFillStyle = legacyFillStyle
            }
        }
        buttonCustomization.fillColor = nil
        buttonCustomization.fillStyle = nil
    }

    private func handleFillImageImport(_ result: Result<URL, Error>, for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        switch result {
        case .success(let url):
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                guard data.count <= GamepadImageFill.maximumStoredBytes else {
                    fillImageImportError = "Choose an image under 2.5 MB."
                    return
                }
                var imageFill = imageFillBinding(for: target, scheme: scheme).wrappedValue
                imageFill.data = data
                imageFill.fileName = url.lastPathComponent
                imageFillBinding(for: target, scheme: scheme).wrappedValue = imageFill.normalized
                activeFillPopoverTab = .image
                fillImageImportError = nil
            } catch {
                fillImageImportError = "Could not import image: \(error.localizedDescription)"
            }
        case .failure(let error):
            fillImageImportError = error.localizedDescription
        }
    }

    private func makeGeneratedFillImage(for target: GamepadFillEditorTarget, scheme: ColorScheme) {
        let base = selectedFillColorValue(for: target, scheme: scheme).normalized
        let size = CGSize(width: 256, height: 256)
        let image = NSImage(size: size)
        image.lockFocus()

        let baseColor = NSColor(srgbRed: base.red, green: base.green, blue: base.blue, alpha: 1)
        let highlight = NSColor(srgbRed: min(base.red + 0.34, 1), green: min(base.green + 0.34, 1), blue: min(base.blue + 0.34, 1), alpha: 1)
        let shadow = NSColor(srgbRed: max(base.red * 0.46, 0), green: max(base.green * 0.46, 0), blue: max(base.blue * 0.46, 0), alpha: 1)

        NSGradient(colors: [highlight, baseColor, shadow])?.draw(in: NSRect(origin: .zero, size: size), angle: 35)

        for index in 0..<9 {
            let side = CGFloat(34 + index * 8)
            let rect = NSRect(
                x: CGFloat((index * 37) % 220) - 12,
                y: CGFloat((index * 53) % 220) - 8,
                width: side,
                height: side
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: side * 0.28, yRadius: side * 0.28)
            (index.isMultiple(of: 2) ? NSColor.white.withAlphaComponent(0.16) : NSColor.black.withAlphaComponent(0.12)).setFill()
            path.fill()
        }
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:])
        else {
            fillImageImportError = "Could not generate an image."
            return
        }

        var imageFill = imageFillBinding(for: target, scheme: scheme).wrappedValue
        imageFill.data = data
        imageFill.fileName = "Generated texture.png"
        imageFill.contentMode = .fill
        imageFillBinding(for: target, scheme: scheme).wrappedValue = imageFill.normalized
        activeFillPopoverTab = .image
        fillImageImportError = nil
    }

    private func uniformCornerRadiusBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(uniformCornerRadiusValue(for: identity)) },
            set: { newValue in
                let normalizedValue = GamepadButtonCustomization.normalizedCornerRadius(CGFloat(newValue))
                let currentShape = shapeValue(for: identity)
                let defaultRadius = defaultCornerRadiusValue(for: identity)
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    if currentShape.usesDynamicEditableCornerRadiusDefault {
                        buttonCustomization.shape = currentShape
                    }
                    buttonCustomization.cornerRadius = nil
                    buttonCustomization.cornerRadii = abs(normalizedValue - defaultRadius) < 0.001 ? nil : .uniform(normalizedValue)
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
                radii[corner] = GamepadButtonCustomization.normalizedCornerRadius(CGFloat(newValue))
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

    private func normalVisualStyleValue(for identity: GamepadControlIdentity) -> GamepadControlStateStyle {
        selectedLayoutCustomization(for: identity).visualStyle?.normal.normalized ?? .empty
    }

    private func updateNormalVisualStyle(for identity: GamepadControlIdentity, mutate: (inout GamepadControlStateStyle) -> Void) {
        updateLayoutCustomization(for: identity) { layout in
            var visualStyle = layout.visualStyle ?? .empty
            var normal = visualStyle.normal
            mutate(&normal)
            visualStyle.normal = normal.normalized
            layout.visualStyle = visualStyle.normalized
        }
    }

    private func visualStyleColorHexBinding(
        for identity: GamepadControlIdentity,
        keyPath: WritableKeyPath<GamepadControlStateStyle, GamepadRGBAColor?>
    ) -> Binding<String> {
        Binding(
            get: { normalVisualStyleValue(for: identity)[keyPath: keyPath]?.hexString ?? "" },
            set: { value in
                updateNormalVisualStyle(for: identity) { style in
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        style[keyPath: keyPath] = nil
                    } else if let color = GamepadRGBAColor(hexString: trimmed) {
                        style[keyPath: keyPath] = color.normalized
                    }
                }
            }
        )
    }

    private func visualStyleNumberBinding(
        for identity: GamepadControlIdentity,
        keyPath: WritableKeyPath<GamepadControlStateStyle, CGFloat?>,
        defaultValue: CGFloat = 0
    ) -> Binding<Double> {
        Binding(
            get: { Double(normalVisualStyleValue(for: identity)[keyPath: keyPath] ?? defaultValue) },
            set: { value in
                updateNormalVisualStyle(for: identity) { style in
                    let next = CGFloat(value)
                    style[keyPath: keyPath] = abs(next - defaultValue) < 0.001 ? nil : next
                }
            }
        )
    }

    private func applyMaterial(_ material: GamepadControlVisualStyle, to identity: GamepadControlIdentity) {
        updateLayoutCustomization(for: identity) { layout in
            layout.visualStyle = material.normalized
            layout.shadowStrength = 0
        }
    }

    private func clearMaterialEffects(for identity: GamepadControlIdentity) {
        updateNormalVisualStyle(for: identity) { style in
            style.foregroundColor = nil
            style.shadows = nil
            style.innerShadowColor = nil
            style.innerShadowRadius = nil
            style.innerShadowX = nil
            style.innerShadowY = nil
            style.highlightColor = nil
            style.highlightRadius = nil
            style.highlightX = nil
            style.highlightY = nil
            style.highlightOpacity = nil
            style.bevelHighlightColor = nil
            style.bevelShadowColor = nil
            style.bevelWidth = nil
        }
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

    private func zIndexBinding(for identity: GamepadControlIdentity) -> Binding<Double> {
        Binding(
            get: { Double(selectedLayoutCustomization(for: identity).zIndex) },
            set: { newValue in
                updateLayoutCustomization(for: identity) { buttonCustomization in
                    buttonCustomization.zIndex = GamepadButtonCustomization.normalizedZIndex(newValue)
                }
            }
        )
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
                case .system(.topBarActivation), .controlBarItem:
                    updateLayoutCustomization(for: identity) {
                        $0.shape = shape
                        $0.cornerRadius = nil
                        $0.cornerRadii = nil
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
        let minWidth = GamepadButtonCustomization.minimumDimension(forBaseDimension: baseSize.width)
        let minHeight = GamepadButtonCustomization.minimumDimension(forBaseDimension: baseSize.height)
        let maxWidth = min(currentCanvasLayoutSize.width, baseSize.width * GamepadButtonCustomization.maximumScale)
        let maxHeight = min(currentCanvasLayoutSize.height, baseSize.height * GamepadButtonCustomization.maximumScale)
        let clampedWidth = Self.clamp(frame.width, lower: minWidth, upper: maxWidth)
        let clampedHeight = Self.clamp(frame.height, lower: minHeight, upper: maxHeight)

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
                case .system(.topBarActivation):
                    return Double(customization.topBarActivationRegion[keyPath: keyPath])
                case .controlBarItem(let item):
                    return Double(customization.controlBarItemCustomization(for: item)[keyPath: keyPath])
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
        if case .controlBarItem = identity {
            updateLayoutCustomization(for: identity) { appearance in
                appearance[keyPath: keyPath] = GamepadButtonCustomization.clamp(
                    value,
                    lower: GamepadButtonCustomization.minimumScale,
                    upper: GamepadButtonCustomization.maximumScale
                )
            }
            return
        }

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
        case .system(.topBarActivation):
            return customization.topBarActivationRegion.resolvedShape(defaultShape: .capsule)
        case .controlBarItem(let item):
            return customization.controlBarItemCustomization(for: item).resolvedShape(defaultShape: .roundedRectangle)
        }
    }

    private func widthScaleValue(for identity: GamepadControlIdentity) -> CGFloat {
        switch identity {
        case .builtin(let button): customization.buttonCustomization(for: button).widthScale
        case .custom(let id): customButton(id: id)?.layout.widthScale ?? 1.0
        case .system(.topBarActivation): customization.topBarActivationRegion.widthScale
        case .controlBarItem(let item): customization.controlBarItemCustomization(for: item).widthScale
        }
    }

    private func heightScaleValue(for identity: GamepadControlIdentity) -> CGFloat {
        switch identity {
        case .builtin(let button): customization.buttonCustomization(for: button).heightScale
        case .custom(let id): customButton(id: id)?.layout.heightScale ?? 1.0
        case .system(.topBarActivation): customization.topBarActivationRegion.heightScale
        case .controlBarItem(let item): customization.controlBarItemCustomization(for: item).heightScale
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
            let kind = customButton(id: id)?.normalized.controlKind ?? .button
            updateCustomButton(id: id) {
                switch kind {
                case .joystick:
                    $0.label = "Joystick"
                    $0.layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.5,
                        widthScale: 1.35,
                        heightScale: 1.35,
                        shape: .circle
                    )
                    $0.joystickMapping = $0.joystickMapping ?? .movement
                    $0.joystickOutputSettings = $0.joystickOutputSettings ?? .defaultValue
                    $0.triggerSettings = nil
                    $0.trackpadSettings = nil
                case .trigger:
                    let target = ($0.triggerSettings ?? .defaultValue).normalized.target
                    $0.label = target.shortName
                    $0.layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.14,
                        widthScale: 1.08,
                        heightScale: 0.42,
                        shape: .capsule
                    )
                    $0.joystickMapping = nil
                    $0.joystickOutputSettings = nil
                    $0.triggerSettings = GamepadTriggerSettings(target: target, orientation: .horizontal)
                    $0.trackpadSettings = nil
                case .trackpad:
                    $0.label = "Trackpad"
                    $0.layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.58,
                        widthScale: 1.25,
                        heightScale: 1.0,
                        shape: .roundedRectangle,
                        cornerRadius: 18
                    )
                    $0.joystickMapping = nil
                    $0.joystickOutputSettings = nil
                    $0.triggerSettings = nil
                    $0.trackpadSettings = .defaultValue
                case .button:
                    $0.label = "Button"
                    $0.layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.5,
                        widthScale: 1.0,
                        heightScale: 1.0,
                        shape: .roundedRectangle
                    )
                    $0.joystickMapping = nil
                    $0.joystickOutputSettings = nil
                    $0.triggerSettings = nil
                    $0.trackpadSettings = nil
                case .decoration:
                    $0.label = "Decoration"
                    $0.layout = GamepadButtonCustomization(
                        centerX: 0.5,
                        centerY: 0.5,
                        widthScale: 2.2,
                        heightScale: 1.2,
                        shape: .roundedRectangle,
                        fillColor: GamepadRGBAColor(hexString: "#F2EEF5"),
                        visualStyle: .softWhitePlate(),
                        cornerRadius: 28,
                        shadowStrength: 0
                    )
                    $0.joystickMapping = nil
                    $0.joystickOutputSettings = nil
                    $0.triggerSettings = nil
                    $0.trackpadSettings = nil
                }
            }
        case .system(.topBarActivation):
            update { $0.topBarActivationRegion = GamepadCustomization.defaultTopBarActivationRegion }
        case .controlBarItem(let item):
            update { $0.resetControlBarItemAppearance(item) }
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

    private func update(
        actionName: String = "Edit Keypad",
        registersUndo: Bool = true,
        _ mutate: (inout GamepadCustomization) -> Void
    ) {
        var next = customization
        mutate(&next)
        applyCustomization(next, undoActionName: registersUndo ? actionName : nil)
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
        let shouldUpdateCustomization = customization != normalizedCustomization
        let shouldUpdateSelection = nextPrimaryControlID != selectedControlID
            || resolvedSelectionIDs != selectedControlIDs
            || nextIsControlSelectionActive != isControlSelectionActive
        guard shouldUpdateCustomization || shouldUpdateSelection else { return }

        if let undoActionName {
            registerUndoSnapshot(actionName: undoActionName)
        }

        setEditorCustomization(normalizedCustomization)
        selectedControlID = nextPrimaryControlID
        selectedControlIDs = resolvedSelectionIDs
        isControlSelectionActive = nextIsControlSelectionActive
        syncSelectedProfile(with: normalizedCustomization, persistsImmediately: false)
        scheduleExternalEditorCommit()
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

    private var profileUndoSnapshot: GamepadEditorProfileUndoSnapshot {
        GamepadEditorProfileUndoSnapshot(
            profiles: profiles,
            selectedProfileID: selectedProfileID,
            selectedProfileIDs: selectedProfileIDs,
            defaultProfileID: defaultProfileID,
            selectedProfileOrientation: selectedProfileOrientation,
            isSelectedProfileExpanded: isSelectedProfileExpanded,
            selectedProfileNameDraft: selectedProfileNameDraft,
            editorSnapshot: GamepadEditorUndoSnapshot(
                customization: customization.normalized,
                selectedControlID: selectedControlID,
                selectedControlIDs: selectedControlIDs,
                isControlSelectionActive: isControlSelectionActive
            )
        )
    }

    private func registerProfileUndoSnapshot(actionName: String) {
        if let onRegisterProfileUndoSnapshot {
            onRegisterProfileUndoSnapshot(actionName)
            return
        }

        guard let undoManager else { return }
        let snapshot = profileUndoSnapshot
        undoManager.registerUndo(withTarget: undoTarget) { _ in
            restoreProfileUndoSnapshot(snapshot, actionName: actionName)
        }
        undoManager.setActionName(actionName)
    }

    private func restoreProfileUndoSnapshot(_ snapshot: GamepadEditorProfileUndoSnapshot, actionName: String) {
        registerProfileUndoSnapshot(actionName: actionName)

        profiles = snapshot.profiles
        selectedProfileID = snapshot.selectedProfileID
        selectedProfileIDs = GamepadProfileSelectionLogic.normalizedExplicitSelection(
            snapshot.selectedProfileIDs,
            validProfileIDs: Set(snapshot.profiles.map(\.id))
        )
        defaultProfileID = snapshot.defaultProfileID
        selectedProfileOrientation = snapshot.selectedProfileOrientation
        isSelectedProfileExpanded = snapshot.isSelectedProfileExpanded
        selectedProfileNameDraft = snapshot.selectedProfileNameDraft
        setEditorCustomization(snapshot.editorSnapshot.customization.normalized)
        selectedControlID = snapshot.editorSnapshot.selectedControlID
        selectedControlIDs = snapshot.editorSnapshot.selectedControlIDs
        isControlSelectionActive = snapshot.editorSnapshot.isControlSelectionActive && !selectedControlIDs.isEmpty
        persistProfiles()
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
        selectedProfileIDs.removeAll()
        selectedProfileNameDraft = profile.name
        isSelectedProfileExpanded = true
        selectKeypadInspector()
        applyCustomization(profile.customization(for: selectedProfileOrientation))
        persistProfiles()
    }

    private func addJoystickControl() {
        let id = UUID()
        var next = customization
        next.addJoystick(id: id)
        placeCustomControl(id: id, in: &next)
        applyCustomization(next, selecting: .custom(id), undoActionName: "Add Joystick")
    }

    private func addTriggerControl() {
        let id = UUID()
        var next = customization
        next.addTrigger(id: id)
        placeCustomControl(id: id, in: &next)
        applyCustomization(next, selecting: .custom(id), undoActionName: "Add Trigger")
    }

    private func addTrackpadControl() {
        let id = UUID()
        var next = customization
        next.addTrackpad(id: id)
        placeCustomControl(id: id, in: &next)
        applyCustomization(next, selecting: .custom(id), undoActionName: "Add Trackpad")
    }

    private func addDecorationControl(kind: GamepadDecorationTemplateKind) {
        let id = UUID()
        var next = customization
        switch kind {
        case .plate:
            next.addDecoration(
                id: id,
                label: "Soft Plate",
                centerX: 0.5,
                centerY: 0.5,
                widthScale: 3.2,
                heightScale: 1.55,
                shape: .roundedRectangle,
                cornerRadius: 42,
                visualStyle: .softWhitePlate()
            )
        case .ring:
            next.addDecoration(
                id: id,
                label: "Ring",
                centerX: 0.5,
                centerY: 0.5,
                widthScale: 1.35,
                heightScale: 1.35,
                shape: .circle,
                cornerRadius: nil,
                visualStyle: .softWhiteInset()
            )
        }
        placeDecoration(id: id, in: &next)
        applyCustomization(next, selecting: .custom(id), undoActionName: kind == .plate ? "Add Soft Plate" : "Add Ring")
    }

    private func placeCustomControl(id: UUID, in next: inout GamepadCustomization) {
        let identity = GamepadControlIdentity.custom(id)
        let controls = next.resolvedControls(in: currentCanvasLayoutSize)
        guard let control = controls.first(where: { $0.id == identity }),
              let adjustedFrame = GamepadLayoutResolver.nonOverlappingFrame(
                for: control.frame,
                avoiding: controls.compactMap { $0.id == identity || $0.isDecoration ? nil : $0.frame },
                in: currentCanvasLayoutSize
              ),
              let index = next.customButtons.firstIndex(where: { $0.id == id })
        else { return }

        next.customButtons[index].layout.centerX = adjustedFrame.midX / max(currentCanvasLayoutSize.width, 1)
        next.customButtons[index].layout.centerY = adjustedFrame.midY / max(currentCanvasLayoutSize.height, 1)
    }

    private func placeDecoration(id: UUID, in next: inout GamepadCustomization) {
        let identity = GamepadControlIdentity.custom(id)
        guard let index = next.customButtons.firstIndex(where: { $0.id == id }) else { return }
        if let selection = customization.resolvedControls(in: currentCanvasLayoutSize).first(where: { selectedControlIDs.contains($0.id) }) {
            next.customButtons[index].layout.centerX = selection.normalizedCenter.x
            next.customButtons[index].layout.centerY = selection.normalizedCenter.y
        } else if let control = next.resolvedControls(in: currentCanvasLayoutSize).first(where: { $0.id == identity }) {
            next.customButtons[index].layout.centerX = control.normalizedCenter.x
            next.customButtons[index].layout.centerY = control.normalizedCenter.y
        }
    }

    @discardableResult
    private func deleteSelectedControl() -> Bool {
        guard selectedControlIsEditable else { return false }

        switch selectedControlID {
        case .builtin(let button):
            return deleteBuiltInControl(button)
        case .custom(let id):
            return deleteCustomButton(id: id)
        case .system:
            return false
        case .controlBarItem(let item):
            var next = customization
            next.removeControlBarItem(item)
            applyCustomization(next, selecting: .system(.topBarActivation), undoActionName: "Remove Control Bar Item")
            return true
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
        let actionIDs = selectedProfileActionIDs
        guard actionIDs.count == 1,
              let profileID = actionIDs.first,
              let profile = profiles.first(where: { $0.id == profileID })
        else { return }
        beginRenamingProfile(profile)
    }

    private func beginRenamingProfile(_ profile: GamepadConfigurationProfile) {
        if profile.id != selectedProfileID {
            selectProfile(profile)
        } else {
            selectedProfileIDs.removeAll()
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
        duplicateProfiles(ids: selectedProfileActionIDs)
    }

    private func duplicateProfile(_ profile: GamepadConfigurationProfile) {
        duplicateProfiles(ids: [profile.id])
    }

    private func duplicateProfiles(ids: Set<UUID>) {
        commitSelectedProfileNameDraft()
        let sourceProfiles = profiles.filter { ids.contains($0.id) }
        guard !sourceProfiles.isEmpty else { return }

        let duplicates = sourceProfiles.map { source -> GamepadConfigurationProfile in
            var sourceProfile = source.normalized
            if source.id == selectedProfileID {
                sourceProfile.setCustomization(customization.normalized, for: selectedProfileOrientation)
            }
            var duplicate = sourceProfile.normalized
            duplicate.id = UUID()
            duplicate.name = "\(sourceProfile.name) Copy"
            duplicate.updatedAt = Date.currentMilliseconds
            return duplicate
        }

        profiles.append(contentsOf: duplicates)
        guard let firstDuplicate = duplicates.first else { return }
        selectedProfileID = firstDuplicate.id
        selectedProfileIDs = Set(duplicates.map(\.id))
        selectedProfileNameDraft = firstDuplicate.name
        isSelectedProfileExpanded = true
        selectKeypadInspector()
        applyCustomization(firstDuplicate.customization(for: selectedProfileOrientation))
        persistProfiles()
    }

    private func deleteSelectedProfile() {
        deleteProfiles(selectedProfileActionIDs)
    }

    private func deleteProfile(_ profile: GamepadConfigurationProfile) {
        deleteProfiles([profile.id])
    }

    private func deleteProfiles(_ ids: Set<UUID>) {
        commitSelectedProfileNameDraft()
        let validProfileIDs = Set(profiles.map(\.id))
        let removedIDs = ids.intersection(validProfileIDs)
        guard !removedIDs.isEmpty,
              let firstRemovedIndex = profiles.firstIndex(where: { removedIDs.contains($0.id) })
        else { return }

        let removedActiveProfile = removedIDs.contains(selectedProfileID)
        let removedActiveIndex = removedActiveProfile
            ? profiles.firstIndex(where: { $0.id == selectedProfileID }) ?? firstRemovedIndex
            : firstRemovedIndex
        let removedDefaultProfile = removedIDs.contains(defaultProfileID)
        let removedEveryProfile = removedIDs.count == profiles.count
        registerProfileUndoSnapshot(actionName: removedIDs.count == 1 ? "Delete Setup" : "Delete Setups")
        profiles.removeAll { removedIDs.contains($0.id) }
        selectedProfileIDs = normalizedProfileSelection(selectedProfileIDs.subtracting(removedIDs))

        if removedEveryProfile {
            let replacementProfile = GamepadConfigurationProfile(
                name: "Setup 1",
                customization: GamepadCustomization.blankCanvas
            )
            profiles = [replacementProfile]
            selectedProfileID = replacementProfile.id
            selectedProfileIDs.removeAll()
            defaultProfileID = replacementProfile.id
            selectedProfileNameDraft = replacementProfile.name
            isSelectedProfileExpanded = true
            selectKeypadInspector()
            applyCustomization(replacementProfile.customization(for: selectedProfileOrientation))
        } else if removedActiveProfile {
            let nextProfile = profiles[min(removedActiveIndex, profiles.count - 1)]
            selectedProfileID = nextProfile.id
            selectedProfileNameDraft = nextProfile.name
            isSelectedProfileExpanded = true
            selectKeypadInspector()
            if removedDefaultProfile {
                defaultProfileID = nextProfile.id
            }
            applyCustomization(nextProfile.customization(for: selectedProfileOrientation))
        } else {
            if removedDefaultProfile {
                defaultProfileID = selectedProfileID
            }
        }

        persistProfiles()
    }

    private func selectProfile(_ profile: GamepadConfigurationProfile, expandsDetails: Bool = true) {
        activateProfile(profile, expandsDetails: expandsDetails, selectionIDs: [])
    }

    private func activateProfile(
        _ profile: GamepadConfigurationProfile,
        expandsDetails: Bool = true,
        selectionIDs: Set<UUID>
    ) {
        commitSelectedProfileNameDraft()
        let nextProfile = profiles.first { $0.id == profile.id } ?? profile
        let wasSelectedProfile = selectedProfileID == nextProfile.id
        selectedProfileID = nextProfile.id
        selectedProfileIDs = normalizedProfileSelection(selectionIDs)
        selectedProfileNameDraft = nextProfile.name
        if expandsDetails {
            isSelectedProfileExpanded = true
        } else if !wasSelectedProfile {
            isSelectedProfileExpanded = false
        }
        selectKeypadInspector()
        applyCustomization(nextProfile.customization(for: selectedProfileOrientation))
        persistProfiles()
    }

    private func handleProfileClick(_ profile: GamepadConfigurationProfile, expandsDetails: Bool = true) {
        if isCommandProfileSelectionModifierActive {
            toggleProfileSelection(profile)
        } else {
            selectProfile(profile, expandsDetails: expandsDetails)
        }
    }

    private func toggleProfileSelection(_ profile: GamepadConfigurationProfile) {
        commitSelectedProfileNameDraft()
        let validProfileIDs = Set(profiles.map(\.id))
        guard validProfileIDs.contains(profile.id) else { return }

        selectedProfileIDs = GamepadProfileSelectionLogic.toggledExplicitSelection(
            profile.id,
            currentExplicitSelection: selectedProfileIDs,
            orderedProfileIDs: profiles.map(\.id)
        )
    }

    private var isCommandProfileSelectionModifierActive: Bool {
#if os(macOS)
        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.command)
#else
        return false
#endif
    }

    private var selectedProfileActionIDs: Set<UUID> {
        GamepadProfileSelectionLogic.actionIDs(
            explicitSelection: selectedProfileIDs,
            activeID: selectedProfileID,
            orderedProfileIDs: profiles.map(\.id)
        )
    }

    private func normalizedProfileSelection(_ ids: Set<UUID>) -> Set<UUID> {
        GamepadProfileSelectionLogic.normalizedExplicitSelection(ids, validProfileIDs: Set(profiles.map(\.id)))
    }

    private func profileContextSelectionIDs(for profile: GamepadConfigurationProfile) -> Set<UUID> {
        let validSelection = normalizedProfileSelection(selectedProfileIDs)
        return validSelection.contains(profile.id) ? validSelection : [profile.id]
    }

    private func canDeleteProfiles(_ ids: Set<UUID>) -> Bool {
        let validProfileIDs = Set(profiles.map(\.id))
        let deleteCount = ids.intersection(validProfileIDs).count
        return deleteCount > 0
    }

    private func profileSelectionFill(
        isActive: Bool,
        isSelected: Bool,
        defaultFill: Color = .clear
    ) -> Color {
        if isActive {
            return Geist.color(.background100, scheme: colorScheme)
        }
        if isSelected {
            return Geist.color(.gray100, scheme: colorScheme)
        }
        return defaultFill
    }

    private func profileSelectionStroke(isActive: Bool, isSelected: Bool) -> Color {
        if isActive {
            return Geist.color(.grayAlpha600, scheme: colorScheme)
        }
        if isSelected {
            return Geist.color(.blue700, scheme: colorScheme)
        }
        return Geist.color(.grayAlpha400, scheme: colorScheme)
    }

    private func profileDragItemProvider(for profile: GamepadConfigurationProfile) -> NSItemProvider {
        commitSelectedProfileNameDraft()
        let ids = profileDragIDs(for: profile)
        draggingProfileIDs = ids
        let payload = ids.map(\.uuidString).joined(separator: "\n")
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: Self.profileDragUTType.identifier, visibility: .ownProcess) { completion in
            completion(Data(payload.utf8), nil)
            return nil
        }
        return provider
    }

    private func profileDragIDs(for profile: GamepadConfigurationProfile) -> [UUID] {
        if selectedProfileIDs.contains(profile.id) {
            return profiles.map(\.id).filter { selectedProfileIDs.contains($0) }
        }

        selectProfile(profile, expandsDetails: false)
        return [profile.id]
    }

    private func moveDraggedProfiles(_ movingIDs: [UUID], targetProfileID: UUID?) {
        var uniqueMovingIDs: [UUID] = []
        var seenMovingIDs = Set<UUID>()
        for id in movingIDs where seenMovingIDs.insert(id).inserted {
            uniqueMovingIDs.append(id)
        }

        let movingIDSet = Set(uniqueMovingIDs)
        guard !movingIDSet.isEmpty else { return }
        if let targetProfileID, movingIDSet.contains(targetProfileID) { return }

        let movingProfiles = profiles.filter { movingIDSet.contains($0.id) }
        guard !movingProfiles.isEmpty else { return }

        let remainingProfiles = profiles.filter { !movingIDSet.contains($0.id) }
        let insertionIndex: Int
        if let targetProfileID,
           let targetIndex = remainingProfiles.firstIndex(where: { $0.id == targetProfileID }) {
            insertionIndex = targetIndex
        } else {
            insertionIndex = remainingProfiles.count
        }

        var nextProfiles = remainingProfiles
        nextProfiles.insert(contentsOf: movingProfiles, at: insertionIndex)
        guard nextProfiles.map(\.id) != profiles.map(\.id) else { return }

        profiles = nextProfiles
        selectedProfileIDs = normalizedProfileSelection(selectedProfileIDs.union(movingIDSet))
        persistProfiles()
    }

    private func finishProfileDrag() {
        draggingProfileIDs.removeAll()
    }

    private func toggleProfileRow(_ profile: GamepadConfigurationProfile, isSelected: Bool) {
        if isSelected {
            isSelectedProfileExpanded.toggle()
            selectKeypadInspector()
        } else {
            selectProfile(profile)
        }
    }

    private func profileRowAccessibilityHint(isSelected: Bool, isExpanded: Bool) -> String {
        if isSelected {
            return "Shows this keypad setup in the editor. Use the arrow to \(isExpanded ? "hide" : "show") setup details."
        }

        return "Selects and shows this keypad setup without opening details. Use the arrow to show setup details."
    }

    private func profileDisclosureAccessibilityHint(isSelected: Bool, isExpanded: Bool) -> String {
        if isSelected {
            return isExpanded ? "Hides the keypad setup details." : "Shows the keypad setup details."
        }

        return "Selects this keypad setup and shows its details."
    }

    private func setSelectedProfileAsDefault() {
        commitSelectedProfileNameDraft()
        defaultProfileID = selectedProfileID
        persistProfiles()
    }

    private func resetActiveConfiguration() {
        applyCustomization(.defaultValue, undoActionName: "Reset Keypad")
        selectComponent(.builtin(.jump))
        onReset?()
    }

    private func syncSelectedProfile(with newCustomization: GamepadCustomization, persistsImmediately: Bool = true) {
        guard let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        let normalizedCustomization = newCustomization.normalized
        var nextProfile = profiles[index]
        nextProfile.setCustomization(normalizedCustomization, for: selectedProfileOrientation)
        guard profiles[index] != nextProfile.normalized else { return }

        profiles[index] = nextProfile.normalized
        profiles[index].updatedAt = Date.currentMilliseconds
        if persistsImmediately {
            persistProfiles()
        }
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
        selectedProfileIDs = didChangeSelectedProfile
            ? []
            : normalizedProfileSelection(selectedProfileIDs)
        if didChangeSelectedProfile {
            isSelectedProfileExpanded = true
        }
        if didChangeSelectedProfile || !isProfileNameFieldFocused {
            syncSelectedProfileNameDraft()
        }
        if didChangeSelectedProfile {
            selectKeypadInspector()
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
        selectedProfileIDs = normalizedProfileSelection(selectedProfileIDs)
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

private struct GamepadEditorBlankSetupCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var isHoverPulseActive = false

    var onShowDefaultControls: () -> Void
    var onAddJoystick: () -> Void
    var onDrawButton: () -> Void
    var onShowTour: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .top, spacing: Geist.Spacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                        .fill(Geist.color(.blue100, scheme: colorScheme))
                        .frame(width: 48, height: 48)

                    Image(systemName: "hand.point.up.left.and.text")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))

                    if !accessibilityReduceMotion {
                        RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                            .stroke(Geist.color(.blue700, scheme: colorScheme), lineWidth: 1.5)
                            .frame(width: 48, height: 48)
                            .scaleEffect(isHoverPulseActive ? 1.32 : 1.0)
                            .opacity(isHoverPulseActive ? 0.02 : 0.55)
                    }
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Create your first keypad")
                        .geistTypography(.heading20)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("Start from a blank canvas. Add only the controls you need, then select each one to assign labels, shortcuts, and style.")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: Geist.Spacing.s2)], alignment: .leading, spacing: Geist.Spacing.s2) {
                GamepadEditorStarterStepCard(step: "1", title: "Add controls", text: "Use default buttons, a joystick, or draw a custom key.")
                GamepadEditorStarterStepCard(step: "2", title: "Bind actions", text: "Select an element and set its keyboard or gamepad output.")
                GamepadEditorStarterStepCard(step: "3", title: "Test on iPhone", text: "Pair your phone and the active setup syncs automatically.")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) {
                    starterButtons
                }

                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    starterButtons
                }
            }
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: 560, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .fill(Geist.color(.background100, scheme: colorScheme).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.12), radius: 24, x: 0, y: 14)
        .onAppear(perform: startPulseIfNeeded)
    }

    @ViewBuilder
    private var starterButtons: some View {
        Button(action: onShowDefaultControls) {
            Label("Show Default Controls", systemImage: "square.grid.3x3")
        }
        .geistButtonStyle(.primary, size: .small)

        Button(action: onAddJoystick) {
            Label("Add Joystick", systemImage: "circle.circle")
        }
        .geistButtonStyle(.secondary, size: .small)

        Button(action: onDrawButton) {
            Label("Draw Button", systemImage: "rectangle.roundedtop")
        }
        .geistButtonStyle(.secondary, size: .small)

        Button(action: onShowTour) {
            Label("Tour UI", systemImage: "sparkles")
        }
        .geistButtonStyle(.tertiary, size: .small)
    }

    private func startPulseIfNeeded() {
        guard !accessibilityReduceMotion else { return }
        withAnimation(.easeOut(duration: 1.45).repeatForever(autoreverses: false)) {
            isHoverPulseActive = true
        }
    }
}

private struct GamepadEditorStarterStepCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let step: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s2) {
            Text(step)
                .geistTypography(.label12)
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(Geist.color(.gray1000, scheme: colorScheme), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(text)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Geist.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct GamepadEditorFirstKeypadOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var isPulseActive = false

    var step: GamepadEditorFirstKeypadStep
    var targetRect: CGRect?
    var containerSize: CGSize
    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        let highlight = highlightedRect

        ZStack(alignment: .topLeading) {
            GamepadEditorSpotlightScrim(targetRect: highlight)

            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .stroke(Geist.color(.blue700, scheme: colorScheme), lineWidth: 2)
                .frame(width: highlight.width, height: highlight.height)
                .offset(x: highlight.minX, y: highlight.minY)

            if !accessibilityReduceMotion {
                RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                    .stroke(Geist.color(.blue700, scheme: colorScheme).opacity(0.58), lineWidth: 2)
                    .frame(width: highlight.width, height: highlight.height)
                    .scaleEffect(isPulseActive ? 1.08 : 1.0)
                    .opacity(isPulseActive ? 0.03 : 0.7)
                    .offset(x: highlight.minX, y: highlight.minY)
            }

            coachCard
                .frame(width: cardWidth)
                .offset(x: cardOrigin.x, y: cardOrigin.y)
        }
        .onAppear(perform: startPulseIfNeeded)
        .onChange(of: step) { _, _ in
            restartPulse()
        }
    }

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(spacing: Geist.Spacing.s2) {
                Text(step.eyebrow.uppercased())
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))

                Spacer(minLength: Geist.Spacing.s2)

                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .frame(width: 28, height: 28)
                        .background(Geist.color(.gray100, scheme: colorScheme), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip first keypad tour")
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text(step.title)
                    .geistTypography(.heading20)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.message)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Geist.Spacing.s2) {
                Button("Skip", action: onSkip)
                    .geistButtonStyle(.tertiary, size: .small)

                Spacer(minLength: Geist.Spacing.s2)

                Button(action: onNext) {
                    Label(step.nextTitle, systemImage: step.next == nil ? "checkmark" : "arrow.right")
                }
                .geistButtonStyle(.primary, size: .small)
            }
        }
        .padding(Geist.Spacing.s4)
        .background(Geist.color(.background100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.36 : 0.14), radius: 22, x: 0, y: 12)
    }

    private var highlightedRect: CGRect {
        let source = targetRect?.standardized ?? fallbackRect
        let padded = source.insetBy(dx: -12, dy: -12)
        let bounds = CGRect(origin: .zero, size: containerSize).insetBy(dx: 8, dy: 8)
        let clipped = padded.intersection(bounds)
        return clipped.isNull || clipped.isEmpty ? fallbackRect : clipped
    }

    private var fallbackRect: CGRect {
        switch step.target {
        case .setups:
            CGRect(x: 16, y: 24, width: min(280, max(180, containerSize.width * 0.26)), height: max(180, containerSize.height - 48))
        case .canvas:
            CGRect(x: max(24, containerSize.width * 0.30), y: max(48, containerSize.height * 0.18), width: max(220, containerSize.width * 0.40), height: max(180, containerSize.height * 0.46))
        case .toolbar:
            CGRect(x: max(40, containerSize.width * 0.35), y: max(80, containerSize.height - 120), width: max(260, containerSize.width * 0.30), height: 76)
        case .inspector:
            CGRect(x: max(24, containerSize.width - min(360, containerSize.width * 0.32) - 16), y: 24, width: min(360, max(220, containerSize.width * 0.32)), height: max(180, containerSize.height - 48))
        }
    }

    private var cardWidth: CGFloat {
        min(360, max(280, containerSize.width - 32))
    }

    private var cardOrigin: CGPoint {
        let highlight = highlightedRect
        let estimatedHeight: CGFloat = 236
        let wantsBelow = highlight.midY < containerSize.height * 0.52
        let rawY = wantsBelow ? highlight.maxY + 18 : highlight.minY - estimatedHeight - 18
        let rawX: CGFloat

        switch step.target {
        case .setups:
            rawX = highlight.maxX + 18
        case .inspector:
            rawX = highlight.minX - cardWidth - 18
        default:
            rawX = highlight.midX - cardWidth / 2
        }

        let maxX = max(16, containerSize.width - cardWidth - 16)
        let maxY = max(18, containerSize.height - estimatedHeight - 18)

        return CGPoint(
            x: min(max(rawX, 16), maxX),
            y: min(max(rawY, 18), maxY)
        )
    }

    private func startPulseIfNeeded() {
        guard !accessibilityReduceMotion else { return }
        withAnimation(.easeOut(duration: 1.35).repeatForever(autoreverses: false)) {
            isPulseActive = true
        }
    }

    private func restartPulse() {
        guard !accessibilityReduceMotion else { return }
        isPulseActive = false
        DispatchQueue.main.async {
            startPulseIfNeeded()
        }
    }
}

private struct GamepadEditorSpotlightScrim: View {
    @Environment(\.colorScheme) private var colorScheme
    var targetRect: CGRect

    var body: some View {
        Canvas { context, size in
            var path = Path(CGRect(origin: .zero, size: size))
            path.addRoundedRect(
                in: targetRect,
                cornerSize: CGSize(width: Geist.Radius.lg, height: Geist.Radius.lg),
                style: .continuous
            )
            context.fill(
                path,
                with: .color(Geist.color(.background100, scheme: colorScheme).opacity(colorScheme == .dark ? 0.78 : 0.68)),
                style: FillStyle(eoFill: true)
            )
        }
        .ignoresSafeArea()
    }
}

private struct GamepadProfileDropDelegate: DropDelegate {
    let targetProfileID: UUID?
    @Binding var draggingProfileIDs: [UUID]
    let onMove: ([UUID], UUID?) -> Void
    let onDropEnded: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        !draggingProfileIDs.isEmpty
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard !draggingProfileIDs.isEmpty else { return false }
        onMove(draggingProfileIDs, targetProfileID)
        onDropEnded()
        return true
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
    var onGroup: () -> Bool
    var onNudge: (GamepadEditorNudgeDirection, Bool) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onDelete: onDelete, onUndo: onUndo, onRedo: onRedo, onGroup: onGroup, onNudge: onNudge)
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
        context.coordinator.onGroup = onGroup
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
        var onGroup: () -> Bool
        var onNudge: (GamepadEditorNudgeDirection, Bool) -> Bool
        weak var view: NSView?
        private var monitor: Any?

        init(
            onDelete: @escaping () -> Bool,
            onUndo: @escaping () -> Bool,
            onRedo: @escaping () -> Bool,
            onGroup: @escaping () -> Bool,
            onNudge: @escaping (GamepadEditorNudgeDirection, Bool) -> Bool
        ) {
            self.onDelete = onDelete
            self.onUndo = onUndo
            self.onRedo = onRedo
            self.onGroup = onGroup
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

            if Self.isGroupEvent(event) {
                return onGroup() ? nil : event
            }

            if let nudgeDirection = Self.nudgeDirection(for: event) {
                return onNudge(nudgeDirection, Self.isShiftModifierEvent(event)) ? nil : event
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
                && !flags.contains(.control)
        }

        private static func isShiftModifierEvent(_ event: NSEvent) -> Bool {
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

        private static func isGroupEvent(_ event: NSEvent) -> Bool {
            guard !event.isARepeat else { return false }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.contains(.command),
                  !flags.contains(.shift),
                  !flags.contains(.option),
                  !flags.contains(.control)
            else { return false }
            return event.charactersIgnoringModifiers?.lowercased() == "g"
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

private final class GamepadResolvedControlsCache {
    private var cachedCustomization: GamepadCustomization?
    private var cachedLayoutSize: CGSize?
    private var cachedDefaultLabels: [GameButton: String] = [:]
    private var cachedControls: [GamepadResolvedControl] = []

    func controls(
        for customization: GamepadCustomization,
        in layoutSize: CGSize,
        defaultLabelProvider: ((GameButton) -> String?)?
    ) -> [GamepadResolvedControl] {
        let defaultLabels = Self.defaultLabels(from: defaultLabelProvider)
        if cachedLayoutSize == layoutSize,
           cachedDefaultLabels == defaultLabels,
           cachedCustomization == customization {
            return cachedControls
        }

        let controls = customization.resolvedControls(in: layoutSize) { button in
            defaultLabels[button]
        }
        cachedCustomization = customization
        cachedLayoutSize = layoutSize
        cachedDefaultLabels = defaultLabels
        cachedControls = controls
        return controls
    }

    private static func defaultLabels(from provider: ((GameButton) -> String?)?) -> [GameButton: String] {
        guard let provider else { return [:] }
        var labels: [GameButton: String] = [:]
        labels.reserveCapacity(GameButton.builtInControls.count)
        for button in GameButton.builtInControls {
            if let label = provider(button) {
                labels[button] = label
            }
        }
        return labels
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
    var groupedSelectionForControl: (GamepadControlIdentity) -> Set<GamepadControlIdentity>? = { _ in nil }
    var onBeginUndoableChange: (String) -> Void = { _ in }
    var onEndEditingGesture: () -> Void = {}
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
    @State private var resolvedControlsCache = GamepadResolvedControlsCache()

    private static let dragActivationDistance: CGFloat = 4
    private static let minimumDrawnButtonSize = GamepadButtonCustomization.minimumDimension
    private static let defaultDrawnButtonSize = CGSize(width: 76, height: 76)

    var body: some View {
        GeometryReader { proxy in
            let resolvedLayoutSize = resolvedLayoutSize(for: proxy.size)
            let resolvedDisplayScale = max(displayScale, 0.001)
            let controls = resolvedControlsCache.controls(
                for: customization,
                in: resolvedLayoutSize,
                defaultLabelProvider: defaultLabelProvider
            )
            let selectedDesignerControls = currentSelectedControls(in: controls)
            let isMultiSelection = selectedDesignerControls.count > 1
            let selectedControlBarItem = selectedControlIDs.lazy.compactMap { identity -> GamepadControlBarItem? in
                if case .controlBarItem(let item) = identity { return item }
                return nil
            }.first

            ZStack(alignment: .topLeading) {
                GamepadFillShapeLayer(
                    shape: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous),
                    fillStyle: customization.keypadBackgroundFillStyle(scheme: colorScheme)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    guard activeTool == .select else { return }
                    clearSelection()
                }
                layoutGrid(canvasSize: resolvedLayoutSize, displayScale: resolvedDisplayScale)

                ForEach(controls) { control in
                    let isSelected = isControlSelectionActive && selectedControlIDs.contains(control.id)

                    GamepadDesignerButton(
                        control: control,
                        customization: customization,
                        isSelected: isSelected,
                        showsSelectionHandles: !isMultiSelection,
                        displayScale: resolvedDisplayScale,
                        selectedControlBarItem: selectedControlBarItem,
                        onSelectControlBarItem: { item in
                            selectOnly(.controlBarItem(item))
                        },
                        onMoveControlBarItem: { item, offset in
                            reorderControlBarItem(item, by: offset)
                        },
                        onResizeChanged: { corner, value in
                            selectOnly(control.id)
                            guard !control.isLocationLocked else { return }
                            updateResize(corner, value: value, control: control, controls: controls, canvasSize: resolvedLayoutSize, displayScale: resolvedDisplayScale)
                        },
                        onResizeEnded: {
                            activeResize = nil
                            onEndEditingGesture()
                        },
                        onRadiusChanged: { value in
                            selectOnly(control.id)
                            updateRadius(value, control: control, displayScale: resolvedDisplayScale)
                        },
                        onRadiusEnded: {
                            activeRadiusDrag = nil
                            onEndEditingGesture()
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
                                if !dragState.didRegisterUndo {
                                    onBeginUndoableChange(dragState.snapshots.count > 1 ? "Move Selection" : "Move Key")
                                    dragState.didRegisterUndo = true
                                }
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
                                onEndEditingGesture()
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
                            onEndEditingGesture()
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
                            updateGroupResize(corner, value: value, selectedControls: selectedDesignerControls, controls: controls, canvasSize: resolvedLayoutSize, displayScale: resolvedDisplayScale)
                        },
                        onResizeEnded: {
                            activeGroupResize = nil
                            onEndEditingGesture()
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
                    guard shouldTrackHoverState else {
                        clearHoverStateIfNeeded()
                        return
                    }

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
                    let nextHoveredControlID = controlIDUnderPointer(
                        at: location,
                        in: controls,
                        canvasSize: resolvedLayoutSize,
                        displayScale: resolvedDisplayScale
                    )
                    let nextIsHoveringCanvasBackground = pointerIsInsideCanvas && hoveredAnyControlID == nil
                    if hoveredControlID != nextHoveredControlID {
                        hoveredControlID = nextHoveredControlID
                    }
                    if isHoveringCanvasBackground != nextIsHoveringCanvasBackground {
                        isHoveringCanvasBackground = nextIsHoveringCanvasBackground
                    }
                case .ended:
                    clearHoverStateIfNeeded()
                }
            }
        }
    }

    private var shouldTrackHoverState: Bool {
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

    private var shouldShowMeasurementOverlay: Bool {
        shouldTrackHoverState
    }

    private func clearHoverStateIfNeeded() {
        if hoveredControlID != nil {
            hoveredControlID = nil
        }
        if isHoveringCanvasBackground {
            isHoveringCanvasBackground = false
        }
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
        guard !isControlSelectionActive || selectedControlID != identity || selectedControlIDs != [identity] else { return }
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
        } else if let groupSelection = groupedSelectionForControl(identity), groupSelection.count > 1 {
            nextSelectionIDs = groupSelection
        } else {
            nextSelectionIDs = [identity]
        }

        selectedControlID = identity
        selectedControlIDs = nextSelectionIDs
        isControlSelectionActive = true
        return nextSelectionIDs
    }

    private func reorderControlBarItem(_ item: GamepadControlBarItem, by offset: Int) {
        let items = customization.normalized.controlBarItems
        guard let sourceIndex = items.firstIndex(of: item) else { return }
        let destination = min(max(sourceIndex + offset, 0), max(items.count - 1, 0))
        guard destination != sourceIndex else { return }

        onBeginUndoableChange("Reorder Control Bar")
        var next = customization
        next.moveControlBarItem(item, to: destination)
        customization = next.normalized
        selectOnly(.controlBarItem(item))
        onEndEditingGesture()
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
                onEndEditingGesture()
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

        onBeginUndoableChange("Add Shape")

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
            RoundedRectangle(cornerRadius: GamepadButtonCustomization.capsulePreviewCornerRadius, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: GamepadButtonCustomization.capsulePreviewCornerRadius, style: .continuous).stroke(stroke, lineWidth: lineWidth))
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

    private func layoutGrid(canvasSize: CGSize, displayScale: CGFloat) -> some View {
        let grid = customization.designMetadata?.grid.normalized ?? .defaultValue
        return ZStack {
            if grid.showsGrid {
                Canvas { context, _ in
                    var path = Path()
                    let spacing = max(4, grid.gridSize * max(displayScale, 0.001))
                    var x: CGFloat = 0
                    while x <= canvasSize.width * displayScale {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: canvasSize.height * displayScale))
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y <= canvasSize.height * displayScale {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: canvasSize.width * displayScale, y: y))
                        y += spacing
                    }
                    context.stroke(path, with: .color(Geist.color(.grayAlpha400, scheme: colorScheme).opacity(0.42)), lineWidth: 0.75)
                }
            }

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
        .opacity(grid.showsGrid ? 0.64 : 0.45)
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

    private func snappedFrame(
        _ frame: CGRect,
        excluding identities: Set<GamepadControlIdentity>,
        controls: [GamepadResolvedControl],
        canvasSize: CGSize,
        displayScale: CGFloat
    ) -> GamepadAlignmentSnapResult {
        let grid = customization.designMetadata?.grid.normalized ?? .defaultValue
        let objectResult: GamepadAlignmentSnapResult
        if grid.snapToObjects {
            objectResult = GamepadAlignmentSnapSolver.snappedFrame(
                for: frame,
                targetFrames: alignmentTargetFrames(excluding: identities, in: controls),
                canvasSize: canvasSize,
                displayScale: displayScale
            )
        } else {
            objectResult = GamepadAlignmentSnapResult(frame: frame.standardized, guide: nil)
        }
        guard grid.snapToGrid else { return objectResult }
        return GamepadAlignmentSnapResult(frame: snappedToGrid(objectResult.frame, gridSize: grid.gridSize, canvasSize: canvasSize), guide: objectResult.guide)
    }

    private func snappedToGrid(_ frame: CGRect, gridSize: CGFloat, canvasSize: CGSize) -> CGRect {
        let safeGridSize = max(1, gridSize)
        let center = CGPoint(
            x: (frame.midX / safeGridSize).rounded() * safeGridSize,
            y: (frame.midY / safeGridSize).rounded() * safeGridSize
        )
        let origin = CGPoint(
            x: Self.clamp(center.x - frame.width / 2, lower: 0, upper: max(0, canvasSize.width - frame.width)),
            y: Self.clamp(center.y - frame.height / 2, lower: 0, upper: max(0, canvasSize.height - frame.height))
        )
        return CGRect(origin: origin, size: frame.size).standardized
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
        let snapResult = snappedFrame(
            preferredFrame,
            excluding: selectedControlIDs,
            controls: controls,
            canvasSize: canvasSize,
            displayScale: displayScale
        )
        let adjustedFrame = nonOverlappingFrame(for: snapResult.frame, excluding: control.id, controls: controls, canvasSize: canvasSize) ?? control.frame
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
        let snapResult = snappedFrame(
            proposedBounds,
            excluding: selectedIDs,
            controls: controls,
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
        let existingFrames = existingControlFrames(excluding: selectedIDs, controls: controls)
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

    private func existingControlFrames(excluding identities: Set<GamepadControlIdentity>, controls: [GamepadResolvedControl]) -> [CGRect] {
        controls.compactMap { control in
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

    private func nonOverlappingFrame(for preferredFrame: CGRect, excluding identity: GamepadControlIdentity, controls: [GamepadResolvedControl], canvasSize: CGSize) -> CGRect? {
        GamepadLayoutResolver.nonOverlappingFrame(
            for: preferredFrame,
            avoiding: existingControlFrames(excluding: [identity], controls: controls),
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
        controls: [GamepadResolvedControl],
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
        let minWidth = GamepadButtonCustomization.minimumDimension(forBaseDimension: baseWidth)
        let minHeight = GamepadButtonCustomization.minimumDimension(forBaseDimension: baseHeight)
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
            avoiding: existingControlFrames(excluding: [control.id], controls: controls)
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
        controls: [GamepadResolvedControl],
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
            controls: controls,
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
                width: GamepadButtonCustomization.minimumDimension(forBaseDimension: baseWidth),
                height: GamepadButtonCustomization.minimumDimension(forBaseDimension: baseHeight)
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
        controls: [GamepadResolvedControl],
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
        let existingFrames = existingControlFrames(excluding: state.selectionIDs, controls: controls)
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
            case .system(.topBarActivation):
                next.topBarActivationRegion.widthScale = frame.width / control.baseSize.width
                next.topBarActivationRegion.heightScale = frame.height / control.baseSize.height
                next.topBarActivationRegion.centerX = center.x / max(canvasSize.width, 1)
                next.topBarActivationRegion.centerY = center.y / max(canvasSize.height, 1)
            case .controlBarItem:
                continue
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
        let maximumVisualRadius = max(GamepadButtonCustomization.minimumCornerRadius, min(control.size.width, control.size.height) / 2)
        if activeRadiusDrag?.identity != control.id {
            activeRadiusDrag = GamepadControlRadiusDragState(identity: control.id, startRadius: min(currentRadii.averageRadius, maximumVisualRadius))
        }

        guard var radiusDrag = activeRadiusDrag else { return }
        let diagonalDelta = (value.translation.width + value.translation.height) / 2 / max(displayScale, 0.001)
        let nextRadius = Self.clamp(radiusDrag.startRadius + diagonalDelta, lower: GamepadButtonCustomization.minimumCornerRadius, upper: maximumVisualRadius)
        guard abs(nextRadius - currentRadii.averageRadius) > 0.05 else { return }
        if !radiusDrag.didRegisterUndo {
            onBeginUndoableChange("Round Corners")
            radiusDrag.didRegisterUndo = true
            activeRadiusDrag = radiusDrag
        }

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
        case .system(.topBarActivation):
            customization.topBarActivationRegion.normalized
        case .controlBarItem(let item):
            customization.controlBarItemCustomization(for: item)
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
        case .system(.topBarActivation):
            mutate(&next.topBarActivationRegion)
        case .controlBarItem(let item):
            var appearance = next.controlBarItemCustomization(for: item)
            mutate(&appearance)
            next.setControlBarItemCustomization(appearance, for: item)
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
    var didRegisterUndo = false
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
    var didRegisterUndo = false
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

private struct GamepadControlRotationOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    let control: GamepadResolvedControl
    let displayScale: CGFloat
    let onRotationChanged: (DragGesture.Value) -> Void
    let onRotationEnded: () -> Void

    private static let handleHitSize: CGFloat = 32
    private static let handleIconFrame: CGFloat = 16
    private static let handleTopInset: CGFloat = 4

    private var safeDisplayScale: CGFloat {
        max(displayScale, 0.001)
    }

    private var visualSize: CGSize {
        CGSize(width: max(1, control.size.width * safeDisplayScale), height: max(1, control.size.height * safeDisplayScale))
    }

    private var handlePosition: CGPoint {
        CGPoint(
            x: visualSize.width / 2,
            y: min(Self.handleTopInset + Self.handleHitSize / 2, max(visualSize.height / 2, 1))
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            rotationHandle
                .position(handlePosition)
        }
        .frame(width: visualSize.width, height: visualSize.height)
        .rotationEffect(.degrees(control.rotationDegrees))
        .accessibilityElement(children: .contain)
    }

    private var rotationHandle: some View {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Geist.color(.blue700, scheme: colorScheme))
            .frame(width: Self.handleIconFrame, height: Self.handleIconFrame)
            .frame(width: Self.handleHitSize, height: Self.handleHitSize)
            .contentShape(Rectangle())
            .rotationEffect(.degrees(-control.rotationDegrees))
            .gamepadRotationCursor()
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
                    .onChanged(onRotationChanged)
                    .onEnded { _ in onRotationEnded() }
            )
            .accessibilityLabel(Text("Rotate selected component"))
            .accessibilityHint(Text("Press and drag this handle to rotate it"))
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
    var selectedControlBarItem: GamepadControlBarItem? = nil
    var onSelectControlBarItem: ((GamepadControlBarItem) -> Void)? = nil
    var onMoveControlBarItem: ((GamepadControlBarItem, Int) -> Void)? = nil
    let onResizeChanged: (GamepadResizeHandleCorner, DragGesture.Value) -> Void
    let onResizeEnded: () -> Void
    let onRadiusChanged: (DragGesture.Value) -> Void
    let onRadiusEnded: () -> Void

    var body: some View {
        ZStack {
            GamepadRenderedControlFace(
                control: control,
                customization: customization,
                state: .normal,
                selectedControlBarItem: selectedControlBarItem,
                onSelectControlBarItem: onSelectControlBarItem,
                onMoveControlBarItem: onMoveControlBarItem
            )

            if isSelected {
                background(isSelected: true)
                    .foregroundStyle(.clear)
            }

            if isSelected && showsSelectionHandles {
                selectionHandles
            }
        }
        .frame(width: control.size.width, height: control.size.height)
        .contentShape(Rectangle())
        .shadow(
            color: isSelected ? Color.black.opacity(0.12 * resolvedShadowStrength) : .clear,
            radius: isSelected ? 5 * max(0.25, resolvedShadowStrength) : 0,
            x: 0,
            y: isSelected ? 3 * resolvedShadowStrength : 0
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

    private var resolvedPresentation: GamepadResolvedControlPresentation {
        customization.resolvedPresentation(for: control, state: .normal, scheme: colorScheme)
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
        let knobFillColor = control.layoutCustomization.joystickKnobFill(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let knobStrokeColor = control.layoutCustomization.joystickKnobStroke(accentStyle: resolvedAccentStyle, isPressed: false, scheme: colorScheme)
        let isThumbstick = control.layoutCustomization.joystickVisualStyle == .thumbstick
        let knobRatio: CGFloat = isThumbstick ? 0.72 : 0.34

        return ZStack {
            if !isThumbstick {
                Circle()
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1 * inverseDisplayScale)
                    .frame(width: control.size.width * 0.70, height: control.size.height * 0.70)
            }
            Circle()
                .fill(knobFillColor)
                .overlay(Circle().stroke(knobStrokeColor, lineWidth: 1 * inverseDisplayScale))
                .frame(width: min(control.size.width, control.size.height) * knobRatio, height: min(control.size.width, control.size.height) * knobRatio)

            if customization.showsButtonLabels && !isThumbstick {
                Text(control.label)
                    .geistTypography(control.size.width <= 72 ? .button12 : .button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.48)
                    .foregroundStyle(resolvedPresentation.foregroundSwiftUIColor)
                    .padding(.horizontal, 4)
                    .offset(y: control.size.height * (isThumbstick ? 0.58 : 0.34))
            }
        }
        .allowsHitTesting(false)
    }

    private var trackpadFace: some View {
        let foreground = resolvedPresentation.foregroundSwiftUIColor
        return ZStack {
            RoundedRectangle(cornerRadius: max(5, min(control.size.width, control.size.height) * 0.08), style: .continuous)
                .stroke(foreground.opacity(0.24), lineWidth: 1 * inverseDisplayScale)
                .padding(max(5, 10 * inverseDisplayScale))

            HStack(spacing: max(5, 9 * inverseDisplayScale)) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: max(12, min(control.size.width, control.size.height) * 0.18), weight: .semibold))
                if customization.showsButtonLabels {
                    Text(control.label)
                        .geistTypography(control.size.width <= 96 ? .button12 : .button14)
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                }
            }
            .foregroundStyle(foreground.opacity(0.82))

            HStack(spacing: max(4, 7 * inverseDisplayScale)) {
                Capsule().fill(foreground.opacity(0.34))
                Capsule().fill(foreground.opacity(0.18))
            }
            .frame(width: control.size.width * 0.34, height: max(3, 5 * inverseDisplayScale))
            .offset(y: control.size.height * 0.36)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func background(isSelected: Bool) -> some View {
        let presentation = resolvedPresentation
        let fillStyle: GamepadFillStyle = isSelected ? .solid(GamepadRGBAColor(red: 0, green: 0, blue: 0, alpha: 0)) : presentation.fillStyle
        let strokeColor = isSelected ? Geist.color(.blue700, scheme: colorScheme) : presentation.strokeSwiftUIColor
        let lineWidth: CGFloat = isSelected ? 3 : presentation.strokeWidth

        switch control.shape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            let shape = UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay {
                    if !isSelected {
                        GamepadControlEffectOverlay(shape: shape, presentation: presentation)
                    }
                }
        case .polygon:
            let shape = GamepadRegularPolygonButtonShape(sides: 3)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay {
                    if !isSelected {
                        GamepadControlEffectOverlay(shape: shape, presentation: presentation)
                    }
                }
        case .star:
            let shape = GamepadStarButtonShape(points: 5)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay {
                    if !isSelected {
                        GamepadControlEffectOverlay(shape: shape, presentation: presentation)
                    }
                }
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
