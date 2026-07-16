import Foundation

struct ShopifyOrderDTO: Decodable, Equatable, Identifiable {
    let id: String
    let orderNo: String?
    let paymentStatus: String?
    let refundStatus: String?
    let currency: String?
    let totalAmount: Decimal?
    let processedAt: String?
    let redeemedTime: String?
    let items: [ShopifyOrderItemDTO]
}

struct ShopifyOrderItemDTO: Decodable, Equatable, Identifiable {
    let id: String
    let title: String?
    let sku: String?
    let planCode: String?
    let planName: String?
    let billingCycle: String?
    let quantity: Int
    let unitAmount: Decimal?
    let currency: String?
    let serviceDurationDays: Int?
    let redemptionStatus: String?
    let redeemedTime: String?
}
