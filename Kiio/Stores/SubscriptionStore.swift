import Foundation
import Combine

@MainActor
final class SubscriptionStore: ObservableObject {
    @Published private(set) var subscription: UserSubscriptionDTO?
    @Published private(set) var preview: RedeemCodePreviewDTO?
    @Published var isLoadingSubscription = false
    @Published var isPreviewing = false
    @Published var isRedeeming = false
    @Published var errorMessage: String?

    private let service: SubscriptionService

    init(service: SubscriptionService) {
        self.service = service
    }

    func loadCurrent(silent: Bool = false) async -> Bool {
        guard !isLoadingSubscription else { return false }
        isLoadingSubscription = !silent
        defer { isLoadingSubscription = false }

        do {
            subscription = try await service.currentSubscription()
            errorMessage = nil
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }

    func preview(code: String) async -> RedeemCodePreviewDTO? {
        guard !isPreviewing, !isRedeeming else { return nil }
        isPreviewing = true
        defer { isPreviewing = false }

        do {
            let result = try await service.previewRedeemCode(code)
            preview = result
            errorMessage = nil
            return result
        } catch {
            preview = nil
            errorMessage = AppError.from(error).errorDescription
            return nil
        }
    }

    func redeem(
        code: String,
        membershipConsent: LegalConsentSelection,
        context: LegalConsentContext
    ) async -> Bool {
        guard !isRedeeming else { return false }
        isRedeeming = true
        defer { isRedeeming = false }

        do {
            let result = try await service.redeemCode(
                code,
                membershipConsent: membershipConsent,
                context: context
            )
            if let subscription = result.subscription {
                self.subscription = subscription
            }
            preview = nil
            errorMessage = nil
            _ = await loadCurrent(silent: true)
            return true
        } catch {
            errorMessage = AppError.from(error).errorDescription
            return false
        }
    }
}
