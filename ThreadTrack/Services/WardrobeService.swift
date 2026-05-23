import Foundation
import SwiftData
import PhotosUI
import UIKit

// MARK: - WardrobeService

/// Central service for all wardrobe CRUD operations and laundry management.
/// Designed to be injected via SwiftUI's @Environment or held as an ObservableObject.
@Observable
final class WardrobeService {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - CRUD: Create

    /// Add a new clothing item. If photoFilename is provided, the caller is
    /// responsible for copying the image to the documents directory first.
    @discardableResult
    func addItem(
        name: String,
        category: ClothingCategory,
        brand: String? = nil,
        color: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        photoFilename: String? = nil,
        laundryThreshold: Int? = nil
    ) -> ClothingItem {
        let item = ClothingItem(
            name: name,
            category: category,
            brand: brand,
            color: color,
            notes: notes,
            tags: tags,
            photoFilename: photoFilename,
            laundryThreshold: laundryThreshold
        )
        modelContext.insert(item)
        try? modelContext.save()
        return item
    }

    // MARK: - CRUD: Read

    /// Fetch all clothing items, optionally filtered by category.
    func fetchItems(category: ClothingCategory? = nil) -> [ClothingItem] {
        var descriptor = FetchDescriptor<ClothingItem>(
            sortBy: [SortDescriptor(\.name)]
        )
        if let category {
            #Predicate<ClothingItem> { $0.categoryRaw == category.rawValue }
            // SwiftData predicate filtering
            descriptor.predicate = #Predicate { $0.categoryRaw == category.rawValue }
        }
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch items that need laundry (wearCount >= threshold).
    func fetchDirtyItems() -> [ClothingItem] {
        let all = fetchItems()
        return all.filter(\.needsLaundry)
    }

    /// Fetch a single item by ID.
    func fetchItem(id: UUID) -> ClothingItem? {
        var descriptor = FetchDescriptor<ClothingItem>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    /// Search items by name, brand, or tags (case-insensitive).
    func searchItems(query: String) -> [ClothingItem] {
        let lowercased = query.lowercased()
        return fetchItems().filter { item in
            item.name.localizedCaseInsensitiveContains(lowercased)
            || (item.brand?.localizedCaseInsensitiveContains(lowercased) ?? false)
            || item.tags.contains { $0.localizedCaseInsensitiveContains(lowercased) }
        }
    }

    /// Count of items per category.
    func itemCountsByCategory() -> [ClothingCategory: Int] {
        var counts: [ClothingCategory: Int] = [:]
        for category in ClothingCategory.allCases {
            counts[category] = 0
        }
        for item in fetchItems() {
            counts[item.category, default: 0] += 1
        }
        return counts
    }

    // MARK: - CRUD: Update

    /// Update an existing item's editable fields.
    func updateItem(
        _ item: ClothingItem,
        name: String? = nil,
        category: ClothingCategory? = nil,
        brand: String? = nil,
        color: String? = nil,
        notes: String? = nil,
        tags: [String]? = nil,
        photoFilename: String? = nil,
        laundryThreshold: Int? = nil
    ) {
        if let name { item.name = name }
        if let category { item.category = category }
        if let brand { item.brand = brand }
        if let color { item.color = color }
        if let notes { item.notes = notes }
        if let tags { item.tags = tags }
        if let photoFilename { item.photoFilename = photoFilename }
        if let laundryThreshold { item.laundryThreshold = laundryThreshold }
        item.updatedAt = Date()
        try? modelContext.save()
    }

    /// Increment wear count. Call when the user logs wearing this item today.
    func recordWear(_ item: ClothingItem) {
        item.wearCount += 1
        item.lifetimeWears += 1
        item.isDirty = item.needsLaundry
        item.updatedAt = Date()
        try? modelContext.save()
    }

    /// Update an item's laundry threshold.
    func updateLaundryThreshold(_ item: ClothingItem, threshold: Int) {
        item.laundryThreshold = max(1, threshold)
        item.updatedAt = Date()
        try? modelContext.save()
    }

    // MARK: - CRUD: Delete

    /// Delete a clothing item and its associated photo file.
    func deleteItem(_ item: ClothingItem) {
        // Remove photo file if it exists
        if let filename = item.photoFilename {
            let url = ClothingImageStore.directory.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(item)
        try? modelContext.save()
    }

    /// Delete multiple items at once.
    func deleteItems(_ items: [ClothingItem]) {
        for item in items {
            if let filename = item.photoFilename {
                let url = ClothingImageStore.directory.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: url)
            }
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    // MARK: - Batch Laundry Operations

    /// Mark multiple items as laundered: reset wearCount, clear isDirty, record lastWashedAt.
    /// Optionally creates a LaundryBatch record.
    @discardableResult
    func markAsLaundered(
        items: [ClothingItem],
        notes: String? = nil,
        createBatch: Bool = true
    ) -> LaundryBatch? {
        for item in items {
            item.wearCount = 0
            item.isDirty = false
            item.lastWashedAt = Date()
            item.updatedAt = Date()
        }

        var batch: LaundryBatch?
        if createBatch && !items.isEmpty {
            batch = LaundryBatch(
                startedAt: Date(),
                items: items,
                notes: notes
            )
            modelContext.insert(batch!)
        }

        try? modelContext.save()
        return batch
    }

    /// Complete a laundry batch (mark as done).
    func completeLaundryBatch(_ batch: LaundryBatch) {
        batch.completedAt = Date()
        for item in batch.items {
            item.isDirty = false
            item.updatedAt = Date()
        }
        try? modelContext.save()
    }

    /// Fetch all laundry batches, newest first.
    func fetchLaundryBatches() -> [LaundryBatch] {
        var descriptor = FetchDescriptor<LaundryBatch>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Outfit Tracking

    /// Log a daily outfit for a given date.
    @discardableResult
    func logOutfit(
        date: Date = Date(),
        items: [ClothingItem],
        notes: String? = nil
    ) -> DailyOutfit {
        // Record a wear for each item in the outfit
        for item in items {
            recordWear(item)
        }
        let outfit = DailyOutfit(date: date, items: items, notes: notes)
        modelContext.insert(outfit)
        try? modelContext.save()
        return outfit
    }

    /// Fetch outfits, newest first.
    func fetchOutfits(limit: Int = 30) -> [DailyOutfit] {
        var descriptor = FetchDescriptor<DailyOutfit>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Get outfit for a specific date.
    func fetchOutfit(for date: Date) -> DailyOutfit? {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        var descriptor = FetchDescriptor<DailyOutfit>(
            predicate: #Predicate { $0.date >= dayStart && $0.date < dayEnd },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
