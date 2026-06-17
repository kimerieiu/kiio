import SwiftUI

struct MailView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        MailListScene(store: MailStore(service: dependencies.mailService))
    }
}

private struct MailListScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @StateObject private var store: MailStore
    @State private var isShowingAccountForm = false
    @State private var editingAccount: MailAccountDTO?

    init(store: MailStore) {
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        List {
            Section {
                KiioCard(padding: 8, radius: 16) {
                    Picker("", selection: Binding(
                        get: { store.selectedOperationFilter },
                        set: { filter in Task { await store.selectOperationFilter(filter) } }
                    )) {
                        ForEach(MailOperationFilter.allCases) { filter in
                            Text(operationFilterTitle(filter))
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
            } else if store.accounts.isEmpty && store.operations.isEmpty {
                KiioEmptyStateView(
                    systemImage: "envelope",
                    title: L10n.tr("mail.empty.title", locale: appState.locale),
                    message: L10n.tr("mail.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            } else {
                Section(L10n.tr("mail.accounts", locale: appState.locale)) {
                    if store.accounts.isEmpty {
                        KiioCard {
                            Text(L10n.tr("mail.noAccounts", locale: appState.locale))
                                .font(.system(size: 14))
                                .foregroundStyle(KiioTheme.secondaryText)
                        }
                        .kiioListCardRow()
                    } else {
                        ForEach(store.accounts) { account in
                            NavigationLink {
                                MailAccountDetailView(accountId: account.id, store: store)
                            } label: {
                                MailAccountRow(account: account)
                            }
                            .swipeActions {
                                Button {
                                    editingAccount = account
                                    isShowingAccountForm = true
                                } label: {
                                    Label(L10n.tr("common.edit", locale: appState.locale), systemImage: "pencil")
                                }
                                .tint(KiioTheme.accent)

                                Button {
                                    Task { await setDefault(account) }
                                } label: {
                                    Label(L10n.tr("mail.setDefault", locale: appState.locale), systemImage: "star")
                                }
                                .tint(KiioTheme.accent)

                                Button(role: .destructive) {
                                    Task { await deleteAccount(account) }
                                } label: {
                                    Label(L10n.tr("common.delete", locale: appState.locale), systemImage: "trash")
                                }
                            }
                            .kiioListCardRow()
                        }
                    }
                }

                Section(L10n.tr("mail.operations", locale: appState.locale)) {
                    if store.operations.isEmpty {
                        KiioCard {
                            Text(L10n.tr("mail.noOperations", locale: appState.locale))
                                .font(.system(size: 14))
                                .foregroundStyle(KiioTheme.secondaryText)
                        }
                        .kiioListCardRow()
                    } else {
                        ForEach(store.operations) { operation in
                            NavigationLink {
                                MailOperationDetailView(operationId: operation.id, store: store)
                            } label: {
                                MailOperationRow(operation: operation)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await deleteOperation(operation) }
                                } label: {
                                    Label(L10n.tr("common.delete", locale: appState.locale), systemImage: "trash")
                                }
                            }
                            .kiioListCardRow()
                        }

                        KiioPaginationFooter(
                            isLoading: store.isLoadingMore,
                            hasMore: store.hasMoreOperations,
                            isEmpty: store.operations.isEmpty,
                            locale: appState.locale
                        ) {
                            Task { await store.loadMoreOperations() }
                        }
                        .kiioListCardRow()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("mail.title", locale: appState.locale))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingAccount = nil
                    isShowingAccountForm = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await refreshFromBackend() }
        .refreshable { await refreshFromBackend() }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .mailOperation else { return }
            Task { await refreshFromBackend(version: event?.version) }
        }
        .sheet(isPresented: $isShowingAccountForm) {
            MailAccountFormView(
                account: editingAccount,
                hasExistingAccounts: !store.accounts.isEmpty
            ) { request in
                if let editingAccount {
                    return await store.updateAccount(id: editingAccount.id, request: request)
                }
                return await store.createAccount(request)
            } onSaved: {
                await refreshFromBackend()
            }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.mailOperation, incomingVersion: version)
        guard await store.load(reset: true) else { return }
        syncStore.markSynced(.mailOperation, version: targetVersion)
        if syncStore.hasRemoteVersion(.mailOperation, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func setDefault(_ account: MailAccountDTO) async {
        if await store.setDefaultAccount(id: account.id) {
            await refreshFromBackend()
        }
    }

    private func deleteAccount(_ account: MailAccountDTO) async {
        if await store.deleteAccount(id: account.id) {
            await refreshFromBackend()
        }
    }

    private func deleteOperation(_ operation: MailOperationDTO) async {
        if await store.deleteOperation(id: operation.id) {
            await refreshFromBackend()
        }
    }

    private func operationFilterTitle(_ filter: MailOperationFilter) -> String {
        switch filter {
        case .all:
            return L10n.tr("common.all", locale: appState.locale)
        case .success:
            return L10n.tr("mail.filter.success", locale: appState.locale)
        case .failed:
            return L10n.tr("mail.filter.failed", locale: appState.locale)
        case .pendingConfirm:
            return L10n.tr("mail.filter.pending", locale: appState.locale)
        }
    }
}

private struct MailAccountFormView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let account: MailAccountDTO?
    let hasExistingAccounts: Bool
    let onSubmit: (MailAccountSaveRequest) async -> Bool
    let onSaved: () async -> Void

    @State private var email: String
    @State private var authCode = ""
    @State private var imapServer: String
    @State private var imapPort: String
    @State private var smtpServer: String
    @State private var smtpPort: String
    @State private var isEnabled: Bool
    @State private var isDefault: Bool
    @State private var isSaving = false
    @State private var alertMessage: String?

    init(
        account: MailAccountDTO?,
        hasExistingAccounts: Bool,
        onSubmit: @escaping (MailAccountSaveRequest) async -> Bool,
        onSaved: @escaping () async -> Void
    ) {
        self.account = account
        self.hasExistingAccounts = hasExistingAccounts
        self.onSubmit = onSubmit
        self.onSaved = onSaved

        _email = State(initialValue: account?.email ?? "")
        _imapServer = State(initialValue: account?.imapServer ?? "")
        _imapPort = State(initialValue: account?.imapPort.map { String($0) } ?? "993")
        _smtpServer = State(initialValue: account?.smtpServer ?? "")
        _smtpPort = State(initialValue: account?.smtpPort.map { String($0) } ?? "587")
        _isEnabled = State(initialValue: account?.enabled != 0)
        _isDefault = State(initialValue: account?.isDefault == 1 || (account == nil && !hasExistingAccounts))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("mail.account", locale: appState.locale)) {
                    TextField(L10n.tr("mail.email", locale: appState.locale), text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField(authCodePlaceholder, text: $authCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("IMAP") {
                    TextField(L10n.tr("mail.imapServer", locale: appState.locale), text: $imapServer)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(L10n.tr("mail.imapPort", locale: appState.locale), text: $imapPort)
                        .keyboardType(.numberPad)
                }

                Section("SMTP") {
                    TextField(L10n.tr("mail.smtpServer", locale: appState.locale), text: $smtpServer)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(L10n.tr("mail.smtpPort", locale: appState.locale), text: $smtpPort)
                        .keyboardType(.numberPad)
                }

                Section(L10n.tr("device.settings", locale: appState.locale)) {
                    Toggle(L10n.tr("mail.enabled", locale: appState.locale), isOn: $isEnabled)
                        .onChange(of: isEnabled) { enabled in
                            if !enabled {
                                isDefault = false
                            }
                        }
                    Toggle(L10n.tr("mail.setAsDefault", locale: appState.locale), isOn: $isDefault)
                        .onChange(of: isDefault) { value in
                            if value {
                                isEnabled = true
                            }
                        }
                }

                if account != nil {
                    Section {
                        Text(L10n.tr("mail.authCodeOptionalHint", locale: appState.locale))
                            .font(.system(size: 12))
                            .foregroundStyle(KiioTheme.secondaryText)
                    }
                }
            }
            .navigationTitle(account == nil ? L10n.tr("mail.addAccount", locale: appState.locale) : L10n.tr("mail.editAccount", locale: appState.locale))
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

    private var authCodePlaceholder: String {
        account == nil
        ? L10n.tr("mail.authCode", locale: appState.locale)
        : L10n.tr("mail.authCodeOptional", locale: appState.locale)
    }

    private func save() async {
        guard let request = buildRequest() else { return }

        isSaving = true
        defer { isSaving = false }

        guard await onSubmit(request) else {
            alertMessage = L10n.tr("mail.saveFailed", locale: appState.locale)
            return
        }

        await onSaved()
        dismiss()
    }

    private func buildRequest() -> MailAccountSaveRequest? {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAuthCode = authCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedImap = imapServer.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSmtp = smtpServer.trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalizedEmail.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil else {
            alertMessage = L10n.tr("mail.errorEmail", locale: appState.locale)
            return nil
        }
        guard account != nil || !normalizedAuthCode.isEmpty else {
            alertMessage = L10n.tr("mail.errorAuthCode", locale: appState.locale)
            return nil
        }
        guard !normalizedImap.isEmpty else {
            alertMessage = L10n.tr("mail.errorImapServer", locale: appState.locale)
            return nil
        }
        guard !normalizedSmtp.isEmpty else {
            alertMessage = L10n.tr("mail.errorSmtpServer", locale: appState.locale)
            return nil
        }
        guard let imapPortValue = normalizedPort(imapPort),
              let smtpPortValue = normalizedPort(smtpPort) else {
            alertMessage = L10n.tr("mail.errorPort", locale: appState.locale)
            return nil
        }

        return MailAccountSaveRequest(
            email: normalizedEmail,
            imapServer: normalizedImap,
            imapPort: imapPortValue,
            smtpServer: normalizedSmtp,
            smtpPort: smtpPortValue,
            authCode: normalizedAuthCode.isEmpty ? nil : normalizedAuthCode,
            isDefault: isDefault ? 1 : 0,
            enabled: isEnabled ? 1 : 0
        )
    }

    private func normalizedPort(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let port = Int(trimmed), port > 0, port <= 65_535 else {
            return nil
        }
        return port
    }
}

private struct MailAccountDetailView: View {
    let accountId: String
    @ObservedObject var store: MailStore

    init(accountId: String, store: MailStore) {
        self.accountId = accountId
        self.store = store
    }

    var body: some View {
        MailAccountDetailScene(
            accountId: accountId,
            store: store
        )
    }
}

private struct MailAccountDetailScene: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let accountId: String
    @ObservedObject var store: MailStore
    @State private var isShowingEditForm = false

    init(accountId: String, store: MailStore) {
        self.accountId = accountId
        self.store = store
    }

    var body: some View {
        List {
            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if let account = store.accountDetail {
                Section {
                    KiioCard {
                        HStack(spacing: 12) {
                            KiioIconBadge(systemImage: "envelope", size: 48, iconSize: 20)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(account.displayTitle)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(KiioTheme.text)
                                if account.isDefault == 1 {
                                    KiioStatusBadge(text: L10n.tr("mail.defaultAccount", locale: appState.locale), tone: .accent)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .kiioListCardRow()

                Section(L10n.tr("common.detail", locale: appState.locale)) {
                    labeled("IMAP", serverText(account.imapServer, account.imapPort))
                    labeled("SMTP", serverText(account.smtpServer, account.smtpPort))
                    labeled(L10n.tr("common.status", locale: appState.locale), account.enabled == 1 ? L10n.tr("device.enabled", locale: appState.locale) : L10n.tr("device.disabled", locale: appState.locale))
                    labeled(L10n.tr("mail.lastUsedAt", locale: appState.locale), account.lastUsedAt)
                    labeled(L10n.tr("common.createdAt", locale: appState.locale), account.createdAt)
                }
            } else {
                KiioEmptyStateView(
                    systemImage: "envelope",
                    title: L10n.tr("mail.account.empty.title", locale: appState.locale),
                    message: L10n.tr("mail.account.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("mail.accountDetail", locale: appState.locale))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isShowingEditForm = true
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(store.accountDetail == nil || store.isActionRunning)

                Button {
                    Task { await setDefault() }
                } label: {
                    Image(systemName: "star")
                }
                .disabled(store.isActionRunning)

                Button(role: .destructive) {
                    Task { await delete() }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.isActionRunning)
            }
        }
        .task { _ = await store.loadAccountDetail(id: accountId) }
        .refreshable { _ = await store.loadAccountDetail(id: accountId) }
        .sheet(isPresented: $isShowingEditForm) {
            MailAccountFormView(
                account: store.accountDetail,
                hasExistingAccounts: true
            ) { request in
                await store.updateAccount(id: accountId, request: request)
            } onSaved: {
                _ = await store.loadAccountDetail(id: accountId)
                _ = await store.load(reset: true, silent: true)
            }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func setDefault() async {
        guard await store.setDefaultAccount(id: accountId) else { return }
        _ = await store.loadAccountDetail(id: accountId)
        _ = await store.load(reset: true, silent: true)
    }

    private func delete() async {
        guard await store.deleteAccount(id: accountId) else { return }
        _ = await store.load(reset: true, silent: true)
        dismiss()
    }

    private func serverText(_ host: String?, _ port: Int?) -> String? {
        guard let host, !host.isEmpty else { return nil }
        guard let port else { return host }
        return "\(host):\(port)"
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

    private func statusTone(_ status: String) -> KiioBadgeTone {
        if status == "failed" {
            return .danger
        }
        if status == "pending_confirm" {
            return .warning
        }
        return .accent
    }
}

private struct MailOperationDetailView: View {
    let operationId: String
    @ObservedObject var store: MailStore

    init(operationId: String, store: MailStore) {
        self.operationId = operationId
        self.store = store
    }

    var body: some View {
        MailOperationDetailScene(
            operationId: operationId,
            store: store
        )
    }
}

private struct MailOperationDetailScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @Environment(\.dismiss) private var dismiss

    let operationId: String
    @ObservedObject var store: MailStore

    init(operationId: String, store: MailStore) {
        self.operationId = operationId
        self.store = store
    }

    var body: some View {
        List {
            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if let operation = store.operationDetail {
                let summary = clean(operation.summary)
                let error = clean(operation.errorMessage)
                let fallbackBody = summary == nil ? clean(operation.rawText) : nil

                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: operation.status == "failed" ? "exclamationmark.triangle.fill" : "paperplane.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(statusColor(operation.status))
                                .frame(width: 48, height: 48)
                                .background(statusColor(operation.status).opacity(0.14))
                                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                            VStack(alignment: .leading, spacing: 8) {
                                Text(operation.displayTitle)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(KiioTheme.text)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let status = statusText(operation.status) {
                                    MailOperationStatusBadge(
                                        text: status,
                                        color: statusColor(operation.status)
                                    )
                                }
                            }
                        }

                        if let operationType = operationText(operation.operationType) {
                            MailOperationMetaPill(
                                icon: "tray.full",
                                text: operationType
                            )
                        }
                    }
                    .mailOperationDetailCard()
                }
                .kiioListCardRow()

                Section {
                    MailOperationDetailRow(
                        title: L10n.tr("common.time", locale: appState.locale),
                        value: formattedDateTime(operation.createdAt) ?? "--"
                    )
                    .mailOperationDetailCard()
                }
                .kiioListCardRow()

                if let summary {
                    Section {
                        MailOperationTextCard(
                            title: L10n.tr("common.summary", locale: appState.locale),
                            text: summary
                        )
                    }
                    .kiioListCardRow()
                }

                if let error {
                    Section {
                        MailOperationTextCard(
                            title: L10n.tr("mail.errorReason", locale: appState.locale),
                            text: error,
                            isError: true
                        )
                    }
                    .kiioListCardRow()
                }

                if let fallbackBody {
                    Section {
                        MailOperationTextCard(
                            title: L10n.tr("common.content", locale: appState.locale),
                            text: fallbackBody
                        )
                    }
                    .kiioListCardRow()
                }
            } else {
                KiioEmptyStateView(
                    systemImage: "envelope",
                    title: L10n.tr("mail.operation.empty.title", locale: appState.locale),
                    message: L10n.tr("mail.operation.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("mail.operationDetail", locale: appState.locale))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive) {
                    Task { await delete() }
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.isActionRunning)
            }
        }
        .task { await refreshFromBackend() }
        .refreshable { await refreshFromBackend() }
        .onReceive(syncStore.$latestEvent) { event in
            guard let event,
                  event.notifyModule == .mailOperation,
                  event.matchesBizId(operationId) else { return }
            Task { await refreshFromBackend(version: event.version) }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.mailOperation, incomingVersion: version)
        guard await store.loadOperationDetail(id: operationId) else { return }
        syncStore.markSynced(.mailOperation, version: targetVersion)
        if syncStore.hasRemoteVersion(.mailOperation, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func delete() async {
        guard await store.deleteOperation(id: operationId) else { return }
        _ = await store.load(reset: true, silent: true)
        dismiss()
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func statusText(_ status: String?) -> String? {
        guard let status = clean(status) else { return nil }
        switch status {
        case "success":
            return L10n.tr("mail.filter.success", locale: appState.locale)
        case "failed":
            return L10n.tr("mail.filter.failed", locale: appState.locale)
        case "pending_confirm":
            return L10n.tr("mail.filter.pending", locale: appState.locale)
        default:
            return status
        }
    }

    private func operationText(_ type: String?) -> String? {
        guard let type = clean(type) else { return nil }
        let key = "mail.operation.\(type)"
        let text = L10n.tr(key, locale: appState.locale)
        return text == key ? type : text
    }

    private func formattedDateTime(_ value: String?) -> String? {
        MailOperationDateFormatter.string(from: value, locale: appState.locale)
    }

    private func statusColor(_ status: String?) -> Color {
        switch status {
        case "failed":
            return KiioTheme.danger
        case "pending_confirm":
            return KiioTheme.warning
        default:
            return KiioTheme.success
        }
    }
}

private struct MailOperationStatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.13))
            .clipShape(Capsule())
            .lineLimit(1)
    }
}

private struct MailOperationMetaPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(KiioTheme.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(KiioTheme.mutedText.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(KiioTheme.mutedText.opacity(0.2), lineWidth: 1))
    }
}

private struct MailOperationDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KiioTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KiioTheme.text)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct MailOperationTextCard: View {
    let title: String
    let text: String
    var isError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isError ? KiioTheme.danger : KiioTheme.secondaryText)
            Text(text)
                .font(.system(size: 15))
                .lineSpacing(4)
                .foregroundStyle(isError ? KiioTheme.danger : KiioTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .mailOperationDetailCard()
    }
}

private struct MailOperationDetailCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
    }
}

private extension View {
    func mailOperationDetailCard() -> some View {
        modifier(MailOperationDetailCardModifier())
    }
}

private enum MailOperationDateFormatter {
    static func string(from value: String?, locale: String) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        guard let date = date(from: value) else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale.hasPrefix("zh") ? "zh_CN" : "en_US")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private static func date(from value: String) -> Date? {
        if let date = backendSecondFormatter.date(from: value) {
            return date
        }
        if let date = backendMinuteFormatter.date(from: value) {
            return date
        }
        let normalized = value.replacingOccurrences(of: " ", with: "T")
        return isoFormatter.date(from: normalized) ?? fallbackISOFormatter.date(from: normalized)
    }

    private static let backendSecondFormatter: DateFormatter = {
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
}

private struct MailAccountRow: View {
    @EnvironmentObject private var appState: AppState
    let account: MailAccountDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KiioIconBadge(systemImage: "envelope", size: 42, iconSize: 17)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(account.displayTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(1)
                    Spacer()
                    if account.isDefault == 1 {
                        KiioStatusBadge(text: L10n.tr("mail.defaultAccount", locale: appState.locale), tone: .accent)
                    }
                }

                Text(account.imapServer ?? account.smtpServer ?? "--")
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(1)

                KiioMetaPill(
                    icon: account.enabled == 1 ? "checkmark.circle" : "pause.circle",
                    text: statusText,
                    tone: accountTone
                )
            }
        }
        .padding(15)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 12, y: 6)
    }

    private var statusText: String {
        account.enabled == 1
            ? L10n.tr("device.enabled", locale: appState.locale)
            : L10n.tr("device.disabled", locale: appState.locale)
    }

    private var accountTone: KiioBadgeTone {
        account.enabled == 1 ? .success : .muted
    }
}

private struct MailOperationRow: View {
    let operation: MailOperationDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KiioIconBadge(systemImage: "paperplane", tone: iconTone, size: 42, iconSize: 17)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(operation.displayTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(2)
                    Spacer()
                    if let status = operation.status {
                        KiioStatusBadge(text: status, tone: statusTone)
                    }
                }

                if let summary = operation.summary {
                    Text(summary)
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineLimit(2)
                }

                if let createdAt = operation.createdAt {
                    KiioMetaPill(icon: "clock", text: createdAt)
                }
            }
        }
        .padding(15)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 12, y: 6)
    }

    private var statusTone: KiioBadgeTone {
        switch operation.status {
        case "failed":
            return .danger
        case "pending_confirm":
            return .warning
        default:
            return .accent
        }
    }

    private var iconTone: KiioBadgeTone {
        operation.status == "failed" ? .danger : .accent
    }
}
