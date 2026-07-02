import AVFoundation
import SwiftUI

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let viewController = QRCodeScannerViewController()
        viewController.onScan = onScan
        return viewController
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {
        uiViewController.onScan = onScan
    }
}

final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(geistHex: "#000000")
        checkCameraPermissionAndStart()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    deinit {
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func checkCameraPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.setupCaptureSession() : self?.showCameraPermissionMessage()
                }
            }
        case .denied, .restricted:
            showCameraPermissionMessage()
        @unknown default:
            showCameraPermissionMessage()
        }
    }

    private func setupCaptureSession() {
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input)
        else {
            showCameraPermissionMessage(text: "Camera unavailable")
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showCameraPermissionMessage(text: "QR scanning unavailable")
            return
        }

        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer

        addOverlay()

        DispatchQueue.global(qos: .userInitiated).async { [weak session] in
            session?.startRunning()
        }
    }

    private func addOverlay() {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Point the camera at the QR code on your Mac"
        label.textColor = UIColor(geistHex: "#ededed")
        label.font = UIFont(name: "Geist Sans", size: 14) ?? .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.backgroundColor = UIColor(geistHex: "#1a1a1a")
        label.layer.cornerRadius = 6
        label.layer.borderWidth = 1
        label.layer.borderColor = UIColor(geistHex: "#ffffff24").cgColor
        label.clipsToBounds = true

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 56)
        ])
    }

    private func showCameraPermissionMessage(text: String = "Allow camera access in Settings to scan the Mac QR code.") {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = UIColor(geistHex: "#ededed")
        label.font = UIFont(name: "Geist Sans", size: 14) ?? .systemFont(ofSize: 14, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = 0

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let stringValue = object.stringValue
        else {
            return
        }

        didScan = true
        session.stopRunning()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onScan?(stringValue)
    }
}

private extension UIColor {
    convenience init(geistHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch cleaned.count {
        case 8:
            red = (value >> 24) & 0xff
            green = (value >> 16) & 0xff
            blue = (value >> 8) & 0xff
            alpha = value & 0xff
        case 6:
            red = (value >> 16) & 0xff
            green = (value >> 8) & 0xff
            blue = value & 0xff
            alpha = 0xff
        default:
            red = 0
            green = 0
            blue = 0
            alpha = 0xff
        }

        self.init(
            red: CGFloat(red) / 255,
            green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255,
            alpha: CGFloat(alpha) / 255
        )
    }
}
