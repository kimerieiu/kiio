import Foundation
import EventKit

enum NativeCalendarItemKind: String, CaseIterable, Identifiable {
    case reminder
    case event

    var id: String { rawValue }
}

enum NativeCalendarRecurrence: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly

    var id: String { rawValue }
}

struct NativeCalendarItem: Identifiable, Equatable {
    let id: String
    let kind: NativeCalendarItemKind
    let title: String
    let notes: String?
    let startAt: Date?
    let endAt: Date?
    let calendarTitle: String
    let isAllDay: Bool
    let isCompleted: Bool
}

struct NativeCalendarDraft {
    var kind: NativeCalendarItemKind = .reminder
    var title = ""
    var notes = ""
    var startAt = Date().addingTimeInterval(3_600)
    var endAt = Date().addingTimeInterval(7_200)
    var allDay = false
    var recurrence: NativeCalendarRecurrence = .none
}

enum EventKitServiceError: LocalizedError {
    case accessDenied
    case noWritableCalendar
    case invalidTitle

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar or Reminders access was not granted."
        case .noWritableCalendar:
            return "No writable Calendar or Reminders list is available."
        case .invalidTitle:
            return "A title is required."
        }
    }
}

@MainActor
final class EventKitService {
    private let eventStore = EKEventStore()
    private let mappingDefaultsKey = "kiio.eventkit.backendMappings.v1"
    private let markerPrefix = "kiio-task:"

    func requestAccess() async throws {
        try await requestReminderAccess()
        try await requestEventAccess()
    }

    func hasReadAccess() -> Bool {
        hasReminderAccess() && hasEventReadAccess()
    }

    func fetchItems() async throws -> [NativeCalendarItem] {
        guard hasReadAccess() else {
            throw EventKitServiceError.accessDenied
        }

        async let reminders = fetchReminderItems()
        let events = fetchEventItems(
            from: Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date(),
            to: Calendar.current.date(byAdding: .year, value: 3, to: Date()) ?? Date()
        )
        let reminderItems = try await reminders
        return (reminderItems + events).sorted {
            ($0.startAt ?? .distantFuture) < ($1.startAt ?? .distantFuture)
        }
    }

    func create(_ draft: NativeCalendarDraft) throws {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            throw EventKitServiceError.invalidTitle
        }

