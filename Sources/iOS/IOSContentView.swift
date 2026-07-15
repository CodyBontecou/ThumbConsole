import SwiftUI
import UIKit
import CoreHaptics
import UniformTypeIdentifiers

struct IOSContentView: View {
    @EnvironmentObject private var client: ControllerClient
    @AppStorage("macHost") private var macHost = "192.168.0.113"
    @AppStorage("macPort") private var macPort = "8765"
    @AppStorage("pairingCode") private var pairingCode = ""
    @AppStorage("PocketPad.iOS.onboarding.completed.v1") private var hasCompletedOnboarding = false
    @State private var prefersConnectionView = true
    @State private var isShowingOnboarding = false

    private let defaultMacHost = "192.168.0.113"
    private let defaultMacPort = "8765"

    private var shouldShowControllerPad: Bool {
        client.isConnected || (client.canViewSavedKeypadOffline && !prefersConnectionView)
    }

    var body: some View {
        let isShowingControllerPad = shouldShowControllerPad

        ZStack {
            if isShowingControllerPad {
                ControllerPadView(
                    onShowConnectionPage: {
                        prefersConnectionView = true
                    },
                    onShowOnboarding: {
                        isShowingOnboarding = true
                    }
                )
                .ignoresSafeArea()
            } else {
                ConnectionView(
                    macHost: $macHost,
                    macPort: $macPort,
                    pairingCode: $pairingCode,
                    onShowSavedKeypad: {
                        prefersConnectionView = false
                    },
                    onShowOnboarding: {
                        isShowingOnboarding = true
                    }
                )
            }
        }
        .geistScreenBackground()
        .statusBarHidden(isShowingControllerPad)
        .persistentSystemOverlays(isShowingControllerPad ? .hidden : .automatic)
        .sheet(isPresented: $isShowingOnboarding) {
            IOSOnboardingView(
                onStartSmartConnect: {
                    client.startSmartConnect()
                },
                onComplete: {
                    completeOnboarding()
                }
            )
            .interactiveDismissDisabled(!hasCompletedOnboarding)
        }
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
            if hasCompletedOnboarding {
                client.startSmartConnect()
            } else {
                DispatchQueue.main.async {
                    isShowingOnboarding = true
                }
            }
        }
        .onChange(of: client.isConnected) { _, isConnected in
            if isConnected {
                prefersConnectionView = false
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        isShowingOnboarding = false
        client.startSmartConnect()
    }
}

private enum IOSKeypadSettings {
    static let hapticsEnabledDefaultsKey = "PocketPad.iOS.keypadHapticsEnabled.v1"
    static let hasOpenedKeypadDefaultsKey = "PocketPad.iOS.hasOpenedKeypad.v1"
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

private struct ConnectionView: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @Binding var macHost: String
    @Binding var macPort: String
    @Binding var pairingCode: String
    @AppStorage(IOSKeypadSettings.hapticsEnabledDefaultsKey) private var isKeypadHapticsEnabled = true
    let onShowSavedKeypad: () -> Void
    let onShowOnboarding: () -> Void

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
            Text("ThumbConsole")
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
                onShowOnboarding()
            } label: {
                Label("Setup Guide", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.tertiary, size: .medium)

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

                Text("Enter the code shown on ThumbConsole Mac.")
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
        guard let payload = PairingPayload.decode(from: text) else {
            qrScanError = "QR code not recognized. Scan the ThumbConsole code shown on your Mac."
            isShowingScanner = false
            return
        }

        pairingCode = payload.pairingCode ?? ""
        if let urlString = payload.urls.first {
            applyConnectionFields(from: urlString)
        }
        isShowingScanner = false
        client.connect(pairingPayload: payload)
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

private enum IOSOnboardingStep: String, CaseIterable, Identifiable, Hashable {
    case welcome
    case permissions
    case connect
    case keypad

    var id: Self { self }

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .permissions: "Permissions"
        case .connect: "Connect"
        case .keypad: "Use Keypads"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "iphone.gen3"
        case .permissions: "checkmark.shield.fill"
        case .connect: "macbook.and.iphone"
        case .keypad: "rectangle.grid.2x2"
        }
    }
}

private struct IOSOnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedStep: IOSOnboardingStep = .welcome

    let onStartSmartConnect: () -> Void
    let onComplete: () -> Void

    private var steps: [IOSOnboardingStep] { IOSOnboardingStep.allCases }
    private var selectedIndex: Int { steps.firstIndex(of: selectedStep) ?? 0 }
    private var isFirstStep: Bool { selectedIndex == 0 }
    private var isLastStep: Bool { selectedIndex == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.vertical, showsIndicators: false) {
                stepContent
                    .padding(.horizontal, Geist.Spacing.s6)
                    .padding(.vertical, Geist.Spacing.s6)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            footer
        }
        .geistScreenBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .center, spacing: Geist.Spacing.s3) {
                Image(systemName: selectedStep.systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .frame(width: 46, height: 46)
                    .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                            .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                    Text("Set up ThumbConsole")
                        .geistTypography(.heading24)
                        .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    Text("Pair this iPhone with ThumbConsole Mac and learn where keypad editing lives.")
                        .geistTypography(.copy14)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Geist.Spacing.s2)
            }

            stepDots
        }
        .padding(Geist.Spacing.s6)
        .background(Geist.color(.background100, scheme: colorScheme))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Geist.color(.grayAlpha400, scheme: colorScheme))
                .frame(height: 1)
        }
    }

    private var stepDots: some View {
        HStack(spacing: Geist.Spacing.s2) {
            ForEach(steps) { step in
                let isSelected = step == selectedStep
                Button {
                    selectedStep = step
                } label: {
                    HStack(spacing: Geist.Spacing.s1) {
                        Circle()
                            .fill(isSelected ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.grayAlpha600, scheme: colorScheme))
                            .frame(width: 8, height: 8)
                        if isSelected {
                            Text(step.title)
                                .geistTypography(.label12)
                                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                        }
                    }
                    .padding(.horizontal, Geist.Spacing.s2)
                    .frame(height: 28)
                    .background(isSelected ? Geist.color(.gray100, scheme: colorScheme) : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch selectedStep {
        case .welcome:
            welcomeStep
        case .permissions:
            permissionsStep
        case .connect:
            connectStep
        case .keypad:
            keypadStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                Text("Use your iPhone as the Mac keypad.")
                    .geistTypography(.heading32)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                Text("ThumbConsole sends presses from this screen to ThumbConsole Mac, where they become keyboard shortcuts, pointer actions, or gamepad output for the app you are using.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            IOSOnboardingCallout(
                title: "You will need the Mac app too",
                text: "Open ThumbConsole Mac on the same Wi‑Fi network, or keep Wi‑Fi/Bluetooth enabled nearby for offline peer-to-peer. The Mac app grants permissions, shows the QR code, and hosts the keypad editor.",
                systemImage: "macbook"
            )

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                IOSOnboardingInstructionCard(step: "1", title: "Open ThumbConsole Mac", text: "Leave the helper running while you use the phone keypad.")
                IOSOnboardingInstructionCard(step: "2", title: "Pair securely", text: "Use Smart Connect, scan the QR code, or type the local address and pairing code.")
                IOSOnboardingInstructionCard(step: "3", title: "Control the focused Mac app", text: "After pairing, focus Terminal, Cursor, a browser, or a game and press controls on this iPhone.")
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Allow the iPhone permissions when prompted.")
                    .geistTypography(.heading32)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text("ThumbConsole only needs local device discovery and QR scanning. Keyboard permissions are granted on the Mac, not on the iPhone.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                IOSOnboardingPermissionCard(
                    title: "Local Network",
                    text: "Allow this so Smart Connect can discover ThumbConsole Mac over Wi‑Fi or nearby peer-to-peer, and so manual WebSocket pairing works on your network.",
                    systemImage: "wifi"
                )
                IOSOnboardingPermissionCard(
                    title: "Camera",
                    text: "Allow camera access when you tap Scan Mac QR Code. ThumbConsole only uses the camera to read the pairing QR code.",
                    systemImage: "camera.viewfinder"
                )
            }

            Button {
                onStartSmartConnect()
            } label: {
                Label("Start Smart Connect", systemImage: "bolt.horizontal.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.primary, size: .large)

            IOSOnboardingCallout(
                title: "Mac permissions happen on the Mac",
                text: "If shortcuts do not fire, open ThumbConsole Mac and enable Accessibility in System Settings → Privacy & Security → Accessibility.",
                systemImage: "checkmark.shield.fill"
            )
        }
    }

    private var connectStep: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Pair with ThumbConsole Mac.")
                    .geistTypography(.heading32)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("Smart Connect is fastest after the first pair. QR and manual pairing are available any time from the connection screen.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                IOSOnboardingInstructionCard(step: "1", title: "Tap Smart Connect", text: "ThumbConsole looks for the Mac helper advertised on your local or nearby peer-to-peer network.")
                IOSOnboardingInstructionCard(step: "2", title: "If needed, scan the QR", text: "On the Mac Home screen, scan the QR card shown under Connect From iPhone.")
                IOSOnboardingInstructionCard(step: "3", title: "Enter the six-digit code", text: "Manual pairing asks you to type the code shown on ThumbConsole Mac. Smart Connect will remember this Mac after pairing.")
            }

            Button {
                onStartSmartConnect()
            } label: {
                Label("Try Smart Connect Now", systemImage: "bolt.horizontal.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.primary, size: .large)
        }
    }

    private var keypadStep: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("Use and switch keypad setups.")
                    .geistTypography(.heading32)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
                Text("The full keypad editor is on the Mac. This iPhone receives the saved setups, lets you switch between them, and can make small layout edits for freeform controls.")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                IOSOnboardingInstructionCard(step: "1", title: "Edit on Mac", text: "Open the Keypad section on ThumbConsole Mac to add controls, style them, and record shortcuts.")
                IOSOnboardingInstructionCard(step: "2", title: "Open the top bar", text: "Swipe down from the top edge if the keypad controls are hidden.")
                IOSOnboardingInstructionCard(step: "3", title: "Switch setups", text: "Use the Keypad setup menu to choose another synced setup, mark it as default, or export keypads as JSON.")
                IOSOnboardingInstructionCard(step: "4", title: "Adjust a freeform layout", text: "Tap the lock icon to unlock controls, then move, resize, rotate, or delete elements before locking again.")
            }

            Button {
                onComplete()
            } label: {
                Text("Finish Setup")
                    .frame(maxWidth: .infinity)
            }
            .geistButtonStyle(.primary, size: .large)
        }
    }

    private var footer: some View {
        HStack(spacing: Geist.Spacing.s3) {
            Button("Skip") { onComplete() }
                .geistButtonStyle(.tertiary)

            Spacer(minLength: Geist.Spacing.s3)

            Button("Back") { moveSelection(by: -1) }
                .geistButtonStyle(.secondary)
                .disabled(isFirstStep)

            Button(isLastStep ? "Done" : "Next") {
                if isLastStep {
                    onComplete()
                } else {
                    moveSelection(by: 1)
                }
            }
            .geistButtonStyle(.primary)
        }
        .padding(Geist.Spacing.s4)
        .background(Geist.color(.background100, scheme: colorScheme))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Geist.color(.grayAlpha400, scheme: colorScheme))
                .frame(height: 1)
        }
    }

    private func moveSelection(by offset: Int) {
        let nextIndex = min(max(selectedIndex + offset, 0), steps.count - 1)
        selectedStep = steps[nextIndex]
    }
}

