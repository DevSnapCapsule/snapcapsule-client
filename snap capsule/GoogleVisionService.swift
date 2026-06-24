import Foundation
import UIKit


// MARK: - Brand Detection Result
struct BrandDetectionResult {
    let brandName: String
    let confidence: Double
    let boundingBox: CGRect?

    init(brandName: String, confidence: Double, boundingBox: CGRect?) {
        // Canonicalize at the source so sub-brands/product lines (e.g. "iPhone") resolve to the
        // parent brand ("Apple") regardless of which Vision path produced them.
        self.brandName = VisionNoiseTerms.canonicalBrandName(brandName)
        self.confidence = confidence
        self.boundingBox = boundingBox
    }
}

struct VisionLocalizedObject {
    let name: String
    let confidence: Double
    /// Normalized CGRect in top-left coordinate space (0...1)
    let boundingBox: CGRect
}

// MARK: - Vision Service Error
enum VisionServiceError: Error {
    case invalidAPIKey
    case invalidImage
    case noData
    case apiError(String)
}

// MARK: - Google Vision Service
/// Calls the Vision API via a Cloud Function proxy so the API key never lives in the app.
class GoogleVisionService {
    static let shared = GoogleVisionService()
    
    /// Cloud Function URL that holds the Vision API key and forwards requests.
    private static let visionProxyURL = "https://vision-proxy-937348762913.europe-west1.run.app"
    
    private init() {}
    
    private func brandBoxArea(_ brand: BrandDetectionResult) -> Double {
        guard let box = brand.boundingBox else { return 1.0 }
        return max(0.000001, Double(box.width * box.height))
    }
    
    /// Prefer higher confidence, but for near-equal confidence choose tighter bounding boxes.
    private func shouldReplaceBrand(existing: BrandDetectionResult, candidate: BrandDetectionResult) -> Bool {
        if candidate.confidence > existing.confidence + 0.06 {
            return true
        }
        if existing.confidence > candidate.confidence + 0.06 {
            return false
        }
        
        let existingArea = brandBoxArea(existing)
        let candidateArea = brandBoxArea(candidate)
        
        // If confidence is close, pick the tighter and more precise region.
        if candidateArea < existingArea * 0.72 {
            return true
        }
        
        // Final tiebreaker: slight confidence edge.
        return candidate.confidence > existing.confidence
    }
    
    // MARK: - Detect Labels and Logos
    func detectLabelsAndLogos(in image: UIImage, completion: @escaping (Result<([BrandDetectionResult], [DetectedTag]), Error>) -> Void) {
        print("🔍 Starting Vision API call via Cloud Function proxy for labels and logos")
        print("💡 Using ephemeral session with Connection: close to avoid QUIC issues")
        print("💡 The retry mechanism will attempt to resolve temporary network issues")
        
        // Use the actual image but with proper resizing for network stability
        let resizedImage = resizeImageForNetwork(image)
        print("📐 Using resized image: \(resizedImage.size)")
        
        // Convert to base64 with more aggressive compression
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else {
            print("❌ Failed to convert image to JPEG")
            completion(.failure(VisionServiceError.invalidImage))
            return
        }
        
        let base64String = imageData.base64EncodedString()
        print("📊 Image data: \(imageData.count) bytes, Base64: \(base64String.count) chars")
        
        // Check if payload is too large
        if base64String.count > 1000000 { // 1MB limit (more aggressive)
            print("⚠️ Payload too large (\(base64String.count) chars), using more aggressive compression")
            guard let compressedData = resizedImage.jpegData(compressionQuality: 0.3) else {
                completion(.failure(VisionServiceError.invalidImage))
                return
            }
            let compressedBase64 = compressedData.base64EncodedString()
            print("📊 Compressed data: \(compressedData.count) bytes, Base64: \(compressedBase64.count) chars")
            // Use compressed version
            return makeAPICallForLabelsAndLogos(with: compressedBase64, imageSize: resizedImage.size, completion: completion)
        }
        
        // Make the API call
        makeAPICallForLabelsAndLogos(with: base64String, imageSize: resizedImage.size, completion: completion)
    }
    
