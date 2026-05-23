import Foundation
import UIKit
import PhotosUI

// MARK: - ClothingImageStore

/// Manages persistent storage of clothing item photos on disk.
/// Images are saved as JPEG in the app's Documents/clothing-images/ directory.
enum ClothingImageStore {

    /// Directory where all clothing photos are stored.
    static let directory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("clothing-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Maximum dimension (width or height) for stored images. Larger images are downscaled.
    static let maxImageDimension: CGFloat = 1024

    /// JPEG compression quality (0.0 to 1.0).
    static let compressionQuality: CGFloat = 0.8

    // MARK: - Save

    /// Save a UIImage to disk and return the filename. Returns nil on failure.
    @discardableResult
    static func save(image: UIImage) -> String? {
        let filename = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        guard let resized = resizeImage(image, maxDimension: maxImageDimension),
              let data = resized.jpegData(compressionQuality: compressionQuality)
        else { return nil }

        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            print("[ClothingImageStore] Failed to save image: \(error)")
            return nil
        }
    }

    /// Save from a PhotosUI PhotosPicker item (async). Returns the filename.
    static func save(from pickerItem: PhotosPickerItem) async -> String? {
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else { return nil }
        return save(image: image)
    }

    // MARK: - Load

    /// Load a UIImage from a stored filename. Returns nil if file doesn't exist.
    static func load(filename: String) -> UIImage? {
        let url = directory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete

    /// Remove a stored photo file.
    static func delete(filename: String) {
        let url = directory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Resize

    /// Downscale an image so its longest edge fits within maxDimension.
    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        let aspectRatio = size.width / size.height
        let newSize: CGSize
        if aspectRatio > 1 {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized
    }
}
