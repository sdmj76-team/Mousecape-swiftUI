//
//  Cursor.swift
//  Mousecape
//
//  Swift wrapper for MCCursor
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import ImageIO

/// Swift wrapper around MCCursor for SwiftUI usage
@Observable
final class Cursor: Identifiable, Hashable {
    let id: UUID
    private let objcCursor: MCCursor

    /// Cached image to avoid repeated NSImage allocation from imageWithAllReps
    private var _cachedImage: NSImage?

    // MARK: - Properties (bridged from ObjC)

    var identifier: String {
        get { objcCursor.identifier }
        set { objcCursor.identifier = newValue }
    }

    var name: String {
        // First try ObjC cursor name
        let objcName = objcCursor.name
        if !objcName.isEmpty {
            return objcName
        }
        // Then try to extract from identifier
        if !identifier.isEmpty, let lastName = identifier.components(separatedBy: ".").last, !lastName.isEmpty {
            return lastName
        }
        return "Unknown"
    }

    var displayName: String {
        // First check if we have a known cursor type - use its display name
        if let type = CursorType(rawValue: identifier) {
            return type.displayName
        }
        // Clean up the name for display
        let baseName = name
        // Convert camelCase to Title Case with spaces
        var result = ""
        for char in baseName {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result.isEmpty ? "Cursor" : result
    }

    var frameDuration: CGFloat {
        get { objcCursor.frameDuration }
        set { objcCursor.frameDuration = newValue }
    }

    var frameCount: Int {
        get { Int(objcCursor.frameCount) }
        set { objcCursor.frameCount = UInt(newValue) }
    }

    var size: NSSize {
        get { objcCursor.size }
        set { objcCursor.size = newValue }
    }

    var hotSpot: NSPoint {
        get { objcCursor.hotSpot }
        set { objcCursor.hotSpot = newValue }
    }

    var isAnimated: Bool {
        frameCount > 1
    }

    // MARK: - Image Access

    /// Get the full image with all representations (cached)
    var image: NSImage? {
        if let cached = _cachedImage {
            return cached
        }
        let img = objcCursor.imageWithAllReps()
        _cachedImage = img
        return img
    }

    /// Invalidate cached image (call after image data changes)
    func invalidateImageCache() {
        _cachedImage = nil
    }

    /// Get representation at specific scale
    func representation(for scale: CursorScale) -> NSImageRep? {
        guard let mcScale = MCCursorScale(rawValue: UInt(scale.rawValue)) else {
            return nil
        }
        return objcCursor.representation(for: mcScale)
    }

    /// Set representation at specific scale
    func setRepresentation(_ imageRep: NSImageRep, for scale: CursorScale) {
        guard let mcScale = MCCursorScale(rawValue: UInt(scale.rawValue)) else {
            return
        }
        objcCursor.setRepresentation(imageRep, for: mcScale)
        invalidateImageCache()
    }

    /// Remove representation at specific scale
    func removeRepresentation(for scale: CursorScale) {
        guard let mcScale = MCCursorScale(rawValue: UInt(scale.rawValue)) else {
            return
        }
        objcCursor.removeRepresentation(for: mcScale)
        invalidateImageCache()
    }

    /// Check if a representation exists for scale
    func hasRepresentation(for scale: CursorScale) -> Bool {
        representation(for: scale) != nil
    }

    /// Check if cursor has any actual image data
    var hasAnyRepresentation: Bool {
        for scale in CursorScale.allCases {
            if hasRepresentation(for: scale) {
                return true
            }
        }
        return false
    }

    // MARK: - Cursor Type

    var cursorType: CursorType? {
        CursorType(rawValue: identifier)
    }

    // MARK: - Initialization

    init(objcCursor: MCCursor) {
        self.id = UUID()
        self.objcCursor = objcCursor
    }

    /// Create a new empty cursor with identifier
    convenience init(identifier: String) {
        let cursor = MCCursor()
        cursor.identifier = identifier
        cursor.frameCount = 1
        cursor.frameDuration = 1.0  // Default 1 fps
        cursor.size = NSSize(width: 32, height: 32)  // Default size
        cursor.hotSpot = NSPoint(x: 0, y: 0)
        self.init(objcCursor: cursor)
    }

    /// Initialize from dictionary (for .cape file deserialization)
    /// - Parameters:
    ///   - dictionary: Dictionary containing cursor data
    ///   - version: Cape file version (should be >= 2.0)
    /// - Returns: nil if dictionary is invalid or version is unsupported
    convenience init?(dictionary: [String: Any], version: CGFloat) {
        // We only support version 2.0+
        guard version >= 2.0 else { return nil }

        // Extract required keys
        guard let frameCount = dictionary["FrameCount"] as? NSNumber,
              let frameDuration = dictionary["FrameDuration"] as? NSNumber,
              let hotSpotX = dictionary["HotSpotX"] as? NSNumber,
              let hotSpotY = dictionary["HotSpotY"] as? NSNumber,
              let pointsWide = dictionary["PointsWide"] as? NSNumber,
              let pointsHigh = dictionary["PointsHigh"] as? NSNumber,
              let reps = dictionary["Representations"] as? [Data] else {
            return nil
        }

        // Create empty cursor
        let cursor = MCCursor()
        cursor.frameCount = frameCount.uintValue
        cursor.frameDuration = frameDuration.doubleValue
        cursor.hotSpot = NSPoint(x: hotSpotX.doubleValue, y: hotSpotY.doubleValue)
        cursor.size = NSSize(width: pointsWide.doubleValue, height: pointsHigh.doubleValue)

        // Parse representations (TIFF data)
        for data in reps {
            guard let rep = NSBitmapImageRep(data: data) else { continue }

            // Set logical size (points, not pixels)
            rep.size = NSSize(width: cursor.size.width, height: cursor.size.height * CGFloat(cursor.frameCount))

            // Calculate scale from pixel dimensions
            let scale = CGFloat(rep.pixelsWide) / pointsWide.doubleValue
            let mcScale = MCCursorScale(rawValue: UInt(scale * 100))

            // Retag color space to sRGB
            let retaggedRep = rep.retaggedSRGBSpace()

            if let mcScale = mcScale {
                cursor.setRepresentation(retaggedRep, for: mcScale)
            }
        }

        self.init(objcCursor: cursor)
    }

    // MARK: - Copy

    func copy(withIdentifier newIdentifier: String) -> Cursor {
        let newCursor = Cursor(identifier: newIdentifier)
        newCursor.frameCount = self.frameCount
        newCursor.frameDuration = self.frameDuration
        newCursor.size = self.size
        newCursor.hotSpot = self.hotSpot
        for scale in CursorScale.allCases {
            if let rep = self.representation(for: scale),
               let repCopy = rep.copy() as? NSImageRep {
                newCursor.setRepresentation(repCopy, for: scale)
            }
        }
        return newCursor
    }

    /// 只复制元数据（hotspot、fps、frameCount、size），共享图像引用
    /// 用于 onChange 时的快速同步，避免不必要的图像深拷贝
    func copyMetadata(withIdentifier newIdentifier: String) -> Cursor {
        let newCursor = Cursor(identifier: newIdentifier)
        newCursor.frameCount = self.frameCount
        newCursor.frameDuration = self.frameDuration
        newCursor.size = self.size
        newCursor.hotSpot = self.hotSpot
        // 共享图像引用而非深拷贝，因为光标图像设置后不会被修改
        for scale in CursorScale.allCases {
            if let rep = self.representation(for: scale) {
                newCursor.setRepresentation(rep, for: scale)
            }
        }
        return newCursor
    }

    // MARK: - Serialization

    /// Convert cursor to dictionary representation (for .cape file serialization)
    /// - Returns: Dictionary compatible with ObjC MCCursor format
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["FrameCount"] = NSNumber(value: frameCount)
        dict["FrameDuration"] = NSNumber(value: frameDuration)
        dict["HotSpotX"] = NSNumber(value: hotSpot.x)
        dict["HotSpotY"] = NSNumber(value: hotSpot.y)
        dict["PointsWide"] = NSNumber(value: size.width)
        dict["PointsHigh"] = NSNumber(value: size.height)

        // Convert all representations to HEIF data (lossless compression, quality = 1.0)
        var heifData: [Data] = []
        for scale in CursorScale.allCases {
            if let rep = representation(for: scale) as? NSBitmapImageRep,
               let cgImage = rep.cgImage {
                // Use CGImageDestination for HEIF encoding with lossless compression
                let data = NSMutableData()
                if let destination = CGImageDestinationCreateWithData(data as CFMutableData, UTType.heic.identifier as CFString, 1, nil) {
                    let options: [CFString: Any] = [
                        kCGImageDestinationLossyCompressionQuality: 1.0
                    ]
                    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
                    if CGImageDestinationFinalize(destination) {
                        heifData.append(data as Data)
                    }
                }
            }
        }

        dict["Representations"] = heifData

        return dict
    }

