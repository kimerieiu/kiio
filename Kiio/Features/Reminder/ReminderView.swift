import SwiftUI

private enum ReminderDataSource: String, CaseIterable, Identifiable {
    case system
    case kiio

    var id: String { rawValue }
}

struct ReminderView: View {
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        ReminderListScene(
            store: ReminderStore(service: dependencies.reminderService),
            eventKitStore: dependencies.eventKitStore
        )
    }
}

private struct ReminderListScene: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var syncStore: SyncStore
    @StateObject private var store: ReminderStore
    @ObservedObject private var eventKitStore: EventKitStore
    @State private var selectedSource: ReminderDataSource = .system
    @State private var isPresentingCreate = false

    init(store: ReminderStore, eventKitStore: EventKitStore) {
        _store = StateObject(wrappedValue: store)
        self.eventKitStore = eventKitStore
    }

    var body: some View {
        List {
            Section {
                KiioCard(padding: 8, radius: 16) {
                    Picker("", selection: $selectedSource) {
                        Text("System").tag(ReminderDataSource.system)
                        Text("Kiio").tag(ReminderDataSource.kiio)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .kiioListHeaderRow()
            }
            .listRowBackground(Color.clear)

            if selectedSource == .kiio {
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
                                .kiioHidesTabBar()
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
            } else {
                if eventKitStore.isLoading {
                    KiioLoadingCard(message: L10n.tr("common.loading", locale: appState.locale))
                        .kiioListCardRow()
                } else if !eventKitStore.hasAccess {
                    KiioCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Calendar & Reminders access", systemImage: "calendar.badge.exclamationmark")
                                .font(.headline)
                            Text("Allow access to read and create native reminders and calendar events.")
                                .foregroundStyle(KiioTheme.secondaryText)
                            Button("Allow Access") {
                                Task {
                                    await eventKitStore.load(requestAccess: true)
                                    await syncBackendTasksToEventKit()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .kiioListCardRow()
                } else if eventKitStore.items.isEmpty {
                    KiioEmptyStateView(
                        systemImage: "calendar",
                        title: "No system items",
                        message: "Create a reminder or calendar event with the add button."
                    )
                    .kiioListCardRow()
                } else {
                    ForEach(eventKitStore.items) { item in
                        NativeCalendarItemRow(item: item)
                            .kiioListCardRow()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KiioTheme.background.ignoresSafeArea())
        .listStyle(.plain)
        .navigationTitle(L10n.tr("reminder.title", locale: appState.locale))
        .kiioHidesTabBar()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isPresentingCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingCreate) {
            NativeCalendarCreateView(store: eventKitStore)
        }
        .task {
            await refreshFromBackend()
            await eventKitStore.load(requestAccess: false)
            await syncBackendTasksToEventKit()
        }
        .refreshable {
            if selectedSource == .system {
                await eventKitStore.load(requestAccess: false)
                await syncBackendTasksToEventKit()
            } else {
                await refreshFromBackend()
            }
        }
        .onReceive(syncStore.$latestEvent) { event in
            guard event?.notifyModule == .reminderTask else { return }
            Task {
                await refreshFromBackend(version: event?.version)
                await syncBackendTasksToEventKit()
            }
        }
        .kiioErrorAlert(
            message: Binding(
                get: { store.errorMessage ?? eventKitStore.errorMessage },
                set: { value in
                    if value == nil {
                        store.errorMessage = nil
                        eventKitStore.errorMessage = nil
                    }
                }
            ),
            locale: appState.locale
        )
    }

    private func refreshFromBackend(version: Int? = nil) async {
        let targetVersion = syncStore.targetVersion(.reminderTask, incomingVersion: version)
        guard await store.loadTasks(reset: true) else { return }
        syncStore.markSynced(.reminderTask, version: targetVersion)
        if syncStore.hasRemoteVersion(.reminderTask, after: targetVersion) {
            await refreshFromBackend()
        }
    }

    private func syncBackendTasksToEventKit() async {
        guard eventKitStore.hasAccess else { return }
        do {
            var tasks = try await dependencies.reminderService.allTasks()
            let completedIds = await dependencies.eventKitService.completedBackendTaskIds(tasks)
            for taskId in completedIds {
                try await dependencies.reminderService.complete(id: taskId)
            }
            if !completedIds.isEmpty {
                tasks = try await dependencies.reminderService.allTasks()
            }
            await eventKitStore.sync(tasks: tasks)
        } catch {
            eventKitStore.errorMessage = AppError.from(error).errorDescription
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

private struct NativeCalendarItemRow: View {
    let item: NativeCalendarItem

    var body: some View {
        KiioCard {
            HStack(alignment: .top, spacing: 12) {
                KiioIconBadge(
                    systemImage: item.kind == .reminder ? "checklist" : "calendar",
                    size: 42,
                    iconSize: 17
                )
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(item.title.isEmpty ? "--" : item.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KiioTheme.text)
                        Spacer()
                        KiioStatusBadge(
                            text: item.kind == .reminder ? "Reminder" : "Event",
                            tone: item.isCompleted ? .muted : .accent
                        )
                    }
                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes.replacingOccurrences(
                            of: #"\n\nkiio-task:[^\n]+"#,
                            with: "",
                            options: .regularExpression
                        ))
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineLimit(2)
                    }
                    if let startAt = item.startAt {
                        KiioMetaPill(icon: "clock", text: startAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    KiioMetaPill(icon: "tray", text: item.calendarTitle)
                }
            }
        }
    }
}

private struct NativeCalendarCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: EventKitStore
    @State private var draft = NativeCalendarDraft()
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("Type", selection: $draft.kind) {
                    Text("Reminder").tag(NativeCalendarItemKind.reminder)
                    Text("Calendar Event").tag(NativeCalendarItemKind.event)
                }
                .pickerStyle(.segmented)

                Section("Details") {
                    TextField("Title", text: $draft.title)
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                    DatePicker(
                        draft.kind == .reminder ? "Remind me" : "Starts",
                        selection: $draft.startAt,
                        displayedComponents: draft.allDay ? [.date] : [.date, .hourAndMinute]
                    )
                    if draft.kind == .event {
                        Toggle("All day", isOn: $draft.allDay)
                        if !draft.allDay {
                            DatePicker(
                                "Ends",
                                selection: $draft.endAt,
                                in: draft.startAt...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $draft.recurrence) {
                        Text("Never").tag(NativeCalendarRecurrence.none)
                        Text("Daily").tag(NativeCalendarRecurrence.daily)
                        Text("Weekly").tag(NativeCalendarRecurrence.weekly)
                        Text("Monthly").tag(NativeCalendarRecurrence.monthly)
                    }
                }
            }
            .navigationTitle(draft.kind == .reminder ? "New Reminder" : "New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            if await store.create(draft) {
                                dismiss()
                            }
                            isSaving = false
                        }
                    }
                    .disabled(isSaving || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
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
                    labeled("Type", task.itemType)
                    labeled(L10n.tr("common.time", locale: appState.locale), task.remindAt)
                    if task.itemType == "event" {
                        labeled("Ends", task.endAt)
                        labeled("All day", task.allDay == true ? "Yes" : "No")
                    }
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
        .kiioHidesTabBar()
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
