import Foundation
import Vision
import CoreML

/// ML service for clothing detection and feature extraction from photos.
/// Uses Vision framework for on-device classification.
@Observable
final class MLService {
    var isProcessing = false
    var error: MLError?

    enum MLError: LocalizedError {
        case noImageProvided
        case classificationFailed(String)
        case featureExtractionFailed(String)

        var errorDescription: String? {
            switch self {
            case .noImageProvided: return "No image provided for analysis."
            case .classificationFailed(let reason): return "Classification failed: \(reason)"
            case .featureExtractionFailed(let reason): return "Feature extraction failed: \(reason)"
            }
        }
    }

    /// Detected clothing item from ML classification.
    struct ClothingDetection: Identifiable {
        let id = UUID()
        let label: String
        let confidence: Float
        let boundingBox: CGRect
    }

    /// Classify clothing items in an image using Vision's built-in classifiers.
    /// - Parameter image: The image to analyze.
    /// - Returns: Array of detected clothing items with bounding boxes.
    func classifyClothing(in image: CGImage) async throws -> [ClothingDetection] {
        isProcessing = true
        defer { isProcessing = false }

        let request = VNRecognizeAnimalsRequest() // Placeholder — will be replaced with custom clothing classifier
        // TODO(TT-T4): Replace with custom CoreML model for clothing classification
        // let config = MLModelConfiguration()
        // let model = try ClothingClassifier(configuration: config)
        // let request = VNCoreMLRequest(model: try VNCoreMLModel(for: model.model))

        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        // Placeholder: return empty detections until custom model is integrated
        return []
    }

    /// Extract feature vector from an image for similarity matching.
    /// - Parameter image: The image to extract features from.
    /// - Returns: Feature vector as [Float].
    func extractFeatures(from image: CGImage) async throws -> [Float] {
        isProcessing = true
        defer { isProcessing = false }

        // TODO(TT-T4): Implement feature extraction using custom CoreML model
        // This will be used to match daily outfit photos against wardrobe items
        return []
    }

    /// Compute cosine similarity between two feature vectors.
    func similarity(between a: [Float], and b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dotProduct = zip(a, b).map { $0 * $1 }.reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        guard magnitudeA > 0, magnitudeB > 0 else { return 0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }
}
