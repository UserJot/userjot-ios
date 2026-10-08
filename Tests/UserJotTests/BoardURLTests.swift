// Pins the board paths and the token's query encoding, the two places the SDK has built broken links.
import Foundation
import Testing

@testable import UserJot

/** Base used by every case; any https host works since boardURL only replaces the path and query. */
private let publicBaseUrl = "https://feedback.example.com"

@Test(
    "builds the board's route for each section",
    arguments: [
        (Section.feedback(board: nil), "https://feedback.example.com/"),
        (Section.feedback(board: "features"), "https://feedback.example.com/board/features"),
        (Section.roadmap, "https://feedback.example.com/roadmap"),
        (Section.updates, "https://feedback.example.com/updates"),
    ]
)
func buildsRouteForSection(section: Section, expectedURL: String) {
    let url = boardURL(publicBaseUrl: publicBaseUrl, section: section, clientToken: nil)

    #expect(url?.absoluteString == expectedURL)
}

@Test("percent-encodes a board slug that has characters outside the path set")
func encodesBoardSlug() {
    let url = boardURL(
        publicBaseUrl: publicBaseUrl,
        section: .feedback(board: "new features"),
        clientToken: nil
    )

    #expect(url?.absoluteString == "https://feedback.example.com/board/new%20features")
}

@Test("percent-encodes the base64 characters of the token so the board reads it back intact")
func encodesClientToken() throws {
    let token = "ab+cd/ef=="

    let url = try #require(
        boardURL(publicBaseUrl: publicBaseUrl, section: .feedback(board: nil), clientToken: token)
    )
    let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(url.absoluteString == "https://feedback.example.com/?clientToken=ab%2Bcd%2Fef%3D%3D")
    #expect(!url.absoluteString.contains("%25"))
    #expect(components.queryItems?.first?.value == token)
}
