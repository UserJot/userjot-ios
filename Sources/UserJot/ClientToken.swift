// Encodes the identified user as the clientToken the board's x1.user.identify accepts. The shape is the
// legacy contract pinned by apps/server/src/routers/x1/identify-autologin.test.ts; keys are sorted so the
// output is deterministic.
import Foundation

/** Top level of the token: the project ID and the user it signs in. */
struct ClientTokenPayload: Encodable {
    let id: String
    let user: UserPayload
}

/** The user fields the server reads. Nil fields are left out of the JSON. */
struct UserPayload: Encodable {
    let id: String
    let email: String?
    let firstName: String?
    let lastName: String?
    let avatar: String?
    let signature: String?
}

/** Base64 of the JSON payload for this project and user, with sorted keys and unescaped slashes. */
func clientToken(projectId: String, user: UserJot.User) -> String {
    let userPayload = UserPayload(
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        avatar: user.avatar,
        signature: user.signature
    )
    let payload = ClientTokenPayload(id: projectId, user: userPayload)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let json = try! encoder.encode(payload)  // a struct of strings cannot fail to encode

    return json.base64EncodedString()
}
