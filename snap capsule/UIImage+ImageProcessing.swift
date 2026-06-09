import UIKit

extension UIImage {
    /// Bitmap with `.up` orientation so `cgImage`, `jpegData`, and Vision match what the user sees.
    /// Fixes logo/OCR failures when the camera stores rotation as EXIF instead of baking pixels (common in landscape).
    func normalizedForImageProcessing() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
