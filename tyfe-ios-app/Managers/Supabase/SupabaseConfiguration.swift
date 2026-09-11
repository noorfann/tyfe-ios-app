import Foundation

struct SupabaseConfiguration: Equatable {
    let url: URL
    let publishableKey: String

    init?(urlString: String, publishableKey: String) {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmedURL),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }
        guard Self.isPublishableKey(trimmedKey) else { return nil }

        self.url = url
        self.publishableKey = trimmedKey
    }

    static func isPublishableKey(_ key: String) -> Bool {
        if key.hasPrefix("sb_publishable_") { return true }
        if key.hasPrefix("sb_secret_") || key.hasPrefix("sbp_") { return false }
        return legacyJWTKeyRole(key) == "anon"
    }

    private static func legacyJWTKeyRole(_ key: String) -> String? {
        let segments = key.split(separator: ".")
        guard segments.count == 3,
              let payloadData = base64URLDecoded(String(segments[1])),
              let object = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }
        return object["role"] as? String
    }

    private static func base64URLDecoded(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
