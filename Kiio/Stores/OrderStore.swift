import Combine
import Foundation

@MainActor
final class OrderStore: ObservableObject {
    @Published private(set) var orders: [ShopifyOrderDTO] = []
    @Published private(set) var detail: ShopifyOrderDTO?
    @Published private(set) var hasMoreOrders = false
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?

    private let service: OrderService
    private var nextPage = 1
    private var total = 0
    private let pageLimit = 20

    init(service: OrderService) {
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
            let page = try await service.orders(page: targetPage, limit: pageLimit)
            if reset {
                orders = page.list
            } else {
                orders.append(contentsOf: page.list)
            }
            total = page.total
            nextPage = targetPage + 1
            hasMoreOrders = orders.count < total && !page.list.isEmpty
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func loadMore() async {
        guard hasMoreOrders, !isLoading, !isLoadingMore else { return }
        _ = await load(reset: false)
    }

    func loadDetail(id: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let order = try await service.detail(id: id)
            detail = order
            if let index = orders.firstIndex(where: { $0.id == order.id }) {
                orders[index] = order
            }
            errorMessage = nil
            return true
        } catch {
            detail = nil
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }
}