        switch draft.kind {
        case .reminder:
            try createReminder(
                title: title,
                notes: draft.notes,
                dueAt: draft.startAt,
                recurrence: draft.recurrence,
                marker: nil
            )
        case .event:
            try createEvent(
                title: title,
                notes: draft.notes,
                startAt: draft.startAt,
                endAt: max(draft.endAt, draft.startAt.addingTimeInterval(60)),
                allDay: draft.allDay,
                recurrence: draft.recurrence,
                marker: nil
            )
        }
    }

    func syncBackendTasks(_ tasks: [ReminderTaskDTO]) async throws {
        guard hasReadAccess() else {
            return
        }

        var mappings = loadMappings()
        let taskIds = Set(tasks.map(\.id))
        let itemsByMarker = await nativeItemsByMarker()

        for task in tasks {
            let status = task.status ?? "active"
            if status == "active" {
                let marker = "\(markerPrefix)\(task.id)"
                let fallbackIdentifier = itemsByMarker[marker]?.calendarItemIdentifier
                let identifier = try upsert(
                    task,
                    existingIdentifier: mappings[task.id] ?? fallbackIdentifier
                )
                mappings[task.id] = identifier
            } else if let identifier = mappings.removeValue(forKey: task.id) {
                try finishOrRemove(identifier: identifier, task: task)
            }
        }

        for staleTaskId in Set(mappings.keys).subtracting(taskIds) {
            if let identifier = mappings.removeValue(forKey: staleTaskId),
               let item = eventStore.calendarItem(withIdentifier: identifier) {
                try remove(item)
            }
        }
        saveMappings(mappings)
    }

    func completedBackendTaskIds(_ tasks: [ReminderTaskDTO]) async -> Set<String> {
        guard hasReadAccess() else {
            return []
        }
        let mappings = loadMappings()
        let itemsByMarker = await nativeItemsByMarker()
        var completed: Set<String> = []

        for task in tasks where task.status == "active" {
            if task.itemType == "event" {
                let eventEnd = parseBackendDate(task.endAt ?? task.remindAt, timezone: task.timezone)
                if (task.repeatType ?? "none") == "none", let eventEnd, eventEnd <= Date() {
                    completed.insert(task.id)
                }
                continue
            }
            let marker = "\(markerPrefix)\(task.id)"
            let item = mappings[task.id].flatMap(eventStore.calendarItem(withIdentifier:))
                ?? itemsByMarker[marker]
            if let reminder = item as? EKReminder, reminder.isCompleted {
                completed.insert(task.id)
            }
        }
        return completed
    }

    private func requestReminderAccess() async throws {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await eventStore.requestFullAccessToReminders()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { allowed, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: allowed)
                    }
                }
            }
        }
        if !granted {
            throw EventKitServiceError.accessDenied
        }
    }

    private func requestEventAccess() async throws {
        let granted: Bool
        if #available(iOS 17.0, *) {
            granted = try await eventStore.requestFullAccessToEvents()
        } else {
            granted = try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { allowed, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: allowed)
                    }
                }
            }
        }
        if !granted {
            throw EventKitServiceError.accessDenied
        }
    }

    private func hasReminderAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    private func hasEventReadAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    private func fetchReminderItems() async throws -> [NativeCalendarItem] {
        let predicate = eventStore.predicateForReminders(in: nil)
        let reminders = await fetchReminders(matching: predicate)
        return reminders.map {
            NativeCalendarItem(
                id: $0.calendarItemIdentifier,
                kind: .reminder,
                title: $0.title ?? "",
                notes: $0.notes,
                startAt: date(from: $0.dueDateComponents ?? $0.startDateComponents),
                endAt: nil,
                calendarTitle: $0.calendar.title,
                isAllDay: isDateOnly($0.dueDateComponents),
                isCompleted: $0.isCompleted
            )
        }
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { values in
                continuation.resume(returning: values ?? [])
            }
        }
    }

    private func nativeItemsByMarker() async -> [String: EKCalendarItem] {
        var result: [String: EKCalendarItem] = [:]
        let reminders = await fetchReminders(
            matching: eventStore.predicateForReminders(in: nil)
        )
        let eventStart = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? .distantPast
        let eventEnd = Calendar.current.date(byAdding: .year, value: 10, to: Date()) ?? .distantFuture
        let events = eventStore.events(
            matching: eventStore.predicateForEvents(
                withStart: eventStart,
                end: eventEnd,
                calendars: nil
            )
        )

        let calendarItems: [EKCalendarItem] =
            reminders.map { $0 as EKCalendarItem } + events.map { $0 as EKCalendarItem }
        for item in calendarItems {
            guard let notes = item.notes else { continue }
            for line in notes.split(whereSeparator: \.isNewline) {
                let marker = String(line).trimmingCharacters(in: .whitespaces)
                if marker.hasPrefix(markerPrefix) {
                    result[marker] = item
                }
            }
        }
        return result
    }

    private func fetchEventItems(from start: Date, to end: Date) -> [NativeCalendarItem] {
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        return eventStore.events(matching: predicate).map {
            NativeCalendarItem(
                id: $0.eventIdentifier ?? $0.calendarItemIdentifier,
                kind: .event,
                title: $0.title ?? "",
                notes: $0.notes,
                startAt: $0.startDate,
                endAt: $0.endDate,
                calendarTitle: $0.calendar.title,
                isAllDay: $0.isAllDay,
                isCompleted: false
            )
        }
    }

    private func upsert(_ task: ReminderTaskDTO, existingIdentifier: String?) throws -> String {
        let kind = NativeCalendarItemKind(rawValue: task.itemType ?? "reminder") ?? .reminder
        let marker = "\(markerPrefix)\(task.id)"
        let existing = existingIdentifier.flatMap(eventStore.calendarItem(withIdentifier:))
        let start = parseBackendDate(task.remindAt, timezone: task.timezone) ?? Date()
        let recurrence = NativeCalendarRecurrence(rawValue: task.repeatType ?? "none") ?? .none

        if kind == .reminder {
            let reminder: EKReminder
            if let existing = existing as? EKReminder {
                reminder = existing
            } else {
                if let existing {
                    try remove(existing)
                }
                reminder = EKReminder(eventStore: eventStore)
                reminder.calendar = eventStore.defaultCalendarForNewReminders()
            }
            guard reminder.calendar != nil else {
                throw EventKitServiceError.noWritableCalendar
            }
            configure(
                reminder,
                title: task.displayTitle,
                notes: task.displayContent,
                dueAt: start,
                recurrence: recurrence,
                recurrenceEnd: parseBackendDate(task.repeatEndAt, timezone: task.timezone),
                marker: marker
            )
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemIdentifier
        }

        let event: EKEvent
        if let existing = existing as? EKEvent {
            event = existing
        } else {
            if let existing {
                try remove(existing)
            }
            event = EKEvent(eventStore: eventStore)
            event.calendar = eventStore.defaultCalendarForNewEvents
        }
        guard event.calendar != nil else {
            throw EventKitServiceError.noWritableCalendar
        }
        let end = parseBackendDate(task.endAt, timezone: task.timezone) ?? start.addingTimeInterval(3_600)
        configure(
            event,
            title: task.displayTitle,
            notes: task.displayContent,
            startAt: start,
            endAt: max(end, start.addingTimeInterval(60)),
            allDay: task.allDay == true,
            recurrence: recurrence,
            recurrenceEnd: parseBackendDate(task.repeatEndAt, timezone: task.timezone),
            marker: marker
        )
        try eventStore.save(event, span: .futureEvents, commit: true)
        return event.calendarItemIdentifier
    }

    private func finishOrRemove(identifier: String, task: ReminderTaskDTO) throws {
        guard let item = eventStore.calendarItem(withIdentifier: identifier) else {
            return
        }
        if task.status == "done" {
            if let reminder = item as? EKReminder {
                reminder.isCompleted = true
                reminder.completionDate = Date()
                try eventStore.save(reminder, commit: true)
            }
        } else {
            try remove(item)
        }
    }

    private func remove(_ item: EKCalendarItem) throws {
        if let reminder = item as? EKReminder {
            try eventStore.remove(reminder, commit: true)
        } else if let event = item as? EKEvent {
            try eventStore.remove(event, span: .futureEvents, commit: true)
        }
    }

    private func createReminder(
        title: String,
        notes: String?,
        dueAt: Date,
        recurrence: NativeCalendarRecurrence,
        marker: String?
    ) throws {
        guard hasReminderAccess() else {
            throw EventKitServiceError.accessDenied
        }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        guard reminder.calendar != nil else {
            throw EventKitServiceError.noWritableCalendar
        }
        configure(
            reminder,
            title: title,
            notes: notes,
            dueAt: dueAt,
            recurrence: recurrence,
            recurrenceEnd: nil,
            marker: marker
        )
        try eventStore.save(reminder, commit: true)
    }

    private func configure(
        _ reminder: EKReminder,
        title: String,
        notes: String?,
        dueAt: Date,
        recurrence: NativeCalendarRecurrence,
        recurrenceEnd: Date? = nil,
        marker: String?
    ) {
        reminder.title = title
        reminder.notes = notesWithMarker(notes, marker: marker)
        let components = dateComponents(for: dueAt)
        reminder.startDateComponents = components
        reminder.dueDateComponents = components
        reminder.alarms = [EKAlarm(absoluteDate: dueAt)]
        reminder.recurrenceRules = recurrenceRule(recurrence, endAt: recurrenceEnd).map { [$0] }
    }

    private func createEvent(
        title: String,
        notes: String?,
        startAt: Date,
        endAt: Date,
        allDay: Bool,
        recurrence: NativeCalendarRecurrence,
        marker: String?
    ) throws {
        guard hasEventReadAccess() else {
            throw EventKitServiceError.accessDenied
        }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = eventStore.defaultCalendarForNewEvents
        guard event.calendar != nil else {
            throw EventKitServiceError.noWritableCalendar
        }
        configure(
            event,
            title: title,
            notes: notes,
            startAt: startAt,
            endAt: endAt,
            allDay: allDay,
            recurrence: recurrence,
            recurrenceEnd: nil,
            marker: marker
        )
        try eventStore.save(event, span: .thisEvent, commit: true)
    }

    private func configure(
        _ event: EKEvent,
        title: String,
        notes: String?,
        startAt: Date,
        endAt: Date,
        allDay: Bool,
        recurrence: NativeCalendarRecurrence,
        recurrenceEnd: Date?,
        marker: String?
    ) {
        event.title = title
        event.notes = notesWithMarker(notes, marker: marker)
        event.startDate = allDay ? Calendar.current.startOfDay(for: startAt) : startAt
        event.endDate = allDay
            ? (Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: startAt)) ?? endAt)
            : endAt
        event.isAllDay = allDay
        event.alarms = [EKAlarm(absoluteDate: event.startDate)]
        event.recurrenceRules = recurrenceRule(recurrence, endAt: recurrenceEnd).map { [$0] }
    }

    private func recurrenceRule(_ recurrence: NativeCalendarRecurrence, endAt: Date?) -> EKRecurrenceRule? {
        let frequency: EKRecurrenceFrequency
        switch recurrence {
        case .none:
            return nil
        case .daily:
            frequency = .daily
        case .weekly:
            frequency = .weekly
        case .monthly:
            frequency = .monthly
        }
        let recurrenceEnd = endAt.map { EKRecurrenceEnd(end: $0) }
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: 1,
            end: recurrenceEnd
        )
    }

    private func dateComponents(for date: Date) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var components = calendar.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
            from: date
        )
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return components
    }

    private func date(from components: DateComponents?) -> Date? {
        guard var components else {
            return nil
        }
        components.calendar = components.calendar ?? Calendar(identifier: .gregorian)
        return components.date
    }

    private func isDateOnly(_ components: DateComponents?) -> Bool {
        components?.hour == nil && components?.minute == nil && components?.second == nil
    }

    private func notesWithMarker(_ notes: String?, marker: String?) -> String? {
        let cleanNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let marker else {
            return cleanNotes.isEmpty ? nil : cleanNotes
        }
        return cleanNotes.isEmpty ? marker : "\(cleanNotes)\n\n\(marker)"
    }

    private func parseBackendDate(_ value: String?, timezone: String?) -> Date? {
        guard let value, !value.isEmpty else {
            return nil
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: value) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timezone.flatMap(TimeZone.init(identifier:)) ?? .current
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private func loadMappings() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: mappingDefaultsKey) as? [String: String] ?? [:]
    }

    private func saveMappings(_ mappings: [String: String]) {
        UserDefaults.standard.set(mappings, forKey: mappingDefaultsKey)
    }
}
