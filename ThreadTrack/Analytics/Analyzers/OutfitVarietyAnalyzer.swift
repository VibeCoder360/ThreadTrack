// OutfitVarietyAnalyzer.swift
// ThreadTrack — Analytics Engine

import Foundation

/// Measures outfit diversity — detects repeated exact combinations and
/// computes a variety score (0 = every day the same, 1 = all unique).
public struct OutfitVarietyAnalyzer: Sendable {

    // MARK: - Output

    public struct Result: Sendable {
        public let stats: OutfitVarietyStats
        /// Weekly variety breakdown (week number → unique combos that week).
        public let weeklyBreakdown: [WeeklyVariety]
        /// Insight text.
        public let insight: String

        public init(stats: OutfitVarietyStats, weeklyBreakdown: [WeeklyVariety],
                    insight: String) {
            self.stats = stats; self.weeklyBreakdown = weeklyBreakdown
            self.insight = insight
        }
    }

    public struct WeeklyVariety: Identifiable, Codable, Sendable {
        public var id: String { "\(year)-W\(week)" }
        public let year: Int
        public let week: Int
        public let totalOutfits: Int
        public let uniqueCombos: Int
        public let varietyScore: Double

        public init(year: Int, week: Int, totalOutfits: Int,
                    uniqueCombos: Int, varietyScore: Double) {
            self.year = year; self.week = week
            self.totalOutfits = totalOutfits
            self.uniqueCombos = uniqueCombos
            self.varietyScore = varietyScore
        }
    }

    // MARK: - Analysis

    public init() {}

    public func analyze(
        outfits: [any DailyOutfitRepresentable],
        period: AnalyticsPeriod = .allTime
    ) -> Result {
        let cutoff = period.cutoffDate
        let cal = Calendar.current

        // Filter to period, sort chronologically.
        let relevant = outfits
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }

        let totalOutfits = relevant.count

        // Count occurrences of each unique combination.
        var comboCounts: [String: Int] = [:]
        var comboIDs: [String: Set<String>] = [:]

        for outfit in relevant {
            // Normalize: sorted item-id string as the key.
            let key = outfit.itemIDs.sorted().joined(separator: "|")
            comboCounts[key, default: 0] += 1
            comboIDs[key] = outfit.itemIDs
        }

        let uniqueCombinations = comboCounts.count
        let repeatedCombos = comboCounts.values.filter { $0 > 1 }.count

        // Variety score: ratio of unique combos to total outfits.
        let varietyScore: Double = totalOutfits > 0
            ? min(1.0, Double(uniqueCombinations) / Double(totalOutfits))
            : 0.0

        // Most repeated combination.
        let mostRepeated: OutfitVarietyStats.RepeatedCombo? = comboCounts
            .filter { $0.value > 1 }
            .max { $0.value < $1.value }
            .map { OutfitVarietyStats.RepeatedCombo(itemIDs: comboIDs[$0.key]!, count: $0.value) }

        let stats = OutfitVarietyStats(
            totalOutfits: totalOutfits,
            uniqueCombinations: uniqueCombinations,
            repeatedCombinations: repeatedCombos,
            varietyScore: varietyScore,
            mostRepeatedCombo: mostRepeated
        )

        // Weekly breakdown.
        var weeklyMap: [String: (total: Int, combos: Set<String>)] = [:]
        for outfit in relevant {
            let weekComps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: outfit.date)
            guard let year = weekComps.yearForWeekOfYear, let week = weekComps.weekOfYear else { continue }
            let key = "\(year)-W\(week)"
            let comboKey = outfit.itemIDs.sorted().joined(separator: "|")
            var entry = weeklyMap[key, default: (total: 0, combos: []))
            entry.total += 1
            entry.combos.insert(comboKey)
            weeklyMap[key] = entry
        }

        let weeklyBreakdown = weeklyMap.map { key, val in
            let parts = key.split(separator: "-W")
            let year = Int(parts[0]) ?? 0
            let week = Int(parts[1]) ?? 0
            let score = val.total > 0 ? min(1.0, Double(val.combos.count) / Double(val.total)) : 0
            return WeeklyVariety(year: year, week: week,
                                 totalOutfits: val.total, uniqueCombos: val.combos.count,
                                 varietyScore: score)
        }.sorted { $0.year != $1.year ? $0.year < $1.year : $0.week < $1.week }

        // Insight.
        let insight: String = {
            guard totalOutfits >= 3 else {
                return "Log more outfits to see variety insights."
            }
            if varietyScore >= 0.9 {
                return "Excellent variety — \(Int(varietyScore * 100))% of your outfits are unique combinations. You're making the most of your wardrobe!"
            } else if varietyScore >= 0.7 {
                return "Good variety (\(Int(varietyScore * 100))% unique). A bit of repetition but a solid rotation."
            } else if varietyScore >= 0.4 {
                return "Moderate variety (\(Int(varietyScore * 100))% unique). You tend to repeat some favorite combinations."
            } else {
                return "Low variety (\(Int(varietyScore * 100))% unique). You're wearing the same outfits frequently — try mixing it up!"
            }
        }()

        return Result(stats: stats, weeklyBreakdown: weeklyBreakdown, insight: insight)
    }
}
