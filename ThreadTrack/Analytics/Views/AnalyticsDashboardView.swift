// AnalyticsDashboardView.swift
// ThreadTrack — Analytics Engine
//
// Top-level analytics tab: period selector, metric cards, chart sections,
// and navigation to detailed views + export.

import SwiftUI

public struct AnalyticsDashboardView: View {
    @StateObject private var service: AnalyticsService
    @State private var selectedPeriod: AnalyticsPeriod = .month
    @State private var isLoading = false
    @State private var selectedTab: DashboardTab = .overview

    /// Initialize with a data provider (bridge from your SwiftData layer).
    public init(provider: any AnalyticsDataProvider) {
        _service = StateObject(wrappedValue: AnalyticsService(provider: provider))
    }

    /// For SwiftUI previews — uses a mock provider.
    public init() {
        _service = StateObject(wrappedValue: AnalyticsService(provider: MockAnalyticsProvider()))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: Period Picker
                periodPicker

                // MARK: Content
                if let snapshot = service.snapshot {
                    content(snapshot)
                } else if isLoading {
                    ProgressView("Computing analytics...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ExportView(analyticsService: service)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(service.snapshot == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await refresh()
            }
            .onChange(of: selectedPeriod) { _ in
                Task { await refresh() }
            }
        }
    }

    // MARK: Period Picker

    @ViewBuilder
    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AnalyticsPeriod.allCases, id: \.rawValue) { period in
                    Button {
                        selectedPeriod = period
                    } label: {
                        Text(period.label)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedPeriod == period
                                    ? Color.blue
                                    : Color(.systemGray5),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedPeriod == period ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ snap: AnalyticsSnapshot) -> some View {
        switch selectedTab {
        case .overview:
            overviewContent(snap)
        case .costPerWear:
            CostPerWearChartView(result: snap.costPerWear)
        case .frequency:
            WearFrequencyChartView(result: snap.wearFrequency)
        case .categories:
            CategoryBreakdownChartView(result: snap.categoryBreakdown)
        case .laundry:
            LaundryCycleChartView(result: snap.laundryStats)
        case .variety:
            OutfitVarietyChartView(result: snap.outfitVariety)
        }
    }

    // MARK: Overview

    @ViewBuilder
    private func overviewContent(_ snap: AnalyticsSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Quick stat cards.
                overviewStatCards(snap)

                // Mini charts for each metric.
                NavigationLink {
                    CostPerWearChartView(result: snap.costPerWear)
                } label: {
                    MiniMetricCard(
                        title: "Cost Per Wear",
                        subtitle: "Best: \(snap.costPerWear.bestValue?.name ?? "—")",
                        value: snap.costPerWear.avgCostPerWear
                            .map { "$\(String(format: "%.2f", $0))/wear" } ?? "—",
                        icon: "dollarsign.circle.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WearFrequencyChartView(result: snap.wearFrequency)
                } label: {
                    MiniMetricCard(
                        title: "Wear Frequency",
                        subtitle: "Never worn: \(snap.wearFrequency.neverWorn.count)",
                        value: "\(snap.wearFrequency.ranked.first?.wearCount ?? 0)x top",
                        icon: "chart.bar.fill",
                        color: .blue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CategoryBreakdownChartView(result: snap.categoryBreakdown)
                } label: {
                    MiniMetricCard(
                        title: "Categories",
                        subtitle: snap.categoryBreakdown.suggestion ?? "Balanced",
                        value: "\(snap.categoryBreakdown.entries.first?.category.displayName ?? "—") leads",
                        icon: "square.grid.2x2.fill",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LaundryCycleChartView(result: snap.laundryStats)
                } label: {
                    MiniMetricCard(
                        title: "Laundry",
                        subtitle: snap.laundryStats.trend,
                        value: "\(snap.laundryStats.stats.totalBatches) loads",
                        icon: "washer.fill",
                        color: .cyan
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    OutfitVarietyChartView(result: snap.outfitVariety)
                } label: {
                    MiniMetricCard(
                        title: "Outfit Variety",
                        subtitle: snap.outfitVariety.insight,
                        value: "\(Int(snap.outfitVariety.stats.varietyScore * 100))% unique",
                        icon: "sparkles",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    // MARK: Overview Stat Cards

    @ViewBuilder
    private func overviewStatCards(_ snap: AnalyticsSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatCard(
                title: "Items",
                value: "\(snap.wearFrequency.items.count)",
                icon: "tshirt.fill",
                color: .blue
            )
            StatCard(
                title: "Total Wears",
                value: "\(snap.wearFrequency.ranked.reduce(0) { $0 + $1.wearCount })",
                icon: "repeat.circle.fill",
                color: .green
            )
            StatCard(
                title: "Outfits Logged",
                value: "\(snap.outfitVariety.stats.totalOutfits)",
                icon: "camera.fill",
                color: .orange
            )
            StatCard(
                title: "Laundry Loads",
                value: "\(snap.laundryStats.stats.totalBatches)",
                icon: "washer.fill",
                color: .cyan
            )
        }
    }

    // MARK: Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No analytics data yet")
                .font(.headline)
            Text("Start logging outfits and wearing your clothes to see insights here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Refresh

    private func refresh() async {
        isLoading = true
        await service.compute(period: selectedPeriod)
        isLoading = false
    }
}

// MARK: - Supporting Views

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct MiniMetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Dashboard Tab

private enum DashboardTab: String, CaseIterable {
    case overview
    case costPerWear
    case frequency
    case categories
    case laundry
    case variety
}

// MARK: - Period Label

private extension AnalyticsPeriod {
    var label: String {
        switch self {
        case .week:    "7 Days"
        case .month:   "30 Days"
        case .quarter: "90 Days"
        case .year:    "1 Year"
        case .allTime: "All Time"
        }
    }
}

// MARK: - Preview Mock

/// Minimal mock for SwiftUI previews.  Not used in production.
private final class MockAnalyticsProvider: AnalyticsDataProvider, @unchecked Sendable {
    func allItems() async throws -> [any ClothingItemRepresentable] { [] }
    func allOutfits() async throws -> [any DailyOutfitRepresentable] { [] }
    func allLaundryBatches() async throws -> [any LaundryBatchRepresentable] { [] }
}
