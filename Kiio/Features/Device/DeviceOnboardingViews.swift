import SwiftUI
import UIKit

struct DeviceProvisioningGuideView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    let onContinue: () -> Void

    @State private var actionMessage: String?

    private let portalURLString = "http://192.168.4.1"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                modeBanner
                guidePanel
                quickActions
                tipsPanel
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("device.provisioning.title", locale: appState.locale))
        .safeAreaInset(edge: .bottom) {
            KiioPrimaryButton(title: L10n.tr("device.provisioning.next", locale: appState.locale)) {
                onContinue()
            }
            .padding(20)
            .background(KiioTheme.background.opacity(0.96))
        }
    }

    private var modeBanner: some View {
        KiioCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "wifi")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(KiioTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(KiioTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("device.provisioning.modeTitle", locale: appState.locale))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                    Text(L10n.tr("device.provisioning.modeDesc", locale: appState.locale))
                        .font(.system(size: 14))
                        .lineSpacing(3)
                        .foregroundStyle(KiioTheme.secondaryText)
                }
            }
        }
    }

    private var guidePanel: some View {
        KiioCard {
            Label(L10n.tr("device.provisioning.helpTitle", locale: appState.locale), systemImage: "info.circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(KiioTheme.text)

            VStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { index in
                    DeviceGuideStep(
                        number: index + 1,
                        title: L10n.tr("device.provisioning.step\(index).title", locale: appState.locale),
                        desc: L10n.tr("device.provisioning.step\(index).desc", locale: appState.locale)
                    )
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                DeviceGuideAction(
                    icon: "gearshape",
                    title: L10n.tr("device.provisioning.openSettings", locale: appState.locale),
                    subtitle: L10n.tr("device.provisioning.openSettingsSub", locale: appState.locale)
                ) {
                    openSystemSettings()
                }

                DeviceGuideAction(
                    icon: "globe",
                    title: L10n.tr("device.provisioning.portal", locale: appState.locale),
                    subtitle: "192.168.4.1"
                ) {
                    openDevicePortal()
                }
            }

            KiioSecondaryButton(title: L10n.tr("device.provisioning.copyPortal", locale: appState.locale)) {
                copyPortalAddress()
            }

            if let actionMessage {
                Text(actionMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var tipsPanel: some View {
        KiioCard {
            Label(L10n.tr("device.provisioning.tipsTitle", locale: appState.locale), systemImage: "lightbulb")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(KiioTheme.text)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(KiioTheme.accent)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(L10n.tr("device.provisioning.tip\(index)", locale: appState.locale))
                            .font(.system(size: 13))
                            .foregroundStyle(KiioTheme.secondaryText)
                            .lineSpacing(3)
                    }
                }
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            actionMessage = L10n.tr("device.provisioning.openSettingsFailed", locale: appState.locale)
            return
        }
        openURL(url) { accepted in
            actionMessage = accepted
                ? L10n.tr("device.provisioning.openSettingsHint", locale: appState.locale)
                : L10n.tr("device.provisioning.openSettingsFailed", locale: appState.locale)
        }
    }

    private func openDevicePortal() {
        guard let url = URL(string: portalURLString) else {
            actionMessage = L10n.tr("device.provisioning.portalOpenFailed", locale: appState.locale)
            return
        }
        openURL(url) { accepted in
            actionMessage = accepted
                ? L10n.tr("device.provisioning.portalOpened", locale: appState.locale)
                : L10n.tr("device.provisioning.portalOpenFailed", locale: appState.locale)
        }
    }

    private func copyPortalAddress() {
        UIPasteboard.general.string = portalURLString
        actionMessage = L10n.tr("device.provisioning.portalCopied", locale: appState.locale)
    }
}

struct DevicePairingGuideView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore
    @EnvironmentObject private var deviceStore: DeviceStore
    let onBound: () -> Void

    @State private var code = ""
    @State private var alertMessage: String?
    @State private var didBind = false
    @State private var isRefreshingAgent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heading
                if bootstrapStore.agents.isEmpty {
                    agentUnavailableCard
                }
                scannerVisual
                manualInput
                KiioPrimaryButton(
                    title: didBind ? L10n.tr("device.pairing.success", locale: appState.locale) : L10n.tr("device.bind", locale: appState.locale),
                    isLoading: deviceStore.isBinding,
                    isDisabled: !canSubmitManualCode
                ) {
                    Task { await bindDevice() }
                }
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("device.pairing.title", locale: appState.locale))
        .task {
            await bootstrapStore.ensureLoaded()
        }
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("device.pairing.heading", locale: appState.locale))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(KiioTheme.text)
            Text(L10n.tr("device.pairing.headingSub", locale: appState.locale))
                .font(.system(size: 14))
                .foregroundStyle(KiioTheme.secondaryText)
                .lineSpacing(3)
        }
    }

    private var agentUnavailableCard: some View {
        KiioCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(KiioTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(KiioTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.tr("device.pairing.agentMissingTitle", locale: appState.locale))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                    Text(L10n.tr("device.pairing.agentMissingMessage", locale: appState.locale))
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineSpacing(3)

                    Button {
                        Task { await refreshAgentContext() }
                    } label: {
                        HStack(spacing: 8) {
                            if isRefreshingAgent || bootstrapStore.isLoading {
                                ProgressView()
                            }
                            Text(L10n.tr("common.refresh", locale: appState.locale))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(KiioTheme.accent)
                    }
                    .disabled(isRefreshingAgent || bootstrapStore.isLoading)
                    .padding(.top, 4)
                }

                Spacer()
            }
        }
    }

    private var scannerVisual: some View {
        NavigationLink {
            DeviceQRCodeScannerView {
                didBind = true
                onBound()
            }
        } label: {
            KiioCard {
                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(KiioTheme.accentSoft)
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(KiioTheme.accent.opacity(0.55), lineWidth: 2)
                            .frame(width: 150, height: 150)
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 52, weight: .light))
                            .foregroundStyle(KiioTheme.accent)
                    }
                    .frame(height: 210)

                    HStack(spacing: 8) {
                        Text(L10n.tr("device.pairing.scanHint", locale: appState.locale))
                            .font(.system(size: 13))
                            .foregroundStyle(KiioTheme.secondaryText)
                            .multilineTextAlignment(.center)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(KiioTheme.accent)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canOpenScanner)
        .opacity(canOpenScanner ? 1 : 0.58)
    }

    private var manualInput: some View {
        KiioCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(L10n.tr("device.pairing.manualTitle", locale: appState.locale), systemImage: "number.square")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KiioTheme.text)

                Text(L10n.tr("device.pairing.manualSub", locale: appState.locale))
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)

                TextField(L10n.tr("device.code.placeholder", locale: appState.locale), text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .kiioTextField()
                    .onChange(of: code) { value in
                        code = String(value.filter { $0.isNumber }.prefix(6))
                    }

                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        Text(character(at: index))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(KiioTheme.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(KiioTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                if !code.isEmpty && code.count < 6 {
                    Text(L10n.tr("device.pairing.codeInvalid", locale: appState.locale))
                        .font(.system(size: 12))
                        .foregroundStyle(KiioTheme.danger)
                }
            }
        }
    }

    private var selectedAgentId: String? {
        bootstrapStore.agents.first?.id
    }

    private var canOpenScanner: Bool {
        selectedAgentId != nil && !didBind && !deviceStore.isBinding
    }

    private var canSubmitManualCode: Bool {
        selectedAgentId != nil && code.count == 6 && !didBind
    }

    private func character(at index: Int) -> String {
        guard index < code.count else { return "" }
        let charIndex = code.index(code.startIndex, offsetBy: index)
        return String(code[charIndex])
    }

    private func bindDevice() async {
        guard let agentId = selectedAgentId else {
            alertMessage = L10n.tr("device.pairing.agentMissingMessage", locale: appState.locale)
            await refreshAgentContext(showFailure: false)
            return
        }

        guard code.count == 6 else {
            alertMessage = L10n.tr("device.pairing.codeInvalid", locale: appState.locale)
            return
        }

        if await deviceStore.bindDevice(agentId: agentId, code: code) {
            didBind = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onBound()
            }
        } else {
            alertMessage = deviceStore.errorMessage
        }
    }

    private func refreshAgentContext(showFailure: Bool = true) async {
        guard !isRefreshingAgent else { return }
        isRefreshingAgent = true
        defer { isRefreshingAgent = false }

        let didRefresh = await bootstrapStore.refresh()
        if showFailure && (!didRefresh || bootstrapStore.agents.isEmpty) {
            alertMessage = bootstrapStore.errorMessage ?? L10n.tr("device.pairing.agentStillMissing", locale: appState.locale)
        }
    }
}

private struct DeviceGuideStep: View {
    let number: Int
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(KiioTheme.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                Text(desc)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .foregroundStyle(KiioTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DeviceGuideAction: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KiioTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(KiioTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(KiioTheme.mutedText)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
