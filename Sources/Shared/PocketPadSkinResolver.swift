import Foundation
import SwiftUI

public struct PocketPadSkinReference: Codable, Equatable, Hashable, Sendable {
    public var identifier: String
    public var version: String

    public init(identifier: String, version: String) {
        self.identifier = identifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.version = version.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var isValid: Bool {
        PocketPadSkinPackageValidator.isValidReverseDNSIdentifier(identifier)
            && PocketPadSemanticVersion(version) != nil
    }
}

public struct PocketPadSkinApplicationOptions: Equatable, Sendable {
    /// Existing per-control appearance remains the final cascade layer when enabled.
    public var preservesLocalControlAppearance: Bool
    /// Existing non-default background and label choices remain the final cascade layer when enabled.
    public var preservesLocalKeypadAppearance: Bool

    public init(
        preservesLocalControlAppearance: Bool = true,
        preservesLocalKeypadAppearance: Bool = true
    ) {
        self.preservesLocalControlAppearance = preservesLocalControlAppearance
        self.preservesLocalKeypadAppearance = preservesLocalKeypadAppearance
    }

    public static let preservingUserOverrides = PocketPadSkinApplicationOptions()
    public static let replacingAppearance = PocketPadSkinApplicationOptions(
        preservesLocalControlAppearance: false,
        preservesLocalKeypadAppearance: false
    )
}

public enum PocketPadSkinResolver {
    /// Produces a render-ready customization without mutating the saved profile.
    public static func applying(
        package: PocketPadSkinPackage,
        to customization: GamepadCustomization,
        orientation: PocketPadSkinOrientation,
        colorScheme: PocketPadSkinColorScheme,
        options: PocketPadSkinApplicationOptions = .preservingUserOverrides,
        overrideBaseline: GamepadCustomization? = nil
    ) -> GamepadCustomization {
        guard let skin = package.skin else { return customization.normalized }
        let original = customization.normalized
        let baseline = overrideBaseline?.normalized
        let appearance = skin.appearance(orientation: orientation, colorScheme: colorScheme)
        let compatibility = PocketPadSkinCompatibilityEvaluator.evaluate(
            package.manifest.compatibility,
            customization: original,
            orientation: orientation
        )
        var result = original

        result.assetLibrary = mergedAssetLibrary(
            package: package,
            local: original.assetLibrary,
            baseline: baseline?.assetLibrary
        )
        result.styleLibrary = mergedStyleLibrary(
            skin: appearance.styleLibrary,
            local: original.styleLibrary,
            baseline: baseline?.styleLibrary
        )
        result.artworkLayers = compatibility.allowsTemplateArtwork
            ? (appearance.artworkLayers ?? [])
            : []

        if let background = appearance.backgroundFillStyle,
           package.manifest.compatibility?.mode != .templateAligned || compatibility.allowsTemplateArtwork {
            let shouldPreserve: Bool
            if options.preservesLocalKeypadAppearance, let baseline {
                shouldPreserve = original.hasBackgroundAppearanceDifferent(from: baseline)
            } else {
                shouldPreserve = options.preservesLocalKeypadAppearance
                    && original.hasCustomBackgroundFill(for: colorScheme.swiftUIColorScheme)
            }
            if !shouldPreserve {
                result.backgroundFillStyle = background
                result.backgroundLightFillStyle = nil
                result.backgroundDarkFillStyle = nil
                result.backgroundLightColor = nil
                result.backgroundDarkColor = nil
            }
        }
        if let accent = appearance.accentStyle {
            let hasLocalAccentOverride = baseline.map { original.accentStyle != $0.accentStyle }
                ?? (original.accentStyle != .monochrome)
            if !options.preservesLocalKeypadAppearance || !hasLocalAccentOverride {
                result.accentStyle = accent
            }
        }
        if let showsLabels = appearance.showsButtonLabels {
            let hasLocalLabelOverride = baseline.map { original.showsButtonLabels != $0.showsButtonLabels }
                ?? (original.showsButtonLabels != true)
            if !options.preservesLocalKeypadAppearance || !hasLocalLabelOverride {
                result.showsButtonLabels = showsLabels
            }
        }

        for button in GameButton.builtInControls {
            let role = original.elements.first(where: { $0.builtInButton == button })?.visualRole
                ?? GamepadVisualRole.inferred(for: button, controlKind: .button)
            let skinControl = appearance.controlAppearance(for: button, controlKind: .button, visualRole: role)
            let local = original.buttonCustomization(for: button)
            result.setButtonCustomization(
                applying(
                    skinControl,
                    to: local,
                    preserveLocal: options.preservesLocalControlAppearance,
                    baseline: baseline?.buttonCustomization(for: button)
                ),
                for: button
            )
        }

        for index in result.customButtons.indices {
            let local = original.customButtons.first(where: { $0.id == result.customButtons[index].id })?.layout
                ?? result.customButtons[index].layout
            let baselineLayout = baseline?.customButtons.first(where: { $0.id == result.customButtons[index].id })?.layout
            let control = result.customButtons[index]
            let role = control.visualRole
                ?? GamepadVisualRole.inferred(for: control.mappedButton, controlKind: control.controlKind)
            let skinControl = appearance.controlAppearance(
                for: control.mappedButton,
                controlKind: control.controlKind,
                visualRole: role
            )
            result.customButtons[index].layout = applying(
                skinControl,
                to: local,
                preserveLocal: options.preservesLocalControlAppearance,
                baseline: baselineLayout
            )
        }

        let topBarSkin = appearance.controlAppearance(for: .system)
        result.topBarActivationRegion = applying(
            topBarSkin,
            to: original.topBarActivationRegion,
            preserveLocal: options.preservesLocalControlAppearance,
            baseline: baseline?.topBarActivationRegion
        )

        for item in result.controlBarItems {
            let role: GamepadVisualRole = switch item {
            case .profileMenu, .launchTarget, .editLayout, .settings, .home: .utility
            case .connectionStatus, .connectionAction, .spacer: .system
            }
            let skinControl = appearance.controlAppearance(for: role)
            let local = original.controlBarItemCustomization(for: item)
            result.setControlBarItemCustomization(
                applying(
                    skinControl,
                    to: local,
                    preserveLocal: options.preservesLocalControlAppearance,
                    baseline: baseline?.controlBarItemCustomization(for: item)
                ),
                for: item
            )
        }

        return result.normalized.resolvingAssetReferences()
    }

