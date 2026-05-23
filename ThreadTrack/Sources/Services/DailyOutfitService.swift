import Foundation
import PhotosUI
import os.log

// MARK: - Daily Outfit Service

/// Orchestrates the daily outfit workflow:
/// 1. Capture photo (via CameraService)
/// 2. Match clothing items (via ClothingMatcher)
/// 3. Confirm matches → increment wear counts
/// 4. Create DailyOutfit record
/// 5. Generate today's summary
///
/// This service bridges the camera, ML matching, and data persistence layers.
/// It expects the SwiftData models (ClothingItem, DailyOutfit) to exist — defined in T3.
@Observable
final class DailyOutfitService {

    // MARK: - Types

    struct TodaySummary: Sendable {
        let date: Date
        let outfitPhotoData: Data?
        let matchedItems: [MatchedItemSummary]
        let hasOutfitToday: Bool
    }

    struct MatchedItemSummary: Identifiable, Sendable {
        let id: UUID
        let name: String
        let category: String
        let wearsRemaining: Int
        let laundryDue: Bool
        let confidence: Float
    }

    enum DailyOutfitError: LocalizedError {
        case duplicateOutfit
        case photoSaveFailed(String)
        case itemNotFound(UUID)
        case noMatchesConfirmed

        var errorDescription: String? {
            switch self {
            case .duplicateOutfit:
                return "An outfit has already been recorded for today."
            case .photoSaveFailed(let detail):
                return "Failed to save photo: \(detail)"
            case .itemNotFound(let id):
                return "Clothing item \(id) not found in wardrobe."
            case .noMatchesConfirmed:
                return "No clothing items were confirmed for this outfit."
            }
        }
    }

    // MARK: - State

    private(set) var todayOutfit: TodaySummary?
    private(set) var isProcessing = false
    private(set) var lastError: DailyOutfitError?

    // MARK: - Dependencies

    let cameraService: CameraService
    let matcher: ClothingMatcher
    private let logger = Logger(subsystem: "com.threadtrack", category: "DailyOutfitService")

    // MARK: - Photo Storage

    /// Base directory for storing outfit photos.
    private let photosDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let outfitPhotos = appSupport.appendingPathComponent("ThreadTrack/OutfitPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: outfitPhotos, withIntermediateDirectories: true)
        return outfitPhotos
    }()

    // MARK: - Wardrobe Data Access

    /// Protocol for accessing wardrobe data (implemented by the SwiftData repository).
    /// Decouples this service from the specific persistence layer.
    protocol WardrobeRepository: AnyObject {
        /// Fetch all clothing items in the wardrobe.
        func fetchAllItems() -> [WardrobeItem]
        /// Fetch a single item by ID.
        func fetchItem(id: UUID) -> WardrobeItem?
        /// Update an item (wear count, last worn date).
        func updateItem(_ item: WardrobeItem)
        /// Save a DailyOutfit record.
        func saveOutfit(_ outfit: DailyOutfitRecord)
        /// Check if an outfit already exists for today.
        func hasOutfitForToday() -> Bool
        /// Fetch today's outfit if it exists.
        func fetchTodayOutfit() -> DailyOutfitRecord?
    }

    /// Wardrobe item data (mirrors SwiftData ClothingItem model).
    struct WardrobeItem {
        let id: UUID
        let name: String
        let category: String
        let photoData: Data?
        let wearCount: Int
        let maxWearsBeforeLaundry: Int
        let lastWornDate: Date?
        let laundryDue: Bool
    }

    /// Daily outfit record (mirrors SwiftData DailyOutfit model).
    struct DailyOutfitRecord {
        let id: UUID
        let date: Date
        let photoPath: String?
        let matchedItemIds: [UUID]
    }

    weak var wardrobeRepo: WardrobeRepository?

    // MARK: - Init

    init(cameraService: CameraService, matcher: ClothingMatcher) {
        self.cameraService = cameraService
        self.matcher = matcher
    }

    // MARK: - Core Workflow

    /// Check if an outfit has already been recorded today.
    func checkTodayStatus() -> Bool {
        guard let repo = wardrobeRepo else { return false }
        return repo.hasOutfitForToday()
    }

    /// Load today's summary if an outfit exists.
    func loadTodaySummary() {
        guard let repo = wardrobeRepo else { return }
        guard let outfit = repo.fetchTodayOutfit() else {
            todayOutfit = nil
            return
        }

        var itemSummaries: [MatchedItemSummary] = []
        for itemId in outfit.matchedItemIds {
            guard let item = repo.fetchItem(id: itemId) else { continue }
            itemSummaries.append(MatchedItemSummary(
                id: item.id,
                name: item.name,
                category: item.category,
                wearsRemaining: max(0, item.maxWearsBeforeLaundry - item.wearCount),
                laundryDue: item.laundryDue,
                confidence: 1.0  // Already confirmed
            ))
        }

        todayOutfit = TodaySummary(
            date: outfit.date,
            outfitPhotoData: loadPhotoData(at: outfit.photoPath),
            matchedItems: itemSummaries,
            hasOutfitToday: true
        )
    }

    // MARK: - Step 1: Capture Photo

    /// Start the camera for outfit capture.
    func startCamera() async throws {
        try await cameraService.start()
    }

    func stopCamera() {
        cameraService.stop()
    }

