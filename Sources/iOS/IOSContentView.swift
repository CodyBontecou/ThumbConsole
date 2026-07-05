import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct IOSContentView: View {
    @EnvironmentObject private var client: ControllerClient
    @AppStorage("macHost") private var macHost = "192.168.0.113"
    @AppStorage("macPort") private var macPort = "8765"
    @AppStorage("pairingCode") private var pairingCode = ""
    @State private var prefersConnectionView = false

    private let defaultMacHost = "192.168.0.113"
    private let defaultMacPort = "8765"

    private var shouldShowControllerPad: Bool {
        client.isConnected || (client.canViewSavedKeypadOffline && !prefersConnectionView)
    }

    var body: some View {
        let isShowingControllerPad = shouldShowControllerPad

        ZStack {
            if isShowingControllerPad {
                ControllerPadView(onShowConnectionPage: {
                    prefersConnectionView = true
                })
                .ignoresSafeArea()
            } else {
                ConnectionView(
                    macHost: $macHost,
                    macPort: $macPort,
                    pairingCode: $pairingCode,
                    onShowSavedKeypad: {
                        prefersConnectionView = false
                    }
                )
            }
        }
        .geistScreenBackground()
        .statusBarHidden(isShowingControllerPad)
        .persistentSystemOverlays(isShowingControllerPad ? .hidden : .automatic)
        .onAppear {
            if macHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                macHost = defaultMacHost
            }
            if macPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                macPort = defaultMacPort
            }
            // Pairing codes are one-time setup hints. Smart Connect uses the trusted token
            // saved after a successful pairing instead of reusing stale six-digit codes.
            pairingCode = ""
            client.startSmartConnect()
        }
        .onChange(of: client.isConnected) { _, isConnected in
            if isConnected {
                prefersConnectionView = false
            }
        }
    }
}

private enum IOSKeypadSettings {
    static let hapticsEnabledDefaultsKey = "PocketPad.iOS.keypadHapticsEnabled.v1"
}

private struct KeypadHapticsEnabledEnvironmentKey: EnvironmentKey {
    static let defaultValue = true
}

