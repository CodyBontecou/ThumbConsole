import Foundation

#if os(macOS)
import AppKit
#endif

public enum PocketPadSVGRasterizerError: Error, LocalizedError, Equatable {
    case sourceTooLarge
    case unsafeConstruct(String)
    case excessiveComplexity
    case invalidDimensions
    case unsupportedPlatform
    case cannotDecode
    case cannotRender

    public var errorDescription: String? {
        switch self {
        case .sourceTooLarge: "SVG authoring source exceeds the 1 MB limit."
        case .unsafeConstruct(let value): "SVG authoring source contains unsafe content: \(value)."
        case .excessiveComplexity: "SVG authoring source exceeds the node, path, or filter complexity limit."
        case .invalidDimensions: "SVG raster dimensions must be between 16 and 4096 pixels."
        case .unsupportedPlatform: "SVG compilation is supported by the macOS authoring CLI."
        case .cannotDecode: "The sanitized SVG could not be decoded."
        case .cannotRender: "The sanitized SVG could not be rasterized to PNG."
        }
    }
}

public enum PocketPadSVGRasterizer {
    public static let maximumSourceBytes = 1_000_000
    public static let maximumNodeCount = 4_000
    public static let maximumPathCount = 1_000
    public static let maximumFilterCount = 64

    /// SVG is source-only. The sanitized bytes are rasterized during compilation and never enter a package.
    public static func sanitize(_ data: Data) throws -> Data {
        guard data.count <= maximumSourceBytes else { throw PocketPadSVGRasterizerError.sourceTooLarge }
        guard var source = String(data: data, encoding: .utf8) else { throw PocketPadSVGRasterizerError.cannotDecode }
        source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = source.lowercased()
        guard lower.hasPrefix("<svg") || lower.hasPrefix("<?xml") else {
            throw PocketPadSVGRasterizerError.cannotDecode
        }

        let forbiddenTokens = [
            "<!doctype", "<!entity", "<script", "<foreignobject", "<iframe", "<object", "<embed",
            "<animate", "<animatemotion", "<animatetransform", "<set", "@import", "javascript:",
            "data:text/html"
        ]
        for token in forbiddenTokens where lower.contains(token) {
            throw PocketPadSVGRasterizerError.unsafeConstruct(token)
        }

        let eventPattern = #"\son[a-zA-Z]+\s*="#
        if lower.range(of: eventPattern, options: .regularExpression) != nil {
            throw PocketPadSVGRasterizerError.unsafeConstruct("event handler")
        }
        let hrefPattern = #"(?:href|xlink:href)\s*=\s*[\"']\s*(?!#)[^\"']+[\"']"#
        if source.range(of: hrefPattern, options: [.regularExpression, .caseInsensitive]) != nil {
            throw PocketPadSVGRasterizerError.unsafeConstruct("external href")
        }

        let urlPattern = #"url\s*\(\s*([^\)]*)\)"#
        if let expression = try? NSRegularExpression(pattern: urlPattern, options: [.caseInsensitive]) {
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            for match in expression.matches(in: source, range: range) {
                guard let valueRange = Range(match.range(at: 1), in: source) else { continue }
                let value = source[valueRange]
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \t\r\n\"'"))
                if !value.hasPrefix("#") {
                    throw PocketPadSVGRasterizerError.unsafeConstruct("external CSS URL")
                }
            }
        }

        let nodeCount = lower.components(separatedBy: "<").count - 1
        let pathCount = lower.components(separatedBy: "<path").count - 1
        let filterCount = lower.components(separatedBy: "<filter").count - 1
        guard nodeCount <= maximumNodeCount,
              pathCount <= maximumPathCount,
              filterCount <= maximumFilterCount
        else { throw PocketPadSVGRasterizerError.excessiveComplexity }
        return Data(source.utf8)
    }

    public static func rasterize(_ data: Data, width: Int, height: Int) throws -> Data {
        guard (16...4096).contains(width), (16...4096).contains(height) else {
            throw PocketPadSVGRasterizerError.invalidDimensions
        }
        let sanitized = try sanitize(data)
        #if os(macOS)
        guard let image = NSImage(data: sanitized) else { throw PocketPadSVGRasterizerError.cannotDecode }
        return try drawPNG(width: width, height: height) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
        #else
        throw PocketPadSVGRasterizerError.unsupportedPlatform
        #endif
    }

    public static func composite(basePNG: Data, overlayPNG: Data, width: Int, height: Int) throws -> Data {
        guard (16...4096).contains(width), (16...4096).contains(height) else {
            throw PocketPadSVGRasterizerError.invalidDimensions
        }
        #if os(macOS)
        guard let base = NSImage(data: basePNG), let overlay = NSImage(data: overlayPNG) else {
            throw PocketPadSVGRasterizerError.cannotDecode
        }
        return try drawPNG(width: width, height: height) { rect in
            base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            overlay.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
        #else
        throw PocketPadSVGRasterizerError.unsupportedPlatform
        #endif
    }

    #if os(macOS)
    private static func drawPNG(
        width: Int,
        height: Int,
        drawing: (NSRect) -> Void
    ) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { throw PocketPadSVGRasterizerError.cannotRender }
        bitmap.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw PocketPadSVGRasterizerError.cannotRender
        }
        NSGraphicsContext.current = graphics
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        drawing(NSRect(x: 0, y: 0, width: width, height: height))
        graphics.flushGraphics()
        guard let data = bitmap.representation(
            using: NSBitmapImageRep.FileType.png,
            properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 0.85]
        ) else {
            throw PocketPadSVGRasterizerError.cannotRender
        }
        return data
    }
    #endif
}