private struct IOSOnboardingInstructionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let step: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s3) {
            Text(step)
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.background100, scheme: colorScheme))
                .frame(width: 28, height: 28)
                .background(Geist.color(.gray1000, scheme: colorScheme), in: Circle())

            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(title)
                    .geistTypography(.heading16)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(text)
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct IOSOnboardingPermissionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s3) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))
                .frame(width: 32, height: 32)
                .background(Geist.color(.blue100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(title)
                    .geistTypography(.heading16)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(text)
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct IOSOnboardingCallout: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let text: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
                Text(title)
                    .geistTypography(.heading14)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text(text)
                    .geistTypography(.copy13)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))
        }
        .padding(Geist.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Geist.color(.blue100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.md, style: .continuous)
                .stroke(Geist.color(.blue400, scheme: colorScheme), lineWidth: 1)
        )
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
    let customization: GamepadCustomization
    let onShowGuide: (() -> Void)?
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

            if let onShowGuide {
                Divider()

                Button {
                    onShowGuide()
                } label: {
                    Label("Setup Guide", systemImage: "questionmark.circle")
                }
            }

            Divider()

            Button(role: .destructive) {
                onReleaseAllInputs()
            } label: {
                Label("Release All Keys", systemImage: "keyboard.chevron.compact.down")
            }
        } label: {
            GamepadControlBarItemIcon(
                customization: customization,
                item: .settings,
                defaultSystemImage: "gearshape.fill",
                fontSize: 13,
                frameWidth: 28
            )
        }
        .gamepadControlBarButtonStyle(customization: customization, item: .settings)
        .accessibilityLabel("Keypad settings")
        .accessibilityHint("Opens settings for keypad appearance, feedback, and input reset.")
    }
}

private struct ControllerPadView: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(IOSKeypadSettings.hapticsEnabledDefaultsKey) private var isKeypadHapticsEnabled = true
    @AppStorage(IOSKeypadSettings.hasOpenedKeypadDefaultsKey) private var hasOpenedKeypad = false
    @State private var isTopBarVisible = true
    @State private var isShowingFirstOpenTopBar = false
    @State private var isExportingKeypadConfiguration = false
    @State private var isEditingKeypadLayout = false

    let onShowConnectionPage: (() -> Void)?
    let onShowOnboarding: (() -> Void)?

    init(
        onShowConnectionPage: (() -> Void)? = nil,
        onShowOnboarding: (() -> Void)? = nil
    ) {
        self.onShowConnectionPage = onShowConnectionPage
        self.onShowOnboarding = onShowOnboarding
    }

    var body: some View {
        GeometryReader { proxy in
            let orientation = GamepadControllerPresentationRouting.orientation(for: proxy.size)
            let context = ControllerPadRenderContext(
                size: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                client: client,
                orientation: orientation,
                isEditingLayout: isEditingKeypadLayout,
                systemColorScheme: colorScheme
            )

            ControllerPadGeometryScene(
                context: context,
                isTopBarVisible: $isTopBarVisible,
                isEditingLayout: $isEditingKeypadLayout,
                isExportingKeypadConfiguration: $isExportingKeypadConfiguration,
                isKeypadHapticsEnabled: $isKeypadHapticsEnabled,
                onShowConnectionPage: onShowConnectionPage,
                onShowOnboarding: onShowOnboarding
            )
        }
        .environment(\.keypadHapticsEnabled, isKeypadHapticsEnabled)
        .onAppear {
            applyInitialTopBarVisibility()
        }
        .onChange(of: client.isConnected) { _, isConnected in
            guard !isShowingFirstOpenTopBar else { return }
            isTopBarVisible = !isConnected
        }
        .onChange(of: isTopBarVisible) { _, isVisible in
            if !isVisible {
                isShowingFirstOpenTopBar = false
            }
        }
        .onChange(of: client.gamepadCustomization) { _, _ in
            guard !isEditingKeypadLayout else { return }
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
        }
        .onChange(of: client.gamepadProfiles) { _, _ in
            guard !isEditingKeypadLayout else { return }
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
        }
        .fileExporter(
            isPresented: $isExportingKeypadConfiguration,
            document: keypadExportDocument,
            contentType: .json,
            defaultFilename: keypadExportFilename
        ) { _ in }
    }

    private func applyInitialTopBarVisibility() {
        // Reveal the slide-down controls on a user's first keypad session so
        // profile switching, settings, and Home are discoverable.
        if hasOpenedKeypad {
            isShowingFirstOpenTopBar = false
            isTopBarVisible = !client.isConnected
        } else {
            hasOpenedKeypad = true
            isShowingFirstOpenTopBar = true
            isTopBarVisible = true
        }
    }

    private var keypadExportDocument: ThumbConsoleKeypadConfigurationJSONDocument {
        ThumbConsoleKeypadConfigurationJSONDocument(
            export: ThumbConsoleKeypadConfigurationExport(
                profiles: client.gamepadProfiles,
                activeProfileID: client.selectedGamepadProfileID,
                defaultProfileID: client.defaultGamepadProfileID
            )
        )
    }

    private var keypadExportFilename: String {
        ThumbConsoleKeypadConfigurationExport.suggestedFilename(activeProfileName: client.selectedGamepadProfileName)
    }

}

@MainActor
private final class ControllerPadCustomizationSnapshot {
    let value: GamepadCustomization

    init(client: ControllerClient, orientation: GamepadEditorDeviceOrientation) {
        if let selectedProfile = client.selectedGamepadProfile {
            value = selectedProfile.customization(for: orientation)
        } else {
            value = client.gamepadCustomization
        }
    }
}

/// Immutable per-render snapshot. Child views carry this reference instead of
/// copying the large `GamepadCustomization` value through every routing layer.
@MainActor
private final class ControllerPadRenderContext {
    let size: CGSize
    let safeAreaInsets: EdgeInsets
    let orientation: GamepadEditorDeviceOrientation
    let colorScheme: ColorScheme
    let layoutRoute: GamepadControllerLayoutRoute
    private let customizationSnapshot: ControllerPadCustomizationSnapshot

    var customization: GamepadCustomization { customizationSnapshot.value }

    var isLandscape: Bool { orientation == .landscape }

    init(
        size: CGSize,
        safeAreaInsets: EdgeInsets,
        client: ControllerClient,
        orientation: GamepadEditorDeviceOrientation,
        isEditingLayout: Bool,
        systemColorScheme: ColorScheme
    ) {
        let customizationSnapshot = ControllerPadCustomizationSnapshot(
            client: client,
            orientation: orientation
        )
        self.size = size
        self.safeAreaInsets = safeAreaInsets
        self.orientation = orientation
        self.customizationSnapshot = customizationSnapshot
        self.colorScheme = customizationSnapshot.value.resolvedColorScheme(system: systemColorScheme)
        self.layoutRoute = GamepadControllerPresentationRouting.layoutRoute(
            orientation: orientation,
            isEditingLayout: isEditingLayout,
            usesFreeformLayout: customizationSnapshot.value.usesFreeformLayout
        )
    }
}

/// A nominal boundary around the controller's geometry-dependent scene.
private struct ControllerPadGeometryScene: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    @Binding var isTopBarVisible: Bool
    @Binding var isEditingLayout: Bool
    @Binding var isExportingKeypadConfiguration: Bool
    @Binding var isKeypadHapticsEnabled: Bool
    let onShowConnectionPage: (() -> Void)?
    let onShowOnboarding: (() -> Void)?

    var body: some View {
        ZStack(alignment: .top) {
            ControllerPadLayoutRouter(context: context, isEditingLayout: isEditingLayout)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ControllerTopBarDrawer(
                isVisible: $isTopBarVisible,
                safeAreaInsets: context.safeAreaInsets,
                isLandscape: context.isLandscape,
                activationFrame: context.customization.topBarActivationFrame(in: context.size),
                collapsedTitle: ""
            ) {
                ControllerPadTopBar(
                    context: context,
                    isEditingLayout: $isEditingLayout,
                    isExportingKeypadConfiguration: $isExportingKeypadConfiguration,
                    isKeypadHapticsEnabled: $isKeypadHapticsEnabled,
                    onShowConnectionPage: onShowConnectionPage,
                    onShowOnboarding: onShowOnboarding
                )
            }
        }
        .background {
            ControllerPadBackground(context: context)
        }
        .environment(\.colorScheme, context.colorScheme)
        .frame(width: context.size.width, height: context.size.height)
        .onChange(of: context.orientation) { _, _ in
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
        }
    }
}

private struct ControllerPadBackground: View {
    let context: ControllerPadRenderContext

    var body: some View {
        GamepadFillShapeLayer(
            shape: Rectangle(),
            fillStyle: context.customization.keypadBackgroundFillStyle(scheme: context.colorScheme)
        )
        .ignoresSafeArea()
    }
}

/// The only orientation/style type-erasure boundary in the controller canvas.
private struct ControllerPadLayoutRouter: View {
    let context: ControllerPadRenderContext
    let isEditingLayout: Bool

    var body: AnyView {
        switch context.layoutRoute {
        case .standard(.landscape):
            return AnyView(ControllerPadStandardLandscapeLayout(context: context))
        case .standard(.portrait):
            return AnyView(ControllerPadStandardPortraitLayout(context: context))
        case .freeform:
            return AnyView(
                ControllerPadFreeformLayout(
                    context: context,
                    isEditingLayout: isEditingLayout
                )
            )
        }
    }
}

private struct ControllerPadFreeformLayout: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    let isEditingLayout: Bool

    var body: some View {
        GamepadFreeformControllerCanvas(
            context: context,
            isEditingLayout: isEditingLayout
        ) { nextCustomization, isFinal in
            client.updateSelectedKeypadLayout(
                nextCustomization,
                orientation: context.orientation,
                sendsToMac: isFinal
            )
        }
        .padding(
            .leading,
            max(
                context.isLandscape ? Geist.Spacing.s3 : Geist.Spacing.s4,
                context.safeAreaInsets.leading + Geist.Spacing.s2
            )
        )
        .padding(
            .trailing,
            max(
                context.isLandscape ? Geist.Spacing.s3 : Geist.Spacing.s4,
                context.safeAreaInsets.trailing + Geist.Spacing.s2
            )
        )
        .padding(.bottom, max(Geist.Spacing.s4, context.safeAreaInsets.bottom + Geist.Spacing.s2))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if !isEditingLayout {
                TouchRoutingView()
            }
        }
    }
}

private struct ControllerPadStandardLandscapeLayout: View {
    let context: ControllerPadRenderContext

