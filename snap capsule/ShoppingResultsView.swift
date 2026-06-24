import SwiftUI

struct ShoppingResultsView: View {
    @StateObject private var viewModel: ShoppingViewModel
    @State private var safariLink: SafariLink?

    init(query: String) {
        _viewModel = StateObject(wrappedValue: ShoppingViewModel(query: query))
    }

    var body: some View {
        ZStack {
            ShoppingResultsBackground()
                .ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.products.isEmpty {
                    loadingGrid
                } else if let error = viewModel.errorMessage, viewModel.products.isEmpty {
                    errorState(message: error)
                } else if viewModel.products.isEmpty {
                    emptyState
                } else {
                    resultsGrid
                }
            }
        }
        .navigationTitle("Shop This")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - States

    private var loadingGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonProductCard()
                }
            }
            .padding(.horizontal, gridSpacing)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
    }

    private var resultsGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: gridSpacing) {
                ForEach(viewModel.products) { product in
                    ProductCardView(product: product) {
                        openProduct(product)
                    }
                    .onAppear {
                        Task { await viewModel.loadMoreIfNeeded(currentProduct: product) }
                    }
                }
            }
            .padding(.horizontal, gridSpacing)
            .padding(.top, 12)

            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }

            attributionLabel
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No products found", systemImage: "magnifyingglass")
        } description: {
            Text("We couldn't find eBay listings for this search. Try a different query.")
        } actions: {
            Button("Try Again") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    private func errorState(message: String) -> some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.retry() }
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white.opacity(0.85))
    }

    private var attributionLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2)
            Text("Results from eBay")
                .font(.caption)
        }
        .foregroundStyle(.white.opacity(0.45))
        .frame(maxWidth: .infinity)
    }

    private let gridSpacing: CGFloat = 14

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: gridSpacing, alignment: .top),
            GridItem(.flexible(), spacing: gridSpacing, alignment: .top)
        ]
    }

    private func openProduct(_ product: Product) {
        guard let url = product.buyURL else { return }
        safariLink = SafariLink(url: url)
    }
}

// MARK: - Safari sheet item

private struct SafariLink: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Skeleton card

private struct SkeletonProductCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShimmerPlaceholder()
                .aspectRatio(1, contentMode: .fit)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.1))
                .frame(width: 100, height: 12)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.08))
                .frame(width: 70, height: 18)

            Capsule()
                .fill(Color.white.opacity(0.06))
                .frame(width: 96, height: 26)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        }
    }
}

// MARK: - Background

private struct ShoppingResultsBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.14),
                Color(red: 0.04, green: 0.05, blue: 0.1),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