private extension EnvironmentValues {
    var keypadHapticsEnabled: Bool {
        get { self[KeypadHapticsEnabledEnvironmentKey.self] }
        set { self[KeypadHapticsEnabledEnvironmentKey.self] = newValue }
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
    @AppStorage(IOSKeypadSettings.hapticsEnabledDefaultsKey) private var isKeypadHapticsEnabled = true
    let onShowSavedKeypad: () -> Void

    @State private var isShowingScanner = false
    @State private var qrScanError: String?
    @State private var pendingPairingCode = ""

    private var keypadColorSchemePreferenceBinding: Binding<GamepadColorSchemePreference> {
        Binding(
            get: { client.gamepadCustomization.colorSchemePreference },
            set: { client.setKeypadColorSchemePreference($0) }
        )
    }

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

            if let smartConnectStatus = client.smartConnectStatus {
                MessageBanner(text: smartConnectStatus, tone: .accent)
            }
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
                client.startSmartConnect()
            } label: {
                Label("Smart Connect", systemImage: "bolt.horizontal.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.primary, size: .large)

            if client.canViewSavedKeypadOffline {
                Button {
                    onShowSavedKeypad()
                } label: {
                    Label("View Saved Keypad", systemImage: "rectangle.grid.2x2")
                        .frame(maxWidth: .infinity)
                }
                .geistButtonStyle(.secondary, size: .large)
            }

            Button {
                qrScanError = nil
                isShowingScanner = true
            } label: {
                Label("Scan Mac QR Code", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.secondary, size: .large)

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

            DividerLabel("iPhone Settings")

            KeypadAppearancePickerRow(selection: keypadColorSchemePreferenceBinding)
            KeypadHapticsToggleRow(isEnabled: $isKeypadHapticsEnabled)
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
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .foregroundStyle(tone.foreground(scheme: colorScheme))
            .padding(.horizontal, Geist.Spacing.s3)
            .padding(.vertical, Geist.Spacing.s2)
            .background(tone.background(scheme: colorScheme), in: Capsule())
            .overlay(Capsule().stroke(tone.border(scheme: colorScheme), lineWidth: 1))
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
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

private struct KeypadAppearancePickerRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selection: GamepadColorSchemePreference

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text("Keypad Appearance")
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Text("Choose whether the keypad uses light mode, dark mode, or follows iOS.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker("Keypad Appearance", selection: $selection) {
                ForEach(GamepadColorSchemePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s3)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .fill(Geist.color(.gray100, scheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .accessibilityHint("Controls whether the keypad follows iOS appearance or is forced light or dark.")
    }
}

private struct KeypadHapticsToggleRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle(isOn: $isEnabled) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text("Keypad Haptics")
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

                Text("Vibrate when you press keypad buttons.")
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .tint(Geist.color(.blue700, scheme: colorScheme))
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s3)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .fill(Geist.color(.gray100, scheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
        .accessibilityHint("Controls whether keypad button presses vibrate.")
    }
}

private struct KeypadSettingsMenu: View {
    @Binding var isHapticFeedbackEnabled: Bool
    @Binding var colorSchemePreference: GamepadColorSchemePreference
    let onReleaseAllInputs: () -> Void

    var body: some View {
        Menu {
            Picker(selection: $colorSchemePreference) {
                ForEach(GamepadColorSchemePreference.allCases) { preference in
                    Text(preference.displayName).tag(preference)
                }
            } label: {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
            }

            Toggle(isOn: $isHapticFeedbackEnabled) {
                Label("Haptic Feedback", systemImage: "waveform.path")
            }

            Divider()

            Button(role: .destructive) {
                onReleaseAllInputs()
            } label: {
                Label("Release All Keys", systemImage: "keyboard.chevron.compact.down")
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28)
        }
        .geistButtonStyle(.secondary, size: .small)
        .accessibilityLabel("Keypad settings")
        .accessibilityHint("Opens settings for keypad appearance, feedback, and input reset.")
    }
}

private struct ControllerPadView: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(IOSKeypadSettings.hapticsEnabledDefaultsKey) private var isKeypadHapticsEnabled = true
    @State private var isTopBarVisible = true
    @State private var isExportingKeypadConfiguration = false
    @State private var keypadExportStatus: String?

    let onShowConnectionPage: (() -> Void)?

    init(onShowConnectionPage: (() -> Void)? = nil) {
        self.onShowConnectionPage = onShowConnectionPage
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width >= proxy.size.height
            let keypadColorScheme = client.gamepadCustomization.resolvedColorScheme(system: colorScheme)

            ZStack(alignment: .top) {
                Group {
                    if isLandscape {
                        landscapeControllerLayout(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                    } else {
                        portraitControllerLayout(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                ControllerTopBarDrawer(
                    isVisible: $isTopBarVisible,
                    safeAreaInsets: proxy.safeAreaInsets,
                    isLandscape: isLandscape,
                    collapsedTitle: ""
                ) {
                    topBar(isLandscape: isLandscape)
                }
            }
            .background {
                GamepadFillShapeLayer(
                    shape: Rectangle(),
                    fillStyle: client.gamepadCustomization.keypadBackgroundFillStyle(scheme: keypadColorScheme)
                )
                .ignoresSafeArea()
            }
            .environment(\.colorScheme, keypadColorScheme)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .environment(\.keypadHapticsEnabled, isKeypadHapticsEnabled)
        .onAppear {
            if !client.isConnected {
                isTopBarVisible = true
            }
        }
        .onChange(of: client.isConnected) { _, isConnected in
            isTopBarVisible = !isConnected
        }
        .onChange(of: client.gamepadCustomization) { _, _ in
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
        }
        .fileExporter(
            isPresented: $isExportingKeypadConfiguration,
            document: keypadExportDocument,
            contentType: .json,
            defaultFilename: keypadExportFilename
        ) { result in
            switch result {
            case .success:
                keypadExportStatus = "Keypad JSON saved"
            case .failure(let error):
                keypadExportStatus = "Export failed: \(error.localizedDescription)"
            }
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

    @ViewBuilder
    private func topBar(isLandscape: Bool) -> some View {
        if isLandscape {
            landscapeTopBar
        } else {
            portraitTopBar
        }
    }

    private var landscapeTopBar: some View {
        HStack(spacing: Geist.Spacing.s3) {
            StatusPill(title: controllerStatusTitle, systemImage: controllerStatusSystemImage, tone: controllerStatusTone)

            if !client.gamepadProfiles.isEmpty {
                keypadProfileMenu
            }

            keypadSettingsMenu
            statusDetailText

            Spacer(minLength: Geist.Spacing.s2)

            homeButton
            connectionActionButton(isCompact: false)
        }
        .padding(Geist.Spacing.s2)
        .background(Geist.color(.background100, scheme: colorScheme), in: Capsule())
        .overlay(Capsule().stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1))
    }

    private var portraitTopBar: some View {
        HStack(spacing: Geist.Spacing.s2) {
            StatusPill(title: controllerStatusTitle, systemImage: controllerStatusSystemImage, tone: controllerStatusTone)

            if !client.gamepadProfiles.isEmpty {
                compactKeypadProfileMenu
            }

            Spacer(minLength: 0)

            keypadSettingsMenu
            homeButton
            connectionActionButton(isCompact: true)
        }
        .padding(Geist.Spacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Geist.color(.background100, scheme: colorScheme),
            in: RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    private var statusDetailText: some View {
        Text(controllerStatusDetail)
            .geistTypography(.label12Mono)
            .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var homeButton: some View {
        Button {
            showConnectionPage()
        } label: {
            Image(systemName: "house.fill")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28)
        }
        .geistButtonStyle(.secondary, size: .small)
        .disabled(onShowConnectionPage == nil)
        .accessibilityLabel("Home")
        .accessibilityHint("Returns to the connection page.")
    }

    @ViewBuilder
    private func connectionActionButton(isCompact: Bool) -> some View {
        if client.isConnected {
            Button {
                client.disconnect(sendReleaseAll: true)
            } label: {
                if isCompact {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28)
                } else {
                    Text("Disconnect iPhone")
                }
            }
            .geistButtonStyle(.error, size: .small)
            .accessibilityLabel("Disconnect iPhone")
        } else {
            Button {
                onShowConnectionPage?()
            } label: {
                if isCompact {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 28)
                } else {
                    Text("Connect Mac")
                }
            }
            .geistButtonStyle(.secondary, size: .small)
            .disabled(onShowConnectionPage == nil)
            .accessibilityLabel("Connect Mac")
        }
    }

    private func showConnectionPage() {
        if client.isConnected {
            client.disconnect(sendReleaseAll: true)
        }
        onShowConnectionPage?()
    }

    private var controllerStatusTitle: String {
        switch client.state {
        case .connected: "Connected"
        case .connecting: "Connecting…"
        case .pairingCodeRequired: "Pairing Needed"
        case .failed, .disconnected: "Saved Keypad"
        }
    }

    private var controllerStatusSystemImage: String {
        switch client.state {
        case .connected: "wifi"
        case .connecting: "arrow.triangle.2.circlepath"
        case .pairingCodeRequired: "key.fill"
        case .failed, .disconnected: "rectangle.grid.2x2"
        }
    }

    private var controllerStatusTone: GeistInterfaceTone {
        switch client.state {
        case .connected: .success
        case .connecting, .pairingCodeRequired: .warning
        case .failed, .disconnected: .neutral
        }
    }

    private var controllerStatusDetail: String {
        if let keypadExportStatus {
            return keypadExportStatus
        }

        if client.isConnected {
            return client.lastSentEvent
        }

        if case .failed = client.state, let error = client.lastError {
            return error
        }

        if let smartConnectStatus = client.smartConnectStatus {
            return smartConnectStatus
        }

        if let macName = client.savedKeypadMacName {
            return "Saved from \(macName)"
        }

        return "Saved on this iPhone"
    }

    private var keypadExportDocument: PocketPadKeypadConfigurationJSONDocument {
        PocketPadKeypadConfigurationJSONDocument(
            export: PocketPadKeypadConfigurationExport(
                profiles: client.gamepadProfiles,
                activeProfileID: client.selectedGamepadProfileID,
                defaultProfileID: client.defaultGamepadProfileID
            )
        )
    }

    private var keypadExportFilename: String {
        PocketPadKeypadConfigurationExport.suggestedFilename(activeProfileName: client.selectedGamepadProfileName)
    }

    private var keypadSettingsMenu: some View {
        KeypadSettingsMenu(
            isHapticFeedbackEnabled: $isKeypadHapticsEnabled,
            colorSchemePreference: keypadColorSchemePreferenceBinding
        ) {
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
        }
    }

    private var keypadColorSchemePreferenceBinding: Binding<GamepadColorSchemePreference> {
        Binding(
            get: { client.gamepadCustomization.colorSchemePreference },
            set: { client.setKeypadColorSchemePreference($0) }
        )
    }

    private var keypadProfileMenu: some View {
        Menu {
            keypadProfileMenuItems
        } label: {
            HStack(spacing: Geist.Spacing.s1) {
                Image(systemName: client.isSelectedGamepadProfileDefault ? "star.fill" : "rectangle.grid.2x2")
                    .font(.system(size: 11, weight: .semibold))
                Text(client.selectedGamepadProfileName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: 160)
        }
        .geistButtonStyle(.secondary, size: .small)
        .accessibilityLabel("Keypad setup")
    }

    private var compactKeypadProfileMenu: some View {
        Menu {
            keypadProfileMenuItems
        } label: {
            Image(systemName: client.isSelectedGamepadProfileDefault ? "star.fill" : "rectangle.grid.2x2")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28)
        }
        .geistButtonStyle(.secondary, size: .small)
        .accessibilityLabel("Keypad setup: \(client.selectedGamepadProfileName)")
    }

    @ViewBuilder
    private var keypadProfileMenuItems: some View {
        ForEach(client.gamepadProfiles) { profile in
            Button {
                client.selectGamepadProfile(profile.id)
            } label: {
                Label(
                    profile.name,
                    systemImage: profile.id == client.selectedGamepadProfileID ? "checkmark.circle.fill" : (profile.id == client.defaultGamepadProfileID ? "star.fill" : "rectangle.grid.2x2")
                )
            }
        }

        Divider()

        Button {
            client.setDefaultGamepadProfile(client.selectedGamepadProfileID)
        } label: {
            Label(
                client.isSelectedGamepadProfileDefault ? "Current Is Default" : "Make Current Default",
                systemImage: client.isSelectedGamepadProfileDefault ? "star.fill" : "star"
            )
        }
        .disabled(client.isSelectedGamepadProfileDefault)

        Button {
            keypadExportStatus = "Choose where to save keypad JSON"
            isExportingKeypadConfiguration = true
        } label: {
            Label("Export Keypads as JSON", systemImage: "square.and.arrow.up")
        }
    }
}

private struct ControllerTopBarDrawer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isVisible: Bool
    let safeAreaInsets: EdgeInsets
    let isLandscape: Bool
    let collapsedTitle: String
    let content: Content

    init(
        isVisible: Binding<Bool>,
        safeAreaInsets: EdgeInsets,
        isLandscape: Bool,
        collapsedTitle: String = "Controls",
        @ViewBuilder content: () -> Content
    ) {
        self._isVisible = isVisible
        self.safeAreaInsets = safeAreaInsets
        self.isLandscape = isLandscape
        self.collapsedTitle = collapsedTitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: Geist.Spacing.s1) {
            if isVisible {
                content
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 10, y: 4)
                    .contentShape(Rectangle())
                    .simultaneousGesture(drawerDragGesture)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            revealHandle
        }
        .padding(.top, topPadding)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .frame(maxWidth: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .highPriorityGesture(drawerDragGesture)
        .background {
            ControllerTopBarSwipeBridge(isVisible: $isVisible, animation: drawerAnimation)
        }
        .animation(drawerAnimation, value: isVisible)
        .zIndex(10)
    }

    private var revealHandle: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Geist.color(.grayAlpha700, scheme: colorScheme))
                .frame(width: isVisible ? 36 : 56, height: 5)

            if !isVisible && !collapsedTitle.isEmpty {
                Text(collapsedTitle)
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, isVisible ? Geist.Spacing.s3 : Geist.Spacing.s4)
        .padding(.vertical, Geist.Spacing.s2)
        .background(
            Capsule()
                .fill(Geist.color(.background100, scheme: colorScheme).opacity(isVisible ? 0.74 : 0.94))
        )
        .overlay(
            Capsule()
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                .opacity(isVisible ? 0 : 1)
        )
        .contentShape(Capsule())
        .onTapGesture {
            setVisible(!isVisible)
        }
        .simultaneousGesture(drawerDragGesture)
        .accessibilityLabel(isVisible ? "Hide connection bar" : "Show connection bar")
        .accessibilityHint(isVisible ? "Swipe up or tap to hide the connection controls." : "Swipe down or tap to show the connection controls.")
    }

    private var drawerDragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onEnded { value in
                let verticalMovement = dominantMovement(
                    current: value.translation.height,
                    predicted: value.predictedEndTranslation.height
                )
                let horizontalMovement = max(
                    abs(value.translation.width),
                    abs(value.predictedEndTranslation.width)
                )
                guard abs(verticalMovement) > max(18, horizontalMovement * 0.65) else { return }

                setVisible(verticalMovement > 0)
            }
    }

    private func dominantMovement(current: CGFloat, predicted: CGFloat) -> CGFloat {
        abs(predicted) > abs(current) ? predicted : current
    }

    private var topPadding: CGFloat {
        let topInset = max(effectiveSafeAreaInsets.top, minimumPortraitTopInset)
        let extraPadding = isLandscape ? Geist.Spacing.s2 : 0
        return max(isLandscape ? Geist.Spacing.s3 : Geist.Spacing.s2, topInset + extraPadding)
    }

    private var leadingPadding: CGFloat {
        max(isLandscape ? Geist.Spacing.s6 : Geist.Spacing.s4, effectiveSafeAreaInsets.leading + Geist.Spacing.s3)
    }

    private var trailingPadding: CGFloat {
        max(isLandscape ? Geist.Spacing.s6 : Geist.Spacing.s4, effectiveSafeAreaInsets.trailing + Geist.Spacing.s3)
    }

    private var effectiveSafeAreaInsets: EdgeInsets {
        #if os(iOS)
        let windowInsets = Self.currentWindowSafeAreaInsets()
        return EdgeInsets(
            top: max(safeAreaInsets.top, windowInsets.top),
            leading: max(safeAreaInsets.leading, windowInsets.left),
            bottom: max(safeAreaInsets.bottom, windowInsets.bottom),
            trailing: max(safeAreaInsets.trailing, windowInsets.right)
        )
        #else
        return safeAreaInsets
        #endif
    }

    private var minimumPortraitTopInset: CGFloat {
        #if os(iOS)
        return !isLandscape && UIDevice.current.userInterfaceIdiom == .phone ? 54 : 0
        #else
        return 0
        #endif
    }

    #if os(iOS)
    private static func currentWindowSafeAreaInsets() -> UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .safeAreaInsets ?? .zero
    }
    #endif

    private var drawerAnimation: Animation {
        .spring(response: 0.26, dampingFraction: 0.86)
    }

    private func setVisible(_ visible: Bool) {
        withAnimation(drawerAnimation) {
            isVisible = visible
        }
    }
}

private struct ControllerTopBarSwipeBridge: UIViewRepresentable {
    @Binding var isVisible: Bool
    let animation: Animation

    func makeCoordinator() -> Coordinator {
        Coordinator(isVisible: $isVisible, animation: animation)
    }

    func makeUIView(context: Context) -> ActivationView {
        let view = ActivationView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: ActivationView, context: Context) {
        context.coordinator.isVisible = $isVisible
        context.coordinator.animation = animation
        uiView.updateActivationFrame()
    }

    final class ActivationView: UIView {
        weak var coordinator: Coordinator?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.attach(to: window)
            updateActivationFrame()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateActivationFrame()
        }

        func updateActivationFrame() {
            guard let window else {
                coordinator?.activationFrame = .null
                return
            }

            coordinator?.activationFrame = convert(bounds, to: window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isVisible: Binding<Bool>
        var animation: Animation
        fileprivate var activationFrame = CGRect.null
        private weak var window: UIWindow?
        private lazy var panRecognizer: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.maximumNumberOfTouches = 1
            recognizer.delegate = self
            return recognizer
        }()

        init(isVisible: Binding<Bool>, animation: Animation) {
            self.isVisible = isVisible
            self.animation = animation
        }

        deinit {
            window?.removeGestureRecognizer(panRecognizer)
        }

        func attach(to newWindow: UIWindow?) {
            guard window !== newWindow else { return }

            window?.removeGestureRecognizer(panRecognizer)
            window = newWindow
            newWindow?.addGestureRecognizer(panRecognizer)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer === panRecognizer,
                  let window = gestureRecognizer.view
            else { return false }

            let paddedFrame = activationFrame.insetBy(dx: -18, dy: -18)
            return !paddedFrame.isNull && paddedFrame.contains(touch.location(in: window))
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === panRecognizer,
                  let window = gestureRecognizer.view
            else { return false }

            let translation = panRecognizer.translation(in: window)
            let velocity = panRecognizer.velocity(in: window)
            let verticalIntent = max(abs(translation.y), abs(velocity.y) * 0.05)
            let horizontalIntent = max(abs(translation.x), abs(velocity.x) * 0.05)
            return verticalIntent > max(8, horizontalIntent * 0.65)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .ended,
                  let window = recognizer.view
            else { return }

            let translation = recognizer.translation(in: window)
            let velocity = recognizer.velocity(in: window)
            let projectedTranslation = CGPoint(
                x: translation.x + velocity.x * 0.12,
                y: translation.y + velocity.y * 0.12
            )
            let verticalMovement = abs(projectedTranslation.y) > abs(translation.y) ? projectedTranslation.y : translation.y
            let horizontalMovement = max(abs(translation.x), abs(projectedTranslation.x))
            guard abs(verticalMovement) > max(18, horizontalMovement * 0.65) else { return }

            setVisible(verticalMovement > 0)
        }

        private func setVisible(_ visible: Bool) {
            withAnimation(animation) {
                isVisible.wrappedValue = visible
            }
        }
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
        let sideSafePadding = Geist.Spacing.s2
        leadingPadding = max(Geist.Spacing.s3, safeAreaInsets.leading + sideSafePadding)
        trailingPadding = max(Geist.Spacing.s3, safeAreaInsets.trailing + sideSafePadding)
        bottomPadding = max(Geist.Spacing.s4, safeAreaInsets.bottom + Geist.Spacing.s2)

        let availableHeight = max(220, size.height - bottomPadding)
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
                    if control.isJoystick, let joystickMapping = control.joystickMapping {
                        GamepadJoystick(
                            mapping: joystickMapping,
                            outputSettings: control.joystickOutputSettings ?? .defaultValue,
                            label: control.label,
                            size: control.size,
                            elementCustomization: control.layoutCustomization,
                            customization: customization
                        )
                        .rotationEffect(.degrees(control.rotationDegrees))
                        .position(control.center)
                    } else if control.isTrigger, let triggerSettings = control.triggerSettings {
                        GamepadTrigger(
                            mappedButton: control.mappedButton,
                            label: control.label,
                            size: control.size,
                            elementCustomization: control.layoutCustomization,
                            settings: triggerSettings,
                            customization: customization
                        )
                        .rotationEffect(.degrees(control.rotationDegrees))
                        .position(control.center)
                    } else if control.isTrackpad {
                        GamepadTrackpad(
                            label: control.label,
                            size: control.size,
                            elementCustomization: control.layoutCustomization,
                            settings: control.trackpadSettings ?? .defaultValue,
                            customization: customization
                        )
                        .rotationEffect(.degrees(control.rotationDegrees))
                        .position(control.center)
                    } else {
                        GamepadButton(
                            button: control.mappedButton,
                            size: control.size,
                            shape: control.shape,
                            labelOverride: control.label,
                            elementCustomization: control.layoutCustomization,
                            customization: customization
                        )
                        .rotationEffect(.degrees(control.rotationDegrees))
                        .position(control.center)
                    }
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

private struct GamepadJoystick: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    let mapping: GamepadJoystickMapping
    let outputSettings: GamepadJoystickOutputSettings
    let label: String
    let size: CGSize
    let elementCustomization: GamepadButtonCustomization
    let customization: GamepadCustomization

    @State private var activeDirections: Set<GamepadJoystickDirection> = []
    @State private var normalizedOffset = CGSize.zero

    private var visualSide: CGFloat {
        min(size.width, size.height)
    }

    private var knobSide: CGFloat {
        max(34, visualSide * 0.36)
    }

    private var knobTravelRadius: CGFloat {
        max(0, (visualSide - knobSide) / 2 - 4)
    }

    var body: some View {
        let hitSide = max(visualSide + ControllerLayoutMetrics.buttonHitOutset * 2, visualSide)

        ZStack {
            joystickBase
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

            JoystickCaptureView { direction, pressed, pressIdentifier in
                handleDirectionEdge(direction, pressed: pressed, pressIdentifier: pressIdentifier)
            } onVectorChanged: { vector, directions in
                normalizedOffset = CGSize(width: vector.dx, height: vector.dy)
                activeDirections = directions
                handleVectorChanged(vector)
            }
            .frame(width: hitSide, height: hitSide)
        }
        .frame(width: hitSide, height: hitSide)
        .accessibilityLabel(label)
        .onDisappear {
            activeDirections.removeAll()
            normalizedOffset = .zero
        }
    }

    private var joystickBase: some View {
        let accentStyle = elementCustomization.accentStyle ?? customization.accentStyle
        let fillStyle = elementCustomization.buttonFillStyle(accentStyle: accentStyle, isPressed: !activeDirections.isEmpty, scheme: colorScheme)
        let strokeColor = elementCustomization.buttonStroke(accentStyle: accentStyle, isPressed: !activeDirections.isEmpty, scheme: colorScheme)
        let isActive = !activeDirections.isEmpty
        let foregroundColor = elementCustomization.buttonForeground(accentStyle: accentStyle, isPressed: isActive, scheme: colorScheme)
        let knobFillColor = elementCustomization.joystickKnobFill(accentStyle: accentStyle, isPressed: isActive, scheme: colorScheme)
        let knobStrokeColor = elementCustomization.joystickKnobStroke(accentStyle: accentStyle, isPressed: isActive, scheme: colorScheme)
        let knobOffset = CGSize(width: normalizedOffset.width * knobTravelRadius, height: normalizedOffset.height * knobTravelRadius)

        return ZStack {
            GamepadFillShapeLayer(shape: Circle(), fillStyle: fillStyle)
                .overlay(Circle().stroke(strokeColor, lineWidth: activeDirections.isEmpty ? 1 : 2))
                .shadow(
                    color: Color.black.opacity((activeDirections.isEmpty ? 0.05 : 0.16) * elementCustomization.shadowStrength),
                    radius: (activeDirections.isEmpty ? 2 : 4) * max(0.25, elementCustomization.shadowStrength),
                    y: (activeDirections.isEmpty ? 2 : 3) * elementCustomization.shadowStrength
                )

            Circle()
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                .frame(width: visualSide * 0.70, height: visualSide * 0.70)

            directionLabels(foregroundColor: foregroundColor)

            Circle()
                .fill(knobFillColor)
                .overlay(Circle().stroke(knobStrokeColor, lineWidth: 1))
                .frame(width: knobSide, height: knobSide)
                .offset(knobOffset)
                .animation(.interactiveSpring(response: 0.16, dampingFraction: 0.82), value: normalizedOffset)

            if customization.showsButtonLabels {
                Text(label)
                    .geistTypography(visualSide <= 88 ? .button12 : .button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(foregroundColor)
                    .padding(.horizontal, 6)
                    .offset(y: visualSide * 0.34)
            }
        }
    }

    private func directionLabels(foregroundColor: Color) -> some View {
        ZStack {
            ForEach(GamepadJoystickDirection.allCases) { direction in
                Text(direction.shortLabel)
                    .geistTypography(.label12)
                    .foregroundStyle(foregroundColor.opacity(activeDirections.contains(direction) ? 1 : 0.42))
                    .offset(labelOffset(for: direction))
            }
        }
        .allowsHitTesting(false)
    }

    private func labelOffset(for direction: GamepadJoystickDirection) -> CGSize {
        let radius = visualSide * 0.34
        switch direction {
        case .up: return CGSize(width: 0, height: -radius)
        case .down: return CGSize(width: 0, height: radius)
        case .left: return CGSize(width: -radius, height: 0)
        case .right: return CGSize(width: radius, height: 0)
        }
    }

    private func handleDirectionEdge(_ direction: GamepadJoystickDirection, pressed: Bool, pressIdentifier: UInt64) {
        guard outputSettings.normalized.sendsDigitalDirections else { return }
        client.setButton(mapping[direction], pressed: pressed, pressIdentifier: pressIdentifier)
    }

    private func handleVectorChanged(_ vector: CGVector) {
        let settings = outputSettings.normalized
        guard let stick = settings.analogTarget.stick else { return }
        let transformed = settings.transformedVector(x: vector.dx, y: vector.dy)
        let isFinal = abs(vector.dx) < 0.001 && abs(vector.dy) < 0.001
        client.setGamepadStick(stick, x: Double(transformed.dx), y: Double(transformed.dy), isFinal: isFinal)
    }
}

private struct GamepadTrigger: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    let mappedButton: GameButton
    let label: String
    let size: CGSize
    let elementCustomization: GamepadButtonCustomization
    let settings: GamepadTriggerSettings
    let customization: GamepadCustomization

    @State private var value: CGFloat = 0
    @State private var isDigitalPressed = false

    var body: some View {
        let hitSize = ControllerLayoutMetrics.hitSize(for: size)
        ZStack {
            triggerFace
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

            TriggerCaptureView(orientation: settings.normalized.orientation) { rawValue, isActive in
                handleValueChanged(rawValue, isActive: isActive)
            }
            .frame(width: hitSize.width, height: hitSize.height)
        }
        .frame(width: hitSize.width, height: hitSize.height)
        .accessibilityLabel(label)
        .onDisappear {
            if value != 0 {
                handleValueChanged(0, isActive: false)
            }
        }
    }

    private var triggerFace: some View {
        let normalizedSettings = settings.normalized
        let accentStyle = elementCustomization.accentStyle ?? customization.accentStyle
        let isPressed = value > normalizedSettings.deadZone
        let fillStyle = elementCustomization.buttonFillStyle(accentStyle: accentStyle, isPressed: isPressed, scheme: colorScheme)
        let strokeColor = elementCustomization.buttonStroke(accentStyle: accentStyle, isPressed: isPressed, scheme: colorScheme)
        let foregroundColor = elementCustomization.buttonForeground(accentStyle: accentStyle, isPressed: isPressed, scheme: colorScheme)
        let fillFraction = max(0, min(1, value))

        return ZStack(alignment: normalizedSettings.orientation == .vertical ? .bottom : .leading) {
            GamepadFillShapeLayer(shape: Capsule(), fillStyle: fillStyle)
                .overlay(Capsule().stroke(strokeColor, lineWidth: isPressed ? 2 : 1))
                .shadow(
                    color: Color.black.opacity((isPressed ? 0.16 : 0.05) * elementCustomization.shadowStrength),
                    radius: (isPressed ? 4 : 2) * max(0.25, elementCustomization.shadowStrength),
                    y: (isPressed ? 3 : 2) * elementCustomization.shadowStrength
                )

            Capsule()
                .fill(foregroundColor.opacity(colorScheme == .dark ? 0.24 : 0.18))
                .frame(
                    width: normalizedSettings.orientation == .vertical ? size.width : max(4, size.width * fillFraction),
                    height: normalizedSettings.orientation == .vertical ? max(4, size.height * fillFraction) : size.height
                )
                .allowsHitTesting(false)

            if customization.showsButtonLabels {
                Text(label)
                    .geistTypography(size.height <= 44 ? .button12 : .button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(foregroundColor)
                    .padding(.horizontal, 8)
            }
        }
    }

    private func handleValueChanged(_ rawValue: CGFloat, isActive: Bool) {
        let normalizedSettings = settings.normalized
        let transformed = normalizedSettings.transformedValue(rawValue)
        value = transformed
        client.setGamepadTrigger(normalizedSettings.target, value: Double(transformed), isFinal: !isActive || transformed <= 0.001)

        guard normalizedSettings.sendsDigitalButton else { return }
        let shouldPress = transformed >= normalizedSettings.digitalThreshold
        if shouldPress != isDigitalPressed {
            isDigitalPressed = shouldPress
            client.setButton(mappedButton, pressed: shouldPress)
        }
        if !isActive, isDigitalPressed {
            isDigitalPressed = false
            client.setButton(mappedButton, pressed: false)
        }
    }
}

private struct GamepadTrackpad: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.keypadHapticsEnabled) private var isKeypadHapticsEnabled
    let label: String
    let size: CGSize
    let elementCustomization: GamepadButtonCustomization
    let settings: GamepadTrackpadSettings
    let customization: GamepadCustomization

    @State private var isActive = false
    @State private var touchCount = 0
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)

    private var normalizedSettings: GamepadTrackpadSettings {
        settings.normalized
    }

    var body: some View {
        let hitSize = CGSize(
            width: size.width + ControllerLayoutMetrics.buttonHitOutset * 2,
            height: size.height + ControllerLayoutMetrics.buttonHitOutset * 2
        )

        ZStack {
            trackpadSurface
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)

            TrackpadCaptureView(
                isTapToClickEnabled: normalizedSettings.tapToClick,
                isTwoFingerScrollEnabled: normalizedSettings.twoFingerScroll
            ) { delta in
                handleMove(delta)
            } onScroll: { delta in
                handleScroll(delta)
            } onTap: { fingerCount in
                handleTap(fingerCount: fingerCount)
            } onActiveChanged: { active, count in
                isActive = active
                touchCount = count
            }
            .frame(width: hitSize.width, height: hitSize.height)
        }
        .frame(width: hitSize.width, height: hitSize.height)
        .accessibilityLabel(label)
        .onAppear { prepareHapticIfNeeded() }
        .onChange(of: isKeypadHapticsEnabled) { _, isEnabled in
            if isEnabled { prepareHapticIfNeeded() }
        }
        .onDisappear {
            isActive = false
            touchCount = 0
        }
    }

    private var resolvedAccentStyle: GamepadAccentStyle {
        elementCustomization.accentStyle ?? customization.accentStyle
    }

    private var resolvedCornerRadii: GamepadCornerRadii {
        elementCustomization.resolvedCornerRadii(defaultRadius: GamepadButtonShapeStyle.roundedRectangle.defaultEditableCornerRadius(in: size))
    }

    private var trackpadSurface: some View {
        let fillStyle = elementCustomization.buttonFillStyle(accentStyle: resolvedAccentStyle, isPressed: isActive, scheme: colorScheme)
        let strokeColor = elementCustomization.buttonStroke(accentStyle: resolvedAccentStyle, isPressed: isActive, scheme: colorScheme)
        let foregroundColor = elementCustomization.buttonForeground(accentStyle: resolvedAccentStyle, isPressed: isActive, scheme: colorScheme)
        let shape = UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)

        return ZStack {
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: isActive ? 2 : 1))
                .shadow(
                    color: Color.black.opacity((isActive ? 0.16 : 0.05) * elementCustomization.shadowStrength),
                    radius: (isActive ? 4 : 2) * max(0.25, elementCustomization.shadowStrength),
                    y: (isActive ? 3 : 2) * elementCustomization.shadowStrength
                )

