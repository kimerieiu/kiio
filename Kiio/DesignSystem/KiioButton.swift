import SwiftUI

struct KiioPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(isDisabled ? KiioTheme.text : .white)
            .background(isDisabled ? KiioTheme.disabledFill : KiioTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isDisabled || isLoading)
    }
}

struct KiioSecondaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(KiioTheme.text)
            .background(isDisabled ? KiioTheme.disabledFill : KiioTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isDisabled || isLoading)
    }
}

struct KiioBackButton: View {
    enum Style: Equatable {
        case surface
        case onDark
    }

    @EnvironmentObject private var appState: AppState

    var style: Style = .surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(foregroundColor)
                .frame(width: 36, height: 36)
                .background(background)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(borderColor, lineWidth: 1)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .shadow(color: shadowColor, radius: style == .surface ? 8 : 0, y: style == .surface ? 3 : 0)
        .accessibilityLabel(L10n.tr("common.back", locale: appState.locale))
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .surface:
            KiioTheme.surface
        case .onDark:
            Color.black.opacity(0.36)
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .surface:
            return KiioTheme.text
        case .onDark:
            return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .surface:
            return KiioTheme.border
        case .onDark:
            return .white.opacity(0.18)
        }
    }

    private var shadowColor: Color {
        switch style {
        case .surface:
            return .black.opacity(0.08)
        case .onDark:
            return .clear
        }
    }
}
