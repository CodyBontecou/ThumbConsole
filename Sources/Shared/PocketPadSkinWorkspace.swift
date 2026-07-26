import CryptoKit
import Foundation

public enum PocketPadSkinWorkspaceSchema {
    public static let identifier = "com.codybontecou.pocketpad.skin-source"
    public static let currentVersion = 1
}

public struct PocketPadNormalizedRect: Codable, Equatable, Sendable {
    public var x: CGFloat
    public var y: CGFloat
    public var width: CGFloat
    public var height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var normalized: PocketPadNormalizedRect {
        let width = Self.clamp(self.width, 0, 1)
        let height = Self.clamp(self.height, 0, 1)
        return PocketPadNormalizedRect(
            x: Self.clamp(x, 0, 1 - width),
            y: Self.clamp(y, 0, 1 - height),
            width: width,
            height: height
        )
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        guard value.isFinite else { return lower }
        return min(max(value, lower), max(lower, upper))
    }
}

public struct PocketPadNormalizedInsets: Codable, Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public var normalized: PocketPadNormalizedInsets {
        PocketPadNormalizedInsets(
            top: Self.clamp(top),
            leading: Self.clamp(leading),
            bottom: Self.clamp(bottom),
            trailing: Self.clamp(trailing)
        )
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 0.45)
    }
}

public enum PocketPadSkinMaterialKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case translucentPlastic = "translucent_plastic"
    case opaquePlastic = "opaque_plastic"
    case matteRubber = "matte_rubber"
    case glossyPlastic = "glossy_plastic"
    case glass
    case metal
    case raised
    case inset

    public var id: String { rawValue }
}

public struct PocketPadSkinPaletteToken: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var light: String
    public var dark: String?

    public init(id: String, light: String, dark: String? = nil) {
        self.id = id
        self.light = light
        self.dark = dark
    }
}

