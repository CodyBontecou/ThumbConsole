import SwiftUI
import UIKit

struct IOSContentView: View {
    @EnvironmentObject private var client: ControllerClient
    @AppStorage("macHost") private var macHost = "192.168.0.113"
    @AppStorage("macPort") private var macPort = "8765"
    @AppStorage("pairingCode") private var pairingCode = ""

    private let defaultMacHost = "192.168.0.113"
    private let defaultMacPort = "8765"

    var body: some View {
        ZStack {
            if client.isConnected {
                ControllerPadView()
            } else {
                ConnectionView(macHost: $macHost, macPort: $macPort, pairingCode: $pairingCode)
            }
        }
        .geistScreenBackground()
        .statusBarHidden(client.isConnected)
        .persistentSystemOverlays(client.isConnected ? .hidden : .automatic)
        .onAppear {
            if macHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                macHost = defaultMacHost
            }
            if macPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                macPort = defaultMacPort
            }
            // Pairing is optional in the Mac helper. Keep this blank for faster local testing
            // and to avoid stale saved pairing codes causing immediate disconnects.
            pairingCode = ""
        }
    }
}

private enum GeistInterfaceTone {
    case neutral
    case success
    case warning
    case error
    case accent

    func foreground(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.gray900, scheme: scheme)
        case .success: Geist.color(.blue900, scheme: scheme)
        case .warning: Geist.color(.amber900, scheme: scheme)
        case .error: Geist.color(.red900, scheme: scheme)
        case .accent: Geist.color(.blue900, scheme: scheme)
        }
    }

    func background(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.gray100, scheme: scheme)
        case .success: Geist.color(.blue100, scheme: scheme)
        case .warning: Geist.color(.amber100, scheme: scheme)
        case .error: Geist.color(.red100, scheme: scheme)
        case .accent: Geist.color(.blue100, scheme: scheme)
        }
    }

    func border(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.grayAlpha400, scheme: scheme)
        case .success: Geist.color(.blue400, scheme: scheme)
        case .warning: Geist.color(.amber400, scheme: scheme)
        case .error: Geist.color(.red400, scheme: scheme)
        case .accent: Geist.color(.blue400, scheme: scheme)
        }
    }
}

