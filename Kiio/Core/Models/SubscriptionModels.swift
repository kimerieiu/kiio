import Foundation

struct SubscriptionEntitlementValue: Decodable, Equatable {
    enum Storage: Equatable {
        case bool(Bool)
        case number(Decimal)
        case string(String)
    }

    let storage: Storage

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            storage = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            storage = .number(Decimal(int))
        } else if let double = try? container.decode(Double.self) {
            storage = .number(Decimal(double))
        } else if let string = try? container.decode(String.self) {
            storage = .string(string)
        } else {
            storage = .string("")
        }
    }

    var boolValue: Bool? {
        switch storage {
        case .bool(let value):
            return value
        case .number(let value):
            return NSDecimalNumber(decimal: value).intValue != 0
        case .string(let value):
            let text = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "1", "yes", "y"].contains(text) {
                return true
            }
            if ["false", "0", "no", "n", ""].contains(text) {
                return false
            }
            return nil
        }
    }

    var intValue: Int? {
        switch storage {
        case .bool(let value):
            return value ? 1 : 0
        case .number(let value):
            return NSDecimalNumber(decimal: value).intValue
        case .string(let value):
            if let int = Int(value) {
                return int
            }
            if let double = Double(value) {
                return Int(double)
            }
            return nil
        }
    }

    var stringValue: String {
        switch storage {
        case .bool(let value):
            return value ? "true" : "false"
        case .number(let value):
            return NSDecimalNumber(decimal: value).stringValue
        case .string(let value):
            return value
        }
    }
}

struct SubscriptionFlexibleInt: Decodable, Equatable {
    let value: Int

    init(_ value: Int = 0) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = Int(double)
        } else if let string = try? container.decode(String.self) {
            if let int = Int(string) {
                value = int
            } else if let double = Double(string) {
                value = Int(double)
            } else {
                value = 0
            }
        } else {
            value = 0
        }
    }
}

struct SubscriptionUsageQuotaDTO: Decodable, Equatable {
    let quotaKey: String?
    let total: SubscriptionFlexibleInt
    let used: SubscriptionFlexibleInt
    let remaining: SubscriptionFlexibleInt
    let periodStart: String?
    let periodEnd: String?

    enum CodingKeys: String, CodingKey {
        case quotaKey
        case total
        case used
        case remaining
        case periodStart
        case periodEnd
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        quotaKey = try container.decodeIfPresent(String.self, forKey: .quotaKey)
        total = try container.decodeIfPresent(SubscriptionFlexibleInt.self, forKey: .total) ?? SubscriptionFlexibleInt()
        used = try container.decodeIfPresent(SubscriptionFlexibleInt.self, forKey: .used) ?? SubscriptionFlexibleInt()
        remaining = try container.decodeIfPresent(SubscriptionFlexibleInt.self, forKey: .remaining) ?? SubscriptionFlexibleInt()
        periodStart = try container.decodeIfPresent(String.self, forKey: .periodStart)
        periodEnd = try container.decodeIfPresent(String.self, forKey: .periodEnd)
    }
}

struct SubscriptionFeatureStatusDTO: Decodable, Equatable {
    let planCode: String?
    let entitlementKey: String?
    let enabled: Bool?
    let billingCycle: String?
    let expireTime: String?
}

struct UserSubscriptionDTO: Decodable, Equatable {
    let id: String?
    let userId: String?
    let currentPlan: String?
    let planCode: String?
    let effectivePlan: String?
    let activePlans: [String]?
    let status: String?
    let billingCycle: String?
    let channel: String?
    let startTime: String?
    let expireTime: String?
    let autoRenew: Int?
    let externalSubscriptionId: String?
    let sourceRedeemCodeId: String?
    let entitlements: [String: SubscriptionEntitlementValue]?
    let featureSubscriptions: [String: SubscriptionFeatureStatusDTO]?
    let usage: [String: SubscriptionUsageQuotaDTO]?
}

struct RedeemCodeRequest: Encodable {
    let code: String
    let legalConsents: [LegalConsentSelection]?
    let legalConsentContext: LegalConsentContext?
}

struct RedeemCodePreviewDTO: Decodable, Equatable {
    let redeemable: Bool?
    let status: String?
    let codeTail: String?
    let planCode: String?
    let planName: String?
    let billingCycle: String?
    let serviceDurationDays: Int?
    let codeExpireTime: String?
}

struct RedeemCodeRedeemDTO: Decodable, Equatable {
    let redeemCodeId: String?
    let status: String?
    let redeemedTime: String?
    let subscription: UserSubscriptionDTO?
}
