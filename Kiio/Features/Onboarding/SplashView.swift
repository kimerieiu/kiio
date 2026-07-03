import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var appState: AppState
    let errorMessage: String?
    let isRetrying: Bool
    let retryAction: () -> Void
    @State private var activeDot = 0
    @State private var artworkVisible = false

    init(
        errorMessage: String? = nil,
        isRetrying: Bool = false,
        retryAction: @escaping () -> Void = {}
    ) {
        self.errorMessage = errorMessage
        self.isRetrying = isRetrying
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("SplashGreeting")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 286)
                .opacity(artworkVisible ? 1 : 0)
                .scaleEffect(artworkVisible ? 1 : 0.96)
                .accessibilityHidden(true)

            Text(L10n.tr("app.name", locale: appState.locale))
                .font(.system(size: 30, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(KiioTheme.text)
                .padding(.top, 18)

            Text(L10n.tr("splash.tagline", locale: appState.locale))
                .font(.system(size: 14))
                .foregroundStyle(KiioTheme.secondaryText)
                .padding(.top, 8)

            if let errorMessage {
                errorContent(errorMessage)
                    .padding(.top, 44)
            } else {
                loadingDots
                    .padding(.top, 56)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.84)) {
                artworkVisible = true
            }

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 320_000_000)
                withAnimation(.easeInOut(duration: 0.22)) {
                    activeDot = (activeDot + 1) % 3
                }
            }
        }
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(KiioTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            KiioSecondaryButton(
                title: L10n.tr("common.refresh", locale: appState.locale),
                isLoading: isRetrying,
                action: retryAction
            )
            .frame(maxWidth: 220)
        }
    }

    private var loadingDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(KiioTheme.accent.opacity(index == activeDot ? 1 : 0.25))
                    .frame(width: index == activeDot ? 18 : 6, height: 6)
            }
        }
    }
}
