import Foundation

/// Deterministic query templates keyed by classified product domain.
enum QueryTemplateEngine {
    
    private static let queryNoiseTerms: Set<String> = [
        "logo", "logos", "symbol", "icon", "text", "font", "label", "brand", "brands",
        "product", "products", "object", "objects", "thing", "items", "image", "photo",
        "face", "person", "people", "background", "design", "graphic"
    ]
    
    static func generate(
        domain: ProductExploreDomain,
        snapshot: ProductExploreSnapshot,
        rankedTerms: [String]
    ) -> [QueryDraft] {
        let brand = snapshot.primaryBrand
        let descriptors = pickDescriptors(from: rankedTerms, domain: domain, max: 3)
        let ocrKeyword = pickOCRKeyword(from: snapshot.ocrTexts.map(\.name))
        
        var drafts: [QueryDraft] = []
        
        switch domain {
        case .fashionApparel:
            drafts.append(contentsOf: fashionQueries(brand: brand, descriptors: descriptors))
        case .eyewear:
            drafts.append(contentsOf: eyewearQueries(brand: brand, descriptors: descriptors))
        case .automotive:
            drafts.append(contentsOf: automotiveQueries(brand: brand, descriptors: descriptors))
        case .foodBeverage:
            drafts.append(contentsOf: foodQueries(brand: brand, descriptors: descriptors, ocr: ocrKeyword))
        case .cosmeticsBeauty:
            drafts.append(contentsOf: cosmeticsQueries(brand: brand, descriptors: descriptors))
        case .electronics:
            drafts.append(contentsOf: electronicsQueries(brand: brand, descriptors: descriptors))
        case .sportsFitness:
            drafts.append(contentsOf: sportsQueries(brand: brand, descriptors: descriptors))
        case .accessories:
            drafts.append(contentsOf: accessoriesQueries(brand: brand, descriptors: descriptors))
        case .lifestyleGeneral:
            drafts.append(contentsOf: lifestyleQueries(brand: brand, descriptors: descriptors))
        case .unknown:
            drafts.append(contentsOf: brandFallbackQueries(brand: brand, descriptors: descriptors))
        }
        
        if drafts.isEmpty {
            drafts.append(contentsOf: brandFallbackQueries(brand: brand, descriptors: descriptors))
        }
        
        return drafts
    }
    
    // MARK: - Domain templates
    
    private static func fashionQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        var result: [QueryDraft] = []
        let sport = descriptors.first(where: { containsAny($0, ["sport", "athletic", "gym", "fitness", "training"]) })
        let apparel = descriptors.first(where: { containsAny($0, ["shirt", "sleeve", "shoe", "dress", "jacket", "pants", "apparel", "sportswear"]) })
        
