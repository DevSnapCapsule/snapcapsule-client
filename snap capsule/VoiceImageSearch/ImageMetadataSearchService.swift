import CoreData
import Foundation

/// Executes local Core Data searches against indexed `searchableText` metadata.
struct ImageMetadataSearchService {
    private let viewContext: NSManagedObjectContext

    init(viewContext: NSManagedObjectContext = UserManager.shared.viewContext) {
        self.viewContext = viewContext
    }

    func search(with intent: SearchIntent) throws -> [ImageEntity] {
        var terms = intent.searchableTerms

        let queryWords = intent.searchQuery
            .split(whereSeparator: { $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

        var seen = Set(terms.map { $0.lowercased() })
        for word in queryWords {
            let key = word.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                terms.append(word)
            }
        }

        guard !terms.isEmpty else { return [] }

        guard
            let user = UserManager.shared.getCurrentUser(),
            let userAlbums = user.albums as? Set<AlbumEntity>
        else {
            return []
        }

        let albumIds = userAlbums.compactMap(\.id)
        guard !albumIds.isEmpty else { return [] }

        let fetchRequest: NSFetchRequest<ImageEntity> = ImageEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        fetchRequest.fetchBatchSize = 48

        let albumPredicate = NSPredicate(format: "album.id IN %@", albumIds)
        let indexedPredicate = NSPredicate(format: "isIndexed == YES")
        let textPredicates = terms.map { term in
            NSPredicate(format: "searchableText CONTAINS[cd] %@", term)
        }
        let searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: textPredicates)

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            albumPredicate,
            indexedPredicate,
            searchPredicate
        ])

        return try viewContext.fetch(fetchRequest)
    }
}
