import Foundation
import Combine

@MainActor
final class LegalDocumentViewModel: ObservableObject {
    @Published private(set) var metadata: LegalDocumentVersionDTO?
    @Published private(set) var html: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isUsingCache = false
    @Published var errorMessage: String?

    func load(
        document: LegalDocument,
        locale: String,
        requestedVersion: LegalDocumentVersionDTO? = nil,
        service: LegalDocumentService,
        cache: LegalDocumentCache,
        force: Bool = false
    ) async {
        guard !isLoading else { return }
        let expectedVersion = requestedVersion?.version ?? metadata?.version
        if !force,
           metadata?.slug == document.slug,
           metadata?.locale == locale,
           metadata?.version == expectedVersion,
           html != nil { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let target: LegalDocumentVersionDTO
            if let requestedVersion {
                target = requestedVersion
            } else {
                target = try await service.latest(slug: document.slug, locale: locale)
            }
            let content = try await service.download(target)
            try await cache.store(metadata: target, html: content, updateLatest: requestedVersion == nil)
            metadata = target
            html = content
            isUsingCache = false
        } catch {
            let cached: CachedLegalDocument?
            if let requestedVersion {
                cached = await cache.exact(metadata: requestedVersion)
            } else {
                cached = await cache.latest(slug: document.slug, locale: locale)
            }
            if let cached,
               service.validate(html: cached.html, metadata: cached.metadata) {
                metadata = cached.metadata
                html = cached.html
                isUsingCache = true
            } else {
                metadata = nil
                html = nil
                errorMessage = AppError.from(error).errorDescription
            }
        }
    }
}