            RoundedRectangle(cornerRadius: max(8, min(size.width, size.height) * 0.08), style: .continuous)
                .stroke(foregroundColor.opacity(isActive ? 0.28 : 0.18), lineWidth: 1)
                .padding(max(8, min(size.width, size.height) * 0.08))

            VStack(spacing: max(4, size.height * 0.06)) {
                Image(systemName: touchCount >= 2 ? "hand.draw" : "cursorarrow")
                    .font(.system(size: max(18, min(size.width, size.height) * 0.20), weight: .semibold))
                    .foregroundStyle(foregroundColor.opacity(isActive ? 0.95 : 0.70))

                if customization.showsButtonLabels {
                    Text(label)
                        .geistTypography(size.width <= 112 ? .button12 : .button14)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(foregroundColor.opacity(0.94))
                        .padding(.horizontal, 8)
                }
            }

            HStack(spacing: 7) {
                Capsule().fill(foregroundColor.opacity(isActive ? 0.42 : 0.30))
                Capsule().fill(foregroundColor.opacity(touchCount >= 2 ? 0.42 : 0.16))
            }
            .frame(width: size.width * 0.32, height: max(4, size.height * 0.045))
            .offset(y: size.height * 0.37)
        }
        .scaleEffect(isActive ? 0.985 : 1)
        .animation(.interactiveSpring(response: 0.14, dampingFraction: 0.82), value: isActive)
        .animation(.interactiveSpring(response: 0.14, dampingFraction: 0.82), value: touchCount)
    }

    private func handleMove(_ delta: CGVector) {
        let settings = normalizedSettings
        client.sendPointerMove(
            deltaX: Double(delta.dx) * Double(settings.sensitivity),
            deltaY: Double(delta.dy) * Double(settings.sensitivity)
        )
    }

    private func handleScroll(_ delta: CGVector) {
        let settings = normalizedSettings
        let direction = settings.naturalScrolling ? 1.0 : -1.0
        client.sendPointerScroll(
            deltaX: Double(delta.dx) * Double(settings.scrollSensitivity) * direction,
            deltaY: Double(delta.dy) * Double(settings.scrollSensitivity) * direction
        )
    }

    private func handleTap(fingerCount: Int) {
        scheduleTapHaptic()
        client.sendPointerClick(fingerCount >= 2 ? .right : .left)
    }

    private func scheduleTapHaptic() {
        guard isKeypadHapticsEnabled else { return }
        let haptic = haptic
        DispatchQueue.main.async {
            haptic.impactOccurred(intensity: 0.35)
            haptic.prepare()
        }
    }

    private func prepareHapticIfNeeded() {
        guard isKeypadHapticsEnabled else { return }
        haptic.prepare()
    }
}

