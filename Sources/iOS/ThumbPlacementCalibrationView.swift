import SwiftUI
import UIKit

@MainActor
final class ThumbPlacementCalibrationRuntime: ObservableObject {
    enum Phase: Equatable {
        case idle
        case capturing(ThumbPlacementHand)
        case suggestions
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var calibration: ThumbPlacementCalibration?
    @Published private(set) var draftSamples: [ThumbPlacementNormalizedPoint] = []
    @Published private(set) var report = ThumbPlacementScoreReport(overallScore: 100, controls: [], suggestions: [])
    @Published private(set) var requiredHands: [ThumbPlacementHand] = []

    private var controls: [ThumbPlacementControlGeometry] = []
    private var canvasSize: CGSize = .zero
    private var safeArea: CGRect = .zero

    var isActive: Bool { phase != .idle }

    var activeHand: ThumbPlacementHand? {
        guard case .capturing(let hand) = phase else { return nil }
        return hand
    }

    var visibleZones: [ThumbPlacementReachZone] {
        var zones = calibration?.zones ?? []
        if let activeHand,
           let draftZone = ThumbPlacementReachZone(hand: activeHand, samples: draftSamples) {
            zones.removeAll { $0.hand == activeHand }
            zones.append(draftZone)
        }
        return zones
    }

    func begin(
        profileID: UUID,
        customization: GamepadCustomization,
        orientation: GamepadEditorDeviceOrientation,
        canvasSize: CGSize,
        safeAreaInsets: EdgeInsets
    ) {
        let key = ThumbPlacementCalibrationKey(
            profileID: profileID,
            deviceIdentity: Self.deviceIdentity,
            displayIdentity: Self.displayIdentity,
            orientation: orientation
        )
        let hands: [ThumbPlacementHand] = switch customization.layoutReachMode {
        case .twoHanded: [.left, .right]
        case .oneHandedLeft: [.left]
        case .oneHandedRight: [.right]
        }
        self.canvasSize = canvasSize
        self.safeArea = CGRect(
            x: safeAreaInsets.leading,
            y: safeAreaInsets.top,
            width: max(1, canvasSize.width - safeAreaInsets.leading - safeAreaInsets.trailing),
            height: max(1, canvasSize.height - safeAreaInsets.top - safeAreaInsets.bottom)
        )
        self.controls = Self.controlGeometries(customization: customization, canvasSize: canvasSize)
        requiredHands = hands
        calibration = ThumbPlacementCalibrationStore().load(for: key) ?? ThumbPlacementCalibration(key: key)
        draftSamples = []
        phase = .capturing(hands[0])
        announce("Thumb placement calibration. Trace your comfortable \(hands[0].displayName.lowercased()) thumb reach, then lift.")
    }

    func updateDraft(location: CGPoint) {
        guard activeHand != nil else { return }
        let point = ThumbPlacementNormalizedPoint(location, in: canvasSize)
        if let last = draftSamples.last,
           hypot(last.x - point.x, last.y - point.y) < 0.008 {
            return
        }
        draftSamples.append(point)
    }

    func finishDraft(at location: CGPoint) {
        guard let activeHand, var calibration else { return }
        updateDraft(location: location)
        if draftSamples.count == 1, let point = draftSamples.first {
            draftSamples = Self.defaultReachSamples(around: point)
        }
        guard !draftSamples.isEmpty else { return }
        calibration.setSamples(draftSamples, for: activeHand)
        self.calibration = calibration
        draftSamples = []

        if let index = requiredHands.firstIndex(of: activeHand), index + 1 < requiredHands.count {
            let next = requiredHands[index + 1]
            phase = .capturing(next)
            announce("\(activeHand.displayName) thumb captured. Now trace your \(next.displayName.lowercased()) thumb reach.")
        } else {
            ThumbPlacementCalibrationStore().save(calibration)
            report = ThumbPlacementScorer.score(
                controls: controls,
                zones: calibration.zones,
                canvasSize: canvasSize,
                safeArea: safeArea
            )
            phase = .suggestions
            announce("Calibration complete. Layout score \(report.overallScore) out of 100. Review suggestions or tap Done.")
        }
    }

    func useAccessibleDefaultForActiveHand() {
        guard let hand = activeHand else { return }
        let point = CGPoint(
            x: canvasSize.width * (hand == .left ? 0.24 : 0.76),
            y: canvasSize.height * 0.74
        )
        draftSamples = Self.defaultReachSamples(around: ThumbPlacementNormalizedPoint(point, in: canvasSize))
        finishDraft(at: point)
    }

    func cancel() {
        guard isActive else { return }
        phase = .idle
        calibration = nil
        draftSamples = []
        controls = []
        announce("Thumb placement calibration canceled. The keypad layout was not changed.")
    }

    func complete() {
        phase = .idle
        calibration = nil
        draftSamples = []
        controls = []
    }

