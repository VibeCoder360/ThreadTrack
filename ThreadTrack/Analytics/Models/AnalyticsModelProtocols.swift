// AnalyticsModelProtocols.swift
// ThreadTrack — Analytics Engine
//
// Protocol-based data contracts so the analytics layer stays decoupled
// from SwiftData concrete model types (defined in T3).  Bridge adapters
// extend the concrete SwiftData models to conform to these protocols.

import Foundation

// MARK: - Domain Types

/// Mirrors ClothingCategory from the data model layer.
/// Raw-string-backed for safe JSON/Codable serialization.
public enum ClothingCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case tops
    case bottoms
    case shoes
    case outerwear
    case accessories
    case underwear
    case socks

    /// Human-readable label for UI.
    public var displayName: String {
        switch self {
        case .tops: "Tops"
        case .bottoms: "Bottoms"
        case .shoes: "Shoes"
        case .outerwear: "Outerwear"
        case .accessories: "Accessories"
        case .underwear: "Underwear"
        case .socks: "Socks"
        }
    }

    /// SF Symbol name for chart legends.
    public var systemImage: String {
        switch self {
        case .tops: "tshirt"
        case .bottoms: "trousers"
        case .shoes: "shoeprints.fill"
        case .outerwear: "wind"
        case .accessories: "eyeglasses"
        case .underwear: "bandage.fill"
        case .socks: "socks.fill"
        }
    }

    /// A distinct SwiftUI Chart-compatible color for each category.
    public var chartColor: String {
        switch self {
        case .tops: "blue"
        case .bottoms: "indigo"
        case .shoes: "brown"
        case .outerwear: "orange"
        case .accessories: "purple"
        case .underwear: "pink"
        case .socks: "mint"
        }
    }
}

// MARK: - Item Protocol

/// Minimal contract for a clothing item consumed by every analyzer.
public protocol ClothingItemRepresentable: Identifiable, Sendable {
    var id: String { get }
    var name: String { get }
    var category: ClothingCategory { get }
    var wearCount: Int { get }
    var lastWornDate: Date? { get }
    var price: Double? { get }
    var dateAdded: Date { get }
    var isDirty: Bool { get }
    var maxWearsBeforeLaundry: Int { get }

    /// Ordered list of dates the item was worn (for frequency analysis).
    /// If the concrete model stores wear logs separately, the bridge adapter
    /// should resolve them here.
    var wearDates: [Date] { get }
}

// MARK: - Outfit Protocol

/// A single daily outfit composed of one or more clothing items.
public protocol DailyOutfitRepresentable: Identifiable, Sendable {
    var id: String { get }
    var date: Date { get }
    /// Stable item-id set — order-insensitive for dedup.
    var itemIDs: Set<String> { get }
}

// MARK: - Laundry Protocol

/// A single laundry batch (one load).
public protocol LaundryBatchRepresentable: Identifiable, Sendable {
    var id: String { get }
    var date: Date { get }
    var itemCount: Int { get }
    var itemIDs: Set<String> { get }
}

// MARK: - Data Provider

/// Single gateway the AnalyticsService uses to fetch everything it needs.
/// Conform your SwiftData ModelContext wrapper to this.
public protocol AnalyticsDataProvider: Sendable {
    func allItems() async throws -> [any ClothingItemRepresentable]
    func allOutfits() async throws -> [any DailyOutfitRepresentable]
    func allLaundryBatches() async throws -> [any LaundryBatchRepresentable]
}

// MARK: - Export-Ready Representations

/// Value types that the export service serializes — no protocols, just Codable structs.

public struct CostPerWearEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: ClothingCategory
    public let price: Double
    public let wearCount: Int
    public let costPerWear: Double

    public init(id: String, name: String, category: ClothingCategory,
                price: Double, wearCount: Int, costPerWear: Double) {
        self.id = id; self.name = name; self.category = category
        self.price = price; self.wearCount = wearCount; self.costPerWear = costPerWear
    }
}

public struct WearFrequencyEntry: Codable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: ClothingCategory
    public let wearCount: Int
    public let lastWorn: Date?
    public let daysSinceLastWorn: Int?
    public let wearDates: [Date]

    public init(id: String, name: String, category: ClothingCategory,
                wearCount: Int, lastWorn: Date?, daysSinceLastWorn: Int?,
                wearDates: [Date]) {
        self.id = id; self.name = name; self.category = category
        self.wearCount = wearCount; self.lastWorn = lastWorn
        self.daysSinceLastWorn = daysSinceLastWorn; self.wearDates = wearDates
    }
}

public struct CategoryBreakdownEntry: Codable, Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: ClothingCategory
    public let count: Int
    public let totalWears: Int
    public let avgWearCount: Double

    public init(category: ClothingCategory, count: Int,
                totalWears: Int, avgWearCount: Double) {
        self.category = category; self.count = count
        self.totalWears = totalWears; self.avgWearCount = avgWearCount
    }
}

public struct LaundryCycleStats: Codable, Sendable {
    public let totalBatches: Int
    public let totalItemsLaundered: Int
    public let avgDaysBetweenBatches: Double?
    public let minDaysBetweenBatches: Int?
    public let maxDaysBetweenBatches: Int?
    public let batchesPerMonth: Double
    public let batchHistory: [BatchRecord]

    public struct BatchRecord: Codable, Identifiable, Sendable {
        public var id: String { "\(date.timeIntervalSince1970)" }
        public let date: Date
        public let itemCount: Int
        public let daysSincePrevious: Int?
    }

    public init(totalBatches: Int, totalItemsLaundered: Int,
                avgDaysBetweenBatches: Double?, minDaysBetweenBatches: Int?,
                maxDaysBetweenBatches: Int?, batchesPerMonth: Double,
                batchHistory: [BatchRecord]) {
        self.totalBatches = totalBatches; self.totalItemsLaundered = totalItemsLaundered
        self.avgDaysBetweenBatches = avgDaysBetweenBatches
        self.minDaysBetweenBatches = minDaysBetweenBatches
        self.maxDaysBetweenBatches = maxDaysBetweenBatches
        self.batchesPerMonth = batchesPerMonth; self.batchHistory = batchHistory
    }
}

public struct OutfitVarietyStats: Codable, Sendable {
    public let totalOutfits: Int
    public let uniqueCombinations: Int
    public let repeatedCombinations: Int
    public let varietyScore: Double          // 0.0 … 1.0
    public let mostRepeatedCombo: RepeatedCombo?

    public struct RepeatedCombo: Codable, Identifiable, Sendable {
        public var id: String { itemIDs.sorted().joined(separator: ",") }
        public let itemIDs: Set<String>
        public let count: Int
    }

    public init(totalOutfits: Int, uniqueCombinations: Int,
                repeatedCombinations: Int, varietyScore: Double,
                mostRepeatedCombo: RepeatedCombo?) {
        self.totalOutfits = totalOutfits; self.uniqueCombinations = uniqueCombinations
        self.repeatedCombinations = repeatedCombinations
        self.varietyScore = varietyScore; self.mostRepeatedCombo = mostRepeatedCombo
    }
}

/// Aggregation-friendly period bucket.
public enum AnalyticsPeriod: String, CaseIterable, Codable, Sendable {
    case week = "7d"
    case month = "30d"
    case quarter = "90d"
    case year = "365d"
    case allTime = "all"
}
