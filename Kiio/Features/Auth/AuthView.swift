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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if availableModes.count > 1 {
                    Picker("", selection: $mode) {
                        ForEach(availableModes) { mode in
                            Text(L10n.tr(mode.localizationKey, locale: appState.locale)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                formFields

                KiioPrimaryButton(
                    title: primaryButtonTitle,
                    isLoading: authStore.isLoading,
                    isDisabled: !canSubmit
                ) {
                    Task { await submit() }
                }

                if mode != .password {
                    KiioSecondaryButton(
                        title: L10n.tr("auth.sendCode", locale: appState.locale),
                        isLoading: authStore.isLoading,
                        isDisabled: !isValidEmail(normalizedEmail)
                    ) {
                        Task { await sendCode() }
                    }
                }

                if mode == .forgot {
                    Button(L10n.tr("auth.backToSignIn", locale: appState.locale)) {
                        mode = .password
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KiioTheme.accent)
                    .frame(maxWidth: .infinity)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            KiioLogoView(size: 56)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr("auth.title", locale: appState.locale))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                Text(L10n.tr("auth.subtitle", locale: appState.locale))
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(KiioTheme.secondaryText)
            }
        }
        .padding(.top, 24)
    }

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: 12) {
            TextField(L10n.tr("auth.email.placeholder", locale: appState.locale), text: $email)
                .keyboardType(.emailAddress)
                .kiioTextField()

            if mode != .code {
                SecureField(passwordPlaceholder, text: $password)
                    .kiioTextField()
            }

            if mode != .password {
                TextField(L10n.tr("auth.code.placeholder", locale: appState.locale), text: $code)
                    .keyboardType(.numberPad)
                    .kiioTextField()
            }
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

    private var canSubmit: Bool {
        guard availableModes.contains(mode), isValidEmail(normalizedEmail) else {
            return false
        }

        switch mode {
        case .password:
            return !password.isEmpty
        case .code:
            return normalizedCode.count >= 4
        case .register, .forgot:
            return normalizedCode.count >= 4 && password.count >= 6
        }
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var normalizedCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
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
                await finishAuthenticatedFlow()
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

    private func finishAuthenticatedFlow() async {
        await bootstrapStore.refresh()
        guard authStore.isAuthenticated else {
            appState.showAuth()
            return
        }
        authStore.updateUser(bootstrapStore.userInfo)
        appState.showMain()
    }

    private func isValidEmail(_ value: String) -> Bool {
        value.range(of: #"^\S+@\S+\.\S+$"#, options: .regularExpression) != nil
    }

    private func normalizeModeAvailability() {
        if !availableModes.contains(mode) {
            mode = .password
        }
    }
}
