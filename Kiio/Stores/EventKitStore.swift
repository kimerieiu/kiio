import Foundation
import EventKit
import Combine

@MainActor
final class EventKitStore: ObservableObject {
    @Published private(set) var items: [NativeCalendarItem] = []
    @Published private(set) var hasAccess = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: EventKitService
    private var changeObserver: AnyCancellable?

    init(service: EventKitService) {
        self.service = service
        hasAccess = service.hasReadAccess()
        changeObserver = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.load(requestAccess: false)
                }
            }
    }

    func load(requestAccess: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if requestAccess && !service.hasReadAccess() {
                try await service.requestAccess()
            }
            hasAccess = service.hasReadAccess()
            guard hasAccess else {
                items = []
                return
            }
            items = try await service.fetchItems()
            errorMessage = nil
        } catch {
            hasAccess = service.hasReadAccess()
            errorMessage = error.localizedDescription
        }
    }

    func create(_ draft: NativeCalendarDraft) async -> Bool {
        do {
            if !service.hasReadAccess() {
                try await service.requestAccess()
            }
            try service.create(draft)
            await load(requestAccess: false)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func sync(tasks: [ReminderTaskDTO]) async {
        guard service.hasReadAccess() else {
            return
        }
        do {
            try await service.syncBackendTasks(tasks)
            await load(requestAccess: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
