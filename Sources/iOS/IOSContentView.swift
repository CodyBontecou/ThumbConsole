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
            LinearGradient(colors: [.black, Color(red: 0.05, green: 0.06, blue: 0.09)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if client.isConnected {
                ControllerPadView()
                    .ignoresSafeArea()
            } else {
                ConnectionView(macHost: $macHost, macPort: $macPort, pairingCode: $pairingCode)
            }
        }
        .preferredColorScheme(.dark)
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

private struct ConnectionView: View {
    @EnvironmentObject private var client: ControllerClient
    @Binding var macHost: String
    @Binding var macPort: String
    @Binding var pairingCode: String

    @State private var isShowingScanner = false
    @State private var qrScanError: String?

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height && proxy.size.width >= 760

            ScrollView(.vertical) {
                Group {
                    if isWide {
                        HStack(alignment: .center, spacing: 32) {
                            header
                                .frame(maxWidth: 380, alignment: .leading)
                            form
                                .frame(maxWidth: 460)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            header
                            form
                        }
                        .frame(maxWidth: 520)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, isWide ? 36 : 20)
                .padding(.vertical, isWide ? 20 : 18)
                .frame(minHeight: proxy.size.height, alignment: isWide ? .center : .top)
            }
            .scrollDismissesKeyboard(.interactively)
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
                        Button("Cancel") {
                            isShowingScanner = false
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PocketPad")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .minimumScaleFactor(0.75)
            Text("Use this iPhone as a controller for Hollow Knight on your Mac.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(client.state.label)
                .font(.headline)
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)
            if let error = client.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let qrScanError {
                Text(qrScanError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var form: some View {
        VStack(spacing: 14) {
            Button {
                qrScanError = nil
                isShowingScanner = true
            } label: {
                Label("Scan Mac QR Code", systemImage: "qrcode.viewfinder")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
                Text("or enter manually")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
            }

            TextField("Mac IP, e.g. 192.168.1.24", text: $macHost)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numbersAndPunctuation)
                .fieldStyle()

            TextField("Port", text: $macPort)
                .keyboardType(.numberPad)
                .fieldStyle()

            TextField("Pairing code (optional)", text: $pairingCode)
                .keyboardType(.numberPad)
                .fieldStyle()

            Button {
                client.connect(hostField: macHost, port: macPort, pairingCode: pairingCode)
            } label: {
                Text("Connect")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(macHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(macHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
    }

    private func handleScannedPairingCode(_ text: String) {
        guard let payload = PairingPayload.decode(from: text),
              let urlString = payload.urls.first
        else {
            qrScanError = "That QR code is not a PocketPad pairing code."
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

    private var statusColor: Color {
        switch client.state {
        case .connected: .green
        case .connecting: .yellow
        case .failed: .orange
        case .disconnected: .secondary
        }
    }
}

private struct ControllerPadView: View {
    @EnvironmentObject private var client: ControllerClient

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width >= proxy.size.height

            VStack(spacing: 0) {
                topBar
                    .padding(.leading, max(isLandscape ? 24 : 16, proxy.safeAreaInsets.leading + 12))
                    .padding(.trailing, max(isLandscape ? 24 : 16, proxy.safeAreaInsets.trailing + 12))
                    .padding(.top, max(isLandscape ? 12 : 8, proxy.safeAreaInsets.top + 8))

                if isLandscape {
                    landscapeControllerLayout(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                } else {
                    portraitControllerLayout(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
                }
            }
        }
    }

    private func landscapeControllerLayout(size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let availableHeight = max(220, size.height - 58)
        let dPadButton = min(82, max(64, availableHeight * 0.24), size.width * 0.095)
        let actionButton = min(86, max(64, availableHeight * 0.25), size.width * 0.10)
        let utilityHeight = min(64, max(52, availableHeight * 0.18))

        return HStack(alignment: .center, spacing: max(16, size.width * 0.035)) {
            DPadView(buttonSize: CGSize(width: dPadButton, height: dPadButton))
                .frame(width: dPadButton * 3 + 16, height: dPadButton * 3 + 16)

            Spacer(minLength: 8)

            HStack(spacing: 18) {
                GamepadButton(button: .map, title: "Map", size: CGSize(width: 92, height: utilityHeight), shape: .capsule)
                GamepadButton(button: .pause, title: "Pause", size: CGSize(width: 104, height: utilityHeight), shape: .capsule)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            ActionButtonsView(buttonSize: CGSize(width: actionButton, height: actionButton))
                .frame(width: actionButton * 2 + 18, height: actionButton * 2 + 18)
        }
        .padding(.leading, max(20, max(size.width * 0.045, safeAreaInsets.leading + 12)))
        .padding(.trailing, max(20, max(size.width * 0.045, safeAreaInsets.trailing + 12)))
        .padding(.bottom, max(18, safeAreaInsets.bottom + 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func portraitControllerLayout(size: CGSize, safeAreaInsets: EdgeInsets) -> some View {
        let usableWidth = max(300, size.width - 32)
        let dPadButton = min(82, max(64, usableWidth / 4.2))
        let actionButton = min(82, max(64, usableWidth / 4.5))

        return VStack(spacing: 16) {
            Spacer(minLength: 6)

            DPadView(buttonSize: CGSize(width: dPadButton, height: dPadButton))
                .frame(width: dPadButton * 3 + 16, height: dPadButton * 3 + 16)

            HStack(spacing: 16) {
                GamepadButton(button: .map, title: "Map", size: CGSize(width: 94, height: 58), shape: .capsule)
                GamepadButton(button: .pause, title: "Pause", size: CGSize(width: 108, height: 58), shape: .capsule)
            }

            ActionButtonsView(buttonSize: CGSize(width: actionButton, height: actionButton))
                .frame(width: actionButton * 2 + 18, height: actionButton * 2 + 18)

            Spacer(minLength: 6)
        }
        .padding(.leading, max(16, safeAreaInsets.leading + 12))
        .padding(.trailing, max(16, safeAreaInsets.trailing + 12))
        .padding(.bottom, max(16, safeAreaInsets.bottom + 8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Label("Connected", systemImage: "wifi")
                .foregroundStyle(.green)
                .font(.headline)
            Text(client.lastSentEvent)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Button("Disconnect") {
                client.disconnect(sendReleaseAll: true)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.75))
        }
    }
}

private struct DPadView: View {
    var buttonSize = CGSize(width: 78, height: 78)

    var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                GamepadButton(button: .up, title: "↑", size: buttonSize)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
            GridRow {
                GamepadButton(button: .left, title: "←", size: buttonSize)
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: buttonSize.width, height: buttonSize.height)
                GamepadButton(button: .right, title: "→", size: buttonSize)
            }
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                GamepadButton(button: .down, title: "↓", size: buttonSize)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
    }
}

private struct ActionButtonsView: View {
    var buttonSize = CGSize(width: 82, height: 82)

    var body: some View {
        Grid(horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
                GamepadButton(button: .focus, title: "Focus", size: buttonSize, tint: .purple)
                GamepadButton(button: .dash, title: "Dash", size: buttonSize, tint: .cyan)
            }
            GridRow {
                GamepadButton(button: .attack, title: "Attack", size: buttonSize, tint: .orange)
                GamepadButton(button: .jump, title: "Jump", size: buttonSize, tint: .green)
            }
        }
    }
}

private enum GamepadButtonShape {
    case roundedRectangle
    case capsule
}

private struct GamepadButton: View {
    @EnvironmentObject private var client: ControllerClient
    let button: GameButton
    let title: String
    let size: CGSize
    var tint: Color = .blue
    var shape: GamepadButtonShape = .roundedRectangle

    @State private var isPressed = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack {
            buttonBackground
                .shadow(color: tint.opacity(isPressed ? 0.55 : 0.25), radius: isPressed ? 16 : 7, y: isPressed ? 3 : 8)

            Text(title)
                .font(.system(size: title.count <= 2 ? 34 : 17, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.65)
                .foregroundStyle(.white)

            TouchCaptureView { pressed in
                setPressed(pressed)
            }
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(isPressed ? 0.93 : 1)
        .animation(.snappy(duration: 0.08), value: isPressed)
        .onDisappear {
            if isPressed { setPressed(false) }
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        let fillColor = tint.opacity(isPressed ? 0.95 : 0.34)
        let strokeColor = Color.white.opacity(isPressed ? 0.45 : 0.16)
        let lineWidth: CGFloat = isPressed ? 3 : 1

        switch shape {
        case .roundedRectangle:
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(fillColor)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(strokeColor, lineWidth: lineWidth))
        case .capsule:
            Capsule()
                .fill(fillColor)
                .overlay(Capsule().stroke(strokeColor, lineWidth: lineWidth))
        }
    }

    private func setPressed(_ pressed: Bool) {
        guard pressed != isPressed else { return }
        isPressed = pressed
        if pressed {
            haptic.impactOccurred(intensity: 0.55)
        }
        client.setButton(button, pressed: pressed)
    }
}


private extension View {
    func fieldStyle() -> some View {
        self
            .textFieldStyle(.plain)
            .font(.title3.monospaced())
            .padding(14)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.16)))
    }
}
