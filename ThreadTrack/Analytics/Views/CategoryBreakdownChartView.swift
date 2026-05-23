// CategoryBreakdownChartView.swift
// ThreadTrack — Analytics Engine
//
// Donut chart for item distribution + bar chart for wear utilization.
// Uses Swift Charts (iOS 16+).

import SwiftUI
import Charts

public struct CategoryBreakdownChartView: View {
    let entries: [CategoryBreakdownEntry]
    let distributionPct: [ClothingCategory: Double]
    let largestCategory: ClothingCategory?
    let smallestCategory: ClothingCategory?
    let mostUtilized: ClothingCategory?
    let leastUtilized: ClothingCategory?
    let suggestion: String?

    public init(result: CategoryBreakdownAnalyzer.Result) {
        self.entries = result.entries
        self.distributionPct = result.distributionPct
        self.largestCategory = result.largestCategory
        self.smallestCategory = result.smallestCategory
        self.mostUtilized = result.mostUtilized
        self.leastUtilized = result.leastUtilized
        self.suggestion = result.suggestion
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Distribution Donut
                donutSection

                // MARK: - Wear Utilization Bars
                utilizationSection

                // MARK: - Suggestion Card
                if let suggestion {
                    suggestionCard(suggestion)
                }
            }
            .padding()
        }
    }

    // MARK: Donut

    @ViewBuilder
    private var donutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wardrobe Distribution")
                .font(.headline)

            let nonEmpty = entries.filter { $0.count > 0 }

            if nonEmpty.isEmpty {
                Text("No items in wardrobe yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(nonEmpty, id: \.category) { entry in
                    SectorMark(
                        angle: .value("Items", entry.count),
                        innerRadius: .ratio(0.55)
                    )
                    .foregroundStyle(Color(entry.category.chartColor))
                    .annotation(position: .overlay) {
                        if entry.count >= 2 {
                            Text("\(entry.count)")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .bold()
                        }
                    }
                }
                .frame(height: 200)

                // Legend grid.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 6) {
                    ForEach(nonEmpty) { entry in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(entry.category.chartColor))
                                .frame(width: 8, height: 8)
                            Text("\(entry.category.displayName) (\(entry.count) — \(String(format: "%.0f", distributionPct[entry.category] ?? 0))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Utilization

    @ViewBuilder
    private var utilizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wear Utilization by Category")
                .font(.headline)

            let withWears = entries.filter { $0.totalWears > 0 }

            if withWears.isEmpty {
                Text("No wear data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(withWears, id: \.category) { entry in
                    BarMark(
                        x: .value("Category", entry.category.displayName),
                        y: .value("Avg Wears", entry.avgWearCount)
                    )
                    .foregroundStyle(Color(entry.category.chartColor))
                    .cornerRadius(4)
                }
                .frame(height: 160)
                .chartYAxisLabel("Avg wears per item")

                // Highlights.
                HStack(spacing: 16) {
                    if let most = mostUtilized {
                        Label("Most worn: \(most.displayName)", systemImage: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    if let least = leastUtilized {
                        Label("Least worn: \(least.displayName)", systemImage: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    // MARK: Suggestion

    @ViewBuilder
    private func suggestionCard(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.title3)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
