import Foundation
import SwiftData

// MARK: - ClothingItem

/// A single garment or accessory owned by the user.
@Model
final class ClothingItem {

    // ── Identity ──────────────────────────────────────────────
    var id: UUID
    var name: String
    var brand: String?
    var notes: String?

    // ── Classification ────────────────────────────────────────
    var categoryRaw: String          // ClothingCategory.rawValue
    var color: String?               // Free-form color label
    var tags: [String]               // User-defined tags

    // ── Photo ─────────────────────────────────────────────────
    /// Filename inside the app's documents /clothing-images/ directory.
    var photoFilename: String?

    // ── Laundry Tracking ──────────────────────────────────────
    /// How many times this item has been worn since last wash.
    var wearCount: Int
    /// Total lifetime wears (never reset).
    var lifetimeWears: Int
    /// User-configurable threshold. When wearCount >= this, item needs laundry.
    var laundryThreshold: Int
    /// True while the item is currently in the laundry basket / washing machine.
    var isDirty: Bool
    /// When the item was last marked as laundered (wearCount reset to 0).
    var lastWashedAt: Date?
    /// Date the item was added to the wardrobe.
    var createdAt: Date
    /// Date of last modification.
    var updatedAt: Date

    // ── Relationships ─────────────────────────────────────────
    @Relationship(deleteRule: .cascade, inverse: \DailyOutfit.items)
    var outfitEntries: [DailyOutfit]

    var category: ClothingCategory {
        get { ClothingCategory(rawValue: categoryRaw) ?? .tops }
        set { categoryRaw = newValue.rawValue }
    }

    /// Whether this item needs laundry (wear count reached threshold).
    var needsLaundry: Bool {
        wearCount >= laundryThreshold
    }

    /// Fraction of wears before laundry is needed (1.0 = clean, 0.0 = needs wash).
    var cleanlinessRatio: Double {
        guard laundryThreshold > 0 else { return 1.0 }
        let remaining = Double(laundryThreshold - wearCount)
        return max(0.0, min(1.0, remaining / Double(laundryThreshold)))
    }

    // MARK: - Init

    init(
        name: String,
        category: ClothingCategory,
        brand: String? = nil,
        color: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        photoFilename: String? = nil,
        laundryThreshold: Int? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.color = color
        self.notes = notes
        self.tags = tags
        self.photoFilename = photoFilename
        self.categoryRaw = category.rawValue
        self.wearCount = 0
        self.lifetimeWears = 0
        self.laundryThreshold = laundryThreshold ?? category.defaultLaundryThreshold
        self.isDirty = false
        self.lastWashedAt = nil
        self.createdAt = Date()
        self.updatedAt = Date()
        self.outfitEntries = []
    }
}