public struct PocketPadSkinMaterialSpec: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var kind: PocketPadSkinMaterialKind
    public var baseColor: String
    public var darkBaseColor: String?
    public var foregroundColor: String
    public var darkForegroundColor: String?
    public var strokeColor: String?
    public var darkStrokeColor: String?
    /// Surface highlight used for bevel and upper-left light response.
    public var highlightColor: String?
    /// Optional interaction accent used for the active state's crisp index stroke.
    public var activeColor: String?
    public var darkActiveColor: String?
    public var activeIndexColor: String?
    public var darkActiveIndexColor: String?
    public var activeIndexWidth: CGFloat?
    public var shadowColor: String?
    /// Optional native joystick puck colors. These remain passive appearance values.
    public var joystickKnobColor: String?
    public var darkJoystickKnobColor: String?
    /// Exact state colors opt a material into authored state output instead of derived color mixing.
    public var pressedFillColor: String?
    public var darkPressedFillColor: String?
    public var activeFillColor: String?
    public var darkActiveFillColor: String?
    public var disabledFillColor: String?
    public var darkDisabledFillColor: String?
    public var disabledForegroundColor: String?
    public var darkDisabledForegroundColor: String?
    public var disabledStrokeColor: String?
    public var darkDisabledStrokeColor: String?
    /// Optional state geometry and depth controls. Missing values preserve legacy compilation.
    public var shadowScale: CGFloat?
    public var pressedShadowScale: CGFloat?
    public var pressedInnerShadowScale: CGFloat?
    public var activeStrokeWidth: CGFloat?
    public var portraitActiveStrokeWidth: CGFloat?
    public var landscapeActiveStrokeWidth: CGFloat?
    public var disabledStrokeWidth: CGFloat?
    public var disabledOpacity: CGFloat?
    public var depth: CGFloat
    public var gloss: CGFloat
    public var cornerRadius: CGFloat?
    public var pressedScale: CGFloat
    public var hapticFeedback: GamepadHapticFeedback?

    public init(
        id: String,
        name: String,
        kind: PocketPadSkinMaterialKind,
        baseColor: String,
        darkBaseColor: String? = nil,
        foregroundColor: String,
        darkForegroundColor: String? = nil,
        strokeColor: String? = nil,
        darkStrokeColor: String? = nil,
        highlightColor: String? = nil,
        activeColor: String? = nil,
        darkActiveColor: String? = nil,
        activeIndexColor: String? = nil,
        darkActiveIndexColor: String? = nil,
        activeIndexWidth: CGFloat? = nil,
        shadowColor: String? = nil,
        joystickKnobColor: String? = nil,
        darkJoystickKnobColor: String? = nil,
        pressedFillColor: String? = nil,
        darkPressedFillColor: String? = nil,
        activeFillColor: String? = nil,
        darkActiveFillColor: String? = nil,
        disabledFillColor: String? = nil,
        darkDisabledFillColor: String? = nil,
        disabledForegroundColor: String? = nil,
        darkDisabledForegroundColor: String? = nil,
        disabledStrokeColor: String? = nil,
        darkDisabledStrokeColor: String? = nil,
        shadowScale: CGFloat? = nil,
        pressedShadowScale: CGFloat? = nil,
        pressedInnerShadowScale: CGFloat? = nil,
        activeStrokeWidth: CGFloat? = nil,
        portraitActiveStrokeWidth: CGFloat? = nil,
        landscapeActiveStrokeWidth: CGFloat? = nil,
        disabledStrokeWidth: CGFloat? = nil,
        disabledOpacity: CGFloat? = nil,
        depth: CGFloat = 0.6,
        gloss: CGFloat = 0.35,
        cornerRadius: CGFloat? = nil,
        pressedScale: CGFloat = 0.97,
        hapticFeedback: GamepadHapticFeedback? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.baseColor = baseColor
        self.darkBaseColor = darkBaseColor
        self.foregroundColor = foregroundColor
        self.darkForegroundColor = darkForegroundColor
        self.strokeColor = strokeColor
        self.darkStrokeColor = darkStrokeColor
        self.highlightColor = highlightColor
        self.activeColor = activeColor
        self.darkActiveColor = darkActiveColor
        self.activeIndexColor = activeIndexColor
        self.darkActiveIndexColor = darkActiveIndexColor
        self.activeIndexWidth = activeIndexWidth
        self.shadowColor = shadowColor
        self.joystickKnobColor = joystickKnobColor
        self.darkJoystickKnobColor = darkJoystickKnobColor
        self.pressedFillColor = pressedFillColor
        self.darkPressedFillColor = darkPressedFillColor
        self.activeFillColor = activeFillColor
        self.darkActiveFillColor = darkActiveFillColor
        self.disabledFillColor = disabledFillColor
        self.darkDisabledFillColor = darkDisabledFillColor
        self.disabledForegroundColor = disabledForegroundColor
        self.darkDisabledForegroundColor = darkDisabledForegroundColor
        self.disabledStrokeColor = disabledStrokeColor
        self.darkDisabledStrokeColor = darkDisabledStrokeColor
        self.shadowScale = shadowScale
        self.pressedShadowScale = pressedShadowScale
        self.pressedInnerShadowScale = pressedInnerShadowScale
        self.activeStrokeWidth = activeStrokeWidth
        self.portraitActiveStrokeWidth = portraitActiveStrokeWidth
        self.landscapeActiveStrokeWidth = landscapeActiveStrokeWidth
        self.disabledStrokeWidth = disabledStrokeWidth
        self.disabledOpacity = disabledOpacity
        self.depth = depth
        self.gloss = gloss
        self.cornerRadius = cornerRadius
        self.pressedScale = pressedScale
        self.hapticFeedback = hapticFeedback
    }
}

public enum PocketPadSkinComponentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case canvasBackground = "canvas_background"
    case controllerShell = "controller_shell"
    case controlWell = "control_well"
    case buttonFace = "button_face"
    case dpad
    case joystick
    case utilityButton = "utility_button"
    case decorativeArtwork = "decorative_artwork"

    public var id: String { rawValue }
}

public struct PocketPadSkinComponentSpec: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var kind: PocketPadSkinComponentKind
    public var materialID: String
    public var role: GamepadVisualRole?
    public var button: GameButton?
    public var frame: PocketPadNormalizedRect?
    public var shape: GamepadButtonShapeStyle?
    public var zIndex: Int
    public var sourceAssetID: String?
    public var label: String?

    public init(
        id: String,
        kind: PocketPadSkinComponentKind,
        materialID: String,
        role: GamepadVisualRole? = nil,
        button: GameButton? = nil,
        frame: PocketPadNormalizedRect? = nil,
        shape: GamepadButtonShapeStyle? = nil,
        zIndex: Int = 0,
        sourceAssetID: String? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.materialID = materialID
        self.role = role
        self.button = button
        self.frame = frame
        self.shape = shape
        self.zIndex = zIndex
        self.sourceAssetID = sourceAssetID
        self.label = label
    }
}

public enum PocketPadSkinRasterFormat: String, Codable, CaseIterable, Identifiable, Sendable {
    case png
    case webp

    public var id: String { rawValue }
}

