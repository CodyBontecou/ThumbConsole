import CoreGraphics
import Foundation

public enum GamepadEditorDeviceOrientation: String, Codable, CaseIterable, Identifiable, Sendable {
    case landscape
    case portrait

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .landscape: "Landscape"
        case .portrait: "Portrait"
        }
    }

    var systemImage: String {
        switch self {
        case .landscape: "iphone.landscape"
        case .portrait: "iphone"
        }
    }
}

enum GamepadEditorDeviceFrameStyle: String, Codable, Sendable {
    case dynamicIsland
    case notch
    case homeButton

    var displayName: String {
        switch self {
        case .dynamicIsland: "Dynamic Island"
        case .notch: "Notch"
        case .homeButton: "Home Button"
        }
    }
}

struct GamepadEditorDeviceSpec: Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var portraitScreenPoints: CGSize
    var nativePixels: CGSize
    var scale: CGFloat
    var nativeScale: CGFloat
    var frameStyle: GamepadEditorDeviceFrameStyle
    var modelIdentifiers: [String]
    var aliases: [String]

    init(
        id: String,
        displayName: String,
        portraitScreenPoints: CGSize,
        nativePixels: CGSize,
        scale: CGFloat,
        nativeScale: CGFloat? = nil,
        frameStyle: GamepadEditorDeviceFrameStyle,
        modelIdentifiers: [String],
        aliases: [String] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.portraitScreenPoints = portraitScreenPoints
        self.nativePixels = nativePixels
        self.scale = scale
        self.nativeScale = nativeScale ?? scale
        self.frameStyle = frameStyle
        self.modelIdentifiers = modelIdentifiers
        self.aliases = aliases
    }
}

struct GamepadEditorDeviceFrame: Identifiable, Hashable, Sendable {
    var spec: GamepadEditorDeviceSpec
    var orientation: GamepadEditorDeviceOrientation

    var id: String { "\(spec.id)-\(orientation.rawValue)" }
    var displayName: String { "\(spec.displayName) \(orientation.displayName)" }
    var shortName: String { orientation.displayName }
    var systemImage: String { orientation.systemImage }
    var frameStyle: GamepadEditorDeviceFrameStyle { spec.frameStyle }
    var isLandscape: Bool { orientation == .landscape }

    var screenSize: CGSize {
        switch orientation {
        case .portrait:
            spec.portraitScreenPoints
        case .landscape:
            CGSize(width: spec.portraitScreenPoints.height, height: spec.portraitScreenPoints.width)
        }
    }

    var screenRect: CGRect {
        // Editor coordinates should match the actual iPhone display points exactly.
        // The vector chrome is drawn inside these bounds so it does not add extra
        // padding around the keypad canvas.
        CGRect(origin: .zero, size: screenSize)
    }

    var imageSize: CGSize {
        screenSize
    }

    var bodyCornerRadius: CGFloat {
        switch frameStyle {
        case .homeButton:
            min(44, max(28, min(imageSize.width, imageSize.height) * 0.055))
        case .dynamicIsland, .notch:
            min(64, max(34, min(imageSize.width, imageSize.height) * 0.095))
        }
    }

    var screenCornerRadius: CGFloat {
        switch frameStyle {
        case .homeButton:
            3
        case .dynamicIsland, .notch:
            min(48, max(24, min(screenSize.width, screenSize.height) * 0.075))
        }
    }

    var helpText: String {
        "Use the \(spec.displayName) \(orientation.displayName.lowercased()) frame and \(Int(screenRect.width.rounded()))×\(Int(screenRect.height.rounded()))pt display canvas."
    }
}

enum GamepadEditorDeviceCatalog {
    static let selectedFrameDefaultsKey = "PocketPad.GamepadEditor.deviceFrame"
    static let didChooseFrameDefaultsKey = "PocketPad.GamepadEditor.didChooseDeviceFrame"
    static let defaultFrameID = "iphone-17-pro-landscape"
    static let customFrameIDPrefix = "custom-"
    static let minimumCustomScreenSide: CGFloat = 240
    static let maximumCustomScreenSide: CGFloat = 1800

