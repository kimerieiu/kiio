import SwiftUI

struct ReminderView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        ReminderListScene(store: ReminderStore(service: dependencies.reminderService))
    }
}

private struct ReminderListScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @StateObject private var store: ReminderStore

    init(store: ReminderStore) {
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
                        ForEach(ReminderTaskFilter.allCases) { filter in
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
            } else if store.tasks.isEmpty {
                KiioEmptyStateView(
                    systemImage: "bell",
                    title: L10n.tr("reminder.empty.title", locale: appState.locale),
                    message: L10n.tr("reminder.empty.message", locale: appState.locale)
                )
                .kiioListCardRow()
            } else {
                ForEach(store.tasks) { task in
                    NavigationLink {
                        ReminderDetailView(taskId: task.id, store: store)
                    } label: {
                        ReminderTaskRow(task: task)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task { await delete(task) }
                        } label: {
                            Label(L10n.tr("common.delete", locale: appState.locale), systemImage: "trash")
                        }

                        if task.status == "active" {
                            Button {
                                Task { await cancel(task) }
                            } label: {
                                Label(L10n.tr("common.cancel", locale: appState.locale), systemImage: "xmark.circle")
                            }
                            .tint(KiioTheme.warning)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if task.status == "active" {
                            Button {
                                Task { await complete(task) }
                            } label: {
                                Label(L10n.tr("common.complete", locale: appState.locale), systemImage: "checkmark.circle")
                            }
                            .tint(KiioTheme.success)
                        }
                    }
                    .kiioListCardRow()
                }

                KiioPaginationFooter(
                    isLoading: store.isLoadingMore,
                    hasMore: store.hasMoreTasks,
                    isEmpty: store.tasks.isEmpty,
                    locale: appState.locale
                ) {
                    Task { await store.loadMoreTasks() }
                }
                .kiioListCardRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("reminder.title", locale: appState.locale))
        .task { await refreshFromBackend() }
        .refreshable { await refreshFromBackend() }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .reminderTask else { return }
            Task { await refreshFromBackend(version: event?.version) }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.reminderTask, incomingVersion: version)
        guard await store.loadTasks(reset: true) else { return }
        syncStore.markSynced(.reminderTask, version: targetVersion)
        if syncStore.hasRemoteVersion(.reminderTask, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func filterTitle(_ filter: ReminderTaskFilter) -> String {
        switch filter {
        case .all:
            return L10n.tr("common.all", locale: appState.locale)
        case .active:
            return L10n.tr("reminder.filter.active", locale: appState.locale)
        case .done:
            return L10n.tr("reminder.filter.done", locale: appState.locale)
        case .cancelled:
            return L10n.tr("reminder.filter.cancelled", locale: appState.locale)
        case .expired:
            return L10n.tr("reminder.filter.expired", locale: appState.locale)
        }
    }

    private func complete(_ task: ReminderTaskDTO) async {
        if await store.complete(id: task.id) {
            await refreshFromBackend()
        }
    }

    private func cancel(_ task: ReminderTaskDTO) async {
        if await store.cancel(id: task.id) {
            await refreshFromBackend()
        }
    }

    private func delete(_ task: ReminderTaskDTO) async {
        if await store.delete(id: task.id) {
            await refreshFromBackend()
        }
    }
}

private struct ReminderDetailView: View {
    let taskId: String
    @ObservedObject var store: ReminderStore

    init(taskId: String, store: ReminderStore) {
        self.taskId = taskId
        self.store = store
    }

    var body: some View {
        ReminderDetailScene(
            taskId: taskId,
            store: store
        )
    }
}