public enum PocketPadSkinAssetPurpose: String, Codable, CaseIterable, Identifiable, Sendable {
    case canvasArtwork = "canvas_artwork"
    case controlFace = "control_face"
    case icon
    case texture
    case preview

    public var id: String { rawValue }
}

public struct PocketPadSkinSourceAsset: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var path: String
    public var purpose: PocketPadSkinAssetPurpose
    public var outputWidth: Int
    public var outputHeight: Int
    public var format: PocketPadSkinRasterFormat
    public var nineSliceInsets: PocketPadNormalizedInsets?
    public var orientation: PocketPadSkinOrientation?
    public var colorScheme: PocketPadSkinColorScheme?

    public init(
        id: String,
        path: String,
        purpose: PocketPadSkinAssetPurpose,
        outputWidth: Int,
        outputHeight: Int,
        format: PocketPadSkinRasterFormat = .png,
        nineSliceInsets: PocketPadNormalizedInsets? = nil,
        orientation: PocketPadSkinOrientation? = nil,
        colorScheme: PocketPadSkinColorScheme? = nil
    ) {
        self.id = id
        self.path = path
        self.purpose = purpose
        self.outputWidth = outputWidth
        self.outputHeight = outputHeight
        self.format = format
        self.nineSliceInsets = nineSliceInsets
        self.orientation = orientation
        self.colorScheme = colorScheme
    }
}

public struct PocketPadSemanticStyleAssignment: Codable, Equatable, Sendable {
    public var role: GamepadVisualRole?
    public var button: GameButton?
    public var materialID: String
    public var componentID: String?

    public init(
        role: GamepadVisualRole? = nil,
        button: GameButton? = nil,
        materialID: String,
        componentID: String? = nil
    ) {
        self.role = role
        self.button = button
        self.materialID = materialID
        self.componentID = componentID
    }
}

public enum PocketPadPreviewState: String, Codable, CaseIterable, Identifiable, Sendable {
    case normal
    case pressed
    case active
    case disabled

    public var id: String { rawValue }
}

public struct PocketPadPreviewRequest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var artboardID: String
    public var orientation: PocketPadSkinOrientation
    public var colorScheme: PocketPadSkinColorScheme
    public var state: PocketPadPreviewState
    public var scale: CGFloat

    public init(
        id: String,
        artboardID: String,
        orientation: PocketPadSkinOrientation,
        colorScheme: PocketPadSkinColorScheme,
        state: PocketPadPreviewState = .normal,
        scale: CGFloat = 2
    ) {
        self.id = id
        self.artboardID = artboardID
        self.orientation = orientation
        self.colorScheme = colorScheme
        self.state = state
        self.scale = scale
    }
}

public struct PocketPadSkinWorkspace: Codable, Equatable, Sendable {
    public var schema: String
    public var schemaVersion: Int
    public var identifier: String
    public var version: String
    public var name: String
    public var author: PocketPadSkinAuthor
    public var summary: String
    public var license: String
    public var artboardID: String
    public var orientations: [PocketPadSkinOrientation]
    public var colorSchemes: [PocketPadSkinColorScheme]
    public var palette: [PocketPadSkinPaletteToken]
    public var materials: [PocketPadSkinMaterialSpec]
    public var components: [PocketPadSkinComponentSpec]
    public var assignments: [PocketPadSemanticStyleAssignment]
    public var sourceAssets: [PocketPadSkinSourceAsset]
    public var previews: [PocketPadPreviewRequest]

    public init(
        schema: String = PocketPadSkinWorkspaceSchema.identifier,
        schemaVersion: Int = PocketPadSkinWorkspaceSchema.currentVersion,
        identifier: String,
        version: String = "1.0.0",
        name: String,
        author: PocketPadSkinAuthor,
        summary: String,
        license: String = "All Rights Reserved",
        artboardID: String = "showcase-controller-v1",
        orientations: [PocketPadSkinOrientation] = [.landscape, .portrait],
        colorSchemes: [PocketPadSkinColorScheme] = [.light, .dark],
        palette: [PocketPadSkinPaletteToken] = [],
        materials: [PocketPadSkinMaterialSpec] = [],
        components: [PocketPadSkinComponentSpec] = [],
        assignments: [PocketPadSemanticStyleAssignment] = [],
        sourceAssets: [PocketPadSkinSourceAsset] = [],
        previews: [PocketPadPreviewRequest] = []
    ) {
        self.schema = schema
        self.schemaVersion = schemaVersion
        self.identifier = identifier
        self.version = version
        self.name = name
        self.author = author
        self.summary = summary
        self.license = license
        self.artboardID = artboardID
        self.orientations = orientations
        self.colorSchemes = colorSchemes
        self.palette = palette
        self.materials = materials
        self.components = components
        self.assignments = assignments
        self.sourceAssets = sourceAssets
        self.previews = previews
    }