    static let specs: [GamepadEditorDeviceSpec] = [
        .init(id: "iphone-17-pro", displayName: "iPhone 17 Pro", portraitScreenPoints: CGSize(width: 402, height: 874), nativePixels: CGSize(width: 1206, height: 2622), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone18,1"]),
        .init(id: "iphone-17-pro-max", displayName: "iPhone 17 Pro Max", portraitScreenPoints: CGSize(width: 440, height: 956), nativePixels: CGSize(width: 1320, height: 2868), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone18,2"]),
        .init(id: "iphone-17e", displayName: "iPhone 17e", portraitScreenPoints: CGSize(width: 390, height: 844), nativePixels: CGSize(width: 1170, height: 2532), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone18,5"]),
        .init(id: "iphone-air", displayName: "iPhone Air", portraitScreenPoints: CGSize(width: 420, height: 912), nativePixels: CGSize(width: 1260, height: 2736), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone18,4"]),
        .init(id: "iphone-17", displayName: "iPhone 17", portraitScreenPoints: CGSize(width: 402, height: 874), nativePixels: CGSize(width: 1206, height: 2622), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone18,3"]),
        .init(id: "iphone-16-pro", displayName: "iPhone 16 Pro", portraitScreenPoints: CGSize(width: 402, height: 874), nativePixels: CGSize(width: 1206, height: 2622), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone17,1"]),
        .init(id: "iphone-16-pro-max", displayName: "iPhone 16 Pro Max", portraitScreenPoints: CGSize(width: 440, height: 956), nativePixels: CGSize(width: 1320, height: 2868), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone17,2"]),
        .init(id: "iphone-16e", displayName: "iPhone 16e", portraitScreenPoints: CGSize(width: 390, height: 844), nativePixels: CGSize(width: 1170, height: 2532), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone17,5"]),
        .init(id: "iphone-16", displayName: "iPhone 16", portraitScreenPoints: CGSize(width: 393, height: 852), nativePixels: CGSize(width: 1179, height: 2556), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone17,3"]),
        .init(id: "iphone-16-plus", displayName: "iPhone 16 Plus", portraitScreenPoints: CGSize(width: 430, height: 932), nativePixels: CGSize(width: 1290, height: 2796), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone17,4"]),
        .init(id: "iphone-15-pro", displayName: "iPhone 15 Pro", portraitScreenPoints: CGSize(width: 393, height: 852), nativePixels: CGSize(width: 1179, height: 2556), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone16,1"]),
        .init(id: "iphone-15-pro-max", displayName: "iPhone 15 Pro Max", portraitScreenPoints: CGSize(width: 430, height: 932), nativePixels: CGSize(width: 1290, height: 2796), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone16,2"]),
        .init(id: "iphone-15", displayName: "iPhone 15", portraitScreenPoints: CGSize(width: 393, height: 852), nativePixels: CGSize(width: 1179, height: 2556), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone15,4"]),
        .init(id: "iphone-15-plus", displayName: "iPhone 15 Plus", portraitScreenPoints: CGSize(width: 430, height: 932), nativePixels: CGSize(width: 1290, height: 2796), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone15,5"]),
        .init(id: "iphone-14-pro", displayName: "iPhone 14 Pro", portraitScreenPoints: CGSize(width: 393, height: 852), nativePixels: CGSize(width: 1179, height: 2556), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone15,2"]),
        .init(id: "iphone-14-pro-max", displayName: "iPhone 14 Pro Max", portraitScreenPoints: CGSize(width: 430, height: 932), nativePixels: CGSize(width: 1290, height: 2796), scale: 3, frameStyle: .dynamicIsland, modelIdentifiers: ["iPhone15,3"]),
        .init(id: "iphone-14", displayName: "iPhone 14", portraitScreenPoints: CGSize(width: 390, height: 844), nativePixels: CGSize(width: 1170, height: 2532), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone14,7"]),
        .init(id: "iphone-14-plus", displayName: "iPhone 14 Plus", portraitScreenPoints: CGSize(width: 428, height: 926), nativePixels: CGSize(width: 1284, height: 2778), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone14,8"]),
        .init(id: "iphone-se-3", displayName: "iPhone SE (3rd generation)", portraitScreenPoints: CGSize(width: 375, height: 667), nativePixels: CGSize(width: 750, height: 1334), scale: 2, frameStyle: .homeButton, modelIdentifiers: ["iPhone14,6"], aliases: ["iPhone SE 3", "iPhone SE 2022", "iPhone SE (3rd gen)"]),
        .init(id: "iphone-13-pro", displayName: "iPhone 13 Pro", portraitScreenPoints: CGSize(width: 390, height: 844), nativePixels: CGSize(width: 1170, height: 2532), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone14,2"]),
        .init(id: "iphone-13-pro-max", displayName: "iPhone 13 Pro Max", portraitScreenPoints: CGSize(width: 428, height: 926), nativePixels: CGSize(width: 1284, height: 2778), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone14,3"]),
        .init(id: "iphone-13", displayName: "iPhone 13", portraitScreenPoints: CGSize(width: 390, height: 844), nativePixels: CGSize(width: 1170, height: 2532), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone14,5"]),
        .init(id: "iphone-13-mini", displayName: "iPhone 13 mini", portraitScreenPoints: CGSize(width: 375, height: 812), nativePixels: CGSize(width: 1080, height: 2340), scale: 3, nativeScale: 2.88, frameStyle: .notch, modelIdentifiers: ["iPhone14,4"]),
        .init(id: "iphone-12-pro", displayName: "iPhone 12 Pro", portraitScreenPoints: CGSize(width: 390, height: 844), nativePixels: CGSize(width: 1170, height: 2532), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone13,3"]),
        .init(id: "iphone-12-pro-max", displayName: "iPhone 12 Pro Max", portraitScreenPoints: CGSize(width: 428, height: 926), nativePixels: CGSize(width: 1284, height: 2778), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone13,4"]),
        .init(id: "iphone-12", displayName: "iPhone 12", portraitScreenPoints: CGSize(width: 390, height: 844), nativePixels: CGSize(width: 1170, height: 2532), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone13,2"]),
        .init(id: "iphone-12-mini", displayName: "iPhone 12 mini", portraitScreenPoints: CGSize(width: 375, height: 812), nativePixels: CGSize(width: 1080, height: 2340), scale: 3, nativeScale: 2.88, frameStyle: .notch, modelIdentifiers: ["iPhone13,1"]),
        .init(id: "iphone-se-2", displayName: "iPhone SE (2nd generation)", portraitScreenPoints: CGSize(width: 375, height: 667), nativePixels: CGSize(width: 750, height: 1334), scale: 2, frameStyle: .homeButton, modelIdentifiers: ["iPhone12,8"], aliases: ["iPhone SE 2", "iPhone SE 2020", "iPhone SE (2nd gen)"]),
        .init(id: "iphone-11-pro", displayName: "iPhone 11 Pro", portraitScreenPoints: CGSize(width: 375, height: 812), nativePixels: CGSize(width: 1125, height: 2436), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone12,3"]),
        .init(id: "iphone-11-pro-max", displayName: "iPhone 11 Pro Max", portraitScreenPoints: CGSize(width: 414, height: 896), nativePixels: CGSize(width: 1242, height: 2688), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone12,5"]),
        .init(id: "iphone-11", displayName: "iPhone 11", portraitScreenPoints: CGSize(width: 414, height: 896), nativePixels: CGSize(width: 828, height: 1792), scale: 2, frameStyle: .notch, modelIdentifiers: ["iPhone12,1"]),
        .init(id: "iphone-xr", displayName: "iPhone XR", portraitScreenPoints: CGSize(width: 414, height: 896), nativePixels: CGSize(width: 828, height: 1792), scale: 2, frameStyle: .notch, modelIdentifiers: ["iPhone11,8"], aliases: ["iPhone Xʀ"]),
        .init(id: "iphone-xs", displayName: "iPhone XS", portraitScreenPoints: CGSize(width: 375, height: 812), nativePixels: CGSize(width: 1125, height: 2436), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone11,2"], aliases: ["iPhone Xs"]),
        .init(id: "iphone-xs-max", displayName: "iPhone XS Max", portraitScreenPoints: CGSize(width: 414, height: 896), nativePixels: CGSize(width: 1242, height: 2688), scale: 3, frameStyle: .notch, modelIdentifiers: ["iPhone11,4", "iPhone11,6"], aliases: ["iPhone Xs Max"])
    ]

    static var frames: [GamepadEditorDeviceFrame] {
        specs.flatMap { spec in
            GamepadEditorDeviceOrientation.allCases.map { orientation in
                GamepadEditorDeviceFrame(spec: spec, orientation: orientation)
            }
        }
    }

    static var defaultFrame: GamepadEditorDeviceFrame {
        frames.first { $0.id == defaultFrameID } ?? GamepadEditorDeviceFrame(spec: specs[0], orientation: .landscape)
    }

    static func frame(forStoredID storedID: String?) -> GamepadEditorDeviceFrame? {
        guard let storedID, !storedID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultFrame
        }

        if let custom = customFrame(matching: storedID, preferredOrientation: nil) {
            return custom
        }

        if let legacy = legacyFrame(for: storedID) {
            return legacy
        }

        return frames.first { $0.id == storedID } ?? frame(matching: storedID, preferredOrientation: nil)
    }

    static func frame(matching text: String, preferredOrientation: GamepadEditorDeviceOrientation?) -> GamepadEditorDeviceFrame? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let custom = customFrame(matching: trimmed, preferredOrientation: preferredOrientation) {
            return custom
        }

        if let legacy = legacyFrame(for: trimmed) {
            return legacy
        }

        let normalizedText = normalizedLookup(trimmed)
        if normalizedText == "landscape" {
            return GamepadEditorDeviceFrame(spec: specs[0], orientation: .landscape)
        }
        if normalizedText == "portrait" {
            return GamepadEditorDeviceFrame(spec: specs[0], orientation: .portrait)
        }

        if let directFrame = frames.first(where: { frameMatches($0, normalizedText: normalizedText) }) {
            return directFrame
        }

        let orientation = orientation(in: normalizedText) ?? preferredOrientation ?? .landscape
        let specLookup = normalizedText
            .replacingOccurrences(of: "landscape", with: "")
            .replacingOccurrences(of: "portrait", with: "")
        guard let spec = specs.first(where: { specMatches($0, normalizedText: specLookup) }) else { return nil }
        return GamepadEditorDeviceFrame(spec: spec, orientation: orientation)
    }

    static func suggestedFrame(
        for deviceInfo: ControllerClientDeviceInfo,
        preferredOrientation: GamepadEditorDeviceOrientation = .landscape
    ) -> GamepadEditorDeviceFrame? {
        if let modelIdentifier = deviceInfo.modelIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
           !modelIdentifier.isEmpty,
           let spec = specs.first(where: { $0.modelIdentifiers.contains(modelIdentifier) }) {
            return GamepadEditorDeviceFrame(spec: spec, orientation: preferredOrientation)
        }

        let pointSize = normalizedPortraitSize(width: deviceInfo.screenBoundsWidth, height: deviceInfo.screenBoundsHeight)
        let nativeSize = normalizedPortraitSize(width: deviceInfo.nativeBoundsWidth, height: deviceInfo.nativeBoundsHeight)

        let pointMatches = specs.filter {
            approximatelyEqual($0.portraitScreenPoints, pointSize, tolerance: 1.5)
        }
        if let nativeMatch = pointMatches.first(where: { approximatelyEqual($0.nativePixels, nativeSize, tolerance: 2) }) {
            return GamepadEditorDeviceFrame(spec: nativeMatch, orientation: preferredOrientation)
        }
        if let firstPointMatch = pointMatches.first {
            return GamepadEditorDeviceFrame(spec: firstPointMatch, orientation: preferredOrientation)
        }

        let nativeMatches = specs.filter { approximatelyEqual($0.nativePixels, nativeSize, tolerance: 2) }
        if let firstNativeMatch = nativeMatches.first {
            return GamepadEditorDeviceFrame(spec: firstNativeMatch, orientation: preferredOrientation)
        }

        return nil
    }

    static func normalizedLookup(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func customFrame(width: CGFloat, height: CGFloat, preferredOrientation: GamepadEditorDeviceOrientation? = nil) -> GamepadEditorDeviceFrame? {
        guard width.isFinite, height.isFinite, width > 1, height > 1 else { return nil }
        let clampedWidth = clampedCustomScreenSide(width)
        let clampedHeight = clampedCustomScreenSide(height)
        let orientation = preferredOrientation ?? (clampedWidth >= clampedHeight ? .landscape : .portrait)
        let portraitSize = CGSize(width: min(clampedWidth, clampedHeight), height: max(clampedWidth, clampedHeight))
        let screenSize = orientation == .landscape
            ? CGSize(width: portraitSize.height, height: portraitSize.width)
            : portraitSize
        let spec = GamepadEditorDeviceSpec(
            id: "\(customFrameIDPrefix)\(formatDimension(portraitSize.width))x\(formatDimension(portraitSize.height))",
            displayName: "Custom \(formatDimension(screenSize.width))×\(formatDimension(screenSize.height))",
            portraitScreenPoints: portraitSize,
            nativePixels: CGSize(width: portraitSize.width * 3, height: portraitSize.height * 3),
            scale: 3,
            frameStyle: .dynamicIsland,
            modelIdentifiers: [],
            aliases: ["Custom"]
        )
        return GamepadEditorDeviceFrame(spec: spec, orientation: orientation)
    }

    private static func customFrame(matching text: String, preferredOrientation: GamepadEditorDeviceOrientation?) -> GamepadEditorDeviceFrame? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowercased = trimmed.lowercased()
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "_", with: "-")
        let orientation = orientation(in: normalizedLookup(lowercased)) ?? preferredOrientation
        let digitsAndSeparator = lowercased.map { character -> Character in
            if character.isNumber || character == "." { return character }
            if character == "x" || character == "," || character == ":" { return "x" }
            return " "
        }
        let parts = String(digitsAndSeparator)
            .split { $0 == " " || $0 == "x" }
            .compactMap { Double($0) }
        guard parts.count >= 2 else { return nil }
        return customFrame(width: CGFloat(parts[0]), height: CGFloat(parts[1]), preferredOrientation: orientation)
    }

    private static func clampedCustomScreenSide(_ value: CGFloat) -> CGFloat {
        min(max(value.rounded(), minimumCustomScreenSide), maximumCustomScreenSide)
    }

    private static func formatDimension(_ value: CGFloat) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.001 {
            return String(Int(rounded))
        }
        return String(format: "%.1f", Double(value))
    }

    private static func legacyFrame(for text: String) -> GamepadEditorDeviceFrame? {
        switch normalizedLookup(text) {
        case "iphone17prolandscape":
            return GamepadEditorDeviceFrame(spec: specs[0], orientation: .landscape)
        case "iphone17proportrait":
            return GamepadEditorDeviceFrame(spec: specs[0], orientation: .portrait)
        default:
            return nil
        }
    }

    private static func frameMatches(_ frame: GamepadEditorDeviceFrame, normalizedText: String) -> Bool {
        normalizedLookup(frame.id) == normalizedText
            || normalizedLookup(frame.displayName) == normalizedText
    }

    private static func specMatches(_ spec: GamepadEditorDeviceSpec, normalizedText: String) -> Bool {
        guard !normalizedText.isEmpty else { return false }
        if normalizedLookup(spec.id) == normalizedText || normalizedLookup(spec.displayName) == normalizedText {
            return true
        }
        if spec.modelIdentifiers.contains(where: { normalizedLookup($0) == normalizedText }) {
            return true
        }
        return spec.aliases.contains { normalizedLookup($0) == normalizedText }
    }

    private static func orientation(in normalizedText: String) -> GamepadEditorDeviceOrientation? {
        if normalizedText.contains("portrait") { return .portrait }
        if normalizedText.contains("landscape") { return .landscape }
        return nil
    }

    private static func normalizedPortraitSize(width: Double, height: Double) -> CGSize {
        CGSize(width: min(width, height), height: max(width, height))
    }

    private static func approximatelyEqual(_ lhs: CGSize, _ rhs: CGSize, tolerance: CGFloat) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }
}
