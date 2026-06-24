import Foundation

/// Shared filters for Google Vision / on-device outputs so UI and API stay aligned.
enum VisionNoiseTerms {
    
    // MARK: - Brand
    
    /// Terms that are almost never real product brands when returned by Vision (colors, UI, photo jargon).
    static let brandBlocklist: Set<String> = [
        "white", "black", "red", "blue", "green", "yellow", "orange", "purple", "pink", "brown", "gray", "grey",
        "font", "fonts", "typeface", "text", "letter", "letters",
        "night", "darkness", "dark", "light", "bright", "shadow", "shadows",
        "monochrome", "mono-chrome", "mono chrome", "chromatic", "color", "colour", "colors", "colours",
        "photography", "photo", "photos", "image", "images", "picture", "pictures", "snapshot",
        "screenshot", "background", "foreground", "sky", "cloud", "clouds", "sun", "moon", "star",
        "silhouette", "blur", "bokeh", "texture", "pattern", "abstract", "minimalism", "minimal",
        "macro", "close-up", "close up", "wide angle", "panorama", "landscape", "portrait",
        "indoor", "outdoor", "studio", "natural", "artificial",
        "happiness", "sadness", "emotion", "emotions", "smile", "face", "faces", "eye", "eyes",
        "skin", "hair", "hand", "hands", "finger", "arm", "leg", "body",
        "water", "fire", "earth", "wood", "metal", "glass", "plastic", "fabric", "leather",
        "winter", "summer", "spring", "autumn", "fall", "rain", "snow", "fog", "mist",
        "vehicle", "car", "building", "house", "room", "wall", "floor", "ceiling", "window", "door",
        "animal", "dog", "cat", "bird", "tree", "flower", "grass", "plant",
        "food", "fruit", "drink", "coffee", "tea", "water bottle",
        "logo", "logos", "brand", "brands", "label", "labels", "symbol", "icon", "icons",
        "line", "lines", "shape", "shapes", "circle", "square", "triangle",
        "design", "graphic", "graphics", "illustration", "art", "arts", "drawing", "painting",
        "technology", "computer", "phone", "mobile", "screen", "digital", "electronics",
        "fashion", "clothing", "shirt", "shoe", "shoes", "bag", "hat", "dress", "jacket", "pants",
        "sport", "sports", "ball", "game", "games", "music", "musical", "instrument",
        "travel", "vacation", "holiday", "beach", "mountain", "ocean", "sea", "river", "lake",
        "city", "street", "road", "highway", "bridge", "tower", "castle", "church", "temple",
        "people", "person", "man", "woman", "boy", "girl", "child", "children", "baby", "family",
        "group", "crowd", "team", "audience", "human", "humans", "figure", "silhouette",
        "chin", "cheek", "cheeks", "jaw", "jawline", "face shape", "facial hair", "beard", "mustache", "moustache",
        "forehead", "nose", "lip", "lips", "eyebrow", "eyebrows", "eyelash", "eyelashes", "skin tone", "complexion",
        "stubble", "goatee", "sideburns", "head", "neck", "ear", "ears",
        "nature", "wildlife", "environment", "scene", "scenery", "view", "horizon",
        "product", "products", "object", "objects", "thing", "things", "item", "items",
        "material", "surface", "paper", "canvas", "film", "video", "movie", "animation",
        "vintage", "retro", "modern", "classic", "style", "styles", "theme", "themes",
        "beauty", "cosmetics", "makeup", "jewelry", "jewellery", "watch", "watches", "accessory",
        "furniture", "chair", "table", "lamp", "lighting", "equipment", "tool", "tools",
        "science", "medical", "health", "fitness", "exercise", "yoga", "running", "cycling",
        "business", "office", "work", "meeting", "conference", "presentation",
        "education", "school", "book", "books", "library", "study", "learning",
        "security", "safety", "warning", "sign", "signs", "notice", "information",
        "energy", "power", "electricity", "battery", "solar", "wind",
        "space", "planet", "moonlight", "sunlight", "sunrise", "sunset", "dawn", "dusk",
        "midnight", "noon", "evening", "morning", "afternoon", "time", "clock",
        "empty", "full", "half", "quarter", "zero", "one", "two", "first", "last", "next", "new", "old",
        "big", "small", "large", "tiny", "huge", "mini", "max", "micro", "mega",
        "high", "low", "top", "bottom", "left", "right", "center", "centre", "middle", "side",
        "up", "down", "forward", "back", "inside", "outside", "inner", "outer",
        "fast", "slow", "quick", "long", "short", "wide", "narrow", "thick", "thin",
        "soft", "hard", "smooth", "rough", "clean", "dirty", "fresh", "stale",
        "hot", "cold", "warm", "cool", "wet", "dry", "clean", "clear", "opaque", "transparent",
        "loud", "quiet", "silent", "noise", "sound", "voice", "speech", "talk",
        "happy", "sad", "angry", "calm", "peace", "love", "hate", "fear", "hope", "joy",
        "success", "failure", "win", "lose", "goal", "dream", "idea", "concept",
        "future", "past", "present", "history", "story", "news", "media", "press",
        "internet", "web", "online", "offline", "network", "data", "file", "files", "folder",
        "number", "numbers", "letter", "word", "words", "sentence", "paragraph",
        "english", "spanish", "french", "language", "languages", "alphabet",
        "north", "south", "east", "west", "global", "local", "national", "international",
        "public", "private", "personal", "professional", "commercial", "retail", "sale", "sales",
        "price", "cost", "free", "premium", "basic", "standard", "deluxe", "luxury",
        "gold", "silver", "bronze", "platinum", "diamond", "crystal", "pearl",
        "neon", "fluorescent", "glow", "glowing", "shiny", "matte", "glossy", "dull",
        "horizontal", "vertical", "diagonal", "parallel", "perpendicular", "straight", "curved",
        "symmetry", "asymmetric", "balance", "contrast", "brightness", "saturation", "hue",
        "pixel", "pixels", "resolution", "hd", "4k", "8k", "ultra", "hdr", "raw", "jpeg", "png",
        "vector", "bitmap", "raster", "render", "rendering", "filter", "filters", "effect", "effects",
        "blur", "sharp", "focus", "defocus", "depth", "perspective", "angle", "angles",
        "composition", "frame", "framing", "crop", "cropped", "zoom", "macro", "microscope"
    ]
    