    private enum CodingKeys: String, CodingKey {
        case schema, schemaVersion, identifier, version, name, author, summary, license, artboardID
        case orientations, colorSchemes, palette, materials, components, assignments, sourceAssets, previews
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = try container.decodeIfPresent(String.self, forKey: .schema) ?? PocketPadSkinWorkspaceSchema.identifier
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        identifier = try container.decode(String.self, forKey: .identifier)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0.0"
        name = try container.decode(String.self, forKey: .name)
        author = try container.decodeIfPresent(PocketPadSkinAuthor.self, forKey: .author) ?? PocketPadSkinAuthor(name: "Unknown Creator")
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        license = try container.decodeIfPresent(String.self, forKey: .license) ?? "All Rights Reserved"
        artboardID = try container.decodeIfPresent(String.self, forKey: .artboardID) ?? "showcase-controller-v1"
        orientations = try container.decodeIfPresent([PocketPadSkinOrientation].self, forKey: .orientations) ?? [.landscape]
        colorSchemes = try container.decodeIfPresent([PocketPadSkinColorScheme].self, forKey: .colorSchemes) ?? [.light, .dark]
        palette = try container.decodeIfPresent([PocketPadSkinPaletteToken].self, forKey: .palette) ?? []
        materials = try container.decodeIfPresent([PocketPadSkinMaterialSpec].self, forKey: .materials) ?? []
        components = try container.decodeIfPresent([PocketPadSkinComponentSpec].self, forKey: .components) ?? []
        assignments = try container.decodeIfPresent([PocketPadSemanticStyleAssignment].self, forKey: .assignments) ?? []
        sourceAssets = try container.decodeIfPresent([PocketPadSkinSourceAsset].self, forKey: .sourceAssets) ?? []
        previews = try container.decodeIfPresent([PocketPadPreviewRequest].self, forKey: .previews) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(version, forKey: .version)
        try container.encode(name, forKey: .name)
        try container.encode(author, forKey: .author)
        try container.encode(summary, forKey: .summary)
        try container.encode(license, forKey: .license)
        try container.encode(artboardID, forKey: .artboardID)
        try container.encode(orientations, forKey: .orientations)
        try container.encode(colorSchemes, forKey: .colorSchemes)
        try container.encode(palette, forKey: .palette)
        try container.encode(materials, forKey: .materials)
        try container.encode(components, forKey: .components)
        try container.encode(assignments, forKey: .assignments)
        try container.encode(sourceAssets, forKey: .sourceAssets)
        try container.encode(previews, forKey: .previews)
    }

