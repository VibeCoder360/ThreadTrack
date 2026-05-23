import Foundation
import SwiftData

/// A single clothing item in the user's wardrobe.
/// NOTE: Schema is preliminary — TT-T1 will refine based on architecture design.
@Model
final class ClothingItem {
    var name: String
    var category: ClothingCategory
    var photoData: Data?
    var thumbnailData: Data?
    var colorHex: String?
    var wearCount: Int
    var maxWearsBeforeLaundry: Int
    var lastWornDate: Date?
    var laundryDue: Bool
    var isDirty: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        category: ClothingCategory = .other,
        photoData: Data? = nil,
        thumbnailData: Data? = nil,
        colorHex: String? = nil,
        wearCount: Int = 0,
        maxWearsBeforeLaundry: Int = 3,
        lastWornDate: Date? = nil,
        laundryDue: Bool = false,
        isDirty: Bool = false
    ) {
        self.name = name
        self.category = category
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.colorHex = colorHex
        self.wearCount = wearCount
        self.maxWearsBeforeLaundry = maxWearsBeforeLaundry
        self.lastWornDate = lastWornDate
        self.laundryDue = laundryDue
        self.isDirty = isDirty
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
