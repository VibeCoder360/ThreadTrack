import Foundation
import SwiftData

// MARK: - SampleDataSeeder

/// Generates realistic sample wardrobe data for onboarding demo.
/// Call once on first launch (check UserDefaults for "hasSeededSampleData").
enum SampleDataSeeder {

    private static let seededKey = "hasSeededSampleData"

    /// Whether sample data has already been seeded this install.
    static var hasSeeded: Bool {
        UserDefaults.standard.bool(forKey: seededKey)
    }

    /// Seed sample data into the given model context. Idempotent — skips if already seeded.
    /// Returns the number of items created.
    @discardableResult
    static func seed(in context: ModelContext) -> Int {
        guard !hasSeeded else { return 0 }

        var count = 0

        // ── Tops ────────────────────────────────────────────────
        count += create(context, name: "White Crew Neck Tee", category: .tops, brand: "Uniqlo", color: "White", tags: ["basics", "summer"])
        count += create(context, name: "Navy Polo", category: .tops, brand: "Ralph Lauren", color: "Navy", tags: ["smart casual"])
        count += create(context, name: "Oxford Button-Down", category: .tops, brand: "J.Crew", color: "Light Blue", tags: ["work", "smart casual"])
        count += create(context, name: "Black Henley", category: .tops, brand: "Everlane", color: "Black", tags: ["casual", "basics"])
        count += create(context, name: "Flannel Shirt", category: .tops, brand: "L.L.Bean", color: "Red Plaid", tags: ["winter", "casual"], wearCount: 2)
        count += create(context, name: "Graphic Tee", category: .tops, brand: "Threadless", color: "Gray", tags: ["casual"], wearCount: 3)  // dirty
        count += create(context, name: "Linen Shirt", category: .tops, brand: "MUJI", color: "Beige", tags: ["summer", "smart casual"], wearCount: 3)  // dirty

        // ── Bottoms ─────────────────────────────────────────────
        count += create(context, name: "Slim Chinos", category: .bottoms, brand: "Bonobos", color: "Khaki", tags: ["work", "smart casual"])
        count += create(context, name: "Dark Wash Jeans", category: .bottoms, brand: "Levi's", color: "Indigo", tags: ["casual", "basics"], wearCount: 2)
        count += create(context, name: "Black Joggers", category: .bottoms, brand: "Nike", color: "Black", tags: ["athleisure"], wearCount: 1)
        count += create(context, name: "Cargo Shorts", category: .bottoms, brand: "Patagonia", color: "Olive", tags: ["summer", "outdoor"])
        count += create(context, name: "Gray Dress Pants", category: .bottoms, brand: "Banana Republic", color: "Charcoal", tags: ["work"], wearCount: 3)  // dirty

        // ── Shoes ───────────────────────────────────────────────
        count += create(context, name: "White Sneakers", category: .shoes, brand: "Common Projects", color: "White", tags: ["basics", "smart casual"], laundryThreshold: 10)
        count += create(context, name: "Running Shoes", category: .shoes, brand: "Nike", color: "Black/White", tags: ["athletic"], laundryThreshold: 10)
        count += create(context, name: "Brown Loafers", category: .shoes, brand: "Clarks", color: "Brown", tags: ["work", "smart casual"], laundryThreshold: 10)
        count += create(context, name: "Chelsea Boots", category: .shoes, brand: "Dr. Martens", color: "Black", tags: ["winter", "smart casual"], laundryThreshold: 10, wearCount: 5)

        // ── Outerwear ───────────────────────────────────────────
        count += create(context, name: "Navy Pea Coat", category: .outerwear, brand: "Schott", color: "Navy", tags: ["winter", "formal"], laundryThreshold: 5)
        count += create(context, name: "Denim Jacket", category: .outerwear, brand: "Levi's", color: "Medium Wash", tags: ["spring", "casual"], laundryThreshold: 5, wearCount: 3)
        count += create(context, name: "Puffer Vest", category: .outerwear, brand: "Patagonia", color: "Black", tags: ["fall", "outdoor"], laundryThreshold: 5)
        count += create(context, name: "Rain Shell", category: .outerwear, brand: "Arc'teryx", color: "Green", tags: ["rain", "outdoor"], laundryThreshold: 5)

        // ── Accessories ─────────────────────────────────────────
        count += create(context, name: "Leather Belt", category: .accessories, brand: "Coach", color: "Brown", tags: ["basics"], laundryThreshold: 10)
        count += create(context, name: "Wool Beanie", category: .accessories, brand: "Carhartt", color: "Charcoal", tags: ["winter"], laundryThreshold: 10)
        count += create(context, name: "Aviator Sunglasses", category: .accessories, brand: "Ray-Ban", color: "Gold/Green", tags: ["summer", "basics"], laundryThreshold: 10)
        count += create(context, name: "Canvas Tote Bag", category: .accessories, brand: "Muji", color: "Natural", tags: ["casual", "errands"], laundryThreshold: 10)

        // ── Underwear ───────────────────────────────────────────
        for i in 1...5 {
            count += create(context, name: "Boxer Brief \(i)", category: .underwear, brand: "Calvin Klein", color: "Black", tags: ["basics"], laundryThreshold: 1, wearCount: i <= 3 ? 1 : 0)
        }

        // ── Socks ───────────────────────────────────────────────
        for i in 1...6 {
            count += create(context, name: "Crew Socks \(i)", category: .socks, brand: "Bombas", color: i % 2 == 0 ? "Black" : "White", tags: ["basics"], laundryThreshold: 1, wearCount: i <= 4 ? 1 : 0)
        }

        // ── Mark dirty items ────────────────────────────────────
        for item in context.registeredModels(of: ClothingItem.self) {
            if item.wearCount >= item.laundryThreshold {
                item.isDirty = true
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
        return count
    }

    /// Reset the seeded flag (for debugging / re-onboarding).
    static func resetSeedFlag() {
        UserDefaults.standard.set(false, forKey: seededKey)
    }

    // MARK: - Private

    @discardableResult
    private static func create(
        _ context: ModelContext,
        name: String,
        category: ClothingCategory,
        brand: String,
        color: String,
        tags: [String] = [],
        laundryThreshold: Int? = nil,
        wearCount: Int = 0
    ) -> Int {
        let item = ClothingItem(
            name: name,
            category: category,
            brand: brand,
            color: color,
            tags: tags,
            laundryThreshold: laundryThreshold ?? category.defaultLaundryThreshold
        )
        if wearCount > 0 {
            item.wearCount = wearCount
            item.lifetimeWears = wearCount * 2  // simulate some past washes
        }
        context.insert(item)
        return 1
    }
}
