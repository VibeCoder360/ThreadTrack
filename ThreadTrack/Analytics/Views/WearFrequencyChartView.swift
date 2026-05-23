// WearFrequencyChartView.swift
// ThreadTrack — Analytics Engine
//
// Multi-chart view: tier pie chart + monthly wear bar chart + ranked list.
// Uses Swift Charts (iOS 16+).

import SwiftUI
import Charts

public struct WearFrequencyChartView: View {
    let items: [WearFrequencyEntry]
    let byTier: [WearFrequencyAnalyzer.RotationTier: [WearFrequencyAnalyzer.TieredItem]]
    let ranked: [WearFrequencyEntry]
    let neverWorn: [WearFrequencyEntry]
    let monthlyCounts: [WearFrequencyAnalyzer.MonthlyWearCount]

    public init(result: WearFrequencyAnalyzer.Result) {
        self.items = result.items
        self.byTier = result.byTier
        self.ranked = result.ranked
        self.neverWorn = result.neverWorn
        self.monthlyCounts = result.monthlyCounts
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Tier Distribution Pie
                tierSection

                // MARK: - Monthly Wear Heatmap (bar chart)
                monthlySection

                // MARK: - Top Rotation List
                rankedList

                // MARK: - Neglected Items
                neglectedSection
            }
            .padding()
        }
    }

    // MARK: Tier Section

    @ViewBuilder
    private var tierSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rotation Tiers")
                .font(.headline)

            let tierData = WearFrequencyAnalyzer.RotationTier.allCases.compactMap { tier -> (String, Int, Color)? in
                let count = byTier[tier]?.count ?? 0
                guard count > 0 else { return nil }
                return (tier.rawValue, count, tierColor(tier))
            }

            Chart(tierData, id: \.0) { name, count, color in
                SectorMark(
                    angle: .value("Count", count),
                    innerRadius: .ratio(0.5)
                )
                .foregroundStyle(color)
                .annotation(position: .overlay) {
                    if count > 2 {
                        Text("\(count)")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .bold()
                    }
                }
            }
            .frame(height: 180)

            // Legend.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 6) {
                ForEach(WearFrequencyAnalyzer.RotationTier.allCases, id: \.rawValue) { tier in
                    let count = byTier[tier]?.count ?? 0
                    if count > 0 {
                        HStack(spacing: 4) {
                            Circle().fill(tierColor(tier)).frame(width: 8, height: 8)
                            Text("\(tier.rawValue) (\(count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Monthly Section

    @ViewBuilder
    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly Wear Volume")
                .font(.headline)

            if monthlyCounts.isEmpty {
                Text("No wear data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(monthlyCounts) { month in
                    BarMark(
                        x: .value("Month", "\(shortMonth(month.month)) \(month.year)"),
                        y: .value("Wears", month.totalWears)
                    )
                    .foregroundStyle(
                        month.totalWears > 20 ? .red
                        : month.totalWears > 10 ? .orange
                        : .blue
                    )
                }
                .frame(height: 160)
                .chartYAxisLabel("Total wears")
            }
        }
    }

    // MARK: Ranked List

    @ViewBuilder
    private var rankedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Rotation (Most Worn)")
                .font(.headline)

            let top = Array(ranked.prefix(10))
            ForEach(top) { item in
                HStack {
                    Circle()
                        .fill(Color(item.category.chartColor))
                        .frame(width: 10, height: 10)
                    Text(item.name)
                        .lineLimit(1)
                    Spacer()
                    Text("\(item.wearCount)x")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: Neglected Section

    @ViewBuilder
    private var neglectedSection: some View {
        if !neverWorn.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.badge.questionmark")
                        .foregroundStyle(.orange)
                    Text("Never Worn (\(neverWorn.count))")
                        .font(.headline)
                }

                ForEach(Array(neverWorn.prefix(5))) { item in
                    HStack {
                        Circle()
                            .fill(Color(item.category.chartColor))
                            .frame(width: 8, height: 8)
                        Text(item.name)
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Helpers

    private func tierColor(_ tier: WearFrequencyAnalyzer.RotationTier) -> Color {
        switch tier {
        case .heavyRotation: .green
        case .moderate:      .blue
        case .underused:     .orange
        case .neglected:     .red
        }
    }

    private func shortMonth(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let components = DateComponents(year: 2024, month: month, day: 1)
        return formatter.string(from: Calendar.current.date(from: components)!)
    }
}
