import AVFoundation
import SwiftUI
import os.log

// MARK: - Camera Error

enum CameraError: LocalizedError {
    case permissionDenied
    case configurationFailed(String)
    case captureFailed(String)
    case noSession

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access was denied. Please enable it in System Settings > Privacy & Security > Camera."
        case .configurationFailed(let detail):
            return "Failed to configure camera: \(detail)"
        case .captureFailed(let detail):
            return "Failed to capture photo: \(detail)"
        case .noSession:
            return "Camera session is not running."
        }
    }
}

// MARK: - Camera Service

/// Manages AVFoundation camera session for full-body / mirror selfie capture.
/// Provides a SwiftUI-compatible preview stream and photo capture.
@Observable
final class CameraService: NSObject {

    // MARK: - Published State

    private(set) var isAuthorized = false
    private(set) var isRunning = false
    private(set) var lastError: CameraError?

    /// Live camera feed as a SwiftUI Image (updated on each frame).
    private(set) var previewImage: Image?

    // MARK: - Private

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.threadtrack.camera.session", qos: .userInitiated)
    private let photoProcessingQueue = DispatchQueue(label: "com.threadtrack.camera.photo", qos: .userInitiated)

    private var currentCaptureContinuation: CheckedContinuation<CapturedPhoto, Error>?
    private let logger = Logger(subsystem: "com.threadtrack", category: "CameraService")

    // MARK: - Types

    struct CapturedPhoto: Sendable {
        let originalData: Data
        let thumbnailData: Data?

        /// Write the original photo to a file URL.
        func save(to url: URL) throws {
            try originalData.write(to: url)
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        session.sessionPreset = .photo
    }

    deinit {
        stop()
    }

    // MARK: - Authorization

    /// Request camera permission. Must be called before `start()`.
    @MainActor
    func requestPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            isAuthorized = true
            return true

        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            isAuthorized = granted
            return granted

        case .denied, .restricted:
            isAuthorized = false
            lastError = .permissionDenied
            return false

        @unknown default:
            isAuthorized = false
            lastError = .permissionDenied
            return false
        }
    }

    // MARK: - Session Lifecycle

    /// Configure and start the camera session.
    func start() async throws {
        guard !isRunning else { return }

        do {
            try await configureSession()
            sessionQueue.async { [weak self] in
                self?.session.startRunning()
            }
            // Wait briefly for session to actually start
            try await Task.sleep(for: .milliseconds(500))
            isRunning = session.isRunning
            if !isRunning {
                throw CameraError.configurationFailed("Session failed to start.")
            }
        } catch let error as CameraError {
            lastError = error
            throw error
        } catch {
            let camError = CameraError.configurationFailed(error.localizedDescription)
            lastError = camError
            throw camError
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        isRunning = false
    }

    // MARK: - Configuration

    private func configureSession() async throws {
        let authorized = await requestPermission()
        guard authorized else {
            throw CameraError.permissionDenied
        }

        session.beginConfiguration()

        defer {
            session.commitConfiguration()
        }

        // Video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else {
            // Fall back to rear camera
            guard let rearDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .rear),
                  let rearInput = try? AVCaptureDeviceInput(device: rearDevice)
            else {
                throw CameraError.configurationFailed("No camera device available.")
            }

            if session.canAddInput(rearInput) {
                session.addInput(rearInput)
            } else {
                throw CameraError.configurationFailed("Cannot add rear camera input.")
            }
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            throw CameraError.configurationFailed("Cannot add front camera input.")
        }

        // Configure video output for live preview
        videoOutput.setSampleBufferDelegate(self, queue: photoProcessingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        // Configure photo output for capture
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        photoOutput.isHighResolutionPhotoEnabled = true
    }

    // MARK: - Capture

    /// Capture a photo and return the image data.
    func capturePhoto() async throws -> CapturedPhoto {
        guard isRunning else {
            throw CameraError.noSession
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.currentCaptureContinuation = continuation

            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = true
            settings.flashMode = .off

            if photoOutput.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }

            sessionQueue.async { [weak self] in
                self?.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    // MARK: - Switch Camera

    func switchCamera() async throws {
        let wasRunning = isRunning
        if wasRunning {
            stop()
            try await Task.sleep(for: .milliseconds(300))
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Remove current input
        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)
        }

        // Determine new position
        let newPosition: AVCaptureDevice.Position = (currentInput?.device.position == .front) ? .rear : .front

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            throw CameraError.configurationFailed("Cannot switch to \(newPosition == .front ? "front" : "rear") camera.")
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if wasRunning {
            try await start()
        }
    }

    /// The current camera position.
    var cameraPosition: AVCaptureDevice.Position {
        (session.inputs.first as? AVCaptureDeviceInput)?.device.position ?? .front
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Live Preview)

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])

        // Scale down for preview performance
        let targetSize = CGSize(width: 480, height: 640)
        let scaleX = targetSize.width / ciImage.extent.width
        let scaleY = targetSize.height / ciImage.extent.height
        let scale = min(scaleX, scaleY)

        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return }

        Task { @MainActor in
            self.previewImage = Image(cgImage: cgImage, scale: 1.0, orientation: .rightMirrored)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                self.currentCaptureContinuation?.resume(throwing: CameraError.captureFailed(error.localizedDescription))
                self.currentCaptureContinuation = nil
                return
            }

            guard let data = photo.fileDataRepresentation() else {
                self.currentCaptureContinuation?.resume(throwing: CameraError.captureFailed("No image data received."))
                self.currentCaptureContinuation = nil
                return
            }

            // Generate thumbnail
            let thumbnailData = generateThumbnail(from: data, maxDimension: 200)

            let captured = CapturedPhoto(originalData: data, thumbnailData: thumbnailData)
            self.currentCaptureContinuation?.resume(returning: captured)
            self.currentCaptureContinuation = nil
        }
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        // Capture is starting
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        // Photo captured
    }

    // MARK: - Helpers

    private nonisolated func generateThumbnail(from data: Data, maxDimension: CGFloat) -> Data? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else { return nil }

        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let scale = min(maxDimension / originalWidth, maxDimension / originalHeight, 1.0)

        let newWidth = Int(originalWidth * scale)
        let newHeight = Int(originalHeight * scale)

        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: newWidth * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let thumbnail = context.makeImage() else { return nil }

        let uiImage = UIImage(cgImage: thumbnail)
        return uiImage.jpegData(compressionQuality: 0.7)
    }
}

// MARK: - Camera Preview View

/// SwiftUI view that displays the live camera feed.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = .zero
        return previewLayer
    }

    func updateNSView(_ nsView: AVCaptureVideoPreviewLayer, context: Context) {
        // No-op — session is already set
    }
}
