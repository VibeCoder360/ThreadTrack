// OutfitVarietyChartView.swift
// ThreadTrack — Analytics Engine
//
// Gauge for variety score + weekly trend bar chart + combo breakdown.
// Uses Swift Charts (iOS 16+).

import SwiftUI
import Charts

public struct OutfitVarietyChartView: View {
    let stats: OutfitVarietyStats
    let weeklyBreakdown: [OutfitVarietyAnalyzer.WeeklyVariety]
    let insight: String

    public init(result: OutfitVarietyAnalyzer.Result) {
        self.stats = result.stats
        self.weeklyBreakdown = result.weeklyBreakdown
        self.insight = result.insight
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Variety Score Gauge
                gaugeSection

                // MARK: - Weekly Trend
                weeklyTrendSection

                // MARK: - Combo Breakdown
                comboBreakdown

                // MARK: - Insight Card
                insightCard
            }
            .padding()
        }
    }

    // MARK: Gauge

    @ViewBuilder
    private var gaugeSection: some View {
        VStack(spacing: 12) {
            Text("Outfit Variety Score")
                .font(.headline)

            ZStack {
                // Background ring.
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 14)

                // Filled arc.
                Circle()
                    .trim(from: 0, to: stats.varietyScore)
                    .stroke(
                        varietyGradient,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: stats.varietyScore)

                // Score text.
                VStack(spacing: 2) {
                    Text("\(Int(stats.varietyScore * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(varietyColor)
                    Text("unique")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 160, height: 160)

            // Quick stats row.
            HStack(spacing: 20) {
                statItem("Total Outfits", "\(stats.totalOutfits)")
                statItem("Unique Combos", "\(stats.uniqueCombinations)")
                statItem("Repeated", "\(stats.repeatedCombinations)")
            }
        }
    }

    // MARK: Weekly Trend

    @ViewBuilder
    private var weeklyTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Variety Trend")
                .font(.headline)

            if weeklyBreakdown.isEmpty {
                Text("Not enough outfit data for weekly trends.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(weeklyBreakdown) { week in
                    BarMark(
                        x: .value("Week", "W\(week.week)"),
                        y: .value("Score", week.varietyScore * 100)
                    )
                    .foregroundStyle(
                        week.varietyScore >= 0.8 ? .green
                        : week.varietyScore >= 0.5 ? .orange
                        : .red
                    )
                    .cornerRadius(4)
                }
                .frame(height: 140)
                .chartYAxisLabel("Variety %")
                .chartYScale(domain: 0...100)
            }
        }
    }

    // MARK: Combo Breakdown

    @ViewBuilder
    private var comboBreakdown: some View {
        if let most = stats.mostRepeatedCombo {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "repeat.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Most Repeated Combination")
                        .font(.headline)
                }

                HStack {
                    Text("\(most.count) times")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.12), in: Capsule())

                    Text("\(most.itemIDs.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: Insight Card

    @ViewBuilder
    private var insightCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .font(.title3)
            Text(insight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.purple.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Helpers

    private var varietyColor: Color {
        if stats.varietyScore >= 0.8 { return .green }
        if stats.varietyScore >= 0.5 { return .orange }
        return .red
    }

    private var varietyGradient: LinearGradient {
        let end: UnitPoint = .bottomTrailing
        if stats.varietyScore >= 0.8 {
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: end)
        } else if stats.varietyScore >= 0.5 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: end)
        }
        return LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: end)
    }

    @ViewBuilder
    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
