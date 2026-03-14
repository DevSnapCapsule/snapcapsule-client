import Foundation
import CoreData
import UIKit

class IndexingQueue: ObservableObject {
    static let shared = IndexingQueue()
    
    @Published var isIndexing = false
    @Published var indexingProgress: Double = 0.0
    @Published var currentIndexingImageId: UUID?
    
    private var queue: [ImageEntity] = []
    private var isProcessing = false
    
    private init() {}
    
    func addImage(_ imageEntity: ImageEntity) {
        // Only add if not already indexed
        guard !imageEntity.isIndexed else { return }
        
        queue.append(imageEntity)
        processQueue()
    }
    
    private func processQueue() {
        guard !isProcessing else { return }
        guard !queue.isEmpty else {
            DispatchQueue.main.async {
                self.isIndexing = false
                self.indexingProgress = 0.0
                self.currentIndexingImageId = nil
            }
            return
        }
        
        isProcessing = true
        DispatchQueue.main.async {
            self.isIndexing = true
        }
        
        let imageEntity = queue.removeFirst()
        
        DispatchQueue.main.async {
            self.currentIndexingImageId = imageEntity.id
            self.indexingProgress = 0.1
        }
        
        // Load image from file system
        guard let filePath = imageEntity.filePath,
              let image = ImageStorageManager.shared.loadImage(from: filePath) else {
            print("❌ Failed to load image for indexing: \(imageEntity.id?.uuidString ?? "unknown")")
            isProcessing = false
            processQueue()
            return
        }
        
        DispatchQueue.main.async {
            self.indexingProgress = 0.3
        }
        
        // Analyze image
        ImageAnalyzer.shared.analyzeImage(image) { [weak self] metadata in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.indexingProgress = 0.7
            }
            
            // Save metadata to Core Data
            let context = UserManager.shared.viewContext
            
            // Find the image entity
            guard let imageId = imageEntity.id else {
                self.isProcessing = false
                self.processQueue()
                return
            }
            
            let fetchRequest: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", imageId as CVarArg)
            
            guard let savedImageEntity = try? context.fetch(fetchRequest).first else {
                self.isProcessing = false
                self.processQueue()
                return
            }
            
            // Update image entity with metadata
            savedImageEntity.searchableText = metadata.searchableText
            savedImageEntity.isIndexed = true
            
            // Save labels
            metadata.labels.forEach { label in
                let labelEntity = LabelEntity(context: context)
                labelEntity.name = label
                labelEntity.image = savedImageEntity
            }
            
            // Save colors
            metadata.colors.forEach { color in
                let colorEntity = ColorEntity(context: context)
                colorEntity.name = color
                colorEntity.image = savedImageEntity
            }
            
            // Save objects
            metadata.objects.forEach { object in
                let objectEntity = ObjectEntity(context: context)
                objectEntity.name = object
                objectEntity.image = savedImageEntity
            }
            
            // Save scenes
            metadata.scenes.forEach { scene in
                let sceneEntity = SceneEntity(context: context)
                sceneEntity.name = scene
                sceneEntity.image = savedImageEntity
            }
            
            // Save faces
            metadata.faces.forEach { face in
                let faceEntity = FaceEntity(context: context)
                faceEntity.faceType = face
                faceEntity.image = savedImageEntity
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
                brandEntity.image = savedImageEntity
            }
            
            do {
                try context.save()
                print("✅ Image indexed successfully: \(imageId.uuidString)")
                
                DispatchQueue.main.async {
                    self.indexingProgress = 1.0
                }
                
                // Small delay before processing next
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isProcessing = false
                    self.processQueue()
                }
            } catch {
                print("❌ Failed to save indexed metadata: \(error)")
                self.isProcessing = false
                self.processQueue()
            }
        }
    }
}

