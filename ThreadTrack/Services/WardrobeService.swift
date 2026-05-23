import Foundation
import SwiftData

/// Manages wardrobe CRUD operations and laundry tracking logic.
@Observable
final class WardrobeService {
    /// Add a new clothing item to the wardrobe.
    func addItem(_ item: ClothingItem, context: ModelContext) {
        context.insert(item)
    }

    /// Remove a clothing item from the wardrobe.
    func removeItem(_ item: ClothingItem, context: ModelContext) {
        context.delete(item)
    }

    /// Mark an item as worn — increments wear count and updates laundry status.
    func markAsWorn(_ item: ClothingItem, context: ModelContext) {
        item.wearCount += 1
        item.lastWornDate = Date()
        item.laundryDue = item.wearCount >= item.maxWearsBeforeLaundry
        item.updatedAt = Date()
    }

    /// Mark an item as clean (post-laundry).
    func markAsClean(_ item: ClothingItem, context: ModelContext) {
        item.wearCount = 0
        item.isDirty = false
        item.laundryDue = false
        item.updatedAt = Date()
    }

    /// Create a laundry batch with the given items.
    func createLaundryBatch(items: [ClothingItem], context: ModelContext) {
        let batch = LaundryBatch(items: items)
        context.insert(batch)

        for item in items {
            item.isDirty = false
            item.laundryDue = false
            item.updatedAt = Date()
        }
    }

    /// Complete a laundry batch — marks items as clean.
    func completeLaundryBatch(_ batch: LaundryBatch, context: ModelContext) {
        batch.completed = true
        for item in batch.items {
            markAsClean(item, context: context)
        }
    }

    /// Fetch all clothing items.
    func fetchAllItems(context: ModelContext) throws -> [ClothingItem] {
        let descriptor = FetchDescriptor<ClothingItem>(sortBy: [SortDescriptor(\.name)])
        return try context.fetch(descriptor)
    }

    /// Fetch items that are due for laundry.
    func fetchItemsDueForLaundry(context: ModelContext) throws -> [ClothingItem] {
        var descriptor = FetchDescriptor<ClothingItem>(
            predicate: #Predicate { $0.laundryDue == true },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        return try context.fetch(descriptor)
    }

    /// Fetch all laundry batches.
    func fetchLaundryBatches(context: ModelContext) throws -> [LaundryBatch] {
        let descriptor = FetchDescriptor<LaundryBatch>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try context.fetch(descriptor)
    }
}
