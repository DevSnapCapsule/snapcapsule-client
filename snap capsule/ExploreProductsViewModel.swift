import CoreData
import Foundation

@MainActor
final class ExploreProductsViewModel: ObservableObject {
    @Published private(set) var queries: [GeneratedProductQuery] = []
    @Published private(set) var isLoading = false
    @Published private(set) var subtitle: String = ""
    @Published private(set) var didUseWeakFallback = false
    
    private let image: ImageEntity
    
    init(image: ImageEntity) {
        self.image = image
    }
    
    func load() {
        guard !isLoading else { return }
        isLoading = true
        
        let snapshot = ProductExploreMetadataBuilder.build(from: image)
        let generated = ProductQueryGenerator.generate(from: snapshot)
        
        queries = generated
        didUseWeakFallback = generated.allSatisfy { $0.confidence == .low }
        subtitle = makeSubtitle(snapshot: snapshot, queryCount: generated.count)
        isLoading = false
    }
    
    private func makeSubtitle(snapshot: ProductExploreSnapshot, queryCount: Int) -> String {
        if queryCount == 0 {
            return "Add or index photos with AI tags to discover product ideas."
        }
        if let brand = snapshot.primaryBrand {
            return "Suggestions based on \(brand) and on-device metadata — nothing leaves your device."
        }
        return "Suggestions from on-device metadata only — private and local."
    }
}
