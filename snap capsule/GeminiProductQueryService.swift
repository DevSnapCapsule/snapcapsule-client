import Foundation

/// Generates shopping search queries from brand names and image metadata tags via Gemini 2.5 Flash Lite.
final class GeminiProductQueryService {
    static let shared = GeminiProductQueryService()

    private static let defaultGeminiProxyURL = "https://gemini-proxy-937348762913.europe-west1.run.app"

    static let systemPrompt = """
    You generate shopping search queries for e-commerce sites like Amazon and Google Shopping.
    Return only a JSON array of strings — no wrapper object, no markdown. Generate at least 2 queries.
    The tags are ordered by confidence, most relevant first.
    The FIRST query must be specific to the item in the photo, combining the brand (if any) with the most relevant tags.
    The SECOND query must be the single most popular, best-selling, or most-searched product shoppers commonly look for — based on the brand (if any), otherwise the most relevant tag.
    Each query must read like a real search term a shopper types: natural, specific, and product-focused.
    Keep each query under 8 words. No punctuation and no quotes inside query strings.
    Avoid vague phrases like "image containing" or "photo of".
    """

    private let session: URLSession
    private let requestCoordinator = ProductQueryRequestCoordinator()

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
    }

    private var proxyURL: URL? {
        if let configured = AppConfiguration.geminiProxyURL {
            return configured
        }
        return URL(string: Self.defaultGeminiProxyURL)
    }

    func generateQueries(brands: [String], tags: [String]) async throws -> [String] {
        let normalizedBrands = normalizeTerms(brands)
        let normalizedTags = normalizeTerms(tags)
        guard !normalizedBrands.isEmpty || !normalizedTags.isEmpty else {
            throw GeminiServiceError.emptyResponse
        }

        let cacheKey = (normalizedBrands + ["|"] + normalizedTags).joined(separator: ",").lowercased()
        return try await requestCoordinator.run(key: cacheKey) { [self] in
            guard let proxyURL = self.proxyURL else {
                return try await self.requestDirectGemini(brands: normalizedBrands, tags: normalizedTags)
            }

            do {
                return try await self.requestViaProxy(
                    brands: normalizedBrands,
                    tags: normalizedTags,
                    proxyURL: proxyURL
                )
            } catch GeminiServiceError.proxyUnavailable {
                // Proxy is reachable but the /product-queries route isn't deployed yet.
                // Fall back to the direct Gemini API when a development key is configured.
                guard let apiKey = AppConfiguration.geminiAPIKey, !apiKey.isEmpty else {
                    throw GeminiServiceError.proxyUnavailable
                }
                return try await self.requestDirectGemini(brands: normalizedBrands, tags: normalizedTags)
            }
        }
    }

    // MARK: - Proxy

    private func requestViaProxy(brands: [String], tags: [String], proxyURL: URL) async throws -> [String] {
        let endpoint = proxyURL.appendingPathComponent("product-queries")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "brands": brands,
            "tags": tags
        ])

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

        return try decodeQueryArray(from: data)
    }

    // MARK: - Direct Gemini (development fallback)

    private func requestDirectGemini(brands: [String], tags: [String]) async throws -> [String] {
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
        request.httpBody = try JSONSerialization.data(withJSONObject: makeGeminiRequestBody(brands: brands, tags: tags))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiServiceError.invalidResponse
        }

        if http.statusCode == 429 {
            throw GeminiServiceError.rateLimited
        }

        try validateHTTPResponse(http, data: data)

        let textData = try extractGeminiText(from: data)
        return try decodeQueryArray(from: textData)
    }

    private func makeGeminiRequestBody(brands: [String], tags: [String]) -> [String: Any] {
        [
            "systemInstruction": [
                "parts": [["text": Self.systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": makeUserPrompt(brands: brands, tags: tags)]]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 256,
                "responseMimeType": "application/json"
            ]
        ]
    }

    private func makeUserPrompt(brands: [String], tags: [String]) -> String {
        let brandList = brands.joined(separator: ", ")
        let tagList = tags.joined(separator: ", ")
        let topTag = tags.first ?? "the main item"

        if brands.isEmpty {
            return """
            Image tags (most relevant first): [\(tagList)].
            Query 1: a specific shopping search for this item using the most relevant tags.
            Query 2: the most popular or most-searched product related to \(topTag) that shoppers buy.
            Return only a JSON array of strings. \
            Example output: ["brown leather crossbody bag", "best selling crossbody bags women"]
            """
        }

        return """
        Brand: [\(brandList)]. Image tags (most relevant first): [\(tagList)].
        Query 1: a specific shopping search combining the brand with the most relevant tags.
        Query 2: the most popular or most-searched \(brands.first ?? brandList) product shoppers buy right now.
        Return only a JSON array of strings. \
        Example output: ["Nike white running shoes men", "Nike Air Force 1"]
        """
    }

    // MARK: - Response handling

    private func decodeQueryArray(from data: Data) throws -> [String] {
        if let queries = try? JSONSerialization.jsonObject(with: data) as? [String] {
            return sanitizeQueries(queries)
        }

        if let text = String(data: data, encoding: .utf8),
           let extracted = extractJSONArrayString(from: text),
           let extractedData = extracted.data(using: .utf8),
           let queries = try? JSONSerialization.jsonObject(with: extractedData) as? [String] {
            return sanitizeQueries(queries)
        }

        throw GeminiServiceError.invalidResponse
    }

    private func sanitizeQueries(_ raw: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []

        for item in raw {
            guard let cleaned = sanitizeQuery(item) else { continue }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            results.append(cleaned)
        }

        return results
    }

    private func sanitizeQuery(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        text = text.components(separatedBy: CharacterSet.punctuationCharacters).joined(separator: " ")
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return nil }
        return words.prefix(8).joined(separator: " ")
    }

    private func normalizeTerms(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for term in terms {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(trimmed)
        }

        return result
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

    private func extractJSONArrayString(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            return trimmed
        }
        guard let start = trimmed.firstIndex(of: "["), let end = trimmed.lastIndex(of: "]") else {
            return nil
        }
        return String(trimmed[start...end])
    }
}

// MARK: - In-flight deduplication

private actor ProductQueryRequestCoordinator {
    private var inFlight: [String: Task<[String], Error>] = [:]

    func run(
        key: String,
        operation: @Sendable @escaping () async throws -> [String]
    ) async throws -> [String] {
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
