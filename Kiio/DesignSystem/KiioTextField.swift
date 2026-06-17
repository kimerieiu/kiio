import SwiftUI

struct KiioTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(KiioTheme.text)
            .tint(KiioTheme.accent)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(KiioTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(KiioTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func kiioTextField() -> some View {
        modifier(KiioTextFieldModifier())
    }
}
