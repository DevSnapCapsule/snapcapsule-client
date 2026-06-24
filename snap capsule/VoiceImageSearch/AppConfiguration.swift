import Foundation

/// Loads runtime configuration from `Config.plist`, `Secrets.plist`, or environment variables.
/// Keeps secrets out of source code and makes a future backend proxy swap straightforward.
enum AppConfiguration {
    /// Direct Gemini API key (development / local builds only).
    static var geminiAPIKey: String? {
        AppSecrets.geminiAPIKey
    }

    /// Optional proxy URL that accepts `{ "transcript": "..." }` and returns the same JSON schema.
    /// When set, the app never sends the API key from the client.
    static var geminiProxyURL: URL? {
        guard let raw = resolvedString(forKey: "GeminiProxyURL", environmentKeys: ["GEMINI_PROXY_URL"]) else {
            return nil
        }
        return URL(string: raw)
    }

    static var geminiModelName: String {
        resolvedString(forKey: "GeminiModelName", environmentKeys: ["GEMINI_MODEL_NAME"])
            ?? "gemini-2.5-flash-lite"
    }

    /// Cloud Run proxy URL for eBay product search (`GET /shopping/search`).
    static var shoppingProxyURL: URL? {
        guard let raw = resolvedString(forKey: "ShoppingProxyURL", environmentKeys: ["SHOPPING_PROXY_URL"]) else {
            return nil
        }
        return URL(string: raw)
    }

    private static func resolvedString(forKey key: String, environmentKeys: [String]) -> String? {
        AppSecrets.string(plistKey: key, environmentKeys: environmentKeys)
    }
}
