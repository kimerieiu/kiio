import SwiftUI

struct AccountingView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        AccountingListScene(store: AccountingStore(service: dependencies.accountingService))
    }
}

private struct AccountingListScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @StateObject private var store: AccountingStore

    init(store: AccountingStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        List {
            Section {
                KiioCard(padding: 8, radius: 16) {
                    Picker("", selection: Binding(
                        get: { store.selectedFilter },
                        set: { filter in Task { await store.selectFilter(filter) } }
                    )) {
                        ForEach(AccountingBillFilter.allCases) { filter in
                            Text(filterTitle(filter))
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .kiioListHeaderRow()
            }
            .listRowBackground(Color.clear)

            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if store.bills.isEmpty {
                KiioEmptyStateView(
                    systemImage: "wallet.pass",
                    title: L10n.tr("accounting.empty.title", locale: appState.locale),
                    message: L10n.tr("accounting.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            } else {
                Section(filterTitle(store.selectedFilter)) {
                    ForEach(store.bills) { bill in
                        billLink(bill)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await delete(bill) }
                                } label: {
                                    Label(L10n.tr("common.delete", locale: appState.locale), systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if bill.status == "pending_confirm" {
                                    Button {
                                        Task { await confirm(bill) }
                                    } label: {
                                        Label(L10n.tr("common.confirm", locale: appState.locale), systemImage: "checkmark")
                                    }
                                    .tint(KiioTheme.success)
                                }
                            }
                            .kiioListCardRow()
                    }

                    KiioPaginationFooter(
                        isLoading: store.isLoadingMore,
                        hasMore: store.hasMoreBills,
                        isEmpty: store.bills.isEmpty,
                        locale: appState.locale
                    ) {
                        Task { await store.loadMore() }
                    }
                    .kiioListCardRow()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("accounting.title", locale: appState.locale))
        .task { await refreshFromBackend() }
        .refreshable { await refreshFromBackend() }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .accountingBill else { return }
            Task { await refreshFromBackend(version: event?.version) }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.accountingBill, incomingVersion: version)
        guard await store.load(reset: true) else { return }
        syncStore.markSynced(.accountingBill, version: targetVersion)
        if syncStore.hasRemoteVersion(.accountingBill, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func filterTitle(_ filter: AccountingBillFilter) -> String {
        switch filter {
        case .all:
            return L10n.tr("common.all", locale: appState.locale)
        case .expense:
            return L10n.tr("accounting.filter.expense", locale: appState.locale)
        case .income:
            return L10n.tr("accounting.filter.income", locale: appState.locale)
        case .pendingConfirm:
            return L10n.tr("accounting.filter.pending", locale: appState.locale)
        }
    }

    private func billLink(_ bill: AccountingBillDTO) -> some View {
        NavigationLink {
            AccountingDetailView(billId: bill.id, store: store)
        } label: {
            AccountingBillRow(bill: bill)
        }
    }

    private func confirm(_ bill: AccountingBillDTO) async {
        if await store.confirm(id: bill.id) {
            await refreshFromBackend()
        }
    }

    private func delete(_ bill: AccountingBillDTO) async {
        if await store.delete(id: bill.id) {
            await refreshFromBackend()
        }
    }
}

private struct AccountingDetailView: View {
    let billId: String
    @ObservedObject var store: AccountingStore

    init(billId: String, store: AccountingStore) {
        self.billId = billId
        self.store = store
    }

    var body: some View {
        AccountingDetailScene(
            billId: billId,
            store: store
        )
    }
}

private struct AccountingDetailScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @Environment(\.dismiss) private var dismiss

    let billId: String
    @ObservedObject var store: AccountingStore
    @State private var isShowingEditForm = false

    init(billId: String, store: AccountingStore) {
        self.billId = billId
        self.store = store
    }

    var body: some View {
        List {
            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if let bill = store.detail {
                Section {
                    KiioCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                KiioIconBadge(systemImage: "wallet.pass", tone: typeTone(for: bill), size: 48, iconSize: 20)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(amountText(for: bill))
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundStyle(amountColor(for: bill))
                                    Text(bill.displayTitle)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(KiioTheme.text)
                                    if let status = bill.status {
                                        KiioStatusBadge(text: status, tone: statusTone(status))
                                    }
                                }
                            }
                        }
                    }
                }
                .kiioListCardRow()

                Section(L10n.tr("common.detail", locale: appState.locale)) {
                    labeled(L10n.tr("common.type", locale: appState.locale), bill.billType)
                    labeled(L10n.tr("common.category", locale: appState.locale), bill.categoryName ?? bill.categoryCode)
                    labeled(L10n.tr("accounting.account", locale: appState.locale), bill.accountName)
                    labeled(L10n.tr("accounting.toAccount", locale: appState.locale), bill.toAccountName)
                    labeled(L10n.tr("common.time", locale: appState.locale), bill.occurredAt)
                    labeled(L10n.tr("common.status", locale: appState.locale), bill.status)
                    labeled(L10n.tr("common.source", locale: appState.locale), bill.sourceType)
                    labeled(L10n.tr("accounting.tags", locale: appState.locale), bill.displayTags)
                    labeled(L10n.tr("common.createdAt", locale: appState.locale), bill.createdAt)
                }

                if let remark = bill.remark, !remark.isEmpty {
                    Section(L10n.tr("common.remark", locale: appState.locale)) {
                        Text(remark)
                            .foregroundStyle(KiioTheme.text)
                    }
                }

                if bill.status == "pending_confirm" {
                    Section {
                        KiioPrimaryButton(
                            title: L10n.tr("accounting.confirmBill", locale: appState.locale),
                            isLoading: store.isActionRunning
                        ) {
                            Task { await confirm() }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                KiioEmptyStateView(
                    systemImage: "wallet.pass",
                    title: L10n.tr("accounting.detail.empty.title", locale: appState.locale),
                    message: L10n.tr("accounting.detail.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("common.detail", locale: appState.locale))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShowingEditForm = true
                    Task { _ = await store.loadMetadata() }
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(store.detail == nil || store.isActionRunning)

                Button(role: .destructive) {
                    Task { await delete() }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.isActionRunning)
            }
        }
        .task { await loadDetailAndMetadata() }
        .refreshable { await loadDetailAndMetadata() }
        .onReceive(syncStore.$latestEvent) { event in
            guard let event,
                  event.notifyModule == .accountingBill,
                  event.matchesBizId(billId) else { return }
            Task { await loadDetailAndMetadata(version: event.version) }
        }
        .sheet(isPresented: $isShowingEditForm) {
            if let bill = store.detail {
                AccountingBillFormView(
                    bill: bill,
                    categories: store.categories,
                    accounts: store.accounts,
                    isLoadingMetadata: store.isLoadingMetadata
                ) { request in
                    await store.update(id: billId, request: request)
                } onSaved: {
                    await loadDetailAndMetadata()
                    _ = await store.load(reset: true, silent: true)
                }
            }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func loadDetailAndMetadata(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.accountingBill, incomingVersion: version)
        guard await store.loadDetail(id: billId) else { return }
        if store.categories.isEmpty || store.accounts.isEmpty {
            _ = await store.loadMetadata()
        }
        syncStore.markSynced(.accountingBill, version: targetVersion)
        if syncStore.hasRemoteVersion(.accountingBill, after: targetVersion) {
            await loadDetailAndMetadata()
        }
    }

    private func confirm() async {
        guard await store.confirm(id: billId) else { return }
        await loadDetailAndMetadata()
        _ = await store.load(reset: true, silent: true)
    }

    private func delete() async {
        guard await store.delete(id: billId) else { return }
        _ = await store.load(reset: true, silent: true)
        dismiss()
    }

    private func amountText(for bill: AccountingBillDTO) -> String {
        let sign: String
        switch bill.billType {
        case "income":
            sign = "+"
        case "transfer":
            sign = ""
        default:
            sign = "-"
        }
        return "\(sign)\(bill.displayAmount)"
    }

    private func amountColor(for bill: AccountingBillDTO) -> Color {
        switch bill.billType {
        case "income":
            return KiioTheme.success
        case "transfer":
            return KiioTheme.accent
        default:
            return KiioTheme.danger
        }
    }

    private func typeTone(for bill: AccountingBillDTO) -> KiioBadgeTone {
        switch bill.billType {
        case "income":
            return .success
        case "transfer":
            return .accent
        default:
            return .danger
        }
    }

    private func statusTone(_ status: String) -> KiioBadgeTone {
        status == "pending_confirm" ? .warning : .accent
    }

    private func labeled(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
            Spacer()
            Text(value?.isEmpty == false ? value! : "--")
                .foregroundStyle(KiioTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct AccountingBillFormView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let bill: AccountingBillDTO
    let categories: [AccountingCategoryDTO]
    let accounts: [AccountingPaymentAccountDTO]
    let isLoadingMetadata: Bool
    let onSubmit: (AccountingBillUpdateRequest) async -> Bool
    let onSaved: () async -> Void

    @State private var billType: String
    @State private var amount: String
    @State private var currency: String
    @State private var title: String
    @State private var categoryId: String
    @State private var accountId: String
    @State private var toAccountId: String
    @State private var updatesOccurredAt: Bool
    @State private var occurredAt: Date
    @State private var remark: String
    @State private var status: String
    @State private var includeStatistics: Bool
    @State private var tagsText: String
    @State private var isSaving = false
    @State private var alertMessage: String?

    init(
        bill: AccountingBillDTO,
        categories: [AccountingCategoryDTO],
        accounts: [AccountingPaymentAccountDTO],
        isLoadingMetadata: Bool,
        onSubmit: @escaping (AccountingBillUpdateRequest) async -> Bool,
        onSaved: @escaping () async -> Void
    ) {
        self.bill = bill
        self.categories = categories
        self.accounts = accounts
        self.isLoadingMetadata = isLoadingMetadata
        self.onSubmit = onSubmit
        self.onSaved = onSaved

        _billType = State(initialValue: bill.billType ?? "expense")
        _amount = State(initialValue: Self.amountString(from: bill.amount))
        _currency = State(initialValue: bill.currency ?? "CNY")
        _title = State(initialValue: bill.title ?? "")
        _categoryId = State(initialValue: bill.categoryId ?? "")
        _accountId = State(initialValue: bill.accountId ?? "")
        _toAccountId = State(initialValue: bill.toAccountId ?? "")
        let parsedOccurredAt = AccountingDateFormatter.date(from: bill.occurredAt)
        _updatesOccurredAt = State(initialValue: parsedOccurredAt != nil)
        _occurredAt = State(initialValue: parsedOccurredAt ?? Date())
        _remark = State(initialValue: bill.remark ?? "")
        _status = State(initialValue: bill.status ?? "confirmed")
        _includeStatistics = State(initialValue: bill.includeStatistics ?? true)
        _tagsText = State(initialValue: Self.tagsString(from: bill))
    }

    var body: some View {
        NavigationStack {
            Form {
                if isLoadingMetadata {
                    ProgressView(L10n.tr("common.loading", locale: appState.locale))
                }

                Section(L10n.tr("accounting.basicInfo", locale: appState.locale)) {
                    Picker(L10n.tr("common.type", locale: appState.locale), selection: $billType) {
                        ForEach(["expense", "income", "transfer"], id: \.self) { type in
                            Text(typeTitle(type))
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: billType) { _ in
                        normalizeSelectionForType()
                    }

                    TextField(L10n.tr("accounting.amount", locale: appState.locale), text: $amount)
                        .keyboardType(.decimalPad)
                    TextField(L10n.tr("accounting.currency", locale: appState.locale), text: $currency)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField(L10n.tr("accounting.billTitle", locale: appState.locale), text: $title)
                }

                Section(L10n.tr("accounting.classification", locale: appState.locale)) {
                    if billType == "transfer" {
                        Text(L10n.tr("accounting.transferNoCategory", locale: appState.locale))
                            .font(.system(size: 12))
                            .foregroundStyle(KiioTheme.secondaryText)
                    } else {
                        Picker(L10n.tr("common.category", locale: appState.locale), selection: $categoryId) {
                            Text(L10n.tr("common.notSet", locale: appState.locale))
                                .tag("")
                            ForEach(filteredCategories) { category in
                                Text(category.displayName)
                                    .tag(category.id)
                            }
                        }
                    }

                    Picker(accountTitle, selection: $accountId) {
                        Text(L10n.tr("common.notSet", locale: appState.locale))
                            .tag("")
                        ForEach(accounts) { account in
                            Text(account.displayName)
                                .tag(account.id)
                        }
                    }

                    if billType == "transfer" {
                        Picker(L10n.tr("accounting.toAccount", locale: appState.locale), selection: $toAccountId) {
                            Text(L10n.tr("common.notSet", locale: appState.locale))
                                .tag("")
                            ForEach(accounts) { account in
                                Text(account.displayName)
                                    .tag(account.id)
                            }
                        }
                    }
                }

                Section(L10n.tr("accounting.transaction", locale: appState.locale)) {
                    Toggle(L10n.tr("accounting.updateOccurredAt", locale: appState.locale), isOn: $updatesOccurredAt)
                    if updatesOccurredAt {
                        DatePicker(
                            L10n.tr("accounting.occurredAt", locale: appState.locale),
                            selection: $occurredAt,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                    Picker(L10n.tr("common.status", locale: appState.locale), selection: $status) {
                        ForEach(["pending_confirm", "confirmed"], id: \.self) { value in
                            Text(statusTitle(value))
                                .tag(value)
                        }
                    }
                    Toggle(L10n.tr("accounting.includeStatistics", locale: appState.locale), isOn: $includeStatistics)
                }

                Section(L10n.tr("accounting.tags", locale: appState.locale)) {
                    TextField(L10n.tr("accounting.tagsHint", locale: appState.locale), text: $tagsText)
                        .textInputAutocapitalization(.never)
                }

                Section(L10n.tr("common.remark", locale: appState.locale)) {
                    TextEditor(text: $remark)
                        .frame(minHeight: 88)
                }
            }
            .navigationTitle(L10n.tr("accounting.editBill", locale: appState.locale))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(KiioTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.tr("common.cancel", locale: appState.locale)) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.tr("common.save", locale: appState.locale)) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
        }
    }

    private var filteredCategories: [AccountingCategoryDTO] {
        categories.filter { $0.categoryType == billType }
    }

    private var accountTitle: String {
        billType == "transfer"
        ? L10n.tr("accounting.fromAccount", locale: appState.locale)
        : L10n.tr("accounting.account", locale: appState.locale)
    }

    private func normalizeSelectionForType() {
        if billType == "transfer" {
            categoryId = ""
            return
        }

        if !categoryId.isEmpty,
           !filteredCategories.contains(where: { $0.id == categoryId }) {
            categoryId = ""
        }
        toAccountId = ""
    }

    private func save() async {
        guard let request = buildRequest() else { return }

        isSaving = true
        defer { isSaving = false }

        guard await onSubmit(request) else {
            alertMessage = L10n.tr("accounting.saveFailed", locale: appState.locale)
            return
        }

        await onSaved()
        dismiss()
    }

    private func buildRequest() -> AccountingBillUpdateRequest? {
        let normalizedAmount = amount
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let amountValue = Decimal(string: normalizedAmount, locale: Locale(identifier: "en_US_POSIX")),
              amountValue > Decimal(0) else {
            alertMessage = L10n.tr("accounting.errorAmount", locale: appState.locale)
            return nil
        }

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTitle.isEmpty else {
            alertMessage = L10n.tr("accounting.errorTitle", locale: appState.locale)
            return nil
        }

        if billType == "transfer" {
            guard !accountId.isEmpty, !toAccountId.isEmpty, accountId != toAccountId else {
                alertMessage = L10n.tr("accounting.errorTransferAccounts", locale: appState.locale)
                return nil
            }
        }

        let selectedCategory = categories.first(where: { $0.id == categoryId })
        let selectedAccount = accounts.first(where: { $0.id == accountId })
        let normalizedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedRemark = remark.trimmingCharacters(in: .whitespacesAndNewlines)

        return AccountingBillUpdateRequest(
            billType: billType,
            amount: amountValue,
            currency: normalizedCurrency.isEmpty ? "CNY" : normalizedCurrency,
            title: normalizedTitle,
            categoryId: billType == "transfer" || categoryId.isEmpty ? nil : categoryId,
            categoryCode: billType == "transfer" ? nil : selectedCategory?.categoryCode,
            accountId: accountId.isEmpty ? nil : accountId,
            accountType: selectedAccount?.accountType,
            toAccountId: billType == "transfer" && !toAccountId.isEmpty ? toAccountId : nil,
            occurredAt: updatesOccurredAt ? AccountingDateFormatter.backendString(from: occurredAt) : nil,
            remark: normalizedRemark,
            status: status,
            includeStatistics: includeStatistics,
            tagNames: normalizedTags()
        )
    }

    private func normalizedTags() -> [String] {
        tagsText
            .replacingOccurrences(of: "\u{FF0C}", with: ",")
            .replacingOccurrences(of: " / ", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func typeTitle(_ type: String) -> String {
        switch type {
        case "income":
            return L10n.tr("accounting.type.income", locale: appState.locale)
        case "transfer":
            return L10n.tr("accounting.type.transfer", locale: appState.locale)
        default:
            return L10n.tr("accounting.type.expense", locale: appState.locale)
        }
    }

    private func statusTitle(_ value: String) -> String {
        value == "pending_confirm"
        ? L10n.tr("accounting.status.pending", locale: appState.locale)
        : L10n.tr("accounting.status.confirmed", locale: appState.locale)
    }

    private static func amountString(from amount: Decimal?) -> String {
        guard let amount else { return "" }
        return NSDecimalNumber(decimal: amount).stringValue
    }

    private static func tagsString(from bill: AccountingBillDTO) -> String {
        if let tagNames = bill.tagNames, !tagNames.isEmpty {
            return tagNames.joined(separator: ", ")
        }
        let names = bill.tags?.compactMap { $0.displayName }.filter { !$0.isEmpty } ?? []
        return names.joined(separator: ", ")
    }
}

private enum AccountingDateFormatter {
    private static let backendFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let backendMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        if let date = backendFormatter.date(from: value) {
            return date
        }
        if let date = backendMinuteFormatter.date(from: value) {
            return date
        }
        let normalized = value.replacingOccurrences(of: " ", with: "T")
        return isoFormatter.date(from: normalized) ?? fallbackISOFormatter.date(from: normalized)
    }

    static func backendString(from date: Date) -> String {
        backendFormatter.string(from: date)
    }
}

private struct AccountingBillRow: View {
    let bill: AccountingBillDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KiioIconBadge(systemImage: iconName, tone: tone, size: 42, iconSize: 17)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(bill.displayTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(2)
                    Spacer()
                    Text(amountText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tone.color)
                }

                HStack(spacing: 6) {
                    if let billType = bill.billType {
                        KiioMetaPill(icon: nil, text: billType, tone: tone)
                    }
                    if let accountName = bill.accountName {
                        KiioMetaPill(icon: "creditcard", text: accountName)
                    }
                }

                if let occurredAt = bill.occurredAt {
                    KiioMetaPill(icon: "clock", text: occurredAt)
                }

                if bill.status == "pending_confirm" {
                    KiioStatusBadge(text: bill.status ?? "", tone: .warning)
                }
            }
        }
        .padding(15)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.8), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 12, y: 6)
    }

    private var amountText: String {
        switch bill.billType {
        case "income":
            return "+\(bill.displayAmount)"
        case "transfer":
            return bill.displayAmount
        default:
            return "-\(bill.displayAmount)"
        }
    }

    private var iconName: String {
        switch bill.billType {
        case "income":
            return "arrow.down.left"
        case "transfer":
            return "arrow.left.arrow.right"
        default:
            return "arrow.up.right"
        }
    }

    private var tone: KiioBadgeTone {
        switch bill.billType {
        case "income":
            return .success
        case "transfer":
            return .accent
        default:
            return .danger
        }
    }
}
