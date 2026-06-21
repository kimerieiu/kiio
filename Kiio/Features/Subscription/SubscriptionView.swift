import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        SubscriptionScene(store: SubscriptionStore(service: dependencies.subscriptionService))
    }
}

private struct SubscriptionScene: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var store: SubscriptionStore
    @State private var redeemCode = ""
    @State private var previewToConfirm: RedeemCodePreviewDTO?
    @State private var alertMessage: String?
    @FocusState private var isCodeFocused: Bool

    init(store: SubscriptionStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if store.isLoadingSubscription && store.subscription == nil {
                    KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                } else {
                    currentStatusCard
                }

                entitlementCard
                redeemCard
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("subscription.title", locale: appState.locale))
        .task {
            await loadCurrent(showError: true)
        }
        .refreshable {
            await loadCurrent(showError: true)
        }
        .alert(L10n.tr("subscription.confirmTitle", locale: appState.locale), isPresented: confirmBinding) {
            Button(L10n.tr("common.cancel", locale: appState.locale), role: .cancel) {}
            Button(L10n.tr("subscription.confirmAction", locale: appState.locale)) {
                Task { await redeemConfirmedCode() }
            }
        } message: {
            Text(confirmMessage)
        }
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
    }

    private var currentStatusCard: some View {
        KiioCard {
            HStack(alignment: .top, spacing: 14) {
                KiioIconBadge(systemImage: "crown", tone: statusTone, size: 52, iconSize: 22)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.tr("subscription.currentStatus", locale: appState.locale))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(KiioTheme.mutedText)
                            Text(planText)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(KiioTheme.text)
                                .lineLimit(1)
                        }

                        Spacer()
                        KiioStatusBadge(text: statusText(statusCode), tone: statusTone)
                    }

                    KiioDetailField(
                        title: L10n.tr("subscription.expireTime", locale: appState.locale),
                        value: formatDateTime(store.subscription?.expireTime)
                    )
                }
            }
        }
    }

    private var entitlementCard: some View {
        KiioCard {
            KiioSectionTitle(
                title: L10n.tr("subscription.entitlementsTitle", locale: appState.locale),
                icon: "sparkles"
            )

            VStack(spacing: 12) {
                entitlementRow(
                    icon: "wand.and.stars",
                    title: L10n.tr("subscription.enabledFeatures", locale: appState.locale),
                    value: enabledServicesText
                )
            }
        }
    }

    private func entitlementRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            KiioIconBadge(systemImage: icon, size: 38, iconSize: 15)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KiioTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private var redeemCard: some View {
        KiioCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    KiioIconBadge(systemImage: "key", size: 42, iconSize: 17)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(L10n.tr("subscription.redeemTitle", locale: appState.locale))
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(KiioTheme.text)
                        Text(L10n.tr("subscription.redeemDesc", locale: appState.locale))
                            .font(.system(size: 13))
                            .foregroundStyle(KiioTheme.secondaryText)
                            .lineSpacing(3)
                    }
                }

                TextField(L10n.tr("subscription.redeemPlaceholder", locale: appState.locale), text: $redeemCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isCodeFocused)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(KiioTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(KiioTheme.border, lineWidth: 1)
                    )
                    .foregroundStyle(KiioTheme.text)
                    .tint(KiioTheme.accent)

                Button {
                    Task { await previewCode() }
                } label: {
                    HStack(spacing: 8) {
                        if store.isPreviewing || store.isRedeeming {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }
                        Text(actionTitle)
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(actionDisabled ? KiioTheme.secondaryText : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(actionDisabled ? KiioTheme.disabledFill : KiioTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .disabled(actionDisabled)
            }
        }
    }

    private var confirmBinding: Binding<Bool> {
        Binding(
            get: { previewToConfirm != nil },
            set: { isPresented in
                if !isPresented {
                    previewToConfirm = nil
                }
            }
        )
    }

    private var confirmMessage: String {
        guard let preview = previewToConfirm else { return "" }
        return L10n.tr(
            "subscription.confirmMessage",
            locale: appState.locale,
            preview.planName ?? preview.planCode ?? "--",
            formatDateTime(preview.codeExpireTime) ?? "--"
        )
    }

    private var actionDisabled: Bool {
        trimmedCode.isEmpty || store.isPreviewing || store.isRedeeming
    }

    private var actionTitle: String {
        if store.isRedeeming {
            return L10n.tr("subscription.redeeming", locale: appState.locale)
        }
        if store.isPreviewing {
            return L10n.tr("subscription.previewing", locale: appState.locale)
        }
        return L10n.tr("subscription.redeemAction", locale: appState.locale)
    }

    private var trimmedCode: String {
        redeemCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var statusCode: String {
        store.subscription?.status ?? "active"
    }

    private var planText: String {
        if let effectivePlan = store.subscription?.effectivePlan, !effectivePlan.isEmpty {
            return effectivePlan
        }
        if let currentPlan = store.subscription?.currentPlan, !currentPlan.isEmpty {
            return currentPlan
        }
        return "free"
    }

    private var statusTone: KiioBadgeTone {
        switch statusCode {
        case "active":
            return .success
        case "grace_period":
            return .warning
        case "expired", "frozen", "canceled":
            return .danger
        default:
            return .muted
        }
    }

    private var enabledServicesText: String {
        let services = enabledServices()
        return services.isEmpty
            ? L10n.tr("subscription.noPremiumFeatures", locale: appState.locale)
            : services.joined(separator: " / ")
    }

    private func loadCurrent(showError: Bool) async {
        let ok = await store.loadCurrent()
        if !ok && showError {
            alertMessage = store.errorMessage
        }
    }

    private func previewCode() async {
        guard !trimmedCode.isEmpty else {
            alertMessage = L10n.tr("subscription.redeemEmpty", locale: appState.locale)
            return
        }

        let result = await store.preview(code: trimmedCode)
        guard let result else {
            alertMessage = store.errorMessage
            return
        }

        guard result.redeemable == true else {
            alertMessage = L10n.tr(
                "subscription.redeemUnavailable",
                locale: appState.locale,
                statusText(result.status ?? "--")
            )
            return
        }

        isCodeFocused = false
        previewToConfirm = result
    }

    private func redeemConfirmedCode() async {
        guard !trimmedCode.isEmpty else {
            alertMessage = L10n.tr("subscription.redeemEmpty", locale: appState.locale)
            return
        }

        let ok = await store.redeem(code: trimmedCode)
        if ok {
            redeemCode = ""
            alertMessage = L10n.tr("subscription.redeemSuccess", locale: appState.locale)
        } else {
            alertMessage = store.errorMessage
        }
    }

    private func enabledServices() -> [String] {
        let statuses = store.subscription?.featureSubscriptions ?? [:]
        let ordered: [(String, String)] = [
            ("accounting", L10n.tr("subscription.services.accounting", locale: appState.locale)),
            ("news", L10n.tr("subscription.services.news", locale: appState.locale)),
            ("outfit", L10n.tr("subscription.services.outfit", locale: appState.locale)),
            ("mail", L10n.tr("subscription.services.mail", locale: appState.locale))
        ]
        return ordered.compactMap { key, label in
            statuses[key]?.enabled == true ? label : nil
        }
    }

    private func statusText(_ status: String?) -> String {
        switch status {
        case "active":
            return L10n.tr("subscription.status.active", locale: appState.locale)
        case "grace_period":
            return L10n.tr("subscription.status.gracePeriod", locale: appState.locale)
        case "expired":
            return L10n.tr("subscription.status.expired", locale: appState.locale)
        case "canceled":
            return L10n.tr("subscription.status.canceled", locale: appState.locale)
        case "frozen":
            return L10n.tr("subscription.status.frozen", locale: appState.locale)
        case "unused":
            return L10n.tr("subscription.redeemStatus.unused", locale: appState.locale)
        case "redeemed":
            return L10n.tr("subscription.redeemStatus.redeemed", locale: appState.locale)
        case "invalidated":
            return L10n.tr("subscription.redeemStatus.invalidated", locale: appState.locale)
        default:
            return status ?? "--"
        }
    }

    private func formatDateTime(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        guard let date = DeviceConnectionHelper.date(from: value) else {
            return value
        }
        let formatter = DateFormatter()
        let localeId = appState.locale.hasPrefix("zh") ? "zh_CN" : "en_US"
        formatter.locale = Locale(identifier: localeId)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