    func customization(
        byApplying suggestion: ThumbPlacementSuggestionKind,
        to source: GamepadCustomization
    ) -> GamepadCustomization? {
        guard let calibration else { return nil }
        var next = source
        switch suggestion {
        case .minimumTouchTarget:
            _ = next.applyLayoutRepair(.minimumTouchTarget, canvasSize: canvasSize)
        case .separateRuntimeHitTargets:
            _ = next.applyLayoutRepair(.separateExpandedHitTargets, canvasSize: canvasSize)
        case .moveInsideSafeArea:
            Self.moveControlsInsideSafeArea(&next, canvasSize: canvasSize, safeArea: safeArea)
        case .moveIntoReach:
            Self.moveControlsIntoReach(
                &next,
                zones: calibration.zones,
                canvasSize: canvasSize,
                outOfReachIDs: Set(report.controls.filter { !$0.isReachable }.map(\.controlID))
            )
        }
        next = next.normalized
        return next.hasSamePresentation(as: source) ? nil : next
    }

    private static var deviceIdentity: String {
        UIDevice.current.identifierForVendor?.uuidString ?? UIDevice.current.model
    }

    private static var displayIdentity: String {
        let screen = UIScreen.main
        return "\(Int(screen.nativeBounds.width))x\(Int(screen.nativeBounds.height))@\(screen.nativeScale)"
    }

    private static func controlGeometries(
        customization: GamepadCustomization,
        canvasSize: CGSize
    ) -> [ThumbPlacementControlGeometry] {
        customization.resolvedControls(in: canvasSize)
            .filter { !$0.isDecoration }
            .map {
                ThumbPlacementControlGeometry(
                    id: $0.id.id,
                    label: $0.label,
                    visualFrame: $0.frame,
                    runtimeHitFrame: GamepadLayoutQualityReport.runtimeHitFrame(for: $0)
                )
            }
    }

    private static func defaultReachSamples(
        around center: ThumbPlacementNormalizedPoint
    ) -> [ThumbPlacementNormalizedPoint] {
        let radiusX: CGFloat = 0.16
        let radiusY: CGFloat = 0.20
        return stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 8).map { angle in
            ThumbPlacementNormalizedPoint(
                x: center.x + cos(angle) * radiusX,
                y: center.y + sin(angle) * radiusY
            )
        }
    }

    private static func moveControlsIntoReach(
        _ customization: inout GamepadCustomization,
        zones: [ThumbPlacementReachZone],
        canvasSize: CGSize,
        outOfReachIDs: Set<String>
    ) {
        guard !zones.isEmpty, !outOfReachIDs.isEmpty else { return }
        let controls = customization.resolvedControls(in: canvasSize)
            .filter { outOfReachIDs.contains($0.id.id) && !$0.isDecoration && !$0.isLocationLocked }
            .sorted { $0.id.id < $1.id.id }
        var counts: [ThumbPlacementHand: Int] = [:]

        for control in controls {
            let normalizedCenter = CGPoint(
                x: control.center.x / max(canvasSize.width, 1),
                y: control.center.y / max(canvasSize.height, 1)
            )
            let zone = preferredZone(for: control, currentCenter: normalizedCenter, zones: zones)
            let index = counts[zone.hand, default: 0]
            counts[zone.hand] = index + 1
            let columns = [-0.48, 0, 0.48]
            let column = columns[index % columns.count]
            let row = CGFloat(index / columns.count)
            let target = CGPoint(
                x: (zone.center.x + CGFloat(column) * zone.radiusX).clamped(to: 0...1),
                y: (zone.center.y + (0.30 - row * 0.42) * zone.radiusY).clamped(to: 0...1)
            )
            let normalized = GamepadLayoutResolver.normalizedPosition(
                for: CGPoint(x: target.x * canvasSize.width, y: target.y * canvasSize.height),
                visualSize: control.size,
                in: canvasSize
            )
            customization.setPosition(normalized, for: control.id)
        }
        _ = customization.separateExpandedHitTargets(in: canvasSize, respectingLocks: true)
    }

    private static func preferredZone(
        for control: GamepadResolvedControl,
        currentCenter: CGPoint,
        zones: [ThumbPlacementReachZone]
    ) -> ThumbPlacementReachZone {
        if zones.count == 1 { return zones[0] }
        let role = GamepadLayoutErgonomicRole.role(for: control)
        if role == .movement, let left = zones.first(where: { $0.hand == .left }) { return left }
        if role == .action, let right = zones.first(where: { $0.hand == .right }) { return right }
        return zones.min { $0.normalizedDistance(to: currentCenter) < $1.normalizedDistance(to: currentCenter) } ?? zones[0]
    }

    private static func moveControlsInsideSafeArea(
        _ customization: inout GamepadCustomization,
        canvasSize: CGSize,
        safeArea: CGRect
    ) {
        for control in customization.resolvedControls(in: canvasSize) where !control.isDecoration && !control.isLocationLocked {
            guard !safeArea.contains(control.frame) else { continue }
            let halfWidth = control.size.width / 2
            let halfHeight = control.size.height / 2
            let center = CGPoint(
                x: min(max(control.center.x, safeArea.minX + halfWidth), safeArea.maxX - halfWidth),
                y: min(max(control.center.y, safeArea.minY + halfHeight), safeArea.maxY - halfHeight)
            )
            customization.setPosition(
                CGPoint(x: center.x / max(canvasSize.width, 1), y: center.y / max(canvasSize.height, 1)),
                for: control.id
            )
        }
    }

