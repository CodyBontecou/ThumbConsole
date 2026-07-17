#if os(macOS)
import AppKit
import ImageIO
import XCTest

@MainActor
final class PocketPadNativeSkinPreviewRendererTests: XCTestCase {
    func testNativeRendererIsDeterministicAndUsesImagePayloads() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketPadNativePreviewTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)

        let redImage = try solidPNG(color: .systemRed)
        var customization = GamepadCustomization.blankCanvas
        customization.backgroundFillStyle = .image(GamepadImageFill(
            data: redImage,
            contentMode: .fill,
            resizingMode: .scale
        ))
        let item = PocketPadNativeSkinPreviewItem(
            title: "payload",
            customization: customization,
            colorScheme: .light,
            state: .normal
        )
        let first = temporary.appendingPathComponent("first.png")
        let second = temporary.appendingPathComponent("second.png")
        try PocketPadNativeSkinPreviewRenderer.writePNG(item: item, outputURL: first, scale: 1)
        try PocketPadNativeSkinPreviewRenderer.writePNG(item: item, outputURL: second, scale: 1)

        XCTAssertEqual(try Data(contentsOf: first), try Data(contentsOf: second))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(first as CFURL, nil))
        let rendered = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let size = customization.deviceCanvas.editorDeviceFrame.screenRect.size
        XCTAssertEqual(rendered.width, Int(size.width))
        XCTAssertEqual(rendered.height, Int(size.height))
        let color = try XCTUnwrap(NSBitmapImageRep(cgImage: rendered).colorAt(x: rendered.width / 2, y: rendered.height / 2))
        XCTAssertGreaterThan(color.redComponent, 0.8)
        XCTAssertLessThan(color.greenComponent, 0.35)
        XCTAssertLessThan(color.blueComponent, 0.35)
    }

    func testContactSheetContainsEveryRequestedState() throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketPadNativeContactSheetTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let output = temporary.appendingPathComponent("contact.png")
        let profile = try XCTUnwrap(PocketPadSkinArtboardCatalog.profile(for: PocketPadSkinArtboardCatalog.defaultID))
        let items = GamepadControlPresentationState.allCases.map { state in
            PocketPadNativeSkinPreviewItem(
                title: "landscape · dark · \(state.rawValue)",
                customization: profile.customization(for: .landscape),
                colorScheme: .dark,
                state: state
            )
        }

        try PocketPadNativeSkinPreviewRenderer.writeContactSheet(
            items: items,
            skinName: "Renderer Test",
            outputURL: output,
            columns: 2
        )
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(output as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 1104)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 902)
    }

    private func solidPNG(color: NSColor) throws -> Data {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 8, height: 8)).fill()
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
#endif
