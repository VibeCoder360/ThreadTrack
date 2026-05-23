import Testing
@testable import ThreadTrack

struct ThreadTrackTests {

    @Test func clothingItemCreation() async throws {
        let item = ClothingItem(
            name: "Blue T-Shirt",
            category: .shirt,
            maxWearsBeforeLaundry: 3
        )
        #expect(item.name == "Blue T-Shirt")
        #expect(item.category == .shirt)
        #expect(item.wearCount == 0)
        #expect(item.laundryDue == false)
        #expect(item.isDirty == false)
    }

    @Test func clothingCategoryDisplayNames() async throws {
        for category in ClothingCategory.allCases {
            #expect(!category.displayName.isEmpty)
            #expect(!category.systemImage.isEmpty)
        }
    }

    @Test func clothingItemWearTracking() async throws {
        let item = ClothingItem(name: "Jeans", category: .pants, maxWearsBeforeLaundry: 3)

        // Simulate wearing 3 times
        item.wearCount = 3
        item.laundryDue = item.wearCount >= item.maxWearsBeforeLaundry

        #expect(item.laundryDue == true)
    }

    @Test func laundryBatchCreation() async throws {
        let shirt = ClothingItem(name: "Shirt", category: .shirt)
        let batch = LaundryBatch(items: [shirt])
        #expect(batch.items.count == 1)
        #expect(batch.completed == false)
    }
}
