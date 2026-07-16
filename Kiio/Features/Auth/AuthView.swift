import SwiftUI

private enum AuthMode: Hashable {
    case password
    case code
    case register
    case forgot

    var isSignInMode: Bool {
        self == .password || self == .code
    }

    var needsEmailCode: Bool {
        self == .code || self == .register || self == .forgot
    }
}

struct AuthView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var mode: AuthMode = .password
    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var alertMessage: String?
    @State private var hasAcceptedRegistrationTerms = false
    @State private var presentedLegalDocument: LegalDocument?
    @State private var registrationLegalVersions: [LegalDocumentVersionDTO] = []
    @State private var isLoadingRegistrationLegal = false
    @State private var registrationLegalError: String?
    @State private var isSendingCode = false

    private let legalFooterReservedHeight: CGFloat = 80

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !mode.isSignInMode {
                        backToSignInButton
                    }

                    header

                    if mode.isSignInMode && emailVerificationEnabled {
                        signInMethodPicker
                    }

                    formFields

                    if mode == .register {
                        registrationLegalConsent
                    }

                    KiioPrimaryButton(
                        title: primaryButtonTitle,
                        isLoading: authStore.isLoading && !isSendingCode,
                        isDisabled: !canSubmit || isSendingCode
                    ) {
                        Task { await submit() }
                    }

                    if mode.isSignInMode {
                        secondaryActions
                    }
                }
                .frame(maxWidth: 460, alignment: .leading)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(
                    minHeight: max(0, geometry.size.height - legalFooterReservedHeight),
                    alignment: .center
                )
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                legalFooter
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(KiioTheme.background)
            }
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
        .task {
            await bootstrapStore.ensureLoaded()
            await loadRegistrationLegalVersions()
            normalizeModeAvailability()
        }
        .onChange(of: bootstrapStore.publicConfig) { _ in
            normalizeModeAvailability()
        }
        .sheet(item: $presentedLegalDocument) { document in
            LegalDocumentSheet(
                document: document,
                requestedVersion: registrationLegalVersions.first { $0.slug == document.slug }
            )
        }
        .onChange(of: appState.locale) { _ in
            hasAcceptedRegistrationTerms = false
            registrationLegalVersions = []
            Task { await loadRegistrationLegalVersions(force: true) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(headerTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(KiioTheme.text)
            Text(headerSubtitle)
                .font(.system(size: 14))
                .lineSpacing(2)
                .foregroundStyle(KiioTheme.secondaryText)
        }
    }

    private var signInMethodPicker: some View {
        Picker("", selection: $mode) {
            Text(L10n.tr("auth.mode.password", locale: appState.locale)).tag(AuthMode.password)
            Text(L10n.tr("auth.mode.code", locale: appState.locale)).tag(AuthMode.code)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 12) {
            TextField("", text: $email, prompt: fieldPrompt("auth.email.placeholder"))
                .keyboardType(.emailAddress)
                .kiioTextField()

            if mode == .password || mode == .register || mode == .forgot {
                SecureField(
                    "",
                    text: $password,
                    prompt: Text(passwordPlaceholder).foregroundColor(authFieldPlaceholderColor)
                )
                .kiioTextField()
            }

            if mode.needsEmailCode {
                emailCodeField
            }
        }
    }

    private var emailCodeField: some View {
        HStack(spacing: 10) {
            TextField("", text: $code, prompt: fieldPrompt("auth.code.placeholder"))
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(KiioTheme.text)
                .tint(KiioTheme.accent)

            Divider()
                .frame(height: 24)

            Button {
                Task { await sendCode() }
            } label: {
                Group {
                    if isSendingCode {
                        ProgressView()
                            .controlSize(.small)
                            .tint(KiioTheme.accent)
                    } else {
                        Text(L10n.tr("auth.sendCode", locale: appState.locale))
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(canSendCode ? KiioTheme.accent : KiioTheme.mutedText)
                .frame(minWidth: 82)
                .frame(height: 38)
                .background(canSendCode ? KiioTheme.accentSoft : KiioTheme.disabledFill.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSendCode || authStore.isLoading)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 50)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }

    private var registrationLegalConsent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    guard registrationLegalReady else {
                        Task { await loadRegistrationLegalVersions(force: true) }
                        return
                    }
                    hasAcceptedRegistrationTerms.toggle()
                } label: {
                    Image(systemName: hasAcceptedRegistrationTerms ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(hasAcceptedRegistrationTerms ? KiioTheme.accent : KiioTheme.mutedText)
                }
                .buttonStyle(.plain)
                .disabled(!registrationLegalReady)
                .accessibilityLabel(L10n.tr("auth.legal.consentAccessibility", locale: appState.locale))

                Text(registrationConsentText)
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .tint(KiioTheme.accent)
                    .environment(\.openURL, OpenURLAction { url in
                        openRegistrationLegalURL(url)
                    })
            }

            if isLoadingRegistrationLegal {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.small)
                    Text(L10n.tr("auth.legal.loading", locale: appState.locale))
                }
                .font(.system(size: 12))
                .foregroundStyle(KiioTheme.secondaryText)
                .padding(.leading, 30)
            } else if registrationLegalError != nil {
                Button(L10n.tr("auth.legal.retry", locale: appState.locale)) {
                    Task { await loadRegistrationLegalVersions(force: true) }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KiioTheme.danger)
                .buttonStyle(.plain)
                .padding(.leading, 30)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
    }

    private var legalFooter: some View {
        HStack(spacing: 14) {
            legalButton(.termsOfService)
            Divider()
                .frame(height: 14)
            legalButton(.privacyPolicy)
        }
        .frame(maxWidth: .infinity)
    }

    private func legalButton(_ document: LegalDocument) -> some View {
        Button {
            presentedLegalDocument = document
        } label: {
            Text(L10n.tr(document.titleKey, locale: appState.locale))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .underline()
        }
        .buttonStyle(.plain)
    }

    private var secondaryActions: some View {
        VStack(spacing: 12) {
            if mode == .password && emailVerificationEnabled {
                Button {
                    enterSecondaryMode(.forgot)
                } label: {
                    Text(L10n.tr("auth.forgotPasswordLink", locale: appState.locale))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KiioTheme.text)
                }
                .frame(maxWidth: .infinity)
            }

            if userRegistrationEnabled {
                HStack(spacing: 5) {
                    Text(L10n.tr("auth.noAccountPrompt", locale: appState.locale))
                        .foregroundStyle(KiioTheme.text)
                    Button {
                        enterSecondaryMode(.register)
                    } label: {
                        Text(L10n.tr("auth.createAccountLink", locale: appState.locale))
                            .fontWeight(.semibold)
                            .foregroundStyle(KiioTheme.text)
                    }
                }
                .font(.system(size: 14))
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var backToSignInButton: some View {
        Button {
            returnToSignIn()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                Text(L10n.tr("auth.backToSignIn", locale: appState.locale))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(KiioTheme.text)
        }
    }

    private var primaryButtonTitle: String {
        switch mode {
        case .password: return L10n.tr("auth.signIn", locale: appState.locale)
        case .code: return L10n.tr("auth.signInCode", locale: appState.locale)
        case .register: return L10n.tr("auth.createAccount", locale: appState.locale)
        case .forgot: return L10n.tr("auth.resetPassword", locale: appState.locale)
        }
    }

    private var headerTitle: String {
        switch mode {
        case .password, .code:
            return L10n.tr("auth.title", locale: appState.locale)
        case .register:
            return L10n.tr("auth.registerTitle", locale: appState.locale)
        case .forgot:
            return L10n.tr("auth.forgotTitle", locale: appState.locale)
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .password:
            return L10n.tr("auth.subtitle", locale: appState.locale)
        case .code:
            return L10n.tr("auth.codeSubtitle", locale: appState.locale)
        case .register:
            return L10n.tr("auth.registerSubtitle", locale: appState.locale)
        case .forgot:
            return L10n.tr("auth.forgotSubtitle", locale: appState.locale)
        }
    }

    private var availableModes: [AuthMode] {
        var modes: [AuthMode] = [.password]

        if emailVerificationEnabled {
            modes.append(.code)
            if userRegistrationEnabled {
                modes.append(.register)
            }
            modes.append(.forgot)
        }

        return modes
    }

    private var emailVerificationEnabled: Bool {
        bootstrapStore.publicConfig?.enableEmailRegister ?? true
    }

    private var userRegistrationEnabled: Bool {
        (bootstrapStore.publicConfig?.allowUserRegister ?? true) && emailVerificationEnabled
    }

    private var passwordPlaceholder: String {
        return mode == .forgot
            ? L10n.tr("auth.newPassword.placeholder", locale: appState.locale)
            : L10n.tr("auth.password.placeholder", locale: appState.locale)
    }

    private var authFieldPlaceholderColor: Color {
        KiioTheme.text.opacity(0.58)
    }

    private var canSendCode: Bool {
        mode.needsEmailCode
            && availableModes.contains(mode)
            && isValidEmail(normalizedEmail)
    }

    private var registrationConsentText: AttributedString {
        var result = AttributedString(L10n.tr("auth.legal.consentPrefix", locale: appState.locale) + " ")

        var terms = AttributedString(L10n.tr(LegalDocument.termsOfService.titleKey, locale: appState.locale))
        terms.link = URL(string: "kiio-legal://terms")
        result += terms

        result += AttributedString(" " + L10n.tr("auth.legal.and", locale: appState.locale) + " ")

        var privacy = AttributedString(L10n.tr(LegalDocument.privacyPolicy.titleKey, locale: appState.locale))
        privacy.link = URL(string: "kiio-legal://privacy")
        result += privacy

        return result
    }

    private var canSubmit: Bool {
        guard availableModes.contains(mode), isValidEmail(normalizedEmail) else {
            return false
        }

        switch mode {
        case .password:
            return !password.isEmpty
        case .code:
            return normalizedCode.count >= 4
        case .register:
            return normalizedCode.count >= 4
                && password.count >= 6
                && hasAcceptedRegistrationTerms
                && registrationLegalReady
        case .forgot:
            return normalizedCode.count >= 4 && password.count >= 6
        }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var normalizedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fieldPrompt(_ key: String) -> Text {
        Text(L10n.tr(key, locale: appState.locale))
            .foregroundColor(authFieldPlaceholderColor)
    }

    private func openRegistrationLegalURL(_ url: URL) -> OpenURLAction.Result {
        guard url.scheme == "kiio-legal" else {
            return .systemAction
        }

        switch url.host {
        case "terms":
            presentedLegalDocument = .termsOfService
        case "privacy":
            presentedLegalDocument = .privacyPolicy
        default:
            return .discarded
        }
        return .handled
    }

    private func submit() async {
        do {
            switch mode {
            case .password:
                try await authStore.loginWithPassword(email: normalizedEmail, password: password)
                await finishAuthenticatedFlow()
            case .code:
                try await authStore.loginWithCode(email: normalizedEmail, code: normalizedCode)
                await finishAuthenticatedFlow()
            case .register:
                guard registrationLegalReady else {
                    alertMessage = L10n.tr("auth.legal.loadFailed", locale: appState.locale)
                    return
                }
                try await authStore.register(
                    email: normalizedEmail,
                    password: password,
                    code: normalizedCode,
                    language: L10n.backendLocale(appState.locale),
                    legalConsents: registrationLegalVersions.map(\.consentSelection),
                    legalConsentContext: .ios(locale: appState.locale, source: "REGISTRATION")
                )
                await finishAuthenticatedFlow(destination: .invite)
            case .forgot:
                try await authStore.resetPassword(email: normalizedEmail, code: normalizedCode, password: password)
                alertMessage = L10n.tr("auth.resetSuccess", locale: appState.locale)
                mode = .password
                password = ""
                code = ""
            }
        } catch {
            alertMessage = AppError.from(error).errorDescription
        }
    }

    private var registrationLegalReady: Bool {
        Set(registrationLegalVersions.map(\.slug)) == Set(["terms", "privacy"])
            && registrationLegalVersions.allSatisfy { $0.locale == L10n.legalLocale(appState.locale) }
    }

    private func loadRegistrationLegalVersions(force: Bool = false) async {
        guard !isLoadingRegistrationLegal else { return }
        if registrationLegalReady, !force { return }

        isLoadingRegistrationLegal = true
        registrationLegalError = nil
        defer { isLoadingRegistrationLegal = false }
        do {
            let locale = L10n.legalLocale(appState.locale)
            let terms = try await dependencies.legalDocumentService.latest(slug: "terms", locale: locale)
            let privacy = try await dependencies.legalDocumentService.latest(slug: "privacy", locale: locale)
            registrationLegalVersions = [terms, privacy]
        } catch {
            registrationLegalVersions = []
            registrationLegalError = AppError.from(error).errorDescription
        }
    }

    private func sendCode() async {
        guard !isSendingCode, !authStore.isLoading else { return }
        guard isValidEmail(normalizedEmail) else {
            alertMessage = L10n.tr("auth.invalidEmail", locale: appState.locale)
            return
        }

        isSendingCode = true
        defer { isSendingCode = false }
        do {
            try await authStore.sendEmailCode(email: normalizedEmail)
            alertMessage = L10n.tr("auth.codeSent", locale: appState.locale)
        } catch {
            alertMessage = AppError.from(error).errorDescription
        }
    }

    private func finishAuthenticatedFlow(destination: AuthSuccessDestination = .main) async {
        await bootstrapStore.refresh()
        guard authStore.isAuthenticated else {
            appState.showAuth()
            return
        }
        authStore.updateUser(bootstrapStore.userInfo)
        switch destination {
        case .main:
            appState.showMain()
        case .invite:
            appState.showInvite()
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

    private func normalizeModeAvailability() {
        if !availableModes.contains(mode) {
            mode = .password
        }
    }

    private func enterSecondaryMode(_ nextMode: AuthMode) {
        guard availableModes.contains(nextMode) else { return }
        mode = nextMode
        password = ""
        code = ""
        if nextMode == .register {
            hasAcceptedRegistrationTerms = false
        }
    }

    private func returnToSignIn() {
        mode = .password
        password = ""
        code = ""
        hasAcceptedRegistrationTerms = false
    }
}

private enum AuthSuccessDestination {
    case main
    case invite
}
