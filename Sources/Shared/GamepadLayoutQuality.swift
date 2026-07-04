import Foundation
import CoreGraphics
import SwiftUI

#if os(macOS)
import AppKit
#endif

enum GamepadLayoutIssueSeverity: String, Codable, CaseIterable {
    case info
    case warning
    case error
}

struct GamepadLayoutIssue: Codable, Equatable {
    var severity: GamepadLayoutIssueSeverity
    var code: String
    var message: String
    var controls: [String]
    var metric: Double?
}

struct GamepadLayoutRectSummary: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = Double(rect.minX)
        y = Double(rect.minY)
        width = Double(rect.width)
        height = Double(rect.height)
    }
}

struct GamepadLayoutCanvasSummary: Codable, Equatable {
    var width: Double
    var height: Double

    init(_ size: CGSize) {
        width = Double(size.width)
        height = Double(size.height)
    }
}

struct GamepadLayoutControlSummary: Codable, Equatable {
    var id: String
    var mappedButton: GameButton
    var kind: String
    var label: String
    var shape: GamepadButtonShapeStyle
    var requestedFrame: GamepadLayoutRectSummary
    var resolvedFrame: GamepadLayoutRectSummary
    var displacement: Double
    var widthRatio: Double
    var heightRatio: Double

    init(requested: GamepadResolvedControl, resolved: GamepadResolvedControl, canvasSize: CGSize) {
        id = requested.id.id
        mappedButton = requested.mappedButton
        kind = requested.isJoystick ? "joystick" : "button"
        label = requested.label
        shape = requested.shape
        requestedFrame = GamepadLayoutRectSummary(requested.frame)
        resolvedFrame = GamepadLayoutRectSummary(resolved.frame)
        displacement = Double(hypot(resolved.center.x - requested.center.x, resolved.center.y - requested.center.y))
        widthRatio = Double(resolved.frame.width / max(canvasSize.width, 1))
        heightRatio = Double(resolved.frame.height / max(canvasSize.height, 1))
    }
}

struct GamepadLayoutQualitySummary: Codable, Equatable {
    var controlCount: Int
    var errorCount: Int
    var warningCount: Int
    var largestDisplacement: Double
    var largestWidthRatio: Double
    var largestHeightRatio: Double
    var layoutWidthCoverage: Double
    var layoutHeightCoverage: Double
    var bottomUnusedRatio: Double
}

struct GamepadLayoutQualityReport: Codable, Equatable {
    var profileName: String?
    var canvas: GamepadLayoutCanvasSummary
    var controls: [GamepadLayoutControlSummary]
    var issues: [GamepadLayoutIssue]
    var summary: GamepadLayoutQualitySummary

    var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }

    var hasWarnings: Bool {
        issues.contains { $0.severity == .warning }
    }

    var statusText: String {
        hasErrors ? "failed" : (hasWarnings ? "passed with warnings" : "passed")
    }
}

extension GamepadCustomization {
    func layoutQualityReport(
        profileName: String? = nil,
        canvasSize: CGSize? = nil
    ) -> GamepadLayoutQualityReport {
        let canvasSize = canvasSize ?? deviceCanvas.editorDeviceFrame.screenRect.size
        let requestedControls = GamepadLayoutResolver.preferredControls(for: self, in: canvasSize)
        let resolvedControls = resolvedControls(in: canvasSize)
        return GamepadLayoutQualityReport.make(
            profileName: profileName,
            canvasSize: canvasSize,
            requestedControls: requestedControls,
            resolvedControls: resolvedControls,
            validatesFreeformLayout: usesFreeformLayout
        )
    }
}

