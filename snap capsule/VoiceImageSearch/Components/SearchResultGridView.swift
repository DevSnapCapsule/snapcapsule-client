import CoreData
import SwiftUI

struct SearchResultGridView: View {
    let imageObjectIDs: [NSManagedObjectID]

    @State private var selectedObjectID: NSManagedObjectID?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(imageObjectIDs, id: \.self) { objectID in
                if let image = resolveImageEntity(objectID) {
                    Button {
                        selectedObjectID = objectID
                    } label: {
                        SearchResultThumbnail(image: image)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: Binding(
            get: { selectedObjectID.map(VoiceSearchImageSheetItem.init) },
            set: { selectedObjectID = $0?.id }
        )) { item in
            VoiceSearchImageDetailHost(managedObjectID: item.id)
        }
    }

    private func resolveImageEntity(_ objectID: NSManagedObjectID) -> ImageEntity? {
        let context = UserManager.shared.viewContext
        do {
            let object = try context.existingObject(with: objectID)
            guard !object.isDeleted else { return nil }
            return object as? ImageEntity
        } catch {
            return nil
        }
    }
}

private struct SearchResultThumbnail: View {
    let image: ImageEntity

    var body: some View {
        Group {
            if let filePath = image.filePath,
               let uiImage = ImageStorageManager.shared.loadImage(from: filePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.45))
                    }
            }
        }
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct VoiceSearchImageSheetItem: Identifiable {
    let id: NSManagedObjectID
}

private struct VoiceSearchImageDetailHost: View {
    let managedObjectID: NSManagedObjectID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let entity = resolveImageEntity() {
                ImageDetailView(image: entity, onDelete: {
                    dismiss()
                })
            } else {
                NavigationStack {
                    ContentUnavailableView(
                        "Couldn't open photo",
                        systemImage: "exclamationmark.triangle",
                        description: Text("This image may no longer be available.")
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }
                }
            }
        }
    }

    private func resolveImageEntity() -> ImageEntity? {
        let context = UserManager.shared.viewContext
        do {
            let object = try context.existingObject(with: managedObjectID)
            guard !object.isDeleted else { return nil }
            return object as? ImageEntity
        } catch {
            return nil
        }
    }
}