    /// Capture a full-body / mirror selfie.
    /// Returns the raw image data and saves it to the photo store.
    @discardableResult
    func captureOutfitPhoto() async throws -> Data {
        let captured = try await cameraService.capturePhoto()

        // Save to photo store
        let filename = "outfit_\(Date.now.timeIntervalSince1970).jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try captured.save(to: fileURL)

        logger.info("Saved outfit photo to \(fileURL.lastPathComponent)")
        return captured.originalData
    }

    // MARK: - Step 2: Match Clothing Items

    /// Run ML matching on the captured photo against the wardrobe catalog.
    ///
    /// - Parameter imageData: The captured outfit photo.
    /// - Returns: Array of potential matches sorted by confidence.
    func matchClothing(in imageData: Data) async throws -> [ClothingMatch] {
        guard let repo = wardrobeRepo else {
            throw DailyOutfitError.noMatchesConfirmed
        }

        let allItems = repo.fetchAllItems()
        let itemInfos = allItems.map {
            WardrobeItemInfo(
                id: $0.id,
                name: $0.name,
                category: $0.category,
                thumbnailData: $0.photoData
            )
        }

        let matches = try await matcher.matchPhoto(imageData, against: itemInfos)
        return matches
    }

    /// Detect clothing regions in the photo for context.
    func detectRegions(in imageData: Data) async throws -> [ClothingMatcher.ClothingRegion] {
        try await matcher.detectClothingRegions(in: imageData)
    }

    // MARK: - Step 3: Confirm Matches & Update Wear Counts

    /// Confirm matched items, increment wear counts, and create the DailyOutfit record.
    ///
    /// - Parameters:
    ///   - confirmedMatches: The matches the user confirmed.
    ///   - photoData: The captured outfit photo data.
    ///   - photoPath: Optional path if photo was already saved.
    func confirmOutfit(
        confirmedMatches: [ClothingMatch],
        photoData: Data,
        photoPath: String? = nil
    ) async throws {
        guard let repo = wardrobeRepo else {
            throw DailyOutfitError.noMatchesConfirmed
        }

        guard !confirmedMatches.isEmpty else {
            throw DailyOutfitError.noMatchesConfirmed
        }

        // Check for duplicate
        if repo.hasOutfitForToday() {
            throw DailyOutfitError.duplicateOutfit
        }

        isProcessing = true
        defer { isProcessing = false }

        let now = Date()

        // Update each matched item
        var updatedItems: [MatchedItemSummary] = []

        for match in confirmedMatches {
            guard var item = repo.fetchItem(id: match.id) else {
                logger.warning("Item \(match.id) not found during outfit confirmation, skipping")
                continue
            }

            // Increment wear count
            item.wearCount += 1
            item.lastWornDate = now

            // Check laundry due
            if item.wearCount >= item.maxWearsBeforeLaundry {
                item.laundryDue = true
            }

            repo.updateItem(item)

            updatedItems.append(MatchedItemSummary(
                id: item.id,
                name: item.name,
                category: item.category,
                wearsRemaining: max(0, item.maxWearsBeforeLaundry - item.wearCount),
                laundryDue: item.laundryDue,
                confidence: match.confidence
            ))

            logger.info("Updated item '\(item.name)': wearCount=\(item.wearCount), laundryDue=\(item.laundryDue)")
        }

        // Save photo if not already saved
        let savedPhotoPath = photoPath ?? savePhoto(photoData)

        // Create DailyOutfit record
        let outfit = DailyOutfitRecord(
            id: UUID(),
            date: now,
            photoPath: savedPhotoPath,
            matchedItemIds: confirmedMatches.map(\.id)
        )
        repo.saveOutfit(outfit)

        // Update today summary
        todayOutfit = TodaySummary(
            date: now,
            outfitPhotoData: photoData,
            matchedItems: updatedItems,
            hasOutfitToday: true
        )

        logger.info("Created daily outfit with \(confirmedMatches.count) items")
    }

    // MARK: - Step 4: Manual Tag Mode (Approach A)

    /// User manually selects wardrobe items to tag in the photo.
    /// Skips ML matching entirely.
    func manualTagOutfit(
        selectedItems: [WardrobeItemInfo],
        photoData: Data
    ) async throws {
        let manualMatches = selectedItems.map {
            matcher.manualMatch(wardrobeItemId: $0.id, name: $0.name, category: $0.category)
        }

        try await confirmOutfit(confirmedMatches: manualMatches, photoData: photoData)
    }

    // MARK: - Photo Helpers

    private func savePhoto(_ data: Data) -> String {
        let filename = "outfit_\(Int(Date.now.timeIntervalSince1970)).jpg"
        let fileURL = photosDirectory.appendingPathComponent(filename)
        try? data.write(to: fileURL)
        return fileURL.path
    }

    private func loadPhotoData(at path: String?) -> Data? {
        guard let path else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: path))
    }

    // MARK: - Rebuild Wardrobe Index

    /// Rebuild the ML feature print index from all wardrobe items with photos.
    /// Should be called on app launch or when items change.
    func rebuildWardrobeIndex() async {
        guard let repo = wardrobeRepo else { return }

        let items = repo.fetchAllItems()
        let itemsWithPhotos = items.compactMap { item -> (id: UUID, imageData: Data)? in
            guard let photoData = item.photoData else { return nil }
            return (item.id, photoData)
        }

        await matcher.rebuildWardrobeIndex(items: itemsWithPhotos)
    }

    // MARK: - Utility

    /// Calculate wears remaining for an item.
    static func wearsRemaining(wearCount: Int, maxWears: Int) -> Int {
        max(0, maxWears - wearCount)
    }
}
