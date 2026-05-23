// AnalyticsService.swift
// ThreadTrack — Analytics Engine
//
// Central orchestrator that wires together all analyzers, the data provider,
// and the export service.  Views call a single `compute()` method and get
// back a snapshot of every metric.

import Foundation

/// A frozen point-in-time snapshot of all analytics.  Cheap to pass around
/// (value type), safe to display in any view hierarchy.
public struct AnalyticsSnapshot: Sendable {
    public let costPerWear: CostPerWearAnalyzer.Result
    public let wearFrequency: WearFrequencyAnalyzer.Result
    public let categoryBreakdown: CategoryBreakdownAnalyzer.Result
    public let laundryStats: LaundryStatsAnalyzer.Result
    public let outfitVariety: OutfitVarietyAnalyzer.Result
    public let computedAt: Date
    public let period: AnalyticsPeriod

    public init(
        costPerWear: CostPerWearAnalyzer.Result,
        wearFrequency: WearFrequencyAnalyzer.Result,
        categoryBreakdown: CategoryBreakdownAnalyzer.Result,
        laundryStats: LaundryStatsAnalyzer.Result,
        outfitVariety: OutfitVarietyAnalyzer.Result,
        computedAt: Date,
        period: AnalyticsPeriod
    ) {
        self.costPerWear = costPerWear
        self.wearFrequency = wearFrequency
        self.categoryBreakdown = categoryBreakdown
        self.laundryStats = laundryStats
        self.outfitVariety = outfitVariety
        self.computedAt = computedAt
        self.period = period
    }
}

// MARK: - Main Service

@MainActor
public final class AnalyticsService: ObservableObject, Sendable {

    /// Published so SwiftUI views re-render when analytics refresh.
    @Published public private(set) var snapshot: AnalyticsSnapshot?

    /// The configured data provider (set during app setup).
    private let provider: any AnalyticsDataProvider

    /// Injected analyzers (overridable for testing).
    private let costAnalyzer: CostPerWearAnalyzer
    private let frequencyAnalyzer: WearFrequencyAnalyzer
    private let categoryAnalyzer: CategoryBreakdownAnalyzer
    private let laundryAnalyzer: LaundryStatsAnalyzer
    private let varietyAnalyzer: OutfitVarietyAnalyzer
    private let exportService: DataExportService

    public init(
        provider: any AnalyticsDataProvider,
        costAnalyzer: CostPerWearAnalyzer = CostPerWearAnalyzer(),
        frequencyAnalyzer: WearFrequencyAnalyzer = WearFrequencyAnalyzer(),
        categoryAnalyzer: CategoryBreakdownAnalyzer = CategoryBreakdownAnalyzer(),
        laundryAnalyzer: LaundryStatsAnalyzer = LaundryStatsAnalyzer(),
        varietyAnalyzer: OutfitVarietyAnalyzer = OutfitVarietyAnalyzer(),
        exportService: DataExportService = DataExportService()
    ) {
        self.provider = provider
        self.costAnalyzer = costAnalyzer
        self.frequencyAnalyzer = frequencyAnalyzer
        self.categoryAnalyzer = categoryAnalyzer
        self.laundryAnalyzer = laundryAnalyzer
        self.varietyAnalyzer = varietyAnalyzer
        self.exportService = exportService
    }

    // MARK: - Compute

    /// Fetches all data and runs every analyzer.  Updates `snapshot` on completion.
    public func compute(period: AnalyticsPeriod = .allTime) async {
        do {
            async let items = provider.allItems()
            async let outfits = provider.allOutfits()
            async let batches = provider.allLaundryBatches()

            let (fetchedItems, fetchedOutfits, fetchedBatches) = try await (
                items, outfits, batches
            )

            let cpw = costAnalyzer.analyze(items: fetchedItems, period: period)
            let wf = frequencyAnalyzer.analyze(items: fetchedItems, period: period)
            let cat = categoryAnalyzer.analyze(items: fetchedItems, period: period)
            let ls = laundryAnalyzer.analyze(
                items: fetchedItems, batches: fetchedBatches, period: period
            )
            let ov = varietyAnalyzer.analyze(outfits: fetchedOutfits, period: period)

            self.snapshot = AnalyticsSnapshot(
                costPerWear: cpw,
                wearFrequency: wf,
                categoryBreakdown: cat,
                laundryStats: ls,
                outfitVariety: ov,
                computedAt: .now,
                period: period
            )
        } catch {
            // In production, surface this to the user. For now, clear snapshot.
            self.snapshot = nil
        }
    }

    // MARK: - Export Convenience

    /// Exports a single analytics section.
    public func export<T>(
        _ section: ExportableSection,
        format: DataExportService.ExportFormat
    ) throws -> Data where T: Encodable {
        guard let snap = snapshot else {
            throw DataExportService.ExportError.noData
        }
        return try exportService.export(section: section, snapshot: snap, format: format)
    }

    /// Exports the full analytics bundle.
    public func exportFullReport(
        format: DataExportService.ExportFormat
    ) throws -> Data {
        guard let snap = snapshot else {
            throw DataExportService.ExportError.noData
        }
        return try exportService.exportFullReport(
            costPerWear: snap.costPerWear.entries,
            wearFrequency: snap.wearFrequency.items,
            categoryBreakdown: snap.categoryBreakdown.entries,
            laundryStats: snap.laundryStats.stats,
            outfitVariety: snap.outfitVariety.stats,
            format: format
        )
    }

    /// Save and return a file URL for sharing.
    public func saveReport(
        format: DataExportService.ExportFormat,
        filename: String = "ThreadTrack_Analytics"
    ) throws -> URL {
        let data = try exportFullReport(format: format)
        return try exportService.saveToDocuments(
            data: data, filename: filename, format: format
        )
    }
}

// MARK: - Export Section Routing

/// Identifies which analytics section to export.
public enum ExportableSection: Sendable {
    case costPerWear
    case wearFrequency
    case categoryBreakdown
    case laundry
    case outfitVariety
}

extension DataExportService {
    fileprivate func export(
        section: ExportableSection,
        snapshot: AnalyticsSnapshot,
        format: ExportFormat
    ) throws -> Data {
        switch section {
        case .costPerWear:
            return try exportCostPerWear(snapshot.costPerWear.entries, format: format)
        case .wearFrequency:
            return try exportWearFrequency(snapshot.wearFrequency.items, format: format)
        case .categoryBreakdown:
            return try exportCategoryBreakdown(snapshot.categoryBreakdown.entries, format: format)
        case .laundry:
            return try exportLaundryStats(snapshot.laundryStats.stats, format: format)
        case .outfitVariety:
            return try exportOutfitVariety(snapshot.outfitVariety.stats, format: format)
        }
    }
}
