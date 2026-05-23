// LaundryStatsAnalyzer.swift
// ThreadTrack — Analytics Engine

import Foundation

/// Tracks laundry cycle metrics: frequency, volume, trends.
public struct LaundryStatsAnalyzer: Sendable {

    // MARK: - Output

    public struct Result: Sendable {
        public let stats: LaundryCycleStats
        /// Trend description (human-readable).
        public let trend: String
        /// Recommended next laundry date (based on current dirty items).
        public let suggestedNextDate: Date?

        public init(stats: LaundryCycleStats, trend: String,
                    suggestedNextDate: Date?) {
            self.stats = stats; self.trend = trend
            self.suggestedNextDate = suggestedNextDate
        }
    }

    // MARK: - Analysis

    public init() {}

    public func analyze(
        items: [any ClothingItemRepresentable],
        batches: [any LaundryBatchRepresentable],
        period: AnalyticsPeriod = .allTime
    ) -> Result {
        let cutoff = period.cutoffDate
        let cal = Calendar.current
        let now = Date.now

        // Filter batches within period.
        let relevantBatches = batches.filter { $0.date >= cutoff }
        let sortedBatches = relevantBatches.sorted { $0.date < $1.date }

        let totalBatches = sortedBatches.count
        let totalItems = sortedBatches.reduce(0) { $0 + $1.itemCount }

        // Build batch records with day deltas.
        var batchRecords: [LaundryCycleStats.BatchRecord] = []
        var dayGaps: [Int] = []

        for (i, batch) in sortedBatches.enumerated() {
            let daysSincePrev: Int? = i > 0
                ? cal.dateComponents([.day], from: sortedBatches[i - 1].date, to: batch.date).day
                : nil

            if let gap = daysSincePrev, gap >= 0 {
                dayGaps.append(gap)
            }

            batchRecords.append(LaundryCycleStats.BatchRecord(
                date: batch.date, itemCount: batch.itemCount, daysSincePrevious: daysSincePrev
            ))
        }

        // Statistics.
        let avgDays = dayGaps.isEmpty ? nil : Double(dayGaps.reduce(0, +)) / Double(dayGaps.count)
        let minDays = dayGaps.min()
        let maxDays = dayGaps.max()

        // Batches per month.
        let batchesPerMonth: Double = {
            guard let first = sortedBatches.first, let last = sortedBatches.last,
                  first != last else { return Double(totalBatches) }
            let days = cal.dateComponents([.day], from: first.date, to: last.date).day ?? 1
            return Double(totalBatches) / (Double(days) / 30.0)
        }()

        let stats = LaundryCycleStats(
            totalBatches: totalBatches,
            totalItemsLaundered: totalItems,
            avgDaysBetweenBatches: avgDays,
            minDaysBetweenBatches: minDays,
            maxDaysBetweenBatches: maxDays,
            batchesPerMonth: batchesPerMonth,
            batchHistory: batchRecords
        )

        // Trend text.
        let trend: String = {
            guard totalBatches >= 2 else {
                return "Not enough laundry history for trends yet."
            }
            if let avg = avgDays {
                if avg < 4 {
                    return "You're doing laundry very frequently (~\(String(format: "%.1f", avg)) days). You may be over-laundering."
                } else if avg > 10 {
                    return "Long gaps between laundry (~\(String(format: "%.1f", avg)) days). Consider more frequent loads to reduce wear."
                } else {
                    return "Good laundry rhythm — averaging \(String(format: "%.1f", avg)) days between loads."
                }
            }
            return "Laundry pattern detected."
        }()

        // Suggested next laundry date.
        let suggestedNextDate: Date? = {
            let dirtyItems = items.filter { $0.isDirty }
            guard !dirtyItems.isEmpty else { return nil }
            let maxRemaining = dirtyItems.map {
                max(0, $0.maxWearsBeforeLaundry - $0.wearCount)
            }.min() ?? 0
            return cal.date(byAdding: .day, value: max(1, maxRemaining), to: now)
        }()

        return Result(stats: stats, trend: trend, suggestedNextDate: suggestedNextDate)
    }
}
