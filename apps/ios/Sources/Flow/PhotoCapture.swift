import SwiftUI
import PhotosUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

// One-tap field capture. Device = the camera directly (zero chrome, zero
// confirm — gloves and speed rule out anything else); simulator / no-camera
// = PhotosPicker fallback so the flow stays exercisable everywhere.

/// Downsize a captured photo before it's stored. A field photo needs to be
/// legible on a document, not 48-megapixel — and a full-res capture (12–48 MP)
/// decoded + re-encoded WHILE a live whisper walk already holds the model +
/// Metal context in memory is a classic out-of-memory (jetsam) kill. This is
/// the fix for the field crash "app crashed when uploading a photo": cap the
/// longest edge and keep peak memory bounded.
enum PhotoDownsize {
    /// Longest-edge cap in pixels. 2048 is sharp for a letter-size document
    /// while ~10–30× smaller in bytes + memory than a raw capture.
    static let maxPixel = 2048.0
    static let quality = 0.8

    /// Memory-efficient path (picker / any encoded Data): ImageIO downsamples
    /// straight from the source without fully decoding the full-res image.
    static func jpeg(fromData data: Data) -> Data {
        guard let src = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return data }
        let opts = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honor EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts),
              let out = UIImage(cgImage: cg).jpegData(compressionQuality: quality) else { return data }
        return out
    }

    /// Camera path: the picker already handed us a decoded UIImage. Cap the
    /// dimension BEFORE the JPEG encode (where a second full-res allocation
    /// would otherwise blow up), preserving orientation.
    static func jpeg(fromImage image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxPixel else { return image.jpegData(compressionQuality: quality) }
        let scale = maxPixel / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.scale = 1
        let scaled = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return scaled.jpegData(compressionQuality: quality)
    }
}

struct CameraCapture: UIViewControllerRepresentable {
    var onImage: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = PhotoDownsize.jpeg(fromImage: image) {
                parent.onImage(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
