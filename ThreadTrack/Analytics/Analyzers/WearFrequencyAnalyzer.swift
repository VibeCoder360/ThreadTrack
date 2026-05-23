// WearFrequencyAnalyzer.swift
// ThreadTrack — Analytics Engine

import Foundation

/// Identifies wardrobe rotation patterns: power-user items vs neglected pieces.
public struct WearFrequencyAnalyzer: Sendable {

    // MARK: - Output

    public enum RotationTier: String, Codable, Sendable, CaseIterable {
        case heavyRotation  = "Heavy Rotation"
        case moderate       = "Moderate"
        case underused      = "Underused"
        case neglected      = "Neglected"

        /// Friendly description for UI.
        public var description: String {
            switch self {
            case .heavyRotation: "Worn frequently — core staples"
            case .moderate:      "Decent rotation"
            case .underused:     "Rarely worn — consider donating?"
            case .neglected:     "Never or barely worn"
            }
        }
    }

    public struct TieredItem: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let category: ClothingCategory
        public let wearCount: Int
        public let tier: RotationTier

        public init(id: String, name: String, category: ClothingCategory,
                    wearCount: Int, tier: RotationTier) {
            self.id = id; self.name = name; self.category = category
            self.wearCount = wearCount; self.tier = tier
        }
    }

    public struct Result: Sendable {
        /// All items with their tier classification.
        public let items: [WearFrequencyEntry]
        /// Items grouped by tier.
        public let byTier: [RotationTier: [TieredItem]]
        /// Items sorted by wear count descending (most-worn first).
        public let ranked: [WearFrequencyEntry]
        /// Items never worn.
        public let neverWorn: [WearFrequencyEntry]
        /// Calendar-month aggregation for the heatmap.
        public let monthlyCounts: [MonthlyWearCount]

        public init(items: [WearFrequencyEntry], byTier: [RotationTier: [TieredItem]],
                    ranked: [WearFrequencyEntry], neverWorn: [WearFrequencyEntry],
                    monthlyCounts: [MonthlyWearCount]) {
            self.items = items; self.byTier = byTier
            self.ranked = ranked; self.neverWorn = neverWorn
            self.monthlyCounts = monthlyCounts
        }
    }

    /// Counts for a single calendar month — drives the heatmap.
    public struct MonthlyWearCount: Identifiable, Codable, Sendable {
        public var id: String { "\(year)-\(month)" }
        public let year: Int
        public let month: Int   // 1 … 12
        public let totalWears: Int

        public init(year: Int, month: Int, totalWears: Int) {
            self.year = year; self.month = month; self.totalWears = totalWears
        }
    }

    // MARK: - Tuning

    /// Wear-count thresholds for tier classification (configurable per user).
    public struct Thresholds: Sendable {
        public let heavyRotation: Int
        public let moderate: Int
        public let underused: Int

        public init(heavy: Int = 10, moderate: Int = 5, underused: Int = 2) {
            self.heavyRotation = heavy
            self.moderate = moderate
            self.underused = underused
        }

        /// Classify a wear count into a tier.
        public func tier(for wearCount: Int) -> RotationTier {
            if wearCount >= heavyRotation { return .heavyRotation }
            if wearCount >= moderate     { return .moderate }
            if wearCount >= underused    { return .underused }
            return .neglected
        }
    }

    // MARK: - Analysis

    private let thresholds: Thresholds

    public init(thresholds: Thresholds = Thresholds()) {
        self.thresholds = thresholds
    }

    public func analyze(
        items: [any ClothingItemRepresentable],
        period: AnalyticsPeriod = .allTime
    ) -> Result {
        let cutoff = period.cutoffDate
        let cal = Calendar.current
        var byTier: [RotationTier: [TieredItem]] = [:]
        for t in RotationTier.allCases { byTier[t] = [] }

        var entries: [WearFrequencyEntry] = []
        var ranked: [WearFrequencyEntry] = []
        var neverWorn: [WearFrequencyEntry] = []

        // Month-keyed wear counter for heatmap.
        var monthlyMap: [String: Int] = [:]

        for item in items {
            let relevantDates = item.wearDates.filter { $0 >= cutoff }
            let count = relevantDates.count

            let entry = WearFrequencyEntry(
                id: item.id, name: item.name, category: item.category,
                wearCount: count,
                lastWorn: item.lastWornDate,
                daysSinceLastWorn: item.lastWornDate.map {
                    cal.dateComponents([.day], from: $0, to: .now).day ?? 0
                },
                wearDates: relevantDates
            )
            entries.append(entry)
            ranked.append(entry)

            if count == 0 { neverWorn.append(entry) }

            let tier = thresholds.tier(for: count)
            byTier[tier]?.append(TieredItem(
                id: item.id, name: item.name,
                category: item.category, wearCount: count, tier: tier
            ))

            // Aggregate monthly counts.
            for d in relevantDates {
                let comps = cal.dateComponents([.year, .month], from: d)
                guard let y = comps.year, let m = comps.month else { continue }
                let key = "\(y)-\(m)"
                monthlyMap[key, default: 0] += 1
            }
        }

        ranked.sort { $0.wearCount > $1.wearCount }

        // Convert monthly map → sorted array.
        let monthlyCounts = monthlyMap.map { key, total in
            let parts = key.split(separator: "-").compactMap(Int.init)
            return MonthlyWearCount(year: parts[0], month: parts[1], totalWears: total)
        }.sorted { $0.year != $1.year ? $0.year < $1.year : $0.month < $1.month }

        return Result(
            items: entries, byTier: byTier, ranked: ranked,
            neverWorn: neverWorn, monthlyCounts: monthlyCounts
        )
    }
}
