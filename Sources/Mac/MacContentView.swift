import SwiftUI
import CoreGraphics
import CoreImage.CIFilterBuiltins
import AppKit

struct MacContentView: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    @State private var keyCaptureButton: GameButton?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Geist.Spacing.s6) {
                header
                accessibilityPanel
                connectionPanel
                if server.isPairingPending {
                    pairingRequestPanel
                }
                keyBindingsPanel
                debugPanel
                testPanel
            }
            .padding(Geist.Spacing.s8)
            .frame(maxWidth: 1100, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .geistScreenBackground()
        .sheet(item: $keyCaptureButton) { button in
            KeyCaptureSheet(button: button)
                .environmentObject(server)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Geist.Spacing.s6) {
            VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                Text("PocketPad Mac Helper")
                    .geistTypography(.heading40)
                    .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                Text("iPhone controller → WebSocket → CGEvent keyboard injection")
                    .geistTypography(.copy16)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }

            Spacer(minLength: Geist.Spacing.s4)
            statusBadge
        }
    }

    private var statusBadge: some View {
        MacStatusPill(
            title: server.statusText,
            systemImage: server.isClientConnected ? "iphone.gen3.radiowaves.left.and.right" : (server.isPairingPending ? "lock.fill" : (server.isRunning ? "dot.radiowaves.left.and.right" : "xmark.circle.fill")),
            tone: server.isClientConnected ? .success : (server.isRunning ? .warning : .error)
        )
    }

    private var accessibilityPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s4) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Text("Accessibility Permission")
                        .geistTypography(.heading20)
                    Text("macOS requires Accessibility access before PocketPad can inject keyboard events.")
                        .geistTypography(.copy14)
                        .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                }

                Spacer()

                MacStatusPill(
                    title: server.accessibilityTrusted ? "Permission Granted" : "Permission Required",
                    systemImage: server.accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                    tone: server.accessibilityTrusted ? .success : .warning
                )
            }

            if !server.accessibilityTrusted {
                Text("Keyboard injection is blocked. Open System Settings → Privacy & Security → Accessibility and enable PocketPad Mac.")
                    .geistTypography(.copy14)
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Geist.Spacing.s3) {
                        accessibilityButtons
                    }
                    VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
                        accessibilityButtons
                    }
                }
            }
        }
        .geistPanel()
    }

    @ViewBuilder
    private var accessibilityButtons: some View {
        Button("Request Accessibility Permission") { server.promptForAccessibility() }
            .geistButtonStyle(.primary)
        Button("Open Accessibility Settings") { server.openAccessibilitySettings() }
            .geistButtonStyle(.secondary)
        Button("Refresh Permission Status") { server.refreshAccessibilityStatus() }
            .geistButtonStyle(.tertiary)
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "Connect From iPhone",
                subtitle: "Scan the QR code or enter one of these local WebSocket addresses in the iOS app."
            )

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Geist.Spacing.s6) {
                    connectionAddresses
                    Spacer(minLength: Geist.Spacing.s4)
                    qrCodeCard
                }
                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    connectionAddresses
                    qrCodeCard
                }
            }

            Divider()
                .overlay(Geist.color(.grayAlpha400, scheme: colorScheme))

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Geist.Spacing.s4) {
                    serverInfoTiles
                    Spacer()
                    serverControls
                }
                VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
                    serverInfoTiles
                    serverControls
                }
            }
        }
        .geistPanel()
    }

    private var pairingRequestPanel: some View {
        VStack(spacing: Geist.Spacing.s4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    Text("Secure Pairing Request")
                        .geistTypography(.heading20)
                        .foregroundStyle(Color.white)
                    Text("\(server.pendingPairingClientName ?? "An iPhone") wants to pair with PocketPad Mac.")
                        .geistTypography(.copy14)
                        .foregroundStyle(Color.white.opacity(0.68))
                }

                Spacer()

                Button {
                    server.cancelPairing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel pairing")
            }

            VStack(spacing: Geist.Spacing.s3) {
                Text("Enter this code on PocketPad iPhone:")
                    .geistTypography(.label13)
                    .foregroundStyle(Color.white.opacity(0.72))

                Text(server.pairingCode)
                    .geistTypography(.heading32)
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                    .textSelection(.enabled)

                HStack(spacing: Geist.Spacing.s2) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Waiting for iPhone to enter the code…")
                        .geistTypography(.copy13)
                }
                .foregroundStyle(Color.white.opacity(0.62))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Geist.Spacing.s4)
        }
        .padding(Geist.Spacing.s6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private var connectionAddresses: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s3) {
            Text("Local Addresses")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            if server.localURLs.isEmpty {
                MessageRow(
                    text: "No local IPv4 address found. Enable Wi‑Fi and refresh the server.",
                    tone: .warning
                )
            } else {
                VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
                    ForEach(server.localURLs, id: \.self) { url in
                        Text(url)
                            .geistTypography(.label14Mono)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .textSelection(.enabled)
                            .padding(.horizontal, Geist.Spacing.s3)
                            .frame(height: Geist.Spacing.s10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var qrCodeCard: some View {
        VStack(alignment: .center, spacing: Geist.Spacing.s3) {
            Text("Scan With iPhone")
                .geistTypography(.heading14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            QRCodeView(text: server.pairingPayload)
                .frame(width: 152, height: 152)
            Text("Tap Scan Mac QR Code in PocketPad on iPhone.")
                .geistTypography(.copy13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .multilineTextAlignment(.center)
        }
        .padding(Geist.Spacing.s4)
        .frame(width: 200)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var serverInfoTiles: some View {
        HStack(spacing: Geist.Spacing.s3) {
            InfoTile(title: "Pairing Code", value: server.pairingCode, mono: true)
            InfoTile(title: "Client", value: server.clientName)
            InfoTile(title: "Port", value: "\(server.port)", mono: true)
        }
    }

    private var serverControls: some View {
        HStack(spacing: Geist.Spacing.s3) {
            Button(server.isRunning ? "Restart Server" : "Start Server") {
                if server.isRunning {
                    server.restart()
                } else {
                    server.start()
                }
            }
            .geistButtonStyle(.primary)

            Button("Stop Server") { server.stop() }
                .geistButtonStyle(.secondary)
                .disabled(!server.isRunning)
        }
    }

    private var keyBindingsPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s4) {
                SectionHeader(
                    title: "Controller Key Bindings",
                    subtitle: "Record any Mac key for each iPhone controller button. Changes are saved automatically."
                )

                Spacer()

                Button("Reset Key Bindings") {
                    server.resetAllKeyBindings()
                }
                .geistButtonStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: Geist.Spacing.s3, verticalSpacing: Geist.Spacing.s2) {
                ForEach(GameButton.allCases) { button in
                    GridRow {
                        Text(button.displayName)
                            .geistTypography(.heading14)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .frame(width: 82, alignment: .leading)

                        Text(server.keyLabel(for: button))
                            .geistTypography(.label14Mono)
                            .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                            .padding(.horizontal, Geist.Spacing.s3)
                            .frame(height: Geist.Spacing.s8)
                            .frame(minWidth: 112, alignment: .leading)
                            .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
                            )

                        Button("Record Key") {
                            keyCaptureButton = button
                        }
                        .geistButtonStyle(.primary, size: .small)

                        Button("Restore Default") {
                            server.resetKeyBinding(button)
                        }
                        .geistButtonStyle(.tertiary, size: .small)
                        .disabled(server.isDefaultBinding(for: button))
                    }
                }
            }
        }
        .geistPanel()
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "Input Diagnostics",
                subtitle: "Transport and keyboard-injection details for live testing."
            )

            VStack(spacing: 0) {
                DiagnosticRow(title: "Last Heartbeat", value: lastHeartbeatText)
                DiagnosticRow(title: "Estimated Latency", value: server.estimatedLatencyMS.map { "\($0) ms" } ?? "—")
                DiagnosticRow(title: "Missing Input Frames", value: "\(server.missedButtonFrames)")
                DiagnosticRow(title: "Ignored Input Edges", value: "\(server.ignoredButtonEdges)")
                DiagnosticRow(title: "Recovered Input Edges", value: "\(server.recoveredButtonEdges)")
                DiagnosticRow(title: "Last Event", value: server.lastReceivedEvent)
                DiagnosticRow(title: "Pressed Buttons", value: pressedButtonsText)
            }
            .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
            )
        }
        .geistPanel()
    }

    private var testPanel: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s4) {
            SectionHeader(
                title: "Local Keyboard Test",
                subtitle: "Hold a test button to emit keyDown; release it to emit keyUp. Use Release All Keys if anything sticks."
            )

            HStack(spacing: Geist.Spacing.s3) {
                TestKeyButton(button: .left)
                TestKeyButton(button: .jump)
                TestKeyButton(button: .attack)
                Button("Release All Keys") { server.releaseAll(reason: "Manual release all") }
                    .geistButtonStyle(.error)
                    .keyboardShortcut(.escape, modifiers: [.command])
            }
        }
        .geistPanel()
    }

    private var lastHeartbeatText: String {
        guard let date = server.lastHeartbeat else { return "—" }
        return date.formatted(date: .omitted, time: .standard)
    }

    private var pressedButtonsText: String {
        if server.pressedButtons.isEmpty { return "None" }
        return server.pressedButtons
            .map(\.rawValue)
            .sorted()
            .joined(separator: ", ")
    }
}

