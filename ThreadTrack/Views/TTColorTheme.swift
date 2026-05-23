import SwiftUI

// MARK: - Color Theme (Dark Mode Support)
enum TTColorTheme {
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)

    static let text = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)

    static let accent = Color.blue
    static let green = Color.green
    static let yellow = Color.yellow
    static let red = Color.red
    static let orange = Color.orange

    static let laundryDue = Color.red
    static let laundryWarning = Color.orange
    static let laundryFresh = Color.green
    static let separator = Color(.separator)
}

// MARK: - Clothing Category
enum ClothingCategory: String, CaseIterable, Codable, Identifiable {
    case tops
    case bottoms
    case shoes
    case outerwear
    case accessories
    case underwear
    case socks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tops: return "Tops"
        case .bottoms: return "Bottoms"
        case .shoes: return "Shoes"
        case .outerwear: return "Outerwear"
        case .accessories: return "Accessories"
        case .underwear: return "Underwear"
        case .socks: return "Socks"
        }
    }

    var systemImage: String {
        switch self {
        case .tops: return "tshirt"
        case .bottoms: return "trousers"
        case .shoes: return "shoeprints.fill"
        case .outerwear: return "coat"
        case .accessories: return "watch"
        case .underwear: return "rectangle.roundedbottom"
        case .socks: return "socks"
        }
    }
}

// MARK: - Color Tag
enum ColorTag: String, CaseIterable, Codable, Identifiable {
    case black, white, gray, red, blue, green, yellow, orange,
         purple, pink, brown, beige, navy, teal

    var id: String { rawValue }

    var swiftUIColor: Color {
        switch self {
        case .black:  return .black
        case .white:  return .white
        case .gray:   return .gray
        case .red:    return .red
        case .blue:   return .blue
        case .green:  return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .pink:   return .pink
        case .brown:  return .brown
        case .beige:  return Color(red: 0.96, green: 0.90, blue: 0.80)
        case .navy:   return Color(red: 0.0, green: 0.0, blue: 0.5)
        case .teal:   return .teal
        }
    }
}

// MARK: - View Extensions
extension View {
    func ttCard() -> some View {
        self
            .padding()
            .background(TTColorTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    func ttSectionHeader(_ title: String) -> some View {
        self
            .font(.headline)
            .foregroundColor(TTColorTheme.secondaryText)
            .textCase(.uppercase)
    }
}
