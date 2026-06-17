import SwiftUI

struct KiioCard<Content: View>: View {
    var padding: CGFloat = 16
    var radius: CGFloat = KiioTheme.cardRadius
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KiioTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(KiioTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 16, y: 8)
    }
}

struct KiioSectionTitle: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: 7) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(title)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(KiioTheme.mutedText)
        .padding(.horizontal, 4)
    }
}

enum KiioBadgeTone: Equatable {
    case accent
    case success
    case warning
    case danger
    case muted

    var color: Color {
        switch self {
        case .accent:
            return KiioTheme.accent
        case .success:
            return KiioTheme.success
        case .warning:
            return KiioTheme.warning
        case .danger:
            return KiioTheme.danger
        case .muted:
            return KiioTheme.mutedText
        }
    }
}

struct KiioStatusBadge: View {
    let text: String
    var tone: KiioBadgeTone = .accent

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tone.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(tone.color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(tone.color.opacity(0.24), lineWidth: 1))
            .lineLimit(1)
    }
}

struct KiioIconBadge: View {
    let systemImage: String
    var tone: KiioBadgeTone = .accent
    var size: CGFloat = 42
    var iconSize: CGFloat = 17

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(tone.color)
            .frame(width: size, height: size)
            .background(tone.color.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.31, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                    .stroke(tone.color.opacity(0.22), lineWidth: 1)
            )
    }
}

struct KiioMetaPill: View {
    let icon: String?
    let text: String
    var tone: KiioBadgeTone = .muted

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tone.color.opacity(tone == .muted ? 0.1 : 0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(tone.color.opacity(0.2), lineWidth: 1))
    }
}

struct KiioLoadingCard: View {
    let message: String

    var body: some View {
        KiioCard {
            HStack(spacing: 12) {
                ProgressView()
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(KiioTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
    }
}

struct KiioDetailField: View {
    let title: String
    let value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(KiioTheme.secondaryText)
            Spacer()
            Text(value?.isEmpty == false ? value! : "--")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KiioTheme.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
}

private struct KiioListCardRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
    }
}

private struct KiioListSectionHeaderRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 4, trailing: 20))
    }
}

extension View {
    func kiioListCardRow() -> some View {
        modifier(KiioListCardRowModifier())
    }

    func kiioListHeaderRow() -> some View {
        modifier(KiioListSectionHeaderRowModifier())
    }
}