private enum MacInterfaceTone {
    case neutral
    case success
    case warning
    case error

    func foreground(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.gray900, scheme: scheme)
        case .success: Geist.color(.blue900, scheme: scheme)
        case .warning: Geist.color(.amber900, scheme: scheme)
        case .error: Geist.color(.red900, scheme: scheme)
        }
    }

    func background(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.gray100, scheme: scheme)
        case .success: Geist.color(.blue100, scheme: scheme)
        case .warning: Geist.color(.amber100, scheme: scheme)
        case .error: Geist.color(.red100, scheme: scheme)
        }
    }

    func border(scheme: ColorScheme) -> Color {
        switch self {
        case .neutral: Geist.color(.grayAlpha400, scheme: scheme)
        case .success: Geist.color(.blue400, scheme: scheme)
        case .warning: Geist.color(.amber400, scheme: scheme)
        case .error: Geist.color(.red400, scheme: scheme)
        }
    }
}

private struct MacStatusPill: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let systemImage: String
    let tone: MacInterfaceTone

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

private struct MessageRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String
    let tone: MacInterfaceTone

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
    }
}

private struct SectionHeader: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s2) {
            Text(title)
                .geistTypography(.heading20)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
            Text(subtitle)
                .geistTypography(.copy14)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct InfoTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    var mono = false

