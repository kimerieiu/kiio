import Foundation

@MainActor
final class SubscriptionService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func currentSubscription() async throws -> UserSubscriptionDTO {
        try await apiClient.get("/subscription/me")
    }

    func previewRedeemCode(_ code: String) async throws -> RedeemCodePreviewDTO {
        try await apiClient.post(
            "/subscription/redeem-codes/preview",
            body: RedeemCodeRequest(code: code, legalConsents: nil, legalConsentContext: nil)
        )
    }

    func redeemCode(
        _ code: String,
        membershipConsent: LegalConsentSelection,
        context: LegalConsentContext
    ) async throws -> RedeemCodeRedeemDTO {
        try await apiClient.post(
            "/subscription/redeem-codes/redeem",
            body: RedeemCodeRequest(
                code: code,
                legalConsents: [membershipConsent],
                legalConsentContext: context
            )
        )
    }
}
