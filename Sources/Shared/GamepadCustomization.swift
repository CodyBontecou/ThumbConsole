import Foundation
import SwiftUI

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
    public static let defaultValue = GamepadButtonCustomization()

    public var centerX: CGFloat?
    public var centerY: CGFloat?
    public var widthScale: CGFloat
    public var heightScale: CGFloat
    public var shape: GamepadButtonShapeStyle?

    public init(
        centerX: CGFloat? = nil,
        centerY: CGFloat? = nil,
        widthScale: CGFloat = 1.0,
        heightScale: CGFloat = 1.0,
        shape: GamepadButtonShapeStyle? = nil
    ) {
        self.centerX = centerX
        self.centerY = centerY
        self.widthScale = widthScale
        self.heightScale = heightScale
        self.shape = shape
    }

    var normalized: GamepadButtonCustomization {
        var copy = self
        copy.centerX = copy.centerX.map { Self.clamp($0, lower: 0, upper: 1) }
        copy.centerY = copy.centerY.map { Self.clamp($0, lower: 0, upper: 1) }
        copy.widthScale = Self.clamp(copy.widthScale, lower: Self.minimumScale, upper: Self.maximumScale)
        copy.heightScale = Self.clamp(copy.heightScale, lower: Self.minimumScale, upper: Self.maximumScale)
        return copy
    }

    var isDefault: Bool {
        centerX == nil
            && centerY == nil
            && abs(widthScale - 1.0) < 0.001
            && abs(heightScale - 1.0) < 0.001
            && shape == nil
    }

    var hasCustomPosition: Bool {
        centerX != nil || centerY != nil
    }

    func resolvedShape(defaultShape: GamepadButtonShapeStyle) -> GamepadButtonShapeStyle {
        shape ?? defaultShape
    }

    static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
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
        !buttonCustomizations.isEmpty || !customButtons.isEmpty
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
    let isCustom: Bool
}

extension GamepadCustomization {
    func resolvedControls(in canvasSize: CGSize) -> [GamepadResolvedControl] {
        GamepadLayoutResolver.resolvedControls(for: self, in: canvasSize)
    }
}

private enum GamepadLayoutResolver {
    static func resolvedControls(for customization: GamepadCustomization, in canvasSize: CGSize) -> [GamepadResolvedControl] {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return [] }

        let builtinControls = GameButton.builtInControls.map { button -> GamepadResolvedControl in
            let buttonCustomization = customization.buttonCustomization(for: button)
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
                isCustom: false
            )
        }

        let customControls = customization.customButtons.map { customButton -> GamepadResolvedControl in
            let normalizedButton = customButton.normalized
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
                isCustom: true
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

private struct GamepadEditorConfigurationProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var customization: GamepadCustomization
    var updatedAt: Int64

    init(
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

    var normalized: GamepadEditorConfigurationProfile {
        var copy = self
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = trimmedName.isEmpty ? "Untitled" : trimmedName
        copy.customization = customization.normalized
        return copy
    }
}

private enum GamepadEditorConfigurationProfilePersistence {
    struct LoadedState {
        let profiles: [GamepadEditorConfigurationProfile]
        let activeProfileID: UUID
    }

    private struct StoredState: Codable {
        var profiles: [GamepadEditorConfigurationProfile]
        var activeProfileID: UUID?
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
                    let currentProfile = GamepadEditorConfigurationProfile(
                        name: "Current Setup",
                        customization: activeCustomization
                    )
                    profiles.insert(currentProfile, at: 0)
                    activeProfileID = currentProfile.id
                }

                return LoadedState(profiles: profiles, activeProfileID: activeProfileID)
            }
        }

        let profiles = defaultProfiles(activeCustomization: activeCustomization)
        return LoadedState(profiles: profiles, activeProfileID: profiles[0].id)
    }

    static func save(_ profiles: [GamepadEditorConfigurationProfile], activeProfileID: UUID) {
        let normalizedProfiles = normalizedUniqueProfiles(profiles)
        guard !normalizedProfiles.isEmpty,
              let data = try? JSONEncoder().encode(
                StoredState(profiles: normalizedProfiles, activeProfileID: activeProfileID)
              )
        else { return }

        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func normalizedUniqueProfiles(_ profiles: [GamepadEditorConfigurationProfile]) -> [GamepadEditorConfigurationProfile] {
        var seenIDs = Set<UUID>()
        return profiles.compactMap { profile in
            let normalizedProfile = profile.normalized
            guard seenIDs.insert(normalizedProfile.id).inserted else { return nil }
            return normalizedProfile
        }
    }

    private static func defaultProfiles(activeCustomization: GamepadCustomization) -> [GamepadEditorConfigurationProfile] {
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
            GamepadEditorConfigurationProfile(name: "Current Setup", customization: activeCustomization),
            GamepadEditorConfigurationProfile(name: "Navigation Left", customization: standard),
            GamepadEditorConfigurationProfile(name: "Actions Left", customization: southpaw),
            GamepadEditorConfigurationProfile(name: "Large Blue", customization: largeBlue),
            GamepadEditorConfigurationProfile(name: "Compact Minimal", customization: compact)
        ]
    }
}

