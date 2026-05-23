import Foundation
import SwiftData

/// A laundry batch — tracks when items were sent for washing.
/// NOTE: Schema is preliminary — TT-T1 will refine based on architecture design.
@Model
final class LaundryBatch {
    var date: Date
    var items: [ClothingItem]
    var completed: Bool
    var createdAt: Date

    init(
        date: Date = Date(),
        items: [ClothingItem] = [],
        completed: Bool = false
    ) {
        self.date = date
        self.items = items
        self.completed = completed
        self.createdAt = Date()
    }
}
