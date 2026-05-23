import Foundation
import SwiftData

// MARK: - LaundryBatch

/// A record of one laundry cycle. Groups multiple ClothingItems that were washed together.
@Model
final class LaundryBatch {

    var id: UUID
    /// When the laundry was started (put in the wash).
    var startedAt: Date
    /// When the laundry was completed (removed from dryer / hung up). Nil if still in progress.
    var completedAt: Date?
    var notes: String?

    /// Items included in this batch.
    var items: [ClothingItem]

    init(
        startedAt: Date = Date(),
        items: [ClothingItem] = [],
        notes: String? = nil
    ) {
        self.id = UUID()
        self.startedAt = startedAt
        self.notes = notes
        self.items = items
    }

    /// Whether this batch is still in progress.
    var isInProgress: Bool {
        completedAt == nil
    }

    /// Total number of items in the batch.
    var itemCount: Int {
        items.count
    }

    /// Duration of the laundry cycle, or nil if not yet completed.
    var duration: TimeInterval? {
        guard let completedAt else { return nil }
        return completedAt.timeIntervalSince(startedAt)
    }

    /// Human-readable duration string.
    var durationString: String? {
        guard let duration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
