import Foundation
import Vision
import CoreLocation
import UIKit

struct ImageMetadata {
    let imageId: UUID
    let timestamp: Date
    let location: CLLocation?
    let labels: [String]
    let colors: [String]
    let objects: [String]
    let scenes: [String]
    let faces: [String]
    let brands: [BrandDetectionResult]
    let searchableText: String
    let productInfo: ProductInfo
}

class ImageAnalyzer {
    static let shared = ImageAnalyzer()
    
    private init() {}
    
    func analyzeImage(_ image: UIImage, location: CLLocation?, completion: @escaping (ImageMetadata) -> Void) {
        guard let cgImage = image.cgImage else { return }
        
        // Resize image for optimal processing and API efficiency
        let optimizedImage = resizeImageForAnalysis(image)
        guard let optimizedCGImage = optimizedImage.cgImage else { return }
        
        var labels: Set<String> = []
        var objects: Set<String> = []
        var scenes: Set<String> = []
        var faces: Set<String> = []
        var colors: Set<String> = []
        var brands: [BrandDetectionResult] = []
        
        let group = DispatchGroup()
        
        // Detect objects and scenes
        group.enter()
        let classificationRequest = VNClassifyImageRequest { request, error in
            defer { group.leave() }
            guard let results = request.results as? [VNClassificationObservation] else { return }
            
            for result in results {
                if result.confidence > 0.5 {
                    if result.identifier.contains("scene") {
                        scenes.insert(result.identifier)
                    } else {
                        objects.insert(result.identifier)
                    }
                }
            }
        }
        
        // Detect faces
        group.enter()
        let faceRequest = VNDetectFaceRectanglesRequest { request, error in
            defer { group.leave() }
            guard let results = request.results as? [VNFaceObservation] else { return }
            
            faces.insert(results.isEmpty ? "no person" : "person")
        }
        
        // Detect text
        group.enter()
        let textRequest = VNRecognizeTextRequest { request, error in
            defer { group.leave() }
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }
            
            for result in results {
                if let text = result.topCandidates(1).first?.string {
                    labels.insert(text)
                }
            }
        }
        
        // Detect logos and labels using Google Cloud Vision API with optimized image
        group.enter()
        var visionLabels: [String] = []
        GoogleVisionService.shared.detectLabelsAndLogos(in: optimizedImage) { result in
            defer { group.leave() }
            switch result {
            case .success(let (detectedBrands, detectedLabels)):
                brands = detectedBrands
                visionLabels = detectedLabels
                // Add vision labels to the labels set
                for label in detectedLabels {
                    labels.insert(label)
                }
            case .failure(let error):
                // Handle logo detection error silently
                brands = []
                visionLabels = []
            }
        }
        
        // Analyze colors
        let dominantColors = analyzeDominantColors(in: image)
        colors = Set(dominantColors)
        
        let handler = VNImageRequestHandler(cgImage: optimizedCGImage, options: [:])
        try? handler.perform([classificationRequest, faceRequest, textRequest])
        
        group.notify(queue: .main) {
            // Combine all text for searching, including brand names
            let brandNames = brands.map { $0.brandName }
            let searchableText = (labels.union(objects).union(scenes).union(faces).union(colors).union(Set(brandNames)))
                .joined(separator: " ")
            
            // Extract product information (gender, brand, product type)
            // Use labels from both Vision framework and Google Vision API
            let allLabelsArray = Array(labels)
            let productInfo = ProductAnalyzer.shared.extractProductInfo(
                from: allLabelsArray,
                objects: Array(objects),
                brands: brands,
                faces: Array(faces)
            )
            
            print("🔍 Product Info extracted - Gender: \(productInfo.gender ?? "nil"), Brand: \(productInfo.brand ?? "nil"), Product: \(productInfo.product ?? "nil")")
            print("🔍 Labels available: \(allLabelsArray)")
            print("🔍 Brands available: \(brands.map { $0.brandName })")
            
            let metadata = ImageMetadata(
                imageId: UUID(),
                timestamp: Date(),
                location: location,
                labels: Array(labels),
                colors: Array(colors),
                objects: Array(objects),
                scenes: Array(scenes),
                faces: Array(faces),
                brands: brands,
                searchableText: searchableText,
                productInfo: productInfo
            )
            
            completion(metadata)
        }
    }
    
    private func analyzeDominantColors(in image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        
        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height
        
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
        let pointer = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        for i in stride(from: 0, to: totalPixels * 4, by: 4) {
            let red = Double(pointer[i]) / 255.0
            let green = Double(pointer[i + 1]) / 255.0
            let blue = Double(pointer[i + 2]) / 255.0
            
            let colorName = getColorName(red: red, green: green, blue: blue)
            colorCounts[colorName, default: 0] += 1
        }
        
        // Return top 5 dominant colors
        return Array(colorCounts.sorted { $0.value > $1.value }.prefix(5).map { $0.key })
    }
    
    private func getColorName(red: Double, green: Double, blue: Double) -> String {
        let colors: [(name: String, r: Double, g: Double, b: Double)] = [
            ("red", 1.0, 0.0, 0.0),
            ("green", 0.0, 1.0, 0.0),
            ("blue", 0.0, 0.0, 1.0),
            ("yellow", 1.0, 1.0, 0.0),
            ("purple", 0.5, 0.0, 0.5),
            ("orange", 1.0, 0.65, 0.0),
            ("pink", 1.0, 0.75, 0.8),
            ("brown", 0.65, 0.16, 0.16),
            ("black", 0.0, 0.0, 0.0),
            ("white", 1.0, 1.0, 1.0),
            ("gray", 0.5, 0.5, 0.5)
        ]
        
        var minDistance = Double.infinity
        var closestColor = "unknown"
        
        for color in colors {
            let distance = sqrt(
                pow(red - color.r, 2) +
                pow(green - color.g, 2) +
                pow(blue - color.b, 2)
            )
            
            if distance < minDistance {
                minDistance = distance
                closestColor = color.name
            }
        }
        
        return closestColor
    }
    
    // MARK: - Image Optimization for API Efficiency
    private func resizeImageForAnalysis(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1200  // Increased for better logo detection (was 800)
        let originalSize = image.size
        
        print("🖼️ Original image size: \(originalSize)")
        
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
        
        print("📐 Calculated new size: \(newSize)")
        
        // Ensure we don't upscale small images
        if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
            print("✅ Image already small enough, no resize needed")
            return image
        }
        
        // Create resized image with high quality
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let finalImage = resizedImage ?? image
        print("✅ Final resized image size: \(finalImage.size)")
        
        return finalImage
    }
} 