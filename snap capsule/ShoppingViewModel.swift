import Foundation

@MainActor
final class ShoppingViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore = true

    var isEmpty: Bool {
        !isLoading && products.isEmpty && errorMessage == nil
    }

    private let service: any ProductSearching
    private let country: String
    private var currentQuery: String = ""
    private var currentOffset = 0
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    static let debounceInterval: Duration = .milliseconds(400)

    init(
        query: String,
        country: String? = nil,
        service: any ProductSearching = ShoppingService.shared
    ) {
        self.currentQuery = query
        self.country = country ?? Locale.current.region?.identifier ?? "US"
        self.service = service
    }

    func setQuery(_ query: String) {
        guard query != currentQuery else { return }
        currentQuery = query
        debounceSearch()
    }

    func load() async {
        debounceTask?.cancel()
        await performSearch(reset: true)
    }

    func refresh() async {
        await performSearch(reset: true)
    }

    func loadMoreIfNeeded(currentProduct: Product) async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        guard let last = products.last, last.id == currentProduct.id else { return }
        await performSearch(reset: false)
    }

    func retry() async {
        await performSearch(reset: true)
    }

    // MARK: - Private

    private func debounceSearch() {
        debounceTask?.cancel()
        searchTask?.cancel()

        debounceTask = Task {
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            await performSearch(reset: true)
        }
    }

    private func performSearch(reset: Bool) async {
        searchTask?.cancel()

        let query = currentQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            products = []
            errorMessage = nil
            isLoading = false
            return
        }

        if reset {
            currentOffset = 0
            hasMore = true
            isLoading = true
            errorMessage = nil
            if products.isEmpty {
                products = []
            }
        } else {
            isLoadingMore = true
        }

        let offset = reset ? 0 : currentOffset

        searchTask = Task {
            do {
                let results = try await service.searchProducts(
                    query: query,
                    country: country,
                    offset: offset
                )

                guard !Task.isCancelled else { return }

                if reset {
                    products = results
                } else {
                    products.append(contentsOf: results)
                }

                currentOffset = products.count
                hasMore = results.count >= 20
                errorMessage = nil
            } catch is CancellationError {
                return
            } catch ShoppingError.noResults {
                if reset {
                    products = []
                }
                hasMore = false
                errorMessage = nil
            } catch {
                if reset {
                    products = []
                }
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }

            isLoading = false
            isLoadingMore = false
        }

        await searchTask?.value
    }
}
