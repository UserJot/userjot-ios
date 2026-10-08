// Public entry point of the SDK: project setup, user identity, and presenting the public board on iOS and
// macOS. The board's address comes from the widget Hello route, so every call waits for that request.
import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/** Shows a project's public feedback board, roadmap, and updates, signed in as the identified user. */
@MainActor
public final class UserJot {
    public static let shared = UserJot()

    /** Matches the git tag; bump it with each release. The web views send it in their user agent. */
    nonisolated public static let version = "0.4.0"

    /** Host of the Hello route. Pass https://widget.userjot.localhost to develop against a local server. */
    nonisolated public static let defaultWidgetBaseURL = URL(
        string: "https://widget.userjot.com")!  // a literal URL always parses

    /** Whether the board's public address is known, being fetched, or not available yet. */
    private enum BoardAddress {
        case loading(Task<String?, Never>)
        case ready(String)
        case unavailable
    }

    private var configuration: Configuration?
    private var currentUser: User?
    private var boardAddress: BoardAddress = .unavailable
    /** Bumped by every setup, so a Hello response that arrives after a newer setup is dropped. */
    private var setupCount = 0
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        private var currentWindow: NSWindow?
    #endif

    private init() {}

    /// Setup UserJot with your project configuration
    /// - Parameters:
    ///   - projectId: Your UserJot project ID
    ///   - widgetBaseURL: Host of the widget API; leave the default outside local development
    public static func setup(projectId: String, widgetBaseURL: URL = defaultWidgetBaseURL) {
        if case .loading(let request) = shared.boardAddress {
            request.cancel()
        }
        shared.configuration = Configuration(projectId: projectId, widgetBaseURL: widgetBaseURL)
        shared.boardAddress = .unavailable
        shared.setupCount += 1

        // Prefetch so the first show usually finds the address ready; loadBoardAddress stores it.
        Task {
            _ = await shared.loadBoardAddress()
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
        shared.show(section: .feedback(board: board), presentationStyle: presentationStyle)
    }

    /// Show the roadmap modal
    /// - Parameter presentationStyle: How to present the view (sheet or mediumSheet)
    public static func showRoadmap(presentationStyle: PresentationStyle = .sheet) {
        shared.show(section: .roadmap, presentationStyle: presentationStyle)
    }

    /// Show the updates modal
    /// - Parameter presentationStyle: How to present the view (sheet or mediumSheet)
    public static func showUpdates(presentationStyle: PresentationStyle = .sheet) {
        shared.show(section: .updates, presentationStyle: presentationStyle)
    }

    /** The 0.3 name for showUpdates; removed in 1.0. */
    @available(*, deprecated, renamed: "showUpdates(presentationStyle:)")
    public static func showChangelog(presentationStyle: PresentationStyle = .sheet) {
        showUpdates(presentationStyle: presentationStyle)
    }

    /// Get the feedback URL (for custom implementations), waiting for the board address if needed
    /// - Parameter board: Optional specific board
    /// - Returns: The complete URL with authentication token, or nil when the board is unavailable
    public static func feedbackURL(board: String? = nil) async -> URL? {
        return await shared.url(for: .feedback(board: board))
    }

    /// Get the roadmap URL (for custom implementations), waiting for the board address if needed
    /// - Returns: The complete URL with authentication token, or nil when the board is unavailable
    public static func roadmapURL() async -> URL? {
        return await shared.url(for: .roadmap)
    }

    /// Get the updates URL (for custom implementations), waiting for the board address if needed
    /// - Returns: The complete URL with authentication token, or nil when the board is unavailable
    public static func updatesURL() async -> URL? {
        return await shared.url(for: .updates)
    }

    /** The 0.3 name for updatesURL; removed in 1.0. */
    @available(*, deprecated, renamed: "updatesURL()")
    public static func changelogURL() async -> URL? {
        return await updatesURL()
    }

    /**
     * Returns the board's public base URL, waiting for the Hello request in flight or starting one.
     * Nil (already printed) before setup or when the request fails; the next call tries again.
     */
    private func loadBoardAddress() async -> String? {
        guard let configuration else {
            print("UserJot: setup(projectId:) has not been called")
            return nil
        }

        if case .ready(let address) = boardAddress {
            return address
        }

        let generation = setupCount
        let request: Task<String?, Never>
        if case .loading(let requestInFlight) = boardAddress {
            request = requestInFlight
        } else {
            request = startBoardAddressRequest(for: configuration)
        }

        let address = await request.value

        // setup ran again while this call waited, so the address belongs to a project that is no longer
        // current. Comparing project IDs instead would miss a second setup with the same ID.
        guard generation == setupCount else { return nil }

        return address
    }

    /**
     * Starts a Hello request and marks the address as loading. The request records its own outcome
     * before it completes, so every caller waiting on it resumes to settled state and a failure is
     * retried by the next call rather than seen as still loading.
     */
    private func startBoardAddressRequest(for configuration: Configuration) -> Task<String?, Never>
    {
        let generation = setupCount
        let projectId = configuration.projectId
        let widgetBaseURL = configuration.widgetBaseURL

        let request = Task { () -> String? in
            let address = await Self.fetchPublicBaseUrl(
                projectId: projectId, widgetBaseURL: widgetBaseURL)

            // A newer setup owns boardAddress now; recording this project's outcome would overwrite it.
            guard generation == self.setupCount else { return nil }

            if let address {
                self.boardAddress = .ready(address)
            } else {
                self.boardAddress = .unavailable
            }
            return address
        }

        boardAddress = .loading(request)
        return request
    }

    /** GET {widgetBaseURL}/widget/mobile/v1/{projectId}/hello; nil on any failure, with one printed line. */
    nonisolated private static func fetchPublicBaseUrl(projectId: String, widgetBaseURL: URL) async
        -> String?
    {
        let url = widgetBaseURL.appendingPathComponent("widget/mobile/v1/\(projectId)/hello")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(MetadataResponse.self, from: data)
            return response.metadata.publicBaseUrl
        } catch {
            print(
                "UserJot: could not load the board address for project \(projectId): \(error.localizedDescription)"
            )
            return nil
        }
    }

    /** URL for a section, or nil (already printed) when the SDK is not set up or the board is unavailable. */
    private func url(for section: Section) async -> URL? {
        guard let address = await loadBoardAddress() else { return nil }

        var token: String? = nil
        if let currentUser, let configuration {
            token = clientToken(projectId: configuration.projectId, user: currentUser)
        }

        return boardURL(publicBaseUrl: address, section: section, clientToken: token)
    }

    /** Presents a section once its URL is known; does nothing if the URL never arrives. */
    private func show(section: Section, presentationStyle: PresentationStyle) {
        // Not retained: show is a synchronous call from a button, so the sheet either appears when the
        // address arrives or one line has been printed.
        Task {
            guard let url = await url(for: section) else { return }
            present(url: url, presentationStyle: presentationStyle)
        }
    }

    /** A page sheet over the topmost view controller on iOS; a centered window on macOS. */
    private func present(url: URL, presentationStyle: PresentationStyle) {
        #if canImport(UIKit)
            guard
                let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?
                    .rootViewController
            else {
                print("UserJot: no active window to present from")
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
        #elseif canImport(AppKit)
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
            currentWindow = window
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
        let widgetBaseURL: URL
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
