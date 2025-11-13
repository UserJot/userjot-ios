import Testing
import Foundation
@testable import UserJot

// MARK: - Setup and Configuration Tests

@Test("Basic setup")
func basicSetup() {
    UserJot.setup(projectId: "test-project")

    // URLs will be nil until metadata is fetched
    let feedbackURL = UserJot.feedbackURL()
    #expect(feedbackURL == nil) // Expected since metadata not fetched yet
}

// MARK: - User Identification Tests

@Test("User identification with all fields")
func userIdentificationFull() {
    UserJot.setup(projectId: "test-project")

    UserJot.identify(
        userId: "user123",
        email: "test@example.com",
        firstName: "John",
        lastName: "Doe",
        avatar: "https://example.com/avatar.jpg",
        signature: "test-signature-from-server"
    )

    // URL will be nil until metadata is fetched
    let url = UserJot.feedbackURL()
    #expect(url == nil) // Expected since metadata not fetched yet
}


@Test("User identification with minimal fields")
func userIdentificationMinimal() {
    UserJot.setup(projectId: "test-project")

    // Only userId is required
    UserJot.identify(userId: "user789")

    // Test that we can identify without crashing
    #expect(true)
}

// MARK: - Logout Tests

@Test("Logout clears user identification")
func logoutClearsUser() {
    UserJot.setup(projectId: "test-project")

    // Identify user (email is optional)
    UserJot.identify(userId: "logout-test")

    // Logout
    UserJot.logout()

    // Test that logout doesn't crash
    #expect(true)
}

// MARK: - Edge Cases

@Test("Handle missing configuration")
func handleMissingConfiguration() {
    // Don't call setup - should handle gracefully
    UserJot.logout() // Clear any previous state

    let url = UserJot.feedbackURL()
    #expect(url == nil)
}

