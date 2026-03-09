//
//  CursorImageScaler.swift
//  Mousecape
//
//  Shared constants and image scaling utilities for cursor import.
//  Used by both AppState (folder import) and EditOverlayView (single cursor import).
//

import AppKit

/// Shared constants and image scaling utilities for cursor import
enum CursorImageScaler {

    // MARK: - Constants

    /// Standard cursor size in pixels for 2x HiDPI (64x64 pixels = 32x32 points)
    static let standardCursorSize: Int = 64

    /// Maximum animation frame count (macOS system limit)
    static let maxFrameCount: Int = 24

    /// Maximum individual frame size for import validation (pixels)
    static let maxImportSize: Int = 512

    // MARK: - Static Image Scaling

    /// Scale image to standard 64x64 size with aspect fit and transparent padding
    static func scaleImageToStandardSize(_ original: NSBitmapImageRep) -> NSBitmapImageRep? {
        let targetSize = standardCursorSize

        guard let sourceCGImage = original.cgImage else { return nil }

        // Calculate aspect-fit scaling
        let originalWidth = CGFloat(original.pixelsWide)
        let originalHeight = CGFloat(original.pixelsHigh)
        let targetSizeF = CGFloat(targetSize)

        let scale = min(targetSizeF / originalWidth, targetSizeF / originalHeight)
        let scaledWidth = originalWidth * scale
        let scaledHeight = originalHeight * scale

        // Center the image
        let offsetX = (targetSizeF - scaledWidth) / 2
        let offsetY = (targetSizeF - scaledHeight) / 2

        // Use CGContext directly (thread-safe, no NSGraphicsContext overhead)
        guard let context = CGContext(
            data: nil,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        let destRect = CGRect(x: offsetX, y: offsetY, width: scaledWidth, height: scaledHeight)
        context.draw(sourceCGImage, in: destRect)

        guard let resultImage = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: resultImage)
    }

    // MARK: - Sprite Sheet Scaling

    /// Scale a sprite sheet (animated cursor with multiple frames stacked vertically)
    /// Crops each frame individually before scaling to prevent interpolation bleed across frame boundaries.
    static func scaleSpriteSheet(
        _ original: NSBitmapImageRep,
        frameCount: Int,
        originalFrameWidth: Int,
        originalFrameHeight: Int
    ) -> NSBitmapImageRep? {
        let targetSize = standardCursorSize

        guard let fullCGImage = original.cgImage else { return nil }

        // Calculate aspect-fit scaling
        let originalWidth = CGFloat(originalFrameWidth)
        let originalHeight = CGFloat(originalFrameHeight)
        let targetSizeF = CGFloat(targetSize)

        let scale = min(targetSizeF / originalWidth, targetSizeF / originalHeight)
        let scaledWidth = originalWidth * scale
        let scaledHeight = originalHeight * scale

        // Center offset
        let offsetX = (targetSizeF - scaledWidth) / 2
        let offsetY = (targetSizeF - scaledHeight) / 2

        let totalDestHeight = targetSize * frameCount

        // Use CGContext directly (thread-safe, no NSGraphicsContext overhead)
        guard let context = CGContext(
            data: nil,
            width: targetSize,
            height: totalDestHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high

        for frameIndex in 0..<frameCount {
            // Crop frame from sprite sheet using CGImage (top-left origin, integer pixels)
            let cropRect = CGRect(x: 0, y: frameIndex * originalFrameHeight, width: originalFrameWidth, height: originalFrameHeight)
            guard let frameCGImage = fullCGImage.cropping(to: cropRect) else { continue }

            // Destination rect: frame 0 should be at top of new sprite sheet (bottom-left coords)
            let dstY = CGFloat(totalDestHeight - (frameIndex + 1) * targetSize) + offsetY
            let dstRect = CGRect(x: offsetX, y: dstY, width: scaledWidth, height: scaledHeight)

            context.draw(frameCGImage, in: dstRect)
        }

        guard let resultImage = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: resultImage)
    }

    // MARK: - Frame Downsampling

    /// Downsample frames to target count using uniform sampling.
    /// Preserves first and last frames, evenly samples in between.
    static func downsampleFrames(_ frames: [NSBitmapImageRep], targetCount: Int) -> [NSBitmapImageRep] {
        guard frames.count > targetCount else { return frames }

        var result: [NSBitmapImageRep] = []
        let step = Double(frames.count - 1) / Double(targetCount - 1)

        for i in 0..<targetCount {
            let sourceIndex = Int(round(Double(i) * step))
            let clampedIndex = min(sourceIndex, frames.count - 1)
            result.append(frames[clampedIndex])
        }

        return result
    }

    // MARK: - Sprite Sheet Creation

    /// Create a vertical sprite sheet from individual frames
    /// Uses CGContext for thread safety (no NSGraphicsContext dependency)
    static func createSpriteSheet(
        from frames: [NSBitmapImageRep],
        frameWidth: Int,
        frameHeight: Int
    ) -> NSBitmapImageRep? {
        let sheetHeight = frameHeight * frames.count

        guard let context = CGContext(
            data: nil,
            width: frameWidth,
            height: sheetHeight,
            bitsPerComponent: 8,
            bytesPerRow: frameWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Draw each frame
        // CGContext uses bottom-left origin coordinate system
        // Frame 0 should be at the TOP of the sprite sheet (highest Y in bottom-left coords)
        for (index, frame) in frames.enumerated() {
            guard let cgImage = frame.cgImage else { continue }
            let y = sheetHeight - (index + 1) * frameHeight
            context.draw(cgImage, in: CGRect(x: 0, y: y, width: frameWidth, height: frameHeight))
        }

        guard let resultImage = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: resultImage)
    }

    // MARK: - Bitmap Helpers

    /// Get original bitmap representation from an NSImage
    static func getOriginalBitmapRep(from image: NSImage) -> NSBitmapImageRep? {
        // First try to get existing bitmap rep
        for rep in image.representations {
            if let bitmapRep = rep as? NSBitmapImageRep {
                return bitmapRep
            }
        }

        // Create new bitmap by drawing the image
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return NSBitmapImageRep(cgImage: cgImage)
    }

    // MARK: - Hotspot Calculation

    /// Calculate scaled hotspot coordinates for a cursor result
    static func calculateScaledHotspot(
        hotspotX: Int,
        hotspotY: Int,
        originalWidth: Int,
        originalHeight: Int
    ) -> (x: CGFloat, y: CGFloat) {
        let originalWidthF = CGFloat(originalWidth)
        let originalHeightF = CGFloat(originalHeight)
        let targetSizeF = CGFloat(standardCursorSize)  // 64 pixels
        let scale = min(targetSizeF / originalWidthF, targetSizeF / originalHeightF)
        let scaledWidth = originalWidthF * scale
        let scaledHeight = originalHeightF * scale
        let offsetX = (targetSizeF - scaledWidth) / 2
        let offsetY = (targetSizeF - scaledHeight) / 2

        // Calculate hotspot in pixels, then convert to points
        let hotspotPixelsX = CGFloat(hotspotX) * scale + offsetX
        let hotspotPixelsY = CGFloat(hotspotY) * scale + offsetY

        // Convert to points (divide by 2 for 2x scale)
        // Also clamp to valid range [0, 32)
        let pointsSize: CGFloat = 32.0
        let hotspotPointsX = min(max(hotspotPixelsX / 2.0, 0), pointsSize - 0.1)
        let hotspotPointsY = min(max(hotspotPixelsY / 2.0, 0), pointsSize - 0.1)

        return (hotspotPointsX, hotspotPointsY)
    }
}
