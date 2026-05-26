import SwiftUI

struct KiioErrorAlertModifier: ViewModifier {
    @Binding var message: String?
    let locale: String

    func body(content: Content) -> some View {
        content.alert(L10n.tr("app.name", locale: locale), isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(L10n.tr("common.ok", locale: locale), role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }
}

extension View {
    func kiioErrorAlert(message: Binding<String?>, locale: String) -> some View {
        modifier(KiioErrorAlertModifier(message: message, locale: locale))
    }
}
