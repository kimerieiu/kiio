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
    @State private var selectedSource: ReminderDataSource = .kiio
    @State private var isPresentingCreate = false
    private let showsSystemSource = false

    init(store: ReminderStore, eventKitStore: EventKitStore) {
        _store = StateObject(wrappedValue: store)
        self.eventKitStore = eventKitStore
    }

    var body: some View {
        List {
            if showsSystemSource {
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
            }

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
                if showsSystemSource && selectedSource == .system {
                    Button {
                        isPresentingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingCreate) {
            NativeCalendarCreateView(store: eventKitStore)
        }
        .task {
            await refreshFromBackend()
            if !eventKitStore.hasAccess {
                await eventKitStore.load(requestAccess: true)
            }
            await syncBackendTasksToEventKit()
        }
        .refreshable {
            if selectedSource == .system {
                await eventKitStore.load(requestAccess: false)
            }
            await refreshFromBackend()
            await syncBackendTasksToEventKit()
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
                    KiioCard(padding: 20) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 16) {
                                KiioIconBadge(systemImage: "bell.fill", tone: statusTone(task.status ?? ""), size: 56, iconSize: 24)
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(task.displayTitle)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(KiioTheme.text)
                                        .lineLimit(3)
                                    if let status = task.status {
                                        KiioStatusBadge(text: status.capitalized, tone: statusTone(status))
                                    }
                                }
                            }

                            if let content = task.displayContent, !content.isEmpty {
                                Divider()
                                    .background(KiioTheme.border)
                                Text(content)
                                    .font(.system(size: 15))
                                    .foregroundStyle(KiioTheme.secondaryText)
                                    .lineLimit(nil)
                            }
                        }
                    }
                }
                .kiioListCardRow()

                Section {
                    KiioCard(padding: 16) {
                        VStack(spacing: 12) {
                            detailRow(icon: "tag", title: "Type", value: task.itemType)
                            detailRow(icon: "clock", title: L10n.tr("common.time", locale: appState.locale), value: task.remindAt)

                            if task.itemType == "event" {
                                detailRow(icon: "clock.badge", title: "Ends", value: task.endAt)
                            }

                            detailRow(icon: "repeat", title: L10n.tr("reminder.repeat", locale: appState.locale), value: task.repeatType)
                            detailRow(icon: "calendar.badge.clock", title: L10n.tr("reminder.repeatEnd", locale: appState.locale), value: task.repeatEndAt)
                        }
                    }
                }
                .kiioListCardRow()

                if !store.logs.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            ForEach(store.logs) { log in
                                KiioCard(padding: 14) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(logStatusColor(log.notifyStatus ?? ""))
                                                    .frame(width: 8, height: 8)
                                                Text(log.notifyStatus ?? "--")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(KiioTheme.text)
                                            }
                                            Spacer()
                                            Text(log.displayTime ?? "--")
                                                .font(.system(size: 12))
                                                .foregroundStyle(KiioTheme.mutedText)
                                        }

                                        if let channel = log.notifyChannel, !channel.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "antenna.radiowaves.left.and.right")
                                                    .font(.system(size: 10))
                                                Text(channel)
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundStyle(KiioTheme.secondaryText)
                                        }

                                        if let error = log.errorMessage, !error.isEmpty {
                                            HStack(alignment: .top, spacing: 4) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(KiioTheme.danger)
                                                Text(error)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(KiioTheme.danger)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        KiioSectionTitle(title: L10n.tr("reminder.logs", locale: appState.locale), icon: "list.bullet.clipboard")
                            .padding(.horizontal, 4)
                    }
                    .kiioListCardRow()
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

    private func detailRow(icon: String, title: String, value: String?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KiioTheme.mutedText)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(KiioTheme.secondaryText)

            Spacer()

            Text(value?.isEmpty == false ? value! : "--")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(value?.isEmpty == false ? KiioTheme.text : KiioTheme.mutedText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
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

    private func logStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "sent", "delivered", "success":
            return KiioTheme.success
        case "failed", "error":
            return KiioTheme.danger
        case "pending", "scheduled":
            return KiioTheme.warning
        default:
            return KiioTheme.mutedText
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
