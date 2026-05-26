import Foundation
import Combine

@MainActor
final class SyncStore: ObservableObject {
    @Published private(set) var remoteVersions: [AppNotifyModule: Int] = [:]
    @Published private(set) var localVersions: [AppNotifyModule: Int] = [:]
    @Published private(set) var dirtyModules: Set<AppNotifyModule> = []
    @Published private(set) var latestEvent: AppDataChangedEvent?
    @Published var isSyncingVersions = false

    private let notifyService: NotifyService
    private var seenEventIds: [String] = []
    private let maxSeenEvents = 200

    init(notifyService: NotifyService) {
        self.notifyService = notifyService
    }

    func handleDataChanged(_ event: AppDataChangedEvent) {
        guard event.isDataChanged, let module = event.notifyModule else { return }

        if let eventId = event.eventId {
            guard !seenEventIds.contains(eventId) else { return }
            seenEventIds.append(eventId)
            if seenEventIds.count > maxSeenEvents {
                seenEventIds.removeFirst(seenEventIds.count - maxSeenEvents)
            }
        }

        markDirty(module, version: event.version ?? 0, event: event)
    }

    func markDirty(_ module: AppNotifyModule, version: Int = 0, event: AppDataChangedEvent? = nil) {
        let nextVersion = max(remoteVersions[module] ?? 0, version)
        remoteVersions[module] = nextVersion
        dirtyModules.insert(module)
        latestEvent = event ?? AppDataChangedEvent.sync(module: module, version: nextVersion)
    }

    func targetVersion(_ module: AppNotifyModule, incomingVersion: Int? = nil) -> Int {
        max(incomingVersion ?? 0, remoteVersions[module] ?? 0, localVersions[module] ?? 0)
    }

    func hasRemoteVersion(_ module: AppNotifyModule, after version: Int) -> Bool {
        (remoteVersions[module] ?? 0) > version
    }

    func markSynced(_ module: AppNotifyModule, version: Int? = nil) {
        let resolvedVersion = version.map { max($0, localVersions[module] ?? 0) } ?? targetVersion(module)
        localVersions[module] = resolvedVersion

        if (remoteVersions[module] ?? 0) <= resolvedVersion {
            dirtyModules.remove(module)
        }
    }

    func syncVersions(silent: Bool = true) async {
        if isSyncingVersions {
            return
        }

        isSyncingVersions = true
        defer { isSyncingVersions = false }

        do {
            let response = try await notifyService.versions()
            for (rawModule, version) in response.versions {
                guard let module = AppNotifyModule(notifyValue: rawModule) else { continue }
                if version > (remoteVersions[module] ?? 0) {
                    markDirty(module, version: version, event: AppDataChangedEvent.sync(module: module, version: version))
                }
            }
        } catch {
            if !silent {
                latestEvent = nil
            }
        }
    }

    func reset() {
        remoteVersions = [:]
        localVersions = [:]
        dirtyModules = []
        latestEvent = nil
        seenEventIds = []
        isSyncingVersions = false
    }
}