    private static func applying(
        _ appearance: PocketPadSkinControlAppearance,
        to local: GamepadButtonCustomization,
        preserveLocal: Bool,
        baseline: GamepadButtonCustomization?
    ) -> GamepadButtonCustomization {
        let appearance = appearance.normalized
        var result = local
        let localSnapshot = local.styleSnapshot

        // Geometry, hit insets, labels, mappings, and accessibility remain native/local.
        result.clearVisualAppearance()
        if let value = appearance.styleID { result.styleID = value }
        if let value = appearance.shape { result.shape = value }
        if let value = appearance.accentStyle { result.accentStyle = value }
        if let value = appearance.visualStyle { result.visualStyle = value }
        if let value = appearance.icon { result.icon = value }
        if let value = appearance.hapticFeedback { result.hapticFeedback = value; result.hapticStyle = nil }
        if let value = appearance.cornerRadius { result.cornerRadius = value; result.cornerRadii = nil }
        if let value = appearance.cornerRadii { result.cornerRadii = value; result.cornerRadius = nil }
        if let value = appearance.shadowStrength { result.shadowStrength = value }
        if let value = appearance.joystickKnobColor { result.joystickKnobColor = value }
        if let value = appearance.joystickVisualStyle { result.joystickVisualStyle = value }

        if preserveLocal, let baseline {
            result.applyStyleDifferences(from: local, baseline: baseline)
        } else if preserveLocal {
            result.applyNonDefaultStyleSnapshot(localSnapshot)
        }
        return result.normalized
    }

