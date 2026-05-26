import Foundation
import Combine

enum MailOperationFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case success
    case failed
    case pendingConfirm = "pending_confirm"

    var id: String { rawValue }

    var status: String? {
        self == .all ? nil : rawValue
    }
}

@MainActor
final class MailStore: ObservableObject {
    @Published private(set) var accounts: [MailAccountDTO] = []
    @Published private(set) var operations: [MailOperationDTO] = []
    @Published private(set) var accountDetail: MailAccountDTO?
    @Published private(set) var operationDetail: MailOperationDTO?
    @Published private(set) var selectedOperationFilter: MailOperationFilter = .all
    @Published private(set) var hasMoreOperations = false
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isActionRunning = false
    @Published var errorMessage: String?

    private let service: MailService
    private var nextOperationPage = 1
    private var operationTotal = 0
    private let operationPageLimit = 10

    init(service: MailService) {
        self.service = service
    }

    func load(reset: Bool = true, silent: Bool = false) async -> Bool {
        guard !isLoading, !isLoadingMore else { return false }
        let targetPage = reset ? 1 : nextOperationPage
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
            if reset {
                accounts = try await service.accounts()
            }
            let operationPage = try await service.operations(
                status: selectedOperationFilter.status,
                page: targetPage,
                limit: operationPageLimit
            )
            if reset {
                operations = operationPage.list
            } else {
                operations.append(contentsOf: operationPage.list)
            }
            operationTotal = operationPage.total
            nextOperationPage = targetPage + 1
            hasMoreOperations = operations.count < operationTotal && !operationPage.list.isEmpty
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func selectOperationFilter(_ filter: MailOperationFilter) async {
        guard selectedOperationFilter != filter else { return }
        guard !isLoading, !isLoadingMore else { return }
        selectedOperationFilter = filter
        operations = []
        nextOperationPage = 1
        operationTotal = 0
        hasMoreOperations = false
        _ = await load(reset: true)
    }

    func loadMoreOperations() async {
        guard hasMoreOperations, !isLoading, !isLoadingMore else { return }
        _ = await load(reset: false)
    }

    func loadAccountDetail(id: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            accountDetail = try await service.accountDetail(id: id)
            errorMessage = nil
            return true
        } catch {
            accountDetail = nil
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func loadOperationDetail(id: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            operationDetail = try await service.operationDetail(id: id)
            errorMessage = nil
            return true
        } catch {
            operationDetail = nil
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func createAccount(_ request: MailAccountSaveRequest) async -> Bool {
        await runAction {
            _ = try await service.createAccount(request)
        }
    }

    func updateAccount(id: String, request: MailAccountSaveRequest) async -> Bool {
        await runAction {
            try await service.updateAccount(id: id, request: request)
        }
    }

    func setDefaultAccount(id: String) async -> Bool {
        await runAction {
            try await service.setDefaultAccount(id: id)
        }
    }

    func deleteAccount(id: String) async -> Bool {
        await runAction {
            try await service.deleteAccount(id: id)
        }
    }

    func deleteOperation(id: String) async -> Bool {
        await runAction {
            try await service.deleteOperation(id: id)
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
