import Foundation

/// Rule-based domain classifier for product query generation (V1 — deterministic, no LLM).
enum MetadataDomainClassifier {
    
    private struct DomainRule {
        let domain: ProductExploreDomain
        let keywords: [String]
        let weight: Int
    }
    
    private static let rules: [DomainRule] = [
        DomainRule(domain: .fashionApparel, keywords: [
            "shirt", "shoe", "shoes", "dress", "jacket", "pants", "jeans", "apparel", "clothing",
            "sneaker", "sneakers", "hoodie", "blouse", "skirt", "sportswear", "sleeve", "polo",
            "footwear", "garment", "outfit", "tee", "t-shirt", "tshirt", "denim", "knitwear"
        ], weight: 3),
        DomainRule(domain: .eyewear, keywords: [
            "sunglasses", "eyewear", "glasses", "spectacles", "lens", "lenses", "frames", "optical"
        ], weight: 4),
        DomainRule(domain: .automotive, keywords: [
            "car", "vehicle", "automobile", "automotive", "bmw", "mercedes", "audi", "toyota",
            "honda", "ford", "tesla", "porsche", "ferrari", "jeep", "truck", "motorcycle", "tire",
            "wheel", "bumper", "headlight", "dashboard", "engine"
        ], weight: 3),
        DomainRule(domain: .foodBeverage, keywords: [
            "beverage", "drink", "soda", "cola", "coffee", "tea", "juice", "beer", "wine",
            "snack", "food", "meal", "can", "bottle", "cereal", "chocolate", "candy", "restaurant",
            "coca-cola", "pepsi", "starbucks"
        ], weight: 3),
        DomainRule(domain: .cosmeticsBeauty, keywords: [
            "lipstick", "makeup", "cosmetics", "beauty", "skincare", "lotion", "perfume", "fragrance",
            "mascara", "foundation", "serum", "moisturizer", "shampoo", "l'oréal", "loreal", "sephora"
        ], weight: 4),
        DomainRule(domain: .electronics, keywords: [
            "laptop", "phone", "smartphone", "computer", "tablet", "device", "electronic", "electronics",
            "tech", "gadget", "monitor", "keyboard", "headphone", "earbuds", "charger", "cable",
            "television", "tv", "camera", "console"
        ], weight: 3),
        DomainRule(domain: .sportsFitness, keywords: [
            "fitness", "gym", "workout", "yoga", "running", "athletic", "sport", "sports", "ball",
            "dumbbell", "exercise", "training", "cycling", "swim"
        ], weight: 2),
        DomainRule(domain: .accessories, keywords: [
            "watch", "watches", "bag", "handbag", "purse", "wallet", "belt", "hat", "cap", "jewelry",
            "necklace", "bracelet", "ring", "earring", "scarf", "glove", "backpack", "tote"
        ], weight: 2),
        DomainRule(domain: .lifestyleGeneral, keywords: [
            "furniture", "decor", "home", "kitchen", "candle", "plant", "book", "toy", "gift",
            "stationery", "umbrella", "lifestyle", "household"
        ], weight: 1)
    ]
    
    /// Known brands that strongly suggest a domain when category tags are weak.
    private static let brandDomainHints: [String: ProductExploreDomain] = [
        "nike": .fashionApparel, "adidas": .fashionApparel, "puma": .fashionApparel, "gucci": .fashionApparel,
        "bmw": .automotive, "mercedes": .automotive, "audi": .automotive, "toyota": .automotive,
        "coca-cola": .foodBeverage, "cocacola": .foodBeverage, "pepsi": .foodBeverage, "starbucks": .foodBeverage,
        "l'oréal": .cosmeticsBeauty, "loreal": .cosmeticsBeauty, "maybelline": .cosmeticsBeauty,
        "apple": .electronics, "samsung": .electronics, "sony": .electronics, "dell": .electronics,
        "ray-ban": .eyewear, "rayban": .eyewear, "oakley": .eyewear
    ]
    
    static func classify(snapshot: ProductExploreSnapshot, rankedTerms: [String]) -> DomainClassificationResult {
        let corpus = buildCorpus(snapshot: snapshot, rankedTerms: rankedTerms)
        var scores: [ProductExploreDomain: Int] = [:]
        
        for rule in rules {
            var ruleScore = 0
            for keyword in rule.keywords {
                if corpus.contains(keyword) {
                    ruleScore += rule.weight
                }
            }
            if ruleScore > 0 {
                scores[rule.domain, default: 0] += ruleScore
            }
        }
        
        if let brand = snapshot.primaryBrand {
            let brandKey = normalizedKey(brand)
            if let hinted = brandDomainHints[brandKey] {
                scores[hinted, default: 0] += 5
            }
        }
        
        for hint in snapshot.productHints {
            let key = normalizedKey(hint)
            if ["shirt", "shoe", "dress", "jacket", "pants", "bag"].contains(key) {
                scores[.fashionApparel, default: 0] += 2
            }
        }
        
        guard let best = scores.max(by: { $0.value < $1.value }),
              best.value >= 2 else {
            return DomainClassificationResult(primary: .unknown, score: 0)
        }
        
        return DomainClassificationResult(primary: best.key, score: best.value)
    }
    
    private static func buildCorpus(snapshot: ProductExploreSnapshot, rankedTerms: [String]) -> Set<String> {
        var tokens = Set<String>()
        func ingest(_ text: String) {
            let lower = text.lowercased()
            tokens.insert(lower)
            lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).forEach {
                let piece = String($0)
                if piece.count >= 2 { tokens.insert(piece) }
            }
        }
        
        for tag in snapshot.allTags { ingest(tag.name) }
        for hint in snapshot.productHints { ingest(hint) }
        for term in rankedTerms { ingest(term) }
        return tokens
    }
    
    private static func normalizedKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
