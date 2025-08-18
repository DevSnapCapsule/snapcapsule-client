import Foundation
import CoreLocation

struct ImageSearchResult {
    let imageId: UUID
    let timestamp: Date
    let location: CLLocation
    let matchedText: String
} 