// Pins the exact token bytes, so a change to the payload shape or key order fails loudly instead of
// signing users out on the board.
import Foundation
import Testing

@testable import UserJot

@Test("encodes a user with only an ID")
func encodesMinimalUser() {
    let user = UserJot.User(
        id: "u1",
        email: nil,
        firstName: nil,
        lastName: nil,
        avatar: nil,
        signature: nil
    )

    let token = clientToken(projectId: "proj_1", user: user)

    #expect(token == "eyJpZCI6InByb2pfMSIsInVzZXIiOnsiaWQiOiJ1MSJ9fQ==")
}

@Test("encodes every user field with sorted keys and unescaped slashes")
func encodesFullUser() throws {
    let user = UserJot.User(
        id: "u1",
        email: "a@b.co",
        firstName: "Ana",
        lastName: "Lee",
        avatar: "https://cdn.example.com/~ana/p.png",
        signature: "sig"
    )

    let token = clientToken(projectId: "proj_1", user: user)

    let expectedToken =
        "eyJpZCI6InByb2pfMSIsInVzZXIiOnsiYXZhdGFyIjoiaHR0cHM6Ly9jZG4uZXhhbXBsZS5jb20vfmFuYS9wLnBuZyIsImVtYWlsIjoiYUBiLmNvIiwiZmlyc3ROYW1lIjoiQW5hIiwiaWQiOiJ1MSIsImxhc3ROYW1lIjoiTGVlIiwic2lnbmF0dXJlIjoic2lnIn19"
    let expectedJSON =
        #"{"id":"proj_1","user":{"avatar":"https://cdn.example.com/~ana/p.png","email":"a@b.co","firstName":"Ana","id":"u1","lastName":"Lee","signature":"sig"}}"#
    let decodedData = try #require(Data(base64Encoded: token))

    #expect(token == expectedToken)
    #expect(String(decoding: decodedData, as: UTF8.self) == expectedJSON)
}

@Test("leaves nil user fields out of the payload")
func omitsNilFields() throws {
    let user = UserJot.User(
        id: "u1",
        email: "a@b.co",
        firstName: nil,
        lastName: nil,
        avatar: nil,
        signature: "sig"
    )

    let token = clientToken(projectId: "proj_1", user: user)

    let decodedData = try #require(Data(base64Encoded: token))
    let payload = try #require(
        try JSONSerialization.jsonObject(with: decodedData) as? [String: Any]
    )
    let userFields = try #require(payload["user"] as? [String: Any])
    #expect(userFields.keys.sorted() == ["email", "id", "signature"])
}
