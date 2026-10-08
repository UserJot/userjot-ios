// Pins the Hello response the SDK reads, as served by apps/server/src/routers/hono/widget/v1/mobile/hello.ts.
import Foundation
import Testing

@testable import UserJot

@Test("reads the board's public base URL from a Hello response")
func decodesHelloResponse() throws {
    let json = Data(#"{"metadata":{"publicBaseUrl":"https://feedback.example.com"}}"#.utf8)

    let response = try JSONDecoder().decode(UserJot.MetadataResponse.self, from: json)

    #expect(response.metadata.publicBaseUrl == "https://feedback.example.com")
}

@Test("fails to decode the Hello route's not-found body")
func rejectsNotFoundBody() {
    let json = Data(#"{"error":"Workspace not found"}"#.utf8)

    #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(UserJot.MetadataResponse.self, from: json)
    }
}
