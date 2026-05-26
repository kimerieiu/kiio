import Foundation
import Combine

enum AccountingBillFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case expense
    case income
    case pendingConfirm = "pending_confirm"

    var id: String { rawValue }

    var billType: String? {
        switch self {
        case .expense, .income:
            return rawValue
        case .all, .pendingConfirm:
            return nil
        }
    }

    var status: String? {
        self == .pendingConfirm ? rawValue : nil
    }
}

@MainActor
final class AccountingStore: ObservableObject {
    @Published private(set) var bills: [AccountingBillDTO] = []
    @Published private(set) var detail: AccountingBillDTO?
    @Published private(set) var categories: [AccountingCategoryDTO] = []
    @Published private(set) var accounts: [AccountingPaymentAccountDTO] = []
    @Published private(set) var selectedFilter: AccountingBillFilter = .all
    @Published private(set) var hasMoreBills = false
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isLoadingMetadata = false
    @Published var isActionRunning = false
    @Published var errorMessage: String?

    private let service: AccountingService
    private var nextPage = 1
    private var total = 0
    private let pageLimit = 20

    init(service: AccountingService) {
        self.service = service
    }

    func load(reset: Bool = true, silent: Bool = false) async -> Bool {
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
            let page = try await service.bills(
                type: selectedFilter.billType,
                status: selectedFilter.status,
                page: targetPage,
                limit: pageLimit
            )
            if reset {
                bills = page.list
            } else {
                bills.append(contentsOf: page.list)
            }
            total = page.total
            nextPage = targetPage + 1
            hasMoreBills = bills.count < total
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func selectFilter(_ filter: AccountingBillFilter) async {
        guard selectedFilter != filter else { return }
        guard !isLoading, !isLoadingMore else { return }
        selectedFilter = filter
        bills = []
        nextPage = 1
        total = 0
        hasMoreBills = false
        _ = await load(reset: true)
    }

    func loadMore() async {
        guard hasMoreBills, !isLoading, !isLoadingMore else { return }
        _ = await load(reset: false)
    }

    func loadDetail(id: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            detail = try await service.detail(id: id)
            errorMessage = nil
            return true
        } catch {
            detail = nil
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func loadMetadata() async -> Bool {
        isLoadingMetadata = true
        defer { isLoadingMetadata = false }

        do {
            categories = try await service.categories()
            accounts = try await service.accounts()
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func update(id: String, request: AccountingBillUpdateRequest) async -> Bool {
        await runAction {
            try await service.update(id: id, request: request)
        }
    }

    func confirm(id: String) async -> Bool {
        await runAction {
            try await service.confirm(id: id)
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
