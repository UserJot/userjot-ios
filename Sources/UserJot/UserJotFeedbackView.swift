// SwiftUI entry points on iOS: a feedback view and a sheet modifier. The board address may still be
// loading when the sheet opens, so the view waits for the URL before showing the web view.
#if canImport(SwiftUI) && canImport(UIKit)
    import SwiftUI
    import UIKit

    /** The feedback board inside SwiftUI; shows a spinner until the board address loads. */
    public struct UserJotFeedbackView: View {
        /** What the view can show while it waits for, has, or gave up on the board URL. */
        private enum Phase {
            case loading
            case ready(URL)
            case failed
        }

        let board: String?
        @State private var phase: Phase = .loading

        public init(board: String? = nil) {
            self.board = board
        }

        public var body: some View {
            Group {
                switch phase {
                case .loading:
                    ProgressView()
                case .ready(let url):
                    BoardPage(url: url)
                case .failed:
                    Text("UserJot is unavailable")
                        .foregroundStyle(.secondary)
                }
            }
            .task {
                await loadURL()
            }
        }

        /** Waits for the feedback URL; the SDK has already printed why when it is nil. */
        private func loadURL() async {
            guard let url = await UserJot.feedbackURL(board: board) else {
                phase = .failed
                return
            }
            phase = .ready(url)
        }
    }

    /** Hosts the UIKit web view controller inside SwiftUI, in a navigation controller as in 0.3. */
    private struct BoardPage: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context: Context) -> UINavigationController {
            let webViewController = UserJotWebViewController(url: url)
            return UINavigationController(rootViewController: webViewController)
        }

        func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
    }

    extension View {
        public func userJotFeedback(isPresented: Binding<Bool>, board: String? = nil) -> some View {
            self.sheet(isPresented: isPresented) {
                UserJotFeedbackView(board: board)
            }
        }
    }
#endif