private enum GamepadEditorTab: String, CaseIterable, Identifiable {
    case color
    case shape
    case labels
    case keybinds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .color: "Color"
        case .shape: "Shape"
        case .labels: "Labels"
        case .keybinds: "Shortcuts"
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
    private let onReset: (() -> Void)?
    private let keyBindingsContent: AnyView?

    @State private var selectedControlID: GamepadControlIdentity
    @State private var selectedTab: GamepadEditorTab
    @State private var profiles: [GamepadEditorConfigurationProfile]
    @State private var selectedProfileID: UUID

    init(
        customization: Binding<GamepadCustomization>,
        showsPreview: Bool = true,
        onReset: (() -> Void)? = nil,
        keyBindingsContent: AnyView? = nil
    ) {
        let loadedProfiles = GamepadEditorConfigurationProfilePersistence.load(
            activeCustomization: customization.wrappedValue
        )

        self._customization = customization
        self.showsPreview = showsPreview
        self.onReset = onReset
        self.keyBindingsContent = keyBindingsContent
        self._selectedControlID = State(initialValue: .builtin(.jump))
        self._selectedTab = State(initialValue: .color)
        self._profiles = State(initialValue: loadedProfiles.profiles)
        self._selectedProfileID = State(initialValue: loadedProfiles.activeProfileID)
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
        .onChange(of: customization) { _, newValue in
            syncSelectedProfile(with: newValue)
        }
    }

