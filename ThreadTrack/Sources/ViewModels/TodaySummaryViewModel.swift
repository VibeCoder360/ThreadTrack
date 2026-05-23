import SwiftUI

// MARK: - Today Summary View Model

/// ViewModel for the daily outfit summary screen.
/// Displays what you're wearing today and how many wears are left before laundry.
@Observable
final class TodaySummaryViewModel {

    // MARK: - State

    private(set) var hasOutfitToday = false
    private(set) var outfitDate: Date?
    private(set) var outfitPhotoData: Data?
    private(set) var matchedItems: [ItemRow] = []
    private(set) var laundryAlertCount = 0
    private(set) var isLoading = false

    /// Filter state for the summary.
    var showOnlyLaundryDue = false

    // MARK: - Types

    struct ItemRow: Identifiable {
        let id: UUID
        let name: String
        let category: String
        let categoryIcon: String
        let wearCount: Int
        let maxWears: Int
        let wearsRemaining: Int
        let laundryDue: Bool
        let progress: Double  // 0.0 to 1.0

        /// Color based on urgency.
        var urgencyColor: Color {
            if laundryDue { return .red }
            if wearsRemaining <= 1 { return .orange }
            if wearsRemaining <= 2 { return .yellow }
            return .green
        }

        /// Display text for wears remaining.
        var wearsRemainingText: String {
            if laundryDue { return "Laundry due!" }
            if wearsRemaining == 1 { return "1 wear left" }
            return "\(wearsRemaining) wears left"
        }
    }

    // MARK: - Dependencies

    private let outfitService: DailyOutfitService

    // MARK: - Init

    init(outfitService: DailyOutfitService) {
        self.outfitService = outfitService
    }

    // MARK: - Actions

    /// Load today's outfit summary.
    @MainActor
    func load() {
        isLoading = true

        outfitService.loadTodaySummary()

        if let summary = outfitService.todayOutfit {
            hasOutfitToday = summary.hasOutfitToday
            outfitDate = summary.date
            outfitPhotoData = summary.outfitPhotoData
            matchedItems = summary.matchedItems.map { item in
                ItemRow(
                    id: item.id,
                    name: item.name,
                    category: item.category,
                    categoryIcon: categoryIcon(for: item.category),
                    wearCount: 0,  // Not available from summary directly
                    maxWears: 0,
                    wearsRemaining: item.wearsRemaining,
                    laundryDue: item.laundryDue,
                    progress: item.laundryDue ? 1.0 : Double(item.wearsRemaining) / 3.0
                )
            }
            laundryAlertCount = summary.matchedItems.filter(\.laundryDue).count
        } else {
            hasOutfitToday = false
            outfitDate = nil
            outfitPhotoData = nil
            matchedItems = []
            laundryAlertCount = 0
        }

        isLoading = false
    }

    /// Filtered items based on current filter state.
    var filteredItems: [ItemRow] {
        guard showOnlyLaundryDue else { return matchedItems }
        return matchedItems.filter(\.laundryDue)
    }

    // MARK: - Helpers

    /// Map clothing category to SF Symbol icon.
    private func categoryIcon(for category: String) -> String {
        switch category.lowercased() {
        case "tops", "shirt", "t-shirt", "sweater", "hoodie":
            return "shirt"
        case "bottoms", "pants", "jeans", "shorts", "skirt":
            return "trousers"
        case "shoes", "sneaker", "boot", "footwear":
            return "shoe.2"
        case "outerwear", "jacket", "coat", "blazer":
            return "jacket"
        case "accessories", "belt", "tie", "scarf", "hat":
            return "glasses"
        case "underwear":
            return "underwear"
        case "socks":
            return "socks"
        case "dress":
            return "figure.dress.line.vertical.figure"
        default:
            return "tag"
        }
    }

    /// Date formatter for the outfit date.
    var outfitDateString: String {
        guard let date = outfitDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
