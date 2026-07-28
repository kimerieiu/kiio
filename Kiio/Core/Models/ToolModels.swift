import Foundation

struct ReminderTaskDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let requestId: String?
    let title: String?
    let content: String?
    let remindAt: String?
    let itemType: String?
    let endAt: String?
    let allDay: Bool?
    let timezone: String?
    let repeatType: String?
    let repeatRule: String?
    let repeatEndAt: String?
    let status: String?
    let sourceType: String?
    let rawText: String?
    let lastTriggerAt: String?
    let createdAt: String?
    let updatedAt: String?
    let logs: [ReminderTriggerLogDTO]?

    var displayTitle: String {
        title?.isEmpty == false ? title! : content ?? rawText ?? "Reminder"
    }

    var displayContent: String? {
        if let content, !content.isEmpty {
            return content
        }
        if let rawText, !rawText.isEmpty {
            return rawText
        }
        return nil
    }
}

struct ReminderTriggerLogDTO: Decodable, Identifiable, Equatable {
    let id: String
    let taskId: String?
    let userId: String?
    let triggerAt: String?
    let actualAt: String?
    let notifyChannel: String?
    let notifyStatus: String?
    let errorMessage: String?
    let createdAt: String?
    let updatedAt: String?

    var displayTime: String? {
        actualAt ?? triggerAt ?? createdAt
    }
}

struct AccountingBillDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let billType: String?
    let amount: Decimal?
    let currency: String?
    let title: String?
    let categoryId: String?
    let categoryName: String?
    let categoryCode: String?
    let accountId: String?
    let accountName: String?
    let accountType: String?
    let toAccountId: String?
    let toAccountName: String?
    let occurredAt: String?
    let remark: String?
    let sourceType: String?
    let sourceId: String?
    let parseRecordId: String?
    let status: String?
    let includeStatistics: Bool?
    let createdAt: String?
    let updatedAt: String?
    let tags: [AccountingTagDTO]?
    let tagNames: [String]?

    var displayTitle: String {
        title?.isEmpty == false ? title! : categoryName ?? "Bill"
    }

    var displayAmount: String {
        guard let amount else { return "--" }
        return "\(currency ?? "") \(amount)".trimmingCharacters(in: .whitespaces)
    }

    var displayTags: String? {
        if let tagNames, !tagNames.isEmpty {
            return tagNames.joined(separator: " / ")
        }
        let names = tags?.compactMap { $0.displayName }.filter { !$0.isEmpty } ?? []
        return names.isEmpty ? nil : names.joined(separator: " / ")
    }
}

struct AccountingTagDTO: Decodable, Identifiable, Equatable {
    let id: String
    let name: String?
    let tagName: String?
    let color: String?

    var displayName: String? {
        if let name, !name.isEmpty {
            return name
        }
        return tagName
    }
}

struct AccountingCategoryDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let parentId: String?
    let categoryType: String?
    let categoryName: String?
    let categoryCode: String?
    let icon: String?
    let color: String?
    let sort: Int?
    let systemFlag: Int?
    let enabled: Int?

    var displayName: String {
        categoryName?.isEmpty == false ? categoryName! : categoryCode ?? "Category"
    }
}

struct AccountingPaymentAccountDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let accountName: String?
    let accountType: String?
    let accountCode: String?
    let currency: String?
    let defaultFlag: Int?
    let enabled: Int?
    let sort: Int?

    var displayName: String {
        accountName?.isEmpty == false ? accountName! : accountType ?? accountCode ?? "Account"
    }
}

struct AccountingBillUpdateRequest: Encodable {
    let billType: String?
    let amount: Decimal?
    let currency: String?
    let title: String?
    let categoryId: String?
    let categoryCode: String?
    let accountId: String?
    let accountType: String?
    let toAccountId: String?
    let occurredAt: String?
    let remark: String?
    let status: String?
    let includeStatistics: Bool?
    let tagNames: [String]?
}

