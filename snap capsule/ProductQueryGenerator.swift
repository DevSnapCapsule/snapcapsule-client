import CoreData
import Foundation

// MARK: - Future LLM extension (disabled in V1)

/// Future extension point for optional LLM refinement (disabled in V1).
protocol LLMQueryPolisher {
    func polish(queries: [GeneratedProductQuery], snapshot: ProductExploreSnapshot) -> [GeneratedProductQuery]
}

/// Placeholder for a future on-device or opted-in LLM pass. Not used in V1.
struct DisabledLLMQueryPolisher: LLMQueryPolisher {
    func polish(queries: [GeneratedProductQuery], snapshot: ProductExploreSnapshot) -> [GeneratedProductQuery] {
        queries
    }
}

// MARK: - Generator

enum ProductQueryGenerator {
    
    /// Optional future polisher — set to `nil` (default) to keep V1 fully rule-based.
    static var llmPolisher: (any LLMQueryPolisher)? = nil
    
    static func generate(from image: ImageEntity) -> [GeneratedProductQuery] {
        let snapshot = ProductExploreMetadataBuilder.build(from: image)
        return generate(from: snapshot)
    }
    
    static func generate(from snapshot: ProductExploreSnapshot) -> [GeneratedProductQuery] {
        guard snapshot.hasUsableSignals else {
            return finalize(drafts: QueryTemplateEngine.weakMetadataFallback(snapshot: snapshot), snapshot: snapshot)
        }
        
        let rankedTerms = rankTerms(snapshot: snapshot)
        let classification = MetadataDomainClassifier.classify(snapshot: snapshot, rankedTerms: rankedTerms)
        
        // Brand-only or very sparse metadata → safe brand/generic templates (not a single weak line).
        if let brand = snapshot.primaryBrand,
           rankedTerms.filter({ $0.caseInsensitiveCompare(brand) != .orderedSame }).isEmpty {
            let drafts = QueryTemplateEngine.generate(
                domain: .unknown,
                snapshot: snapshot,
                rankedTerms: rankedTerms
            )
            return finalize(drafts: drafts, snapshot: snapshot)
        }
        
        let signalStrength = countStrongSignals(snapshot: snapshot, rankedTerms: rankedTerms)
        if signalStrength < 2 {
            return finalize(drafts: QueryTemplateEngine.weakMetadataFallback(snapshot: snapshot), snapshot: snapshot)
        }
        
        var drafts = QueryTemplateEngine.generate(
            domain: classification.primary,
            snapshot: snapshot,
            rankedTerms: rankedTerms
        )
        
        if drafts.isEmpty {
            drafts = QueryTemplateEngine.weakMetadataFallback(snapshot: snapshot)
        }
        
        return finalize(drafts: drafts, snapshot: snapshot)
    }
    
    // MARK: - Ranking & signals
    
    private static func rankTerms(snapshot: ProductExploreSnapshot) -> [String] {
        var seen = Set<String>()
        func key(_ text: String) -> String {
            text.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        }
        
        let sourcePriority: [ProductExploreTagSource: Int] = [
            .brand: 0, .object: 1, .productHint: 2, .label: 3, .scene: 4, .ocr: 5
        ]
        
        var tags = snapshot.allTags
        for hint in snapshot.productHints {
            tags.append(ProductExploreTag(name: hint, confidence: 0.85, source: .productHint))
        }
        
        let sorted = tags.sorted { lhs, rhs in
            let lp = sourcePriority[lhs.source] ?? 9
            let rp = sourcePriority[rhs.source] ?? 9
            if lp != rp { return lp < rp }
            return lhs.confidence > rhs.confidence
        }
        
        var result: [String] = []
        for tag in sorted {
            let k = key(tag.name)
            guard !seen.contains(k) else { continue }
            guard !isNoiseTerm(tag.name) else { continue }
            seen.insert(k)
            result.append(tag.name)
        }
        return result
    }
    
    private static func countStrongSignals(snapshot: ProductExploreSnapshot, rankedTerms: [String]) -> Int {
        var count = 0
        if snapshot.primaryBrand != nil { count += 1 }
        if !rankedTerms.isEmpty { count += 1 }
        if !snapshot.ocrTexts.isEmpty { count += 1 }
        if !snapshot.productHints.isEmpty { count += 1 }
        return count
    }
    
    private static func isNoiseTerm(_ text: String) -> Bool {
        let lower = text.lowercased()
        if VisionNoiseTerms.shouldSuppressAsFreeformLabel(text) { return true }
        let chromatic: Set<String> = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "brown", "white", "black", "gray", "grey"]
        if chromatic.contains(lower) { return true }
        return false
    }
    
    // MARK: - Finalize
    
    private static func finalize(drafts: [QueryDraft], snapshot: ProductExploreSnapshot) -> [GeneratedProductQuery] {
        var seenTexts = Set<String>()
        var results: [GeneratedProductQuery] = []
        
        for draft in drafts {
            let normalized = draft.text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seenTexts.contains(normalized) else { continue }
            seenTexts.insert(normalized)
            results.append(
                GeneratedProductQuery(
                    text: draft.text,
                    chips: draft.chips,
                    confidence: draft.confidence
                )
            )
            if results.count >= 3 { break }
        }
        
        if let polisher = llmPolisher {
            return polisher.polish(queries: results, snapshot: snapshot)
        }
        
        return results
    }
}
