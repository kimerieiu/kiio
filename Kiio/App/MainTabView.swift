import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @Namespace private var tabSelectionNamespace
    @State private var loadedTabs: Set<MainTab> = [.home]

    private let tabs: [MainTab] = [.home, .chat, .device, .profile]

    var body: some View {
        ZStack {
            ForEach(tabs, id: \.self) { tab in
                if loadedTabs.contains(tab) || tab == appState.selectedTab {
                    tabContent(tab)
                        .opacity(appState.selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(appState.selectedTab == tab)
                        .accessibilityHidden(appState.selectedTab != tab)
                        .zIndex(appState.selectedTab == tab ? 1 : 0)
                        .transaction { transaction in
                            transaction.disablesAnimations = true
                        }
                }
            }
        }
        .background(KiioTheme.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KiioBottomTabBar(
                tabs: tabs,
                selectedTab: appState.selectedTab,
                namespace: tabSelectionNamespace,
                onSelect: selectTab
            )
        }
        .onAppear {
            loadedTabs.insert(appState.selectedTab)
        }
        .onChange(of: appState.selectedTab) { tab in
            loadedTabs.insert(tab)
        }
    }

    @ViewBuilder
    private func tabContent(_ tab: MainTab) -> some View {
        switch tab {
        case .home:
            NavigationStack {
                HomeView()
            }
        case .chat:
            NavigationStack {
                ChatView()
            }
        case .device:
            NavigationStack {
                DeviceView()
            }
        case .profile:
            NavigationStack {
                ProfileView()
            }
        }
    }

    private func selectTab(_ tab: MainTab) {
        guard appState.selectedTab != tab else { return }
        loadedTabs.insert(tab)

        withAnimation(.easeOut(duration: 0.18)) {
            appState.selectedTab = tab
        }
    }
}

private struct KiioBottomTabBar: View {
    @EnvironmentObject private var appState: AppState

    let tabs: [MainTab]
    let selectedTab: MainTab
    let namespace: Namespace.ID
    let onSelect: (MainTab) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tabs, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(
            KiioTheme.surface
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(KiioTheme.border.opacity(0.7))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: MainTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            onSelect(tab)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(KiioTheme.accentSoft)
                            .matchedGeometryEffect(id: "selected-tab-background", in: namespace)
                    }

                    Image(tab.assetName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .scaleEffect(isSelected ? 1.04 : 0.96)
                        .opacity(isSelected ? 1 : 0.68)
                }
                .frame(width: 54, height: 32)

                Text(L10n.tr(tab.localizationKey, locale: appState.locale))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? KiioTheme.accent : KiioTheme.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(height: 12)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr(tab.localizationKey, locale: appState.locale))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
