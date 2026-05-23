// CostPerWearChartView.swift
// ThreadTrack — Analytics Engine
//
// Horizontal bar chart: items sorted by cost-per-wear (best value first).
// Uses Swift Charts (iOS 16+).

import SwiftUI
import Charts

public struct CostPerWearChartView: View {
    let entries: [CostPerWearEntry]
    let neverWorn: [CostPerWearEntry]
    let bestValue: CostPerWearEntry?
    let worstValue: CostPerWearEntry?
    let totalSpent: Double

    public init(result: CostPerWearAnalyzer.Result) {
        // Show top 15 for readability.
        self.entries = Array(result.entries.prefix(15))
        self.neverWorn = result.neverWorn
        self.bestValue = result.bestValue
        self.worstValue = result.worstValue
        self.totalSpent = result.totalSpent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Summary cards.
            HStack(spacing: 12) {
                SummaryCard(
                    title: "Total Investment",
                    value: totalSpent.formatted(.currency(code: "USD")),
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                if let best = bestValue {
                    SummaryCard(
                        title: "Best Value",
                        value: best.name,
                        subtitle: "$\(String(format: "%.2f", best.costPerWear))/wear",
                        icon: "trophy.fill",
                        color: .blue
                    )
                }
                if let worst = worstValue {
                    SummaryCard(
                        title: "Worst Value",
                        value: worst.name,
                        subtitle: "$\(String(format: "%.2f", worst.costPerWear))/wear",
                        icon: "exclamationmark.triangle.fill",
                        color: .red
                    )
                }
            }

            // Chart.
            Chart(entries) { entry in
                BarMark(
                    x: .value("Cost/Wear", entry.costPerWear),
                    y: .value("Item", entry.name)
                )
                .foregroundStyle(Color(entry.category.chartColor))
                .annotation(position: .trailing) {
                    Text("$\(String(format: "%.1f", entry.costPerWear))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: CGFloat(entries.count) * 32)
            .chartXAxisLabel("Cost per wear ($)")

            // Never-worn warning.
            if !neverWorn.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text("\(neverWorn.count) item(s) never worn — $\(neverWorn.reduce(0.0) { $0 + $1.price }.formatted(.currency(code: "USD"))) sitting idle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
    }
}

// MARK: - Summary Card

private struct SummaryCard: View {
    let title: String
    let value: String
    var subtitle: String?
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
