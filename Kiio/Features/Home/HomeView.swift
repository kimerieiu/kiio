import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var bootstrapStore: BootstrapStore

    @State private var viewMode: HomeViewMode = .card
    @State private var currentCard = 0
    @GestureState private var cardDragOffset: CGFloat = 0

    private let tools: [HomeToolItem] = [
        HomeToolItem(icon: "bell", categoryKey: "home.category.productivity", titleKey: "home.tool.reminders.title", subtitleKey: "home.tool.reminders.subtitle", destination: .reminder, accent: KiioTheme.accent, softTint: Color(red: 237 / 255, green: 232 / 255, blue: 225 / 255)),
        HomeToolItem(icon: "wallet.pass", categoryKey: "home.category.finance", titleKey: "home.tool.accounting.title", subtitleKey: "home.tool.accounting.subtitle", destination: .accounting, accent: Color(red: 106 / 255, green: 90 / 255, blue: 73 / 255), softTint: Color(red: 221 / 255, green: 213 / 255, blue: 200 / 255)),
        HomeToolItem(icon: "tshirt", categoryKey: "home.category.life", titleKey: "home.tool.outfit.title", subtitleKey: "home.tool.outfit.subtitle", destination: .outfit, accent: Color(red: 103 / 255, green: 92 / 255, blue: 80 / 255), softTint: Color(red: 230 / 255, green: 224 / 255, blue: 215 / 255)),
        HomeToolItem(icon: "newspaper", categoryKey: "home.category.info", titleKey: "home.tool.news.title", subtitleKey: "home.tool.news.subtitle", destination: .news, accent: Color(red: 107 / 255, green: 90 / 255, blue: 77 / 255), softTint: Color(red: 224 / 255, green: 218 / 255, blue: 209 / 255)),
        HomeToolItem(icon: "envelope", categoryKey: "home.category.communication", titleKey: "home.tool.mail.title", subtitleKey: "home.tool.mail.subtitle", destination: .mail, accent: Color(red: 150 / 255, green: 64 / 255, blue: 84 / 255), softTint: Color(red: 239 / 255, green: 220 / 255, blue: 222 / 255))
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
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
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
                    .lineLimit(1)
                Text("\(L10n.tr("home.companionReady", locale: appState.locale)) / \(L10n.tr("home.mood.askByVoice", locale: appState.locale))")
                    .font(.system(size: 12))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(2)
            }
            .layoutPriority(1)

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
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.035), radius: 14, y: 6)
    }

    private var toolCarousel: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let cardWidth = min(max(proxy.size.width * 0.72, 232), 274)

                ZStack {
                    ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                        let style = flowStyle(for: index, cardWidth: cardWidth)

                        NavigationLink {
                            toolDestination(tool.destination)
                        } label: {
                            HomeFeatureCard(tool: tool)
                                .frame(width: cardWidth)
                        }
                        .buttonStyle(.plain)
                        .rotation3DEffect(.degrees(style.rotation), axis: (x: 0, y: 1, z: 0), perspective: 0.74)
                        .scaleEffect(style.scale)
                        .offset(x: style.xOffset)
                        .opacity(style.opacity)
                        .zIndex(style.zIndex)
                        .allowsHitTesting(index == currentCard)
                        .accessibilityHidden(index != currentCard)
                    }
                }
                .frame(width: proxy.size.width, height: 286)
                .contentShape(Rectangle())
            }
            .frame(height: 286)
            .simultaneousGesture(cardDragGesture)
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: currentCard)
            .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.88), value: cardDragOffset)

            HStack(spacing: 8) {
                ForEach(tools.indices, id: \.self) { index in
                    Button {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            currentCard = index
                        }
                    } label: {
                        Capsule()
                            .fill(index == currentCard ? KiioTheme.accent : KiioTheme.accent.opacity(0.24))
                            .frame(width: index == currentCard ? 18 : 6, height: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.tr(tools[index].titleKey, locale: appState.locale))
                }
            }
        }
    }

    private var cardDragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($cardDragOffset) { value, state, _ in
                state = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 44
                guard tools.count > 1 else { return }

                if value.translation.width < -threshold {
                    moveCard(by: 1)
                } else if value.translation.width > threshold {
                    moveCard(by: -1)
                }
            }
    }

    private func moveCard(by step: Int) {
        guard !tools.isEmpty else { return }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            currentCard = (currentCard + step + tools.count) % tools.count
        }
    }

    private func flowStyle(for index: Int, cardWidth: CGFloat) -> HomeFlowCardStyle {
        let offset = circularOffset(for: index)
        let absOffset = abs(offset)

        if absOffset == 0 {
            let rotation = max(-16, min(16, -Double(cardDragOffset / 14)))
            return HomeFlowCardStyle(
                xOffset: cardDragOffset * 0.42,
                rotation: rotation,
                scale: 1,
                opacity: 1,
                zIndex: 10
            )
        }

        guard absOffset <= 2 else {
            return HomeFlowCardStyle(xOffset: 0, rotation: 0, scale: 0.76, opacity: 0, zIndex: 0)
        }

        let sign: CGFloat = offset < 0 ? -1 : 1
        let depth = CGFloat(absOffset)
        let xOffset = sign * cardWidth * (0.64 + 0.48 * (depth - 1)) + cardDragOffset * 0.16
        let scale: CGFloat = absOffset == 1 ? 0.94 : 0.82
        let opacity: Double = absOffset == 1 ? 0.62 : 0.1

        return HomeFlowCardStyle(
            xOffset: xOffset,
            rotation: -Double(sign) * 44,
            scale: scale,
            opacity: opacity,
            zIndex: Double(10 - absOffset)
        )
    }

    private func circularOffset(for index: Int) -> Int {
        let total = tools.count
        guard total > 0 else { return 0 }

        var offset = index - currentCard
        if offset > total / 2 { offset -= total }
        if offset < -total / 2 { offset += total }
        return offset
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

private struct HomeFlowCardStyle {
    let xOffset: CGFloat
    let rotation: Double
    let scale: CGFloat
    let opacity: Double
    let zIndex: Double
}

private struct HomeFeatureCard: View {
    @EnvironmentObject private var appState: AppState
    let tool: HomeToolItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    KiioTheme.surface,
                    tool.softTint.opacity(0.42),
                    KiioTheme.surface.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(tool.softTint.opacity(0.5))
                .frame(width: 184, height: 184)
                .offset(x: 178, y: 106)

            Image(systemName: tool.icon)
                .font(.system(size: 112, weight: .thin))
                .foregroundStyle(tool.accent.opacity(0.08))
                .offset(x: 116, y: -66)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: tool.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(tool.accent)
                        .frame(width: 48, height: 48)
                        .background(tool.softTint.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    Spacer()

                    Text(L10n.tr(tool.categoryKey, locale: appState.locale))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tool.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(tool.softTint.opacity(0.65))
                        .clipShape(Capsule())
                }

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr(tool.titleKey, locale: appState.locale))
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(2)
                    Text(L10n.tr(tool.subtitleKey, locale: appState.locale))
                        .font(.system(size: 15))
                        .foregroundStyle(KiioTheme.secondaryText)
                        .lineSpacing(3)
                        .lineLimit(3)
                }

                HStack {
                    Capsule()
                        .fill(tool.accent)
                        .frame(width: 34, height: 4)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tool.accent)
                        .frame(width: 34, height: 34)
                        .background(KiioTheme.surface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(KiioTheme.border, lineWidth: 1))
                }
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 278)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
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
                .background(tool.softTint.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(L10n.tr(tool.titleKey, locale: appState.locale))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KiioTheme.text)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(L10n.tr(tool.categoryKey, locale: appState.locale))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tool.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(tool.softTint.opacity(0.7))
                        .clipShape(Capsule())
                }

                Text(L10n.tr(tool.subtitleKey, locale: appState.locale))
                    .font(.system(size: 13))
                    .foregroundStyle(KiioTheme.secondaryText)
                    .lineLimit(2)
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KiioTheme.mutedText)
        }
        .padding(16)
        .frame(minHeight: 88)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 12, y: 6)
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
    let softTint: Color

    var id: String { titleKey }
}

private enum HomeToolDestination {
    case reminder
    case accounting
    case outfit
    case news
    case mail
}