    // MARK: - Direct Image Data Access

    /// Set image data for a specific scale
    /// - Parameters:
    ///   - data: TIFF or PNG image data
    ///   - scale: Target scale
    func setImageData(_ data: Data, for scale: CursorScale) {
        guard let rep = NSBitmapImageRep(data: data) else { return }

        // Set logical size
        rep.size = NSSize(width: size.width, height: size.height * CGFloat(frameCount))

        setRepresentation(rep, for: scale)
    }

    /// Get image data for a specific scale
    /// - Parameter scale: Target scale
    /// - Returns: TIFF data (LZW compressed) or nil if no representation exists
    func imageData(for scale: CursorScale) -> Data? {
        guard let rep = representation(for: scale) as? NSBitmapImageRep else {
            return nil
        }

        // Return TIFF data with LZW compression
        return rep.tiffRepresentation(using: NSBitmapImageRep.TIFFCompression.lzw, factor: 1.0)
    }

    // MARK: - ObjC Bridge

    /// Get the underlying ObjC cursor object
    var underlyingCursor: MCCursor {
        objcCursor
    }

    // MARK: - Hashable & Equatable

    static func == (lhs: Cursor, rhs: Cursor) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Cursor Preview Helper

extension Cursor {
    /// Get a preview image at the specified size
    func previewImage(size: CGFloat = 48) -> NSImage? {
        guard let image = self.image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let frameCount = max(1, self.frameCount)
        let pixelWidth = cgImage.width
        let pixelHeight = cgImage.height
        let framePixelHeight = pixelHeight / frameCount

        guard pixelWidth > 0, framePixelHeight > 0 else { return nil }

        // CGImage uses top-left origin: frame 0 is at Y=0
        let cropRect = CGRect(x: 0, y: 0, width: pixelWidth, height: framePixelHeight)
        guard let firstFrame = cgImage.cropping(to: cropRect) else { return nil }

        let previewImage = NSImage(size: NSSize(width: size, height: size))
        previewImage.lockFocus()
        let drawRect = NSRect(x: 0, y: 0, width: size, height: size)
        let frameNSImage = NSImage(cgImage: firstFrame, size: NSSize(width: pixelWidth, height: framePixelHeight))
        frameNSImage.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
        previewImage.unlockFocus()
        return previewImage
    }
}
