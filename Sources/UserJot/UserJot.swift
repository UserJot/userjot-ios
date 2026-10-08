// Public entry point of the SDK: project setup, user identity, and presenting the public board on iOS and
// macOS. The board's address comes from the widget Hello route, so nothing can be shown until it loads.
import Foundation

#if canImport(UIKit)
    import UIKit
    import WebKit
#elseif canImport(AppKit)
    import AppKit
    import WebKit
#endif

/** Shows a project's public feedback board, roadmap, and updates, signed in as the identified user. */
public class UserJot {
    nonisolated(unsafe) public static let shared = UserJot()

    private var config: Configuration?
    private var currentUser: User?
    private var publicBaseUrl: String?
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        private var currentWindow: NSWindow?
    #endif

    private init() {}

    /// Setup UserJot with your project configuration
    /// - Parameters:
    ///   - projectId: Your UserJot project ID
    public static func setup(projectId: String) {
        shared.config = Configuration(projectId: projectId)

        Task {
            await shared.fetchMetadata()
        }
    }

    /// Identify the current user
    /// - Parameters:
    ///   - userId: Unique user identifier (required)
    ///   - email: Optional email address
    ///   - firstName: Optional first name
    ///   - lastName: Optional last name
    ///   - avatar: Optional avatar URL
    ///   - signature: Optional HMAC-SHA256 signature from your server (for secure authentication)
    public static func identify(
        userId: String,
        email: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        avatar: String? = nil,
        signature: String? = nil
    ) {
        shared.currentUser = User(
            id: userId,
            email: email,
            firstName: firstName,
            lastName: lastName,
            avatar: avatar,
            signature: signature
        )
    }

    /// Clear the current user identification
    public static func logout() {
        shared.currentUser = nil
    }

    /// Show the feedback modal
    /// - Parameters:
    ///   - board: Optional specific board to show
    ///   - presentationStyle: How to present the view (sheet or mediumSheet)
    public static func showFeedback(
        board: String? = nil, presentationStyle: PresentationStyle = .sheet
    ) {
        shared.showWebView(section: .feedback(board: board), presentationStyle: presentationStyle)
    }

    /// Show the roadmap modal
    /// - Parameter presentationStyle: How to present the view (sheet or mediumSheet)
    public static func showRoadmap(presentationStyle: PresentationStyle = .sheet) {
        shared.showWebView(section: .roadmap, presentationStyle: presentationStyle)
    }

    /// Show the updates modal
    /// - Parameter presentationStyle: How to present the view (sheet or mediumSheet)
    public static func showUpdates(presentationStyle: PresentationStyle = .sheet) {
        shared.showWebView(section: .updates, presentationStyle: presentationStyle)
    }

    /** The 0.3 name for showUpdates; removed in 1.0. */
    @available(*, deprecated, renamed: "showUpdates(presentationStyle:)")
    public static func showChangelog(presentationStyle: PresentationStyle = .sheet) {
        showUpdates(presentationStyle: presentationStyle)
    }

    /// Get the feedback URL (for custom implementations)
    /// - Parameter board: Optional specific board
    /// - Returns: The complete URL with authentication token
    public static func feedbackURL(board: String? = nil) -> URL? {
        return shared.url(for: .feedback(board: board))
    }

    /// Get the roadmap URL (for custom implementations)
    /// - Returns: The complete URL with authentication token
    public static func roadmapURL() -> URL? {
        return shared.url(for: .roadmap)
    }

    /// Get the updates URL (for custom implementations)
    /// - Returns: The complete URL with authentication token
    public static func updatesURL() -> URL? {
        return shared.url(for: .updates)
    }

    /** The 0.3 name for updatesURL; removed in 1.0. */
    @available(*, deprecated, renamed: "updatesURL()")
    public static func changelogURL() -> URL? {
        return updatesURL()
    }

