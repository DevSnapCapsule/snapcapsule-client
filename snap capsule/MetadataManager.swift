import CoreData
import Foundation

class MetadataManager {
    static let shared = MetadataManager()
    
    private let persistentContainer: NSPersistentContainer
    
    private init() {
        let container = NSPersistentContainer(name: "SnapCapsule")
        container.loadPersistentStores { description, error in
            if let error = error {
                // Avoid crashing the app; log the error instead.
                print("❌ Failed to load Core Data stack in MetadataManager: \(error)")
            }
        }
        persistentContainer = container
    }
    
    // MARK: - Save Operations
    
    func saveImageMetadata(_ metadata: ImageMetadata) {
        let context = persistentContainer.viewContext
        
        let imageEntity = ImageEntity(context: context)
        imageEntity.id = UUID()
        imageEntity.timestamp = metadata.timestamp
        // Do not collect or store location data
        imageEntity.latitude = 0
        imageEntity.longitude = 0
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
        
        // Save brands
        metadata.brands.forEach { brand in
            let brandEntity = BrandEntity(context: context)
            brandEntity.name = brand.brandName
            brandEntity.confidence = brand.confidence
            if let boundingBox = brand.boundingBox {
                brandEntity.boundingBoxX = boundingBox.origin.x
                brandEntity.boundingBoxY = boundingBox.origin.y
                brandEntity.boundingBoxWidth = boundingBox.size.width
                brandEntity.boundingBoxHeight = boundingBox.size.height
            }
            brandEntity.image = imageEntity
        }
        
        do {
            try context.save()
        } catch {
            print("Failed to save metadata: \(error)")
        }
    }
    
    // MARK: - Search Operations
    
    func searchImages(query: String) -> [ImageSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let context = persistentContainer.viewContext
        let fetchRequest = ImageEntity.fetchRequest()
        
        // Create compound predicate for searching across all metadata
        let searchPredicate = NSPredicate(format: "searchableText CONTAINS[cd] %@", trimmedQuery)
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
                    matchedText: searchableText
                )
            }
        } catch {
            print("Failed to fetch search results: \(error)")
            return []
        }
    }
}

