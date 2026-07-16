import Foundation

actor LegalDocumentCache {
    private let fileManager: FileManager
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let root = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directory = root.appendingPathComponent("kiio-legal", isDirectory: true)
    }

    func store(metadata: LegalDocumentVersionDTO, html: String, updateLatest: Bool) throws {
        try ensureDirectory()
        let key = exactKey(metadata)
        try Data(html.utf8).write(to: directory.appendingPathComponent("\(key).html"), options: .atomic)
        if updateLatest {
            try encoder.encode(metadata).write(
                to: directory.appendingPathComponent("\(latestKey(slug: metadata.slug, locale: metadata.locale)).json"),
                options: .atomic
            )
        }
    }

    func latest(slug: String, locale: String) -> CachedLegalDocument? {
        do {
            let metadataURL = directory.appendingPathComponent("\(latestKey(slug: slug, locale: locale)).json")
            let metadata = try decoder.decode(LegalDocumentVersionDTO.self, from: Data(contentsOf: metadataURL))
            let htmlURL = directory.appendingPathComponent("\(exactKey(metadata)).html")
            guard let html = String(data: try Data(contentsOf: htmlURL), encoding: .utf8) else { return nil }
            return CachedLegalDocument(metadata: metadata, html: html)
        } catch {
            return nil
        }
    }

    func exact(metadata: LegalDocumentVersionDTO) -> CachedLegalDocument? {
        do {
            let htmlURL = directory.appendingPathComponent("\(exactKey(metadata)).html")
            guard let html = String(data: try Data(contentsOf: htmlURL), encoding: .utf8) else { return nil }
            return CachedLegalDocument(metadata: metadata, html: html)
        } catch {
            return nil
        }
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func latestKey(slug: String, locale: String) -> String {
        safe("\(slug)-\(locale)-latest")
    }

    private func exactKey(_ metadata: LegalDocumentVersionDTO) -> String {
        safe("\(metadata.slug)-\(metadata.locale)-\(metadata.version)-\(metadata.contentHash)")
    }

    private func safe(_ value: String) -> String {
        value.map { character in
            character.isLetter || character.isNumber || character == "-" || character == "." ? character : "_"
        }.reduce(into: "") { $0.append($1) }
    }
}
