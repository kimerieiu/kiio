import SwiftUI

struct KiioLogoView: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(
                    colors: [KiioTheme.accent, Color(red: 116 / 255, green: 102 / 255, blue: 84 / 255)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Text("K")
                .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: KiioTheme.accent.opacity(0.2), radius: 12, y: 6)
    }
}
