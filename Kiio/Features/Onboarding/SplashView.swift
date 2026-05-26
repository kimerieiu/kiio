import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var appState: AppState
    @State private var activeDot = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            KiioLogoView(size: 72)

            Text(L10n.tr("app.name", locale: appState.locale))
                .font(.system(size: 30, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(KiioTheme.text)
                .padding(.top, 12)

            Text(L10n.tr("splash.tagline", locale: appState.locale))
                .font(.system(size: 14))
                .foregroundStyle(KiioTheme.secondaryText)
                .padding(.top, 8)

            loadingDots
                .padding(.top, 56)

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 320_000_000)
                withAnimation(.easeInOut(duration: 0.22)) {
                    activeDot = (activeDot + 1) % 3
                }
            }
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
