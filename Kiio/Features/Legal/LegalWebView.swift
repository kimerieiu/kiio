import SwiftUI
import WebKit

struct LegalWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    let onExternalURL: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor(KiioTheme.background)
        webView.scrollView.backgroundColor = UIColor(KiioTheme.background)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        let signature = "\(baseURL?.absoluteString ?? "")|\(html.hashValue)"
        guard context.coordinator.loadedSignature != signature else { return }
        context.coordinator.loadedSignature = signature
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LegalWebView
        var loadedSignature: String?

        init(parent: LegalWebView) {
            self.parent = parent
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if isInternalLegalURL(url) {
                decisionHandler(.allow)
            } else {
                parent.onExternalURL(url)
                decisionHandler(.cancel)
            }
        }

        private func isInternalLegalURL(_ url: URL) -> Bool {
            guard let baseURL = parent.baseURL,
                  let legalPathRange = baseURL.path.range(of: "/legal/pages/") else {
                return false
            }
            let legalPathPrefix = String(baseURL.path[..<legalPathRange.upperBound])
            return url.scheme == baseURL.scheme
                && url.host == baseURL.host
                && url.port == baseURL.port
                && url.path.hasPrefix(legalPathPrefix)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            loadedSignature = nil
            webView.loadHTMLString(parent.html, baseURL: parent.baseURL)
        }
    }
}
