import Foundation
import CoreData
import UIKit

class AlbumManager {
    static let shared = AlbumManager()
    
    private init() {}
    
    var viewContext: NSManagedObjectContext {
        UserManager.shared.viewContext
    }
    
    func getAlbums(for user: UserEntity) -> [AlbumEntity] {
        guard let albums = user.albums as? Set<AlbumEntity> else { return [] }
        return Array(albums).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    func getAlbum(byId id: UUID) -> AlbumEntity? {
        let context = viewContext
        let fetchRequest: NSFetchRequest<AlbumEntity> = AlbumEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        return try? context.fetch(fetchRequest).first
    }
    
    func canAddImage(to album: AlbumEntity) -> Bool {
        guard let images = album.images as? Set<ImageEntity> else { return true }
        let currentCount = Int32(images.count)
        return currentCount < album.maxImages
    }
    
    func getImageCount(for album: AlbumEntity) -> Int {
        guard let images = album.images as? Set<ImageEntity> else { return 0 }
        return images.count
    }

    /// Capsule 1 first, then Capsule 2 — same routing as camera capture.
    func resolveTargetAlbum(for user: UserEntity) -> AlbumEntity? {
        let albums = getAlbums(for: user)
        guard !albums.isEmpty else { return nil }

        let album1 = albums.first { $0.name == "Capsule 1" }
        let album2 = albums.first { $0.name == "Capsule 2" }

        if let album1, canAddImage(to: album1) {
            return album1
        }
        if let album2, canAddImage(to: album2) {
            return album2
        }
        return nil
    }

    /// Saves to the next available capsule (camera or gallery import).
    func addImageToAvailableCapsule(
        image: UIImage,
        importSource: ImageImportSource = .camera,
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard let user = UserManager.shared.getCurrentUser() else {
            completion(false, "Please sign in to save photos.")
            return
        }

        guard let album = resolveTargetAlbum(for: user) else {
            completion(false, "Both capsules are full. Delete photos to make room for new imports.")
            return
        }

        addImage(to: album, image: image, importSource: importSource, completion: completion)
    }
    
    func addImage(
        to album: AlbumEntity,
        image: UIImage,
        importSource: ImageImportSource = .camera,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let context = viewContext
        
        // Check if album is full
        guard canAddImage(to: album) else {
            completion(false, "Album '\(album.name ?? "Unknown")' has reached the maximum limit of \(album.maxImages) images.")
            return
        }
        
        // Save image to file system
        ImageStorageManager.shared.saveImage(image) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case .success(let filePath):
                // Create image entity
                let imageEntity = ImageEntity(context: context)
                imageEntity.id = UUID()
                imageEntity.timestamp = Date()
                // Do not collect or store location data
                imageEntity.latitude = 0
                imageEntity.longitude = 0
                imageEntity.filePath = filePath
                imageEntity.isIndexed = false
                imageEntity.importSource = importSource.rawValue
                imageEntity.width = Int32(image.size.width)
                imageEntity.height = Int32(image.size.height)
                imageEntity.album = album
                
                do {
                    try context.save()
                    
                    // Queue for indexing
                    IndexingQueue.shared.addImage(imageEntity)
                    
                    completion(true, nil)
                } catch {
                    completion(false, "Failed to save image: \(error.localizedDescription)")
                }
                
            case .failure(let error):
                completion(false, "Failed to save image file: \(error.localizedDescription)")
            }
        }
    }
    
    func getImages(for album: AlbumEntity) -> [ImageEntity] {
        guard let images = album.images as? Set<ImageEntity> else { return [] }
        return Array(images).sorted { ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) }
    }
    
    func deleteImage(_ imageEntity: ImageEntity, completion: @escaping (Bool, String?) -> Void) {
        deleteImages([imageEntity], completion: completion)
    }
    
    /// Deletes multiple images in one save transaction.
    func deleteImages(_ imageEntities: [ImageEntity], completion: @escaping (Bool, String?) -> Void) {
        guard !imageEntities.isEmpty else {
            completion(true, nil)
            return
        }
        
        let context = viewContext
        
        for imageEntity in imageEntities {
            if let filePath = imageEntity.filePath {
                ImageStorageManager.shared.deleteImage(at: filePath)
            }
            context.delete(imageEntity)
        }
        
        do {
            try context.save()
            completion(true, nil)
        } catch {
            completion(false, "Failed to delete images: \(error.localizedDescription)")
        }
    }
    
    func deleteAllImages(from album: AlbumEntity, completion: @escaping (Bool, String?) -> Void) {
        let context = viewContext
        
        // Get all images in the album
        guard let images = album.images as? Set<ImageEntity> else {
            completion(true, nil)
            return
        }
        
        // Delete each image file from file system
        for imageEntity in images {
            if let filePath = imageEntity.filePath {
                ImageStorageManager.shared.deleteImage(at: filePath)
            }
        }
        
        // Delete all images from Core Data (cascade deletion will handle related entities like labels, brands, etc.)
        for imageEntity in images {
            context.delete(imageEntity)
        }
        
        do {
            try context.save()
            completion(true, nil)
        } catch {
            completion(false, "Failed to delete all images: \(error.localizedDescription)")
        }
    }
}