    var body: some View {
        let metrics = LandscapeControllerMetrics(
            size: context.size,
            safeAreaInsets: context.safeAreaInsets,
            controlScale: context.customization.controlScale
        )
        let slots = GamepadControllerPresentationRouting.standardSlots(
            orientation: .landscape,
            layoutMode: context.customization.layoutMode
        )

        HStack(alignment: .center, spacing: metrics.controlSpacing) {
            ForEach(slots) { slot in
                ControllerPadLandscapeSlotRouter(
                    context: context,
                    metrics: metrics,
                    slot: slot
                )
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

private struct ControllerPadLandscapeSlotRouter: View {
    let context: ControllerPadRenderContext
    let metrics: LandscapeControllerMetrics
    let slot: GamepadStandardLayoutSlot

    var body: AnyView {
        switch slot {
        case .control(.dPad):
            return AnyView(ControllerPadLandscapeDPad(context: context, metrics: metrics))
        case .control(.utilityButtons):
            return AnyView(ControllerPadLandscapeUtilityButtons(context: context, metrics: metrics))
        case .control(.actionButtons):
            return AnyView(ControllerPadLandscapeActionButtons(context: context, metrics: metrics))
        case .flexibleSpace:
            return AnyView(Spacer(minLength: metrics.spacerMinLength))
        }
    }
}

private struct ControllerPadLandscapeDPad: View {
    let context: ControllerPadRenderContext
    let metrics: LandscapeControllerMetrics

    var body: some View {
        DPadView(buttonSize: metrics.dPadButtonSize, customization: context.customization)
            .frame(width: metrics.dPadHitSize.width * 3, height: metrics.dPadHitSize.height * 3)
            .fixedSize()
    }
}

private struct ControllerPadLandscapeActionButtons: View {
    let context: ControllerPadRenderContext
    let metrics: LandscapeControllerMetrics

    var body: some View {
        ActionButtonsView(buttonSize: metrics.actionButtonSize, customization: context.customization)
            .frame(width: metrics.actionHitSize.width * 2, height: metrics.actionHitSize.height * 2)
            .fixedSize()
    }
}

private struct ControllerPadLandscapeUtilityButtons: View {
    let context: ControllerPadRenderContext
    let metrics: LandscapeControllerMetrics

    var body: some View {
        ControllerPadUtilityButtons(
            context: context,
            mapButtonSize: metrics.mapButtonSize,
            pauseButtonSize: metrics.pauseButtonSize,
            spacing: metrics.utilitySpacing
        )
        .frame(width: metrics.utilityHitWidth, height: metrics.utilityHitHeight)
        .fixedSize()
        .layoutPriority(1)
    }
}

private struct ControllerPadStandardPortraitLayout: View {
    let context: ControllerPadRenderContext

    var body: some View {
        let metrics = PortraitControllerMetrics(
            size: context.size,
            safeAreaInsets: context.safeAreaInsets,
            controlScale: context.customization.controlScale
        )
        let slots = GamepadControllerPresentationRouting.standardSlots(
            orientation: .portrait,
            layoutMode: context.customization.layoutMode
        )

        VStack(spacing: Geist.Spacing.s4) {
            ForEach(slots) { slot in
                ControllerPadPortraitSlotRouter(
                    context: context,
                    metrics: metrics,
                    slot: slot
                )
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

private struct ControllerPadPortraitSlotRouter: View {
    let context: ControllerPadRenderContext
    let metrics: PortraitControllerMetrics
    let slot: GamepadStandardLayoutSlot

    var body: AnyView {
        switch slot {
        case .control(.dPad):
            return AnyView(ControllerPadPortraitDPad(context: context, metrics: metrics))
        case .control(.utilityButtons):
            return AnyView(ControllerPadPortraitUtilityButtons(context: context, metrics: metrics))
        case .control(.actionButtons):
            return AnyView(ControllerPadPortraitActionButtons(context: context, metrics: metrics))
        case .flexibleSpace:
            return AnyView(Spacer(minLength: Geist.Spacing.s2))
        }
    }
}

private struct ControllerPadPortraitDPad: View {
    let context: ControllerPadRenderContext
    let metrics: PortraitControllerMetrics

    var body: some View {
        DPadView(buttonSize: metrics.dPadButtonSize, customization: context.customization)
            .frame(width: metrics.dPadHitSize.width * 3, height: metrics.dPadHitSize.height * 3)
    }
}

private struct ControllerPadPortraitActionButtons: View {
    let context: ControllerPadRenderContext
    let metrics: PortraitControllerMetrics

    var body: some View {
        ActionButtonsView(buttonSize: metrics.actionButtonSize, customization: context.customization)
            .frame(width: metrics.actionHitSize.width * 2, height: metrics.actionHitSize.height * 2)
    }
}

private struct ControllerPadPortraitUtilityButtons: View {
    let context: ControllerPadRenderContext
    let metrics: PortraitControllerMetrics

    var body: some View {
        ControllerPadUtilityButtons(
            context: context,
            mapButtonSize: metrics.mapButtonSize,
            pauseButtonSize: metrics.pauseButtonSize,
            spacing: Geist.Spacing.s4
        )
    }
}

private struct ControllerPadUtilityButtons: View {
    let context: ControllerPadRenderContext
    let mapButtonSize: CGSize
    let pauseButtonSize: CGSize
    let spacing: CGFloat

    var body: some View {
        HStack(spacing: spacing) {
            GamepadButton(
                button: .map,
                size: mapButtonSize,
                shape: .capsule,
                customization: context.customization
            )
            GamepadButton(
                button: .pause,
                size: pauseButtonSize,
                shape: .capsule,
                customization: context.customization
            )
        }
    }
}

private struct ControllerPadTopBar: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    @Binding var isEditingLayout: Bool
    @Binding var isExportingKeypadConfiguration: Bool
    @Binding var isKeypadHapticsEnabled: Bool
    let onShowConnectionPage: (() -> Void)?
    let onShowOnboarding: (() -> Void)?

    var body: some View {
        GamepadControlBarLayout(
            items: visibleItems,
            isLandscape: context.isLandscape
        ) { item, isCompact in
            ControllerPadTopBarItemRouter(
                context: context,
                item: item,
                isCompact: isCompact,
                isEditingLayout: $isEditingLayout,
                isExportingKeypadConfiguration: $isExportingKeypadConfiguration,
                isKeypadHapticsEnabled: $isKeypadHapticsEnabled,
                onShowConnectionPage: onShowConnectionPage,
                onShowOnboarding: onShowOnboarding
            )
        }
    }

    private var visibleItems: [GamepadControlBarItem] {
        let items = context.customization.normalized.controlBarItems
        let hiddenItems = Set(items.filter {
            context.customization.controlBarItemCustomization(for: $0).isHidden
        })
        return GamepadControllerPresentationRouting.visibleControlBarItems(
            items,
            hiddenItems: hiddenItems,
            hasProfiles: !client.gamepadProfiles.isEmpty,
            hasLaunchTarget: client.selectedGamepadProfile?.launchTarget != nil
        )
    }
}

/// Closed leaf router: each branch constructs one nominal item view.
private struct ControllerPadTopBarItemRouter: View {
    let context: ControllerPadRenderContext
    let item: GamepadControlBarItem
    let isCompact: Bool
    @Binding var isEditingLayout: Bool
    @Binding var isExportingKeypadConfiguration: Bool
    @Binding var isKeypadHapticsEnabled: Bool
    let onShowConnectionPage: (() -> Void)?
    let onShowOnboarding: (() -> Void)?

    var body: AnyView {
        switch item {
        case .connectionStatus:
            return AnyView(ControllerPadStatusItem(context: context))
        case .profileMenu:
            return AnyView(
                ControllerPadProfileMenuItem(
                    context: context,
                    isCompact: isCompact,
                    isExportingKeypadConfiguration: $isExportingKeypadConfiguration
                )
            )
        case .launchTarget:
            return AnyView(ControllerPadLaunchTargetItem(context: context, isCompact: isCompact))
        case .spacer:
            return AnyView(ControllerPadSpacerItem(context: context, isCompact: isCompact))
        case .editLayout:
            return AnyView(
                ControllerPadEditLayoutItem(
                    context: context,
                    isEditingLayout: $isEditingLayout
                )
            )
        case .settings:
            return AnyView(
                ControllerPadSettingsItem(
                    context: context,
                    isKeypadHapticsEnabled: $isKeypadHapticsEnabled,
                    onShowOnboarding: onShowOnboarding
                )
            )
        case .home:
            return AnyView(
                ControllerPadHomeItem(
                    context: context,
                    onShowConnectionPage: onShowConnectionPage
                )
            )
        case .connectionAction:
            return AnyView(
                ControllerPadConnectionItem(
                    context: context,
                    isCompact: isCompact,
                    onShowConnectionPage: onShowConnectionPage
                )
            )
        }
    }
}

private struct ControllerPadStatusItem: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext

    var body: some View {
        GamepadControlBarStatusPill(
            customization: context.customization,
            title: title,
            systemImage: systemImage,
            tone: tone
        )
    }

    private var title: String {
        switch client.state {
        case .connected: "Connected"
        case .connecting: "Connecting…"
        case .pairingCodeRequired: "Pairing Needed"
        case .failed, .disconnected: "Saved Keypad"
        }
    }

    private var systemImage: String {
        switch client.state {
        case .connected: "wifi"
        case .connecting: "arrow.triangle.2.circlepath"
        case .pairingCodeRequired: "key.fill"
        case .failed, .disconnected: "rectangle.grid.2x2"
        }
    }

    private var tone: GeistInterfaceTone {
        switch client.state {
        case .connected: .success
        case .connecting, .pairingCodeRequired: .warning
        case .failed, .disconnected: .neutral
        }
    }
}

private struct ControllerPadProfileMenuItem: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    let isCompact: Bool
    @Binding var isExportingKeypadConfiguration: Bool

    var body: some View {
        Menu {
            ForEach(client.gamepadProfiles) { profile in
                Button {
                    client.selectGamepadProfile(profile.id)
                } label: {
                    Label(profile.name, systemImage: profileSystemImage(profile))
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
                isExportingKeypadConfiguration = true
            } label: {
                Label("Export Keypads as JSON", systemImage: "square.and.arrow.up")
            }
        } label: {
            ControllerPadProfileMenuLabelRouter(context: context, isCompact: isCompact)
        }
        .gamepadControlBarButtonStyle(customization: context.customization, item: .profileMenu)
        .accessibilityLabel(isCompact ? "Keypad setup: \(client.selectedGamepadProfileName)" : "Keypad setup")
    }

    private func profileSystemImage(_ profile: GamepadConfigurationProfile) -> String {
        if profile.id == client.selectedGamepadProfileID { return "checkmark.circle.fill" }
        if profile.id == client.defaultGamepadProfileID { return "star.fill" }
        return profile.launchTarget != nil ? "app.badge.fill" : "rectangle.grid.2x2"
    }
}

private struct ControllerPadProfileMenuLabelRouter: View {
    let context: ControllerPadRenderContext
    let isCompact: Bool

    var body: AnyView {
        if isCompact {
            return AnyView(ControllerPadCompactProfileMenuLabel(context: context))
        }
        return AnyView(ControllerPadExpandedProfileMenuLabel(context: context))
    }
}

private struct ControllerPadCompactProfileMenuLabel: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext

    var body: some View {
        GamepadControlBarItemIcon(
            customization: context.customization,
            item: .profileMenu,
            defaultSystemImage: client.isSelectedGamepadProfileDefault ? "star.fill" : "rectangle.grid.2x2",
            fontSize: 13,
            frameWidth: 28
        )
    }
}

private struct ControllerPadExpandedProfileMenuLabel: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext

    var body: some View {
        HStack(spacing: Geist.Spacing.s1) {
            GamepadControlBarItemIcon(
                customization: context.customization,
                item: .profileMenu,
                defaultSystemImage: client.isSelectedGamepadProfileDefault ? "star.fill" : "rectangle.grid.2x2",
                fontSize: 11
            )
            Text(client.selectedGamepadProfileName)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: 160)
    }
}

private struct ControllerPadLaunchTargetItem: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    let isCompact: Bool

    var body: some View {
        Button {
            client.launchSelectedProfileTarget()
        } label: {
            ControllerPadLaunchTargetLabelRouter(context: context, isCompact: isCompact)
        }
        .gamepadControlBarButtonStyle(customization: context.customization, item: .launchTarget)
        .disabled(!client.isConnected)
        .accessibilityLabel("Launch \(client.selectedGamepadProfile?.launchTarget?.displayName ?? "attached application")")
        .accessibilityHint("Asks the paired Mac to open the application attached to this keypad setup.")
    }
}

private struct ControllerPadLaunchTargetLabelRouter: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    let isCompact: Bool

    var body: AnyView {
        let size: CGFloat = isCompact ? 18 : 20
        if context.customization.controlBarItemCustomization(for: .launchTarget).icon != nil {
            return AnyView(
                ControllerPadConfiguredLaunchTargetLabel(context: context, size: size)
            )
        }
        if let launchTarget = client.selectedGamepadProfile?.launchTarget {
            return AnyView(
                ControllerPadApplicationLaunchTargetLabel(launchTarget: launchTarget, size: size)
            )
        }
        return AnyView(ControllerPadFallbackLaunchTargetLabel(context: context))
    }
}

private struct ControllerPadConfiguredLaunchTargetLabel: View {
    let context: ControllerPadRenderContext
    let size: CGFloat

    var body: some View {
        GamepadControlBarItemIcon(
            customization: context.customization,
            item: .launchTarget,
            defaultSystemImage: "app.badge.fill",
            fontSize: size,
            frameWidth: 28
        )
    }
}

private struct ControllerPadFallbackLaunchTargetLabel: View {
    let context: ControllerPadRenderContext

    var body: some View {
        GamepadControlBarItemIcon(
            customization: context.customization,
            item: .launchTarget,
            defaultSystemImage: "app.badge.fill",
            fontSize: 13,
            frameWidth: 28
        )
    }
}

private struct ControllerPadApplicationLaunchTargetLabel: View {
    let launchTarget: GamepadProfileLaunchTarget
    let size: CGFloat

    var body: some View {
        ControllerPadLaunchTargetIconRouter(launchTarget: launchTarget, size: size)
            .frame(width: 28, height: 28)
    }
}

private struct ControllerPadLaunchTargetIconRouter: View {
    let launchTarget: GamepadProfileLaunchTarget
    let size: CGFloat

    var body: AnyView {
        if let data = launchTarget.iconPNGData, let image = UIImage(data: data) {
            return AnyView(ControllerPadLaunchTargetImage(image: image, size: size))
        }
        return AnyView(ControllerPadLaunchTargetSystemImage(size: size))
    }
}

private struct ControllerPadLaunchTargetImage: View {
    let image: UIImage
    let size: CGFloat

    var body: some View {
        Image(uiImage: image)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: max(4, size * 0.22), style: .continuous))
    }
}

