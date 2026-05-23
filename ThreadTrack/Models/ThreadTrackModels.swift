import SwiftUI
import SwiftData

// MARK: - ClothingItem (SwiftData Model)
@Model
final class ClothingItem {
    var id: UUID
    var name: String
    var category: ClothingCategory
    var colorTag: ColorTag
    var photoData: Data?
    var thumbnailData: Data?
    var wearCount: Int
    var maxWearsBeforeLaundry: Int
    var lastWornDate: Date?
    var isDirty: Bool
    var addedDate: Date

    var laundryDue: Bool {
        wearCount >= maxWearsBeforeLaundry
    }

    var wearsRemaining: Int {
        max(0, maxWearsBeforeLaundry - wearCount)
    }

    var laundryProgress: Double {
        min(1.0, Double(wearCount) / Double(max(1, maxWearsBeforeLaundry)))
    }

    init(
        name: String,
        category: ClothingCategory,
        colorTag: ColorTag = .black,
        photoData: Data? = nil,
        thumbnailData: Data? = nil,
        maxWearsBeforeLaundry: Int = 3
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.colorTag = colorTag
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.wearCount = 0
        self.maxWearsBeforeLaundry = maxWearsBeforeLaundry
        self.lastWornDate = nil
        self.isDirty = false
        self.addedDate = Date()
    }
}

// MARK: - DailyOutfit (SwiftData Model)
@Model
final class DailyOutfit {
    var id: UUID
    var date: Date
    var photoData: Data?
    var items: [ClothingItem]

    init(date: Date = Date(), photoData: Data? = nil, items: [ClothingItem] = []) {
        self.id = UUID()
        self.date = date
        self.photoData = photoData
        self.items = items
    }
}

// MARK: - LaundryBatch (SwiftData Model)
@Model
final class LaundryBatch {
    var id: UUID
    var date: Date
    var completedDate: Date?
    var items: [ClothingItem]

    var isCompleted: Bool {
        completedDate != nil
    }

    init(date: Date = Date(), items: [ClothingItem] = []) {
        self.id = UUID()
        self.date = date
        self.completedDate = nil
        self.items = items
    }
}
