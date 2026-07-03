import AVFoundation
import SwiftUI
import UIKit

struct DeviceQRCodeScannerView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @EnvironmentObject private var deviceStore: DeviceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    let onBound: () -> Void

    @StateObject private var viewModel = DeviceQRCodeBindingViewModel()
    @State private var permissionState = CameraPermissionState.checking
    @State private var scannerFailure: String?
    @State private var isRefreshingAgent = false

    var body: some View {
        ZStack {
            scannerBackground

            VStack(spacing: 0) {
                topBar
                Spacer()
                scannerFrame
                Spacer()
                bottomPanel
            }
        }
        .background(Color.black.ignoresSafeArea())
        .kiioHidesTabBar()
        .navigationBarBackButtonHidden(true)
        .task {
            await updatePermission()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else {
                return
            }
            Task {
                await updatePermission()
            }
        }
        .kiioErrorAlert(message: $viewModel.errorMessage, locale: appState.locale)
    }

    @ViewBuilder
    private var scannerBackground: some View {
        if permissionState == .authorized {
            QRCodeScannerView(
                isActive: scannerIsActive,
                onCode: { value in
                    Task { await handleScannedValue(value) }
                },
                onFailure: { failure in
                    if failure == .cameraAccessDenied {
                        scannerFailure = nil
                        permissionState = .denied
                    } else {
                        scannerFailure = scannerFailureMessage(failure)
                    }
                }
            )
            .ignoresSafeArea()
        } else {
            Color.black.ignoresSafeArea()
        }

        Color.black.opacity(0.18)
            .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.32))
                    .clipShape(Circle())
            }

            Spacer()

            Text(L10n.tr("device.scan.title", locale: appState.locale))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear
                .frame(width: 42, height: 42)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var scannerFrame: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.88), lineWidth: 2)
                .frame(width: 238, height: 238)

            ForEach(ScannerCorner.allCases) { corner in
                cornerPath(corner)
                    .stroke(KiioTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .frame(width: 238, height: 238, alignment: corner.alignment)
            }

            if viewModel.isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text(L10n.tr("device.scan.binding", locale: appState.locale))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(18)
                .background(.black.opacity(0.52))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if viewModel.didBind {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(KiioTheme.success)
                    if let scannedCode = viewModel.scannedCode {
                        Text(scannedCode)
                            .font(.system(size: 25, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Text(L10n.tr("device.pairing.success", locale: appState.locale))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .padding(20)
                .background(.black.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: 14) {
            if permissionState == .authorized {
                if !agentIsAvailable {
                    permissionCard(
                        icon: "sparkles",
                        title: L10n.tr("device.pairing.agentMissingTitle", locale: appState.locale),
                        message: L10n.tr("device.pairing.agentMissingMessage", locale: appState.locale),
                        primaryTitle: L10n.tr("common.refresh", locale: appState.locale),
                        primaryAction: refreshAgentContext
                    )
                } else if let scannerFailure {
                    permissionCard(
                        icon: "camera",
                        title: L10n.tr("device.scan.cameraUnavailable", locale: appState.locale),
                        message: scannerFailure,
                        primaryTitle: nil,
                        primaryAction: nil
                    )
                } else {
                    Text(L10n.tr("device.scan.hint", locale: appState.locale))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if viewModel.needsRescan {
                    KiioPrimaryButton(title: L10n.tr("device.scan.scanAgain", locale: appState.locale)) {
                        viewModel.scanAgain()
                    }
                }
            } else {
                permissionStateView
            }

            KiioSecondaryButton(title: L10n.tr("device.scan.manualInput", locale: appState.locale)) {
                dismiss()
            }
        }
        .padding(20)
        .background(.black.opacity(0.28))
    }

    @ViewBuilder
    private var permissionStateView: some View {
        switch permissionState {
        case .checking, .requesting:
            permissionCard(
                icon: "camera",
                title: L10n.tr("device.scan.requestingPermission", locale: appState.locale),
                message: L10n.tr("device.scan.requestingPermissionHint", locale: appState.locale),
                primaryTitle: nil,
                primaryAction: nil
            )
        case .denied:
            permissionCard(
                icon: "camera.fill",
                title: L10n.tr("device.scan.permissionDeniedTitle", locale: appState.locale),
                message: L10n.tr("device.scan.permissionDeniedMessage", locale: appState.locale),
                primaryTitle: L10n.tr("device.scan.openSettings", locale: appState.locale),
                primaryAction: openAppSettings
            )
        case .restricted:
            permissionCard(
                icon: "camera.fill",
                title: L10n.tr("device.scan.permissionRestrictedTitle", locale: appState.locale),
                message: L10n.tr("device.scan.permissionRestrictedMessage", locale: appState.locale),
                primaryTitle: nil,
                primaryAction: nil
            )
        case .authorized:
            EmptyView()
        }
    }

    private func permissionCard(
        icon: String,
        title: String,
        message: String,
        primaryTitle: String?,
        primaryAction: (() -> Void)?
    ) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.system(size: 13))
                .lineSpacing(3)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            if let primaryTitle, let primaryAction {
                KiioPrimaryButton(title: primaryTitle) {
                    primaryAction()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var scannerIsActive: Bool {
        permissionState == .authorized
            && agentIsAvailable
            && scannerFailure == nil
            && !viewModel.isProcessing
            && !viewModel.didBind
            && !viewModel.needsRescan
    }

    private var agentIsAvailable: Bool {
        bootstrapStore.agents.first?.id.isEmpty == false
    }

    private func updatePermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .authorized
        case .notDetermined:
            permissionState = .requesting
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permissionState = granted ? .authorized : .denied
        case .denied:
            permissionState = .denied
        case .restricted:
            permissionState = .restricted
        @unknown default:
            permissionState = .denied
        }
    }

    private func handleScannedValue(_ value: String) async {
        guard agentIsAvailable else {
            viewModel.errorMessage = L10n.tr("device.pairing.agentMissingMessage", locale: appState.locale)
            return
        }

        let success = await viewModel.handleScannedValue(
            value,
            locale: appState.locale,
            agentId: bootstrapStore.agents.first?.id,
            deviceStore: deviceStore
        )

        guard success else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            onBound()
        }
    }

    private func refreshAgentContext() {
        guard !isRefreshingAgent else { return }
        isRefreshingAgent = true
        Task {
            _ = await bootstrapStore.refresh()
            viewModel.scanAgain()
            isRefreshingAgent = false
        }
    }

    private func scannerFailureMessage(_ failure: QRCodeScannerFailure) -> String {
        switch failure {
        case .cameraAccessDenied:
            return L10n.tr("device.scan.permissionDeniedMessage", locale: appState.locale)
        case .cameraUnavailable:
            return L10n.tr("device.scan.cameraUnavailableMessage", locale: appState.locale)
        case .sessionConfigurationFailed:
            return L10n.tr("device.scan.cameraSessionFailed", locale: appState.locale)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
    }

    private func cornerPath(_ corner: ScannerCorner) -> Path {
        Path { path in
            switch corner {
            case .topLeft:
                path.move(to: CGPoint(x: 44, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 44))
            case .topRight:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 44, y: 0))
                path.addLine(to: CGPoint(x: 44, y: 44))
            case .bottomLeft:
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 44))
                path.addLine(to: CGPoint(x: 44, y: 44))
            case .bottomRight:
                path.move(to: CGPoint(x: 44, y: 0))
                path.addLine(to: CGPoint(x: 44, y: 44))
                path.addLine(to: CGPoint(x: 0, y: 44))
            }
        }
    }
}

private enum CameraPermissionState {
    case checking
    case requesting
    case authorized
    case denied
    case restricted
}

private enum ScannerCorner: CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: Self { self }

    var alignment: Alignment {
        switch self {
        case .topLeft:
            return .topLeading
        case .topRight:
            return .topTrailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomRight:
            return .bottomTrailing
        }
    }
}
