// Controls for setup, identify, logout, and each way of showing UserJot, so SDK changes can be checked by hand.
import SwiftUI
import UserJot

/** USERJOT_PROJECT_ID from Example/Local.xcconfig, copied into Info.plist at build time; empty when unset. */
private let configuredProjectId =
    Bundle.main.object(forInfoDictionaryKey: "UserJotProjectID") as? String ?? ""

/** The app's only screen; it calls setup on appear and on submit, so the project ID field is the live configuration. */
struct ExampleScreen: View {
    @State private var projectId = configuredProjectId
    @State private var userId = ""
    @State private var email = ""
    @State private var isShowingModifierSheet = false

    var body: some View {
        Form {
            Section {
                TextField("Project ID", text: $projectId)
                    .onSubmit { setUp() }
            } header: {
                Text("Project")
            } footer: {
                Text("Set USERJOT_PROJECT_ID in Example/Local.xcconfig to fill this in at launch.")
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
                Button("Changelog") { UserJot.showChangelog() }
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

    /** Sets up the SDK with the typed project ID; an empty field skips setup. */
    private func setUp() {
        guard !projectId.isEmpty else { return }
        UserJot.setup(projectId: projectId)
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
