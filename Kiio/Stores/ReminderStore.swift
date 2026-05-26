import Foundation
import Combine

enum ReminderTaskFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case active
    case done
    case cancelled
    case expired

    var id: String { rawValue }

    var status: String? {
        self == .all ? nil : rawValue
    }
}

@MainActor
final class ReminderStore: ObservableObject {
    @Published private(set) var tasks: [ReminderTaskDTO] = []
    @Published private(set) var detail: ReminderTaskDTO?
    @Published private(set) var logs: [ReminderTriggerLogDTO] = []
    @Published private(set) var selectedFilter: ReminderTaskFilter = .all
    @Published private(set) var hasMoreTasks = false
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isActionRunning = false
    @Published var errorMessage: String?

    private let service: ReminderService
    private var nextPage = 1
    private var total = 0
    private let pageLimit = 20

    init(service: ReminderService) {
        self.service = service
    }

    func loadTasks(reset: Bool = true, silent: Bool = false) async -> Bool {
        guard !isLoading, !isLoadingMore else { return false }
        let targetPage = reset ? 1 : nextPage
        if reset {
            isLoading = !silent
        } else {
            isLoadingMore = true
        }
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }

        do {
            let page = try await service.tasks(status: selectedFilter.status, page: targetPage, limit: pageLimit)
            if reset {
                tasks = page.list
            } else {
                tasks.append(contentsOf: page.list)
            }
            total = page.total
            nextPage = targetPage + 1
            hasMoreTasks = tasks.count < total
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func selectFilter(_ filter: ReminderTaskFilter) async {
        guard selectedFilter != filter else { return }
        guard !isLoading, !isLoadingMore else { return }
        selectedFilter = filter
        tasks = []
        nextPage = 1
        total = 0
        hasMoreTasks = false
        _ = await loadTasks(reset: true)
    }

    func loadMoreTasks() async {
        guard hasMoreTasks, !isLoading, !isLoadingMore else { return }
        _ = await loadTasks(reset: false)
    }

    func loadDetail(id: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let task = try await service.detail(id: id)
            detail = task

            if let embeddedLogs = task.logs, !embeddedLogs.isEmpty {
                logs = embeddedLogs
            } else {
                let logPage = try await service.logs(id: id, page: 1, limit: 10)
                logs = logPage.list
            }
            errorMessage = nil
            return true
        } catch {
            detail = nil
            logs = []
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func complete(id: String) async -> Bool {
        await runAction {
            try await service.complete(id: id)
        }
    }

    func cancel(id: String) async -> Bool {
        await runAction {
            try await service.cancel(id: id)
        }
    }

    func delete(id: String) async -> Bool {
        await runAction {
            try await service.delete(id: id)
        }
    }

    private func runAction(_ operation: () async throws -> Void) async -> Bool {
        isActionRunning = true
        defer { isActionRunning = false }

        do {
            try await operation()
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }
}
