import Foundation

enum JWTClaimsDecoder {
    private struct Claims: Decodable {
        let sub: String
    }

    static func subject(from token: String) -> String? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        guard let data = Data(base64URLEncoded: String(segments[1])) else { return nil }
        return try? JSONDecoder().decode(Claims.self, from: data).sub
    }
}