    public static func starter(name: String, identifier: String, artboardID: String) -> PocketPadSkinWorkspace {
        let body = PocketPadSkinMaterialSpec(
            id: "shell",
            name: "Controller Shell",
            kind: .translucentPlastic,
            baseColor: "#433878",
            darkBaseColor: "#211A46",
            foregroundColor: "#F7F1FF",
            strokeColor: "#8E7BC7",
            highlightColor: "#B7A7E8",
            shadowColor: "#100C27",
            depth: 0.8,
            gloss: 0.62,
            cornerRadius: 36,
            pressedScale: 0.99
        )
        let rubber = PocketPadSkinMaterialSpec(
            id: "rubber",
            name: "Movement Rubber",
            kind: .matteRubber,
            baseColor: "#29243B",
            darkBaseColor: "#171421",
            foregroundColor: "#F2ECFF",
            strokeColor: "#5E5574",
            highlightColor: "#6F6685",
            shadowColor: "#08070D",
            depth: 0.55,
            gloss: 0.08,
            cornerRadius: 14,
            pressedScale: 0.965,
            hapticFeedback: GamepadHapticFeedback(style: .rigid, pattern: .single, intensity: 0.55, sharpness: 0.8)
        )
        let candy = PocketPadSkinMaterialSpec(
            id: "candy",
            name: "Glossy Action Plastic",
            kind: .glossyPlastic,
            baseColor: "#D95F91",
            darkBaseColor: "#A83D6A",
            foregroundColor: "#FFFFFF",
            strokeColor: "#FFB1D0",
            highlightColor: "#FFFFFF",
            shadowColor: "#49152D",
            depth: 0.9,
            gloss: 0.88,
            pressedScale: 0.94,
            hapticFeedback: GamepadHapticFeedback(style: .medium, pattern: .single, intensity: 0.62, sharpness: 0.54)
        )
        let utility = PocketPadSkinMaterialSpec(
            id: "utility",
            name: "Utility Rubber",
            kind: .inset,
            baseColor: "#4C4463",
            darkBaseColor: "#2C273A",
            foregroundColor: "#F5F0FF",
            strokeColor: "#776D91",
            depth: 0.35,
            gloss: 0.12,
            cornerRadius: 20,
            pressedScale: 0.97
        )
        return PocketPadSkinWorkspace(
            identifier: identifier,
            name: name,
            author: PocketPadSkinAuthor(name: "Your Name"),
            summary: "A handcrafted controller skin built from a canonical Thumble artboard.",
            license: "All Rights Reserved",
            artboardID: artboardID,
            palette: [
                PocketPadSkinPaletteToken(id: "indigo", light: "#433878", dark: "#211A46"),
                PocketPadSkinPaletteToken(id: "candy", light: "#D95F91", dark: "#A83D6A"),
                PocketPadSkinPaletteToken(id: "rubber", light: "#29243B", dark: "#171421")
            ],
            materials: [body, rubber, candy, utility],
            components: [
                PocketPadSkinComponentSpec(
                    id: "shell-plate",
                    kind: .controllerShell,
                    materialID: "shell",
                    frame: PocketPadNormalizedRect(x: 0.025, y: 0.075, width: 0.95, height: 0.85),
                    shape: .roundedRectangle,
                    zIndex: -100
                ),
                PocketPadSkinComponentSpec(
                    id: "movement-well",
                    kind: .controlWell,
                    materialID: "rubber",
                    role: .movement,
                    frame: PocketPadNormalizedRect(x: 0.055, y: 0.22, width: 0.30, height: 0.60),
                    shape: .circle,
                    zIndex: -50
                ),
                PocketPadSkinComponentSpec(
                    id: "action-well",
                    kind: .controlWell,
                    materialID: "shell",
                    role: .primaryAction,
                    frame: PocketPadNormalizedRect(x: 0.66, y: 0.20, width: 0.30, height: 0.62),
                    shape: .circle,
                    zIndex: -50
                )
            ],
            assignments: [
                PocketPadSemanticStyleAssignment(role: .movement, materialID: "rubber"),
                PocketPadSemanticStyleAssignment(role: .primaryAction, materialID: "candy"),
                PocketPadSemanticStyleAssignment(role: .secondaryAction, materialID: "candy"),
                PocketPadSemanticStyleAssignment(role: .utility, materialID: "utility"),
                PocketPadSemanticStyleAssignment(role: .menu, materialID: "utility"),
                PocketPadSemanticStyleAssignment(role: .joystick, materialID: "rubber"),
                PocketPadSemanticStyleAssignment(role: .trigger, materialID: "utility"),
                PocketPadSemanticStyleAssignment(role: .trackpad, materialID: "rubber"),
                PocketPadSemanticStyleAssignment(role: .custom, materialID: "utility")
            ],
            sourceAssets: [
                PocketPadSkinSourceAsset(
                    id: "accent-lines",
                    path: "sources/artwork/accent-lines.svg",
                    purpose: .canvasArtwork,
                    outputWidth: 1748,
                    outputHeight: 804
                )
            ],
            previews: [
                PocketPadPreviewRequest(id: "landscape-light-normal", artboardID: artboardID, orientation: .landscape, colorScheme: .light),
                PocketPadPreviewRequest(id: "landscape-dark-normal", artboardID: artboardID, orientation: .landscape, colorScheme: .dark),
                PocketPadPreviewRequest(id: "portrait-light-normal", artboardID: artboardID, orientation: .portrait, colorScheme: .light),
                PocketPadPreviewRequest(id: "portrait-dark-normal", artboardID: artboardID, orientation: .portrait, colorScheme: .dark)
            ]
        )
    }
}

public struct PocketPadSkinArtboardControl: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var kind: GamepadCustomControlKind
    public var visualRole: GamepadVisualRole
    public var mappedButton: GameButton
    public var frame: PocketPadNormalizedRect

    public init(
        id: String,
        label: String,
        kind: GamepadCustomControlKind,
        visualRole: GamepadVisualRole,
        mappedButton: GameButton,
        frame: PocketPadNormalizedRect
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.visualRole = visualRole
        self.mappedButton = mappedButton
        self.frame = frame
    }
}

