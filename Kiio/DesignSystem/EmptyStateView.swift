import SwiftUI

struct KiioEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(KiioTheme.accent)
                .frame(width: 72, height: 72)
                .background(KiioTheme.accentSoft)
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(KiioTheme.text)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(KiioTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
