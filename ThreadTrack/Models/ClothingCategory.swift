import Foundation
import SwiftData

/// Clothing categories supported by ThreadTrack.
enum ClothingCategory: String, Codable, CaseIterable, Identifiable {
    case shirt
    case pants
    case shoes
    case accessory
    case jacket
    case sweater
    case shorts
    case dress
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shirt: "Shirt"
        case .pants: "Pants"
        case .shoes: "Shoes"
        case .accessory: "Accessory"
        case .jacket: "Jacket"
        case .sweater: "Sweater"
        case .shorts: "Shorts"
        case .dress: "Dress"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .shirt: "tshirt"
        case .pants: "trousers"
        case .shoes: "shoe.2"
        case .accessory: "eyeglasses"
        case .jacket: "jacket"
        case .sweater: "hoodie"
        case .shorts: "shorts"
        case .dress: "dress"
        case .other: "questionmark.folder"
        }
    }
}