public struct PocketPadSkinArtboardVariant: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var orientation: PocketPadSkinOrientation
    public var canvasWidth: CGFloat
    public var canvasHeight: CGFloat
    public var safeAreaInsets: PocketPadNormalizedInsets
    public var controls: [PocketPadSkinArtboardControl]

    public init(
        id: String,
        orientation: PocketPadSkinOrientation,
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        safeAreaInsets: PocketPadNormalizedInsets,
        controls: [PocketPadSkinArtboardControl]
    ) {
        self.id = id
        self.orientation = orientation
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.safeAreaInsets = safeAreaInsets
        self.controls = controls
    }
}

public struct PocketPadSkinArtboard: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var revision: Int
    public var templateID: String
    public var name: String
    public var summary: String
    public var variants: [PocketPadSkinArtboardVariant]
    public var expectedRoles: [GamepadVisualRole]

    public init(
        id: String,
        revision: Int,
        templateID: String,
        name: String,
        summary: String,
        variants: [PocketPadSkinArtboardVariant],
        expectedRoles: [GamepadVisualRole]
    ) {
        self.id = id
        self.revision = revision
        self.templateID = templateID
        self.name = name
        self.summary = summary
        self.variants = variants
        self.expectedRoles = expectedRoles
    }
}

public enum PocketPadSkinArtboardCatalog {
    public static let defaultID = "showcase-controller-v1"

    public static var all: [PocketPadSkinArtboard] {
        let showcase = makeArtboard(
            id: defaultID,
            template: .snes,
            name: "Showcase Controller",
            summary: "Neutral 16-bit-style controller artboard used for deterministic skin previews."
        )
        let classic = makeArtboard(
            id: "classic-16-bit-v1",
            template: .snes,
            name: "Classic 16-Bit",
            summary: "D-pad, four face actions, two shoulders, and two utility controls."
        )
        let templates = GamepadControllerTemplate.allCases.map { template in
            makeArtboard(
                id: "\(kebabCase(template.rawValue))-v1",
                template: template,
                name: template.displayName,
                summary: template.description
            )
        }
        var seen = Set<String>()
        return ([showcase, classic] + templates).filter { seen.insert($0.id).inserted }
    }

    public static func resolve(_ value: String) -> PocketPadSkinArtboard? {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return all.first {
            $0.id.lowercased() == key
                || $0.name.lowercased() == key
                || $0.templateID.lowercased() == key
        }
    }

    public static func profile(for artboardID: String) -> GamepadConfigurationProfile? {
        guard let artboard = resolve(artboardID),
              let template = GamepadControllerTemplate.allCases.first(where: { $0.rawValue == artboard.templateID })
        else { return nil }
        return stabilized(completingOrientations(template.makeProfile()), seed: artboard.id)
    }

    private static func makeArtboard(
        id: String,
        template: GamepadControllerTemplate,
        name: String,
        summary: String
    ) -> PocketPadSkinArtboard {
        let profile = stabilized(completingOrientations(template.makeProfile()), seed: id)
        let availableOrientations: [(PocketPadSkinOrientation, GamepadCustomization)] = {
            var values: [(PocketPadSkinOrientation, GamepadCustomization)] = []
            if let landscape = profile.landscapeCustomization {
                values.append((.landscape, landscape))
            }
            if let portrait = profile.portraitCustomization {
                values.append((.portrait, portrait))
            }
            if values.isEmpty {
                let customization = profile.customization
                let orientation: PocketPadSkinOrientation = customization.deviceCanvas.editorDeviceFrame.orientation == .portrait ? .portrait : .landscape
                values.append((orientation, customization))
            }
            return values
        }()
        let variants = availableOrientations.map { orientation, customization in
            makeVariant(orientation: orientation, customization: customization)
        }
        let roles = Array(Set(variants.flatMap { $0.controls.map(\.visualRole) }))
            .sorted { $0.rawValue < $1.rawValue }
        return PocketPadSkinArtboard(
            id: id,
            revision: template.templateRevision,
            templateID: template.rawValue,
            name: name,
            summary: summary,
            variants: variants,
            expectedRoles: roles
        )
    }

