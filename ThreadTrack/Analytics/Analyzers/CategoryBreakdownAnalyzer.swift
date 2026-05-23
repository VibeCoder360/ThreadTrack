// CategoryBreakdownAnalyzer.swift
// ThreadTrack — Analytics Engine

import Foundation

/// Analyzes the distribution of items and wear across clothing categories.
/// Helps answer "do I have too many shirts, not enough pants?"
public struct CategoryBreakdownAnalyzer: Sendable {

    // MARK: - Output

    public struct Result: Sendable {
        public let entries: [CategoryBreakdownEntry]
        /// Percentage of wardrobe each category occupies.
        public let distributionPct: [ClothingCategory: Double]
        /// Category with the most items.
        public let largestCategory: ClothingCategory?
        /// Category with the fewest items (excluding empty).
        public let smallestCategory: ClothingCategory?
        /// Category with the highest average wear-per-item (most utilized).
        public let mostUtilized: ClothingCategory?
        /// Category with the lowest average wear-per-item (neglected).
        public let leastUtilized: ClothingCategory?
        /// Suggestion string for balance improvement.
        public let suggestion: String?

        public init(entries: [CategoryBreakdownEntry],
                    distributionPct: [ClothingCategory: Double],
                    largestCategory: ClothingCategory?,
                    smallestCategory: ClothingCategory?,
                    mostUtilized: ClothingCategory?,
                    leastUtilized: ClothingCategory?,
                    suggestion: String?) {
            self.entries = entries; self.distributionPct = distributionPct
            self.largestCategory = largestCategory
            self.smallestCategory = smallestCategory
            self.mostUtilized = mostUtilized
            self.leastUtilized = leastUtilized
            self.suggestion = suggestion
        }
    }

    // MARK: - Analysis

    public init() {}

    public func analyze(
        items: [any ClothingItemRepresentable],
        period: AnalyticsPeriod = .allTime
    ) -> Result {
        let cutoff = period.cutoffDate

        // Bucket items by category.
        var buckets: [ClothingCategory: [any ClothingItemRepresentable]] = [:]
        for cat in ClothingCategory.allCases { buckets[cat] = [] }
        for item in items {
            buckets[item.category, default: []].append(item)
        }

        let totalItems = items.count

        var entries: [CategoryBreakdownEntry] = []
        var distributionPct: [ClothingCategory: Double] = [:]

        for cat in ClothingCategory.allCases {
            let catItems = buckets[cat] ?? []
            let count = catItems.count
            let wearsInPeriod = catItems.reduce(0) { $0 + $1.wearDates.filter { $0 >= cutoff }.count }
            let avg: Double = count > 0 ? Double(wearsInPeriod) / Double(count) : 0

            entries.append(CategoryBreakdownEntry(
                category: cat, count: count,
                totalWears: wearsInPeriod, avgWearCount: avg
            ))
            distributionPct[cat] = totalItems > 0 ? Double(count) / Double(totalItems) * 100 : 0
        }

        // Sort by count descending.
        entries.sort { $0.count > $1.count }

        let nonEmpty = entries.filter { $0.count > 0 }
        let largest = nonEmpty.first?.category
        let smallest = nonEmpty.last?.category

        // Utilization — highest/lowest avg wear.
        let withWears = nonEmpty.filter { $0.totalWears > 0 }
        let mostUtil = withWears.max { $0.avgWearCount < $1.avgWearCount }?.category
        let leastUtil = withWears.min { $0.avgWearCount < $1.avgWearCount }?.category

        // Simple heuristic suggestion.
        let suggestion = Self.generateSuggestion(
            largest: largest, smallest: smallest,
            mostUtil: mostUtil, leastUtil: leastUtil,
            entries: nonEmpty
        )

        return Result(
            entries: entries, distributionPct: distributionPct,
            largestCategory: largest, smallestCategory: smallest,
            mostUtilized: mostUtil, leastUtilized: leastUtil,
            suggestion: suggestion
        )
    }

    // MARK: - Suggestion Engine

    /// Generates a plain-text suggestion based on the imbalance detected.
    private static func generateSuggestion(
        largest: ClothingCategory?,
        smallest: ClothingCategory?,
        mostUtil: ClothingCategory?,
        leastUtil: ClothingCategory?,
        entries: [CategoryBreakdownEntry]
    ) -> String? {
        guard let largest, let smallest, largest != smallest else {
            return nil // Balanced or too few items.
        }

        let maxPct = entries.first.map { Double($0.count) } ?? 0
        let totalItems = entries.reduce(0) { $0 + $1.count }
        guard totalItems > 5 else { return nil } // Not enough data.

        let largestPct = Double(entries.first!.count) / Double(totalItems) * 100

        if largestPct > 50 {
            return "Your wardrobe is heavily skewed toward \(largest.displayName) (\(Int(largestPct))%). Consider diversifying with more \(smallest.displayName)."
        }

        if let leastUtil, let mostUtil, leastUtil != mostUtil {
            return "You wear a lot of \(mostUtil.displayName) but rarely reach for \(leastUtil.displayName). Maybe it's time to refresh your \(leastUtil.displayName) collection."
        }

        return nil
    }
}
