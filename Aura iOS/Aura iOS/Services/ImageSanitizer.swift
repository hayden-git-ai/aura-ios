//
//  ImageSanitizer.swift
//  Aura iOS
//
//  Cleans a user image before it goes to Storage. Every stored photo (Wall of
//  Wins, avatar, support attachments) is routed through this at the upload
//  boundary so none of it can be a metadata-bearing, oversized, or non-image file.
//
//  It does four things in one re-encode:
//   1. Decodes the bytes as an image — non-image data returns nil, so it never
//      reaches storage (a lightweight magic-byte check).
//   2. Downscales to a max edge, capping decoded pixels.
//   3. Re-encodes as JPEG, which drops the original EXIF/GPS/camera metadata (a
//      real privacy leak in raw camera files).
//   4. Enforces a byte ceiling, stepping quality down if needed.
//

import UIKit

enum ImageSanitizer {
    /// Sanitizes raw image bytes into a clean JPEG, or nil if they aren't a
    /// decodable image or can't be brought under `maxBytes`.
    static func sanitizedJPEG(from data: Data,
                              maxDimension: CGFloat = 2048,
                              quality: CGFloat = 0.85,
                              maxBytes: Int = 8 * 1024 * 1024) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return sanitizedJPEG(from: image, maxDimension: maxDimension, quality: quality, maxBytes: maxBytes)
    }

    static func sanitizedJPEG(from image: UIImage,
                              maxDimension: CGFloat = 2048,
                              quality: CGFloat = 0.85,
                              maxBytes: Int = 8 * 1024 * 1024) -> Data? {
        let scaled = downscaled(image, maxDimension: maxDimension)
        guard var jpeg = scaled.jpegData(compressionQuality: quality) else { return nil }
        var q = quality
        while jpeg.count > maxBytes, q > 0.3 {
            q -= 0.15
            guard let smaller = scaled.jpegData(compressionQuality: q) else { break }
            jpeg = smaller
        }
        return jpeg.count <= maxBytes ? jpeg : nil
    }

    /// Downscales so the longest edge is at most `maxDimension`, else returns the
    /// image unchanged. A fresh render also detaches any residual metadata.
    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension, longest > 0 else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