private struct ReminderDetailScene: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @Environment(\.dismiss) private var dismiss

    let taskId: String
    @ObservedObject var store: ReminderStore

    init(taskId: String, store: ReminderStore) {
        self.taskId = taskId
        self.store = store
    }

    var body: some View {
        List {
            if store.isLoading {
                KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                    .kiioListCardRow()
            } else if let task = store.detail {
                Section {
                    KiioCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                KiioIconBadge(systemImage: "bell", size: 48, iconSize: 20)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(task.displayTitle)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(KiioTheme.text)
                                    if let status = task.status {
                                        KiioStatusBadge(text: status, tone: statusTone(status))
                                    }
                                }
                            }
                        }
                    }
                }
                .kiioListCardRow()

                if let content = task.displayContent {
                    Section(L10n.tr("common.content", locale: appState.locale)) {
                        Text(content)
                            .foregroundStyle(KiioTheme.text)
                    }
                }

                Section(L10n.tr("common.detail", locale: appState.locale)) {
                    labeled(L10n.tr("common.time", locale: appState.locale), task.remindAt)
                    labeled(L10n.tr("reminder.repeat", locale: appState.locale), task.repeatType)
                    labeled(L10n.tr("reminder.repeatEnd", locale: appState.locale), task.repeatEndAt)
                    labeled(L10n.tr("common.source", locale: appState.locale), task.sourceType)
                    labeled(L10n.tr("reminder.timezone", locale: appState.locale), task.timezone)
                    labeled(L10n.tr("reminder.lastTrigger", locale: appState.locale), task.lastTriggerAt)
                    labeled(L10n.tr("common.createdAt", locale: appState.locale), task.createdAt)
                }

                if !store.logs.isEmpty {
                    Section(L10n.tr("reminder.logs", locale: appState.locale)) {
                        ForEach(store.logs) { log in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(log.notifyStatus ?? "--")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(KiioTheme.accent)
                                    Spacer()
                                    Text(log.displayTime ?? "--")
                                        .font(.system(size: 12))
                                        .foregroundStyle(KiioTheme.mutedText)
                                }
                                if let channel = log.notifyChannel {
                                    Text(channel)
                                        .font(.system(size: 12))
                                        .foregroundStyle(KiioTheme.secondaryText)
                                }
                                if let error = log.errorMessage, !error.isEmpty {
                                    Text(error)
                                        .font(.system(size: 12))
                                        .foregroundStyle(KiioTheme.danger)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            } else {
                KiioEmptyStateView(
                    systemImage: "bell",
                    title: L10n.tr("reminder.detail.empty.title", locale: appState.locale),
                    message: L10n.tr("reminder.detail.empty.message", locale: appState.locale)
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
                if store.detail?.status == "active" {
                    Button {
                        Task { await complete() }
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .disabled(store.isActionRunning)

                    Button {
                        Task { await cancel() }
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .disabled(store.isActionRunning)
                }

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
                  event.notifyModule == .reminderTask,
                  event.matchesBizId(taskId) else { return }
            Task { await refreshFromBackend(version: event.version) }
        }
        .kiioErrorAlert(message: $store.errorMessage, locale: appState.locale)
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.reminderTask, incomingVersion: version)
        guard await store.loadDetail(id: taskId) else { return }
        syncStore.markSynced(.reminderTask, version: targetVersion)
        if syncStore.hasRemoteVersion(.reminderTask, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func complete() async {
        guard await store.complete(id: taskId) else { return }
        await refreshFromBackend()
        _ = await store.loadTasks(reset: true, silent: true)
    }

    private func cancel() async {
        guard await store.cancel(id: taskId) else { return }
        await refreshFromBackend()
        _ = await store.loadTasks(reset: true, silent: true)
    }

    private func delete() async {
        guard await store.delete(id: taskId) else { return }
        _ = await store.loadTasks(reset: true, silent: true)
        dismiss()
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
        switch status {
        case "active":
            return .success
        case "cancelled", "expired":
            return .muted
        case "failed":
            return .danger
        default:
            return .accent
        }
    }
}

private struct ReminderTaskRow: View {
    let task: ReminderTaskDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KiioIconBadge(systemImage: "bell", size: 42, iconSize: 17)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.displayTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(2)
                    Spacer()
                    if let status = task.status {
                        KiioStatusBadge(text: status, tone: statusTone)
                    }
                }

                if let content = task.displayContent, content != task.displayTitle {
                    Text(content)
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineLimit(2)
                }

                if let remindAt = task.remindAt {
                    KiioMetaPill(icon: "clock", text: remindAt)
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
        switch task.status {
        case "active":
            return .success
        case "cancelled", "expired":
            return .muted
        default:
            return .accent
        }
    }
}
