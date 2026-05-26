import SwiftUI

struct KiioPaginationFooter: View {
    let isLoading: Bool
    let hasMore: Bool
    let isEmpty: Bool
    let locale: String
    let loadMore: () -> Void

    var body: some View {
        if isLoading {
            ProgressView(L10n.tr("common.loadingMore", locale: locale))
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        } else if hasMore {
            Button(action: loadMore) {
                Text(L10n.tr("common.loadMore", locale: locale))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .onAppear(perform: loadMore)
        } else if !isEmpty {
            Text(L10n.tr("common.noMore", locale: locale))
                .font(.system(size: 12))
                .foregroundStyle(KiioTheme.mutedText)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
        }
    }
}
