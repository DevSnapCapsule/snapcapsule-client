import CoreData
import CoreLocation
import Foundation

class MetadataManager {
    static let shared = MetadataManager()
    
    private let persistentContainer: NSPersistentContainer
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "SnapCapsule")
        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }
    }
    
    // MARK: - Save Operations
    
    func saveImageMetadata(_ metadata: ImageMetadata) {
        let context = persistentContainer.viewContext
        
        let imageEntity = ImageEntity(context: context)
        imageEntity.id = UUID()
        imageEntity.timestamp = metadata.timestamp
        imageEntity.latitude = metadata.location?.coordinate.latitude ?? 0
        imageEntity.longitude = metadata.location?.coordinate.longitude ?? 0
        imageEntity.searchableText = metadata.searchableText
        
        // Save labels
        metadata.labels.forEach { label in
            let labelEntity = LabelEntity(context: context)
            labelEntity.name = label
            labelEntity.image = imageEntity
        }
        
        // Save colors
        metadata.colors.forEach { color in
            let colorEntity = ColorEntity(context: context)
            colorEntity.name = color
            colorEntity.image = imageEntity
        }
        
        // Save objects
        metadata.objects.forEach { object in
            let objectEntity = ObjectEntity(context: context)
            objectEntity.name = object
            objectEntity.image = imageEntity
        }
        
        // Save scenes
        metadata.scenes.forEach { scene in
            let sceneEntity = SceneEntity(context: context)
            sceneEntity.name = scene
            sceneEntity.image = imageEntity
        }
        
        // Save faces
        metadata.faces.forEach { face in
            let faceEntity = FaceEntity(context: context)
            faceEntity.faceType = face
            faceEntity.image = imageEntity
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save metadata: \(error)")
        }
    }
    
    // MARK: - Search Operations
    
    func searchImages(query: String) -> [ImageSearchResult] {
        let context = persistentContainer.viewContext
        let fetchRequest = ImageEntity.fetchRequest()
        
        // Create compound predicate for searching across all metadata
        let searchPredicate = NSPredicate(format: "searchableText CONTAINS[cd] %@", query)
        fetchRequest.predicate = searchPredicate
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.compactMap { entity -> ImageSearchResult? in
                guard let id = entity.id,
                      let timestamp = entity.timestamp,
                      let searchableText = entity.searchableText else {
                    return nil
                }
                
                return ImageSearchResult(
                    imageId: id,
                    timestamp: timestamp,
                    location: CLLocation(
                        latitude: entity.latitude,
                        longitude: entity.longitude
                    ),
                    matchedText: searchableText
                )
            }
        } catch {
            print("Failed to fetch search results: \(error)")
            return []
        }
    }
}

