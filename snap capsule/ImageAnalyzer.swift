import Foundation
import Vision
import UIKit

struct DetectedTag: Equatable {
    let name: String
    let confidence: Double
}

/// A dominant color with coverage-based confidence (fraction of pixels, 0...1).
struct ColorDetection: Equatable {
    let name: String
    let confidence: Double
}

struct ImageMetadata {
    let imageId: UUID
    let timestamp: Date
    let labels: [DetectedTag]
    let colors: [ColorDetection]
    let objects: [DetectedTag]
    let scenes: [DetectedTag]
    let faces: [DetectedTag]
    let brands: [BrandDetectionResult]
    let searchableText: String
    let productInfo: ProductInfo
}

class ImageAnalyzer {
    static let shared = ImageAnalyzer()
    
    /// Apple on-device image classification: minimum confidence to accept a tag.
    private static let classificationConfidenceThreshold: Float = 0.72
    /// OCR: minimum confidence per line (when available).
    private static let textRecognitionConfidenceThreshold: Float = 0.78
    
    /// Color must cover at least this fraction of pixels to be listed (achromatic).
    private static let minAchromaticCoverage = 0.055
    /// Chromatic colors need stronger evidence (avoids noise on dark / flat images).
    private static let minChromaticCoverage = 0.088
    /// At most this many distinct colors per image in metadata.
    private static let maxColorTags = 3
    
    private init() {}
    
    func analyzeImage(_ image: UIImage, completion: @escaping (ImageMetadata) -> Void) {
        let image = image.normalizedForImageProcessing()
        
        func makeFallbackMetadata() -> ImageMetadata {
            let emptyProductInfo = ProductAnalyzer.shared.extractProductInfo(
                from: [],
                objects: [],
                brands: [],
                faces: []
            )
            
            return ImageMetadata(
                imageId: UUID(),
                timestamp: Date(),
                labels: [],
                colors: [],
                objects: [],
                scenes: [],
                faces: [],
                brands: [],
                searchableText: "",
                productInfo: emptyProductInfo
            )
        }
        
        guard image.cgImage != nil else {
            completion(makeFallbackMetadata())
            return
        }
        
        let optimizedImage = resizeImageForAnalysis(image)
        guard let optimizedCGImage = optimizedImage.cgImage else {
            completion(makeFallbackMetadata())
            return
        }
        
        var labelsByKey: [String: DetectedTag] = [:]
        var objectsByKey: [String: DetectedTag] = [:]
        var scenesByKey: [String: DetectedTag] = [:]
        var facesByKey: [String: DetectedTag] = [:]
        var brands: [BrandDetectionResult] = []
        
        func normalizedKey(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        
        func upsert(_ tag: DetectedTag, into store: inout [String: DetectedTag]) {
            let trimmed = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let normalized = normalizedKey(trimmed)
            let sanitized = DetectedTag(name: trimmed, confidence: tag.confidence)
            if let existing = store[normalized] {
                if sanitized.confidence > existing.confidence {
                    store[normalized] = sanitized
                }
            } else {
                store[normalized] = sanitized
            }
        }
        
        let group = DispatchGroup()
        
        group.enter()
        let classificationRequest = VNClassifyImageRequest { request, error in
            defer { group.leave() }
            guard let results = request.results as? [VNClassificationObservation] else { return }
            
            let aboveThreshold = results
                .filter { $0.confidence >= Self.classificationConfidenceThreshold }
                .sorted { $0.confidence > $1.confidence }
            
            var objectCount = 0
            var sceneCount = 0
            let maxObjects = 5
            let maxScenes = 4
            
            for result in aboveThreshold {
                if result.identifier.contains("scene") {
                    guard sceneCount < maxScenes else { continue }
                    upsert(
                        DetectedTag(name: result.identifier, confidence: Double(result.confidence)),
                        into: &scenesByKey
                    )
                    sceneCount += 1
                } else {
                    guard objectCount < maxObjects else { continue }
                    upsert(
                        DetectedTag(name: result.identifier, confidence: Double(result.confidence)),
                        into: &objectsByKey
                    )
                    objectCount += 1
                }
            }
        }
        
        group.enter()
        let faceRequest = VNDetectFaceRectanglesRequest { request, error in
            defer { group.leave() }
            guard let results = request.results as? [VNFaceObservation] else { return }
            guard let strongestFace = results.max(by: { $0.confidence < $1.confidence }) else { return }
            upsert(
                DetectedTag(name: "Face", confidence: Double(strongestFace.confidence)),
                into: &facesByKey
            )
        }
        
        group.enter()
        let textRequest = VNRecognizeTextRequest { request, error in
            defer { group.leave() }
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }
            
            for result in results {
                if let candidate = result.topCandidates(1).first {
                    if candidate.confidence >= Self.textRecognitionConfidenceThreshold {
                        upsert(
                            DetectedTag(name: candidate.string, confidence: Double(candidate.confidence)),
                            into: &labelsByKey
                        )
                    }
                }
            }
        }
        
        group.enter()
        GoogleVisionService.shared.detectLabelsAndLogos(in: optimizedImage) { result in
            defer { group.leave() }
            switch result {
            case .success(let (detectedBrands, detectedLabels)):
                brands = detectedBrands
                for label in detectedLabels {
                    upsert(label, into: &labelsByKey)
                }
            case .failure:
                brands = []
            }
        }
        
        let dominantColors = analyzeDominantColors(in: image)
        
        let handler = VNImageRequestHandler(cgImage: optimizedCGImage, options: [:])
        try? handler.perform([classificationRequest, faceRequest, textRequest])
        
        group.notify(queue: .main) {
            let labels = labelsByKey.values.sorted { $0.confidence > $1.confidence }
            let objects = objectsByKey.values.sorted { $0.confidence > $1.confidence }
            let scenes = scenesByKey.values.sorted { $0.confidence > $1.confidence }
            let faces = facesByKey.values.sorted { $0.confidence > $1.confidence }
            let colorNames = Set(dominantColors.map(\.name))
            let brandNames = brands.map { $0.brandName }
            let searchableText = (
                Set(labels.map(\.name))
                    .union(Set(objects.map(\.name)))
                    .union(Set(scenes.map(\.name)))
                    .union(Set(faces.map(\.name)))
                    .union(colorNames)
                    .union(Set(brandNames))
            ).joined(separator: " ")
            
            let allLabelsArray = labels.map(\.name)
            let productInfo = ProductAnalyzer.shared.extractProductInfo(
                from: allLabelsArray,
                objects: objects.map(\.name),
                brands: brands,
                faces: faces.map(\.name)
            )
            
            let metadata = ImageMetadata(
                imageId: UUID(),
                timestamp: Date(),
                labels: labels,
                colors: dominantColors,
                objects: objects,
                scenes: scenes,
                faces: faces,
                brands: brands,
                searchableText: searchableText,
                productInfo: productInfo
            )
            
            completion(metadata)
        }
    }
    
