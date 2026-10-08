// The iOS sheet that loads one board URL in a web view. UIKit rather than SwiftUI, because show calls
// present it from a plain function call outside any SwiftUI hierarchy.
#if canImport(UIKit)
    import UIKit
    import WebKit

    class UserJotWebViewController: UIViewController {
        private let url: URL
        private let webView: WKWebView

        init(url: URL) {
            self.url = url
            let configuration = WKWebViewConfiguration()
            configuration.allowsInlineMediaPlayback = true
            self.webView = WKWebView(frame: .zero, configuration: configuration)
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            setupUI()
            loadURL()
        }

        private func setupUI() {
            webView.frame = view.bounds
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView.navigationDelegate = self

            // Set custom user agent to identify UserJot iOS SDK
            let appVersion =
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let deviceInfo = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
            let osVersion = UIDevice.current.systemVersion
            webView.customUserAgent =
                "UserJotSDK/\(UserJot.version) (\(deviceInfo); iOS \(osVersion); AppVersion/\(appVersion))"

            // Start with webview slightly transparent to prevent white flash
            webView.alpha = 0.0

            // Match WebView background to system appearance
            view.backgroundColor = .systemBackground
            webView.backgroundColor = .systemBackground
            webView.isOpaque = false
            webView.scrollView.backgroundColor = .systemBackground

            // Set the underpage background color for bounce areas
            webView.underPageBackgroundColor = .systemBackground

            view.addSubview(webView)
        }

        private func loadURL() {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        /** Tells the user the board did not load; used for failures before and after the first response. */
        private func showLoadFailure(_ error: Error) {
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to load UserJot: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in })
            present(alert, animated: true)
        }

        override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
            super.traitCollectionDidChange(previousTraitCollection)

            // Update colors when appearance changes (light/dark mode)
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                webView.backgroundColor = .systemBackground
                webView.scrollView.backgroundColor = .systemBackground
                view.backgroundColor = .systemBackground
                webView.underPageBackgroundColor = .systemBackground
            }
        }
    }

    extension UserJotWebViewController: WKNavigationDelegate {
        func webView(
            _ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            // Fade in the web view once loading starts
            if webView.alpha < 1.0 {
                UIView.animate(withDuration: 0.2) {
                    webView.alpha = 1.0
                }
            }
        }

        func webView(
            _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
        ) {
            showLoadFailure(error)
        }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            showLoadFailure(error)
        }
    }
#endif
