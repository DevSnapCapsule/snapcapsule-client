import CoreData
import SwiftUI

/// How an image entered the app. Stored on `ImageEntity.importSource`.
enum ImageImportSource: String, Sendable {
    case camera = "camera"
    case gallery = "gallery"
}

extension ImageEntity {
    var resolvedImportSource: ImageImportSource {
        ImageImportSource(rawValue: importSource ?? ImageImportSource.camera.rawValue) ?? .camera
    }

    var isFromGallery: Bool {
        resolvedImportSource == .gallery
    }
}

/// Small pill shown on gallery-imported photos in grid and detail views.
struct GallerySourceBadge: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 2 : 3) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: compact ? 8 : 9, weight: .semibold))
            if !compact {
                Text("Gallery")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 5 : 6)
        .padding(.vertical, compact ? 2 : 3)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.92), Color.blue.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
        .accessibilityLabel("Imported from photo library")
    }
}
