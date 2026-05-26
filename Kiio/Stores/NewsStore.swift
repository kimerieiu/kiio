import Foundation
import Combine

@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var categories: [NewsCategoryDTO] = []
    @Published private(set) var records: [NewsRecordDTO] = []
    @Published private(set) var detail: NewsRecordDTO?
    @Published private(set) var hasMoreRecords = false
    @Published var selectedCategoryCode = "all"
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isActionRunning = false
    @Published var errorMessage: String?

    private let service: NewsService
    private var nextPage = 1
    private var total = 0
    private let pageLimit = 10

    init(service: NewsService) {
        self.service = service
    }

    func loadCategories() async {
        do {
            categories = try await service.categories()
            errorMessage = nil
        } catch {
            categories = []
            errorMessage = AppError.from(error).errorDescription
        }
    }

    func loadCurrent(reset: Bool = true, silent: Bool = false) async -> Bool {
        return await load(categoryCode: selectedCategoryCode, reset: reset, silent: silent)
    }

    func load(categoryCode: String? = nil, reset: Bool = true, silent: Bool = false) async -> Bool {
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
            let page = try await service.records(categoryCode: categoryCode, page: targetPage, limit: pageLimit)
            if reset {
                records = page.list
            } else {
                records.append(contentsOf: page.list)
            }
            total = page.total
            nextPage = targetPage + 1
            hasMoreRecords = records.count < total && !page.list.isEmpty
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func selectCategory(_ code: String) async {
        guard selectedCategoryCode != code else { return }
        guard !isLoading, !isLoadingMore else { return }
        selectedCategoryCode = code
        records = []
        nextPage = 1
        total = 0
        hasMoreRecords = false
        _ = await loadCurrent(reset: true)
    }

    func loadMoreRecords() async {
        guard hasMoreRecords, !isLoading, !isLoadingMore else { return }
        _ = await loadCurrent(reset: false)
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

    func delete(id: String) async -> Bool {
        isActionRunning = true
        defer { isActionRunning = false }

        do {
            try await service.delete(id: id)
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }
}