    private static func mergedStyleLibrary(
        skin: GamepadStyleLibrary,
        local: GamepadStyleLibrary,
        baseline: GamepadStyleLibrary?
    ) -> GamepadStyleLibrary {
        var styles = skin.normalized.styles
        let baselineByID = Dictionary(uniqueKeysWithValues: (baseline?.normalized.styles ?? []).map { ($0.id, $0) })
        for style in local.normalized.styles where baseline == nil || baselineByID[style.id] != style {
            if let index = styles.firstIndex(where: { $0.id == style.id }) {
                styles[index] = style
            } else {
                styles.append(style)
            }
        }
        return GamepadStyleLibrary(styles: styles).normalized
    }

    private static func mergedAssetLibrary(
        package: PocketPadSkinPackage,
        local: GamepadAssetLibrary,
        baseline: GamepadAssetLibrary?
    ) -> GamepadAssetLibrary {
        var assets: [GamepadAsset] = package.manifest.assets.compactMap { descriptor in
            guard let data = package.assets[descriptor.id] else { return nil }
            return GamepadAsset(
                id: descriptor.id,
                name: URL(fileURLWithPath: descriptor.path).deletingPathExtension().lastPathComponent,
                fileName: URL(fileURLWithPath: descriptor.path).lastPathComponent,
                contentType: descriptor.contentType,
                data: data,
                byteCount: descriptor.byteCount,
                hash: descriptor.sha256,
                role: descriptor.role
            )
        }
        let baselineByID = Dictionary(uniqueKeysWithValues: (baseline?.normalized.assets ?? []).map { ($0.id, $0) })
        for asset in local.normalized.assets where baseline == nil || baselineByID[asset.id] != asset {
            if let index = assets.firstIndex(where: { $0.id == asset.id }) {
                // A dehydrated profile descriptor points back to the package payload.
                // Only a local asset with actual data replaces that package resource.
                if asset.data != nil || assets[index].data == nil {
                    assets[index] = asset
                }
            } else {
                assets.append(asset)
            }
        }
        return GamepadAssetLibrary(assets: assets).normalized
    }
}

public extension GamepadCustomization {
    func applying(
        skinPackage: PocketPadSkinPackage,
        orientation: PocketPadSkinOrientation,
        colorScheme: PocketPadSkinColorScheme,
        options: PocketPadSkinApplicationOptions = .preservingUserOverrides,
        overrideBaseline: GamepadCustomization? = nil
    ) -> GamepadCustomization {
        PocketPadSkinResolver.applying(
            package: skinPackage,
            to: self,
            orientation: orientation,
            colorScheme: colorScheme,
            options: options,
            overrideBaseline: overrideBaseline
        )
    }

    fileprivate func hasBackgroundAppearanceDifferent(from baseline: GamepadCustomization) -> Bool {
        backgroundFillStyle != baseline.backgroundFillStyle
            || backgroundLightFillStyle != baseline.backgroundLightFillStyle
            || backgroundDarkFillStyle != baseline.backgroundDarkFillStyle
            || artworkLayers != baseline.artworkLayers
            || backgroundLightColor != baseline.backgroundLightColor
            || backgroundDarkColor != baseline.backgroundDarkColor
    }

