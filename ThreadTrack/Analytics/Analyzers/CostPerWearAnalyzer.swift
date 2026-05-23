// CostPerWearAnalyzer.swift
// ThreadTrack — Analytics Engine

import Foundation

/// Calculates cost-per-wear for every item that has a price set.
/// Items without a price are excluded from results but reported in `unpricedCount`.
public struct CostPerWearAnalyzer: Sendable {

    // MARK: - Output

    public struct Result: Sendable {
        public let entries: [CostPerWearEntry]
        /// Items that have a price but 0 wears (infinite cost-per-wear).
        public let neverWorn: [CostPerWearEntry]
        /// Best investment — lowest cost-per-wear among worn items.
        public let bestValue: CostPerWearEntry?
        /// Worst investment — highest cost-per-wear.
        public let worstValue: CostPerWearEntry?
        /// Items without a price set.
        public let unpricedCount: Int
        /// Total wardrobe investment.
        public let totalSpent: Double
        /// Weighted average cost-per-wear across all priced items.
        public let avgCostPerWear: Double?

        public init(entries: [CostPerWearEntry], neverWorn: [CostPerWearEntry],
                    bestValue: CostPerWearEntry?, worstValue: CostPerWearEntry?,
                    unpricedCount: Int, totalSpent: Double,
                    avgCostPerWear: Double?) {
            self.entries = entries; self.neverWorn = neverWorn
            self.bestValue = bestValue; self.worstValue = worstValue
            self.unpricedCount = unpricedCount; self.totalSpent = totalSpent
            self.avgCostPerWear = avgCostPerWear
        }
    }

    // MARK: - Analysis

    public init() {}

    /// Runs cost-per-wear over all items.  O(n) where n = item count.
    public func analyze(
        items: [any ClothingItemRepresentable],
        period: AnalyticsPeriod = .allTime
    ) -> Result {
        let cutoff = period.cutoffDate

        let priced = items.filter { $0.price != nil && $0.price! > 0 }
        let unpricedCount = items.count - priced.count

        var entries: [CostPerWearEntry] = []
        var neverWorn: [CostPerWearEntry] = []
        var totalSpent: Double = 0

        for item in priced {
            guard let price = item.price else { continue }
            totalSpent += price

            // Count wears within the period window.
            let wearsInPeriod = item.wearDates.filter { $0 >= cutoff }.count
            let cpw = wearsInPeriod > 0 ? price / Double(wearsInPeriod) : .infinity

            let entry = CostPerWearEntry(
                id: item.id, name: item.name, category: item.category,
                price: price, wearCount: wearsInPeriod, costPerWear: cpw
            )

            if wearsInPeriod == 0 {
                neverWorn.append(entry)
            } else {
                entries.append(entry)
            }
        }

        entries.sort { $0.costPerWear < $1.costPerWear }
        neverWorn.sort { $0.price > $1.price }

        let totalWears = entries.reduce(0) { $0 + $1.wearCount }
        let avgCPW = totalWears > 0
            ? entries.reduce(0.0) { $0 + ($1.price / Double($1.wearCount)) } / Double(entries.count)
            : nil

        return Result(
            entries: entries,
            neverWorn: neverWorn,
            bestValue: entries.first,
            worstValue: entries.last,
            unpricedCount: unpricedCount,
            totalSpent: totalSpent,
            avgCostPerWear: avgCPW
        )
    }
}

// MARK: - Period helper

private extension AnalyticsPeriod {
    /// Returns the start-of-period date, or `.distantPast` for `.allTime`.
    var cutoffDate: Date {
        switch self {
        case .week:     Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        case .month:    Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        case .quarter:  Calendar.current.date(byAdding: .day, value: -90, to: .now)!
        case .year:     Calendar.current.date(byAdding: .day, value: -365, to: .now)!
        case .allTime:  .distantPast
        }
    }
}