    private static func makeVariant(
        orientation: PocketPadSkinOrientation,
        customization: GamepadCustomization
    ) -> PocketPadSkinArtboardVariant {
        let size = customization.deviceCanvas.editorDeviceFrame.screenRect.size
        let controls = customization.resolvedControls(in: size)
            .filter { !$0.layoutCustomization.isHidden }
            .enumerated()
            .map { index, control in
                let frame = control.frame
                let stableID: String
                switch control.id {
                case .builtin(let button): stableID = "builtin.\(button.rawValue)"
                case .custom: stableID = "custom.\(control.controlKind.rawValue).\(index)"
                case .system(let system): stableID = "system.\(system.rawValue)"
                case .controlBarItem(let item): stableID = "control-bar.\(item.rawValue)"
                }
                return PocketPadSkinArtboardControl(
                    id: stableID,
                    label: control.label,
                    kind: control.controlKind,
                    visualRole: control.visualRole,
                    mappedButton: control.mappedButton,
                    frame: PocketPadNormalizedRect(
                        x: frame.minX / max(size.width, 1),
                        y: frame.minY / max(size.height, 1),
                        width: frame.width / max(size.width, 1),
                        height: frame.height / max(size.height, 1)
                    ).normalized
                )
            }
        let safeArea: PocketPadNormalizedInsets = orientation == .portrait
            ? PocketPadNormalizedInsets(top: 0.055, leading: 0.025, bottom: 0.045, trailing: 0.025)
            : PocketPadNormalizedInsets(top: 0.035, leading: 0.045, bottom: 0.035, trailing: 0.045)
        return PocketPadSkinArtboardVariant(
            id: "\(orientation.rawValue)-v1",
            orientation: orientation,
            canvasWidth: size.width,
            canvasHeight: size.height,
            safeAreaInsets: safeArea,
            controls: controls
        )
    }

    private static func completingOrientations(
        _ original: GamepadConfigurationProfile
    ) -> GamepadConfigurationProfile {
        var profile = original
        let baseOrientation = profile.customization.deviceCanvas.editorDeviceFrame.orientation
        if baseOrientation == .landscape, profile.landscapeCustomization == nil {
            profile.landscapeCustomization = profile.customization
        } else if baseOrientation == .portrait, profile.portraitCustomization == nil {
            profile.portraitCustomization = profile.customization
        }
        if profile.portraitCustomization == nil {
            profile.copyLayoutVariant(from: .landscape, to: .portrait, automaticallyArrange: true)
        }
        if profile.landscapeCustomization == nil {
            profile.copyLayoutVariant(from: .portrait, to: .landscape, automaticallyArrange: true)
        }
        return profile
    }

    private static func stabilized(
        _ original: GamepadConfigurationProfile,
        seed: String
    ) -> GamepadConfigurationProfile {
        var profile = original
        profile.id = deterministicUUID("profile:\(seed)")
        profile.updatedAt = 0
        profile.customization = stabilized(profile.customization, seed: "\(seed):base")
        profile.landscapeCustomization = profile.landscapeCustomization.map { stabilized($0, seed: "\(seed):landscape") }
        profile.portraitCustomization = profile.portraitCustomization.map { stabilized($0, seed: "\(seed):portrait") }
        return profile.normalized
    }

    private static func stabilized(_ original: GamepadCustomization, seed: String) -> GamepadCustomization {
        var customization = original
        var replacements: [UUID: UUID] = [:]
        for index in customization.customButtons.indices {
            let oldID = customization.customButtons[index].id
            let newID = deterministicUUID("\(seed):custom:\(index):\(customization.customButtons[index].controlKind.rawValue):\(customization.customButtons[index].mappedButton.rawValue)")
            customization.customButtons[index].id = newID
            replacements[oldID] = newID
        }
        if var metadata = customization.designMetadata {
            metadata.layerOrder = metadata.layerOrder.map { identity in
                guard case .custom(let id) = identity, let replacement = replacements[id] else { return identity }
                return .custom(replacement)
            }
            metadata.groups = metadata.groups.map { group in
                var copy = group
                copy.children = group.children.map { identity in
                    guard case .custom(let id) = identity, let replacement = replacements[id] else { return identity }
                    return .custom(replacement)
                }
                return copy
            }
            customization.designMetadata = metadata
        }
        customization.updatedAt = 0
        return customization.normalized
    }