    /// Removes package-owned binary payloads while retaining IDs, hashes, and metadata.
    /// Saved profiles therefore reference archive assets instead of duplicating Base64 data.
    func dehydratingAssets(from package: PocketPadSkinPackage) -> GamepadCustomization {
        var copy = self
        let packageAssets = package.assets
        copy.backgroundFillStyle = copy.backgroundFillStyle?.dehydrating(packageAssets: packageAssets)
        copy.backgroundLightFillStyle = copy.backgroundLightFillStyle?.dehydrating(packageAssets: packageAssets)
        copy.backgroundDarkFillStyle = copy.backgroundDarkFillStyle?.dehydrating(packageAssets: packageAssets)
        copy.artworkLayers = copy.artworkLayers.map { layer in
            var layer = layer
            layer.fillStyle = layer.fillStyle?.dehydrating(packageAssets: packageAssets)
            return layer
        }
        copy.styleLibrary = copy.styleLibrary.dehydrating(packageAssets: packageAssets)
        for button in GameButton.allCases {
            guard var layout = copy.buttonCustomizations[button] else { continue }
            layout.dehydrateAssetReferences(packageAssets: packageAssets)
            copy.buttonCustomizations[button] = layout
        }
        for index in copy.customButtons.indices {
            copy.customButtons[index].layout.dehydrateAssetReferences(packageAssets: packageAssets)
        }
        copy.topBarActivationRegion.dehydrateAssetReferences(packageAssets: packageAssets)
        for index in copy.controlBarItemCustomizations.indices {
            copy.controlBarItemCustomizations[index].appearance.dehydrateAssetReferences(packageAssets: packageAssets)
        }
        for index in copy.assetLibrary.assets.indices {
            let id = copy.assetLibrary.assets[index].id
            if let packageData = packageAssets[id], copy.assetLibrary.assets[index].data == packageData {
                copy.assetLibrary.assets[index].data = nil
            }
        }
        return copy.normalized
    }

    func resolvingAssetReferences() -> GamepadCustomization {
        var copy = self
        copy.backgroundFillStyle = copy.backgroundFillStyle?.resolvingAssets(in: copy.assetLibrary)
        copy.backgroundLightFillStyle = copy.backgroundLightFillStyle?.resolvingAssets(in: copy.assetLibrary)
        copy.backgroundDarkFillStyle = copy.backgroundDarkFillStyle?.resolvingAssets(in: copy.assetLibrary)
        copy.artworkLayers = copy.artworkLayers.map { layer in
            var layer = layer
            layer.fillStyle = layer.fillStyle?.resolvingAssets(in: copy.assetLibrary)
            return layer
        }
        copy.styleLibrary = copy.styleLibrary.resolvingAssets(in: copy.assetLibrary)
        for button in GameButton.allCases {
            guard var layout = copy.buttonCustomizations[button] else { continue }
            layout.resolveAssetReferences(in: copy.assetLibrary)
            copy.buttonCustomizations[button] = layout
        }
        for index in copy.customButtons.indices {
            copy.customButtons[index].layout.resolveAssetReferences(in: copy.assetLibrary)
        }
        copy.topBarActivationRegion.resolveAssetReferences(in: copy.assetLibrary)
        for index in copy.controlBarItemCustomizations.indices {
            copy.controlBarItemCustomizations[index].appearance.resolveAssetReferences(in: copy.assetLibrary)
        }
        return copy.normalized
    }
}

public extension GamepadFillStyle {
    func resolvingAssets(in library: GamepadAssetLibrary) -> GamepadFillStyle {
        guard case .image(var image) = normalized,
              image.data == nil,
              let assetID = image.assetID,
              let data = library.asset(id: assetID)?.data
        else { return normalized }
        image.data = data
        return .image(image.normalized)
    }
}

private extension GamepadFillStyle {
    func dehydrating(packageAssets: [String: Data]) -> GamepadFillStyle {
        guard case .image(var image) = normalized,
              let assetID = image.assetID,
              let packageData = packageAssets[assetID],
              image.data == packageData
        else { return normalized }
        image.data = nil
        return .image(image.normalized)
    }
}

extension GamepadControlStateStyle {
    func resolvingAssets(in library: GamepadAssetLibrary) -> GamepadControlStateStyle {
        var copy = self
        copy.fillStyle = copy.fillStyle?.resolvingAssets(in: library)
        return copy.normalized
    }

