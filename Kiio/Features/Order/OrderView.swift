import SwiftUI

struct OrderView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        OrderListScene(store: OrderStore(service: dependencies.orderService))
    }
}

private struct OrderListScene: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var store: OrderStore

    init(store: OrderStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        List {
            if store.isLoading && store.orders.isEmpty {
                KiioLoadingCard(message: L10n.tr("orders.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if store.orders.isEmpty {
                KiioEmptyStateView(
                    systemImage: "receipt",
                    title: L10n.tr("orders.empty.title", locale: appState.locale),
                    message: L10n.tr("orders.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            } else {
                ForEach(store.orders) { order in
                    NavigationLink {
                        OrderDetailView(order: order, store: store)
                            .kiioHidesTabBar()
                    } label: {
                        OrderRow(order: order, locale: appState.locale)
                    }
                    .buttonStyle(.plain)
                    .kiioListCardRow()
                }

                KiioPaginationFooter(
                    isLoading: store.isLoadingMore,
                    hasMore: store.hasMoreOrders,
                    isEmpty: store.orders.isEmpty,
                    locale: appState.locale
                ) {
                    Task { await store.loadMore() }
                }
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("orders.title", locale: appState.locale))
        .kiioHidesTabBar()
        .task {
            if store.orders.isEmpty {
                _ = await store.load()
            }
        }
        .refreshable {
            _ = await store.load(reset: true)
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }
}

private struct OrderRow: View {
    let order: ShopifyOrderDTO
    let locale: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            KiioIconBadge(systemImage: planIcon, tone: statusTone, size: 48, iconSize: 19)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(primaryTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    KiioStatusBadge(text: statusText, tone: statusTone)
                }

                Text(orderNumber)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(KiioTheme.mutedText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let item = order.items.first {
                        Text(billingText(item.billingCycle))
                        if item.quantity > 1 {
                            Text(L10n.tr("orders.quantityShort", locale: locale, item.quantity))
                        }
                    }

                    Spacer(minLength: 8)

                    if let date = OrderDisplayFormatter.date(order.processedAt, locale: locale) {
                        Text(date)
                    }

                    if let amount = OrderDisplayFormatter.money(
                        order.totalAmount,
                        currency: order.currency,
                        locale: locale
                    ) {
                        Text(amount)
                            .fontWeight(.semibold)
                            .foregroundStyle(KiioTheme.text)
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(KiioTheme.secondaryText)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.025), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var firstItem: ShopifyOrderItemDTO? {
        order.items.first
    }

    private var primaryTitle: String {
        nonEmpty(firstItem?.title)
            ?? nonEmpty(firstItem?.planName)
            ?? nonEmpty(firstItem?.planCode)
            ?? L10n.tr("orders.subscriptionItem", locale: locale)
    }

    private var orderNumber: String {
        nonEmpty(order.orderNo) ?? order.id
    }

    private var planIcon: String {
        switch firstItem?.planCode {
        case "accounting":
            return "wallet.pass"
        case "news":
            return "newspaper"
        case "outfit":
            return "tshirt"
        case "mail":
            return "envelope"
        default:
            return "receipt"
        }
    }

    private var statusTone: KiioBadgeTone {
        if order.refundStatus == "completed" {
            return .danger
        }
        if order.refundStatus == "partial" {
            return .warning
        }
        return order.paymentStatus == "paid" ? .success : .warning
    }

    private var statusText: String {
        if order.refundStatus == "completed" {
            return L10n.tr("orders.status.refunded", locale: locale)
        }
        if order.refundStatus == "partial" {
            return L10n.tr("orders.status.partiallyRefunded", locale: locale)
        }
        if order.paymentStatus == "paid" {
            return L10n.tr("orders.status.paid", locale: locale)
        }
        return L10n.tr("orders.status.processing", locale: locale)
    }

    private func billingText(_ billingCycle: String?) -> String {
        switch billingCycle {
        case "month":
            return L10n.tr("subscription.billing.month", locale: locale)
        case "year":
            return L10n.tr("subscription.billing.year", locale: locale)
        case "lifetime":
            return L10n.tr("subscription.billing.lifetime", locale: locale)
        case "trial":
            return L10n.tr("subscription.billing.trial", locale: locale)
        default:
            return billingCycle ?? "--"
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private struct OrderDetailView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var store: OrderStore

    let initialOrder: ShopifyOrderDTO

    init(order: ShopifyOrderDTO, store: OrderStore) {
        initialOrder = order
        self.store = store
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if store.isLoading && currentOrder == nil {
                    KiioLoadingCard(message: L10n.tr("orders.loadingDetail", locale: appState.locale))
                } else if let order = currentOrder {
                    statusCard(order)
                    itemSection(order)
                    summarySection(order)
                } else {
                    KiioEmptyStateView(
                        systemImage: "receipt",
                        title: L10n.tr("orders.detail.empty.title", locale: appState.locale),
                        message: L10n.tr("orders.detail.empty.message", locale: appState.locale)
                    )
                    .padding(.top, 80)
                }
            }
            .padding(20)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .navigationTitle(L10n.tr("orders.detail.title", locale: appState.locale))
        .navigationBarTitleDisplayMode(.inline)
        .kiioHidesTabBar()
        .task {
            _ = await store.loadDetail(id: initialOrder.id)
        }
        .refreshable {
            _ = await store.loadDetail(id: initialOrder.id)
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private var currentOrder: ShopifyOrderDTO? {
        if let detail = store.detail, detail.id == initialOrder.id {
            return detail
        }
        return initialOrder
    }

    private func statusCard(_ order: ShopifyOrderDTO) -> some View {
        let refunded = order.refundStatus == "completed"
        let partiallyRefunded = order.refundStatus == "partial"
        let paid = order.paymentStatus == "paid"
        let tone: KiioBadgeTone = refunded ? .danger : (partiallyRefunded ? .warning : (paid ? .success : .warning))
        let title: String
        if refunded {
            title = L10n.tr("orders.status.refunded", locale: appState.locale)
        } else if partiallyRefunded {
            title = L10n.tr("orders.status.partiallyRefunded", locale: appState.locale)
        } else {
            title = L10n.tr(paid ? "orders.status.paid" : "orders.status.processing", locale: appState.locale)
        }

        return KiioCard {
            HStack(alignment: .top, spacing: 14) {
                KiioIconBadge(
                    systemImage: refunded
                        ? "arrow.uturn.backward.circle"
                        : (partiallyRefunded ? "exclamationmark.circle" : "checkmark.seal"),
                    tone: tone,
                    size: 52,
                    iconSize: 22
                )

                VStack(alignment: .leading, spacing: 8) {
                    KiioStatusBadge(text: title, tone: tone)
                    Text(nonEmpty(order.orderNo) ?? order.id)
                        .font(.system(size: 21, weight: .bold, design: .monospaced))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(1)

                    if let amount = OrderDisplayFormatter.money(
                        order.totalAmount,
                        currency: order.currency,
                        locale: appState.locale
                    ) {
                        Text(amount)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(KiioTheme.accent)
                    }
                }

                Spacer()
            }
        }
    }

    private func itemSection(_ order: ShopifyOrderDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            KiioSectionTitle(
                title: L10n.tr("orders.items", locale: appState.locale),
                icon: "bag"
            )

            ForEach(order.items) { item in
                orderItemCard(item, fallbackCurrency: order.currency)
            }
        }
    }

    private func orderItemCard(_ item: ShopifyOrderItemDTO, fallbackCurrency: String?) -> some View {
        let invalidated = item.redemptionStatus == "invalidated"
        let partiallyInvalidated = item.redemptionStatus == "partial"
        return KiioCard {
            HStack(alignment: .top, spacing: 13) {
                KiioIconBadge(
                    systemImage: itemIcon(item.planCode),
                    tone: invalidated ? .danger : (partiallyInvalidated ? .warning : .accent),
                    size: 44,
                    iconSize: 18
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(nonEmpty(item.title) ?? nonEmpty(item.planName) ?? item.planCode ?? "--")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KiioTheme.text)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 6)

                        KiioStatusBadge(
                            text: L10n.tr(
                                invalidated
                                    ? "orders.redemption.invalidated"
                                    : (partiallyInvalidated
                                        ? "orders.redemption.partial"
                                        : "orders.redemption.redeemed"),
                                locale: appState.locale
                            ),
                            tone: invalidated ? .danger : (partiallyInvalidated ? .warning : .success)
                        )
                    }

                    HStack(spacing: 8) {
                        Text(billingText(item.billingCycle))
                        Text(L10n.tr("orders.quantity", locale: appState.locale, item.quantity))
                        if let days = item.serviceDurationDays {
                            Text(L10n.tr("orders.durationDays", locale: appState.locale, days))
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)

                    if let price = OrderDisplayFormatter.money(
                        item.unitAmount,
                        currency: item.currency ?? fallbackCurrency,
                        locale: appState.locale
                    ) {
                        Text(L10n.tr("orders.unitPriceValue", locale: appState.locale, price))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(KiioTheme.accent)
                    }
                }
            }
        }
    }

    private func summarySection(_ order: ShopifyOrderDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            KiioSectionTitle(
                title: L10n.tr("orders.summary", locale: appState.locale),
                icon: "list.bullet.rectangle"
            )

            KiioCard {
                KiioDetailField(
                    title: L10n.tr("orders.number", locale: appState.locale),
                    value: nonEmpty(order.orderNo) ?? order.id
                )
                Divider()
                KiioDetailField(
                    title: L10n.tr("orders.paymentStatus", locale: appState.locale),
                    value: paymentStatusText(order.paymentStatus)
                )
                Divider()
                KiioDetailField(
                    title: L10n.tr("orders.refundStatus", locale: appState.locale),
                    value: refundStatusText(order.refundStatus)
                )
                Divider()
                KiioDetailField(
                    title: L10n.tr("orders.purchaseTime", locale: appState.locale),
                    value: OrderDisplayFormatter.dateTime(order.processedAt, locale: appState.locale)
                )
                Divider()
                KiioDetailField(
                    title: L10n.tr("orders.redeemedTime", locale: appState.locale),
                    value: OrderDisplayFormatter.dateTime(order.redeemedTime, locale: appState.locale)
                )
            }
        }
    }

    private func itemIcon(_ planCode: String?) -> String {
        switch planCode {
        case "accounting": return "wallet.pass"
        case "news": return "newspaper"
        case "outfit": return "tshirt"
        case "mail": return "envelope"
        default: return "bag"
        }
    }

    private func billingText(_ billingCycle: String?) -> String {
        switch billingCycle {
        case "month": return L10n.tr("subscription.billing.month", locale: appState.locale)
        case "year": return L10n.tr("subscription.billing.year", locale: appState.locale)
        case "lifetime": return L10n.tr("subscription.billing.lifetime", locale: appState.locale)
        case "trial": return L10n.tr("subscription.billing.trial", locale: appState.locale)
        default: return billingCycle ?? "--"
        }
    }

    private func paymentStatusText(_ status: String?) -> String {
        status == "paid"
            ? L10n.tr("orders.status.paid", locale: appState.locale)
            : L10n.tr("orders.status.processing", locale: appState.locale)
    }

    private func refundStatusText(_ status: String?) -> String {
        switch status {
        case "completed":
            return L10n.tr("orders.status.refunded", locale: appState.locale)
        case "partial":
            return L10n.tr("orders.status.partiallyRefunded", locale: appState.locale)
        default:
            return L10n.tr("orders.refund.none", locale: appState.locale)
        }
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private enum OrderDisplayFormatter {
    static func money(_ amount: Decimal?, currency: String?, locale: String) -> String? {
        guard let amount else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: locale.hasPrefix("zh") ? "zh_CN" : "en_US")
        formatter.numberStyle = .currency
        formatter.currencyCode = currency?.uppercased() ?? "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }

    static func date(_ value: String?, locale: String) -> String? {
        format(value, locale: locale, pattern: "yyyy-MM-dd")
    }

    static func dateTime(_ value: String?, locale: String) -> String? {
        format(value, locale: locale, pattern: "yyyy-MM-dd HH:mm")
    }

    private static func format(_ value: String?, locale: String, pattern: String) -> String? {
        guard let value, !value.isEmpty else { return nil }
        guard let date = DeviceConnectionHelper.date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.hasPrefix("zh") ? "zh_CN" : "en_US")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
