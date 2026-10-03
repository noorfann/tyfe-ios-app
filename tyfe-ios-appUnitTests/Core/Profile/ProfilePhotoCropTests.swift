import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import tyfe_ios_app

@MainActor
struct ProfilePhotoCropTests {
    @Test func panAndZoomAlwaysFillTheSquareForWideAndTallImages() {
        for imageSize in [CGSize(width: 1200, height: 600), CGSize(width: 600, height: 1200)] {
            for requestedZoom in [CGFloat(0.1), 1, 3, 20] {
                var transform = ProfileCropTransform()
                transform.update(zoom: requestedZoom, offset: CGSize(width: 100, height: -100), imageSize: imageSize)
                let rect = transform.imageRect(imageSize: imageSize, viewport: 320)
                #expect(transform.zoom >= 1 && transform.zoom <= 5)
                #expect(rect.minX <= 0 && rect.minY <= 0)
                #expect(rect.maxX >= 320 && rect.maxY >= 320)
                transform.update(zoom: 1, offset: transform.offset, imageSize: imageSize)
                let reset = transform.imageRect(imageSize: imageSize, viewport: 320)
                #expect(reset.minX <= 0 && reset.minY <= 0)
                #expect(reset.maxX >= 320 && reset.maxY >= 320)
            }
        }
    }

    @Test func decodeAppliesOrientationAndExportRemovesOriginalMetadata() throws {
        let sourceImage = makeTwoColorImage()
        let cgImage = try #require(sourceImage.cgImage)
        let original = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(original, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 51.5, kCGImagePropertyGPSLatitudeRef: "N"],
            kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "private source metadata"]
        ] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let decoded = try ProfilePhotoProcessor.decode(original as Data)
        #expect(decoded.imageOrientation == .up)
        #expect(decoded.size == CGSize(width: 40, height: 80))
        let jpeg = try ProfilePhotoProcessor.export(ProfilePhotoCrop(image: decoded)).jpeg
        #expect(jpeg.count <= 1_000_000)
        let exported = try #require(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(exported, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 512)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 512)
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifUserComment] == nil)
        let orientation = properties[kCGImagePropertyOrientation] as? Int
        #expect(orientation == nil || orientation == 1)
    }

    @Test func exportedPixelsFollowTheManualCropRatherThanTheOriginalCenter() throws {
        let image = makeTwoColorImage()
        let centeredJPEG = try ProfilePhotoProcessor.export(ProfilePhotoCrop(image: image)).jpeg
        let centered = try #require(UIImage(data: centeredJPEG)?.cgImage)
        let left = try pixel(centered, x: 128, y: 256)
        let right = try pixel(centered, x: 384, y: 256)
        #expect(left.red > 200 && left.blue < 60)
        #expect(right.blue > 200 && right.red < 60)
        var crop = ProfilePhotoCrop(image: image)
        crop.transform.update(zoom: 1, offset: CGSize(width: 0.5, height: 0), imageSize: image.size)
        let movedJPEG = try ProfilePhotoProcessor.export(crop).jpeg
        let moved = try #require(UIImage(data: movedJPEG)?.cgImage)
        let movedRight = try pixel(moved, x: 384, y: 256)
        #expect(movedRight.red > 200 && movedRight.blue < 60)
    }

    @Test func mirroredEXIFOrientationIsAppliedBeforeManualCrop() throws {
        let cgImage = try #require(makeTwoColorImage().cgImage)
        let original = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(original, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyOrientation: 2] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        let decoded = try ProfilePhotoProcessor.decode(original as Data)
        let jpeg = try ProfilePhotoProcessor.export(ProfilePhotoCrop(image: decoded)).jpeg
        let mirrored = try #require(UIImage(data: jpeg)?.cgImage)
        let left = try pixel(mirrored, x: 128, y: 256)
        let right = try pixel(mirrored, x: 384, y: 256)
        #expect(left.blue > 200 && left.red < 60)
        #expect(right.red > 200 && right.blue < 60)
    }

    @Test func unreadableLibraryBytesFailWithoutProducingAnUpload() {
        #expect(throws: (any Error).self) { try ProfilePhotoProcessor.decode(Data([1, 2, 3, 4])) }
    }

    private func makeTwoColorImage() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 80, height: 40), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 40, y: 0, width: 40, height: 40))
        }
    }

    private func pixel(_ image: CGImage, x pixelColumn: Int, y pixelRow: Int) throws -> (red: UInt8, blue: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: CGFloat(-pixelColumn), y: CGFloat(-pixelRow), width: CGFloat(image.width), height: CGFloat(image.height)))
        }
        return (bytes[0], bytes[2])
    }
}
