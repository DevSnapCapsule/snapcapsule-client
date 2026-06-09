import Foundation

/// Loads API keys from environment variables and local plist files.
/// Mirrors the documented setup for `GOOGLE_VISION_API_KEY` and `GEMINI_API_KEY`.
enum AppSecrets {
    /// Google Cloud Vision API key (used when not routing through the Cloud Run proxy).
    static var googleVisionAPIKey: String? {
        string(
            plistKey: "GoogleVisionAPIKey",
            environmentKeys: ["GOOGLE_VISION_API_KEY"]
        )
    }

    /// Gemini API key for voice image search intent parsing.
    static var geminiAPIKey: String? {
        string(
            plistKey: "GeminiAPIKey",
            environmentKeys: ["GEMINI_API_KEY", "GEMINI_API"]
        )
    }

    static func string(
        plistKey: String,
        environmentKeys: [String],
        plistNames: [String] = ["Secrets", "Config"]
    ) -> String? {
        for environmentKey in environmentKeys {
            if let value = sanitized(ProcessInfo.processInfo.environment[environmentKey]) {
                return value
            }
        }

        for plistName in plistNames {
            if let value = sanitized(plistValue(forKey: plistKey, in: plistName)) {
                return value
            }
        }

        return nil
    }

    private static func sanitized(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.hasPrefix("YOUR_") else {
            return nil
        }
        return trimmed
    }

    private static func plistValue(forKey key: String, in resourceName: String) -> String? {
        guard
            let path = Bundle.main.path(forResource: resourceName, ofType: "plist"),
            let dictionary = NSDictionary(contentsOfFile: path),
            let value = dictionary[key] as? String
        else {
            return nil
        }
        return value
    }
}
