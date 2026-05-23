import Foundation
import SwiftData

/// A daily outfit photo with references to the matched clothing items.
/// NOTE: Schema is preliminary — TT-T1 will refine based on architecture design.
@Model
final class DailyOutfit {
    var date: Date
    var photoData: Data?
    var items: [ClothingItem]
    var createdAt: Date

    init(
        date: Date = Date(),
        photoData: Data? = nil,
        items: [ClothingItem] = []
    ) {
        self.date = date
        self.photoData = photoData
        self.items = items
        self.createdAt = Date()
    }
}
