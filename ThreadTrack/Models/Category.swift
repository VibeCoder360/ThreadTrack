import Foundation

// MARK: - Category Enum

/// All clothing categories supported by ThreadTrack.
enum ClothingCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case tops
    case bottoms
    case shoes
    case outerwear
    case accessories
    case underwear
    case socks

    var id: String { rawValue }

    /// User-facing display name.
    var displayName: String {
        switch self {
        case .tops:       return "Tops"
        case .bottoms:    return "Bottoms"
        case .shoes:      return "Shoes"
        case .outerwear:  return "Outerwear"
        case .accessories:return "Accessories"
        case .underwear:  return "Underwear"
        case .socks:      return "Socks"
        }
    }

    /// SF Symbol used as fallback when no photo is available.
    var systemImage: String {
        switch self {
        case .tops:       return "tshirt"
        case .bottoms:    return "trousers"
        case .shoes:      return "shoe.2"
        case .outerwear:  return "jacket"
        case .accessories:return "eyeglasses"
        case .underwear:  return "rectangle.roundedbottom"
        case .socks:      return "socks"
        }
    }

    /// Default wears-before-laundry for this category.
    var defaultLaundryThreshold: Int {
        switch self {
        case .tops:       return 3
        case .bottoms:    return 3
        case .shoes:      return 10
        case .outerwear:  return 5
        case .accessories:return 10
        case .underwear:  return 1
        case .socks:      return 1
        }
    }

    /// Accent color used in category pills and card borders.
    var accentColorHex: String {
        switch self {
        case .tops:       return "4A90D9"
        case .bottoms:    return "50C878"
        case .shoes:      return "D4A574"
        case .outerwear:  return "8B5CF6"
        case .accessories:return "F59E0B"
        case .underwear:  return "EC4899"
        case .socks:      return "06B6D4"
        }
    }
}
