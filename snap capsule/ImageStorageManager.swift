import Foundation
import UIKit

class ImageStorageManager {
    static let shared = ImageStorageManager()
    
    private let fileManager = FileManager.default
    private var imagesDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let imagesDir = appSupport.appendingPathComponent("Images", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: imagesDir.path) {
            try? fileManager.createDirectory(at: imagesDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return imagesDir
    }
    
    private init() {}
    
    func saveImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        // Downscale and compress image
        let compressedImage = compressAndDownscale(image)
        
        // Generate unique filename
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        
        // Save as JPEG with compression
        guard let imageData = compressedImage.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "ImageStorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])))
            return
        }
        
        do {
            try imageData.write(to: fileURL)
            // Return only the filename (relative path), not the absolute path
            // This ensures path changes don't break image loading
            completion(.success(filename))
        } catch {
            completion(.failure(error))
        }
    }
    
    func loadImage(from path: String) -> UIImage? {
        // Extract filename from path (handles both absolute paths and filenames)
        let filename: String
        if path.contains("/") {
            // If path contains "/", it's an absolute path - extract filename for backward compatibility
            filename = (path as NSString).lastPathComponent
        } else {
            // If no "/", it's already just a filename
            filename = path
        }
        
        // Always reconstruct the full path using current Application Support directory
        // This ensures path changes (e.g., after simulator restart) don't break image loading
        let fullPath = imagesDirectory.appendingPathComponent(filename).path
        
        // Load image from reconstructed path
        guard fileManager.fileExists(atPath: fullPath) else {
            return nil
        }
        
        return UIImage(contentsOfFile: fullPath)
    }
    
    func deleteImage(at path: String) {
        // Extract filename from path (handles both absolute paths and filenames)
        let filename: String
        if path.contains("/") {
            // If path contains "/", it's an absolute path - extract filename for backward compatibility
            filename = (path as NSString).lastPathComponent
        } else {
            // If no "/", it's already just a filename
            filename = path
        }
        
        // Reconstruct the full path using current Application Support directory
        let fullPath = imagesDirectory.appendingPathComponent(filename).path
        
        guard fileManager.fileExists(atPath: fullPath) else { return }
        try? fileManager.removeItem(atPath: fullPath)
    }
    
    private func compressAndDownscale(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1920 // Max dimension for storage
        let originalSize = image.size
        
        // Calculate new size maintaining aspect ratio
        let aspectRatio = originalSize.width / originalSize.height
        var newSize: CGSize
        
        if originalSize.width > originalSize.height {
            // Landscape
            if originalSize.width > maxDimension {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                return image
            }
        } else {
            // Portrait or square
            if originalSize.height > maxDimension {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            } else {
                return image
            }
        }
        
        // Create resized image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.8)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
}

