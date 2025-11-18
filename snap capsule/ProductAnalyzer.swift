import Foundation
import UIKit

// MARK: - Product Information
struct ProductInfo: Codable {
    let gender: String? // "men" or "women"
    let brand: String? // Brand name (e.g., "Gucci", "Puma")
    let product: String? // Product type (e.g., "shirt", "shoe", "bag")
    
    var isValid: Bool {
        // Valid if we have at least brand and product (gender is optional)
        return brand != nil && product != nil
    }
    
    var searchQuery: String {
        var components: [String] = []
        // Gender is optional - include if available
        if let gender = gender {
            components.append(gender)
        }
        // Brand is required
        if let brand = brand {
            components.append(brand)
        }
        // Product is required
        if let product = product {
            components.append(product)
        }
        return components.joined(separator: " ")
    }
    
    // Convert to dictionary for storage in metadata
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let gender = gender {
            dict["gender"] = gender
        }
        if let brand = brand {
            dict["brand"] = brand
        }
        if let product = product {
            dict["product"] = product
        }
        return dict
    }
    
    // Create from dictionary
    static func fromDictionary(_ dict: [String: Any]) -> ProductInfo {
        return ProductInfo(
            gender: dict["gender"] as? String,
            brand: dict["brand"] as? String,
            product: dict["product"] as? String
        )
    }
}

// MARK: - Product Analyzer
class ProductAnalyzer {
    static let shared = ProductAnalyzer()
    
    private init() {}
    
    // MARK: - Extract Product Information from Labels
    func extractProductInfo(
        from labels: [String],
        objects: [String],
        brands: [BrandDetectionResult],
        faces: [String]
    ) -> ProductInfo {
        let allText = (labels + objects + faces).map { $0.lowercased() }
        let allLabelsSet = Set(allText)
        
        print("🔍 Extracting product info from:")
        print("   Labels: \(labels)")
        print("   Objects: \(objects)")
        print("   Brands: \(brands.map { $0.brandName })")
        
        // Extract gender
        let gender = extractGender(from: allLabelsSet, faces: faces)
        
        // Extract brand (from detected brands or labels)
        // Pass original labels (not lowercased) for brand extraction
        let brand = extractBrand(from: brands, labels: labels)
        
        // Extract product type - use original labels (not lowercased set, preserve individual labels)
        // Also include labels from brands that might be products (like "Men's Shirt")
        var allLabelsForProduct = Set(labels.map { $0.lowercased() })
        // Add brand names that might actually be products (like "Men's Shirt")
        for brand in brands {
            let lowercased = brand.brandName.lowercased()
            // Check if brand name contains product keywords
            let productKeywords = ["shirt", "shoe", "bag", "pants", "jacket", "dress", "watch"]
            for keyword in productKeywords {
                if lowercased.contains(keyword) {
                    allLabelsForProduct.insert(lowercased)
                    print("🔍 Added brand '\(brand.brandName)' to product extraction labels")
                    break
                }
            }
        }
        let product = extractProductType(from: allLabelsForProduct)
        
        let productInfo = ProductInfo(gender: gender, brand: brand, product: product)
        print("🔍 Final ProductInfo - Gender: \(gender ?? "nil"), Brand: \(brand ?? "nil"), Product: \(product ?? "nil"), Valid: \(productInfo.isValid)")
        
        return productInfo
    }
    
    // MARK: - Gender Detection
    private func extractGender(from labels: Set<String>, faces: [String]) -> String? {
        // Check for explicit gender indicators
        let menKeywords = ["men", "man", "male", "mens", "guy", "gentleman", "boys", "boy", "masculine"]
        let womenKeywords = ["women", "woman", "female", "womens", "lady", "ladies", "girl", "girls", "feminine"]
        
        // Check labels for gender indicators
        for label in labels {
            let lowercased = label.lowercased()
            
            // Check for men's clothing/products
            if menKeywords.contains(where: { lowercased.contains($0) }) {
                return "men"
            }
            
            // Check for women's clothing/products
            if womenKeywords.contains(where: { lowercased.contains($0) }) {
                return "women"
            }
        }
        
        // Check faces array for person indicators
        for face in faces {
            let lowercased = face.lowercased()
            if lowercased.contains("person") || lowercased.contains("face") {
                // If we detected a person but no explicit gender, we can't determine it
                // In a real scenario, you'd use ML face detection to determine gender
                // For now, we'll return nil and let the user know gender detection is not available
            }
        }
        
        // Check for gender-specific clothing items
        let menClothing = ["men's", "mens", "male clothing", "tie", "suit", "polo shirt"]
        let womenClothing = ["women's", "womens", "female clothing", "dress", "skirt", "heels", "handbag"]
        
        for label in labels {
            let lowercased = label.lowercased()
            
            if menClothing.contains(where: { lowercased.contains($0) }) {
                return "men"
            }
            
            if womenClothing.contains(where: { lowercased.contains($0) }) {
                return "women"
            }
        }
        
        return nil
    }
    