    /** Loads the board's public address from the Hello route and stores it; prints and leaves it nil on failure. */
    private func fetchMetadata() async {
        guard let projectId = config?.projectId else { return }

        let urlString = "https://widget.userjot.com/widget/mobile/v1/\(projectId)/hello"
        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(MetadataResponse.self, from: data)
            self.publicBaseUrl = response.metadata.publicBaseUrl
        } catch {
            print("UserJot: Failed to fetch metadata - \(error.localizedDescription)")
        }
    }

    /** URL for a section, or nil (already printed) when setup has not run or the board address has not loaded. */
    private func url(for section: Section) -> URL? {
        guard let config else {
            print("UserJot: setup(projectId:) has not been called")
            return nil
        }

        guard let publicBaseUrl else {
            print("UserJot: Still fetching configuration. Please wait...")
            return nil
        }

        var token: String? = nil
        if let currentUser {
            token = clientToken(projectId: config.projectId, user: currentUser)
        }

        return boardURL(publicBaseUrl: publicBaseUrl, section: section, clientToken: token)
    }

    private func showWebView(section: Section, presentationStyle: PresentationStyle = .sheet) {
        guard let url = url(for: section) else {
            print("UserJot: Unable to build URL")
            return
        }

        #if canImport(UIKit)
            DispatchQueue.main.async {
                guard
                    let windowScene = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .first(where: { $0.activationState == .foregroundActive }),
                    let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?
                        .rootViewController
                else {
                    print("UserJot: Unable to find active window")
                    return
                }

                let webViewController = UserJotWebViewController(url: url)

                webViewController.modalPresentationStyle = .pageSheet
                if let sheet = webViewController.sheetPresentationController {
                    switch presentationStyle {
                    case .sheet:
                        sheet.detents = [.large()]
                    case .mediumSheet:
                        sheet.detents = [.medium(), .large()]
                        sheet.selectedDetentIdentifier = .medium
                    }
                    sheet.prefersGrabberVisible = true
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }

                // Find the topmost presented view controller
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }

                topController.present(webViewController, animated: true)
            }
        #elseif canImport(AppKit)
            DispatchQueue.main.async {
                // Calculate size based on screen
                let screen =
                    NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)

                // Width: 896px (Tailwind max-w-4xl), Height: 80% of screen, min 500px
                let width: CGFloat = 896
                let height: CGFloat = max(500, screen.size.height * 0.8)

                // Center the window on screen
                let x = screen.origin.x + (screen.size.width - width) / 2
                let y = screen.origin.y + (screen.size.height - height) / 2

                let window = NSWindow(
                    contentRect: NSRect(x: x, y: y, width: width, height: height),
                    styleMask: [.titled, .closable, .resizable],
                    backing: .buffered,
                    defer: false
                )

                window.title = "UserJot"
                window.minSize = NSSize(width: 400, height: 400)
                window.isReleasedWhenClosed = false

                let webViewController = UserJotMacWebViewController(url: url)
                window.contentViewController = webViewController

                // Ensure the window size is set correctly
                window.setContentSize(NSSize(width: width, height: height))
                window.center()

                window.makeKeyAndOrderFront(nil)

                // Keep a reference so window doesn't get deallocated
                UserJot.shared.currentWindow = window
            }
        #else
            print("UserJot: Platform not supported")
        #endif
    }
}

extension UserJot {
    public struct User {
        let id: String
        let email: String?
        let firstName: String?
        let lastName: String?
        let avatar: String?
        let signature: String?
    }

    struct Configuration {
        let projectId: String
    }

    public enum PresentationStyle: Sendable {
        case sheet  // Standard sheet (default)
        case mediumSheet  // Medium height sheet (iOS 15+)
    }

    struct MetadataResponse: Codable {
        let metadata: Metadata

        struct Metadata: Codable {
            let publicBaseUrl: String
        }
    }
}

#if canImport(UIKit)
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
                "UserJotSDK/1.0 (\(deviceInfo); iOS \(osVersion); AppVersion/\(appVersion))"

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
            // Show loading indicator if needed
            UIApplication.shared.isNetworkActivityIndicatorVisible = true

            // Fade in the web view once loading starts
            if webView.alpha < 1.0 {
                UIView.animate(withDuration: 0.2) {
                    webView.alpha = 1.0
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Hide loading indicator
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }

        func webView(
            _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
        ) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false

            let alert = UIAlertController(
                title: "Error",
                message: "Failed to load UserJot: \(error.localizedDescription)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in })
            present(alert, animated: true)
        }
    }
#endif

#if canImport(SwiftUI) && canImport(UIKit)
    import SwiftUI

    public struct UserJotFeedbackView: UIViewControllerRepresentable {
        let board: String?

        public init(board: String? = nil) {
            self.board = board
        }

        public func makeUIViewController(context: Context) -> UINavigationController {
            guard let url = UserJot.feedbackURL(board: board) else {
                let errorVC = UIViewController()
                errorVC.view.backgroundColor = .systemBackground
                return UINavigationController(rootViewController: errorVC)
            }

            let webViewController = UserJotWebViewController(url: url)
            return UINavigationController(rootViewController: webViewController)
        }

        public func updateUIViewController(
            _ uiViewController: UINavigationController, context: Context
        ) {}
    }

    extension View {
        public func userJotFeedback(isPresented: Binding<Bool>, board: String? = nil) -> some View {
            self.sheet(isPresented: isPresented) {
                UserJotFeedbackView(board: board)
            }
        }
    }
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
                "UserJotSDK/1.0 (macOS; \(osVersionString); AppVersion/\(appVersion))"

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