private extension GamepadLayoutQualityReport {
    static func make(
        profileName: String?,
        canvasSize: CGSize,
        requestedControls: [GamepadResolvedControl],
        resolvedControls: [GamepadResolvedControl],
        validatesFreeformLayout: Bool
    ) -> GamepadLayoutQualityReport {
        let resolvedByID = Dictionary(uniqueKeysWithValues: resolvedControls.map { ($0.id, $0) })
        let controlSummaries = requestedControls.compactMap { requested -> GamepadLayoutControlSummary? in
            guard let resolved = resolvedByID[requested.id] else { return nil }
            return GamepadLayoutControlSummary(requested: requested, resolved: resolved, canvasSize: canvasSize)
        }

        var issues: [GamepadLayoutIssue] = []
        if requestedControls.isEmpty {
            issues.append(
                GamepadLayoutIssue(
                    severity: .error,
                    code: "no-visible-controls",
                    message: "The keypad has no visible controls.",
                    controls: [],
                    metric: nil
                )
            )
        }

        if validatesFreeformLayout {
            issues.append(contentsOf: overlapIssues(
                controls: requestedControls,
                phase: "requested",
                codePrefix: "requested-overlap"
            ))
            issues.append(contentsOf: overlapIssues(
                controls: resolvedControls,
                phase: "resolved",
                codePrefix: "resolved-overlap"
            ).map { issue in
                var copy = issue
                copy.severity = .error
                return copy
            })
            issues.append(contentsOf: displacementIssues(controlSummaries, canvasSize: canvasSize))
            issues.append(contentsOf: sizeIssues(controlSummaries, canvasSize: canvasSize))
            issues.append(contentsOf: edgeIssues(controlSummaries, canvasSize: canvasSize))
            issues.append(contentsOf: utilizationIssues(controlSummaries, canvasSize: canvasSize))
        }

        let usedFrame = usedLayoutFrame(controlSummaries)
        let summary = GamepadLayoutQualitySummary(
            controlCount: controlSummaries.count,
            errorCount: issues.filter { $0.severity == .error }.count,
            warningCount: issues.filter { $0.severity == .warning }.count,
            largestDisplacement: controlSummaries.map(\.displacement).max() ?? 0,
            largestWidthRatio: controlSummaries.map(\.widthRatio).max() ?? 0,
            largestHeightRatio: controlSummaries.map(\.heightRatio).max() ?? 0,
            layoutWidthCoverage: Double(usedFrame.width / max(canvasSize.width, 1)),
            layoutHeightCoverage: Double(usedFrame.height / max(canvasSize.height, 1)),
            bottomUnusedRatio: Double(max(0, canvasSize.height - usedFrame.maxY) / max(canvasSize.height, 1))
        )

        return GamepadLayoutQualityReport(
            profileName: profileName,
            canvas: GamepadLayoutCanvasSummary(canvasSize),
            controls: controlSummaries,
            issues: issues,
            summary: summary
        )
    }

    static func overlapIssues(
        controls: [GamepadResolvedControl],
        phase: String,
        codePrefix: String
    ) -> [GamepadLayoutIssue] {
        var issues: [GamepadLayoutIssue] = []
        for leftIndex in controls.indices {
            for rightIndex in controls.indices where rightIndex > leftIndex {
                let left = controls[leftIndex]
                let right = controls[rightIndex]
                let intersection = left.frame.intersection(right.frame)
                guard !intersection.isNull, intersection.width > 0.5, intersection.height > 0.5 else { continue }
                let minArea = max(1, min(left.frame.width * left.frame.height, right.frame.width * right.frame.height))
                let ratio = (intersection.width * intersection.height) / minArea
                guard ratio > 0.015 else { continue }

                let severity: GamepadLayoutIssueSeverity = ratio >= 0.08 ? .error : .warning
                let percent = Int((ratio * 100).rounded())
                issues.append(
                    GamepadLayoutIssue(
                        severity: severity,
                        code: codePrefix,
                        message: "\(phase.capitalized) frames for \(left.label) and \(right.label) overlap by about \(percent)% of the smaller control.",
                        controls: [left.id.id, right.id.id],
                        metric: Double(ratio)
                    )
                )
            }
        }
        return issues
    }