    fileprivate func dehydrating(packageAssets: [String: Data]) -> GamepadControlStateStyle {
        var copy = self
        copy.fillStyle = copy.fillStyle?.dehydrating(packageAssets: packageAssets)
        return copy.normalized
    }
}

extension GamepadControlVisualStyle {
    func resolvingAssets(in library: GamepadAssetLibrary) -> GamepadControlVisualStyle {
        GamepadControlVisualStyle(
            normal: normal.resolvingAssets(in: library),
            pressed: pressed?.resolvingAssets(in: library),
            active: active?.resolvingAssets(in: library),
            disabled: disabled?.resolvingAssets(in: library),
            icon: icon,
            hapticStyle: hapticStyle,
            hapticFeedback: hapticFeedback
        )
    }

    fileprivate func dehydrating(packageAssets: [String: Data]) -> GamepadControlVisualStyle {
        GamepadControlVisualStyle(
            normal: normal.dehydrating(packageAssets: packageAssets),
            pressed: pressed?.dehydrating(packageAssets: packageAssets),
            active: active?.dehydrating(packageAssets: packageAssets),
            disabled: disabled?.dehydrating(packageAssets: packageAssets),
            icon: icon,
            hapticStyle: hapticStyle,
            hapticFeedback: hapticFeedback
        )
    }
}

extension GamepadStyleLibrary {
    func resolvingAssets(in library: GamepadAssetLibrary) -> GamepadStyleLibrary {
        GamepadStyleLibrary(styles: normalized.styles.map { style in
            var style = style
            style.visualStyle = style.visualStyle.resolvingAssets(in: library)
            return style
        }).normalized
    }

    fileprivate func dehydrating(packageAssets: [String: Data]) -> GamepadStyleLibrary {
        GamepadStyleLibrary(styles: normalized.styles.map { style in
            var style = style
            style.visualStyle = style.visualStyle.dehydrating(packageAssets: packageAssets)
            return style
        }).normalized
    }
}

extension GamepadButtonCustomization {
    var resolvedHitInsets: GamepadHitInsets {
        hitInsets?.normalized ?? .runtimeDefault
    }

    mutating func resolveAssetReferences(in library: GamepadAssetLibrary) {
        fillStyle = fillStyle?.resolvingAssets(in: library)
        lightFillStyle = lightFillStyle?.resolvingAssets(in: library)
        darkFillStyle = darkFillStyle?.resolvingAssets(in: library)
        visualStyle = visualStyle?.resolvingAssets(in: library)
    }

    fileprivate mutating func dehydrateAssetReferences(packageAssets: [String: Data]) {
        fillStyle = fillStyle?.dehydrating(packageAssets: packageAssets)
        lightFillStyle = lightFillStyle?.dehydrating(packageAssets: packageAssets)
        darkFillStyle = darkFillStyle?.dehydrating(packageAssets: packageAssets)
        visualStyle = visualStyle?.dehydrating(packageAssets: packageAssets)
    }

    fileprivate mutating func clearVisualAppearance() {
        shape = nil
        accentStyle = nil
        fillColor = nil
        lightFillColor = nil
        darkFillColor = nil
        fillStyle = nil
        lightFillStyle = nil
        darkFillStyle = nil
        joystickKnobColor = nil
        lightJoystickKnobColor = nil
        darkJoystickKnobColor = nil
        joystickVisualStyle = nil
        styleID = nil
        visualStyle = nil
        icon = nil
        hapticStyle = nil
        hapticFeedback = nil
        cornerRadius = nil
        cornerRadii = nil
        shadowStrength = Self.defaultShadowStrength
    }

