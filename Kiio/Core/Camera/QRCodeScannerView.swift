import AVFoundation
import SwiftUI
import UIKit

enum QRCodeScannerFailure: Error, Equatable {
    case cameraUnavailable
    case cameraAccessDenied
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

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateVideoOrientation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.previewLayer?.frame = CGRect(origin: .zero, size: size)
            self.updateVideoOrientation()
        })
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

        requestCameraAccessIfNeeded { [weak self] granted in
            guard let self else { return }
            if granted {
                self.configureSession()
            } else {
                DispatchQueue.main.async {
                    self.onFailure(.cameraAccessDenied)
                }
            }
        }
    }

    private func requestCameraAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                DispatchQueue.main.async {
                    self.onFailure(.cameraUnavailable)
                }
                return
            }

            let output = AVCaptureMetadataOutput()
            self.session.beginConfiguration()

            if self.session.canSetSessionPreset(.hd1920x1080) {
                self.session.sessionPreset = .hd1920x1080
            }

            guard self.session.canAddInput(input), self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.onFailure(.sessionConfigurationFailed)
                }
                return
            }

            self.session.addInput(input)
            self.session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
            self.session.commitConfiguration()

            self.tuneDeviceForFastAccurateScanning(device)

            DispatchQueue.main.async {
                let previewLayer = AVCaptureVideoPreviewLayer(session: self.session)
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.frame = self.view.bounds
                self.view.layer.insertSublayer(previewLayer, at: 0)
                self.previewLayer = previewLayer
                self.isConfigured = true
                self.updateVideoOrientation()
                self.setActive(self.shouldRunWhenConfigured)
            }
        }
    }

    private func tuneDeviceForFastAccurateScanning(_ device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        if device.isSmoothAutoFocusSupported {
            device.isSmoothAutoFocusEnabled = false
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = true
        }
    }

    private func updateVideoOrientation() {
        guard let connection = previewLayer?.connection, connection.isVideoOrientationSupported else { return }

        let orientation: AVCaptureVideoOrientation
        switch view.window?.windowScene?.interfaceOrientation {
        case .landscapeLeft:
            orientation = .landscapeLeft
        case .landscapeRight:
            orientation = .landscapeRight
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
        default:
            orientation = .portrait
        }
        connection.videoOrientation = orientation
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
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
        stopSession()
        onCode(value)
    }
}
