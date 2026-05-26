import Foundation
import Combine

@MainActor
final class NotifyWebSocketClient: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var isConnecting = false

    private let tokenStore: TokenStore
    private let syncStore: SyncStore
    private let baseURL: URL
    private let decoder = JSONDecoder()
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var activeToken: String?
    private var manualClose = false
    private var reconnectAttempts = 0
    private let heartbeatInterval: UInt64 = 25_000_000_000
    private let reconnectMaxDelay: UInt64 = 30_000_000_000

    init(
        baseURL: URL = AppConfig.apiBaseURL,
        tokenStore: TokenStore,
        syncStore: SyncStore
    ) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore
        self.syncStore = syncStore
    }

    func connect() {
        guard let token = tokenStore.load()?.token, !token.isEmpty else {
            disconnect()
            return
        }

        if activeToken == token, isConnected || isConnecting {
            return
        }

        closeCurrentTask(resetToken: false, reconnect: false)
        manualClose = false
        activeToken = token
        isConnecting = true

        guard let url = notifyURL(token: token) else {
            isConnecting = false
            scheduleReconnect()
            return
        }

        var request = URLRequest(url: url, timeoutInterval: AppConfig.requestTimeout)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let socketTask = URLSession.shared.webSocketTask(with: request)
        task = socketTask
        socketTask.resume()

        isConnecting = false
        isConnected = true
        reconnectAttempts = 0
        listen(to: socketTask)
        startHeartbeat(for: socketTask)

        Task { [weak self] in
            await self?.syncStore.syncVersions(silent: true)
        }
    }

    func disconnect() {
        manualClose = true
        closeCurrentTask(resetToken: true, reconnect: false)
    }

    private func closeCurrentTask(resetToken: Bool, reconnect: Bool) {
        reconnectTask?.cancel()
        reconnectTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
        isConnecting = false

        if resetToken {
            activeToken = nil
            reconnectAttempts = 0
        } else if reconnect {
            scheduleReconnect()
        }
    }

    private func listen(to socketTask: URLSessionWebSocketTask) {
        receiveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await socketTask.receive()
                    await self?.handle(message)
                } catch {
                    await self?.handleDisconnect(from: socketTask)
                    break
                }
            }
        }
    }

    private func startHeartbeat(for socketTask: URLSessionWebSocketTask) {
        heartbeatTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: heartbeatInterval)
                guard !Task.isCancelled else { return }
                try? await socketTask.send(.string("PING"))
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let value):
            handlePayload(value)
        case .data(let data):
            handlePayload(data)
        @unknown default:
            break
        }
    }

    private func handlePayload(_ value: String) {
        guard !value.isEmpty, value != "PONG" else { return }
        guard let data = value.data(using: .utf8) else { return }
        handlePayload(data)
    }

    private func handlePayload(_ data: Data) {
        if let pong = try? decoder.decode(WebSocketPong.self, from: data),
           pong.type == "PONG" {
            return
        }
        guard let event = try? decoder.decode(AppDataChangedEvent.self, from: data) else {
            return
        }
        syncStore.handleDataChanged(event)
    }

    private func handleDisconnect(from socketTask: URLSessionWebSocketTask) {
        guard task === socketTask else { return }
        task = nil
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        isConnected = false
        isConnecting = false

        if !manualClose {
            scheduleReconnect()
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        guard activeToken?.isEmpty == false else { return }

        reconnectAttempts += 1
        let multiplier = UInt64(1 << min(reconnectAttempts, 5))
        let delay = min(reconnectMaxDelay, multiplier * 1_000_000_000)

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.connect()
        }
    }

    private func notifyURL(token: String) -> URL? {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme?.lowercased() == "https" ? "wss" : "ws"
        let basePath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components?.path = basePath.isEmpty ? "/notify/ws" : "/\(basePath)/notify/ws"
        components?.queryItems = [
            URLQueryItem(name: "accessToken", value: token)
        ]
        return components?.url
    }
}

private struct WebSocketPong: Decodable {
    let type: String?
}