private struct ConnectionView: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @Binding var macHost: String
    @Binding var macPort: String
    @Binding var pairingCode: String

    @State private var isShowingScanner = false
    @State private var isShowingCustomization = false
    @State private var qrScanError: String?
    @State private var pendingPairingCode = ""

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height && proxy.size.width >= 760

            ScrollView(.vertical) {
                Group {
                    if isWide {
                        HStack(alignment: .center, spacing: Geist.Spacing.s8) {
                            header
                                .frame(maxWidth: 380, alignment: .leading)
                            activePairingContent
                                .frame(maxWidth: 460)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: Geist.Spacing.s8) {
                            header
                            activePairingContent
                        }
                        .frame(maxWidth: 540)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, isWide ? Geist.Spacing.s10 : Geist.Spacing.s6)
                .padding(.vertical, isWide ? Geist.Spacing.s6 : Geist.Spacing.s8)
                .frame(minHeight: proxy.size.height, alignment: isWide ? .center : .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: client.state) { _, newState in
            if newState == .pairingCodeRequired {
                pendingPairingCode = ""
            }
        }
        .sheet(isPresented: $isShowingScanner) {
            NavigationStack {
                QRCodeScannerView { scannedText in
                    handleScannedPairingCode(scannedText)
                }
                .ignoresSafeArea()
                .navigationTitle("Scan Mac QR Code")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close Scanner") {
                            isShowingScanner = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingCustomization) {
            GamepadCustomizationSheet()
        }
    }

    @ViewBuilder
    private var activePairingContent: some View {
        if client.isAwaitingPairingCode {
            pairingCodePrompt
        } else {
            form
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            Text("PocketPad")
                .geistTypography(.heading40)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .minimumScaleFactor(0.75)

            Text("Use this iPhone as a programmable shortcut keypad for your Mac.")
                .geistTypography(.copy16)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            StatusPill(title: client.state.label, systemImage: statusSystemImage, tone: statusTone)

            if let error = client.lastError {
                MessageBanner(text: error, tone: .warning)
            }
            if let qrScanError {
                MessageBanner(text: qrScanError, tone: .warning)
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Pair With Mac")
                    .geistTypography(.heading20)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("Scan the Mac helper QR code or request a secure six-digit pairing code.")
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }

            Button {
                qrScanError = nil
                isShowingScanner = true
            } label: {
                Label("Scan Mac QR Code", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.primary, size: .large)

            DividerLabel("Manual Connection")

            LabeledInput(title: "Mac Host") {
                TextField("Mac IP, e.g. 192.168.1.24", text: $macHost)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .geistInput()
            }

            LabeledInput(title: "Port") {
                TextField("8765", text: $macPort)
                    .keyboardType(.numberPad)
                    .geistInput()
            }

            Button {
                pairingCode = ""
                client.connect(hostField: macHost, port: macPort, pairingCode: "")
            } label: {
                Text(client.state == .connecting ? "Requesting…" : "Request Pairing")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.primary, size: .medium)
            .disabled(macHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            DividerLabel("Keypad")

            Button {
                isShowingCustomization = true
            } label: {
                Label("Customize iPhone Keypad", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.secondary, size: .medium)
        }
        .geistPanel(padding: Geist.Spacing.s6, radius: Geist.Radius.sm)
    }

    private var pairingCodePrompt: some View {
        VStack(alignment: .center, spacing: Geist.Spacing.s6) {
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: Geist.Spacing.s2) {
                Text("Pairing request accepted")
                    .geistTypography(.heading24)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .multilineTextAlignment(.center)

                Text("Enter the code shown on PocketPad Mac.")
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PairingCodeInput(code: $pendingPairingCode)

            VStack(spacing: Geist.Spacing.s3) {
                Button {
                    pairingCode = pendingPairingCode
                    client.submitPairingCode(pendingPairingCode)
                } label: {
                    Text("Pair")
                        .frame(maxWidth: .infinity)
                }
                .geistButtonStyle(.primary, size: .large)
                .disabled(pendingPairingCode.count < 6)

                Button("Cancel Pairing") {
                    pendingPairingCode = ""
                    client.disconnect(sendReleaseAll: false)
                }
                .geistButtonStyle(.tertiary, size: .medium)
            }
        }
        .geistPanel(padding: Geist.Spacing.s6, radius: Geist.Radius.md)
    }

    private func handleScannedPairingCode(_ text: String) {
        guard let payload = PairingPayload.decode(from: text),
              let urlString = payload.urls.first
        else {
            qrScanError = "QR code not recognized. Scan the PocketPad code shown on your Mac."
            isShowingScanner = false
            return
        }

        pairingCode = payload.pairingCode ?? ""
        applyConnectionFields(from: urlString)
        isShowingScanner = false
        client.connect(hostField: urlString, port: "", pairingCode: pairingCode)
    }

    private func applyConnectionFields(from urlString: String) {
        guard let components = URLComponents(string: urlString),
              let host = components.host
        else {
            macHost = urlString
            macPort = "8765"
            return
        }

        macHost = host
        macPort = components.port.map(String.init) ?? "8765"
    }

    private var statusTone: GeistInterfaceTone {
        switch client.state {
        case .connected: .success
        case .connecting, .pairingCodeRequired: .warning
        case .failed: .error
        case .disconnected: .neutral
        }
    }

    private var statusSystemImage: String {
        switch client.state {
        case .connected: "checkmark.circle.fill"
        case .connecting: "arrow.triangle.2.circlepath"
        case .pairingCodeRequired: "key.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .disconnected: "circle"
        }
    }
}

private struct PairingCodeInput: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var code: String
    @FocusState private var isFocused: Bool

    private let digitCount = 6

    var body: some View {
        ZStack {
            HStack(spacing: Geist.Spacing.s2) {
                ForEach(0..<digitCount, id: \.self) { index in
                    digitBox(at: index)
                }
            }

            TextField("Pairing code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityLabel("Pairing code")
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .onChange(of: code) { _, newValue in
            let filtered = String(newValue.filter(\.isNumber).prefix(digitCount))
            if filtered != newValue {
                code = filtered
            }
        }
    }

    private func digitBox(at index: Int) -> some View {
        let digits = Array(code)
        let digit = index < digits.count ? String(digits[index]) : ""
        let isActive = index == min(code.count, digitCount - 1)

        return Text(digit)
            .geistTypography(.heading24)
            .monospacedDigit()
            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            .frame(width: 44, height: 52)
            .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                    .stroke(isActive ? Geist.color(.blue700, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: isActive ? 2 : 1)
            )
    }
}

private struct StatusPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let tone: GeistInterfaceTone

    var body: some View {
        Label(title, systemImage: systemImage)
            .geistTypography(.label13)
            .foregroundStyle(tone.foreground(scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .padding(.vertical, Geist.Spacing.s2)
            .background(tone.background(scheme: colorScheme), in: Capsule())
            .overlay(Capsule().stroke(tone.border(scheme: colorScheme), lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MessageBanner: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let tone: GeistInterfaceTone

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .geistTypography(.copy13)
            .foregroundStyle(tone.foreground(scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .padding(.vertical, Geist.Spacing.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tone.background(scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(tone.border(scheme: colorScheme), lineWidth: 1)
            )
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DividerLabel: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: Geist.Spacing.s3) {
            Rectangle()
                .fill(Geist.color(.grayAlpha400, scheme: colorScheme))
                .frame(height: 1)
            Text(title)
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(Geist.color(.grayAlpha400, scheme: colorScheme))
                .frame(height: 1)
        }
        .padding(.vertical, Geist.Spacing.s1)
    }
}

private struct LabeledInput<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    var helper: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            HStack(spacing: Geist.Spacing.s2) {
                Text(title)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                if let helper {
                    Text(helper)
                        .geistTypography(.label12)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }
            }
            content
        }
    }
}

private struct GamepadCustomizationSheet: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GamepadCustomizationEditor(
                customization: Binding(
                    get: { client.gamepadCustomization },
                    set: { client.updateGamepadCustomization($0) }
                ),
                onReset: { client.resetGamepadCustomization() }
            )
            .geistScreenBackground()
            .navigationTitle("Keypad Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ControllerPadView: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingCustomization = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width >= proxy.size.height

            VStack(spacing: 0) {
                topBar
                    .padding(.leading, max(isLandscape ? Geist.Spacing.s6 : Geist.Spacing.s4, proxy.safeAreaInsets.leading + Geist.Spacing.s3))
                    .padding(.trailing, max(isLandscape ? Geist.Spacing.s6 : Geist.Spacing.s4, proxy.safeAreaInsets.trailing + Geist.Spacing.s3))
                    .padding(.top, max(isLandscape ? Geist.Spacing.s3 : Geist.Spacing.s2, proxy.safeAreaInsets.top + Geist.Spacing.s2))

                if isLandscape {
                    landscapeControllerLayout(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                } else {
                    portraitControllerLayout(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                }
            }
        }
        .sheet(isPresented: $isShowingCustomization) {
            GamepadCustomizationSheet()
        }
        .onChange(of: client.gamepadCustomization) { _, _ in
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
        }
    }

    @ViewBuilder
    private func landscapeControllerLayout(size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let customization = client.gamepadCustomization

        if customization.usesFreeformLayout {
            freeformControllerLayout(size: size, safeAreaInsets: safeAreaInsets)
        } else {
            let metrics = LandscapeControllerMetrics(
                size: size,
                safeAreaInsets: safeAreaInsets,
                controlScale: customization.controlScale
            )

            HStack(alignment: .center, spacing: metrics.controlSpacing) {
                if customization.layoutMode == .standard {
                    landscapeDPad(metrics: metrics, customization: customization)
                    Spacer(minLength: metrics.spacerMinLength)
                    landscapeUtilityButtons(metrics: metrics, customization: customization)
                    Spacer(minLength: metrics.spacerMinLength)
                    landscapeActions(metrics: metrics, customization: customization)
                } else {
                    landscapeActions(metrics: metrics, customization: customization)
                    Spacer(minLength: metrics.spacerMinLength)
                    landscapeUtilityButtons(metrics: metrics, customization: customization)
                    Spacer(minLength: metrics.spacerMinLength)
                    landscapeDPad(metrics: metrics, customization: customization)
                }
            }
            .padding(.leading, metrics.leadingPadding)
            .padding(.trailing, metrics.trailingPadding)
            .padding(.bottom, metrics.bottomPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                TouchRoutingView()
            }
        }
    }

    @ViewBuilder
    private func portraitControllerLayout(size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let customization = client.gamepadCustomization

        if customization.usesFreeformLayout {
            freeformControllerLayout(size: size, safeAreaInsets: safeAreaInsets)
        } else {
            let scale = customization.controlScale.multiplier
            let usableWidth = max(300, size.width - Geist.Spacing.s8)
            let dPadButton = min(82 * scale, max(64 * scale, (usableWidth / 4.2) * scale))
            let actionButton = min(82 * scale, max(64 * scale, (usableWidth / 4.5) * scale))
            let mapButtonSize = CGSize(width: 94 * scale, height: 58 * scale)
            let pauseButtonSize = CGSize(width: 108 * scale, height: 58 * scale)
            let dPadSize = CGSize(width: dPadButton, height: dPadButton)
            let actionSize = CGSize(width: actionButton, height: actionButton)
            let dPadHitButton = ControllerLayoutMetrics.hitSize(for: dPadSize)
            let actionHitButton = ControllerLayoutMetrics.hitSize(for: actionSize)

            VStack(spacing: Geist.Spacing.s4) {
                Spacer(minLength: Geist.Spacing.s2)

                if customization.layoutMode == .standard {
                    DPadView(buttonSize: dPadSize, customization: customization)
                        .frame(width: dPadHitButton.width * 3, height: dPadHitButton.height * 3)

                    utilityButtons(
                        mapButtonSize: mapButtonSize,
                        pauseButtonSize: pauseButtonSize,
                        spacing: Geist.Spacing.s4,
                        customization: customization
                    )

                    ActionButtonsView(buttonSize: actionSize, customization: customization)
                        .frame(width: actionHitButton.width * 2, height: actionHitButton.height * 2)
                } else {
                    ActionButtonsView(buttonSize: actionSize, customization: customization)
                        .frame(width: actionHitButton.width * 2, height: actionHitButton.height * 2)

                    utilityButtons(
                        mapButtonSize: mapButtonSize,
                        pauseButtonSize: pauseButtonSize,
                        spacing: Geist.Spacing.s4,
                        customization: customization
                    )

                    DPadView(buttonSize: dPadSize, customization: customization)
                        .frame(width: dPadHitButton.width * 3, height: dPadHitButton.height * 3)
                }

                Spacer(minLength: Geist.Spacing.s2)
            }
            .padding(.leading, max(Geist.Spacing.s4, safeAreaInsets.leading + Geist.Spacing.s3))
            .padding(.trailing, max(Geist.Spacing.s4, safeAreaInsets.trailing + Geist.Spacing.s3))
            .padding(.bottom, max(Geist.Spacing.s4, safeAreaInsets.bottom + Geist.Spacing.s2))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                TouchRoutingView()
            }
        }
    }

    private func freeformControllerLayout(size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let isLandscape = size.width >= size.height

        return GamepadFreeformControllerCanvas(customization: client.gamepadCustomization)
            .padding(.leading, max(isLandscape ? Geist.Spacing.s3 : Geist.Spacing.s4, safeAreaInsets.leading + Geist.Spacing.s2))
            .padding(.trailing, max(isLandscape ? Geist.Spacing.s3 : Geist.Spacing.s4, safeAreaInsets.trailing + Geist.Spacing.s2))
            .padding(.bottom, max(Geist.Spacing.s4, safeAreaInsets.bottom + Geist.Spacing.s2))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                TouchRoutingView()
            }
    }

    private func landscapeDPad(metrics: LandscapeControllerMetrics, customization: GamepadCustomization) -> some View {
        DPadView(buttonSize: metrics.dPadButtonSize, customization: customization)
            .frame(width: metrics.dPadHitSize.width * 3, height: metrics.dPadHitSize.height * 3)
            .fixedSize()
    }

    private func landscapeActions(metrics: LandscapeControllerMetrics, customization: GamepadCustomization) -> some View {
        ActionButtonsView(buttonSize: metrics.actionButtonSize, customization: customization)
            .frame(width: metrics.actionHitSize.width * 2, height: metrics.actionHitSize.height * 2)
            .fixedSize()
    }

    private func landscapeUtilityButtons(metrics: LandscapeControllerMetrics, customization: GamepadCustomization) -> some View {
        utilityButtons(
            mapButtonSize: metrics.mapButtonSize,
            pauseButtonSize: metrics.pauseButtonSize,
            spacing: metrics.utilitySpacing,
            customization: customization
        )
        .frame(width: metrics.utilityHitWidth, height: metrics.utilityHitHeight)
        .fixedSize()
        .layoutPriority(1)
    }

    private func utilityButtons(
        mapButtonSize: CGSize,
        pauseButtonSize: CGSize,
        spacing: CGFloat,
        customization: GamepadCustomization
    ) -> some View {
        HStack(spacing: spacing) {
            GamepadButton(button: .map, size: mapButtonSize, shape: .capsule, customization: customization)
            GamepadButton(button: .pause, size: pauseButtonSize, shape: .capsule, customization: customization)
        }
    }

    private var topBar: some View {
        HStack(spacing: Geist.Spacing.s3) {
            StatusPill(title: "Connected", systemImage: "wifi", tone: .success)

            Text(client.lastSentEvent)
                .geistTypography(.label12Mono)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: Geist.Spacing.s2)

            Button {
                TouchCaptureUIView.deactivateAllRegisteredTouches()
                client.releaseAll()
                isShowingCustomization = true
            } label: {
                Label("Customize", systemImage: "slider.horizontal.3")
                    .labelStyle(.iconOnly)
            }
            .geistButtonStyle(.secondary, size: .small)
            .accessibilityLabel("Customize keypad")

            Button("Disconnect iPhone") {
                client.disconnect(sendReleaseAll: true)
            }
            .geistButtonStyle(.error, size: .small)
        }
        .padding(Geist.Spacing.s2)
        .background(Geist.color(.background100, scheme: colorScheme), in: Capsule())
        .overlay(Capsule().stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1))
    }
}

private struct LandscapeControllerMetrics {
    let dPadButtonSize: CGSize
    let actionButtonSize: CGSize
    let mapButtonSize: CGSize
    let pauseButtonSize: CGSize
    let utilitySpacing: CGFloat
    let controlSpacing: CGFloat
    let spacerMinLength: CGFloat
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat
    let bottomPadding: CGFloat

    var dPadHitSize: CGSize {
        ControllerLayoutMetrics.hitSize(for: dPadButtonSize)
    }

    var actionHitSize: CGSize {
        ControllerLayoutMetrics.hitSize(for: actionButtonSize)
    }

    var utilityHitWidth: CGFloat {
        ControllerLayoutMetrics.hitSize(for: mapButtonSize).width
        + ControllerLayoutMetrics.hitSize(for: pauseButtonSize).width
        + utilitySpacing
    }

    var utilityHitHeight: CGFloat {
        max(
            ControllerLayoutMetrics.hitSize(for: mapButtonSize).height,
            ControllerLayoutMetrics.hitSize(for: pauseButtonSize).height
        )
    }

    init(size: CGSize, safeAreaInsets: EdgeInsets, controlScale: GamepadControlScale) {
        let customizationScale = controlScale.multiplier
        let availableHeight = max(220, size.height - 58)
        let sideSafePadding = Geist.Spacing.s2
        leadingPadding = max(Geist.Spacing.s3, safeAreaInsets.leading + sideSafePadding)
        trailingPadding = max(Geist.Spacing.s3, safeAreaInsets.trailing + sideSafePadding)
        bottomPadding = max(Geist.Spacing.s4, safeAreaInsets.bottom + Geist.Spacing.s2)

        let contentWidth = max(320, size.width - leadingPadding - trailingPadding)
        utilitySpacing = contentWidth < 780 ? Geist.Spacing.s2 : Geist.Spacing.s4
        controlSpacing = contentWidth < 780 ? Geist.Spacing.s3 : max(Geist.Spacing.s4, min(Geist.Spacing.s6, contentWidth * 0.02))
        spacerMinLength = Geist.Spacing.s2

        let baseDPadButton = min(82 * customizationScale, max(64 * customizationScale, availableHeight * 0.24 * customizationScale), contentWidth * 0.12 * customizationScale)
        let baseActionButton = min(86 * customizationScale, max(64 * customizationScale, availableHeight * 0.25 * customizationScale), contentWidth * 0.13 * customizationScale)
        let baseMapWidth = min(92 * customizationScale, max(74 * customizationScale, contentWidth * 0.13 * customizationScale))
        let basePauseWidth = min(104 * customizationScale, max(84 * customizationScale, contentWidth * 0.145 * customizationScale))
        let baseUtilityHeight = min(64 * customizationScale, max(52 * customizationScale, availableHeight * 0.18 * customizationScale))

        // Landscape iPhones have a lot less horizontal room after the safe-area
        // notches are removed. Scale the visual controls as one group so the full
        // two-column action cluster stays inside the playable area instead of being
        // squeezed off the trailing edge by SwiftUI's HStack compression.
        let hitOutsetWidth = ControllerLayoutMetrics.buttonHitOutset * 2
        let hitOutsetBudget = hitOutsetWidth * 7 // D-pad columns + action columns + Map/Pause
        let layoutOverhead = hitOutsetBudget
            + utilitySpacing
            + controlSpacing * 4
            + spacerMinLength * 2
        let scalableWidth = baseDPadButton * 3
            + baseActionButton * 2
            + baseMapWidth
            + basePauseWidth
        let fittingScale = (contentWidth - layoutOverhead) / max(scalableWidth, 1)
        let scale = min(1, max(0.5, fittingScale))

        let dPadButton = max(50, floor(baseDPadButton * scale))
        let actionButton = max(52, floor(baseActionButton * scale))
        let mapWidth = max(58, floor(baseMapWidth * scale))
        let pauseWidth = max(68, floor(basePauseWidth * scale))
        let utilityHeight = max(46, floor(baseUtilityHeight * scale))

        dPadButtonSize = CGSize(width: dPadButton, height: dPadButton)
        actionButtonSize = CGSize(width: actionButton, height: actionButton)
        mapButtonSize = CGSize(width: mapWidth, height: utilityHeight)
        pauseButtonSize = CGSize(width: pauseWidth, height: utilityHeight)
    }
}

private enum ControllerLayoutMetrics {
    static let buttonHitOutset: CGFloat = 10

    static func hitSize(for visualSize: CGSize) -> CGSize {
        CGSize(
            width: visualSize.width + buttonHitOutset * 2,
            height: visualSize.height + buttonHitOutset * 2
        )
    }
}

private struct GamepadFreeformControllerCanvas: View {
    let customization: GamepadCustomization

    var body: some View {
        GeometryReader { proxy in
            let controls = customization.resolvedControls(in: proxy.size)

            ZStack {
                ForEach(controls) { control in
                    GamepadButton(
                        button: control.mappedButton,
                        size: control.size,
                        shape: control.shape,
                        labelOverride: control.label,
                        customization: customization
                    )
                    .position(control.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct DPadView: View {
    @Environment(\.colorScheme) private var colorScheme
    var buttonSize = CGSize(width: 78, height: 78)
    let customization: GamepadCustomization

    var body: some View {
        let hitSize = ControllerLayoutMetrics.hitSize(for: buttonSize)

        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                Color.clear.frame(width: hitSize.width, height: hitSize.height)
                GamepadButton(button: .up, size: buttonSize, customization: customization)
                Color.clear.frame(width: hitSize.width, height: hitSize.height)
            }
            GridRow {
                GamepadButton(button: .left, size: buttonSize, customization: customization)
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .fill(Geist.color(.gray100, scheme: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                            .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                    )
                    .frame(width: buttonSize.width, height: buttonSize.height)
                    .frame(width: hitSize.width, height: hitSize.height)
                GamepadButton(button: .right, size: buttonSize, customization: customization)
            }
            GridRow {
                Color.clear.frame(width: hitSize.width, height: hitSize.height)
                GamepadButton(button: .down, size: buttonSize, customization: customization)
                Color.clear.frame(width: hitSize.width, height: hitSize.height)
            }
        }
    }
}

private struct ActionButtonsView: View {
    var buttonSize = CGSize(width: 82, height: 82)
    let customization: GamepadCustomization

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                GamepadButton(button: .focus, size: buttonSize, customization: customization)
                GamepadButton(button: .dash, size: buttonSize, customization: customization)
            }
            GridRow {
                GamepadButton(button: .attack, size: buttonSize, customization: customization)
                GamepadButton(button: .jump, size: buttonSize, customization: customization)
            }
        }
    }
}

private struct GamepadButton: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    let button: GameButton
    let size: CGSize
    var shape: GamepadButtonShapeStyle = .roundedRectangle
    var labelOverride: String? = nil
    let customization: GamepadCustomization

    @State private var isPressed = false
    private static let hapticsEnabled = false
    private let haptic = GamepadButton.hapticsEnabled ? UIImpactFeedbackGenerator(style: .light) : nil

    private var title: String {
        labelOverride ?? customization.visualLabel(for: button)
    }

    var body: some View {
        let hitSize = ControllerLayoutMetrics.hitSize(for: size)

        ZStack {
            ZStack {
                buttonBackground
                    .shadow(color: Color.black.opacity(isPressed ? 0.16 : 0.04), radius: isPressed ? 2 : 1, y: isPressed ? 1 : 2)

                if customization.showsButtonLabels {
                    Text(title)
                        .geistTypography(title.count <= 2 ? .heading32 : .button16)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(customization.accentStyle.buttonForeground(isPressed: isPressed, scheme: colorScheme))
                        .padding(.horizontal, 4)
                }
            }
            .scaleEffect(isPressed ? 0.96 : 1)
            .allowsHitTesting(false)
            .frame(width: size.width, height: size.height)

            TouchCaptureView { pressed, isActive, pressIdentifier in
                handlePressEdge(pressed, isActive: isActive, pressIdentifier: pressIdentifier)
            }
            .frame(width: hitSize.width, height: hitSize.height)
        }
        .frame(width: hitSize.width, height: hitSize.height)
        .accessibilityLabel(button.displayName)
        .onAppear {
            haptic?.prepare()
        }
        .onDisappear {
            isPressed = false
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        let fillColor = customization.accentStyle.buttonFill(isPressed: isPressed, scheme: colorScheme)
        let strokeColor = customization.accentStyle.buttonStroke(isPressed: isPressed, scheme: colorScheme)
        let lineWidth: CGFloat = isPressed ? 2 : 1

        switch shape {
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

    private func handlePressEdge(_ pressed: Bool, isActive: Bool, pressIdentifier: UInt64) {
        // The UIKit touch view is authoritative for press edges. Send every edge to
        // ControllerClient before consulting SwiftUI state so fast taps cannot lose a
        // release through a stale render closure.
        client.setButton(button, pressed: pressed, pressIdentifier: pressIdentifier)

        guard isActive != isPressed else { return }
        isPressed = isActive

        if pressed {
            haptic?.impactOccurred(intensity: 0.45)
            haptic?.prepare()
        }
    }
}
