import Foundation
import SwiftData

// MARK: - DailyOutfit

/// Represents what the user wore on a given day. Each outfit can reference multiple clothing items.
@Model
final class DailyOutfit {

    var id: UUID
    /// The calendar date this outfit was worn (midnight).
    var date: Date
    var notes: String?
    var createdAt: Date

    /// All clothing items worn as part of this outfit.
    var items: [ClothingItem]

    init(
        date: Date = Date(),
        items: [ClothingItem] = [],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.notes = notes
        self.createdAt = Date()
        self.items = items
    }

    /// Returns a comma-separated list of item names.
    var summary: String {
        items.map(\.name).joined(separator: ", ")
    }

    /// Returns unique categories represented in this outfit.
    var categories: [ClothingCategory] {
        Array(Set(items.map(\.category))).sorted { $0.rawValue < $1.rawValue }
    }
}