private struct ControllerPadLaunchTargetSystemImage: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "app.badge.fill")
            .font(.system(size: size, weight: .semibold))
            .frame(width: size, height: size)
    }
}

private struct ControllerPadSpacerItem: View {
    let context: ControllerPadRenderContext
    let isCompact: Bool

    var body: some View {
        Spacer(
            minLength: (isCompact ? 2 : Geist.Spacing.s2)
                * context.customization.controlBarItemCustomization(for: .spacer).widthScale
        )
    }
}

private struct ControllerPadEditLayoutItem: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    @Binding var isEditingLayout: Bool

    var body: some View {
        Button {
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                isEditingLayout.toggle()
            }
        } label: {
            GamepadControlBarItemIcon(
                customization: context.customization,
                item: .editLayout,
                defaultSystemImage: isEditingLayout ? "lock.open.fill" : "lock.fill",
                fontSize: 13,
                frameWidth: 28
            )
        }
        .gamepadControlBarButtonStyle(
            customization: context.customization,
            item: .editLayout,
            variant: isEditingLayout ? .primary : .secondary
        )
        .accessibilityLabel(isEditingLayout ? "Lock keypad layout" : "Unlock keypad layout")
        .accessibilityHint(isEditingLayout ? "Stops editing controls and keeps the saved layout." : "Lets you move, resize, rotate, or delete keypad elements.")
    }
}

private struct ControllerPadSettingsItem: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    @Binding var isKeypadHapticsEnabled: Bool
    let onShowOnboarding: (() -> Void)?

    var body: some View {
        KeypadSettingsMenu(
            isHapticFeedbackEnabled: $isKeypadHapticsEnabled,
            colorSchemePreference: colorSchemePreference,
            customization: context.customization,
            onShowGuide: onShowOnboarding
        ) {
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
        }
    }

    private var colorSchemePreference: Binding<GamepadColorSchemePreference> {
        Binding(
            get: { client.gamepadCustomization.colorSchemePreference },
            set: { client.setKeypadColorSchemePreference($0) }
        )
    }
}

private struct ControllerPadHomeItem: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    let onShowConnectionPage: (() -> Void)?

    var body: some View {
        Button {
            if client.isConnected {
                client.disconnect(sendReleaseAll: true)
            }
            onShowConnectionPage?()
        } label: {
            GamepadControlBarItemIcon(
                customization: context.customization,
                item: .home,
                defaultSystemImage: "house.fill",
                fontSize: 13,
                frameWidth: 28
            )
        }
        .gamepadControlBarButtonStyle(customization: context.customization, item: .home)
        .disabled(onShowConnectionPage == nil)
        .accessibilityLabel("Home")
        .accessibilityHint("Returns to the connection page.")
    }
}

private enum ControllerPadConnectionPresentation {
    case connect
    case disconnect

    var title: String {
        switch self {
        case .connect: "Connect Mac"
        case .disconnect: "Disconnect"
        }
    }

    var systemImage: String {
        switch self {
        case .connect: "link"
        case .disconnect: "wifi.slash"
        }
    }
}

private struct ControllerPadConnectionItem: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    let isCompact: Bool
    let onShowConnectionPage: (() -> Void)?

    var body: AnyView {
        if client.isConnected {
            return AnyView(
                ControllerPadDisconnectItem(context: context, isCompact: isCompact)
            )
        }
        return AnyView(
            ControllerPadConnectItem(
                context: context,
                isCompact: isCompact,
                onShowConnectionPage: onShowConnectionPage
            )
        )
    }
}

private struct ControllerPadDisconnectItem: View {
    @EnvironmentObject private var client: ControllerClient
    let context: ControllerPadRenderContext
    let isCompact: Bool

    var body: some View {
        Button {
            client.disconnect(sendReleaseAll: true)
        } label: {
            ControllerPadConnectionLabelRouter(
                context: context,
                presentation: .disconnect,
                isCompact: isCompact
            )
        }
        .gamepadControlBarButtonStyle(
            customization: context.customization,
            item: .connectionAction,
            variant: .error
        )
        .accessibilityLabel("Disconnect")
    }
}

private struct ControllerPadConnectItem: View {
    let context: ControllerPadRenderContext
    let isCompact: Bool
    let onShowConnectionPage: (() -> Void)?

    var body: some View {
        Button {
            onShowConnectionPage?()
        } label: {
            ControllerPadConnectionLabelRouter(
                context: context,
                presentation: .connect,
                isCompact: isCompact
            )
        }
        .gamepadControlBarButtonStyle(customization: context.customization, item: .connectionAction)
        .disabled(onShowConnectionPage == nil)
        .accessibilityLabel("Connect Mac")
    }
}

private struct ControllerPadConnectionLabelRouter: View {
    let context: ControllerPadRenderContext
    let presentation: ControllerPadConnectionPresentation
    let isCompact: Bool

    var body: AnyView {
        if isCompact {
            return AnyView(
                ControllerPadCompactConnectionLabel(
                    context: context,
                    presentation: presentation
                )
            )
        }
        if context.customization.controlBarItemCustomization(for: .connectionAction).icon != nil {
            return AnyView(
                ControllerPadExpandedConnectionLabel(
                    context: context,
                    presentation: presentation
                )
            )
        }
        return AnyView(ControllerPadTextConnectionLabel(title: presentation.title))
    }
}

private struct ControllerPadCompactConnectionLabel: View {
    let context: ControllerPadRenderContext
    let presentation: ControllerPadConnectionPresentation

    var body: some View {
        GamepadControlBarItemIcon(
            customization: context.customization,
            item: .connectionAction,
            defaultSystemImage: presentation.systemImage,
            fontSize: 13,
            frameWidth: 28
        )
    }
}

private struct ControllerPadExpandedConnectionLabel: View {
    let context: ControllerPadRenderContext
    let presentation: ControllerPadConnectionPresentation

    var body: some View {
        HStack(spacing: Geist.Spacing.s1) {
            GamepadControlBarItemIcon(
                customization: context.customization,
                item: .connectionAction,
                defaultSystemImage: presentation.systemImage,
                fontSize: 13
            )
            Text(presentation.title)
        }
    }
}

private struct ControllerPadTextConnectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
    }
}

