// The macOS window content that loads one board URL in a web view, including the file picker the board
// uses for attachments.
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    import AppKit
    import WebKit

    class UserJotMacWebViewController: NSViewController {
        private let url: URL
        private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

        init(url: URL) {
            self.url = url
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.autoresizingMask = [.width, .height]

            // Set custom user agent
            let appVersion =
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
            let osVersion = ProcessInfo.processInfo.operatingSystemVersion
            let osVersionString =
                "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
            webView.customUserAgent =
                "UserJotSDK/\(UserJot.version) (macOS; \(osVersionString); AppVersion/\(appVersion))"

            self.view = webView
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            loadURL()
        }

        private func loadURL() {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    extension UserJotMacWebViewController: WKNavigationDelegate {
        func webView(
            _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
        ) {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Failed to load UserJot: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Failed to load UserJot: \(error.localizedDescription)"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    extension UserJotMacWebViewController: WKUIDelegate {
        @MainActor
        func webView(
            _ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void
        ) {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = parameters.allowsDirectories
            openPanel.allowsMultipleSelection = parameters.allowsMultipleSelection

            openPanel.begin { response in
                if response == .OK {
                    completionHandler(openPanel.urls)
                } else {
                    completionHandler(nil)
                }
            }
        }
    }
#endif
