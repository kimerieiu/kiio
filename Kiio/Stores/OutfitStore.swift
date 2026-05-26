import Foundation
import Combine

enum OutfitFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case today
    case recent

    var id: String { rawValue }
}

@MainActor
final class OutfitStore: ObservableObject {
    @Published private(set) var outfits: [ClothOutfitDTO] = []
    @Published private(set) var detail: ClothOutfitDTO?
    @Published private(set) var selectedFilter: OutfitFilter = .all
    @Published private(set) var hasMoreOutfits = false
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isActionRunning = false
    @Published var errorMessage: String?

    private let service: OutfitService
    private var nextPage = 1
    private var total = 0
    private let pageLimit = 10

    init(service: OutfitService) {
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
            let range = dateRange(for: selectedFilter)
            let page = try await service.outfits(
                outfitDate: range.outfitDate,
                startDate: range.startDate,
                endDate: range.endDate,
                page: targetPage,
                limit: pageLimit
            )
            if reset {
                outfits = page.list
            } else {
                outfits.append(contentsOf: page.list)
            }
            total = page.total
            nextPage = targetPage + 1
            hasMoreOutfits = outfits.count < total && !page.list.isEmpty
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func selectFilter(_ filter: OutfitFilter) async {
        guard selectedFilter != filter else { return }
        guard !isLoading, !isLoadingMore else { return }
        selectedFilter = filter
        outfits = []
        nextPage = 1
        total = 0
        hasMoreOutfits = false
        _ = await load(reset: true)
    }

    func loadMoreOutfits() async {
        guard hasMoreOutfits, !isLoading, !isLoadingMore else { return }
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

    private func dateRange(for filter: OutfitFilter) -> (outfitDate: String?, startDate: String?, endDate: String?) {
        let today = Date()
        switch filter {
        case .all:
            return (nil, nil, nil)
        case .today:
            return (OutfitDateFormatter.backendDate(from: today), nil, nil)
        case .recent:
            let start = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
            return (nil, OutfitDateFormatter.backendDate(from: start), OutfitDateFormatter.backendDate(from: today))
        }
    }
}

enum OutfitDateFormatter {
    private static let backendFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func backendDate(from date: Date) -> String {
        backendFormatter.string(from: date)
    }
}
