import Foundation
import Combine

@MainActor
final class AppDependencies: ObservableObject {
    let settingsStore: LocalSettingsStore
    let tokenStore: TokenStore
    let apiClient: APIClient

    let authService: AuthService
    let userService: UserService
    let bootstrapService: BootstrapService
    let deviceService: DeviceService
    let chatService: ChatService
    let reminderService: ReminderService
    let accountingService: AccountingService
    let newsService: NewsService
    let outfitService: OutfitService
    let mailService: MailService
    let notifyService: NotifyService

    let appState: AppState
    let authStore: AuthStore
    let bootstrapStore: BootstrapStore
    let deviceStore: DeviceStore
    let syncStore: SyncStore
    let notifyWebSocketClient: NotifyWebSocketClient

    init() {
        let settingsStore = LocalSettingsStore()
        let tokenStore = TokenStore()
        let apiClient = APIClient(tokenStore: tokenStore)

        let authService = AuthService(apiClient: apiClient)
        let userService = UserService(apiClient: apiClient)
        let bootstrapService = BootstrapService(apiClient: apiClient)
        let deviceService = DeviceService(apiClient: apiClient)
        let chatService = ChatService(apiClient: apiClient)
        let reminderService = ReminderService(apiClient: apiClient)
        let accountingService = AccountingService(apiClient: apiClient)
        let newsService = NewsService(apiClient: apiClient)
        let outfitService = OutfitService(apiClient: apiClient)
        let mailService = MailService(apiClient: apiClient)
        let notifyService = NotifyService(apiClient: apiClient)

        let appState = AppState(settings: settingsStore)
        let authStore = AuthStore(authService: authService, userService: userService, tokenStore: tokenStore)
        let bootstrapStore = BootstrapStore(
            bootstrapService: bootstrapService,
            userService: userService,
            tokenStore: tokenStore
        )
        let deviceStore = DeviceStore(deviceService: deviceService, bootstrapStore: bootstrapStore)
        let syncStore = SyncStore(notifyService: notifyService)
        let notifyWebSocketClient = NotifyWebSocketClient(tokenStore: tokenStore, syncStore: syncStore)

        apiClient.localeProvider = {
            settingsStore.locale
        }
        apiClient.onUnauthorized = { [weak authStore] in
            authStore?.handleUnauthorized()
        }

        self.settingsStore = settingsStore
        self.tokenStore = tokenStore
        self.apiClient = apiClient
        self.authService = authService
        self.userService = userService
        self.bootstrapService = bootstrapService
        self.deviceService = deviceService
        self.chatService = chatService
        self.reminderService = reminderService
        self.accountingService = accountingService
        self.newsService = newsService
        self.outfitService = outfitService
        self.mailService = mailService
        self.notifyService = notifyService
        self.appState = appState
        self.authStore = authStore
        self.bootstrapStore = bootstrapStore
        self.deviceStore = deviceStore
        self.syncStore = syncStore
        self.notifyWebSocketClient = notifyWebSocketClient
    }
}
