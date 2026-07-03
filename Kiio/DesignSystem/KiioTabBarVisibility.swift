import SwiftUI

extension View {
    func kiioHidesTabBar() -> some View {
        toolbar(.hidden, for: .tabBar)
    }
}
