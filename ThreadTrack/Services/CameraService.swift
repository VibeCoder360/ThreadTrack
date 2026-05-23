import Foundation
import AVFoundation
import AppKit

/// Handles camera access and photo capture for clothing and outfit photos.
/// Wraps AVCaptureSession for macOS.
@Observable
final class CameraService {
    var isAuthorized = false
    var isRunning = false
    var capturedImage: NSImage?
    var error: CameraError?

    enum CameraError: LocalizedError {
        case notAuthorized
        case noDeviceAvailable
        case captureFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Camera access denied. Please enable it in System Settings > Privacy & Security > Camera."
            case .noDeviceAvailable: return "No camera device found."
            case .captureFailed(let reason): return "Capture failed: \(reason)"
            }
        }
    }

    private let session = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?

    init() {
        photoOutput = AVCapturePhotoOutput()
        if let output = photoOutput, session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    /// Request camera permission from the user.
    @MainActor
    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isAuthorized = granted
        default:
            isAuthorized = false
        }
    }

    /// Start the capture session.
    func startSession() throws {
        guard isAuthorized else {
            error = .notAuthorized
            throw CameraError.notAuthorized
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) else {
            error = .noDeviceAvailable
            throw CameraError.noDeviceAvailable
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
            session.addInput(input)
        }

        session.startRunning()
        isRunning = true
    }

    /// Stop the capture session.
    func stopSession() {
        session.stopRunning()
        isRunning = false
    }

    /// Capture a still photo.
    func capturePhoto() async throws -> NSImage {
        guard isRunning else {
            throw CameraError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            photoOutput?.capturePhoto(with: settings, delegate: PhotoCaptureDelegate { result in
                switch result {
                case .success(let image):
                    continuation.resume(returning: image)
                case .failure(let error):
                    continuation.resume(throwing: CameraError.captureFailed(error.localizedDescription))
                }
            })
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<NSImage, Error>) -> Void

    init(completion: @escaping (Result<NSImage, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let cgImage = photo.cgImageRepresentation() else {
            completion(.failure(CameraError.captureFailed("No image data")))
            return
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        completion(.success(nsImage))
    }
}
