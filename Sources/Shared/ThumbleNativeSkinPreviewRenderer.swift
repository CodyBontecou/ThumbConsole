#if os(macOS)
import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

public struct ThumbleNativeSkinPreviewItem: Sendable {
    public var title: String
    public var customization: GamepadCustomization
    public var colorScheme: ThumbleSkinColorScheme
    public var state: GamepadControlPresentationState

    public init(
        title: String,
        customization: GamepadCustomization,
        colorScheme: ThumbleSkinColorScheme,
        state: GamepadControlPresentationState
    ) {
        self.title = title
        self.customization = customization
        self.colorScheme = colorScheme
        self.state = state
    }
}

public enum ThumbleNativeSkinPreviewError: LocalizedError {
    case invalidScale
    case renderingFailed(String)
    case pngEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .invalidScale: "Preview scale must be between 0.5 and 4."
        case .renderingFailed(let title): "The native renderer could not draw \(title)."
        case .pngEncodingFailed: "The native renderer could not encode PNG output."
        }
    }
}

/// Offscreen SwiftUI renderer shared by the CLI and app previews. Control faces, image fills,
/// artwork layers, typography, effects, and state resolution use the same views as the app.
@MainActor
public enum ThumbleNativeSkinPreviewRenderer {
    public static func writePNG(
        item: ThumbleNativeSkinPreviewItem,
        outputURL: URL,
        scale: CGFloat = 2
    ) throws {
        let data = try pngData(item: item, scale: scale)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: .atomic)
    }

    public static func pngData(
        item: ThumbleNativeSkinPreviewItem,
        scale: CGFloat = 2
    ) throws -> Data {
        try pngData(render(item: item, scale: scale))
    }

    public static func writeContactSheet(
        items: [ThumbleNativeSkinPreviewItem],
        skinName: String,
        outputURL: URL,
        columns: Int = 4,
        scale: CGFloat = 1
    ) throws {
        guard scale.isFinite, (0.5...4).contains(scale) else {
            throw ThumbleNativeSkinPreviewError.invalidScale
        }
        let snapshots = try items.map { item in
            ThumbleRenderedPreview(title: item.title, image: try render(item: item, scale: 2))
        }
        let columnCount = max(1, min(columns, max(snapshots.count, 1)))
        let rows = snapshots.chunked(into: columnCount)
        let cellSize = CGSize(width: 520, height: 390)
        let spacing: CGFloat = 16
        let outer: CGFloat = 24
        let header: CGFloat = 58
        let width = outer * 2 + CGFloat(columnCount) * cellSize.width + CGFloat(max(0, columnCount - 1)) * spacing
        let height = outer * 2 + header + CGFloat(rows.count) * cellSize.height + CGFloat(max(0, rows.count - 1)) * spacing
        let view = ThumbleContactSheetView(
            skinName: skinName,
            rows: rows,
            cellSize: cellSize,
            spacing: spacing
        )
        .frame(width: width, height: height)
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: width, height: height)
        renderer.scale = scale
        renderer.isOpaque = true
        guard let image = renderer.cgImage else {
            throw ThumbleNativeSkinPreviewError.renderingFailed("contact sheet")
        }
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pngData(image).write(to: outputURL, options: .atomic)
    }

    public static func render(
        item: ThumbleNativeSkinPreviewItem,
        scale: CGFloat = 2
    ) throws -> CGImage {
        guard scale.isFinite, (0.5...4).contains(scale) else {
            throw ThumbleNativeSkinPreviewError.invalidScale
        }
        let customization = item.customization.resolvingAssetReferences().normalized
        let size = customization.deviceCanvas.editorDeviceFrame.screenRect.size
        let scheme: ColorScheme = item.colorScheme == .dark ? .dark : .light
        let view = ThumbleNativeSkinCanvas(
            customization: customization,
            state: item.state
        )
        .environment(\.colorScheme, scheme)
        .frame(width: size.width, height: size.height)
        .clipped()

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = scale
        renderer.isOpaque = true
        guard let image = renderer.cgImage else {
            throw ThumbleNativeSkinPreviewError.renderingFailed(item.title)
        }
        return image
    }

    private static func pngData(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { throw ThumbleNativeSkinPreviewError.pngEncodingFailed }
        let properties: [CFString: Any] = [
            kCGImagePropertyPNGDictionary: [
                kCGImagePropertyPNGInterlaceType: 0
            ]
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ThumbleNativeSkinPreviewError.pngEncodingFailed
        }
        return data as Data
    }
}

private struct ThumbleNativeSkinCanvas: View {
    let customization: GamepadCustomization
    let state: GamepadControlPresentationState

    var body: some View {
        let size = customization.deviceCanvas.editorDeviceFrame.screenRect.size
        let controls = customization.resolvedControls(in: size)
        ZStack(alignment: .topLeading) {
            GamepadFillShapeLayer(
                shape: Rectangle(),
                fillStyle: customization.keypadBackgroundFillStyle(scheme: resolvedScheme)
            )
            GamepadArtworkLayersView(layers: customization.artworkLayers, plane: .underlay)
            ForEach(controls) { control in
                GamepadRenderedControlFace(
                    control: control,
                    customization: customization,
                    state: state
                )
                .rotationEffect(.degrees(control.rotationDegrees))
                .position(control.center)
            }
            GamepadArtworkLayersView(layers: customization.artworkLayers, plane: .overlay)
        }
        .frame(width: size.width, height: size.height)
        .background(resolvedScheme == .dark ? Color.black : Color.white)
        .accessibilityHidden(true)
    }

    @Environment(\.colorScheme) private var resolvedScheme
}

private struct ThumbleRenderedPreview {
    var title: String
    var image: CGImage
}

private struct ThumbleContactSheetView: View {
    let skinName: String
    let rows: [[ThumbleRenderedPreview]]
    let cellSize: CGSize
    let spacing: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            VStack(alignment: .leading, spacing: 3) {
                Text(skinName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Text("THUMBLE NATIVE RENDERER · VARIANT & STATE REVIEW")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .frame(height: 42, alignment: .leading)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: spacing) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, preview in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(preview.title.uppercased())
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.72))
                                .lineLimit(1)
                            Image(decorative: preview.image, scale: 1)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(14)
                        .frame(width: cellSize.width, height: cellSize.height, alignment: .topLeading)
                        .background(Color(red: 0.075, green: 0.08, blue: 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                    }
                    if row.count < (rows.first?.count ?? row.count) {
                        ForEach(row.count..<(rows.first?.count ?? row.count), id: \.self) { _ in
                            Color.clear.frame(width: cellSize.width, height: cellSize.height)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color(red: 0.035, green: 0.04, blue: 0.055))
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
#endif
