import Foundation

// MARK: - Generated output

enum ProductQueryConfidence: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct GeneratedProductQuery: Identifiable, Equatable {
    let id: UUID
    let text: String
    let chips: [String]
    let confidence: ProductQueryConfidence
    
    init(id: UUID = UUID(), text: String, chips: [String], confidence: ProductQueryConfidence) {
        self.id = id
        self.text = text
        self.chips = chips
        self.confidence = confidence
    }
}

// MARK: - Domain

enum ProductExploreDomain: String, CaseIterable {
    case fashionApparel
    case eyewear
    case automotive
    case foodBeverage
    case cosmeticsBeauty
    case electronics
    case sportsFitness
    case accessories
    case lifestyleGeneral
    case unknown
}

struct DomainClassificationResult: Equatable {
    let primary: ProductExploreDomain
    let score: Int
}

// MARK: - Snapshot (local metadata only)

enum ProductExploreTagSource: String, CaseIterable {
    case brand
    case object
    case label
    case scene
    case ocr
    case productHint
}

struct ProductExploreTag: Equatable {
    let name: String
    let confidence: Double
    let source: ProductExploreTagSource
}

struct ProductExploreSnapshot: Equatable {
    let brands: [ProductExploreTag]
    let objects: [ProductExploreTag]
    let labels: [ProductExploreTag]
    let scenes: [ProductExploreTag]
    let ocrTexts: [ProductExploreTag]
    let productHints: [String]
    
    var hasUsableSignals: Bool {
        !brands.isEmpty
            || !objects.isEmpty
            || !labels.isEmpty
            || !scenes.isEmpty
            || !ocrTexts.isEmpty
            || !productHints.isEmpty
    }
    
    var primaryBrand: String? {
        brands.first?.name
    }
    
    /// All tag strings for domain classification (lowercased corpus built separately).
    var allTags: [ProductExploreTag] {
        brands + objects + labels + scenes + ocrTexts
    }

    /// Detected brand names sorted by confidence (for Gemini query generation).
    var brandNames: [String] {
        brands.map(\.name)
    }

    /// Top metadata tags from labels, objects, and scenes (up to 10 by confidence).
    var topMetadataTags: [String] {
        (labels + objects + scenes)
            .sorted { $0.confidence > $1.confidence }
            .prefix(10)
            .map(\.name)
    }
}

struct QueryDraft: Equatable {
    let text: String
    let chips: [String]
    let confidence: ProductQueryConfidence
}
