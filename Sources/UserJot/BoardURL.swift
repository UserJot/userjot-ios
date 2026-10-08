// Builds links into a project's public board. The paths must match the board's routes in
// apps/frontend/src/routes, and the sign-in token must survive the board's URLSearchParams parsing.
import Foundation

/** The public board surface a call opens. */
enum Section {
    case feedback(board: String?)
    case roadmap
    case updates

    /**
     * Path on the public board. The routes are _app.index.tsx, _app.board.$board.index.tsx,
     * _app.roadmap.tsx, and _app.updates.index.tsx in apps/frontend/src/routes.
     */
    var path: String {
        switch self {
        case .feedback(let board):
            guard let board else { return "/" }
            return "/board/\(board)"
        case .roadmap:
            return "/roadmap"
        case .updates:
            return "/updates"
        }
    }
}

/** Query parameter the board reads in apps/frontend/src/routes/_app.tsx to sign the user in. */
let clientTokenQueryName = "clientToken"

/**
 * Builds the URL to open for a section, with the sign-in token in the query when there is one.
 * Returns nil only when publicBaseUrl is not a URL.
 */
func boardURL(publicBaseUrl: String, section: Section, clientToken: String?) -> URL? {
    guard var components = URLComponents(string: publicBaseUrl) else { return nil }
    components.path = section.path

    if let clientToken {
        // Base64 is letters, digits, "+", "/", "=". Encoding everything but letters and digits turns
        // exactly those three into %2B %2F %3D; URLSearchParams on the board would otherwise read
        // "+" as a space and the token would fail to decode.
        let encodedToken = clientToken.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics)!  // base64 is ASCII, never nil
        components.percentEncodedQueryItems = [
            URLQueryItem(name: clientTokenQueryName, value: encodedToken)
        ]
    }

    return components.url
}