    fileprivate mutating func applyNonDefaultStyleSnapshot(_ local: GamepadButtonCustomization) {
        if local.shape != nil { shape = local.shape }
        if local.accentStyle != nil { accentStyle = local.accentStyle }
        if local.fillColor != nil { fillColor = local.fillColor }
        if local.lightFillColor != nil { lightFillColor = local.lightFillColor }
        if local.darkFillColor != nil { darkFillColor = local.darkFillColor }
        if local.fillStyle != nil { fillStyle = local.fillStyle }
        if local.lightFillStyle != nil { lightFillStyle = local.lightFillStyle }
        if local.darkFillStyle != nil { darkFillStyle = local.darkFillStyle }
        if local.joystickKnobColor != nil { joystickKnobColor = local.joystickKnobColor }
        if local.lightJoystickKnobColor != nil { lightJoystickKnobColor = local.lightJoystickKnobColor }
        if local.darkJoystickKnobColor != nil { darkJoystickKnobColor = local.darkJoystickKnobColor }
        if local.joystickVisualStyle != nil { joystickVisualStyle = local.joystickVisualStyle }
        if local.styleID != nil { styleID = local.styleID }
        if local.visualStyle != nil { visualStyle = local.visualStyle }
        if local.icon != nil { icon = local.icon }
        if local.hapticStyle != nil { hapticStyle = local.hapticStyle }
        if local.hapticFeedback != nil { hapticFeedback = local.hapticFeedback }
        if local.cornerRadius != nil { cornerRadius = local.cornerRadius; cornerRadii = nil }
        if local.cornerRadii != nil { cornerRadii = local.cornerRadii; cornerRadius = nil }
        if abs(local.shadowStrength - Self.defaultShadowStrength) >= 0.001 {
            shadowStrength = local.shadowStrength
        }
    }

    /// Applies only fields changed since a skin baseline was captured, including intentional clears.
    fileprivate mutating func applyStyleDifferences(
        from local: GamepadButtonCustomization,
        baseline: GamepadButtonCustomization
    ) {
        if local.shape != baseline.shape { shape = local.shape }
        if local.accentStyle != baseline.accentStyle { accentStyle = local.accentStyle }
        if local.fillColor != baseline.fillColor { fillColor = local.fillColor }
        if local.lightFillColor != baseline.lightFillColor { lightFillColor = local.lightFillColor }
        if local.darkFillColor != baseline.darkFillColor { darkFillColor = local.darkFillColor }
        if local.fillStyle != baseline.fillStyle { fillStyle = local.fillStyle }
        if local.lightFillStyle != baseline.lightFillStyle { lightFillStyle = local.lightFillStyle }
        if local.darkFillStyle != baseline.darkFillStyle { darkFillStyle = local.darkFillStyle }
        if local.joystickKnobColor != baseline.joystickKnobColor { joystickKnobColor = local.joystickKnobColor }
        if local.lightJoystickKnobColor != baseline.lightJoystickKnobColor { lightJoystickKnobColor = local.lightJoystickKnobColor }
        if local.darkJoystickKnobColor != baseline.darkJoystickKnobColor { darkJoystickKnobColor = local.darkJoystickKnobColor }
        if local.joystickVisualStyle != baseline.joystickVisualStyle { joystickVisualStyle = local.joystickVisualStyle }
        if local.styleID != baseline.styleID { styleID = local.styleID }
        if local.visualStyle != baseline.visualStyle { visualStyle = local.visualStyle }
        if local.icon != baseline.icon { icon = local.icon }
        if local.hapticStyle != baseline.hapticStyle { hapticStyle = local.hapticStyle }
        if local.hapticFeedback != baseline.hapticFeedback { hapticFeedback = local.hapticFeedback }
        if local.cornerRadius != baseline.cornerRadius { cornerRadius = local.cornerRadius }
        if local.cornerRadii != baseline.cornerRadii { cornerRadii = local.cornerRadii }
        if abs(local.shadowStrength - baseline.shadowStrength) >= 0.001 { shadowStrength = local.shadowStrength }
    }
}

private extension PocketPadSkinColorScheme {
    var swiftUIColorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}
