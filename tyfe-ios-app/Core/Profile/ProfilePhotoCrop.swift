import ImageIO
import UIKit

/// Offset is expressed in crop-width units, so rotation and layout changes preserve the crop.
struct ProfileCropTransform: Equatable {
    private(set) var zoom: CGFloat = 1
    private(set) var offset: CGSize = .zero

    func displayedSize(imageSize: CGSize, viewport: CGFloat) -> CGSize {
        let fillScale = viewport / min(imageSize.width, imageSize.height)
        return CGSize(width: imageSize.width * fillScale * zoom, height: imageSize.height * fillScale * zoom)
    }

    mutating func update(zoom: CGFloat, offset: CGSize, imageSize: CGSize) {
        self.zoom = min(5, max(1, zoom))
        let displayed = displayedSize(imageSize: imageSize, viewport: 1)
        let maxX = max(0, (displayed.width - 1) / 2)
        let maxY = max(0, (displayed.height - 1) / 2)
        self.offset = CGSize(width: min(maxX, max(-maxX, offset.width)), height: min(maxY, max(-maxY, offset.height)))
    }

    func imageRect(imageSize: CGSize, viewport: CGFloat) -> CGRect {
        let size = displayedSize(imageSize: imageSize, viewport: viewport)
        return CGRect(
            x: (viewport - size.width) / 2 + offset.width * viewport,
            y: (viewport - size.height) / 2 + offset.height * viewport,
            width: size.width, height: size.height
        )
    }
}

struct ProfilePhotoCrop: Identifiable {
    let id = UUID()
    let image: UIImage
    var transform = ProfileCropTransform()
}

enum ProfilePhotoError: LocalizedError {
    case unreadableImage
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "This photo could not be opened. Try another photo or try again."
        case .encodingFailed: return "This photo could not be prepared. Try again or choose another photo."
        }
    }
}

@MainActor
enum ProfilePhotoProcessor {
    static let outputSide = 512
    static let maximumBytes = 1_000_000

    static func decode(_ data: Data) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 2048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw ProfilePhotoError.unreadableImage }
        // ImageIO applies all EXIF orientation/mirroring before exposing pixels to the crop.
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    static func export(_ crop: ProfilePhotoCrop) throws -> (jpeg: Data, image: UIImage) {
        let side = CGFloat(outputSide)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let rendered = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            crop.image.draw(in: crop.transform.imageRect(imageSize: crop.image.size, viewport: side))
        }
        // Fresh pixels and fresh JPEG encoding: no original EXIF, GPS, IPTC, or source metadata is copied.
        for quality in [CGFloat(0.9), 0.75, 0.6, 0.4, 0.2] {
            if let jpeg = rendered.jpegData(compressionQuality: quality), jpeg.count <= maximumBytes {
                return (jpeg, rendered)
            }
        }
        throw ProfilePhotoError.encodingFailed
    }
}
