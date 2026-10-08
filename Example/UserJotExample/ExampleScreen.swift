// Controls for setup, identify, logout, and each way of showing UserJot, so SDK changes can be checked by hand.
import SwiftUI
import UserJot

/** USERJOT_PROJECT_ID from Example/Local.xcconfig, copied into Info.plist at build time; empty when unset. */
private let configuredProjectId =
    Bundle.main.object(forInfoDictionaryKey: "UserJotProjectID") as? String ?? ""

/** USERJOT_WIDGET_BASE_URL from Example/Local.xcconfig; empty means the SDK's production host. */
private let configuredWidgetBaseURL =
    Bundle.main.object(forInfoDictionaryKey: "UserJotWidgetBaseURL") as? String ?? ""

/** The app's only screen; it calls setup on appear and on submit, so the project fields are the live configuration. */
struct ExampleScreen: View {
    @State private var projectId = configuredProjectId
    @State private var widgetBaseURL = configuredWidgetBaseURL
    @State private var userId = ""
    @State private var email = ""
    @State private var boardSlug = ""
    @State private var isShowingModifierSheet = false

    var body: some View {
        Form {
            Section {
                TextField("Project ID", text: $projectId)
                    .onSubmit { setUp() }
                TextField("Widget base URL", text: $widgetBaseURL)
                    .onSubmit { setUp() }
            } header: {
                Text("Project")
            } footer: {
                Text(
                    "Set USERJOT_PROJECT_ID, and USERJOT_WIDGET_BASE_URL for a local server, in Example/Local.xcconfig to fill these in at launch."
                )
            }

            Section("User") {
                TextField("User ID", text: $userId)
                TextField("Email", text: $email)
                Button("Identify") { identify() }
                    .disabled(userId.isEmpty)
                Button("Log Out") { UserJot.logout() }
            }

            Section("Show") {
                Button("Feedback") { UserJot.showFeedback() }
                Button("Roadmap") { UserJot.showRoadmap() }
                Button("Updates") { UserJot.showUpdates() }
                TextField("Board slug", text: $boardSlug)
                Button("Feedback for Board") { UserJot.showFeedback(board: boardSlug) }
                    .disabled(boardSlug.isEmpty)
                #if os(iOS)
                    Button("Feedback in Medium Sheet") {
                        UserJot.showFeedback(presentationStyle: .mediumSheet)
                    }
                    Button("Feedback with SwiftUI Modifier") { isShowingModifierSheet = true }
                #endif
            }
        }
        .formStyle(.grouped)
        .autocorrectionDisabled()
        #if os(iOS)
            .textInputAutocapitalization(.never)
            .userJotFeedback(isPresented: $isShowingModifierSheet)
        #endif
        .onAppear { setUp() }
    }

    /**
     * Sets up the SDK with the typed project ID; an empty field skips setup. The widget base URL field
     * overrides the SDK's production host when it holds a URL.
     */
    private func setUp() {
        guard !projectId.isEmpty else { return }

        var baseURL = UserJot.defaultWidgetBaseURL
        if !widgetBaseURL.isEmpty, let typedURL = URL(string: widgetBaseURL) {
            baseURL = typedURL
        }

        UserJot.setup(projectId: projectId, widgetBaseURL: baseURL)
    }

    /** Identifies the typed user, leaving email out when the field is empty. */
    private func identify() {
        var emailOrNil: String? = nil
        if !email.isEmpty {
            emailOrNil = email
        }
        UserJot.identify(userId: userId, email: emailOrNil)
    }
}