    static func displacementIssues(
        _ controls: [GamepadLayoutControlSummary],
        canvasSize: CGSize
    ) -> [GamepadLayoutIssue] {
        let shortestSide = min(canvasSize.width, canvasSize.height)
        let warningThreshold = max(12, shortestSide * 0.035)
        let errorThreshold = max(28, shortestSide * 0.075)

        return controls.compactMap { control in
            guard control.displacement > Double(warningThreshold) else { return nil }
            let severity: GamepadLayoutIssueSeverity = control.displacement > Double(errorThreshold) ? .error : .warning
            return GamepadLayoutIssue(
                severity: severity,
                code: "layout-displacement",
                message: "\(control.label) had to be moved \(Int(control.displacement.rounded()))pt from its requested position to fit the layout.",
                controls: [control.id],
                metric: control.displacement
            )
        }
    }

    static func sizeIssues(
        _ controls: [GamepadLayoutControlSummary],
        canvasSize: CGSize
    ) -> [GamepadLayoutIssue] {
        controls.compactMap { control in
            let minDimension = min(control.resolvedFrame.width, control.resolvedFrame.height)
            if minDimension < 44 {
                return GamepadLayoutIssue(
                    severity: .warning,
                    code: "small-control",
                    message: "\(control.label) renders at only \(Int(minDimension.rounded()))pt on its shortest side; aim for at least 44pt visual size.",
                    controls: [control.id],
                    metric: minDimension
                )
            }

            let isJoystick = control.kind == "joystick"
            let heightWarning = isJoystick ? 0.34 : 0.24
            let heightError = isJoystick ? 0.42 : 0.30
            let widthWarning = isJoystick ? 0.28 : 0.34
            let widthError = isJoystick ? 0.36 : 0.48

            if control.heightRatio > heightError || control.widthRatio > widthError {
                return GamepadLayoutIssue(
                    severity: .error,
                    code: "oversized-control",
                    message: "\(control.label) is oversized for the canvas (\(Int((control.widthRatio * 100).rounded()))% wide, \(Int((control.heightRatio * 100).rounded()))% tall).",
                    controls: [control.id],
                    metric: max(control.widthRatio, control.heightRatio)
                )
            }

            if control.heightRatio > heightWarning || control.widthRatio > widthWarning {
                return GamepadLayoutIssue(
                    severity: .warning,
                    code: "large-control",
                    message: "\(control.label) is very large for the canvas (\(Int((control.widthRatio * 100).rounded()))% wide, \(Int((control.heightRatio * 100).rounded()))% tall).",
                    controls: [control.id],
                    metric: max(control.widthRatio, control.heightRatio)
                )
            }

            return nil
        }
    }

    static func edgeIssues(
        _ controls: [GamepadLayoutControlSummary],
        canvasSize: CGSize
    ) -> [GamepadLayoutIssue] {
        let margin = max(2, min(canvasSize.width, canvasSize.height) * 0.006)
        return controls.compactMap { control in
            let frame = resolvedCGRect(for: control)
            guard frame.minX < margin
                || frame.minY < margin
                || frame.maxX > Double(canvasSize.width - margin)
                || frame.maxY > Double(canvasSize.height - margin)
            else { return nil }

            return GamepadLayoutIssue(
                severity: .warning,
                code: "edge-hugging-control",
                message: "\(control.label) is tight against the device edge; leave a little margin for touch comfort.",
                controls: [control.id],
                metric: nil
            )
        }
    }