        if let brand, let apparel {
            result.append(draft("\(brand) \(apparel)", chips: [brand, apparel], confidence: .high))
        } else if let brand, let sport {
            result.append(draft("\(brand) athletic \(sport)", chips: [brand, sport], confidence: .high))
            result.append(draft("\(brand) gym accessories", chips: [brand, "gym"], confidence: .medium))
        } else if let brand {
            result.append(draft("\(brand) sportswear", chips: [brand, "sportswear"], confidence: .medium))
            result.append(draft("\(brand) apparel", chips: [brand, "apparel"], confidence: .medium))
        } else if let apparel {
            result.append(draft("\(apparel) apparel", chips: [apparel], confidence: .medium))
        }
        return result
    }
    
    private static func eyewearQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        var result: [QueryDraft] = []
        let hasSunglasses = descriptors.contains(where: { containsAny($0, ["sunglass", "eyewear", "glasses"]) })
        
        if let brand {
            result.append(draft("\(brand) eyewear", chips: [brand, "eyewear"], confidence: .high))
            if hasSunglasses {
                result.append(draft("stylish \(brand) sunglasses", chips: [brand, "sunglasses"], confidence: .medium))
            }
        } else {
            result.append(draft("fashion eyewear", chips: ["eyewear", "fashion"], confidence: .medium))
            if hasSunglasses {
                result.append(draft("stylish sunglasses", chips: ["sunglasses"], confidence: .medium))
            }
        }
        return result
    }
    
    private static func automotiveQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        guard let brand else {
            if let vehicle = descriptors.first(where: { containsAny($0, ["car", "vehicle", "automotive"]) }) {
                return [draft("\(vehicle) accessories", chips: [vehicle], confidence: .medium)]
            }
            return []
        }
        return [
            draft("\(brand) car accessories", chips: [brand, "car"], confidence: .high),
            draft("\(brand) automotive products", chips: [brand, "automotive"], confidence: .medium)
        ]
    }
    
    private static func foodQueries(brand: String?, descriptors: [String], ocr: String?) -> [QueryDraft] {
        var result: [QueryDraft] = []
        let beverage = descriptors.first(where: { containsAny($0, ["beverage", "drink", "soda", "cola", "coffee", "juice", "can", "bottle"]) })
        
        if let brand {
            result.append(draft("\(brand) beverages", chips: [brand, "beverage"], confidence: .high))
        }
        if let beverage {
            result.append(draft("\(beverage) products", chips: [beverage], confidence: .medium))
        } else if let ocr {
            result.append(draft("\(ocr) food products", chips: [ocr], confidence: .medium))
        } else {
            result.append(draft("soft drink products", chips: ["beverage"], confidence: .low))
        }
        return result
    }
    
    private static func cosmeticsQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        var result: [QueryDraft] = []
        let beauty = descriptors.first(where: { containsAny($0, ["lipstick", "makeup", "beauty", "cosmetic", "skincare"]) })
        
        if let brand {
            result.append(draft("\(brand) beauty products", chips: [brand, "beauty"], confidence: .high))
        }
        if let beauty {
            result.append(draft("\(beauty) accessories", chips: [beauty], confidence: .medium))
        } else {
            result.append(draft("makeup accessories", chips: ["makeup"], confidence: .medium))
        }
        return result
    }
    
    private static func electronicsQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        guard let brand else {
            if let device = descriptors.first(where: { containsAny($0, ["laptop", "phone", "tablet", "device", "computer"]) }) {
                return [draft("\(device) accessories", chips: [device], confidence: .medium)]
            }
            return [draft("electronic products", chips: ["electronics"], confidence: .low)]
        }
        return [
            draft("\(brand) tech accessories", chips: [brand, "tech"], confidence: .high),
            draft("\(brand) electronic products", chips: [brand, "electronics"], confidence: .medium)
        ]
    }
    
    private static func sportsQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        let athletic = descriptors.first(where: { containsAny($0, ["athletic", "fitness", "gym", "sport", "training"]) }) ?? "fitness"
        if let brand {
            return [
                draft("\(brand) \(athletic) gear", chips: [brand, athletic], confidence: .high),
                draft("\(brand) athletic equipment", chips: [brand, "athletic"], confidence: .medium)
            ]
        }
        return [draft("\(athletic) equipment", chips: [athletic], confidence: .medium)]
    }
    
    private static func accessoriesQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        let item = descriptors.first ?? "accessories"
        if let brand {
            return [
                draft("\(brand) \(item)", chips: [brand, item], confidence: .high),
                draft("\(brand) accessories", chips: [brand, "accessories"], confidence: .medium)
            ]
        }
        return [draft("\(item) accessories", chips: [item], confidence: .medium)]
    }
    
    private static func lifestyleQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        let item = descriptors.first ?? "lifestyle"
        if let brand {
            return [
                draft("\(brand) home products", chips: [brand, item], confidence: .medium),
                draft("\(brand) lifestyle products", chips: [brand, "lifestyle"], confidence: .medium)
            ]
        }
        return [draft("\(item) products", chips: [item], confidence: .low)]
    }
    
    private static func brandFallbackQueries(brand: String?, descriptors: [String]) -> [QueryDraft] {
        if let brand {
            return [
                draft("\(brand) products", chips: [brand], confidence: .medium),
                draft("products related to \(brand)", chips: [brand], confidence: .low)
            ]
        }
        if let top = descriptors.first {
            return [draft("\(top) products", chips: [top], confidence: .low)]
        }
        return []
    }
    
    static func weakMetadataFallback(snapshot: ProductExploreSnapshot) -> [QueryDraft] {
        if let brand = snapshot.primaryBrand {
            return [draft("products related to \(brand)", chips: [brand], confidence: .low)]
        }
        if let tag = snapshot.objects.first?.name ?? snapshot.labels.first?.name {
            return [draft("related \(tag) products", chips: [tag], confidence: .low)]
        }
        return [draft("related product ideas", chips: [], confidence: .low)]
    }
    
    // MARK: - Descriptor picking
    
    private static func pickDescriptors(from rankedTerms: [String], domain: ProductExploreDomain, max: Int) -> [String] {
        rankedTerms
            .filter { term in
                let lower = term.lowercased()
                guard !queryNoiseTerms.contains(lower) else { return false }
                guard !VisionNoiseTerms.shouldSuppressAsFreeformLabel(term) else { return false }
                return true
            }
            .prefix(max)
            .map { $0 }
    }
    
    private static func pickOCRKeyword(from texts: [String]) -> String? {
        texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 && $0.count <= 32 }
            .first
    }
    
    // MARK: - Utilities
    
    private static func draft(_ text: String, chips: [String], confidence: ProductQueryConfidence) -> QueryDraft {
        let cleanedChips = Array(
            Set(chips.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        ).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return QueryDraft(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            chips: cleanedChips,
            confidence: confidence
        )
    }
    
    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        let lower = text.lowercased()
        return needles.contains(where: { lower.contains($0) })
    }
}
