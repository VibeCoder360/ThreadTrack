import Vision
import CoreML
import CoreImage
import Accelerate
import os.log

// MARK: - Match Types

/// A clothing match result with confidence score.
struct ClothingMatch: Identifiable, Sendable {
    let id: UUID              // Matches ClothingItem.id
    let name: String
    let category: String
    let confidence: Float     // 0.0 to 1.0 cosine similarity
    let featurePrint: FeaturePrint

    /// Sort by confidence descending (best match first).
    static func bestFirst(_ a: ClothingMatch, _ b: ClothingMatch) -> Bool {
        a.confidence > b.confidence
    }
}

/// A feature print extracted from an image.
struct FeaturePrint: Sendable {
    let vector: [Float]
    let imageWidth: Int
    let imageHeight: Int

    /// Dimensionality of the feature vector.
    var dimension: Int { vector.count }

    /// Cosine similarity between two feature prints.
    func cosineSimilarity(to other: FeaturePrint) -> Float {
        guard vector.count == other.vector.count, vector.count > 0 else { return 0.0 }

        var dotProduct: Float = 0.0
        var normA: Float = 0.0
        var normB: Float = 0.0

        for i in 0..<vector.count {
            dotProduct += vector[i] * other.vector[i]
            normA += vector[i] * vector[i]
            normB += other.vector[i] * other.vector[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        return denominator > 0 ? dotProduct / denominator : 0.0
    }
}

// MARK: - Clothing Matcher Error

enum ClothingMatcherError: LocalizedError {
    case featurePrintUnavailable
    case noWardrobeItems
    case imageProcessingFailed(String)
    case regionDetectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .featurePrintUnavailable:
            return "Feature print extraction is not available on this device."
        case .noWardrobeItems:
            return "No wardrobe items to match against."
        case .imageProcessingFailed(let detail):
            return "Image processing failed: \(detail)"
        case .regionDetectionFailed(let detail):
            return "Region detection failed: \(detail)"
        }
    }
}

// MARK: - Clothing Matcher

/// Matches clothing items in a photo against the user's wardrobe catalog.
///
/// Uses two approaches:
/// - **Feature print similarity**: Extracts Vision feature vectors from the captured photo
///   and compares against pre-computed wardrobe feature prints using cosine similarity.
/// - **Manual tagging** (Approach A fallback): User taps regions and selects items from catalog.
///
/// The feature print approach is Approach B — more advanced but depends on the Vision framework's
/// ability to generate meaningful feature vectors.
@Observable
final class ClothingMatcher {

    // MARK: - Configuration

    /// Minimum confidence threshold for an automatic match to be considered valid.
    var matchThreshold: Float = 0.75

    /// Maximum number of matches to return per query.
    var maxResults: Int = 5

    /// When true, also runs region detection to find distinct clothing regions.
    var detectRegions: Bool = true

    // MARK: - State

    private(set) var isProcessing = false
    private(set) var lastError: ClothingMatcherError?

    /// Detected clothing regions in the last analyzed image (bounding boxes + labels).
    private(set) var detectedRegions: [ClothingRegion] = []

    // MARK: - Private

    private let logger = Logger(subsystem: "com.threadtrack", category: "ClothingMatcher")
    private let processingQueue = DispatchQueue(label: "com.threadtrack.matcher", qos: .userInitiated)

    // MARK: - Wardrobe Feature Print Store

    /// In-memory store of wardrobe feature prints. In production, this persists alongside
    /// SwiftData ClothingItem records (the FeaturePrint is stored as binary on ClothingItem).
    private var wardrobePrints: [UUID: FeaturePrint] = [:]

    /// Register a wardrobe item's feature print for matching.
    func registerFeaturePrint(for itemId: UUID, print: FeaturePrint) {
        wardrobePrints[itemId] = print
        logger.info("Registered feature print for item \(itemId), dim=\(print.dimension)")
    }