    static func utilizationIssues(
        _ controls: [GamepadLayoutControlSummary],
        canvasSize: CGSize
    ) -> [GamepadLayoutIssue] {
        guard controls.count >= 8 else { return [] }
        let usedFrame = usedLayoutFrame(controls)
        guard usedFrame.width > 1, usedFrame.height > 1 else { return [] }

        let widthCoverage = usedFrame.width / max(canvasSize.width, 1)
        let heightCoverage = usedFrame.height / max(canvasSize.height, 1)
        let bottomUnusedRatio = max(0, canvasSize.height - usedFrame.maxY) / max(canvasSize.height, 1)

        var issues: [GamepadLayoutIssue] = []
        if bottomUnusedRatio > 0.18 {
            let percent = Int((bottomUnusedRatio * 100).rounded())
            issues.append(
                GamepadLayoutIssue(
                    severity: .warning,
                    code: "underused-bottom-space",
                    message: "The bottom \(percent)% of the keypad has no visible controls; move primary actions or utility buttons lower to use the full touch area.",
                    controls: controls.map(\.id),
                    metric: Double(bottomUnusedRatio)
                )
            )
        }

        if heightCoverage < 0.70 {
            let percent = Int((heightCoverage * 100).rounded())
            issues.append(
                GamepadLayoutIssue(
                    severity: .warning,
                    code: "low-vertical-coverage",
                    message: "Controls occupy only \(percent)% of the keypad height; distribute controls from top to bottom for a more efficient two-thumb layout.",
                    controls: controls.map(\.id),
                    metric: Double(heightCoverage)
                )
            )
        }

        if widthCoverage < 0.55 {
            let percent = Int((widthCoverage * 100).rounded())
            issues.append(
                GamepadLayoutIssue(
                    severity: .warning,
                    code: "low-horizontal-coverage",
                    message: "Controls occupy only \(percent)% of the keypad width; spread movement and action clusters toward both sides of the screen.",
                    controls: controls.map(\.id),
                    metric: Double(widthCoverage)
                )
            )
        }

        return issues
    }

    static func usedLayoutFrame(_ controls: [GamepadLayoutControlSummary]) -> CGRect {
        guard let first = controls.first else { return .zero }
        let firstFrame = resolvedCGRect(for: first)
        return controls.dropFirst().map(resolvedCGRect(for:)).reduce(firstFrame) { partialResult, frame in
            partialResult.union(frame)
        }
    }

    static func resolvedCGRect(for control: GamepadLayoutControlSummary) -> CGRect {
        CGRect(
            x: CGFloat(control.resolvedFrame.x),
            y: CGFloat(control.resolvedFrame.y),
            width: CGFloat(control.resolvedFrame.width),
            height: CGFloat(control.resolvedFrame.height)
        )
    }
}

#if os(macOS)
enum GamepadLayoutPreviewRenderer {
    static func writePNG(
        customization: GamepadCustomization,
        profileName: String? = nil,
        canvasSize: CGSize? = nil,
        outputURL: URL,
        scale: CGFloat = 2,
        annotateIssues: Bool = true
    ) throws {
        let canvasSize = canvasSize ?? customization.deviceCanvas.editorDeviceFrame.screenRect.size
        let safeScale = max(1, min(scale, 4))
        let pixelWidth = max(1, Int((canvasSize.width * safeScale).rounded()))
        let pixelHeight = max(1, Int((canvasSize.height * safeScale).rounded()))

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: representation)?.cgContext else {
            throw CocoaError(.fileWriteUnknown)
        }

