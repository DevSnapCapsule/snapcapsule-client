import CoreData
import Foundation

@MainActor
final class ExploreProductsViewModel: ObservableObject {
    @Published private(set) var queries: [GeneratedProductQuery] = []
    @Published private(set) var isLoading = false
    @Published private(set) var subtitle: String = ""
    @Published private(set) var didUseWeakFallback = false
    @Published private(set) var didUseRuleBasedFallback = false

    private let image: ImageEntity

    init(image: ImageEntity) {
        self.image = image
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let snapshot = ProductExploreMetadataBuilder.build(from: image)
        let hasGeminiInput = !snapshot.brandNames.isEmpty || !snapshot.topMetadataTags.isEmpty

        if hasGeminiInput {
            do {
                let geminiTexts = try await GeminiProductQueryService.shared.generateQueries(
                    brands: snapshot.brandNames,
                    tags: snapshot.topMetadataTags
                )
                if geminiTexts.count >= 2 {
                    queries = mapGeminiQueries(geminiTexts, snapshot: snapshot)
                    didUseWeakFallback = false
                    didUseRuleBasedFallback = false
                    subtitle = makeGeminiSubtitle(snapshot: snapshot)
                    return
                }
            } catch {
                // Fall through to on-device rule-based queries.
            }
        }

        let generated = ProductQueryGenerator.generate(from: snapshot)
        queries = generated
        didUseWeakFallback = generated.allSatisfy { $0.confidence == .low }
        didUseRuleBasedFallback = true
        subtitle = makeRuleBasedSubtitle(snapshot: snapshot, queryCount: generated.count)
    }

    // MARK: - Mapping

    private func mapGeminiQueries(_ texts: [String], snapshot: ProductExploreSnapshot) -> [GeneratedProductQuery] {
        let sourceTerms = snapshot.brandNames + snapshot.topMetadataTags

        return texts.map { text in
            let lowerText = text.lowercased()
            let chips = sourceTerms.filter { lowerText.contains($0.lowercased()) }
            return GeneratedProductQuery(
                text: text,
                chips: chips,
                confidence: .high
            )
        }
    }

    // MARK: - Subtitles

    private func makeGeminiSubtitle(snapshot: ProductExploreSnapshot) -> String {
        if let brand = snapshot.primaryBrand {
            return "AI suggestions based on \(brand) and photo metadata."
        }
        return "AI suggestions from your photo metadata."
    }

    private func makeRuleBasedSubtitle(snapshot: ProductExploreSnapshot, queryCount: Int) -> String {
        if queryCount == 0 {
            return "Add or index photos with AI tags to discover product ideas."
        }
        if let brand = snapshot.primaryBrand {
            return "On-device suggestions based on \(brand) and saved metadata."
        }
        return "On-device suggestions from saved metadata."
    }
}