    private func announce(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

struct ThumbPlacementCalibrationOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @ObservedObject var runtime: ThumbPlacementCalibrationRuntime
    let canvasSize: CGSize
    let safeAreaInsets: EdgeInsets
    let onAcceptSuggestion: (ThumbPlacementSuggestionKind) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.20)
                .contentShape(Rectangle())

            ForEach(runtime.visibleZones) { zone in
                reachEllipse(zone)
            }

            if case .capturing = runtime.phase {
                captureSurface
                captureInstructions
            } else if runtime.phase == .suggestions {
                suggestionsPanel
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.995)))
        .zIndex(50)
        .accessibilityElement(children: .contain)
    }

    private func reachEllipse(_ zone: ThumbPlacementReachZone) -> some View {
        let frame = zone.frame(in: canvasSize)
        let color = zone.hand == .left ? Color.cyan : Color.purple
        return Ellipse()
            .fill(color.opacity(0.14))
            .overlay(
                Ellipse().stroke(
                    color,
                    style: StrokeStyle(lineWidth: differentiateWithoutColor ? 4 : 3, dash: zone.hand == .left ? [] : [8, 5])
                )
            )
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var captureSurface: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { runtime.updateDraft(location: $0.location) }
                    .onEnded { runtime.finishDraft(at: $0.location) }
            )
            .accessibilityLabel("Thumb reach capture area")
            .accessibilityHint("Double tap to use an accessible comfortable reach estimate for the active hand.")
            .accessibilityAction { runtime.useAccessibleDefaultForActiveHand() }
    }

    private var captureInstructions: some View {
        VStack(spacing: Geist.Spacing.s2) {
            if let hand = runtime.activeHand {
                Label("Calibrate \(hand.displayName) Thumb", systemImage: hand == .left ? "hand.point.left.fill" : "hand.point.right.fill")
                    .geistTypography(.heading16)
                Text("Hold the phone normally. Trace the comfortable area this thumb can reach, then lift.")
                    .geistTypography(.copy13)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Cancel") { runtime.cancel() }
                    .geistButtonStyle(.secondary, size: .small)
                if UIAccessibility.isVoiceOverRunning {
                    Button("Use Comfortable Estimate") { runtime.useAccessibleDefaultForActiveHand() }
                        .geistButtonStyle(.primary, size: .small)
                }
            }
        }
        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Geist.Radius.md).stroke(Geist.color(.grayAlpha500, scheme: colorScheme)))
        .padding(.horizontal, max(Geist.Spacing.s4, safeAreaInsets.leading + Geist.Spacing.s2))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, max(Geist.Spacing.s4, safeAreaInsets.top + Geist.Spacing.s2))
    }

    private var suggestionsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thumb Placement Score")
                            .geistTypography(.heading20)
                        Text("\(runtime.report.overallScore) / 100")
                            .geistTypography(.heading32)
                    }
                    Spacer()
                    Image(systemName: runtime.report.overallScore >= 85 ? "checkmark.circle.fill" : "hand.raised.fill")
                        .font(.system(size: 32, weight: .semibold))
                }

                Text("Suggestions use calibrated reach, safe areas, 44 pt visual targets, and actual runtime hit-region overlap.")
                    .geistTypography(.copy13)
                    .fixedSize(horizontal: false, vertical: true)

                if runtime.report.suggestions.isEmpty {
                    Label("No layout changes suggested", systemImage: "checkmark.seal.fill")
                        .geistTypography(.heading14)
                } else {
                    ForEach(runtime.report.suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                            Text(suggestion.title).geistTypography(.heading14)
                            Text(suggestion.detail)
                                .geistTypography(.copy13)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Apply Suggestion") { onAcceptSuggestion(suggestion) }
                                .geistButtonStyle(.primary, size: .small)
                                .accessibilityLabel("Apply: \(suggestion.title)")
                        }
                        .padding(Geist.Spacing.s3)
                        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm))
                    }
                }

                HStack {
                    Button("Cancel") { runtime.cancel() }
                        .geistButtonStyle(.secondary, size: .small)
                        .accessibilityHint("Closes calibration without changing the keypad layout. The reach calibration remains saved.")
                    Spacer()
                    Button("Done") { runtime.complete() }
                        .geistButtonStyle(.primary, size: .small)
                }
            }
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .padding(Geist.Spacing.s6)
        }
        .frame(
            maxWidth: 520,
            maxHeight: min(
                560,
                canvasSize.height - safeAreaInsets.top - safeAreaInsets.bottom - Geist.Spacing.s4 * 2
            )
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Geist.Radius.md).stroke(Geist.color(.grayAlpha500, scheme: colorScheme)))
        .padding(.top, max(Geist.Spacing.s4, safeAreaInsets.top + Geist.Spacing.s2))
        .padding(.bottom, max(Geist.Spacing.s4, safeAreaInsets.bottom + Geist.Spacing.s2))
        .padding(.horizontal, max(Geist.Spacing.s4, safeAreaInsets.leading + Geist.Spacing.s2))
    }
}