    var body: some View {
        VStack(alignment: .leading, spacing: Geist.Spacing.s1) {
            Text(title)
                .geistTypography(.label12)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            Text(value)
                .geistTypography(mono ? .label14Mono : .label14)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .frame(height: 56, alignment: .center)
        .background(Geist.color(.gray100, scheme: colorScheme), in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private struct DiagnosticRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Geist.Spacing.s4) {
            Text(title)
                .geistTypography(.label13)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .frame(width: 180, alignment: .leading)
            Text(value)
                .geistTypography(.label13Mono)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))
                .textSelection(.enabled)
            Spacer(minLength: Geist.Spacing.s2)
        }
        .padding(.horizontal, Geist.Spacing.s3)
        .padding(.vertical, Geist.Spacing.s2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Geist.color(.grayAlpha400, scheme: colorScheme))
                .frame(height: 1)
        }
    }
}

private struct TestKeyButton: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.colorScheme) private var colorScheme
    let button: GameButton
    @State private var isPressed = false

    var body: some View {
        Text("\(server.keyLabel(for: button))  \(button.displayName)")
            .geistTypography(.button14)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 124, height: 52)
            .background(buttonFill, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                    .stroke(isPressed ? Geist.color(.grayAlpha600, scheme: colorScheme) : Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: isPressed ? 2 : 1)
            )
            .foregroundStyle(isPressed ? Geist.color(.background100, scheme: colorScheme) : Geist.color(.gray1000, scheme: colorScheme))
            .contentShape(RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        server.sendTestDown(button)
                    }
                    .onEnded { _ in
                        guard isPressed else { return }
                        isPressed = false
                        server.sendTestUp(button)
                    }
            )
            .onDisappear {
                if isPressed {
                    isPressed = false
                    server.sendTestUp(button)
                }
            }
    }

    private var buttonFill: Color {
        isPressed ? Geist.color(.gray1000, scheme: colorScheme) : Geist.color(.gray100, scheme: colorScheme)
    }
}

private struct KeyCaptureSheet: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let button: GameButton
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: Geist.Spacing.s4) {
            Image(systemName: "keyboard")
                .font(.system(size: 46))
                .foregroundStyle(Geist.color(.blue900, scheme: colorScheme))

            Text("Record \(button.displayName)")
                .geistTypography(.heading24)
                .foregroundStyle(Geist.color(.gray1000, scheme: colorScheme))

            Text("Press any key on this Mac. That key will be sent whenever \(button.displayName) is pressed on the iPhone controller.")
                .geistTypography(.copy14)
                .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Cancel Recording") {
                dismiss()
            }
            .geistButtonStyle(.secondary)
            .keyboardShortcut(.cancelAction)
        }
        .padding(Geist.Spacing.s6)
        .frame(width: 380)
        .background(Geist.color(.background100, scheme: colorScheme))
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                server.setKeyBinding(CGKeyCode(event.keyCode), for: button)
                DispatchQueue.main.async { dismiss() }
                return nil
            }
        }
        .onDisappear {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }
    }
}

private struct QRCodeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        Group {
            if let image = QRCodeRenderer.image(from: text) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 72))
                    .foregroundStyle(Geist.color(.gray900, scheme: colorScheme))
            }
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Geist.Radius.sm, style: .continuous)
                .stroke(Geist.color(.grayAlpha400, scheme: colorScheme), lineWidth: 1)
        )
    }
}

private enum QRCodeRenderer {
    static func image(from text: String) -> NSImage? {
        guard !text.isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaledImage.extent.width, height: scaledImage.extent.height))
    }
}