    private static func deterministicUUID(_ value: String) -> UUID {
        let digest = SHA256.hash(data: Data(value.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func kebabCase(_ value: String) -> String {
        var result = ""
        for character in value {
            if character.isUppercase {
                if !result.isEmpty { result.append("-") }
                result.append(character.lowercased())
            } else {
                result.append(character)
            }
        }
        return result
    }
}

public enum PocketPadSkinScaffoldError: Error, LocalizedError, Equatable {
    case invalidIdentity
    case unknownArtboard(String)
    case destinationNotEmpty(String)
    case cannotWrite(String)

    public var errorDescription: String? {
        switch self {
        case .invalidIdentity: "Skin scaffolds require a valid reverse-DNS identifier and semantic version."
        case .unknownArtboard(let value): "Unknown skin artboard: \(value)."
        case .destinationNotEmpty(let path): "Scaffold destination is not empty: \(path). Use --force to replace it."
        case .cannotWrite(let message): "Could not write skin scaffold: \(message)"
        }
    }
}

public enum PocketPadSkinScaffolder {
    public static let sourceFileName = "skin-source.json"

    @discardableResult
    public static func write(
        name: String,
        identifier: String,
        artboardID: String = PocketPadSkinArtboardCatalog.defaultID,
        to destination: URL,
        force: Bool = false,
        fileManager: FileManager = .default
    ) throws -> PocketPadSkinWorkspace {
        guard PocketPadSkinPackageValidator.isValidReverseDNSIdentifier(identifier),
              PocketPadSemanticVersion("1.0.0") != nil
        else { throw PocketPadSkinScaffoldError.invalidIdentity }
        guard PocketPadSkinArtboardCatalog.resolve(artboardID) != nil else {
            throw PocketPadSkinScaffoldError.unknownArtboard(artboardID)
        }
        if fileManager.fileExists(atPath: destination.path) {
            let contents = (try? fileManager.contentsOfDirectory(atPath: destination.path)) ?? []
            if !contents.isEmpty {
                guard force else { throw PocketPadSkinScaffoldError.destinationNotEmpty(destination.path) }
                try fileManager.removeItem(at: destination)
            }
        }
        let workspace = PocketPadSkinWorkspace.starter(name: name, identifier: identifier, artboardID: artboardID)
        do {
            try fileManager.createDirectory(
                at: destination.appendingPathComponent("sources/artwork", isDirectory: true),
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: destination.appendingPathComponent("sources/icons", isDirectory: true),
                withIntermediateDirectories: true
            )
            try fileManager.createDirectory(
                at: destination.appendingPathComponent("reviews", isDirectory: true),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(workspace).write(
                to: destination.appendingPathComponent(sourceFileName),
                options: .atomic
            )
            try readme(name: name, artboardID: artboardID).write(
                to: destination.appendingPathComponent("README.md"),
                atomically: true,
                encoding: .utf8
            )
            try starterSVG(name: name).write(
                to: destination.appendingPathComponent("sources/artwork/accent-lines.svg"),
                atomically: true,
                encoding: .utf8
            )
            try reviewReadme.write(
                to: destination.appendingPathComponent("reviews/README.md"),
                atomically: true,
                encoding: .utf8
            )
            try pendingHumanApproval.write(
                to: destination.appendingPathComponent("reviews/human-approval.json"),
                atomically: true,
                encoding: .utf8
            )
            try "build/\n.DS_Store\n".write(
                to: destination.appendingPathComponent(".gitignore"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            throw PocketPadSkinScaffoldError.cannotWrite(error.localizedDescription)
        }
        return workspace
    }

    private static func readme(name: String, artboardID: String) -> String {
        """
        # \(name)

        Editable Thumble skin workspace targeting `\(artboardID)`.

        - Edit `skin-source.json` for palette, materials, components, semantic assignments, and preview requests.
        - Keep authoring SVG under `sources/`; SVG is sanitized and rasterized during compilation and is never shipped at runtime.
        - Treat `build/` as generated output.
        - Compile with `thumble skin compile . --strict`.
        - Review the native contact sheet before publication.
        """ + "\n"
    }

    private static let reviewReadme = """
    # Review evidence

    Keep versioned native-renderer contact sheets and independent critique reports here.

    `human-approval.json` begins as `pending`. Agents and automation must never change it to `approved` or infer consent. Only a human may record approval after reviewing the named contact sheet and exact package hash.
    """ + "\n"

    private static let pendingHumanApproval = """
    {
      "schema": "com.codybontecou.pocketpad.skin-human-approval",
      "version": 1,
      "status": "pending",
      "approvedBy": null,
      "approvedAt": null,
      "reviewedContactSheet": null,
      "packageSHA256": null,
      "notes": null
    }
    """ + "\n"

    private static func starterSVG(name: String) -> String {
        let escaped = name
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1748 804" role="img" aria-label="\(escaped) accent artwork">
          <defs>
            <linearGradient id="accent" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0" stop-color="#B7A7E8" stop-opacity="0.52"/>
              <stop offset="1" stop-color="#D95F91" stop-opacity="0.18"/>
            </linearGradient>
          </defs>
          <path d="M80 150 C420 40 650 210 920 105 S1430 30 1668 170" fill="none" stroke="url(#accent)" stroke-width="3"/>
          <path d="M80 654 C420 764 650 594 920 699 S1430 774 1668 634" fill="none" stroke="url(#accent)" stroke-width="2" opacity="0.62"/>
        </svg>
        """ + "\n"
    }
}
