import SwiftUI
import CoreData

struct ExploreProductsView: View {
    @StateObject private var viewModel: ExploreProductsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cardsAppeared = false
    
    init(image: ImageEntity) {
        _viewModel = StateObject(wrappedValue: ExploreProductsViewModel(image: image))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                ExploreProductsBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerBlock
                        
                        if viewModel.isLoading {
                            loadingBlock
                        } else if viewModel.queries.isEmpty {
                            emptyBlock
                        } else {
                            queryCards
                        }
                        
                        privacyFootnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Explore Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.load()
            withAnimation(.easeOut(duration: 0.45).delay(0.08)) {
                cardsAppeared = true
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "bag.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.95), Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Product ideas")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
            }
            
            Text(viewModel.subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }
    
    private var loadingBlock: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Generating suggestions…")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
    
    private var emptyBlock: some View {
        ContentUnavailableView(
            "No suggestions yet",
            systemImage: "sparkles",
            description: Text("Index this photo with AI tags, then try again.")
        )
        .foregroundStyle(.white.opacity(0.85))
        .padding(.vertical, 20)
    }
    
    private var queryCards: some View {
        VStack(spacing: 14) {
            ForEach(Array(viewModel.queries.enumerated()), id: \.element.id) { index, query in
                ExploreProductQueryCard(query: query)
                    .opacity(cardsAppeared ? 1 : 0)
                    .offset(y: cardsAppeared ? 0 : 18)
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.82)
                            .delay(Double(index) * 0.07),
                        value: cardsAppeared
                    )
            }
        }
    }
    
    private var privacyFootnote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
            Text(viewModel.didUseRuleBasedFallback
                ? "Queries are generated on your device from saved metadata. Images are not uploaded."
                : "Brand names and tags (not photos) are sent to Google Gemini to generate queries. Images are never uploaded.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}

// MARK: - Card

private struct ExploreProductQueryCard: View {
    let query: GeneratedProductQuery
    @State private var isShopPressed = false

    private var confidenceColor: Color {
        switch query.confidence {
        case .high: return Color.green.opacity(0.9)
        case .medium: return Color.yellow.opacity(0.95)
        case .low: return Color.orange.opacity(0.9)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(query.text)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                confidenceBadge
            }
            
            if !query.chips.isEmpty {
                FlowLayoutChips(items: query.chips)
            }

            NavigationLink {
                ShoppingResultsView(query: query.text)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.subheadline.weight(.semibold))
                    Text("Shop This")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.75)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                }
                .scaleEffect(isShopPressed ? 0.97 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isShopPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isShopPressed = true }
                    .onEnded { _ in isShopPressed = false }
            )
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.35),
                                    Color.white.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
    }
    
    private var confidenceBadge: some View {
        Text(query.confidence.rawValue)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(confidenceColor))
    }
}

// MARK: - Background

private struct ExploreProductsBackground: View {
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

// MARK: - Chips layout

private struct FlowLayoutChips: View {
    let items: [String]
    
    var body: some View {
        ExploreProductsFlexibleChips(items: items) { chip in
            Text(chip)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )
        }
    }
}

/// Simple wrapping chip row without iOS 16+ Layout APIs dependency issues.
private struct ExploreProductsFlexibleChips<Content: View>: View {
    let items: [String]
    let content: (String) -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        content(item)
                    }
                }
            }
        }
    }
    
    private var rows: [[String]] {
        var result: [[String]] = [[]]
        var rowWidth: CGFloat = 0
        let maxWidth: CGFloat = 320
        let spacing: CGFloat = 8
        let approxChip: CGFloat = 72
        
        for item in items {
            if rowWidth + approxChip > maxWidth, !result[result.count - 1].isEmpty {
                result.append([])
                rowWidth = 0
            }
            result[result.count - 1].append(item)
            rowWidth += approxChip + spacing
        }
        return result.filter { !$0.isEmpty }
    }
}