    /// Remove a wardrobe item's feature print.
    func removeFeaturePrint(for itemId: UUID) {
        wardrobePrints.removeValue(forKey: itemId)
    }

    /// Get all registered item IDs.
    var registeredItemIds: Set<UUID> {
        Set(wardrobePrints.keys)
    }

    // MARK: - Feature Print Extraction

    /// Extract a Vision feature print from image data.
    func extractFeaturePrint(from imageData: Data) async throws -> FeaturePrint {
        isProcessing = true
        defer { isProcessing = false }

        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: ClothingMatcherError.featurePrintUnavailable)
                    return
                }

                do {
                    let handler = VNImageRequestHandler(data: imageData, options: [:])
                    let featurePrintRequest = VNFeaturePrintObservation.request(type: .image)

                    try handler.perform([featurePrintRequest])

                    guard let observation = featurePrintRequest.results?.first as? VNFeaturePrintObservation
                    else {
                        continuation.resume(throwing: ClothingMatcherError.featurePrintUnavailable)
                        return
                    }

                    let floatCount = observation.elementCount
                    var floats = [Float](repeating: 0.0, count: floatCount)

                    try observation.data(with: &floats)

                    // Get image dimensions
                    let ciImage = CIImage(data: imageData)
                    let width = ciImage?.extent.width ?? 0
                    let height = ciImage?.extent.height ?? 0

                    let fp = FeaturePrint(
                        vector: floats,
                        imageWidth: Int(width),
                        imageHeight: Int(height)
                    )

                    self.logger.info("Extracted feature print: \(floatCount) floats from image")

                    continuation.resume(returning: fp)
                } catch {
                    continuation.resume(
                        throwing: ClothingMatcherError.imageProcessingFailed(error.localizedDescription)
                    )
                }
            }
        }
    }

    // MARK: - Region Detection

    /// Detected clothing region in a photo.
    struct ClothingRegion: Identifiable, Sendable {
        let id = UUID()
        let label: String           // e.g. "Shirt", "Pants", "Shoe"
        let confidence: Float
        let boundingBox: CGRect     // Normalized 0...1
    }

    /// Detect clothing regions in the photo using a classification request.
    func detectClothingRegions(in imageData: Data) async throws -> [ClothingRegion] {
        guard detectRegions else { return [] }

        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: ClothingMatcherError.regionDetectionFailed("Matcher deallocated"))
                    return
                }

                let handler: VNImageRequestHandler
                do {
                    handler = VNImageRequestHandler(data: imageData, options: [:])
                } catch {
                    continuation.resume(
                        throwing: ClothingMatcherError.regionDetectionFailed(error.localizedDescription)
                    )
                    return
                }

                // Use VNClassifyImageRequest with a scene classification model
                let classifyRequest = VNClassifyImageRequest { request, error in
                    if let error = error {
                        continuation.resume(
                            throwing: ClothingMatcherError.regionDetectionFailed(error.localizedDescription)
                        )
                        return
                    }

                    guard let observations = request.results as? [VNClassificationObservation]
                    else {
                        continuation.resume(returning: [])
                        return
                    }

                    // Filter to clothing-related classifications
                    let clothingKeywords = [
                        "shirt", "pants", "dress", "shoe", "hat", "jacket", "coat", "sweater",
                        "skirt", "shorts", "t-shirt", "jeans", "sneaker", "boot", "hoodie",
                        "blazer", "vest", "sock", "scarf", "glove", "belt", "tie", "top",
                        "bottom", "outerwear", "footwear", "accessory"
                    ]

                    let regions = observations
                        .compactMap { obs -> ClothingRegion? in
                            let label = obs.identifier.lowercased()
                            let isClothing = clothingKeywords.contains { keyword in
                                label.contains(keyword)
                            }
                            guard isClothing, obs.confidence > 0.3 else { return nil }

                            return ClothingRegion(
                                label: obs.identifier,
                                confidence: Float(obs.confidence),
                                boundingBox: .zero  // Classification doesn't provide bounding boxes
                            )
                        }
                        .sorted { $0.confidence > $1.confidence }

                    continuation.resume(returning: regions)
                }

                classifyRequest.revision = VNClassifyImageRequestRevision1

                do {
                    try handler.perform([classifyRequest])
                } catch {
                    continuation.resume(
                        throwing: ClothingMatcherError.regionDetectionFailed(error.localizedDescription)
                    )
                }
            }
        }
    }

    // MARK: - Matching

    /// Match a captured photo against the wardrobe catalog.
    ///
    /// Flow:
    /// 1. Extract feature print from the photo.
    /// 2. Compute cosine similarity against all wardrobe feature prints.
    /// 3. Filter by threshold, sort by confidence.
    /// 4. Optionally detect clothing regions for context.
    ///
    /// - Parameters:
    ///   - imageData: The captured photo data.
    ///   - wardrobeItems: Metadata about wardrobe items (id, name, category) for results.
    ///   - onlyCategories: Optional filter — only match items in these categories.
    /// - Returns: Array of matches sorted by confidence (best first).
    func matchPhoto(
        _ imageData: Data,
        against wardrobeItems: [WardrobeItemInfo],
        onlyCategories: Set<String>? = nil
    ) async throws -> [ClothingMatch] {
        isProcessing = true
        defer { isProcessing = false }

        guard !wardrobePrints.isEmpty else {
            throw ClothingMatcherError.noWardrobeItems
        }

        // Extract feature print from the photo
        let photoPrint = try await extractFeaturePrint(from: imageData)

        // Compute similarities
        var matches: [ClothingMatch] = []

        for item in wardrobeItems {
            guard let wardrobeFP = wardrobePrints[item.id] else { continue }

            // Filter by category if specified
            if let onlyCategories, !onlyCategories.contains(item.category) {
                continue
            }

            let similarity = photoPrint.cosineSimilarity(to: wardrobeFP)

            if similarity >= matchThreshold {
                matches.append(ClothingMatch(
                    id: item.id,
                    name: item.name,
                    category: item.category,
                    confidence: similarity,
                    featurePrint: photoPrint
                ))
            }
        }

        // Sort by confidence, take top N
        matches.sort(by: ClothingMatch.bestFirst)
        let result = Array(matches.prefix(maxResults))

        logger.info("Matched \(result.count) items (threshold=\(self.matchThreshold), checked=\(wardrobeItems.count))")

        return result
    }

    /// Manual match: user explicitly tags an item. Still records the association
    /// but bypasses the ML threshold.
    func manualMatch(
        wardrobeItemId: UUID,
        name: String,
        category: String
    ) -> ClothingMatch {
        ClothingMatch(
            id: wardrobeItemId,
            name: name,
            category: category,
            confidence: 1.0,
            featurePrint: FeaturePrint(vector: [], imageWidth: 0, imageHeight: 0)
        )
    }

    // MARK: - Batch Feature Print Extraction

    /// Extract and register feature prints for all wardrobe items with photos.
    /// Call this when the app launches or when new items are added.
    func rebuildWardrobeIndex(items: [(id: UUID, imageData: Data)]) async {
        isProcessing = true
        defer { isProcessing = false }

        logger.info("Rebuilding wardrobe index for \(items.count) items")

        for (itemId, imageData) in items {
            do {
                let fp = try await extractFeaturePrint(from: imageData)
                registerFeaturePrint(for: itemId, print: fp)
            } catch {
                logger.warning("Failed to extract feature print for item \(itemId): \(error.localizedDescription)")
            }
        }

        logger.info("Wardrobe index rebuilt: \(wardrobePrints.count) prints registered")
    }
}

// MARK: - Wardrobe Item Info (Lightweight reference for matching)

/// Lightweight metadata about a wardrobe item, used as input to the matcher.
/// Avoids pulling full SwiftData models into the ML service layer.
struct WardrobeItemInfo: Sendable, Identifiable {
    let id: UUID
    let name: String
    let category: String
    let thumbnailData: Data?
}
