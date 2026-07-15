import SwiftUI

private enum AuthMode: String, CaseIterable, Identifiable {
    case password
    case code
    case register
    case forgot

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .password: return "auth.mode.password"
        case .code: return "auth.mode.code"
        case .register: return "auth.mode.register"
        case .forgot: return "auth.mode.forgot"
        }
    }

    var isSignInMode: Bool {
        self == .password || self == .code
    }

    var needsEmailCode: Bool {
        self == .code || self == .register || self == .forgot
    }
}

struct AuthView: View {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !mode.isSignInMode {
                    backToSignInButton
                }

                header

                if mode.isSignInMode && emailVerificationEnabled {
                    signInMethodPicker
                }

                formFields

                if mode.needsEmailCode {
                    sendCodeButton
                }

                if mode == .register {
                    registrationLegalConsent
                }

                KiioPrimaryButton(
                    title: primaryButtonTitle,
                    isLoading: authStore.isLoading,
                    isDisabled: !canSubmit
                ) {
                    Task { await submit() }
                }

                secondaryActions

                if mode != .register {
                    legalFooter
                }
            }
            .padding(24)
        }
        .background(KiioTheme.background.ignoresSafeArea())
        .kiioErrorAlert(message: $alertMessage, locale: appState.locale)
        .task {
            await bootstrapStore.ensureLoaded()
            normalizeModeAvailability()
        }
        .onChange(of: bootstrapStore.publicConfig) { _ in
            normalizeModeAvailability()
        }
        .sheet(item: $presentedLegalDocument) { document in
            LegalDocumentSheet(document: document)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            KiioLogoView(size: 56)

            VStack(alignment: .leading, spacing: 8) {
                Text(headerTitle)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                Text(headerSubtitle)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(KiioTheme.text)
            }
        }
        .padding(.top, 24)
    }

    private var signInMethodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("auth.signInMethod", locale: appState.locale))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KiioTheme.text)

            Picker("", selection: $mode) {
                Text(L10n.tr("auth.mode.password", locale: appState.locale)).tag(AuthMode.password)
                Text(L10n.tr("auth.mode.code", locale: appState.locale)).tag(AuthMode.code)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 12) {
            TextField("", text: $email, prompt: fieldPrompt("auth.email.placeholder"))
                .keyboardType(.emailAddress)
                .kiioTextField()

            if mode != .code {
                SecureField("", text: $password, prompt: Text(passwordPlaceholder).foregroundColor(authFieldPlaceholderColor))
                    .kiioTextField()
            }

            if mode != .password {
                TextField("", text: $code, prompt: fieldPrompt("auth.code.placeholder"))
                    .keyboardType(.numberPad)
                    .kiioTextField()
            }
        }
    }

    private var sendCodeButton: some View {
        KiioSecondaryButton(
            title: L10n.tr("auth.sendCode", locale: appState.locale),
            isLoading: authStore.isLoading,
            isDisabled: !isValidEmail(normalizedEmail)
        ) {
            Task { await sendCode() }
        }
    }

    private var registrationLegalConsent: some View {
        HStack(alignment: .top, spacing: 11) {
            Button {
                hasAcceptedRegistrationTerms.toggle()
            } label: {
                Image(systemName: hasAcceptedRegistrationTerms ? "checkmark.square.fill" : "square")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(hasAcceptedRegistrationTerms ? KiioTheme.accent : KiioTheme.mutedText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("auth.legal.consentAccessibility", locale: appState.locale))

            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.tr("auth.legal.consentPrefix", locale: appState.locale))
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)

                HStack(spacing: 6) {
                    legalButton(.termsOfService)
                    Text(L10n.tr("auth.legal.and", locale: appState.locale))
                        .font(.system(size: 13))
                        .foregroundStyle(KiioTheme.secondaryText)
                    legalButton(.privacyPolicy)
                }
            }
        }
        .padding(14)
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
        .padding(.top, 2)
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

    @ViewBuilder
    private var secondaryActions: some View {
        if mode.isSignInMode {
            VStack(spacing: 14) {
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
        } else {
            HStack(spacing: 5) {
                Text(L10n.tr("auth.haveAccountPrompt", locale: appState.locale))
                    .foregroundStyle(KiioTheme.text)
                Button {
                    returnToSignIn()
                } label: {
                    Text(L10n.tr("auth.signIn", locale: appState.locale))
                        .fontWeight(.semibold)
                        .foregroundStyle(KiioTheme.text)
                }
            }
            .font(.system(size: 14))
            .frame(maxWidth: .infinity)
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
        .padding(.top, 8)
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
            return normalizedCode.count >= 4 && password.count >= 6 && hasAcceptedRegistrationTerms
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
                try await authStore.register(
                    email: normalizedEmail,
                    password: password,
                    code: normalizedCode,
                    language: L10n.backendLocale(appState.locale)
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

    private func sendCode() async {
        guard isValidEmail(normalizedEmail) else {
            alertMessage = L10n.tr("auth.invalidEmail", locale: appState.locale)
            return
        }

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