    /// Returns true if the string is acceptable as a **brand** from Vision (after logo / text / label paths).
    static func isPlausibleBrandName(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        let key = trimmed.lowercased()
        let compact = key.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        if brandBlocklist.contains(key) { return false }
        if brandBlocklist.contains(compact) { return false }
        return true
    }

    // MARK: - Brand canonicalization

    /// Maps product lines / sub-brands to their parent brand so detection stays consistent.
    /// Example: an Apple logo that Vision surfaces as "iPhone" still resolves to "Apple".
    /// Keys are lowercased; multi-word keys are matched as substrings, single tokens as whole words.
    private static let brandCanonicalMap: [String: String] = [
        "iphone": "Apple",
        "ipad": "Apple",
        "ipod": "Apple",
        "imac": "Apple",
        "macbook": "Apple",
        "macbook air": "Apple",
        "macbook pro": "Apple",
        "airpods": "Apple",
        "apple watch": "Apple",
        "apple tv": "Apple",
        "samsung galaxy": "Samsung",
        "google pixel": "Google",
        "playstation": "Sony",
        "xbox": "Microsoft"
    ]

    /// Resolves a detected brand/product term to its canonical parent brand.
    /// Returns the trimmed original when no mapping applies, so non-Apple brands are untouched.
    static func canonicalBrandName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let key = trimmed.lowercased()
        if let mapped = brandCanonicalMap[key] { return mapped }

        // Multi-word product lines (e.g. "apple watch", "macbook pro") matched as substrings.
        for (term, parent) in brandCanonicalMap where term.contains(" ") {
            if key.contains(term) { return parent }
        }

        // Single-token product lines (e.g. "iphone 15 pro" -> "iphone" -> Apple) matched on word boundaries.
        let tokens = Set(key.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        for (term, parent) in brandCanonicalMap where !term.contains(" ") {
            if tokens.contains(term) { return parent }
        }

        return trimmed
    }
    
    // MARK: - Person (UI heuristics)
    
    /// Single capitalized words that Vision often returns; not person names.
    static let singleWordPersonBlocklist: Set<String> = brandBlocklist.union([
        "darkness", "silence", "happiness", "loneliness", "emptiness", "sunlight", "moonlight",
        "font", "white", "black", "night", "day", "morning", "evening", "midnight",
        "monochrome", "chrome", "color", "photo", "image", "picture", "video", "film",
        "north", "south", "east", "west", "left", "right", "center", "centre", "middle",
        "summer", "winter", "spring", "autumn", "fall", "rain", "snow", "wind", "storm",
        "love", "hope", "faith", "peace", "war", "life", "death", "birth", "age", "time",
        "man", "woman", "boy", "girl", "baby", "child", "kid", "teen", "adult", "senior",
        "human", "people", "person", "crowd", "group", "family", "team", "audience",
        "male", "female", "lady", "gentleman", "sir", "madam", "mr", "mrs", "ms", "dr"
    ])
    
    /// If true, do not treat `label` as a person name from Vision heuristics.
    static func shouldRejectAsPersonName(_ label: String) -> Bool {
        let lower = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return true }
        if singleWordPersonBlocklist.contains(lower) { return true }
        let compact = lower.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        if singleWordPersonBlocklist.contains(compact) { return true }
        return false
    }
    
    /// Drop generic Vision label strings so they are not stored as searchable labels (reduces Person/Text noise).
    static func shouldSuppressAsFreeformLabel(_ raw: String) -> Bool {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return true }
        if brandBlocklist.contains(lower) { return true }
        let compact = lower.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        if brandBlocklist.contains(compact) { return true }
        return false
    }
}
