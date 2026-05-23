// LaundryCycleChartView.swift
// ThreadTrack — Analytics Engine
//
// Line chart for laundry cadence + summary stats cards.
// Uses Swift Charts (iOS 16+).

import SwiftUI
import Charts

public struct LaundryCycleChartView: View {
    let stats: LaundryCycleStats
    let trend: String
    let suggestedNextDate: Date?

    public init(result: LaundryStatsAnalyzer.Result) {
        self.stats = result.stats
        self.trend = result.trend
        self.suggestedNextDate = result.suggestedNextDate
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Stats Grid
                statsGrid

                // MARK: - Cadence Line Chart
                cadenceChart

                // MARK: - Items-per-Load Chart
                loadSizeChart

                // MARK: - Trend Card
                trendCard

                // MARK: - Suggested Next Date
                if let next = suggestedNextDate {
                    nextLaundryCard(next)
                }
            }
            .padding()
        }
    }

    // MARK: Stats Grid

    @ViewBuilder
    private var statsGrid: some View {
        let cards: [(String, String, String, Color)] = [
            ("Total Loads", "\(stats.totalBatches)", "archivebox.fill", .blue),
            ("Items Laundered", "\(stats.totalItemsLaundered)", "tshirt.fill", .indigo),
            ("Avg Gap", stats.avgDaysBetweenBatches.map { "\(String(format: "%.1f", $0)) days" } ?? "N/A", "clock.fill", .orange),
            ("Loads/Month", "\(String(format: "%.1f", stats.batchesPerMonth))", "calendar.fill", .green),
        ]

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(cards, id: \.0) { title, value, icon, color in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: icon).foregroundStyle(color).font(.caption)
                        Text(title).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(value).font(.title2.bold())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: Cadence Chart

    @ViewBuilder
    private var cadenceChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Laundry Cadence (Days Between Loads)")
                .font(.headline)

            let withGap = stats.batchHistory.filter { $0.daysSincePrevious != nil }

            if withGap.isEmpty {
                Text("Need at least 2 laundry loads to show cadence.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(withGap) { record in
                    LineMark(
                        x: .value("Load", record.date, unit: .day),
                        y: .value("Days Since Previous", record.daysSincePrevious ?? 0)
                    )
                    .foregroundStyle(.blue.gradient)
                    .symbol(Circle())

                    PointMark(
                        x: .value("Load", record.date, unit: .day),
                        y: .value("Days Since Previous", record.daysSincePrevious ?? 0)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 160)
                .chartYAxisLabel("Days")

                // Range annotation.
                if let min = stats.minDaysBetweenBatches, let max = stats.maxDaysBetweenBatches {
                    HStack {
                        Text("Range: \(min)–\(max) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Load Size Chart

    @ViewBuilder
    private var loadSizeChart: some View {
        if !stats.batchHistory.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Items Per Load")
                    .font(.headline)

                Chart(stats.batchHistory) { record in
                    BarMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Items", record.itemCount)
                    )
                    .foregroundStyle(.indigo.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 140)
            }
        }
    }

    // MARK: Trend Card

    @ViewBuilder
    private var trendCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .foregroundStyle(.blue)
                .font(.title3)
            Text(trend)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Next Laundry Card

    @ViewBuilder
    private func nextLaundryCard(_ date: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "washer.fill")
                .foregroundStyle(.cyan)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Suggested Next Laundry")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(date, style: .date)
                    .font(.subheadline.bold())
            }
        }
        .padding(12)
        .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
