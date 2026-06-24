import CoreData
import Foundation

/// Builds a privacy-safe metadata snapshot from Core Data — no image bytes, no network.
enum ProductExploreMetadataBuilder {
    
    private static let minimumBrandConfidence = 0.54
    
    private static let chromaticColorNames: Set<String> = [
        "red", "orange", "yellow", "green", "blue", "purple", "pink", "brown", "gray", "grey",
        "white", "black", "beige", "navy", "teal", "maroon", "cyan", "magenta", "gold", "silver"
    ]
    
    private static let emotionKeywords: Set<String> = [
        "crying", "sad", "happy", "smiling", "smile", "angry", "surprised", "laughing", "emotion"
    ]
    
    private static let locationKeywords: [String] = [
        "taj mahal", "statue of liberty", "eiffel tower", "tower bridge", "golden gate",
        "bridge", "temple", "palace", "monument", "landmark", "cityscape", "skyline"
    ]
    
    static func build(from image: ImageEntity) -> ProductExploreSnapshot {
        var brands: [ProductExploreTag] = []
        var objects: [ProductExploreTag] = []
        var labels: [ProductExploreTag] = []
        var scenes: [ProductExploreTag] = []
        var ocrTexts: [ProductExploreTag] = []
        
        if let brandEntities = image.brands as? Set<BrandEntity> {
            let sorted = brandEntities.sorted { $0.confidence > $1.confidence }
            var seenBrandKeys = Set<String>()
            for brand in sorted {
                guard let rawName = brand.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !rawName.isEmpty,
                      brand.confidence >= minimumBrandConfidence,
                      VisionNoiseTerms.isPlausibleBrandName(rawName) else { continue }
                // Canonicalize stored names (older data may still hold sub-brands like "iPhone").
                let name = VisionNoiseTerms.canonicalBrandName(rawName)
                let key = name.lowercased()
                guard !seenBrandKeys.contains(key) else { continue }
                seenBrandKeys.insert(key)
                brands.append(ProductExploreTag(name: name, confidence: brand.confidence, source: .brand))
            }
        }
        
        if let objectEntities = image.objects as? Set<ObjectEntity> {
            for object in objectEntities.sorted(by: { $0.confidence > $1.confidence }) {
                guard let name = sanitizedName(object.name) else { continue }
                objects.append(ProductExploreTag(name: name, confidence: object.confidence, source: .object))
            }
        }
        
        if let labelEntities = image.labels as? Set<LabelEntity> {
            let sorted = labelEntities.sorted { $0.confidence > $1.confidence }
            for label in sorted {
                guard let raw = label.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty else { continue }
                
                if isOCRLike(raw) {
                    if !VisionNoiseTerms.shouldSuppressAsFreeformLabel(raw) {
                        ocrTexts.append(ProductExploreTag(name: raw, confidence: label.confidence, source: .ocr))
                    }
                    continue
                }
                
                guard let name = sanitizedName(raw),
                      !isEmotionLike(name),
                      !isLocationLike(name) else { continue }
                
                labels.append(ProductExploreTag(name: name, confidence: label.confidence, source: .label))
            }
        }
        
        if let sceneEntities = image.scenes as? Set<SceneEntity> {
            for scene in sceneEntities.sorted(by: { $0.confidence > $1.confidence }) {
                guard let name = sanitizedName(scene.name),
                      !isLocationLike(name) else { continue }
                scenes.append(ProductExploreTag(name: name, confidence: scene.confidence, source: .scene))
            }
        }
        
        let productHints = buildProductHints(
            brands: brands.map(\.name),
            labels: labels.map(\.name),
            objects: objects.map(\.name),
            faces: ((image.faces as? Set<FaceEntity>) ?? []).compactMap { $0.faceType }
        )
        
        return ProductExploreSnapshot(
            brands: brands,
            objects: objects,
            labels: labels,
            scenes: scenes,
            ocrTexts: ocrTexts,
            productHints: productHints
        )
    }
    
    // MARK: - Helpers
    
    private static func sanitizedName(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if chromaticColorNames.contains(lower) { return nil }
        if VisionNoiseTerms.shouldSuppressAsFreeformLabel(trimmed) { return nil }
        return trimmed
    }
    
    private static func isOCRLike(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 6
            || trimmed.contains(" ")
            || trimmed.rangeOfCharacter(from: .decimalDigits) != nil
    }
    
    private static func isEmotionLike(_ text: String) -> Bool {
        let lower = text.lowercased()
        return emotionKeywords.contains(where: { lower.contains($0) })
    }
    
    private static func isLocationLike(_ text: String) -> Bool {
        let lower = text.lowercased()
        return locationKeywords.contains(where: { lower.contains($0) })
    }
    
    private static func buildProductHints(
        brands: [String],
        labels: [String],
        objects: [String],
        faces: [String]
    ) -> [String] {
        let brandResults = brands.map { BrandDetectionResult(brandName: $0, confidence: 1.0, boundingBox: nil) }
        let info = ProductAnalyzer.shared.extractProductInfo(
            from: labels,
            objects: objects,
            brands: brandResults,
            faces: faces
        )
        var hints: [String] = []
        if let product = info.product?.trimmingCharacters(in: .whitespacesAndNewlines), !product.isEmpty {
            hints.append(product)
        }
        if let brand = info.brand?.trimmingCharacters(in: .whitespacesAndNewlines),
           !brand.isEmpty,
           !brands.contains(where: { $0.caseInsensitiveCompare(brand) == .orderedSame }) {
            hints.append(brand)
        }
        return hints
    }
}
