import Foundation
import CoreData

class UserManager {
    static let shared = UserManager()
    
    private let persistentContainer: NSPersistentContainer
    @Published private(set) var currentUser: UserEntity?
    
    private init() {
        let container = NSPersistentContainer(name: "SnapCapsule")
        container.loadPersistentStores { description, error in
            if let error = error {
                // Avoid crashing the app; log the error instead.
                print("❌ Failed to load Core Data stack in UserManager: \(error)")
            }
        }
        persistentContainer = container
    }
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func loginUser(email: String, completion: @escaping (Bool, String?) -> Void) {
        let context = persistentContainer.viewContext
        
        // Check if user exists
        let fetchRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "email == %@", email)
        
        do {
            let existingUsers = try context.fetch(fetchRequest)
            
            if let existingUser = existingUsers.first {
                // User exists, set as current user
                currentUser = existingUser
                createDefaultAlbumsIfNeeded(for: existingUser, context: context)
                completion(true, nil)
            } else {
                // Create new user
                let newUser = UserEntity(context: context)
                newUser.id = UUID()
                newUser.email = email
                newUser.maxImagesPerAlbum = 10 // Default value
                
                // Create default albums
                createDefaultAlbums(for: newUser, context: context)
                
                do {
                    try context.save()
                    currentUser = newUser
                    completion(true, nil)
                } catch {
                    completion(false, "Failed to save user: \(error.localizedDescription)")
                }
            }
        } catch {
            completion(false, "Failed to fetch user: \(error.localizedDescription)")
        }
    }
    
    private func createDefaultAlbums(for user: UserEntity, context: NSManagedObjectContext) {
        // Create Capsule 1
        let album1 = AlbumEntity(context: context)
        album1.id = UUID()
        album1.name = "Capsule 1"
        album1.maxImages = user.maxImagesPerAlbum
        album1.user = user
        
        // Create Capsule 2
        let album2 = AlbumEntity(context: context)
        album2.id = UUID()
        album2.name = "Capsule 2"
        album2.maxImages = user.maxImagesPerAlbum
        album2.user = user
    }
    
    private func createDefaultAlbumsIfNeeded(for user: UserEntity, context: NSManagedObjectContext) {
        guard let albumsSet = user.albums as? Set<AlbumEntity> else { return }
        
        // 1) Normalize names: rename any legacy "Album 1/2" to "Capsule 1/2"
        for album in albumsSet {
            if album.name == "Album 1" {
                album.name = "Capsule 1"
            } else if album.name == "Album 2" {
                album.name = "Capsule 2"
            }
        }
        
        // Recompute after potential renames
        let albums = Array(albumsSet)
        let names = Set(albums.map { $0.name ?? "" })
        
        // 2) Ensure we have at least one Capsule 1 and one Capsule 2
        if !names.contains("Capsule 1") {
            let album1 = AlbumEntity(context: context)
            album1.id = UUID()
            album1.name = "Capsule 1"
            album1.maxImages = user.maxImagesPerAlbum
            album1.user = user
        }
        
        if !names.contains("Capsule 2") {
            let album2 = AlbumEntity(context: context)
            album2.id = UUID()
            album2.name = "Capsule 2"
            album2.maxImages = user.maxImagesPerAlbum
            album2.user = user
        }
        
        // 3) Deduplicate: if there are multiple Capsule 1 or Capsule 2 albums,
        // keep the one with the most images and delete the rest.
        func dedupeCapsule(named capsuleName: String) {
            let capsuleAlbums = (user.albums as? Set<AlbumEntity> ?? [])
                .filter { $0.name == capsuleName }
            
            guard capsuleAlbums.count > 1 else { return }
            
            // Sort by image count (descending) so we keep the most "real" one
            let sorted = capsuleAlbums.sorted { (a, b) in
                let countA = (a.images as? Set<ImageEntity>)?.count ?? 0
                let countB = (b.images as? Set<ImageEntity>)?.count ?? 0
                return countA > countB
            }
            
            // Keep the first, delete the rest
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
            }
        }
        
        dedupeCapsule(named: "Capsule 1")
        dedupeCapsule(named: "Capsule 2")
        
        try? context.save()
    }
    
    func getCurrentUser() -> UserEntity? {
        return currentUser
    }
    
    func updateMaxImagesPerAlbum(_ maxImages: Int32) {
        guard let user = currentUser else { return }
        let context = persistentContainer.viewContext
        
        user.maxImagesPerAlbum = maxImages
        
        // Update all albums
        if let albums = user.albums as? Set<AlbumEntity> {
            for album in albums {
                album.maxImages = maxImages
            }
        }
        
        try? context.save()
    }
}

