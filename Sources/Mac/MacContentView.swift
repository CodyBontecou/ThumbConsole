import SwiftUI
import CoreGraphics
import CoreImage.CIFilterBuiltins
import AppKit

struct MacContentView: View {
    @EnvironmentObject private var server: MacControllerServer
    @State private var keyCaptureButton: GameButton?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                accessibilityPanel
                connectionPanel
                keyBindingsPanel
                debugPanel
                testPanel
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $keyCaptureButton) { button in
            KeyCaptureSheet(button: button)
                .environmentObject(server)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PocketPad Mac Helper")
                    .font(.largeTitle.bold())
                Text("iPhone controller → WebSocket → CGEvent keyboard injection")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(server.isClientConnected ? .green : (server.isRunning ? .orange : .red))
                .frame(width: 10, height: 10)
            Text(server.statusText)
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.quaternary, in: Capsule())
    }

    private var accessibilityPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                server.accessibilityTrusted ? "Accessibility permission granted" : "Accessibility permission required",
                systemImage: server.accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(server.accessibilityTrusted ? .green : .orange)
            .font(.headline)

            if !server.accessibilityTrusted {
                Text("macOS blocks keyboard injection until this helper is allowed in System Settings → Privacy & Security → Accessibility.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Request Permission") { server.promptForAccessibility() }
                    Button("Open Accessibility Settings") { server.openAccessibilitySettings() }
                    Button("Refresh") { server.refreshAccessibilityStatus() }
                }
            }
        }
        .panelStyle()
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect from iPhone")
                .font(.headline)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    if server.localURLs.isEmpty {
                        Text("No local IPv4 address found. Make sure Wi‑Fi is enabled.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(server.localURLs, id: \.self) { url in
                            Text(url)
                                .font(.system(.title3, design: .monospaced).weight(.semibold))
                                .textSelection(.enabled)
                        }
                    }
                }

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Text("Scan with iPhone")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    QRCodeView(text: server.pairingPayload)
                        .frame(width: 152, height: 152)
                    Text("Tap Scan Mac QR Code in the iOS app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 190)
            }

            HStack(spacing: 18) {
                VStack(alignment: .leading) {
                    Text("Pairing code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(server.pairingCode)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                }

                Divider()
                    .frame(height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Client")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(server.clientName)
                    Text("Port \(server.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(server.isRunning ? "Restart Server" : "Start Server") {
                    server.stop()
                    server.start()
                }
                Button("Stop") { server.stop() }
                    .disabled(!server.isRunning)
            }
        }
        .panelStyle()
    }

    private var keyBindingsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Controller Key Bindings")
                        .font(.headline)
                    Text("Record any Mac keyboard key for each iPhone controller button. Changes are saved automatically.")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Reset All") {
                    server.resetAllKeyBindings()
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                ForEach(GameButton.allCases) { button in
                    GridRow {
                        Text(button.displayName)
                            .font(.callout.weight(.semibold))
                            .frame(width: 82, alignment: .leading)

                        Text(server.keyLabel(for: button))
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(minWidth: 112, alignment: .leading)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

                        Button("Record") {
                            keyCaptureButton = button
                        }

                        Button("Default") {
                            server.resetKeyBinding(button)
                        }
                        .disabled(server.isDefaultBinding(for: button))
                    }
                }
            }
        }
        .panelStyle()
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Debug")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    Text("Last heartbeat").foregroundStyle(.secondary)
                    Text(lastHeartbeatText)
                }
                GridRow {
                    Text("Estimated latency").foregroundStyle(.secondary)
                    Text(server.estimatedLatencyMS.map { "\($0) ms" } ?? "—")
                }
                GridRow {
                    Text("Last event").foregroundStyle(.secondary)
                    Text(server.lastReceivedEvent)
                }
                GridRow {
                    Text("Pressed buttons").foregroundStyle(.secondary)
                    Text(pressedButtonsText)
                }
            }
        }
        .panelStyle()
    }

    private var testPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestone 1 Local Keyboard Test")
                .font(.headline)
            Text("Hold a test button to emit keyDown; release it to emit keyUp. Use Release All if anything sticks.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                TestKeyButton(button: .left)
                TestKeyButton(button: .jump)
                TestKeyButton(button: .attack)
                Button("Release All") { server.releaseAll(reason: "Manual release all") }
                    .keyboardShortcut(.escape, modifiers: [.command])
            }
        }
        .panelStyle()
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

private struct TestKeyButton: View {
    @EnvironmentObject private var server: MacControllerServer
    let button: GameButton
    @State private var isPressed = false

    var body: some View {
        Text("\(server.keyLabel(for: button)) \(button.displayName)")
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 124, height: 52)
            .background(isPressed ? Color.accentColor : Color.secondary.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(isPressed ? .white : .primary)
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
}

private struct KeyCaptureSheet: View {
    @EnvironmentObject private var server: MacControllerServer
    @Environment(\.dismiss) private var dismiss

    let button: GameButton
    @State private var monitor: Any?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "keyboard")
                .font(.system(size: 46))
                .foregroundStyle(Color.accentColor)

            Text("Record \(button.displayName)")
                .font(.title2.bold())

            Text("Press any key on this Mac. That key will be sent whenever \(button.displayName) is pressed on the iPhone controller.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(28)
        .frame(width: 360)
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
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
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

private extension View {
    func panelStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