private struct ControllerTopBarDrawer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isVisible: Bool
    let safeAreaInsets: EdgeInsets
    let isLandscape: Bool
    let activationFrame: CGRect
    let collapsedTitle: String
    let content: Content

    init(
        isVisible: Binding<Bool>,
        safeAreaInsets: EdgeInsets,
        isLandscape: Bool,
        activationFrame: CGRect = .null,
        collapsedTitle: String = "Controls",
        @ViewBuilder content: () -> Content
    ) {
        self._isVisible = isVisible
        self.safeAreaInsets = safeAreaInsets
        self.isLandscape = isLandscape
        self.activationFrame = activationFrame
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
            ControllerTopBarSwipeBridge(isVisible: $isVisible, animation: drawerAnimation, activationFrame: activationFrame)
        }
        .animation(drawerAnimation, value: isVisible)
        .animation(drawerAnimation, value: activationFrame)
        .zIndex(10)
    }

    private var revealHandle: some View {
        let visualOpacity = isVisible ? 1.0 : 0.0

        return VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Geist.color(.grayAlpha700, scheme: colorScheme).opacity(visualOpacity))
                .frame(width: isVisible ? 36 : 56, height: 5)

            if !isVisible && !collapsedTitle.isEmpty {
                Text(collapsedTitle)
                    .geistTypography(.label12)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme).opacity(visualOpacity))
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, isVisible ? Geist.Spacing.s3 : Geist.Spacing.s4)
        .padding(.vertical, Geist.Spacing.s2)
        .background(
            Capsule()
                .fill(Geist.color(.background100, scheme: colorScheme).opacity(isVisible ? 0.74 : 0))
        )
        .overlay(
            Capsule()
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                .opacity(0)
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
    let activationFrame: CGRect

    func makeCoordinator() -> Coordinator {
        Coordinator(isVisible: $isVisible, animation: animation, activationFrame: activationFrame)
    }

    func makeUIView(context: Context) -> ActivationView {
        let view = ActivationView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: ActivationView, context: Context) {
        context.coordinator.isVisible = $isVisible
        context.coordinator.animation = animation
        context.coordinator.configuredActivationFrame = activationFrame
        uiView.updateActivationFrame()
        uiView.scheduleActivationFrameUpdate()
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
            scheduleActivationFrameUpdate()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateActivationFrame()
            scheduleActivationFrameUpdate()
        }

        func updateActivationFrame() {
            guard let window else {
                coordinator?.activationFrame = .null
                return
            }

            coordinator?.activationFrame = convert(bounds, to: window)
        }

        func scheduleActivationFrameUpdate() {
            DispatchQueue.main.async { [weak self] in
                self?.updateActivationFrame()
            }
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isVisible: Binding<Bool>
        var animation: Animation
        var configuredActivationFrame: CGRect
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

        init(isVisible: Binding<Bool>, animation: Animation, activationFrame: CGRect) {
            self.isVisible = isVisible
            self.animation = animation
            self.configuredActivationFrame = activationFrame
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
                  let hostView = gestureRecognizer.view
            else { return false }

            let location = touch.location(in: hostView)

            if isVisible.wrappedValue {
                let paddedFrame = activationFrame.insetBy(dx: -24, dy: -24)
                if !paddedFrame.isNull, paddedFrame.width > 1, paddedFrame.height > 1, paddedFrame.contains(location) {
                    return true
                }
            } else {
                let paddedFrame = configuredActivationFrame.insetBy(dx: -24, dy: -24)
                if !paddedFrame.isNull, paddedFrame.width > 1, paddedFrame.height > 1 {
                    return paddedFrame.contains(location)
                }
            }

            // On a cold launch into the saved keypad, SwiftUI can install the
            // bridge before the drawer's background view has a stable frame.
            // Keep the edge swipe available from the top interaction band so
            // the bar can still be hidden without visiting Home and reopening.
            return fallbackActivationFrame(in: hostView).contains(location)
        }

        private func fallbackActivationFrame(in hostView: UIView) -> CGRect {
            let topInset = hostView.safeAreaInsets.top
            let height = if isVisible.wrappedValue {
                min(220, max(120, topInset + 132))
            } else {
                min(140, max(72, topInset + 80))
            }

            return CGRect(x: 0, y: 0, width: hostView.bounds.width, height: height)
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

private struct PortraitControllerMetrics {
    let dPadButtonSize: CGSize
    let actionButtonSize: CGSize
    let mapButtonSize: CGSize
    let pauseButtonSize: CGSize
    let leadingPadding: CGFloat
    let trailingPadding: CGFloat
    let bottomPadding: CGFloat

    var dPadHitSize: CGSize {
        ControllerLayoutMetrics.hitSize(for: dPadButtonSize)
    }

    var actionHitSize: CGSize {
        ControllerLayoutMetrics.hitSize(for: actionButtonSize)
    }

    init(size: CGSize, safeAreaInsets: EdgeInsets, controlScale: GamepadControlScale) {
        let scale = controlScale.multiplier
        let usableWidth = max(300, size.width - Geist.Spacing.s8)
        let dPadButton = min(82 * scale, max(64 * scale, (usableWidth / 4.2) * scale))
        let actionButton = min(82 * scale, max(64 * scale, (usableWidth / 4.5) * scale))

        dPadButtonSize = CGSize(width: dPadButton, height: dPadButton)
        actionButtonSize = CGSize(width: actionButton, height: actionButton)
        mapButtonSize = CGSize(width: 94 * scale, height: 58 * scale)
        pauseButtonSize = CGSize(width: 108 * scale, height: 58 * scale)
        leadingPadding = max(Geist.Spacing.s4, safeAreaInsets.leading + Geist.Spacing.s3)
        trailingPadding = max(Geist.Spacing.s4, safeAreaInsets.trailing + Geist.Spacing.s3)
        bottomPadding = max(Geist.Spacing.s4, safeAreaInsets.bottom + Geist.Spacing.s2)
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

private struct ControllerPadResolvedControlRouter: View {
    let context: ControllerPadRenderContext
    let control: GamepadResolvedControl

    var body: AnyView {
        let route = GamepadControllerPresentationRouting.resolvedControlRoute(
            kind: control.controlKind,
            hasJoystickMapping: control.joystickMapping != nil,
            hasTriggerSettings: control.triggerSettings != nil
        )

        switch route {
        case .decoration:
            return AnyView(ControllerPadResolvedDecoration(context: context, control: control))
        case .joystick:
            guard let mapping = control.joystickMapping else {
                return AnyView(ControllerPadResolvedButton(context: context, control: control))
            }
            return AnyView(
                ControllerPadResolvedJoystick(
                    context: context,
                    control: control,
                    mapping: mapping
                )
            )
        case .trigger:
            guard let settings = control.triggerSettings else {
                return AnyView(ControllerPadResolvedButton(context: context, control: control))
            }
            return AnyView(
                ControllerPadResolvedTrigger(
                    context: context,
                    control: control,
                    settings: settings
                )
            )
        case .trackpad:
            return AnyView(ControllerPadResolvedTrackpad(context: context, control: control))
        case .button:
            return AnyView(ControllerPadResolvedButton(context: context, control: control))
        }
    }
}

private struct ControllerPadResolvedDecoration: View {
    let context: ControllerPadRenderContext
    let control: GamepadResolvedControl

    var body: some View {
        GamepadRenderedControlFace(
            control: control,
            customization: context.customization,
            state: .normal
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ControllerPadResolvedJoystick: View {
    let context: ControllerPadRenderContext
    let control: GamepadResolvedControl
    let mapping: GamepadJoystickMapping

    var body: some View {
        GamepadJoystick(
            elementID: control.elementID,
            mapping: mapping,
            outputSettings: control.joystickOutputSettings ?? .defaultValue,
            label: control.label,
            size: control.size,
            elementCustomization: control.layoutCustomization,
            customization: context.customization
        )
    }
}

private struct ControllerPadResolvedTrigger: View {
    let context: ControllerPadRenderContext
    let control: GamepadResolvedControl
    let settings: GamepadTriggerSettings

    var body: some View {
        GamepadTrigger(
            elementID: control.elementID,
            mappedButton: control.mappedButton,
            label: control.label,
            size: control.size,
            elementCustomization: control.layoutCustomization,
            settings: settings,
            customization: context.customization
        )
    }
}

private struct ControllerPadResolvedTrackpad: View {
    let context: ControllerPadRenderContext
    let control: GamepadResolvedControl

    var body: some View {
        GamepadTrackpad(
            label: control.label,
            size: control.size,
            elementCustomization: control.layoutCustomization,
            settings: control.trackpadSettings ?? .defaultValue,
            customization: context.customization
        )
    }
}

private struct ControllerPadResolvedButton: View {
    let context: ControllerPadRenderContext
    let control: GamepadResolvedControl

    var body: some View {
        GamepadButton(
            elementID: control.elementID,
            button: control.mappedButton,
            size: control.size,
            shape: control.shape,
            labelOverride: control.label,
            elementCustomization: control.layoutCustomization,
            customization: context.customization
        )
    }
}

private struct GamepadFreeformControllerCanvas: View {
    @Environment(\.colorScheme) private var colorScheme
    let context: ControllerPadRenderContext
    var isEditingLayout = false
    var onCustomizationChanged: (GamepadCustomization, Bool) -> Void = { _, _ in }

    private var customization: GamepadCustomization { context.customization }

    @State private var activeDrag: IOSKeypadControlEditDragState?
    @State private var activeResize: IOSKeypadControlResizeState?
    @State private var activeRotation: IOSKeypadControlRotationState?
    @State private var selectedControlID: GamepadControlIdentity?
    @State private var pendingDeleteControl: IOSKeypadControlDeleteCandidate?

    var body: some View {
        GeometryReader { proxy in
            let controls = customization.resolvedControls(in: proxy.size).filter { $0.id != .system(.topBarActivation) }

            ZStack {
                if isEditingLayout {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            clearEditSelection()
                        }
                }

                ForEach(controls) { control in
                    ControllerPadResolvedControlRouter(context: context, control: control)
                        .allowsHitTesting(!isEditingLayout && !control.isDecoration)
                        .rotationEffect(.degrees(control.rotationDegrees))
                        .position(control.center)
                        .zIndex(0)
                }

                if isEditingLayout {
                    ForEach(controls) { control in
                        editOverlay(
                            for: control,
                            canvasSize: proxy.size,
                            isSelected: selectedControlID == control.id
                        )
                        .zIndex(selectedControlID == control.id ? 200 : 100)
                    }
                }
            }
            .coordinateSpace(name: "iOSKeypadLayoutCanvas")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .confirmationDialog(
            "Delete element?",
            isPresented: deleteConfirmationBinding,
            presenting: pendingDeleteControl
        ) { candidate in
            Button("Delete \(candidate.label)", role: .destructive) {
                deleteControl(candidate.identity)
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteControl = nil
            }
        } message: { candidate in
            Text("Remove \(candidate.label) from this keypad setup.")
        }
        .onChange(of: isEditingLayout) { _, isEditing in
            if !isEditing {
                clearEditSelection()
            }
        }
        .onDisappear {
            clearEditSelection()
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteControl != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteControl = nil
                }
            }
        )
    }

    private func clearEditSelection() {
        activeDrag = nil
        activeResize = nil
        activeRotation = nil
        selectedControlID = nil
        pendingDeleteControl = nil
    }

    private func editOverlay(for control: GamepadResolvedControl, canvasSize: CGSize, isSelected: Bool) -> some View {
        let chromeOutset: CGFloat = isSelected ? 12 : 6
        let minimumTouchSize: CGFloat = isSelected ? 52 : 44
        let overlaySize = CGSize(
            width: max(minimumTouchSize, control.size.width + chromeOutset),
            height: max(minimumTouchSize, control.size.height + chromeOutset)
        )
        let handleOutset: CGFloat = isSelected ? 34 : 0
        let hitFrameSize = CGSize(
            width: overlaySize.width + handleOutset * 2,
            height: overlaySize.height + handleOutset * 2
        )
        let chromeCenter = CGPoint(x: hitFrameSize.width / 2, y: hitFrameSize.height / 2)
        let cornerRadius = min(16, max(8, min(overlaySize.width, overlaySize.height) * 0.12))
        let tint = control.isLocationLocked ? Geist.color(.gray900, scheme: colorScheme) : Geist.color(.blue900, scheme: colorScheme)
        let strokeStyle = StrokeStyle(
            lineWidth: isSelected && !control.isLocationLocked ? 1.75 : 1,
            dash: control.isLocationLocked ? [4, 4] : []
        )

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.001))
                .frame(width: overlaySize.width, height: overlaySize.height)
                .position(chromeCenter)
                .zIndex(0)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint.opacity(control.isLocationLocked ? 0.025 : (isSelected ? 0.055 : 0.018)))
                .frame(width: overlaySize.width, height: overlaySize.height)
                .position(chromeCenter)
                .zIndex(1)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(tint.opacity(control.isLocationLocked ? 0.45 : (isSelected ? 0.95 : 0.38)), style: strokeStyle)
                .frame(width: overlaySize.width, height: overlaySize.height)
                .position(chromeCenter)
                .zIndex(2)

            if control.isLocationLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(4)
                    .background(Geist.color(.background100, scheme: colorScheme).opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(tint.opacity(0.2), lineWidth: 1))
                    .position(x: handleOutset + overlaySize.width, y: handleOutset)
                    .zIndex(6)
            }

            if isSelected {
                selectedEditHandles(
                    for: control,
                    overlaySize: overlaySize,
                    handleOutset: handleOutset,
                    canvasSize: canvasSize
                )
                .zIndex(10)
            }
        }
        .frame(width: hitFrameSize.width, height: hitFrameSize.height)
        .contentShape(Rectangle())
        .gesture(editDragGesture(for: control, canvasSize: canvasSize))
        .rotationEffect(.degrees(control.rotationDegrees))
        .position(control.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(control.isLocationLocked ? "\(control.label) locked" : "Edit \(control.label)")
        .accessibilityHint(control.isLocationLocked ? "This control is locked in the Mac keypad editor. Use the trash button to delete it." : "Drag to move. Use the corner handles to resize, the rotate handle at the top-right to rotate, or the trash button to delete.")
    }

    private func selectedEditHandles(for control: GamepadResolvedControl, overlaySize: CGSize, handleOutset: CGFloat, canvasSize: CGSize) -> some View {
        let hitFrameSize = CGSize(
            width: overlaySize.width + handleOutset * 2,
            height: overlaySize.height + handleOutset * 2
        )
        let topTrailingHandlePosition = handlePosition(for: .topTrailing, in: overlaySize)
        let topTrailingPosition = CGPoint(
            x: handleOutset + topTrailingHandlePosition.x,
            y: handleOutset + topTrailingHandlePosition.y
        )
        let rotationHandleOffset: CGFloat = 16
        let rotationHandlePosition = CGPoint(
            x: handleOutset + overlaySize.width + rotationHandleOffset,
            y: handleOutset - rotationHandleOffset
        )

        return ZStack {
            if !control.isLocationLocked {
                Path { path in
                    path.move(to: topTrailingPosition)
                    path.addLine(to: rotationHandlePosition)
                }
                .stroke(
                    Geist.color(.blue700, scheme: colorScheme).opacity(0.45),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .zIndex(1)

                rotationHandle(for: control)
                    .position(rotationHandlePosition)
                    .zIndex(4)

                ForEach(IOSKeypadResizeHandleCorner.allCases) { corner in
                    let position = handlePosition(for: corner, in: overlaySize)
                    resizeHandle(corner, for: control, canvasSize: canvasSize)
                        .position(x: handleOutset + position.x, y: handleOutset + position.y)
                        .zIndex(3)
                }
            }

            deleteHandle(for: control, overlaySize: overlaySize, handleOutset: handleOutset, canvasSize: canvasSize)
                .zIndex(5)
        }
        .frame(width: hitFrameSize.width, height: hitFrameSize.height)
    }

    private func resizeHandle(_ corner: IOSKeypadResizeHandleCorner, for control: GamepadResolvedControl, canvasSize: CGSize) -> some View {
        ZStack {
            Circle()
                .fill(Geist.color(.blue700, scheme: colorScheme))
                .overlay(
                    Circle()
                        .stroke(Geist.color(.background100, scheme: colorScheme), lineWidth: 1.25)
                )
                .frame(width: 10, height: 10)
        }
        .frame(width: 34, height: 34)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("iOSKeypadLayoutCanvas"))
                .onChanged { value in
                    updateResize(corner, value: value, control: control, canvasSize: canvasSize)
                }
                .onEnded { value in
                    finishResize(value, control: control, canvasSize: canvasSize)
                }
        )
        .accessibilityLabel(Text(corner.accessibilityLabel))
        .accessibilityHint(Text("Drag to resize this keypad control"))
    }

    private func rotationHandle(for control: GamepadResolvedControl) -> some View {
        Image(systemName: "arrow.clockwise")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Geist.color(.blue700, scheme: colorScheme), in: Circle())
            .overlay(Circle().stroke(Geist.color(.background100, scheme: colorScheme), lineWidth: 1.25))
            .contentShape(Circle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("iOSKeypadLayoutCanvas"))
                    .onChanged { value in
                        updateRotation(value, control: control)
                    }
                    .onEnded { value in
                        finishRotation(value, control: control)
                    }
            )
            .accessibilityLabel(Text("Rotate \(control.label)"))
            .accessibilityHint(Text("Drag around the selected control to rotate it"))
    }

    private func deleteHandle(for control: GamepadResolvedControl, overlaySize: CGSize, handleOutset: CGFloat, canvasSize: CGSize) -> some View {
        let belowFits = control.center.y + overlaySize.height / 2 + handleOutset <= canvasSize.height
        let aboveFits = control.center.y - overlaySize.height / 2 - handleOutset >= 0
        let rightFits = control.center.x + overlaySize.width / 2 + handleOutset <= canvasSize.width
        let position: CGPoint
        if belowFits {
            position = CGPoint(x: handleOutset + overlaySize.width / 2, y: handleOutset + overlaySize.height + 15)
        } else if aboveFits {
            position = CGPoint(x: handleOutset + overlaySize.width / 2, y: handleOutset - 15)
        } else if rightFits {
            position = CGPoint(x: handleOutset + overlaySize.width + 15, y: handleOutset + overlaySize.height / 2)
        } else {
            position = CGPoint(x: handleOutset - 15, y: handleOutset + overlaySize.height / 2)
        }

        return ZStack {
            Circle()
                .fill(Geist.color(.red900, scheme: colorScheme))
                .overlay(Circle().stroke(Geist.color(.background100, scheme: colorScheme), lineWidth: 1.25))
                .shadow(color: Color.black.opacity(0.16), radius: 5, x: 0, y: 2)

            Image(systemName: "trash.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
        .contentShape(Circle())
        .position(position)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("iOSKeypadLayoutCanvas"))
                .onEnded { _ in
                    requestDelete(control)
                }
        )
        .accessibilityLabel(Text("Delete \(control.label)"))
        .accessibilityHint(Text("Asks before removing this element from the current keypad setup"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            requestDelete(control)
        }
    }

    private func handlePosition(for corner: IOSKeypadResizeHandleCorner, in size: CGSize) -> CGPoint {
        let inset: CGFloat = 4
        switch corner {
        case .topLeading:
            return CGPoint(x: inset, y: inset)
        case .topTrailing:
            return CGPoint(x: size.width - inset, y: inset)
        case .bottomTrailing:
            return CGPoint(x: size.width - inset, y: size.height - inset)
        case .bottomLeading:
            return CGPoint(x: inset, y: size.height - inset)
        }
    }

    private func requestDelete(_ control: GamepadResolvedControl) {
        selectedControlID = control.id
        pendingDeleteControl = IOSKeypadControlDeleteCandidate(identity: control.id, label: control.label)
    }

    private func deleteControl(_ identity: GamepadControlIdentity) {
        guard let nextCustomization = customization.iosDeletingControl(identity) else {
            pendingDeleteControl = nil
            return
        }

        activeDrag = nil
        activeResize = nil
        activeRotation = nil
        selectedControlID = nil
        pendingDeleteControl = nil
        onCustomizationChanged(nextCustomization, true)
    }

    private func editDragGesture(for control: GamepadResolvedControl, canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("iOSKeypadLayoutCanvas"))
            .onChanged { value in
                guard isEditingLayout else { return }
                selectedControlID = control.id
                guard !control.isLocationLocked else { return }

                if activeDrag?.identity != control.id {
                    activeResize = nil
                    activeRotation = nil
                    activeDrag = IOSKeypadControlEditDragState(
                        identity: control.id,
                        startCustomization: customization
                    )
                }

                guard var dragState = activeDrag,
                      dragState.identity == control.id,
                      let nextCustomization = dragState.startCustomization.nudgedControls(
                        [control.id],
                        by: value.translation,
                        in: canvasSize
                      )
                else { return }

                dragState.didMove = true
                activeDrag = dragState
                onCustomizationChanged(nextCustomization, false)
            }
            .onEnded { value in
                guard isEditingLayout,
                      let dragState = activeDrag,
                      dragState.identity == control.id
                else { return }

                defer { activeDrag = nil }

                if let finalCustomization = dragState.startCustomization.nudgedControls(
                    [control.id],
                    by: value.translation,
                    in: canvasSize
                ) {
                    onCustomizationChanged(finalCustomization, true)
                } else if dragState.didMove {
                    onCustomizationChanged(customization, true)
                }
            }
    }

    private func updateResize(
        _ corner: IOSKeypadResizeHandleCorner,
        value: DragGesture.Value,
        control: GamepadResolvedControl,
        canvasSize: CGSize
    ) {
        guard isEditingLayout else { return }
        selectedControlID = control.id
        guard !control.isLocationLocked else { return }

        if activeResize?.identity != control.id || activeResize?.corner != corner {
            activeDrag = nil
            activeRotation = nil
            activeResize = IOSKeypadControlResizeState(
                identity: control.id,
                corner: corner,
                startCustomization: customization,
                startCenter: control.center,
                startSize: control.size,
                startWidthScale: control.layoutCustomization.widthScale,
                startHeightScale: control.layoutCustomization.heightScale
            )
        }

        guard var resizeState = activeResize,
              resizeState.identity == control.id,
              resizeState.corner == corner,
              let nextCustomization = resizedCustomization(from: resizeState, translation: value.translation, in: canvasSize)
        else { return }

        resizeState.didResize = true
        activeResize = resizeState
        onCustomizationChanged(nextCustomization, false)
    }

    private func finishResize(_ value: DragGesture.Value, control: GamepadResolvedControl, canvasSize: CGSize) {
        guard let resizeState = activeResize,
              resizeState.identity == control.id
        else { return }

        defer { activeResize = nil }

        if let finalCustomization = resizedCustomization(from: resizeState, translation: value.translation, in: canvasSize) {
            onCustomizationChanged(finalCustomization, true)
        } else if resizeState.didResize {
            onCustomizationChanged(customization, true)
        }
    }

    private func resizedCustomization(
        from resizeState: IOSKeypadControlResizeState,
        translation: CGSize,
        in canvasSize: CGSize
    ) -> GamepadCustomization? {
        guard canvasSize.width > 1,
              canvasSize.height > 1,
              abs(translation.width) > 0.001 || abs(translation.height) > 0.001
        else { return nil }

        let baseWidth = max(1, resizeState.startSize.width / max(resizeState.startWidthScale, 0.001))
        let baseHeight = max(1, resizeState.startSize.height / max(resizeState.startHeightScale, 0.001))
        let minSize = CGSize(
            width: GamepadButtonCustomization.minimumDimension(forBaseDimension: baseWidth),
            height: GamepadButtonCustomization.minimumDimension(forBaseDimension: baseHeight)
        )
        let maxSize = CGSize(
            width: min(canvasSize.width, baseWidth * GamepadButtonCustomization.maximumScale),
            height: min(canvasSize.height, baseHeight * GamepadButtonCustomization.maximumScale)
        )
        let startRect = CGRect(
            x: resizeState.startCenter.x - resizeState.startSize.width / 2,
            y: resizeState.startCenter.y - resizeState.startSize.height / 2,
            width: resizeState.startSize.width,
            height: resizeState.startSize.height
        )
        let resizedRect = Self.resizedFrame(
            from: startRect,
            corner: resizeState.corner,
            translation: translation,
            minSize: minSize,
            maxSize: maxSize,
            canvasSize: canvasSize
        )
        guard Self.rectDidChange(from: startRect, to: resizedRect) else { return nil }

        let nextCenter = CGPoint(x: resizedRect.midX, y: resizedRect.midY)
        return resizeState.startCustomization.iosUpdatingControlLayout(for: resizeState.identity) { layout in
            layout.widthScale = resizedRect.width / baseWidth
            layout.heightScale = resizedRect.height / baseHeight
            layout.centerX = nextCenter.x / max(canvasSize.width, 1)
            layout.centerY = nextCenter.y / max(canvasSize.height, 1)
        }
    }

    private func updateRotation(_ value: DragGesture.Value, control: GamepadResolvedControl) {
        guard isEditingLayout else { return }
        selectedControlID = control.id
        guard !control.isLocationLocked else { return }

        let pointerAngle = Self.angleInDegrees(from: control.center, to: value.location)
        if activeRotation?.identity != control.id {
            activeDrag = nil
            activeResize = nil
            activeRotation = IOSKeypadControlRotationState(
                identity: control.id,
                startCustomization: customization,
                startCenter: control.center,
                startRotationDegrees: control.layoutCustomization.rotationDegrees,
                startPointerAngleDegrees: pointerAngle
            )
        }

        guard var rotationState = activeRotation,
              rotationState.identity == control.id,
              let nextCustomization = rotatedCustomization(from: rotationState, pointerLocation: value.location)
        else { return }

        rotationState.didRotate = true
        activeRotation = rotationState
        onCustomizationChanged(nextCustomization, false)
    }

    private func finishRotation(_ value: DragGesture.Value, control: GamepadResolvedControl) {
        guard let rotationState = activeRotation,
              rotationState.identity == control.id
        else { return }

        defer { activeRotation = nil }

        if let finalCustomization = rotatedCustomization(from: rotationState, pointerLocation: value.location) {
            onCustomizationChanged(finalCustomization, true)
        } else if rotationState.didRotate {
            onCustomizationChanged(customization, true)
        }
    }

    private func rotatedCustomization(
        from rotationState: IOSKeypadControlRotationState,
        pointerLocation: CGPoint
    ) -> GamepadCustomization? {
        let pointerAngle = Self.angleInDegrees(from: rotationState.startCenter, to: pointerLocation)
        let delta = GamepadButtonCustomization.normalizedRotationDegrees(pointerAngle - rotationState.startPointerAngleDegrees)
        let nextRotation = GamepadButtonCustomization.normalizedRotationDegrees(rotationState.startRotationDegrees + delta)

        return rotationState.startCustomization.iosUpdatingControlLayout(for: rotationState.identity) { layout in
            layout.rotationDegrees = nextRotation
        }
    }


    private static func resizedFrame(
        from rect: CGRect,
        corner: IOSKeypadResizeHandleCorner,
        translation: CGSize,
        minSize: CGSize,
        maxSize: CGSize,
        canvasSize: CGSize
    ) -> CGRect {
        var minX = rect.minX
        var maxX = rect.maxX
        var minY = rect.minY
        var maxY = rect.maxY

        switch corner {
        case .topLeading:
            minX += translation.width
            minY += translation.height
        case .topTrailing:
            maxX += translation.width
            minY += translation.height
        case .bottomTrailing:
            maxX += translation.width
            maxY += translation.height
        case .bottomLeading:
            minX += translation.width
            maxY += translation.height
        }

        if corner.movesLeadingEdge {
            minX = GamepadButtonCustomization.clamp(minX, lower: 0, upper: maxX - minSize.width)
            let width = GamepadButtonCustomization.clamp(maxX - minX, lower: minSize.width, upper: maxSize.width)
            minX = maxX - width
        } else {
            maxX = GamepadButtonCustomization.clamp(maxX, lower: minX + minSize.width, upper: canvasSize.width)
            let width = GamepadButtonCustomization.clamp(maxX - minX, lower: minSize.width, upper: maxSize.width)
            maxX = minX + width
        }

        if corner.movesTopEdge {
            minY = GamepadButtonCustomization.clamp(minY, lower: 0, upper: maxY - minSize.height)
            let height = GamepadButtonCustomization.clamp(maxY - minY, lower: minSize.height, upper: maxSize.height)
            minY = maxY - height
        } else {
            maxY = GamepadButtonCustomization.clamp(maxY, lower: minY + minSize.height, upper: canvasSize.height)
            let height = GamepadButtonCustomization.clamp(maxY - minY, lower: minSize.height, upper: maxSize.height)
            maxY = minY + height
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func rectDidChange(from original: CGRect, to updated: CGRect) -> Bool {
        abs(original.minX - updated.minX) > 0.1
            || abs(original.minY - updated.minY) > 0.1
            || abs(original.width - updated.width) > 0.1
            || abs(original.height - updated.height) > 0.1
    }

    private static func angleInDegrees(from center: CGPoint, to point: CGPoint) -> CGFloat {
        atan2(point.y - center.y, point.x - center.x) * 180 / .pi
    }
}

private struct IOSKeypadControlEditDragState {
    let identity: GamepadControlIdentity
    let startCustomization: GamepadCustomization
    var didMove = false
}

private struct IOSKeypadControlResizeState {
    let identity: GamepadControlIdentity
    let corner: IOSKeypadResizeHandleCorner
    let startCustomization: GamepadCustomization
    let startCenter: CGPoint
    let startSize: CGSize
    let startWidthScale: CGFloat
    let startHeightScale: CGFloat
    var didResize = false
}

private struct IOSKeypadControlRotationState {
    let identity: GamepadControlIdentity
    let startCustomization: GamepadCustomization
    let startCenter: CGPoint
    let startRotationDegrees: CGFloat
    let startPointerAngleDegrees: CGFloat
    var didRotate = false
}

private struct IOSKeypadControlDeleteCandidate: Identifiable {
    let identity: GamepadControlIdentity
    let label: String

    var id: String { identity.id }
}

private extension GamepadCustomization {
    func iosDeletingControl(_ identity: GamepadControlIdentity) -> GamepadCustomization? {
        var next = self

        switch identity {
        case .builtin(let button):
            var buttonCustomization = next.buttonCustomization(for: button)
            guard !buttonCustomization.isHidden else { return nil }
            buttonCustomization.isHidden = true
            next.setButtonCustomization(buttonCustomization, for: button)

        case .custom(let id):
            guard next.customButtons.contains(where: { $0.id == id }) else { return nil }
            next.removeCustomButton(id: id)

        case .system(.topBarActivation), .controlBarItem:
            return nil
        }

        let normalizedNext = next.normalized
        return normalizedNext == normalized ? nil : normalizedNext
    }
}

private enum IOSKeypadResizeHandleCorner: CaseIterable, Identifiable {
    case topLeading
    case topTrailing
    case bottomTrailing
    case bottomLeading

    var id: String {
        switch self {
        case .topLeading: "topLeading"
        case .topTrailing: "topTrailing"
        case .bottomTrailing: "bottomTrailing"
        case .bottomLeading: "bottomLeading"
        }
    }

    var movesLeadingEdge: Bool {
        switch self {
        case .topLeading, .bottomLeading: true
        case .topTrailing, .bottomTrailing: false
        }
    }

    var movesTopEdge: Bool {
        switch self {
        case .topLeading, .topTrailing: true
        case .bottomLeading, .bottomTrailing: false
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .topLeading: "Resize from top left"
        case .topTrailing: "Resize from top right"
        case .bottomTrailing: "Resize from bottom right"
        case .bottomLeading: "Resize from bottom left"
        }
    }
}

private extension GamepadCustomization {
    func iosUpdatingControlLayout(
        for identity: GamepadControlIdentity,
        _ mutate: (inout GamepadButtonCustomization) -> Void
    ) -> GamepadCustomization? {
        var next = self
        switch identity {
        case .builtin(let button):
            var layout = next.buttonCustomization(for: button)
            mutate(&layout)
            next.setButtonCustomization(layout, for: button)
        case .custom(let id):
            guard let index = next.customButtons.firstIndex(where: { $0.id == id }) else { return nil }
            mutate(&next.customButtons[index].layout)
        case .system(.topBarActivation):
            mutate(&next.topBarActivationRegion)
        case .controlBarItem:
            return nil
        }

        let normalizedNext = next.normalized
        return normalizedNext == normalized ? nil : normalizedNext
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

private extension View {
    func gamepadOuterShadows(_ presentation: GamepadResolvedControlPresentation) -> some View {
        modifier(IOSGamepadOuterShadowModifier(presentation: presentation))
    }
}

private struct IOSGamepadOuterShadowModifier: ViewModifier {
    let presentation: GamepadResolvedControlPresentation

    func body(content: Content) -> some View {
        var view = AnyView(content)
        if presentation.shadows.isEmpty {
            view = AnyView(
                view.shadow(
                    color: presentation.shadowSwiftUIColor,
                    radius: presentation.shadowRadius,
                    x: presentation.shadowX,
                    y: presentation.shadowY
                )
            )
        } else {
            for shadow in presentation.shadows {
                let normalized = shadow.normalized
                view = AnyView(
                    view.shadow(
                        color: normalized.swiftUIColor,
                        radius: normalized.radius,
                        x: normalized.x,
                        y: normalized.y
                    )
                )
            }
        }
        return view
    }
}

private struct GamepadJoystick: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    let elementID: UUID?
    let mapping: GamepadJoystickMapping
    let outputSettings: GamepadJoystickOutputSettings
    let label: String
    let size: CGSize
    let elementCustomization: GamepadButtonCustomization
    let customization: GamepadCustomization

    @State private var activeDirections: Set<GamepadJoystickDirection> = []
    @State private var normalizedOffset = CGSize.zero

    private var joystickVisualStyle: GamepadJoystickVisualStyle {
        elementCustomization.joystickVisualStyle ?? .pad
    }

    private var visualSide: CGFloat {
        min(size.width, size.height)
    }

    private var hitSide: CGFloat {
        switch joystickVisualStyle {
        case .pad:
            max(visualSide + ControllerLayoutMetrics.buttonHitOutset * 2, visualSide)
        case .thumbstick:
            max(visualSide + ControllerLayoutMetrics.buttonHitOutset * 2, visualSide * 2.55, 104)
        }
    }

    private var activationDiameter: CGFloat? {
        joystickVisualStyle == .thumbstick ? max(44, visualSide) : nil
    }

    private var knobSide: CGFloat {
        switch joystickVisualStyle {
        case .pad:
            max(34, visualSide * 0.36)
        case .thumbstick:
            max(32, visualSide * 0.72)
        }
    }

    private var knobTravelRadius: CGFloat {
        switch joystickVisualStyle {
        case .pad:
            max(0, (visualSide - knobSide) / 2 - 4)
        case .thumbstick:
            max(0, (hitSide - knobSide) / 2 - 6)
        }
    }

    var body: some View {
        ZStack {
            joystickBase
                .frame(width: hitSide, height: hitSide)
                .allowsHitTesting(false)

            JoystickCaptureView(activationDiameter: activationDiameter) { direction, pressed, pressIdentifier in
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
        let isActive = !activeDirections.isEmpty || abs(normalizedOffset.width) > 0.001 || abs(normalizedOffset.height) > 0.001
        let presentation = customization.resolvedPresentation(for: elementCustomization, fallbackAccentStyle: accentStyle, controlKind: .joystick, state: isActive ? .active : .normal, scheme: colorScheme)
        let fillStyle = presentation.fillStyle
        let strokeColor = presentation.strokeSwiftUIColor
        let foregroundColor = presentation.foregroundSwiftUIColor
        let knobFillColor = elementCustomization.joystickKnobFill(accentStyle: accentStyle, isPressed: isActive, scheme: colorScheme)
        let knobStrokeColor = elementCustomization.joystickKnobStroke(accentStyle: accentStyle, isPressed: isActive, scheme: colorScheme)
        let knobOffset = CGSize(width: normalizedOffset.width * knobTravelRadius, height: normalizedOffset.height * knobTravelRadius)
        let isThumbstick = joystickVisualStyle == .thumbstick

        return ZStack {
            if isThumbstick && isActive {
                Circle()
                    .stroke(foregroundColor.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [5, 7]))
                    .frame(width: hitSide * 0.72, height: hitSide * 0.72)
                    .transition(.opacity)
            }

            GamepadFillShapeLayer(shape: Circle(), fillStyle: fillStyle)
                .overlay(Circle().stroke(strokeColor, lineWidth: presentation.strokeWidth))
                .overlay(GamepadControlEffectOverlay(shape: Circle(), presentation: presentation))
                .gamepadOuterShadows(presentation)
                .frame(width: visualSide, height: visualSide)

            if !isThumbstick {
                Circle()
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                    .frame(width: visualSide * 0.70, height: visualSide * 0.70)

                directionLabels(foregroundColor: foregroundColor)
            }

            Circle()
                .fill(knobFillColor)
                .overlay(Circle().stroke(knobStrokeColor, lineWidth: 1))
                .frame(width: knobSide, height: knobSide)
                .offset(knobOffset)
                .animation(.interactiveSpring(response: 0.16, dampingFraction: 0.82), value: normalizedOffset)

            if customization.showsButtonLabels && !isThumbstick {
                Text(label)
                    .geistTypography(visualSide <= 88 ? .button12 : .button14)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(foregroundColor)
                    .padding(.horizontal, 6)
                    .offset(y: visualSide * (isThumbstick ? 0.58 : 0.34))
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
        if let elementID {
            client.setElementInput(
                KeypadElementInputID(elementID: elementID, part: KeypadElementInputPart(direction: direction)),
                pressed: pressed,
                pressIdentifier: pressIdentifier
            )
        } else {
            client.setButton(mapping[direction], pressed: pressed, pressIdentifier: pressIdentifier)
        }
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
    let elementID: UUID?
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
        let presentation = customization.resolvedPresentation(for: elementCustomization, fallbackAccentStyle: accentStyle, controlKind: .trigger, state: isPressed ? .active : .normal, scheme: colorScheme)
        let fillStyle = presentation.fillStyle
        let strokeColor = presentation.strokeSwiftUIColor
        let foregroundColor = presentation.foregroundSwiftUIColor
        let fillFraction = max(0, min(1, value))

        return ZStack(alignment: normalizedSettings.orientation == .vertical ? .bottom : .leading) {
            GamepadFillShapeLayer(shape: Capsule(), fillStyle: fillStyle)
                .overlay(Capsule().stroke(strokeColor, lineWidth: presentation.strokeWidth))
                .overlay(GamepadControlEffectOverlay(shape: Capsule(), presentation: presentation))
                .gamepadOuterShadows(presentation)

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
            sendDigitalPress(shouldPress)
        }
        if !isActive, isDigitalPressed {
            isDigitalPressed = false
            sendDigitalPress(false)
        }
    }

    private func sendDigitalPress(_ pressed: Bool) {
        if let elementID {
            client.setElementInput(
                KeypadElementInputID(elementID: elementID, part: .triggerDigital),
                pressed: pressed
            )
        } else {
            client.setButton(mappedButton, pressed: pressed)
        }
    }
}

final class KeypadHapticPlayer {
    static let shared = KeypadHapticPlayer()

    private var engine: CHHapticEngine?
    private var fallbackGenerators: [GamepadHapticStyle: UIImpactFeedbackGenerator] = [:]

    private init() {}

    func prepare(_ feedback: GamepadHapticFeedback) {
        let feedback = feedback.normalized
        guard feedback.style != .none else { return }
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            try? startEngineIfNeeded()
        } else {
            fallbackGenerator(for: feedback.style).prepare()
        }
    }

    func play(_ feedback: GamepadHapticFeedback) {
        let feedback = feedback.normalized
        guard feedback.style != .none, feedback.intensity > 0 else { return }
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics, playCoreHaptic(feedback) {
            return
        }
        playFallback(feedback)
    }

    private func playCoreHaptic(_ feedback: GamepadHapticFeedback) -> Bool {
        do {
            try startEngineIfNeeded()
            let pattern = try CHHapticPattern(events: feedback.coreHapticEvents, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
    }

    private func startEngineIfNeeded() throws {
        if engine == nil {
            let newEngine = try CHHapticEngine()
            newEngine.stoppedHandler = { [weak self] _ in
                self?.engine = nil
            }
            newEngine.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine = newEngine
        }
        try engine?.start()
    }

    private func playFallback(_ feedback: GamepadHapticFeedback) {
        let generator = fallbackGenerator(for: feedback.style)
        for event in feedback.fallbackImpactSchedule {
            DispatchQueue.main.asyncAfter(deadline: .now() + event.delay) {
                generator.impactOccurred(intensity: event.intensity)
                generator.prepare()
            }
        }
    }

    private func fallbackGenerator(for style: GamepadHapticStyle) -> UIImpactFeedbackGenerator {
        if let generator = fallbackGenerators[style] { return generator }
        let generator = UIImpactFeedbackGenerator(style: style.impactFeedbackStyle)
        fallbackGenerators[style] = generator
        return generator
    }
}

private extension GamepadHapticStyle {
    var impactFeedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .none, .light: .light
        case .medium: .medium
        case .heavy: .heavy
        case .soft: .soft
        case .rigid: .rigid
        }
    }
}

private extension GamepadHapticFeedback {
    var coreHapticEvents: [CHHapticEvent] {
        let feedback = normalized
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(feedback.intensity))
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(feedback.sharpness))
        let parameters = [intensity, sharpness]
        let duration = TimeInterval(feedback.duration)

        switch feedback.pattern {
        case .single:
            return [CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: 0)]
        case .double:
            let spacing = min(max(duration, 0.045), 0.18)
            return [
                CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: spacing)
            ]
        case .pulse:
            return [CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: 0, duration: max(duration, 0.035))]
        case .buzz:
            let buzzDuration = max(duration, 0.08)
            let accentIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(min(1, feedback.intensity * 0.85)))
            return [
                CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: 0, duration: buzzDuration),
                CHHapticEvent(eventType: .hapticTransient, parameters: [accentIntensity, sharpness], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [accentIntensity, sharpness], relativeTime: buzzDuration * 0.55)
            ]
        }
    }

    var fallbackImpactSchedule: [(delay: TimeInterval, intensity: CGFloat)] {
        let feedback = normalized
        let duration = TimeInterval(feedback.duration)
        switch feedback.pattern {
        case .single, .pulse:
            return [(0, feedback.intensity)]
        case .double:
            return [(0, feedback.intensity), (min(max(duration, 0.045), 0.18), feedback.intensity * 0.85)]
        case .buzz:
            let step: TimeInterval = 0.045
            let count = max(2, min(6, Int(ceil(max(duration, 0.08) / step))))
            return (0..<count).map { index in
                (Double(index) * step, feedback.intensity * (index.isMultiple(of: 2) ? 0.92 : 0.68))
            }
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
        let presentation = customization.resolvedPresentation(for: elementCustomization, fallbackAccentStyle: resolvedAccentStyle, controlKind: .trackpad, state: isActive ? .active : .normal, scheme: colorScheme)
        let fillStyle = presentation.fillStyle
        let strokeColor = presentation.strokeSwiftUIColor
        let foregroundColor = presentation.foregroundSwiftUIColor
        let shape = UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)

        return ZStack {
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: presentation.strokeWidth))
                .overlay(GamepadControlEffectOverlay(shape: shape, presentation: presentation))
                .gamepadOuterShadows(presentation)

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
        let feedback = customization.resolvedPresentation(for: elementCustomization, fallbackAccentStyle: resolvedAccentStyle, controlKind: .trackpad, state: .active, scheme: colorScheme).hapticFeedback
        DispatchQueue.main.async {
            KeypadHapticPlayer.shared.play(feedback)
        }
    }

    private func prepareHapticIfNeeded() {
        guard isKeypadHapticsEnabled else { return }
        let feedback = customization.resolvedPresentation(for: elementCustomization, fallbackAccentStyle: resolvedAccentStyle, controlKind: .trackpad, state: .normal, scheme: colorScheme).hapticFeedback
        KeypadHapticPlayer.shared.prepare(feedback)
    }
}

