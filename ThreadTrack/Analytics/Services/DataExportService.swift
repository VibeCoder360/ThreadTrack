// DataExportService.swift
// ThreadTrack — Analytics Engine

import Foundation

/// Exports analytics results to CSV or JSON, suitable for sharing via
/// UIActivityViewController or saving to Files.
public struct DataExportService: Sendable {

    public enum ExportFormat: String, CaseIterable, Sendable {
        case csv = "CSV"
        case json = "JSON"

        public var fileExtension: String {
            switch self {
            case .csv:  "csv"
            case .json: "json"
            }
        }

        public var uti: String {
            switch self {
            case .csv:  "public.comma-separated-values-text"
            case .json: "public.json"
            }
        }
    }

    // MARK: - Errors

    public enum ExportError: LocalizedError {
        case noData
        case encodingFailed(String)
        case fileWriteFailed(Error)

        public var errorDescription: String? {
            switch self {
            case .noData:               return "No analytics data to export."
            case .encodingFailed(let detail): return "Encoding failed: \(detail)"
            case .fileWriteFailed(let err):   return "File write failed: \(err.localizedDescription)"
            }
        }
    }

    // MARK: - Public API

    public init() {}

    // MARK: Cost-Per-Wear

    public func exportCostPerWear(
        _ entries: [CostPerWearEntry],
        format: ExportFormat
    ) throws -> Data {
        guard !entries.isEmpty else { throw ExportError.noData }
        return try encode(entries, format: format)
    }

    // MARK: Wear Frequency

    public func exportWearFrequency(
        _ entries: [WearFrequencyEntry],
        format: ExportFormat
    ) throws -> Data {
        guard !entries.isEmpty else { throw ExportError.noData }
        return try encode(entries, format: format)
    }

    // MARK: Category Breakdown

    public func exportCategoryBreakdown(
        _ entries: [CategoryBreakdownEntry],
        format: ExportFormat
    ) throws -> Data {
        guard !entries.isEmpty else { throw ExportError.noData }
        return try encode(entries, format: format)
    }

    // MARK: Laundry Stats

