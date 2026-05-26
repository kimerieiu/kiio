import AVFoundation
import SwiftUI
import UIKit

enum QRCodeScannerFailure: Error, Equatable {
    case cameraUnavailable
    case sessionConfigurationFailed
}

struct QRCodeScannerView: UIViewControllerRepresentable {
    let isActive: Bool
    let onCode: (String) -> Void
    let onFailure: (QRCodeScannerFailure) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        QRCodeScannerViewController(
            onCode: onCode,
            onFailure: onFailure
        )
    }

    func updateUIViewController(_ controller: QRCodeScannerViewController, context: Context) {
        controller.onCode = onCode
        controller.onFailure = onFailure
        controller.setActive(isActive)
    }
}

final class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: (String) -> Void
    var onFailure: (QRCodeScannerFailure) -> Void

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "kiio.qrcode.scanner.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var hasReportedCode = false
    private var shouldRunWhenConfigured = false

    init(
        onCode: @escaping (String) -> Void,
        onFailure: @escaping (QRCodeScannerFailure) -> Void
    ) {
        self.onCode = onCode
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func setActive(_ isActive: Bool) {
        shouldRunWhenConfigured = isActive

        guard isConfigured else {
            return
        }

        if isActive {
            hasReportedCode = false
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if isActive, !self.session.isRunning {
                self.session.startRunning()
            } else if !isActive, self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else {
            return
        }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            onFailure(.cameraUnavailable)
            return
        }

        let output = AVCaptureMetadataOutput()
        session.beginConfiguration()

        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            onFailure(.sessionConfigurationFailed)
            return
        }

        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
        self.previewLayer = previewLayer
        isConfigured = true
        setActive(shouldRunWhenConfigured)
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasReportedCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue,
              !value.isEmpty else {
            return
        }

        hasReportedCode = true
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
        onCode(value)
    }
}