private struct GamepadButton: View {
    @EnvironmentObject private var client: ControllerClient
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.keypadHapticsEnabled) private var isKeypadHapticsEnabled
    var elementID: UUID? = nil
    let button: GameButton
    let size: CGSize
    var shape: GamepadButtonShapeStyle = .roundedRectangle
    var labelOverride: String? = nil
    var elementCustomization: GamepadButtonCustomization? = nil
    let customization: GamepadCustomization

    @State private var isPressed = false

    private var title: String {
        labelOverride ?? customization.visualLabel(for: button)
    }

    var body: some View {
        let hitSize = ControllerLayoutMetrics.hitSize(for: size)
        let presentation = resolvedPresentation

        ZStack {
            ZStack {
                buttonBackground(presentation: presentation)
                    .gamepadOuterShadows(presentation)
                    .overlay {
                        if let glowColor = presentation.glowSwiftUIColor, presentation.glowRadius > 0 {
                            buttonBackground(presentation: presentation)
                                .blur(radius: presentation.glowRadius)
                                .foregroundStyle(glowColor)
                                .opacity(0.68)
                                .allowsHitTesting(false)
                        }
                    }

                buttonContent(presentation: presentation)
            }
            .opacity(presentation.opacity)
            .blur(radius: presentation.blurRadius)
            .scaleEffect(presentation.scale)
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

    private var resolvedPresentation: GamepadResolvedControlPresentation {
        customization.resolvedPresentation(
            for: resolvedButtonCustomization,
            fallbackAccentStyle: resolvedAccentStyle,
            state: isPressed ? .pressed : .normal,
            scheme: colorScheme
        )
    }

    @ViewBuilder
    private func buttonBackground(presentation: GamepadResolvedControlPresentation) -> some View {
        let fillStyle = presentation.fillStyle
        let strokeColor = presentation.strokeSwiftUIColor
        let lineWidth: CGFloat = presentation.strokeWidth

        switch resolvedShape {
        case .roundedRectangle, .rectangle, .capsule, .circle, .ellipse:
            let shape = UnevenRoundedRectangle(cornerRadii: resolvedCornerRadii.rectangleCornerRadii, style: .continuous)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay(GamepadControlEffectOverlay(shape: shape, presentation: presentation))
        case .polygon:
            let shape = GamepadRegularPolygonButtonShape(sides: 3)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay(GamepadControlEffectOverlay(shape: shape, presentation: presentation))
        case .star:
            let shape = GamepadStarButtonShape(points: 5)
            GamepadFillShapeLayer(shape: shape, fillStyle: fillStyle)
                .overlay(shape.stroke(strokeColor, lineWidth: lineWidth))
                .overlay(GamepadControlEffectOverlay(shape: shape, presentation: presentation))
        }
    }

    @ViewBuilder
    private func buttonContent(presentation: GamepadResolvedControlPresentation) -> some View {
        if let icon = presentation.icon {
            controlIcon(icon, presentation: presentation)
                .padding(.horizontal, 4)
        }

        if customization.showsButtonLabels && (presentation.icon?.placement != .center || title.count <= 2) {
            Text(title)
                .geistTypography(title.count <= 2 ? .heading32 : .button16)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(presentation.foregroundSwiftUIColor)
                .padding(.horizontal, 4)
                .offset(labelOffset(for: presentation.icon?.placement))
        }
    }

    @ViewBuilder
    private func controlIcon(_ icon: GamepadControlIcon, presentation: GamepadResolvedControlPresentation) -> some View {
        let tint = icon.tintColor?.swiftUIColor ?? presentation.foregroundSwiftUIColor
        let baseSize = max(12, min(size.width, size.height) * 0.34 * icon.scale)
        switch icon.source {
        case .sfSymbol:
            Image(systemName: icon.value)
                .font(.system(size: baseSize, weight: .semibold))
                .symbolRenderingMode(icon.renderingMode == .multicolor ? .multicolor : .monochrome)
                .foregroundStyle(tint)
                .offset(iconOffset(for: icon.placement))
        case .text:
            Text(icon.value)
                .font(.system(size: baseSize, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .offset(iconOffset(for: icon.placement))
        case .asset:
            Text("▧")
                .font(.system(size: baseSize, weight: .semibold))
                .foregroundStyle(tint.opacity(0.72))
                .offset(iconOffset(for: icon.placement))
        }
    }

    private func iconOffset(for placement: GamepadControlIconPlacement) -> CGSize {
        switch placement {
        case .leading: CGSize(width: -size.width * 0.20, height: 0)
        case .trailing: CGSize(width: size.width * 0.20, height: 0)
        case .top: CGSize(width: 0, height: -size.height * 0.18)
        case .bottom: CGSize(width: 0, height: size.height * 0.18)
        case .center, .background: .zero
        }
    }

    private func labelOffset(for placement: GamepadControlIconPlacement?) -> CGSize {
        switch placement {
        case .leading: CGSize(width: size.width * 0.11, height: 0)
        case .trailing: CGSize(width: -size.width * 0.11, height: 0)
        case .top: CGSize(width: 0, height: size.height * 0.15)
        case .bottom: CGSize(width: 0, height: -size.height * 0.15)
        case .center, .background, nil: .zero
        }
    }

    private func handlePressEdge(_ pressed: Bool, isActive: Bool, pressIdentifier: UInt64) {
        // The UIKit touch view is authoritative for press edges. Send every edge to
        // ControllerClient before consulting SwiftUI state so fast taps cannot lose a
        // release through a stale render closure.
        if let elementID {
            client.setElementInput(
                KeypadElementInputID(elementID: elementID, part: .primary),
                pressed: pressed,
                pressIdentifier: pressIdentifier
            )
        } else {
            client.setButton(button, pressed: pressed, pressIdentifier: pressIdentifier)
        }

        guard isActive != isPressed else { return }
        isPressed = isActive

        if pressed {
            schedulePressHaptic()
        }
    }

    private func schedulePressHaptic() {
        guard isKeypadHapticsEnabled else { return }
        let feedback = resolvedPresentation.hapticFeedback
        DispatchQueue.main.async {
            KeypadHapticPlayer.shared.play(feedback)
        }
    }

    private func prepareHapticIfNeeded() {
        guard isKeypadHapticsEnabled else { return }
        KeypadHapticPlayer.shared.prepare(resolvedPresentation.hapticFeedback)
    }
}