        representation.size = canvasSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }

        context.scaleBy(x: safeScale, y: safeScale)
        context.translateBy(x: 0, y: canvasSize.height)
        context.scaleBy(x: 1, y: -1)

        let report = customization.layoutQualityReport(profileName: profileName, canvasSize: canvasSize)
        let requestedByID = Dictionary(uniqueKeysWithValues: GamepadLayoutResolver.preferredControls(for: customization, in: canvasSize).map { ($0.id.id, $0) })
        let problemIDs = Set(report.issues.flatMap(\.controls))

        drawBackground(in: context, customization: customization, canvasSize: canvasSize)
        drawGrid(in: context, canvasSize: canvasSize)

        if annotateIssues {
            for control in report.controls where control.displacement > 1 {
                guard let requested = requestedByID[control.id] else { continue }
                drawFrameOutline(requested.frame, in: context, color: NSColor.systemOrange.withAlphaComponent(0.74), dashed: true, lineWidth: 1.5)
            }
        }

        for control in customization.resolvedControls(in: canvasSize) {
            draw(control: control, customization: customization, problemIDs: problemIDs, in: context, annotateIssues: annotateIssues)
        }

        drawBorder(in: context, canvasSize: canvasSize, report: report)

        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try pngData.write(to: outputURL, options: .atomic)
    }

    private static func drawBackground(in context: CGContext, customization: GamepadCustomization, canvasSize: CGSize) {
        let color = customization.keypadBackgroundFillStyle(scheme: .dark).representativeColor
        context.setFillColor(cgColor(color))
        context.fill(CGRect(origin: .zero, size: canvasSize))
    }

    private static func drawGrid(in context: CGContext, canvasSize: CGSize) {
        context.saveGState()
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: canvasSize.width / 2, y: 0))
        context.addLine(to: CGPoint(x: canvasSize.width / 2, y: canvasSize.height))
        context.move(to: CGPoint(x: 0, y: canvasSize.height / 2))
        context.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height / 2))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawBorder(in context: CGContext, canvasSize: CGSize, report: GamepadLayoutQualityReport) {
        context.saveGState()
        let color: NSColor = report.hasErrors ? .systemRed : (report.hasWarnings ? .systemOrange : .systemGreen)
        context.setStrokeColor(color.withAlphaComponent(0.60).cgColor)
        context.setLineWidth(2)
        context.stroke(CGRect(origin: .zero, size: canvasSize).insetBy(dx: 1, dy: 1))
        context.restoreGState()
    }

    private static func draw(
        control: GamepadResolvedControl,
        customization: GamepadCustomization,
        problemIDs: Set<String>,
        in context: CGContext,
        annotateIssues: Bool
    ) {
        let layout = control.layoutCustomization
        let accent = layout.accentStyle ?? customization.accentStyle
        let fill = layout.buttonFillStyle(accentStyle: accent, isPressed: false, scheme: .dark).representativeColor
        let stroke = GamepadRGBAColor(color: layout.buttonStroke(accentStyle: accent, isPressed: false, scheme: .dark), fallback: .defaultValue)
        let foreground = GamepadRGBAColor(color: layout.buttonForeground(accentStyle: accent, isPressed: false, scheme: .dark), fallback: GamepadRGBAColor(red: 1, green: 1, blue: 1, alpha: 1))

        context.saveGState()
        context.setFillColor(cgColor(fill))
        context.setStrokeColor(cgColor(stroke))
        context.setLineWidth(1)

        addPath(for: control, in: context)
        context.drawPath(using: .fillStroke)

        if control.isJoystick {
            drawJoystickDetails(control: control, foreground: foreground, in: context)
        }

        if annotateIssues, problemIDs.contains(control.id.id) {
            drawFrameOutline(control.frame.insetBy(dx: -2, dy: -2), in: context, color: .systemRed, dashed: false, lineWidth: 2)
        }

        if customization.showsButtonLabels {
            drawLabel(control.label, in: control.frame, foreground: foreground, context: context, isJoystick: control.isJoystick)
        }

        context.restoreGState()
    }

    private static func drawJoystickDetails(control: GamepadResolvedControl, foreground: GamepadRGBAColor, in context: CGContext) {
        let side = min(control.frame.width, control.frame.height)
        let center = control.center
        let ringRect = CGRect(x: center.x - side * 0.35, y: center.y - side * 0.35, width: side * 0.70, height: side * 0.70)
        let knobRect = CGRect(x: center.x - side * 0.18, y: center.y - side * 0.18, width: side * 0.36, height: side * 0.36)
        context.saveGState()
        context.setStrokeColor(cgColor(foreground, alphaMultiplier: 0.38))
        context.setLineWidth(1)
        context.strokeEllipse(in: ringRect)
        context.setFillColor(cgColor(foreground, alphaMultiplier: 0.20))
        context.fillEllipse(in: knobRect)
        context.setStrokeColor(cgColor(foreground, alphaMultiplier: 0.34))
        context.strokeEllipse(in: knobRect)
        context.restoreGState()
    }

    private static func drawLabel(_ label: String, in frame: CGRect, foreground: GamepadRGBAColor, context: CGContext, isJoystick: Bool) {
        let maxFontSize = isJoystick ? CGFloat(14) : CGFloat(label.count <= 2 ? 28 : 16)
        let availableWidth = max(1, frame.width - 8)
        let availableHeight = max(1, frame.height - 6)
        var fontSize = max(8, min(maxFontSize, frame.height * 0.36))
        var attributed = NSAttributedString(
            string: label,
            attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: nsColor(foreground)
            ]
        )
        while fontSize > 7.5 {
            let measured = attributed.size()
            if measured.width <= availableWidth && measured.height <= availableHeight { break }
            fontSize -= 0.5
            attributed = NSAttributedString(
                string: label,
                attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: nsColor(foreground)
                ]
            )
        }
        let textSize = attributed.size()
        let textRect = CGRect(
            x: -min(textSize.width, availableWidth) / 2,
            y: -min(textSize.height, availableHeight) / 2,
            width: min(textSize.width, availableWidth),
            height: min(textSize.height, availableHeight)
        )

        context.saveGState()
        context.translateBy(x: frame.midX, y: frame.midY + (isJoystick ? frame.height * 0.28 : 0))
        context.scaleBy(x: 1, y: -1)
        attributed.draw(in: textRect)
        context.restoreGState()
    }

    private static func drawFrameOutline(_ frame: CGRect, in context: CGContext, color: NSColor, dashed: Bool, lineWidth: CGFloat) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        if dashed { context.setLineDash(phase: 0, lengths: [5, 4]) }
        context.stroke(frame)
        context.restoreGState()
    }

    private static func addPath(for control: GamepadResolvedControl, in context: CGContext) {
        let frame = control.frame
        switch control.shape {
        case .circle, .ellipse:
            context.addEllipse(in: frame)
        case .capsule:
            context.addPath(CGPath(roundedRect: frame, cornerWidth: min(frame.width, frame.height) / 2, cornerHeight: min(frame.width, frame.height) / 2, transform: nil))
        case .roundedRectangle:
            let radius = control.layoutCustomization.resolvedCornerRadii(defaultRadius: 12).averageRadius
            context.addPath(CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil))
        case .rectangle:
            context.addRect(frame)
        case .polygon:
            context.addPath(polygonPath(in: frame, sides: 6))
        case .star:
            context.addPath(starPath(in: frame))
        }
    }

    private static func polygonPath(in frame: CGRect, sides: Int) -> CGPath {
        let path = CGMutablePath()
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let radius = min(frame.width, frame.height) / 2
        for index in 0..<max(3, sides) {
            let angle = (-CGFloat.pi / 2) + CGFloat(index) * (2 * CGFloat.pi / CGFloat(max(3, sides)))
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private static func starPath(in frame: CGRect) -> CGPath {
        let path = CGMutablePath()
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let outer = min(frame.width, frame.height) / 2
        let inner = outer * 0.48
        for index in 0..<10 {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = (-CGFloat.pi / 2) + CGFloat(index) * (CGFloat.pi / 5)
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    private static func cgColor(_ color: GamepadRGBAColor, alphaMultiplier: CGFloat = 1) -> CGColor {
        let normalized = color.normalized
        return CGColor(
            red: normalized.red,
            green: normalized.green,
            blue: normalized.blue,
            alpha: min(max(normalized.alpha * alphaMultiplier, 0), 1)
        )
    }

    private static func nsColor(_ color: GamepadRGBAColor) -> NSColor {
        let normalized = color.normalized
        return NSColor(
            calibratedRed: normalized.red,
            green: normalized.green,
            blue: normalized.blue,
            alpha: normalized.alpha
        )
    }
}
#endif
