import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @State private var currentIndex = 0

    private let slides: [WelcomeSlide] = [
        WelcomeSlide(icon: "calendar", titleKey: "welcome.slides.s1.title", subtitleKey: "welcome.slides.s1.sub"),
        WelcomeSlide(icon: "wallet.pass", titleKey: "welcome.slides.s2.title", subtitleKey: "welcome.slides.s2.sub"),
        WelcomeSlide(icon: "sparkles", titleKey: "welcome.slides.s3.title", subtitleKey: "welcome.slides.s3.sub")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(L10n.tr("common.skip", locale: appState.locale)) {
                    completeWelcome()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KiioTheme.secondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            TabView(selection: $currentIndex) {
                ForEach(slides.indices, id: \.self) { index in
                    slideContent(slides[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 24) {
                pageDots

                KiioPrimaryButton(title: actionTitle) {
                    handleNext()
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 34)
            .background(
                LinearGradient(
                    colors: [KiioTheme.background.opacity(0), KiioTheme.background],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(KiioTheme.background.ignoresSafeArea())
    }

    private func slideContent(_ slide: WelcomeSlide) -> some View {
        VStack(spacing: 36) {
            Spacer()

            Image(systemName: slide.icon)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 120, height: 120)
                .background(Color.black.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(spacing: 10) {
                Text(L10n.tr(slide.titleKey, locale: appState.locale))
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KiioTheme.text)

                Text(L10n.tr(slide.subtitleKey, locale: appState.locale))
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KiioTheme.secondaryText)
                    .padding(.horizontal, 22)
            }

            Spacer()
        }
        .padding(.bottom, 90)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentIndex ? KiioTheme.accent : KiioTheme.text.opacity(0.15))
                    .frame(width: index == currentIndex ? 18 : 5, height: 5)
                    .animation(.easeInOut(duration: 0.25), value: currentIndex)
            }
        }
    }

    private var actionTitle: String {
        currentIndex == slides.count - 1
            ? L10n.tr("welcome.cta", locale: appState.locale)
            : L10n.tr("common.next", locale: appState.locale)
    }

    private func handleNext() {
        if currentIndex < slides.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                currentIndex += 1
            }
            return
        }

        completeWelcome()
    }

    private func completeWelcome() {
        appState.completeWelcome(isAuthenticated: authStore.isAuthenticated)
    }
}

private struct WelcomeSlide {
    let icon: String
    let titleKey: String
    let subtitleKey: String
}