    // MARK: - Dominant colors (coverage = confidence)
    
    private func analyzeDominantColors(in image: UIImage) -> [ColorDetection] {
        guard let cgImage = image.cgImage else { return [] }
        
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        guard totalPixels > 0 else { return [] }
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return [] }
        
        var colorCounts: [String: Int] = [:]
        var chromaticFlags: [String: Bool] = [:]
        
        let pointer = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        for i in stride(from: 0, to: totalPixels * 4, by: 4) {
            let r = Double(pointer[i]) / 255.0
            let g = Double(pointer[i + 1]) / 255.0
            let b = Double(pointer[i + 2]) / 255.0
            
            let (name, isChromatic) = classifyPixelColor(r: r, g: g, b: b)
            colorCounts[name, default: 0] += 1
            chromaticFlags[name] = isChromatic
        }
        
        let total = Double(totalPixels)
        var candidates: [(name: String, confidence: Double, isChromatic: Bool)] = []
        
        for (name, count) in colorCounts {
            let coverage = Double(count) / total
            let isChromatic = chromaticFlags[name] ?? false
            let minRequired = isChromatic ? Self.minChromaticCoverage : Self.minAchromaticCoverage
            guard coverage >= minRequired else { continue }
            candidates.append((name, coverage, isChromatic))
        }
        
        candidates.sort { $0.confidence > $1.confidence }
        
        return candidates.prefix(Self.maxColorTags).map {
            ColorDetection(name: $0.name, confidence: $0.confidence)
        }
    }
    
    /// Per-pixel label using luminance and saturation so dark / noisy frames map to black/gray, not random hues.
    private func classifyPixelColor(r: Double, g: Double, b: Double) -> (name: String, isChromatic: Bool) {
        let maxv = max(r, g, b)
        let minv = min(r, g, b)
        let delta = maxv - minv
        let saturation = maxv > 1e-4 ? delta / maxv : 0
        
        if maxv < 0.085 {
            return ("black", false)
        }
        
        if saturation < 0.10 {
            if maxv > 0.93 {
                return ("white", false)
            }
            return ("gray", false)
        }
        
        let hue = rgbToHueDegrees(r: r, g: g, b: b)
        
        if maxv < 0.22 && hue >= 15 && hue < 50 {
            return ("brown", true)
        }
        
        switch hue {
        case 0..<18, 345...360:
            return ("red", true)
        case 18..<45:
            return ("orange", true)
        case 45..<75:
            return ("yellow", true)
        case 75..<165:
            return ("green", true)
        case 165..<255:
            return ("blue", true)
        case 255..<290:
            return ("purple", true)
        case 290..<345:
            return ("pink", true)
        default:
            return ("red", true)
        }
    }
    
    /// HSV hue in 0...360 (simplified, for bucket naming only).
    private func rgbToHueDegrees(r: Double, g: Double, b: Double) -> Double {
        let maxc = max(r, g, b)
        let minc = min(r, g, b)
        let d = maxc - minc
        if d < 1e-6 { return 0 }
        let h: Double
        if maxc == r {
            h = 60 * (((g - b) / d).truncatingRemainder(dividingBy: 6))
        } else if maxc == g {
            h = 60 * (((b - r) / d) + 2)
        } else {
            h = 60 * (((r - g) / d) + 4)
        }
        return h < 0 ? h + 360 : h
    }
    
    // MARK: - Image Optimization for API Efficiency
    
    private func resizeImageForAnalysis(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1200
        let originalSize = image.size
        
        let aspectRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
}
