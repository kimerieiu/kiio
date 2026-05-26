import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var viewMode: HomeViewMode = .card

    private let tools: [HomeToolItem] = [
        HomeToolItem(icon: "bell", categoryKey: "home.category.productivity", titleKey: "home.tool.reminders.title", subtitleKey: "home.tool.reminders.subtitle", destination: .reminder, accent: Color(red: 123 / 255, green: 158 / 255, blue: 201 / 255), backgroundStart: Color(red: 123 / 255, green: 158 / 255, blue: 201 / 255), backgroundEnd: Color(red: 91 / 255, green: 127 / 255, blue: 168 / 255)),
        HomeToolItem(icon: "wallet.pass", categoryKey: "home.category.finance", titleKey: "home.tool.accounting.title", subtitleKey: "home.tool.accounting.subtitle", destination: .accounting, accent: Color(red: 95 / 255, green: 168 / 255, blue: 130 / 255), backgroundStart: Color(red: 139 / 255, green: 196 / 255, blue: 169 / 255), backgroundEnd: Color(red: 95 / 255, green: 168 / 255, blue: 130 / 255)),
        HomeToolItem(icon: "tshirt", categoryKey: "home.category.life", titleKey: "home.tool.outfit.title", subtitleKey: "home.tool.outfit.subtitle", destination: .outfit, accent: Color(red: 168 / 255, green: 123 / 255, blue: 138 / 255), backgroundStart: Color(red: 201 / 255, green: 168 / 255, blue: 180 / 255), backgroundEnd: Color(red: 168 / 255, green: 123 / 255, blue: 138 / 255)),
        HomeToolItem(icon: "newspaper", categoryKey: "home.category.info", titleKey: "home.tool.news.title", subtitleKey: "home.tool.news.subtitle", destination: .news, accent: Color(red: 123 / 255, green: 123 / 255, blue: 168 / 255), backgroundStart: Color(red: 168 / 255, green: 168 / 255, blue: 201 / 255), backgroundEnd: Color(red: 123 / 255, green: 123 / 255, blue: 168 / 255)),
        HomeToolItem(icon: "envelope", categoryKey: "home.category.communication", titleKey: "home.tool.mail.title", subtitleKey: "home.tool.mail.subtitle", destination: .mail, accent: Color(red: 184 / 255, green: 92 / 255, blue: 110 / 255), backgroundStart: Color(red: 217 / 255, green: 137 / 255, blue: 122 / 255), backgroundEnd: Color(red: 184 / 255, green: 92 / 255, blue: 110 / 255))
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                moodStrip

                if viewMode == .card {
                    toolCarousel
                } else {
                    toolList
                }
            }
            .padding(20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background(KiioTheme.background.ignoresSafeArea())
        .refreshable {
            await bootstrapStore.refresh()
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            KiioLogoView(size: 36)
            Text(L10n.tr("app.name", locale: appState.locale))
                .font(.system(size: 12, weight: .semibold))
                .tracking(2)
                .foregroundStyle(KiioTheme.secondaryText)

            Spacer()

            HStack(spacing: 4) {
                viewToggleButton(mode: .card, icon: "square.grid.2x2")
                viewToggleButton(mode: .list, icon: "list.bullet")
            }
            .padding(4)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var moodStrip: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 44, height: 44)
                .background(KiioTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(greeting)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(KiioTheme.text)
                HStack(spacing: 6) {
                    Text(L10n.tr("home.companionReady", locale: appState.locale))
                    Text("•")
                    Text(L10n.tr("home.mood.askByVoice", locale: appState.locale))
                }
                .font(.system(size: 12))
                .foregroundStyle(KiioTheme.secondaryText)
                .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "heart")
                    .font(.system(size: 10, weight: .semibold))
                Text(L10n.tr("home.mood.today", locale: appState.locale))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(KiioTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(KiioTheme.accentSoft)
            .clipShape(Capsule())
        }
        .padding(16)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var toolCarousel: some View {
        VStack(spacing: 10) {
            TabView {
                ForEach(tools) { tool in
                    NavigationLink {
                        toolDestination(tool.destination)
                    } label: {
                        HomeFeatureCard(tool: tool)
                            .padding(.horizontal, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 318)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    private var toolList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tr("home.tools", locale: appState.locale))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(KiioTheme.text)

            ForEach(tools) { tool in
                NavigationLink {
                    toolDestination(tool.destination)
                } label: {
                    HomeListCard(tool: tool)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func viewToggleButton(mode: HomeViewMode, icon: String) -> some View {
        Button {
            viewMode = mode
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(viewMode == mode ? .white : KiioTheme.secondaryText)
                .frame(width: 34, height: 34)
                .background(viewMode == mode ? KiioTheme.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    @ViewBuilder
    private func toolDestination(_ destination: HomeToolDestination) -> some View {
        switch destination {
        case .reminder:
            ReminderView()
        case .accounting:
            AccountingView()
        case .outfit:
            OutfitView()
        case .news:
            NewsView()
        case .mail:
            MailView()
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return L10n.tr("home.morning", locale: appState.locale) }
        if hour < 18 { return L10n.tr("home.afternoon", locale: appState.locale) }
        return L10n.tr("home.evening", locale: appState.locale)
    }
}

private struct HomeFeatureCard: View {
    @EnvironmentObject private var appState: AppState
    let tool: HomeToolItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [tool.backgroundStart, tool.backgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: tool.icon)
                .font(.system(size: 120, weight: .thin))
                .foregroundStyle(.white.opacity(0.08))
                .offset(x: 120, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(systemName: tool.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    Spacer()

                    Text(L10n.tr(tool.categoryKey, locale: appState.locale))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.white.opacity(0.14))
                        .clipShape(Capsule())
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr(tool.titleKey, locale: appState.locale))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(L10n.tr(tool.subtitleKey, locale: appState.locale))
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineSpacing(3)
                        .lineLimit(3)
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 292)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: tool.backgroundEnd.opacity(0.24), radius: 18, y: 10)
    }
}

private struct HomeListCard: View {
    @EnvironmentObject private var appState: AppState
    let tool: HomeToolItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: tool.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tool.accent)
                .frame(width: 44, height: 44)
                .background(tool.accent.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(L10n.tr(tool.titleKey, locale: appState.locale))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                    Text(L10n.tr(tool.categoryKey, locale: appState.locale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tool.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(tool.accent.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(L10n.tr(tool.subtitleKey, locale: appState.locale))
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
        }
        .padding(16)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private enum HomeViewMode: Equatable {
    case card
    case list
}

private struct HomeToolItem: Identifiable {
    let icon: String
    let categoryKey: String
    let titleKey: String
    let subtitleKey: String
    let destination: HomeToolDestination
    let accent: Color
    let backgroundStart: Color
    let backgroundEnd: Color

    var id: String { titleKey }
}

private enum HomeToolDestination {
    case reminder
    case accounting
    case outfit
    case news
    case mail
}
