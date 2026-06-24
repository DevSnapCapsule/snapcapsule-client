import Foundation

enum ShoppingError: LocalizedError, Equatable {
    case networkError
    case decodingError
    case serverError(code: Int)
    case noResults

    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Unable to connect. Check your network and try again."
        case .decodingError:
            return "Unexpected response from the shopping service."
        case .serverError(let code):
            return "Shopping service error (HTTP \(code))."
        case .noResults:
            return "No products found."
        }
    }
}

protocol ProductSearching: Sendable {
    func searchProducts(query: String, country: String, offset: Int) async throws -> [Product]
}

/// Searches for products via the Cloud Run shopping proxy.
final class ShoppingService: ProductSearching {
    static let shared = ShoppingService()

    private static let defaultShoppingProxyURL = "https://shopping-proxy-937348762913.europe-west1.run.app"
    private static let pageSize = 20

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.waitsForConnectivity = true
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            config.httpAdditionalHeaders = [
                "Accept": "application/json",
                "Connection": "close"
            ]
            self.session = URLSession(configuration: config)
        }
    }

    private var proxyBaseURL: URL {
        if let configured = AppConfiguration.shoppingProxyURL {
            return configured
        }
        return URL(string: Self.defaultShoppingProxyURL)!
    }

    func searchProducts(query: String, country: String, offset: Int = 0) async throws -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ShoppingError.noResults
        }

        try Task.checkCancellation()

        var components = URLComponents(
            url: proxyBaseURL.appendingPathComponent("shopping/search"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: String(Self.pageSize)),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components.url else {
            throw ShoppingError.networkError
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ShoppingError.networkError
        }

        try Task.checkCancellation()

        guard let http = response as? HTTPURLResponse else {
            throw ShoppingError.networkError
        }

        switch http.statusCode {
        case 200:
            break
        case 429:
            throw ShoppingError.serverError(code: 429)
        case 400...499:
            throw ShoppingError.serverError(code: http.statusCode)
        case 500...599:
            throw ShoppingError.serverError(code: http.statusCode)
        default:
            throw ShoppingError.serverError(code: http.statusCode)
        }

        let products: [Product]
        do {
            products = try JSONDecoder().decode([Product].self, from: data)
        } catch {
            throw ShoppingError.decodingError
        }

        if products.isEmpty && offset == 0 {
            throw ShoppingError.noResults
        }

        return products
    }
}