    public func exportLaundryStats(
        _ stats: LaundryCycleStats,
        format: ExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(stats)
        case .csv:
            var csv = "date,item_count,days_since_previous\n"
            for record in stats.batchHistory {
                let iso = ISO8601DateFormatter().string(from: record.date)
                let gap = record.daysSincePrevious.map(String.init) ?? ""
                csv += "\(iso),\(record.itemCount),\(gap)\n"
            }
            guard let data = csv.data(using: .utf8) else {
                throw ExportError.encodingFailed("CSV UTF-8 conversion")
            }
            return data
        }
    }

    // MARK: Outfit Variety

    public func exportOutfitVariety(
        _ stats: OutfitVarietyStats,
        format: ExportFormat
    ) throws -> Data {
        let payload: [String: Any] = [
            "total_outfits": stats.totalOutfits,
            "unique_combinations": stats.uniqueCombinations,
            "repeated_combinations": stats.repeatedCombinations,
            "variety_score": stats.varietyScore,
            "most_repeated_count": stats.mostRepeatedCombo?.count as Any
        ]
        switch format {
        case .json:
            guard let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            ) else {
                throw ExportError.encodingFailed("JSON serialization")
            }
            return data
        case .csv:
            var csv = "metric,value\n"
            for (k, v) in payload {
                csv += "\(k),\(v)\n"
            }
            guard let data = csv.data(using: .utf8) else {
                throw ExportError.encodingFailed("CSV UTF-8 conversion")
            }
            return data
        }
    }

    // MARK: Full Analytics Bundle

    /// Exports all analytics data as a single JSON object or multi-section CSV.
    public func exportFullReport(
        costPerWear: [CostPerWearEntry],
        wearFrequency: [WearFrequencyEntry],
        categoryBreakdown: [CategoryBreakdownEntry],
        laundryStats: LaundryCycleStats,
        outfitVariety: OutfitVarietyStats,
        format: ExportFormat
    ) throws -> Data {
        switch format {
        case .json:
            let wrapper = AnalyticsReport(
                exportDate: .now,
                costPerWear: costPerWear,
                wearFrequency: wearFrequency,
                categoryBreakdown: categoryBreakdown,
                laundryStats: laundryStats,
                outfitVariety: outfitVariety
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(wrapper)
        case .csv:
            // Multi-section CSV with separators.
            var csv = ""
            csv += "=== COST PER WEAR ===\n"
            csv += try buildCSVHeader(CostPerWearEntry.self)
            csv += try buildCSVRows(costPerWear)
            csv += "\n=== WEAR FREQUENCY ===\n"
            csv += try buildCSVHeader(WearFrequencyEntry.self)
            csv += try buildCSVRows(wearFrequency)
            csv += "\n=== CATEGORY BREAKDOWN ===\n"
            csv += try buildCSVHeader(CategoryBreakdownEntry.self)
            csv += try buildCSVRows(categoryBreakdown)
            csv += "\n=== LAUNDRY BATCHES ===\n"
            csv += "date,item_count,days_since_previous\n"
            for r in laundryStats.batchHistory {
                let iso = ISO8601DateFormatter().string(from: r.date)
                csv += "\(iso),\(r.itemCount),\(r.daysSincePrevious ?? 0)\n"
            }
            csv += "\n=== OUTFIT VARIETY ===\n"
            csv += "total_outfits,unique_combos,repeated_combos,variety_score\n"
            csv += "\(outfitVariety.totalOutfits),\(outfitVariety.uniqueCombinations),"
            csv += "\(outfitVariety.repeatedCombinations),\(String(format: "%.2f", outfitVariety.varietyScore))\n"
            guard let data = csv.data(using: .utf8) else {
                throw ExportError.encodingFailed("CSV UTF-8 conversion")
            }
            return data
        }
    }

    // MARK: - File Save Helper

    /// Writes data to the app's Documents directory and returns the URL.
    public func saveToDocuments(
        data: Data,
        filename: String,
        format: ExportFormat
    ) throws -> URL {
        let fname = filename.hasSuffix(format.fileExtension)
            ? filename
            : "\(filename).\(format.fileExtension)"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fname)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Internals

    private func encode<T: Encodable>(_ value: T, format: ExportFormat) throws -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(value)
        case .csv:
            let mirror = Mirror(reflecting: value)
            if let collection = mirror.children.first?.value as? [Any] {
                var csv = ""
                // Header from first element's keys.
                if let first = collection.first {
                    let m = Mirror(reflecting: first)
                    let keys = m.children.compactMap { $0.label }
                    csv += keys.joined(separator: ",") + "\n"
                }
                // Rows.
                for element in collection {
                    let m = Mirror(reflecting: element)
                    let vals = m.children.map { child -> String in
                        if let date = child.value as? Date {
                            return ISO8601DateFormatter().string(from: date)
                        }
                        if let set = child.value as? Set<String> {
                            return "\"\(set.sorted().joined(separator: ";"))\""
                        }
                        return "\(child.value)"
                    }
                    csv += vals.joined(separator: ",") + "\n"
                }
                guard let data = csv.data(using: .utf8) else {
                    throw ExportError.encodingFailed("CSV UTF-8 conversion")
                }
                return data
            }
            throw ExportError.encodingFailed("Unsupported type for CSV")
        }
    }

    private func buildCSVHeader<T>(_ type: T.Type) throws -> String {
        let mirror = Mirror(reflecting: type.init_dummy)
        let keys = mirror.children.compactMap { $0.label }
        return keys.joined(separator: ",") + "\n"
    }

    private func buildCSVRows<T: Encodable>(_ items: [T]) throws -> String {
        var csv = ""
        for item in items {
            let mirror = Mirror(reflecting: item)
            let vals = mirror.children.map { child -> String in
                if let date = child.value as? Date {
                    return ISO8601DateFormatter().string(from: date)
                }
                if let set = child.value as? Set<String> {
                    return "\"\(set.sorted().joined(separator: ";"))\""
                }
                return "\(child.value)"
            }
            csv += vals.joined(separator: ",") + "\n"
        }
        return csv
    }
}

// MARK: - Full Report Wrapper

/// Single Codable struct for the full analytics JSON export.
public struct AnalyticsReport: Codable, Sendable {
    public let exportDate: Date
    public let costPerWear: [CostPerWearEntry]
    public let wearFrequency: [WearFrequencyEntry]
    public let categoryBreakdown: [CategoryBreakdownEntry]
    public let laundryStats: LaundryCycleStats
    public let outfitVariety: OutfitVarietyStats

    public init(exportDate: Date, costPerWear: [CostPerWearEntry],
                wearFrequency: [WearFrequencyEntry],
                categoryBreakdown: [CategoryBreakdownEntry],
                laundryStats: LaundryCycleStats,
                outfitVariety: OutfitVarietyStats) {
        self.exportDate = exportDate
        self.costPerWear = costPerWear
        self.wearFrequency = wearFrequency
        self.categoryBreakdown = categoryBreakdown
        self.laundryStats = laundryStats
        self.outfitVariety = outfitVariety
    }
}

// MARK: - Dummy Init Protocol (for CSV header reflection)

/// Types that can provide a dummy instance for Mirror-based CSV header generation.
private protocol DummyInitializable {
    static var init_dummy: Self { get }
}

extension CostPerWearEntry: DummyInitializable {
    static let init_dummy = CostPerWearEntry(
        id: "", name: "", category: .tops, price: 0, wearCount: 0, costPerWear: 0)
}
extension WearFrequencyEntry: DummyInitializable {
    static let init_dummy = WearFrequencyEntry(
        id: "", name: "", category: .tops, wearCount: 0,
        lastWorn: nil, daysSinceLastWorn: nil, wearDates: [])
}
extension CategoryBreakdownEntry: DummyInitializable {
    static let init_dummy = CategoryBreakdownEntry(
        category: .tops, count: 0, totalWears: 0, avgWearCount: 0)
}