    // MARK: - Brand Detection
    private func extractBrand(from brands: [BrandDetectionResult], labels: [String]) -> String? {
        // Known brand names (prioritize these)
        let knownBrands = [
            "gucci", "puma", "nike", "adidas", "prada", "versace", "armani",
            "calvin klein", "tommy hilfiger", "ralph lauren", "burberry",
            "louis vuitton", "chanel", "dior", "hermes", "balenciaga",
            "saint laurent", "givenchy", "fendi", "dolce gabbana",
            "rolex", "omega", "tag heuer", "cartier", "tiffany", "tiffany & co"
        ]
        
        // Product names and clothing descriptors to exclude
        let productNames = ["shirt", "shoes", "shoe", "bag", "handbag", "pants", "jacket", 
                          "dress", "watch", "sunglasses", "hat", "jewelry", "top", "blouse",
                          "t-shirt", "tshirt", "t shirt", "polo", "sneakers", "boots",
                          "men's", "women's", "mens", "womens", "men", "women", "male", "female"]
        
        // First, check for known brands in the brands array (prioritize known brands)
        // This must be done FIRST to avoid picking "Men's Shirt" over "Gucci"
        for brand in brands {
            let lowercased = brand.brandName.lowercased()
            // Check if it's a known brand (exact match or contains)
            for knownBrand in knownBrands {
                if lowercased == knownBrand || lowercased.contains(knownBrand) {
                    print("✅ Known brand found from detected brands: \(brand.brandName) (matched: \(knownBrand))")
                    return brand.brandName
                }
            }
        }
        
        // If no known brand found, filter out product names and clothing descriptors
        // Exclude anything that contains product names or clothing terms
        let filteredBrands = brands.filter { brand in
            let lowercased = brand.brandName.lowercased()
            // Exclude product names and clothing descriptors
            for productName in productNames {
                if lowercased.contains(productName) {
                    print("⚠️ Filtering out brand '\(brand.brandName)' because it contains '\(productName)'")
                    return false
                }
            }
            return true
        }
        
        if let topBrand = filteredBrands.first {
            print("✅ Brand found from filtered brands: \(topBrand.brandName)")
            return topBrand.brandName
        }
        
        // Fallback: check labels for known brand names
        for label in labels {
            let lowercasedLabel = label.lowercased()
            for knownBrand in knownBrands {
                if lowercasedLabel == knownBrand || lowercasedLabel.contains(knownBrand) {
                    print("✅ Known brand found from labels: \(knownBrand.capitalized)")
                    return knownBrand.capitalized
                }
            }
        }
        
        print("⚠️ No brand found in brands or labels")
        return nil
    }
    
    // MARK: - Product Type Detection
    private func extractProductType(from labels: Set<String>) -> String? {
        print("🔍 Extracting product type from labels: \(labels)")
        // Clothing items - check in order of specificity (more specific first)
        let clothingKeywords: [String: String] = [
            "men's shirt": "shirt",
            "mens shirt": "shirt",
            "women's shirt": "shirt",
            "womens shirt": "shirt",
            "dress shirt": "shirt",
            "casual shirt": "shirt",
            "polo shirt": "shirt",
            "button-down": "shirt",
            "button down": "shirt",
            "button-down shirt": "shirt",
            "long sleeve shirt": "shirt",
            "short sleeve shirt": "shirt",
            "shirt": "shirt",
            "t-shirt": "shirt",
            "tshirt": "shirt",
            "t shirt": "shirt",
            "blouse": "shirt",
            "top": "shirt",
            "polo": "shirt",
            
            "shoe": "shoe",
            "shoes": "shoe",
            "sneaker": "shoe",
            "sneakers": "shoe",
            "boot": "shoe",
            "boots": "shoe",
            "sandal": "shoe",
            "sandals": "shoe",
            "heels": "shoe",
            "high heels": "shoe",
            "loafers": "shoe",
            "trainers": "shoe",
            
            "bag": "bag",
            "handbag": "bag",
            "purse": "bag",
            "backpack": "bag",
            "tote": "bag",
            "tote bag": "bag",
            "shoulder bag": "bag",
            "clutch": "bag",
            "wallet": "bag",
            
            "pants": "pants",
            "trousers": "pants",
            "jeans": "pants",
            "shorts": "pants",
            
            "jacket": "jacket",
            "coat": "jacket",
            "blazer": "jacket",
            
            "dress": "dress",
            "gown": "dress",
            
            "watch": "watch",
            "timepiece": "watch",
            
            "sunglasses": "sunglasses",
            "glasses": "sunglasses",
            
            "hat": "hat",
            "cap": "hat",
            "beanie": "hat",
            
            "jewelry": "jewelry",
            "necklace": "jewelry",
            "bracelet": "jewelry",
            "ring": "jewelry",
            "earrings": "jewelry"
        ]
        
        // Check labels for product keywords (more specific matches first)
        // Sort by key length (longer/more specific first) to match "men's shirt" before "shirt"
        let sortedKeywords = clothingKeywords.sorted { $0.key.count > $1.key.count }
        
        for label in labels {
            let lowercased = label.lowercased()
            
            // Check for exact matches first (more specific keywords first)
            for (keyword, productType) in sortedKeywords {
                if lowercased.contains(keyword) {
                    print("✅ Product type found: \(productType) from label: \(label) (matched keyword: \(keyword))")
                    return productType
                }
            }
        }
        
        print("⚠️ No product type found in labels: \(labels)")
        
        // If no specific product found, check for general clothing terms
        let generalClothingTerms = ["clothing", "apparel", "garment", "outfit", "attire"]
        for label in labels {
            let lowercased = label.lowercased()
            if generalClothingTerms.contains(where: { lowercased.contains($0) }) {
                // Try to infer from context
                if lowercased.contains("shirt") || lowercased.contains("top") {
                    return "shirt"
                } else if lowercased.contains("footwear") || lowercased.contains("shoe") {
                    return "shoe"
                } else if lowercased.contains("bag") || lowercased.contains("handbag") {
                    return "bag"
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Generate Search URL
    func generateSearchURL(for productInfo: ProductInfo) -> URL? {
        guard productInfo.isValid else { return nil }
        
        // Create a Google Shopping search URL
        let query = productInfo.searchQuery
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Google Shopping URL
        let urlString = "https://www.google.com/search?tbm=shop&q=\(query)"
        
        return URL(string: urlString)
    }
}

