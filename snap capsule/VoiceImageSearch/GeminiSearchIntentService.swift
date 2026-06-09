import Foundation

enum GeminiServiceError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case apiError(String)
    case emptyResponse
    case proxyUnavailable
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Gemini is not configured. Deploy the Cloud Run proxy or add a key to Secrets.plist for development."
        case .invalidURL:
            return "Gemini service URL is invalid."
        case .invalidResponse:
            return "Received an unexpected response from Gemini."
        case .apiError(let message):
            return message
        case .emptyResponse:
            return "Gemini returned an empty response."
        case .proxyUnavailable:
            return "Gemini proxy is not reachable. Deploy backend/gemini-proxy to Cloud Run."
        case .rateLimited:
            return "Gemini rate limit reached. Wait a minute and try again."
        }
    }
}

/// Sends voice transcripts to Gemini via Cloud Run proxy (production) with optional direct API fallback (development).
final class GeminiSearchIntentService {
    static let shared = GeminiSearchIntentService()

    private static let defaultGeminiProxyURL = "https://gemini-proxy-937348762913.europe-west1.run.app"

    /// Shared across proxy and direct calls — keep short to save tokens on every request.
    static let systemPrompt = """
    Parse a spoken photo search into JSON only with keys: searchQuery, brand, object, product, scene, personContext, assistantMessage.
    Use null for unused fields. No color terms. searchQuery is one combined metadata string. assistantMessage is one short friendly sentence.
    """

    private let session: URLSession
    private let decoder: JSONDecoder
    private let requestCoordinator = RequestCoordinator()

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 45
        config.timeoutIntervalForResource = 90
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Connection": "close",
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    private var proxyURL: URL? {
        if let configured = AppConfiguration.geminiProxyURL {
            return configured
        }
        return URL(string: Self.defaultGeminiProxyURL)
    }

    func parseSearchIntent(from transcript: String) async throws -> AssistantResponse {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VoiceSearchError.emptyTranscript
        }

        let cacheKey = trimmed.lowercased()
        return try await requestCoordinator.run(key: cacheKey) { [self] in
            if let proxyURL = self.proxyURL {
                return try await self.requestViaProxy(transcript: trimmed, proxyURL: proxyURL)
            }
            return try await self.requestDirectGemini(transcript: trimmed)
        }
    }

    // MARK: - Proxy

    private func requestViaProxy(transcript: String, proxyURL: URL) async throws -> AssistantResponse {
        var request = URLRequest(url: proxyURL)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: ["transcript": transcript])

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiServiceError.invalidResponse
        }

        if http.statusCode == 429 {
            throw GeminiServiceError.rateLimited
        }

        if http.statusCode == 404 || http.statusCode == 503 {
            throw GeminiServiceError.proxyUnavailable
        }

        try validateHTTPResponse(http, data: data)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let proxyError = json["error"] as? String {
            throw GeminiServiceError.apiError(proxyError)
        }

        return try decodeAssistantResponse(from: data)
    }

    // MARK: - Direct Gemini (development fallback)

    private func requestDirectGemini(transcript: String) async throws -> AssistantResponse {
        guard let apiKey = AppConfiguration.geminiAPIKey, !apiKey.isEmpty else {
            throw GeminiServiceError.missingAPIKey
        }

        let model = AppConfiguration.geminiModelName
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw GeminiServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: makeGeminiRequestBody(transcript: transcript))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiServiceError.invalidResponse
        }

        if http.statusCode == 429 {
            throw GeminiServiceError.rateLimited
        }

        try validateHTTPResponse(http, data: data)

        let textData = try extractGeminiText(from: data)
        return try decodeAssistantResponse(from: textData)
    }

    private func makeGeminiRequestBody(transcript: String) -> [String: Any] {
        [
            "systemInstruction": [
                "parts": [["text": Self.systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": transcript]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "maxOutputTokens": 256,
                "responseMimeType": "application/json"
            ]
        ]
    }

    private func validateHTTPResponse(_ http: HTTPURLResponse, data: Data) throws {
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 429 {
                throw GeminiServiceError.rateLimited
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let proxyError = json["error"] as? String {
                throw GeminiServiceError.apiError(proxyError)
            }
            let serverMessage = parseGeminiErrorMessage(from: data) ?? "HTTP \(http.statusCode)"
            throw GeminiServiceError.apiError(serverMessage)
        }
    }

    private func extractGeminiText(from data: Data) throws -> Data {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw GeminiServiceError.invalidResponse
        }

        let combined = parts.compactMap { $0["text"] as? String }.joined()
        guard !combined.isEmpty else {
            throw GeminiServiceError.emptyResponse
        }
        return Data(combined.utf8)
    }

    private func decodeAssistantResponse(from data: Data) throws -> AssistantResponse {
        do {
            return try decoder.decode(AssistantResponse.self, from: data)
        } catch {
            if let text = String(data: data, encoding: .utf8),
               let extracted = extractJSONObjectString(from: text),
               let extractedData = extracted.data(using: .utf8) {
                return try decoder.decode(AssistantResponse.self, from: extractedData)
            }
            throw VoiceSearchError.invalidJSON
        }
    }

    private func parseGeminiErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        else {
            return String(data: data, encoding: .utf8)
        }
        return message
    }

    private func extractJSONObjectString(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") else {
            return nil
        }
        return String(trimmed[start...end])
    }
}

// MARK: - In-flight deduplication

private actor RequestCoordinator {
    private var inFlight: [String: Task<AssistantResponse, Error>] = [:]

    func run(
        key: String,
        operation: @Sendable @escaping () async throws -> AssistantResponse
    ) async throws -> AssistantResponse {
        if let existing = inFlight[key] {
            return try await existing.value
        }

        let task = Task {
            try await operation()
        }
        inFlight[key] = task

        defer { inFlight[key] = nil }

        return try await task.value
    }
}