private struct GamepadButton: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.keypadHapticsEnabled) private var isKeypadHapticsEnabled
    let button: GameButton
    let size: CGSize
    var shape: GamepadButtonShapeStyle = .roundedRectangle
    var labelOverride: String? = nil
    var elementCustomization: GamepadButtonCustomization? = nil
    let customization: GamepadCustomization

    @State private var isPressed = false
    @State private var haptic = UIImpactFeedbackGenerator(style: .light)

    private var title: String {
        labelOverride ?? customization.visualLabel(for: button)
    }

    var body: some View {
        let hitSize = ControllerLayoutMetrics.hitSize(for: size)

        ZStack {
            ZStack {
                buttonBackground
                    .shadow(
                        color: Color.black.opacity((isPressed ? 0.16 : 0.04) * resolvedShadowStrength),
                        radius: (isPressed ? 2 : 1) * max(0.25, resolvedShadowStrength),
                        y: (isPressed ? 1 : 2) * resolvedShadowStrength
                    )

                if customization.showsButtonLabels {
                    Text(title)
                        .geistTypography(title.count <= 2 ? .heading32 : .button16)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(resolvedButtonCustomization.buttonForeground(accentStyle: resolvedAccentStyle, isPressed: isPressed, scheme: colorScheme))
                        .padding(.horizontal, 4)
                }
            }
            .scaleEffect(isPressed ? 0.96 : 1)
            .allowsHitTesting(false)
            .frame(width: size.width, height: size.height)

            TouchCaptureView(hitShape: resolvedShape) { pressed, isActive, pressIdentifier in
                handlePressEdge(pressed, isActive: isActive, pressIdentifier: pressIdentifier)
            }
            .frame(width: hitSize.width, height: hitSize.height)
        }
        .frame(width: hitSize.width, height: hitSize.height)
        .accessibilityLabel(button.displayName)
        .onAppear {
            prepareHapticIfNeeded()
        }
        .onChange(of: isKeypadHapticsEnabled) { _, isEnabled in
            if isEnabled {
                prepareHapticIfNeeded()
            }
        }
        .onDisappear {
            isPressed = false
        }
    }

    private var resolvedButtonCustomization: GamepadButtonCustomization {
        elementCustomization ?? customization.buttonCustomization(for: button)
    }

    private var resolvedShape: GamepadButtonShapeStyle {
        resolvedButtonCustomization.resolvedShape(defaultShape: shape)
    }

    private var resolvedAccentStyle: GamepadAccentStyle {
        resolvedButtonCustomization.accentStyle ?? customization.accentStyle
    }

    private var resolvedCornerRadii: GamepadCornerRadii {
        resolvedButtonCustomization.resolvedCornerRadii(defaultRadius: resolvedShape.defaultEditableCornerRadius(in: size))
    }

    private var resolvedShadowStrength: CGFloat {
        resolvedButtonCustomization.shadowStrength
    }

    @ViewBuilder
    private var buttonBackground: some View {
        let fillStyle = resolvedButtonCustomization.buttonFillStyle(accentStyle: resolvedAccentStyle, isPressed: isPressed, scheme: colorScheme)
        let strokeColor = resolvedButtonCustomization.buttonStroke(accentStyle: resolvedAccentStyle, isPressed: isPressed, scheme: colorScheme)
        let lineWidth: CGFloat = isPressed ? 2 : 1

        switch resolvedShape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            let shape = UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
        case .polygon:
            let shape = GamepadRegularPolygonButtonShape(sides: 3)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
        case .star:
            let shape = GamepadStarButtonShape(points: 5)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
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
            schedulePressHaptic()
        }
    }

    private func schedulePressHaptic() {
        guard isKeypadHapticsEnabled else { return }
        let haptic = haptic
        DispatchQueue.main.async {
            haptic.impactOccurred(intensity: 0.45)
            haptic.prepare()
        }
    }

    private func prepareHapticIfNeeded() {
        guard isKeypadHapticsEnabled else { return }
        haptic.prepare()
    }
}