    // MARK: - Curl-Compatible Logo Detection (backward compatibility)
    func detectLogos(in image: UIImage, completion: @escaping (Result<[BrandDetectionResult], Error>) -> Void) {
        detectLabelsAndLogos(in: image) { result in
            switch result {
            case .success(let (brands, _)):
                completion(.success(brands))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Helper Methods
    /// Builds the same Vision API request body as before (labels, logos, web, text) for full behavior.
    private func visionRequestBody(base64Image: String) -> [String: Any] {
        return [
            "requests": [
                [
                    "image": ["content": base64Image],
                    "features": [
                        ["type": "LOGO_DETECTION", "maxResults": 5],
                        ["type": "LABEL_DETECTION", "maxResults": 10],
                        ["type": "WEB_DETECTION", "maxResults": 3],
                        ["type": "TEXT_DETECTION", "maxResults": 10],
                        ["type": "OBJECT_LOCALIZATION", "maxResults": 15]
                    ]
                ]
            ]
        ]
    }

    func detectLocalizedObjects(in image: UIImage, completion: @escaping (Result<[VisionLocalizedObject], Error>) -> Void) {
        let resizedImage = resizeImageForNetwork(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else {
            completion(.failure(VisionServiceError.invalidImage))
            return
        }
        
        let base64String = imageData.base64EncodedString()
        guard let url = URL(string: Self.visionProxyURL) else {
            completion(.failure(VisionServiceError.apiError("Invalid proxy URL")))
            return
        }
        
        let requestBody = visionRequestBody(base64Image: base64String)
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Connection": "close",
            "Accept": "application/json"
        ]
        
        let session = URLSession(configuration: config)
        session.dataTask(with: urlRequest) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(VisionServiceError.noData))
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(VisionServiceError.noData))
                    return
                }
                if let proxyError = json["error"] as? String {
                    completion(.failure(VisionServiceError.apiError(proxyError)))
                    return
                }
                guard let responses = json["responses"] as? [[String: Any]],
                      let firstResponse = responses.first else {
                    completion(.success([]))
                    return
                }
                
                if let errorNode = firstResponse["error"] as? [String: Any] {
                    completion(.failure(VisionServiceError.apiError(errorNode["message"] as? String ?? "Unknown error")))
                    return
                }
                
                let objects = (firstResponse["localizedObjectAnnotations"] as? [[String: Any]] ?? []).compactMap { annotation -> VisionLocalizedObject? in
                    guard let name = annotation["name"] as? String,
                          let score = annotation["score"] as? Double,
                          let rect = self.parseNormalizedBoundingBox(from: annotation, imageSize: resizedImage.size) else {
                        return nil
                    }
                    return VisionLocalizedObject(name: name, confidence: score, boundingBox: rect)
                }
                completion(.success(objects.sorted { $0.confidence > $1.confidence }))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func detectTextMatchBounds(in image: UIImage, query: String, completion: @escaping (CGRect?) -> Void) {
        let resizedImage = resizeImageForNetwork(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else {
            completion(nil)
            return
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else {
            completion(nil)
            return
        }
        
        guard let url = URL(string: Self.visionProxyURL) else {
            completion(nil)
            return
        }
        
        let body = visionRequestBody(base64Image: imageData.base64EncodedString())
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(nil)
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.httpAdditionalHeaders = ["Content-Type": "application/json", "Connection": "close", "Accept": "application/json"]
        
        URLSession(configuration: config).dataTask(with: urlRequest) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responses = json["responses"] as? [[String: Any]],
                  let first = responses.first else {
                completion(nil)
                return
            }
            
            let textAnnotations = first["textAnnotations"] as? [[String: Any]] ?? []
            let candidates = self.collectTightTextAnnotationRects(
                textAnnotations,
                needle: needle,
                imageSize: resizedImage.size
            )
            
            if let best = candidates.min(by: { $0.1 < $1.1 }) {
                completion(best.0)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    /// Prefer word-level OCR boxes plus optional logo annotations; chooses the smallest matching region so highlights stay tight (brand names, captions).
    func detectTightBrandHighlight(in image: UIImage, brandName: String, completion: @escaping (CGRect?) -> Void) {
        let resizedImage = resizeImageForNetwork(image)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else {
            completion(nil)
            return
        }
        let trimmed = brandName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(nil)
            return
        }
        let needle = trimmed.lowercased()
        
        guard let url = URL(string: Self.visionProxyURL) else {
            completion(nil)
            return
        }
        
        let body = visionRequestBody(base64Image: imageData.base64EncodedString())
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(nil)
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.httpAdditionalHeaders = ["Content-Type": "application/json", "Connection": "close", "Accept": "application/json"]
        
        URLSession(configuration: config).dataTask(with: urlRequest) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responses = json["responses"] as? [[String: Any]],
                  let first = responses.first else {
                completion(nil)
                return
            }
            
            let textAnnotations = first["textAnnotations"] as? [[String: Any]] ?? []
            var candidates = self.collectTightTextAnnotationRects(
                textAnnotations,
                needle: needle,
                imageSize: resizedImage.size,
                foldedBrandQuery: trimmed
            )
            
            let logoAnnotations = first["logoAnnotations"] as? [[String: Any]] ?? []
            for annotation in logoAnnotations {
                guard let desc = annotation["description"] as? String,
                      self.normalizedBrandTokensMatch(description: desc, query: trimmed),
                      let rect = self.parseNormalizedBoundingBox(from: annotation, imageSize: resizedImage.size) else { continue }
                let area = Double(rect.width * rect.height)
                candidates.append((rect, area))
            }
            
            if let best = candidates.min(by: { $0.1 < $1.1 }) {
                completion(best.0)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func normalizedBrandFolded(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return t.applyingTransform(.stripDiacritics, reverse: false)?.replacingOccurrences(of: "\u{2014}", with: "-") ?? t
            .replacingOccurrences(of: " ", with: "")
    }
    
    private func normalizedBrandTokensMatch(description: String, query: String) -> Bool {
        let d = normalizedBrandFolded(description)
        let q = normalizedBrandFolded(query)
        guard !q.isEmpty, !d.isEmpty else { return false }
        return d == q || d.contains(q) || q.contains(d)
    }
    
    /// Text detection: prefer OCR tokens (`textAnnotations[1…]`), then fallback to larger blocks containing the needle.
    private func collectTightTextAnnotationRects(
        _ textAnnotations: [[String: Any]],
        needle: String,
        imageSize: CGSize,
        foldedBrandQuery: String? = nil
    ) -> [(CGRect, Double)] {
        guard !needle.isEmpty else { return [] }
        let foldedNeedle = foldedBrandQuery.map { normalizedBrandFolded($0) } ?? normalizedBrandFolded(needle)
        let detailAnnotations = Array(textAnnotations.dropFirst())
        let softMaxLen = max(needle.count + 14, min(needle.count * 4, 96))
        
        var candidates: [(CGRect, Double)] = []
        
        func appendMatch(annotation: [String: Any]) {
            guard let rect = parseNormalizedBoundingBox(from: annotation, imageSize: imageSize) else { return }
            let area = Double(rect.width * rect.height)
            guard area >= 4e-7 else { return }
            candidates.append((rect, area))
        }
        
        for annotation in detailAnnotations {
            guard let text = annotation["description"] as? String else { continue }
            let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !lowered.isEmpty else { continue }
            let foldedText = normalizedBrandFolded(text)
            let textMatches = lowered == needle
                || lowered.contains(needle)
                || needle.contains(lowered)
                || (!foldedNeedle.isEmpty && (foldedText == foldedNeedle || foldedText.contains(foldedNeedle) || foldedNeedle.contains(foldedText)))
            guard textMatches else { continue }
            guard lowered == needle || text.count <= softMaxLen else { continue }
            appendMatch(annotation: annotation)
        }
        
        if candidates.isEmpty {
            for annotation in textAnnotations {
                guard let text = annotation["description"] as? String else { continue }
                let lowered = text.lowercased()
                let foldedText = normalizedBrandFolded(text)
                let matchesBlob = lowered.contains(needle)
                    || (!foldedNeedle.isEmpty && (foldedText.contains(foldedNeedle) || foldedNeedle.contains(foldedText)))
                guard matchesBlob else { continue }
                appendMatch(annotation: annotation)
            }
        }
        
        return candidates
    }
    
    private func makeAPICallForLabelsAndLogos(with base64String: String, imageSize: CGSize, completion: @escaping (Result<([BrandDetectionResult], [DetectedTag]), Error>) -> Void) {
        guard let url = URL(string: Self.visionProxyURL) else {
            print("❌ Invalid Vision proxy URL")
            completion(.failure(VisionServiceError.apiError("Invalid proxy URL")))
            return
        }
        
        // Send full Vision request (same as before); proxy adds API key and forwards.
        let requestBody = visionRequestBody(base64Image: base64String)
        
        print("📋 Sending full Vision request (labels, logos, web, text) to proxy")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            urlRequest.httpBody = jsonData
            print("📋 JSON payload size: \(jsonData.count) bytes")
        } catch {
            print("❌ Failed to encode JSON request: \(error)")
            completion(.failure(error))
            return
        }
        
        print("🌐 Making API call to Vision proxy: \(url)")
        
        // Configure URLSession for stability
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.allowsCellularAccess = true
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Connection": "close",
            "Accept": "application/json"
        ]
        
        let session = URLSession(configuration: config)
        
        self.makeAPICallWithRetryForLabelsAndLogos(session: session, urlRequest: urlRequest, imageSize: imageSize, retryCount: 0, completion: completion)
    }
    
    private func makeAPICall(with base64String: String, completion: @escaping (Result<[BrandDetectionResult], Error>) -> Void) {
        guard let url = URL(string: Self.visionProxyURL) else {
            completion(.failure(VisionServiceError.apiError("Invalid proxy URL")))
            return
        }
        
        let requestBody = visionRequestBody(base64Image: base64String)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.httpAdditionalHeaders = ["Content-Type": "application/json", "Accept": "application/json"]
        
        let session = URLSession(configuration: config)
        self.makeAPICallWithRetry(session: session, urlRequest: urlRequest, retryCount: 0, completion: completion)
    }
    
    private func makeAPICallWithRetry(session: URLSession, urlRequest: URLRequest, retryCount: Int, completion: @escaping (Result<[BrandDetectionResult], Error>) -> Void) {
        // Make the API call with comprehensive logging
        session.dataTask(with: urlRequest) { data, response, error in
            // Log HTTP response details first
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
                print("📊 Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            if let error = error {
                print("❌ Network error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                
                // Check if it's a -1017 error and we can retry
                if (error as NSError).code == -1017 && retryCount < 2 {
                    print("🔄 -1017 error detected, retrying... (attempt \(retryCount + 1)/3)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.makeAPICallWithRetry(session: session, urlRequest: urlRequest, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                
                // If all retries failed with -1017, this is likely a simulator network issue
                if (error as NSError).code == -1017 && retryCount >= 2 {
                    print("🔄 All retries failed with -1017, this appears to be a simulator network issue")
                    print("💡 This is likely due to iOS Simulator QUIC/HTTP/3 limitations with Google Vision API")
                    print("💡 The HTTP/2 ephemeral session approach should resolve this on real devices")
                    completion(.success([])) // Return empty results gracefully
                    return
                }
                
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(VisionServiceError.noData))
                return
            }
            
            print("📊 Response data size: \(data.count) bytes")
            
            // Log raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📊 Raw API Response: \(responseString)")
                
                // Check if response is valid JSON
                if responseString.isEmpty {
                    print("❌ Empty response string")
                    completion(.failure(VisionServiceError.noData))
                    return
                }
                
                // Check for common error patterns
                if responseString.contains("error") {
                    print("⚠️ Response contains 'error' keyword")
                }
                if responseString.contains("quota") {
                    print("⚠️ Response contains 'quota' keyword - possible API quota exceeded")
                }
                if responseString.contains("billing") {
                    print("⚠️ Response contains 'billing' keyword - billing may not be enabled")
                }
            } else {
                print("❌ Failed to convert response data to string")
                completion(.failure(VisionServiceError.noData))
                return
            }
            
            // Parse JSON (proxy returns Vision API shape, or { error: "..." } on proxy failure)
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let proxyError = json["error"] as? String {
                        print("❌ Vision proxy error: \(proxyError)")
                        completion(.failure(VisionServiceError.apiError(proxyError)))
                        return
                    }
                    
                    if let responses = json["responses"] as? [[String: Any]],
                       let firstResponse = responses.first {
                        
                        if let error = firstResponse["error"] as? [String: Any] {
                            let errorMessage = error["message"] as? String ?? "Unknown error"
                            print("❌ API Error: \(errorMessage)")
                            completion(.failure(VisionServiceError.apiError(errorMessage)))
                            return
                        }
                        
                        // Parse all detection types for comprehensive results
                        var allBrands: [BrandDetectionResult] = []
                        
                        // 1. Logo Detection (primary)
                        if let logoAnnotations = firstResponse["logoAnnotations"] as? [[String: Any]] {
                            print("📊 Found \(logoAnnotations.count) logo annotations")
                            
                            let logoBrands = logoAnnotations.compactMap { annotation -> BrandDetectionResult? in
                                guard let description = annotation["description"] as? String,
                                      let score = annotation["score"] as? Double,
                                      score >= 0.52 else {
                                    return nil
                                }
                                
                                print("🏷️ Logo Brand: \(description) (confidence: \(Int(score * 100))%)")
                                
                                return BrandDetectionResult(
                                    brandName: description,
                                    confidence: score,
                                    boundingBox: nil
                                )
                            }
                            allBrands.append(contentsOf: logoBrands.filter { VisionNoiseTerms.isPlausibleBrandName($0.brandName) })
                        }
                        
                        // Web entities are excluded from brands — they are mostly colors, moods, and generic terms, not logos.
                        
                        // 3. Label Detection (for additional brand candidates)
                        if let labelAnnotations = firstResponse["labelAnnotations"] as? [[String: Any]] {
                            print("📊 Found \(labelAnnotations.count) label annotations")
                            
                            let labelBrands = labelAnnotations.compactMap { annotation -> BrandDetectionResult? in
                                guard let description = annotation["description"] as? String,
                                      let score = annotation["score"] as? Double,
                                      score >= 0.78 else {
                                    return nil
                                }
                                
                                // Treat short, capitalized labels as potential brands
                                // (e.g. "Nike", "Apple", "Adidas").
                                let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
                                let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
                                
                                guard words.count <= 3 else { return nil }
                                
                                // Require at least one word that looks like a proper noun
                                let hasProperNoun = words.contains { word in
                                    guard let first = word.first else { return false }
                                    return first.isUppercase && word.allSatisfy { $0.isLetter }
                                }
                                
                                guard hasProperNoun else { return nil }
                                guard VisionNoiseTerms.isPlausibleBrandName(trimmed) else { return nil }
                                
                                print("🏷️ Label Brand Candidate: \(description) (confidence: \(Int(score * 100))%)")
                                
                                return BrandDetectionResult(
                                    brandName: description,
                                    confidence: score,
                                    boundingBox: nil
                                )
                            }
                            allBrands.append(contentsOf: labelBrands)
                        }
                        
                        // 4. Text Detection (for brand names in text)
                        if let textAnnotations = firstResponse["textAnnotations"] as? [[String: Any]] {
                            print("📊 Found \(textAnnotations.count) text annotations")
                            
                            // Common product names to exclude from brand detection
                            let productNames = ["shirt", "shoes", "shoe", "bag", "handbag", "pants", "jacket", 
                                              "dress", "watch", "sunglasses", "hat", "jewelry", "top", "blouse"]
                            
                            let textBrands = textAnnotations.compactMap { annotation -> BrandDetectionResult? in
                                guard let description = annotation["description"] as? String,
                                      let score = annotation["score"] as? Double,
                                      score >= 0.74 else {
                                    return nil
                                }
                                
                                // Filter for potential brand names (capitalized, short)
                                let words = description.components(separatedBy: .whitespacesAndNewlines)
                                let potentialBrands = words.filter { word in
                                    let lowercased = word.lowercased()
                                    // Exclude product names
                                    guard !productNames.contains(lowercased) else { return false }
                                    
                                    return word.count > 2 && word.count < 20 && 
                                    word.first?.isUppercase == true &&
                                    word.allSatisfy { $0.isLetter }
                                }
                                
                                if !potentialBrands.isEmpty {
                                    let brandName = potentialBrands.first!
                                    guard VisionNoiseTerms.isPlausibleBrandName(brandName) else { return nil }
                                    print("📝 Text Brand: \(brandName) (confidence: \(Int(score * 100))%)")
                                    
                                    return BrandDetectionResult(
                                        brandName: brandName,
                                        confidence: score,
                                        boundingBox: nil
                                    )
                                }
                                return nil
                            }
                            allBrands.append(contentsOf: textBrands)
                        }
                        
                        let minimumBrandConfidence = 0.54
                        var brandByName: [String: BrandDetectionResult] = [:]
                        for brand in allBrands where VisionNoiseTerms.isPlausibleBrandName(brand.brandName) {
                            if let existing = brandByName[brand.brandName] {
                                if self.shouldReplaceBrand(existing: existing, candidate: brand) {
                                    brandByName[brand.brandName] = brand
                                }
                            } else {
                                brandByName[brand.brandName] = brand
                            }
                        }
                        let uniqueBrands = brandByName.values
                            .filter { $0.confidence >= minimumBrandConfidence }
                            .sorted { $0.confidence > $1.confidence }
                            .prefix(18)
                        
                        print("✅ Success: Found \(uniqueBrands.count) total brands from all detection methods")
                        completion(.success(Array(uniqueBrands)))
                    } else {
                        print("📊 No responses in API result")
                        completion(.success([]))
                    }
                } else {
                    print("❌ Failed to parse JSON response")
                    completion(.failure(VisionServiceError.noData))
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func makeAPICallWithRetryForLabelsAndLogos(session: URLSession, urlRequest: URLRequest, imageSize: CGSize, retryCount: Int, completion: @escaping (Result<([BrandDetectionResult], [DetectedTag]), Error>) -> Void) {
        // Make the API call with comprehensive logging
        session.dataTask(with: urlRequest) { data, response, error in
            // Log HTTP response details first
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
                print("📊 Response Headers: \(httpResponse.allHeaderFields)")
            }
            
            if let error = error {
                print("❌ Network error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                
                // Check if it's a -1017 error and we can retry
                if (error as NSError).code == -1017 && retryCount < 2 {
                    print("🔄 -1017 error detected, retrying... (attempt \(retryCount + 1)/3)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.makeAPICallWithRetryForLabelsAndLogos(session: session, urlRequest: urlRequest, imageSize: imageSize, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
                
                // If all retries failed with -1017, this is likely a simulator network issue
                if (error as NSError).code == -1017 && retryCount >= 2 {
                    print("🔄 All retries failed with -1017, this appears to be a simulator network issue")
                    print("💡 This is likely due to iOS Simulator QUIC/HTTP/3 limitations with Google Vision API")
                    print("💡 The HTTP/2 ephemeral session approach should resolve this on real devices")
                    completion(.success(([], []))) // Return empty results gracefully
                    return
                }
                
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(.failure(VisionServiceError.noData))
                return
            }
            
            print("📊 Response data size: \(data.count) bytes")
            
            // Parse JSON (proxy returns Vision API shape, or { error: "..." } on proxy failure)
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let proxyError = json["error"] as? String {
                        print("❌ Vision proxy error: \(proxyError)")
                        completion(.failure(VisionServiceError.apiError(proxyError)))
                        return
                    }
                    
                    if let responses = json["responses"] as? [[String: Any]],
                       let firstResponse = responses.first {
                        
                        if let error = firstResponse["error"] as? [String: Any] {
                            let errorMessage = error["message"] as? String ?? "Unknown error"
                            print("❌ API Error: \(errorMessage)")
                            completion(.failure(VisionServiceError.apiError(errorMessage)))
                            return
                        }
                        
                        // Parse all detection types (proxy may return only labelAnnotations)
                        var allBrands: [BrandDetectionResult] = []
                        var allLabels: [DetectedTag] = []
                        
                        // 1. Logo Detection (primary)
                        if let logoAnnotations = firstResponse["logoAnnotations"] as? [[String: Any]] {
                            print("📊 Found \(logoAnnotations.count) logo annotations")
                            
                            let logoBrands = logoAnnotations.compactMap { annotation -> BrandDetectionResult? in
                                guard let description = annotation["description"] as? String,
                                      let score = annotation["score"] as? Double,
                                      score >= 0.52 else {
                                    return nil
                                }
                                
                                print("🏷️ Logo Brand: \(description) (confidence: \(Int(score * 100))%)")
                                
                                return BrandDetectionResult(
                                    brandName: description,
                                    confidence: score,
                                    boundingBox: self.parseNormalizedBoundingBox(from: annotation, imageSize: imageSize)
                                )
                            }
                            allBrands.append(contentsOf: logoBrands.filter { VisionNoiseTerms.isPlausibleBrandName($0.brandName) })
                        }
                        
                        // Web entities are not used as brands (too many false positives).
                        
                        // 3. Label Detection — high-confidence only, capped count
                        if let labelAnnotations = firstResponse["labelAnnotations"] as? [[String: Any]] {
                            print("📊 Found \(labelAnnotations.count) label annotations")
                            
                            var labelBestByKey: [String: (original: String, score: Double)] = [:]
                            for annotation in labelAnnotations {
                                guard let description = annotation["description"] as? String,
                                      let score = annotation["score"] as? Double,
                                      score >= 0.78 else {
                                    continue
                                }
                                let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { continue }
                                let key = trimmed.lowercased()
                                if let existing = labelBestByKey[key] {
                                    if score > existing.score {
                                        labelBestByKey[key] = (trimmed, score)
                                    }
                                } else {
                                    labelBestByKey[key] = (trimmed, score)
                                }
                                print("🏷️ Label: \(trimmed) (confidence: \(Int(score * 100))%)")
                            }
                            let sortedLabels = labelBestByKey.values
                                .sorted { $0.score > $1.score }
                                .prefix(8)
                                .filter { !VisionNoiseTerms.shouldSuppressAsFreeformLabel($0.original) }
                                .map { DetectedTag(name: $0.original, confidence: $0.score) }
                            allLabels.append(contentsOf: sortedLabels)
                        }
                        
                        // 4. Text Detection (for brand names in text)
                        if let textAnnotations = firstResponse["textAnnotations"] as? [[String: Any]] {
                            print("📊 Found \(textAnnotations.count) text annotations")
                            
                            // Common product names to exclude from brand detection
                            let productNames = ["shirt", "shoes", "shoe", "bag", "handbag", "pants", "jacket", 
                                              "dress", "watch", "sunglasses", "hat", "jewelry", "top", "blouse"]
                            
                            let textBrands = textAnnotations.compactMap { annotation -> BrandDetectionResult? in
                                guard let description = annotation["description"] as? String,
                                      let score = annotation["score"] as? Double,
                                      score >= 0.74 else {
                                    return nil
                                }
                                
                                // Filter for potential brand names (capitalized, short)
                                let words = description.components(separatedBy: .whitespacesAndNewlines)
                                let potentialBrands = words.filter { word in
                                    let lowercased = word.lowercased()
                                    // Exclude product names
                                    guard !productNames.contains(lowercased) else { return false }
                                    
                                    return word.count > 2 && word.count < 20 && 
                                    word.first?.isUppercase == true &&
                                    word.allSatisfy { $0.isLetter }
                                }
                                
                                if !potentialBrands.isEmpty {
                                    let brandName = potentialBrands.first!
                                    guard VisionNoiseTerms.isPlausibleBrandName(brandName) else { return nil }
                                    print("📝 Text Brand: \(brandName) (confidence: \(Int(score * 100))%)")
                                    
                                    return BrandDetectionResult(
                                        brandName: brandName,
                                        confidence: score,
                                        boundingBox: self.parseNormalizedBoundingBox(from: annotation, imageSize: imageSize)
                                    )
                                }
                                return nil
                            }
                            allBrands.append(contentsOf: textBrands)
                        }
                        
                        // Merge brands by name (keep highest confidence), drop low-confidence noise
                        let minimumBrandConfidence = 0.54
                        var brandByName: [String: BrandDetectionResult] = [:]
                        for brand in allBrands where VisionNoiseTerms.isPlausibleBrandName(brand.brandName) {
                            if let existing = brandByName[brand.brandName] {
                                if self.shouldReplaceBrand(existing: existing, candidate: brand) {
                                    brandByName[brand.brandName] = brand
                                }
                            } else {
                                brandByName[brand.brandName] = brand
                            }
                        }
                        let uniqueBrands = brandByName.values
                            .filter { $0.confidence >= minimumBrandConfidence }
                            .sorted { $0.confidence > $1.confidence }
                            .prefix(18)
                        
                        let uniqueLabels = allLabels
                        
                        print("✅ Success: Found \(uniqueBrands.count) total brands and \(uniqueLabels.count) labels from all detection methods")
                        completion(.success((Array(uniqueBrands), uniqueLabels)))
                    } else {
                        print("📊 No responses in API result")
                        completion(.success(([], [])))
                    }
                } else {
                    print("❌ Failed to parse JSON response")
                    completion(.failure(VisionServiceError.noData))
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Ultra-Aggressive Image Resizing
    private func resizeImageUltraAggressively(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 400  // Ultra-small for network stability
        let originalSize = image.size
        
        print("🖼️ Ultra-resizing from: \(originalSize)")
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            // Landscape
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        print("📐 Ultra-calculated size: \(newSize)")
        
        // Ensure we don't upscale small images
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            print("✅ Image already small enough for ultra-compression")
            return image
        }
        
        // Create ultra-small resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.5)  // Lower scale for smaller size
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let finalImage = resizedImage ?? image
        print("✅ Ultra-final size: \(finalImage.size)")
        
        return finalImage
    }
    
    // MARK: - Micro-Image Fallback for -1017 Errors
    private func detectLogosWithMicroImage(_ image: UIImage, completion: @escaping (Result<[BrandDetectionResult], Error>) -> Void) {
        print("🔬 Using micro-image fallback for -1017 error")
        
        // Create micro-sized image (200px max)
        let microImage = createMicroImage(image)
        print("📐 Micro image size: \(microImage.size)")
        
        // Maximum compression
        guard let imageData = microImage.jpegData(compressionQuality: 0.2) else {
            print("❌ Failed to create micro image")
            completion(.failure(VisionServiceError.invalidImage))
            return
        }
        
        let base64String = imageData.base64EncodedString()
        print("📊 Micro data: \(imageData.count) bytes, Base64: \(base64String.count) chars")
        
        guard let url = URL(string: Self.visionProxyURL) else {
            completion(.failure(VisionServiceError.apiError("Invalid proxy URL")))
            return
        }
        
        let requestBody = visionRequestBody(base64Image: base64String)
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        do {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("🌐 Making micro API call via proxy (full features)...")
        
        // Use same HTTP/2 configuration for micro calls
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Connection": "close",
            "Accept": "application/json"
        ]
        
        let microParseSize = microImage.size
        let session = URLSession(configuration: config)
        session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("❌ Micro call also failed: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(VisionServiceError.noData))
                return
            }
            
            // Parse response (same logic as main function)
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responses = json["responses"] as? [[String: Any]],
                   let firstResponse = responses.first,
                   let logoAnnotations = firstResponse["logoAnnotations"] as? [[String: Any]] {
                    
                    let brands = logoAnnotations.compactMap { annotation -> BrandDetectionResult? in
                        guard let description = annotation["description"] as? String,
                              let score = annotation["score"] as? Double else { return nil }
                        return BrandDetectionResult(
                            brandName: description,
                            confidence: score,
                            boundingBox: self.parseNormalizedBoundingBox(from: annotation, imageSize: microParseSize)
                        )
                    }
                    
                    print("✅ Micro call succeeded: Found \(brands.count) brands")
                    completion(.success(brands))
                } else {
                    print("📊 Micro call: No logos found")
                    completion(.success([]))
                }
            } catch {
                print("❌ Micro call JSON error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func createMicroImage(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 200  // Micro size
        let originalSize = image.size
        let aspectRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.3)  // Very low scale
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let microImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return microImage ?? image
    }
    
    private func parseNormalizedBoundingBox(from annotation: [String: Any], imageSize: CGSize) -> CGRect? {
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }
        guard let poly = annotation["boundingPoly"] as? [String: Any] else { return nil }
        
        if let normalizedVertices = poly["normalizedVertices"] as? [[String: Any]], !normalizedVertices.isEmpty {
            let points = normalizedVertices.map {
                CGPoint(x: ($0["x"] as? Double) ?? 0.0, y: ($0["y"] as? Double) ?? 0.0)
            }
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
            let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            let clamped = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard clamped.width >= 0.001, clamped.height >= 0.001 else { return nil }
            return clamped
        }
        
        if let vertices = poly["vertices"] as? [[String: Any]], !vertices.isEmpty {
            let points = vertices.map {
                CGPoint(x: ($0["x"] as? Double) ?? 0.0, y: ($0["y"] as? Double) ?? 0.0)
            }
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
            let rect = CGRect(
                x: minX / imageSize.width,
                y: minY / imageSize.height,
                width: (maxX - minX) / imageSize.width,
                height: (maxY - minY) / imageSize.height
            )
            let clamped = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard clamped.width >= 0.001, clamped.height >= 0.001 else { return nil }
            return clamped
        }
        
        return nil
    }
    
    // MARK: - Image Resizing for Network Stability
    private func resizeImageForNetwork(_ image: UIImage) -> UIImage {
        let image = image.normalizedForImageProcessing()
        let maxDimension: CGFloat = 1000  // Increased for better logo detection (was 512)
        let originalSize = image.size
        
        print("🖼️ Resizing from: \(originalSize)")
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            // Landscape
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait or square
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        print("📐 Calculated size: \(newSize)")
        
        // Ensure we don't upscale small images
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            print("✅ Image already small enough")
            return image
        }
        
        // Create resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let finalImage = resizedImage ?? image
        print("✅ Final size: \(finalImage.size)")
        
        return finalImage
    }
}