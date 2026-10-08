// Entry point for the example app; it links the SDK from this repo, so edits to Sources/ show up on the next run.
import SwiftUI

/** Shows the example screen in a window on iOS and macOS. */
@main
struct UserJotExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ExampleScreen()
        }
    }
}