struct NewsRecordDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let requestId: String?
    let type: String?
    let categoryCode: String?
    let categoryName: String?
    let title: String?
    let summary: String?
    let snippet: String?
    let thumbnailUrl: String?
    let relativeTime: String?
    let keyword: String?
    let source: String?
    let newsDate: String?
    let tagType: String?
    let pushStatus: Int?
    let pushAt: String?
    let createdAt: String?
    let updatedAt: String?
    let links: [NewsLinkDTO]?

    var displayTitle: String {
        title?.isEmpty == false ? title! : summary ?? "News"
    }

    var displaySummary: String? {
        summary?.isEmpty == false ? summary : snippet
    }
}

struct NewsLinkDTO: Decodable, Equatable {
    let id: String?
    let recordId: String?
    let title: String?
    let url: String?
    let source: String?
}

struct NewsCategoryDTO: Decodable, Identifiable, Equatable {
    let id: String
    let name: String?
    let code: String?
    let icon: String?
    let sort: Int?
    let enabled: Int?
    let createdAt: String?
    let updatedAt: String?

    var displayName: String {
        name?.isEmpty == false ? name! : code ?? "News"
    }
}

struct ClothOutfitDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let requestId: String?
    let title: String?
    let content: String?
    let outfitDate: String?
    let rawText: String?
    let createdAt: String?
    let updatedAt: String?
    let items: [ClothOutfitItemDTO]?
    let links: [ClothProductLinkDTO]?

    var displayTitle: String {
        title?.isEmpty == false ? title! : "Outfit"
    }

    var displayContent: String? {
        if let content, !content.isEmpty {
            return content
        }
        if let rawText, !rawText.isEmpty {
            return rawText
        }
        return nil
    }
}

struct ClothOutfitItemDTO: Decodable, Identifiable, Equatable {
    let id: String
    let outfitId: String?
    let userId: String?
    let itemName: String?
    let itemType: String?
    let sort: Int?
    let createdAt: String?
    let updatedAt: String?

    var displayName: String {
        itemName?.isEmpty == false ? itemName! : itemType ?? "Item"
    }
}

struct ClothProductLinkDTO: Decodable, Identifiable, Equatable {
    let id: String?
    let outfitId: String?
    let itemId: String?
    let userId: String?
    let title: String?
    let priceText: String?
    let url: String?
    let createdAt: String?
    let updatedAt: String?

    var stableId: String {
        id ?? url ?? "\(outfitId ?? "")-\(itemId ?? "")-\(title ?? "")"
    }
}

struct MailAccountDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let email: String?
    let imapServer: String?
    let imapPort: Int?
    let smtpServer: String?
    let smtpPort: Int?
    let isDefault: Int?
    let enabled: Int?
    let lastUsedAt: String?
    let createdAt: String?
    let updatedAt: String?

    var displayTitle: String {
        email?.isEmpty == false ? email! : "Mail account"
    }
}

struct MailAccountSaveRequest: Encodable {
    let email: String
    let imapServer: String
    let imapPort: Int?
    let smtpServer: String
    let smtpPort: Int?
    let authCode: String?
    let isDefault: Int?
    let enabled: Int?
    let legalConsents: [LegalConsentSelection]?
    let legalConsentContext: LegalConsentContext?
}

struct MailOperationDTO: Decodable, Identifiable, Equatable {
    let id: String
    let userId: String?
    let accountId: String?
    let requestId: String?
    let operationType: String?
    let title: String?
    let summary: String?
    let status: String?
    let errorMessage: String?
    let rawText: String?
    let payloadJson: MailOperationPayloadDTO?
    let createdAt: String?
    let updatedAt: String?

    var displayTitle: String {
        title?.isEmpty == false ? title! : operationType ?? "Mail operation"
    }
}

struct MailOperationPayloadDTO: Decodable, Equatable {
    let query: String?
    let limit: Int?
    let since: String?
    let unreadOnly: Bool?
    let results: [MailSearchResultDTO]?
    let folders: [String]?
    let draft: MailDraftDTO?
}

struct MailSearchResultDTO: Decodable, Equatable {
    let id: String?
    let from: String?
    let subject: String?
    let date: String?
}

struct MailDraftDTO: Decodable, Equatable {
    let from: String?
    let to: [String]?
    let cc: [String]?
    let bcc: [String]?
    let subject: String?
    let body: String?
}
