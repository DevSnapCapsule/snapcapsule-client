//
//  snap_capsuleTests.swift
//  snap capsuleTests
//

import Foundation
import Testing
@testable import snap_capsule

// MARK: - Product decoding

struct ProductTests {

    @Test func decodesFullProduct() throws {
        let json = """
        {
            "id": "v1|123|0",
            "title": "Nike Air Max 90",
            "price": 89.99,
            "currency": "USD",
            "imageUrl": "https://i.ebayimg.com/images/g/abc/s-l500.jpg",
            "buyUrl": "https://www.ebay.com/itm/123",
            "seller": "sneaker_store",
            "condition": "New",
            "source": "ebay"
        }
        """.data(using: .utf8)!

        let product = try JSONDecoder().decode(Product.self, from: json)

        #expect(product.id == "v1|123|0")
        #expect(product.title == "Nike Air Max 90")
        #expect(product.price == 89.99)
        #expect(product.currency == "USD")
        #expect(product.imageUrl == "https://i.ebayimg.com/images/g/abc/s-l500.jpg")
        #expect(product.buyUrl == "https://www.ebay.com/itm/123")
        #expect(product.seller == "sneaker_store")
        #expect(product.condition == "New")
        #expect(product.source == "ebay")
        #expect(product.formattedPrice.contains("89.99") || product.formattedPrice.contains("90"))
        #expect(product.buyURL != nil)
        #expect(product.imageURL != nil)
    }

    @Test func decodesPartialProduct() throws {
        let json = """
        {
            "id": "v1|456|0",
            "title": "Vintage Camera",
            "price": null,
            "currency": null,
            "imageUrl": null,
            "buyUrl": "https://www.ebay.com/itm/456",
            "seller": null,
            "condition": null,
            "source": "ebay"
        }
        """.data(using: .utf8)!

        let product = try JSONDecoder().decode(Product.self, from: json)

        #expect(product.id == "v1|456|0")
        #expect(product.title == "Vintage Camera")
        #expect(product.price == nil)
        #expect(product.formattedPrice == "Price unavailable")
        #expect(product.imageURL == nil)
        #expect(product.buyURL != nil)
    }

    @Test func malformedJSONThrows() {
        let json = "{ not valid json }".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Product.self, from: json)
        }
    }

    @Test func productEquality() throws {
        let json = """
        {"id":"a","title":"Test","price":10,"currency":"USD","imageUrl":"https://x.com/i.jpg","buyUrl":"https://x.com","seller":"s","condition":"New","source":"ebay"}
        """.data(using: .utf8)!

        let a = try JSONDecoder().decode(Product.self, from: json)
        let b = try JSONDecoder().decode(Product.self, from: json)
        #expect(a == b)
    }
}

// MARK: - ShoppingService

struct ShoppingServiceTests {

    @Test func buildsCorrectSearchURL() async throws {
        let session = makeMockSession { request in
            let url = try #require(request.url)
            #expect(url.path.hasSuffix("/shopping/search"))
            #expect(url.query?.contains("q=Nike") == true || url.query?.contains("q=Nike+") == true)
            #expect(url.query?.contains("country=US") == true)
            #expect(url.query?.contains("limit=20") == true)
            #expect(url.query?.contains("offset=0") == true)

            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let body = """
            [{"id":"1","title":"Shoe","price":50,"currency":"USD","imageUrl":"https://i.ebayimg.com/x.jpg","buyUrl":"https://ebay.com/1","seller":"s","condition":"New","source":"ebay"}]
            """.data(using: .utf8)!
            return (response, body)
        }

        let service = ShoppingService(session: session)
        let products = try await service.searchProducts(query: "Nike", country: "US")
        #expect(products.count == 1)
        #expect(products.first?.title == "Shoe")
    }

    @Test func mapsServerError() async {
        let session = makeMockSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 502, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let service = ShoppingService(session: session)
        await #expect(throws: ShoppingError.serverError(code: 502)) {
            try await service.searchProducts(query: "Nike", country: "US")
        }
    }

    @Test func mapsEmptyResultsToNoResults() async {
        let session = makeMockSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "[]".data(using: .utf8)!)
        }

        let service = ShoppingService(session: session)
        await #expect(throws: ShoppingError.noResults) {
            try await service.searchProducts(query: "Nike", country: "US")
        }
    }

    @Test func mapsDecodingError() async {
        let session = makeMockSession { request in
            let url = try #require(request.url)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }

        let service = ShoppingService(session: session)
        await #expect(throws: ShoppingError.decodingError) {
            try await service.searchProducts(query: "Nike", country: "US")
        }
    }
}

// MARK: - ShoppingViewModel

@MainActor
struct ShoppingViewModelTests {

    @Test func loadingToLoaded() async {
        let mock = MockShoppingService(
            results: [
                Product(id: "1", title: "Item", price: 10, currency: "USD",
                        imageUrl: "https://i.ebayimg.com/x.jpg", buyUrl: "https://ebay.com/1",
                        seller: "s", condition: "New", source: "ebay")
            ],
            error: nil
        )
        let vm = ShoppingViewModel(query: "Nike shoes", country: "US", service: mock)

        #expect(vm.isLoading == false)
        #expect(vm.products.isEmpty)

        async let loadTask: Void = vm.load()
        #expect(vm.isLoading == true)
        await loadTask

        #expect(vm.isLoading == false)
        #expect(vm.products.count == 1)
        #expect(vm.errorMessage == nil)
        #expect(vm.isEmpty == false)
    }

    @Test func loadingToError() async {
        let mock = MockShoppingService(results: [], error: ShoppingError.networkError)
        let vm = ShoppingViewModel(query: "Nike shoes", country: "US", service: mock)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.products.isEmpty)
        #expect(vm.errorMessage != nil)
    }

    @Test func loadingToEmpty() async {
        let mock = MockShoppingService(results: [], error: ShoppingError.noResults)
        let vm = ShoppingViewModel(query: "obscure item xyz", country: "US", service: mock)

        await vm.load()

        #expect(vm.isLoading == false)
        #expect(vm.products.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(vm.isEmpty == true)
    }
}

// MARK: - Test helpers

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockSession(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> URLSession {
    MockURLProtocol.handler = handler
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private struct MockShoppingService: ProductSearching {
    let results: [Product]
    let error: ShoppingError?

    func searchProducts(query: String, country: String, offset: Int) async throws -> [Product] {
        if let error { throw error }
        if results.isEmpty && offset == 0 { throw ShoppingError.noResults }
        return results
    }
}