    private var wideEditor: some View {
        HStack(spacing: 0) {
            configurationSidebar
                .frame(width: 236)

            Divider()

            canvasStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            inspectorSidebar
                .frame(width: 340)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Geist.color(.background100, scheme: colorScheme))
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

            Divider()

            configurationFooter
                .padding(Geist.Spacing.s3)
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

            configurationFooter
        }
        .geistPanel(padding: Geist.Spacing.s4, radius: Geist.Radius.md, raised: false)
    }

    @ViewBuilder
    private func profileRow(_ profile: GamepadEditorConfigurationProfile) -> some View {
        let isSelected = profile.id == selectedProfileID

        Button {
            selectProfile(profile)
        } label: {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                HStack(spacing: Geist.Spacing.s2) {
                    Text(profile.name)
                        .geistTypography(.heading14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: Geist.Spacing.s1)

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
    }

    @ViewBuilder
    private func profileChip(_ profile: GamepadEditorConfigurationProfile) -> some View {
        let isSelected = profile.id == selectedProfileID

        Button {
            selectProfile(profile)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .geistTypography(.heading14)
                    .lineLimit(1)
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
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Geist.Spacing.s2) {
                    profileManagementButtons
                }
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    profileManagementButtons
                }
            }

            Button("Reset Current Setup") {
                resetActiveConfiguration()
            }
            .geistButtonStyle(.tertiary, size: .small)
        }
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
            let availableWidth = max(280, proxy.size.width - Geist.Spacing.s8)
            let availableHeight = max(220, proxy.size.height - 166)
            let canvasWidth = min(availableWidth, availableHeight * 16 / 9)
            let canvasHeight = min(availableHeight, canvasWidth * 9 / 16)

            VStack(spacing: Geist.Spacing.s4) {
                canvasHeader

                Spacer(minLength: Geist.Spacing.s2)

                GamepadLayoutDesigner(customization: editorBinding, selectedControlID: $selectedControlID)
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

                Spacer(minLength: Geist.Spacing.s2)

                canvasActionBar
            }
            .padding(Geist.Spacing.s6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Geist.color(.background100, scheme: colorScheme))
        }
    }

    private var canvasHeader: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s4) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(selectedProfile?.name ?? "Keypad")
                    .geistTypography(.heading24)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .lineLimit(1)
                Text("Drag controls on the canvas. Use the inspector to tune colors, shapes, labels, and shortcuts.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Geist.Spacing.s2)

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

    private var canvasActionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Geist.Spacing.s3) {
                layoutButtons
            }
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                layoutButtons
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var layoutButtons: some View {
        Button {
            let id = UUID()
            update { $0.addCustomButton(id: id) }
            selectedControlID = .custom(id)
            selectedTab = .shape
        } label: {
            Label("Add Custom Key", systemImage: "plus.circle")
        }
        .geistButtonStyle(.primary, size: .small)
        .disabled(customization.customButtons.count >= GamepadCustomization.maximumCustomButtons)

        Button("Reset Key Layout") {
            update { $0.resetButtonLayout() }
            selectedControlID = .builtin(.jump)
        }
        .geistButtonStyle(.secondary, size: .small)
        .disabled(!customization.usesFreeformLayout)
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
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text("Inspector")
                    .geistTypography(.heading20)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(profileSubtitle(for: customization))
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .lineLimit(2)
            }

            GeistSegmentedPicker(title: "Editor Tab", options: GamepadEditorTab.allCases, selection: $selectedTab) { tab in
                tab.title
            }
        }
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch selectedTab {
        case .color:
            VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                layoutSection
                Divider()
                appearanceSection
            }
        case .shape:
            selectedButtonSection
        case .labels:
            labelsSection
        case .keybinds:
            if let keyBindingsContent {
                keyBindingsContent
            } else {
                keybindsPlaceholder
            }
        }
    }

    private var keybindsPlaceholder: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Shortcuts")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            Text("Connect to PocketPad Mac and open its Keypad editor to record hardware shortcuts for each virtual button.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Layout")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            GeistSegmentedPicker(title: "Layout", options: GamepadLayoutMode.allCases, selection: binding(\.layoutMode)) { mode in
                mode.displayName
            }

            Text(customization.layoutMode.description)
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Color & Scale")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            GeistSegmentedPicker(title: "Control Size", options: GamepadControlScale.allCases, selection: binding(\.controlScale)) { scale in
                scale.displayName
            }

            HStack(spacing: Geist.Spacing.s3) {
                Text("Accent")
                    .geistTypography(.label13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                Spacer()
                GeistMenuPicker(title: "Accent", options: GamepadAccentStyle.allCases, selection: binding(\.accentStyle)) { style in
                    style.displayName
                }
                .frame(minWidth: 140)
            }

            GeistCheckboxToggle(title: "Show Key Labels", isOn: binding(\.showsButtonLabels))
        }
    }

    private var selectedButtonSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Selected Control")
                        .geistTypography(.heading14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text(selectedControlTitle)
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }

                Spacer()

                Button("Reset Selected") {
                    resetSelectedControl()
                }
                .geistButtonStyle(.tertiary, size: .small)
            }

            controlSelectionPicker

            if case .custom(let id) = selectedControlID, customButton(id: id) != nil {
                customButtonControls(id: id)
            }

            GeistSegmentedPicker(title: "Shape", options: GamepadButtonShapeStyle.allCases, selection: shapeBinding(for: selectedControlID)) { shape in
                shape.displayName
            }

            sizeSlider(title: "Width", value: widthScaleBinding(for: selectedControlID), currentValue: widthScaleValue(for: selectedControlID))
            sizeSlider(title: "Height", value: heightScaleBinding(for: selectedControlID), currentValue: heightScaleValue(for: selectedControlID))

            if case .custom(let id) = selectedControlID, customButton(id: id) != nil {
                Button("Delete Custom Key") {
                    update { $0.removeCustomButton(id: id) }
                    selectedControlID = .builtin(.jump)
                }
                .geistButtonStyle(.error, size: .small)
            }
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
        HStack(spacing: Geist.Spacing.s3) {
            Text(title)
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 52, alignment: .leading)
            Slider(value: value, in: Double(GamepadButtonCustomization.minimumScale)...Double(GamepadButtonCustomization.maximumScale))
            Text("\(Int((currentValue * 100).rounded()))%")
                .geistTypography(.label12Mono)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 48, alignment: .trailing)
        }
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Key Labels")
                        .geistTypography(.heading14)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("Leave a field blank to use the default label.")
                        .geistTypography(.copy13)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }

                Spacer()

                Button("Reset Labels") {
                    update { $0.resetLabels() }
                }
                .geistButtonStyle(.tertiary, size: .small)
                .disabled(customization.labelOverrides.isEmpty)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: Geist.Spacing.s3)], alignment: .leading, spacing: Geist.Spacing.s3) {
                ForEach(GameButton.allCases) { button in
                    VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                        Text(button.displayName)
                            .geistTypography(.label12)
                            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        TextField(
                            GamepadCustomization.defaultVisualLabel(for: button),
                            text: labelBinding(for: button)
                        )
                        .geistInput(size: .small)
                    }
                }
            }
        }
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

    private var selectedProfile: GamepadEditorConfigurationProfile? {
        profiles.first { $0.id == selectedProfileID }
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
            update { $0.setButtonCustomization(.defaultValue, for: button) }
        case .custom(let id):
            updateCustomButton(id: id) {
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
        let profile = GamepadEditorConfigurationProfile(
            name: "Setup \(profiles.count + 1)",
            customization: GamepadCustomization.defaultValue
        )
        profiles.append(profile)
        selectedProfileID = profile.id
        selectedControlID = .builtin(.jump)
        applyCustomization(profile.customization)
        persistProfiles()
    }

    private func duplicateProfile() {
        let sourceName = selectedProfile?.name ?? "Setup"
        let duplicate = GamepadEditorConfigurationProfile(
            name: "\(sourceName) Copy",
            customization: customization.normalized
        )
        profiles.append(duplicate)
        selectedProfileID = duplicate.id
        persistProfiles()
    }

    private func deleteSelectedProfile() {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == selectedProfileID }

        guard let nextProfile = profiles.first else { return }
        selectedProfileID = nextProfile.id
        selectedControlID = .builtin(.jump)
        applyCustomization(nextProfile.customization)
        persistProfiles()
    }

    private func selectProfile(_ profile: GamepadEditorConfigurationProfile) {
        selectedProfileID = profile.id
        selectedControlID = .builtin(.jump)
        applyCustomization(profile.customization)
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

    private func persistProfiles() {
        GamepadEditorConfigurationProfilePersistence.save(profiles, activeProfileID: selectedProfileID)
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

private struct GamepadLayoutDesigner: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var customization: GamepadCustomization
    @Binding var selectedControlID: GamepadControlIdentity

    var body: some View {
        GeometryReader { proxy in
            let controls = customization.resolvedControls(in: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                    .fill(Geist.color(.gray100, scheme: colorScheme))
                layoutGrid

                ForEach(controls) { control in
                    GamepadDesignerButton(
                        control: control,
                        customization: customization,
                        isSelected: selectedControlID == control.id
                    )
                    .position(control.center)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("gamepadLayoutDesigner"))
                            .onChanged { value in
                                selectedControlID = control.id
                                updatePosition(value.location, control: control, canvasSize: proxy.size)
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

    private func updatePosition(_ point: CGPoint, control: GamepadResolvedControl, canvasSize: CGSize) {
        let normalizedPosition = GamepadLayoutResolver.normalizedPosition(for: point, visualSize: control.size, in: canvasSize)
        var next = customization
        next.setPosition(normalizedPosition, for: control.id)
        customization = next.normalized
    }
}

private struct GamepadDesignerButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let control: GamepadResolvedControl
    let customization: GamepadCustomization
    let isSelected: Bool

    var body: some View {
        ZStack {
            background(isSelected: false)

            if customization.showsButtonLabels {
                Text(control.label)
                    .geistTypography(control.size.width <= 44 ? .button12 : .button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(customization.accentStyle.buttonForeground(isPressed: false, scheme: colorScheme))
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
        .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.04), radius: isSelected ? 5 : 1, y: isSelected ? 3 : 1)
        .accessibilityLabel(control.label)
    }

    @ViewBuilder
    private func background(isSelected: Bool) -> some View {
        let fillColor = isSelected ? Color.clear : customization.accentStyle.buttonFill(isPressed: false, scheme: colorScheme)
        let strokeColor = isSelected ? Geist.color(.blue700, scheme: colorScheme) : customization.accentStyle.buttonStroke(isPressed: false, scheme: colorScheme)
        let lineWidth: CGFloat = isSelected ? 3 : 1

        switch control.shape {
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .fill(fillColor)
                .overlay(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous).stroke(strokeColor, lineWidth: lineWidth))
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
