# UserJot Swift SDK

> **Beta Notice**: This SDK is currently in beta (v0.4.0). The API may change before the 1.0 release.

A Swift SDK for integrating [UserJot](https://userjot.com) feedback, roadmap, and updates into your iOS and macOS applications.

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/UserJot/userjot-ios", from: "0.4.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/UserJot/userjot-ios`
3. Click Add Package

## Quick Start

### 1. Setup

Initialize UserJot with your project ID (found in your UserJot dashboard):

```swift
import UserJot

// In your AppDelegate or App struct
UserJot.setup(projectId: "your-project-id")
```

### 2. Identify Users

Identify users to enable personalized feedback tracking:

```swift
// Minimal identification (only userId required)
UserJot.identify(userId: "user123")

// With email
UserJot.identify(
    userId: "user123",
    email: "user@example.com"
)

// With additional details
UserJot.identify(
    userId: "user123",
    email: "user@example.com",
    firstName: "John",
    lastName: "Doe",
    avatar: "https://example.com/avatar.jpg"
)

// With server-side signature for secure authentication
UserJot.identify(
    userId: "user123",
    email: "user@example.com",
    signature: signatureFromYourServer // HMAC-SHA256 signature
)
```

### 3. Show UserJot Views

Display feedback, roadmap, or updates:

```swift
// Show feedback (default)
UserJot.showFeedback()

// Show feedback for specific board
UserJot.showFeedback(board: "feature-requests")

// Show roadmap
UserJot.showRoadmap()

// Show updates
UserJot.showUpdates()
```

`setup` loads your board's address in the background. A show call made before that finishes waits for it, then presents. If the address could not be loaded (for example, the device was offline at launch), the next call tries again.

#### iOS Presentation

On iOS, views are presented as native sheets with a drag indicator. Two presentation styles are available:

```swift
UserJot.showFeedback()                                // Default: large sheet
UserJot.showFeedback(presentationStyle: .sheet)       // Full height sheet
UserJot.showFeedback(presentationStyle: .mediumSheet) // Medium height sheet (iOS 15+)
```

Users can dismiss by dragging down.

#### macOS Presentation

On macOS, views are presented in a separate resizable window. The window opens centered on screen at a comfortable size (896px wide, 80% of screen height).

**Note for sandboxed macOS apps**: You must enable network access in your entitlements:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

## Advanced Usage

### Custom Implementation

If you prefer to handle the presentation yourself, you can get the URLs. They are `async` because they wait for the board's address, and they return `nil` when the board is unavailable:

```swift
// Get URLs for custom WebView implementation
let feedbackURL = await UserJot.feedbackURL()
let roadmapURL = await UserJot.roadmapURL()
let updatesURL = await UserJot.updatesURL()

// Use with your own WebView
if let url = feedbackURL {
    // Present your custom WebView with url
}
```

### SwiftUI Support

For SwiftUI apps, use the provided view:

```swift
import SwiftUI
import UserJot

struct ContentView: View {
    @State private var showingFeedback = false

    var body: some View {
        Button("Send Feedback") {
            showingFeedback = true
        }
        .userJotFeedback(isPresented: $showingFeedback)
    }
}
```

### Logout

Clear user identification when users log out:

```swift
UserJot.logout()
```

## Server-Side Signature (Optional)

For enhanced security, generate HMAC-SHA256 signatures on your server:

```javascript
// Node.js example
const crypto = require('crypto');

function generateSignature(userId, secret) {
    return crypto
        .createHmac('sha256', secret)
        .update(userId)
        .digest('hex');
}
```

Then pass the signature to the identify method:

```swift
UserJot.identify(
    userId: "user123",
    email: "user@example.com",
    signature: signatureFromServer
)
```

## Migrating from 0.3

- `showChangelog()` is now `showUpdates()`, and `changelogURL()` is now `updatesURL()`. The old names still work with a deprecation warning and an Xcode fix-it, and will be removed in 1.0.
- `feedbackURL(board:)`, `roadmapURL()`, and `updatesURL()` are `async`. Add `await` at each call site.
- `UserJot` runs on the main actor. Calls from UI code need no change; call it from a background task with `await`.
- The minimum platforms are now iOS 15 and macOS 12.

## Example App

`Example/UserJotExample.xcodeproj` runs the SDK from this repo on iOS and macOS, with controls to set up, identify a user, and show feedback, roadmap, and updates. Open that project rather than `Package.swift`; the package appears inside it, so you can edit `Sources/` and run from one window.

Give it a test project to load by creating `Example/Local.xcconfig`, which git ignores:

```
USERJOT_PROJECT_ID = your-project-id
```

To run it against a local UserJot server, also set the widget host there. xcconfig reads `//` as a comment, so write the URL with `$()` between the slashes:

```
USERJOT_WIDGET_BASE_URL = https:/$()/widget.userjot.localhost
```

The simulator rejects the local server's certificate until it trusts Caddy's local CA. With the simulator booted, run:

```
xcrun simctl keychain booted add-root-cert "$HOME/Library/Application Support/Caddy/pki/authorities/local/root.crt"
```

The example needs Xcode 16.3 or later, iOS 17, and macOS 14. The simulator and the Mac run it as is; a physical iPhone or iPad needs your team in Signing & Capabilities and a bundle ID of your own.

## Releasing

Bump `UserJot.version` in `Sources/UserJot/UserJot.swift`, update the version in this README, then tag the commit `vX.Y.Z` and push the tag.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 6.1+
- Xcode 16.3+

## Features

- **Simple Integration**: Just two method calls to get started
- **Cross-Platform**: Native support for both iOS and macOS
- **Native Presentation**: iOS sheets and macOS windows
- **SwiftUI Support**: Native SwiftUI view modifier (iOS)
- **Type-Safe**: Full Swift type safety
- **Secure Authentication**: Optional HMAC-SHA256 signature support

## License

MIT License - see LICENSE file for details.

## Support

For issues or questions, visit [UserJot](https://userjot.com) or email shayan@userjot.com.
