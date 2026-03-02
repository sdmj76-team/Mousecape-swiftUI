//
//  WindowsCursorConverter.swift
//  Mousecape
//
//  Converts Windows .cur/.ani cursor files using native Swift parser.
//  No external dependencies required.
//

import Foundation
import AppKit

// MARK: - Conversion Result

/// Result from converting a Windows cursor file
struct WindowsCursorResult {
    let width: Int
    let height: Int
    let hotspotX: Int
    let hotspotY: Int
    let frameCount: Int
    let frameDuration: Double
    let image: CGImage   // Sprite sheet (for animated: frames stacked vertically)
    let filename: String // Original filename without extension
}

// MARK: - Conversion Error

enum WindowsCursorError: LocalizedError {
    case conversionFailed(String)
    case imageDecodeFailed
    case imageTooLarge(width: Int, height: Int)

    var errorDescription: String? {
        switch self {
        case .conversionFailed(let message):
            return "Conversion failed: \(message)"
        case .imageDecodeFailed:
            return "Failed to decode image data"
        case .imageTooLarge(let width, let height):
            return "Image too large (\(width)x\(height)). Maximum supported size is 512x512 pixels."
        }
    }
}

// MARK: - Converter

/// Converts Windows cursor files (.cur, .ani) to Mousecape format
final class WindowsCursorConverter: @unchecked Sendable {

    /// Shared instance
    static let shared = WindowsCursorConverter()

    /// Nonisolated accessor for use from any context
    nonisolated static var instance: WindowsCursorConverter { shared }

    private init() {}

    // MARK: - Public API

    /// Convert a single cursor file
    /// - Parameter fileURL: URL to .cur or .ani file
    /// - Returns: Conversion result with image data
    func convert(fileURL: URL) throws -> WindowsCursorResult {
        let filename = fileURL.deletingPathExtension().lastPathComponent

        do {
            let parseResult = try WindowsCursorParser.parse(fileURL: fileURL)
            return try convertParseResult(parseResult, filename: filename)
        } catch let error as WindowsCursorParserError {
            throw WindowsCursorError.conversionFailed(error.localizedDescription)
        }
    }

    /// Convert all cursor files in a folder
    /// - Parameter folderURL: URL to folder containing .cur/.ani files
    /// - Returns: Array of conversion results
    func convertFolder(folderURL: URL) throws -> [WindowsCursorResult] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: nil) else {
            throw WindowsCursorError.conversionFailed("Cannot enumerate folder")
        }

        var results: [WindowsCursorResult] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if ext == "cur" || ext == "ani" {
                if let result = try? convert(fileURL: fileURL) {
                    results.append(result)
                }
            }
        }

        return results
    }

    /// Convert cursor files in a folder using INF mapping (position-based)
    /// - Parameters:
    ///   - folderURL: URL to folder containing .cur/.ani files and install.inf
    ///   - infMapping: Parsed INF mapping from install.inf
    /// - Returns: Array of (position, result) tuples for successful conversions
    func convertFolderWithINF(folderURL: URL, infMapping: WindowsINFMapping) throws -> [(position: Int, result: WindowsCursorResult)] {
        var results: [(position: Int, result: WindowsCursorResult)] = []

        for (position, filename) in infMapping.cursorFilesByPosition {
            let fileURL = folderURL.appendingPathComponent(filename)

            // Check if file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                debugLog("INF referenced file not found: \(filename)")
                continue
            }

            // Convert the file
            do {
                let result = try convert(fileURL: fileURL)
                results.append((position: position, result: result))
            } catch {
                debugLog("Failed to convert \(filename): \(error.localizedDescription)")
            }
        }

        return results
    }

    // MARK: - Async Public API

    /// Convert cursor files in a folder asynchronously using INF mapping (position-based)
    /// - Parameters:
    ///   - folderURL: URL to folder containing .cur/.ani files and install.inf
    ///   - infMapping: Parsed INF mapping from install.inf
    /// - Returns: Array of (position, result) tuples for successful conversions
    func convertFolderWithINFAsync(folderURL: URL, infMapping: WindowsINFMapping) async throws -> [(position: Int, result: WindowsCursorResult)] {
        return try await withThrowingTaskGroup(of: (Int, WindowsCursorResult)?.self) { group in
            for (position, filename) in infMapping.cursorFilesByPosition {
                group.addTask {
                    let fileURL = folderURL.appendingPathComponent(filename)
                    guard FileManager.default.fileExists(atPath: fileURL.path) else {
                        debugLog("INF referenced file not found: \(filename)")
                        return nil
                    }
                    do {
                        let result = try self.convert(fileURL: fileURL)
                        return (position, result)
                    } catch {
                        debugLog("Failed to convert \(filename): \(error.localizedDescription)")
                        return nil
                    }
                }
            }
            var results: [(position: Int, result: WindowsCursorResult)] = []
            for try await item in group {
                if let (pos, res) = item {
                    results.append((position: pos, result: res))
                }
            }
            return results
        }
    }

    // MARK: - Private Methods

    /// Convert a parse result to WindowsCursorResult
    /// Downsamples to max 24 frames if needed to comply with system limits
    private func convertParseResult(_ parseResult: WindowsCursorParseResult, filename: String) throws -> WindowsCursorResult {
        let maxFrameCount = CursorImageScaler.maxFrameCount

        // Validate single frame size to prevent importing oversized frames
        // Note: Sprite sheet size validation is not needed since images are scaled to 64x64 per frame later
        try validateSingleFrameSize(width: parseResult.width, height: parseResult.height, filename: filename)

        // Check if we need to downsample
        if parseResult.frameCount > maxFrameCount {
            debugLog("Windows cursor '\(filename)' has \(parseResult.frameCount) frames, downsampling to \(maxFrameCount)")

            // Downsample the sprite sheet with autoreleasepool for memory management
            let downsampledImage: CGImage? = autoreleasepool {
                return downsampleSpriteSheet(
                    parseResult.image,
                    fromFrameCount: parseResult.frameCount,
                    toFrameCount: maxFrameCount,
                    frameWidth: parseResult.width,
                    frameHeight: parseResult.height
                )
            }

            guard let downsampledImage = downsampledImage else {
                throw WindowsCursorError.imageDecodeFailed
            }

            // Adjust duration to maintain overall animation timing
            let adjustedDuration = parseResult.frameDuration * (Double(parseResult.frameCount) / Double(maxFrameCount))

            return WindowsCursorResult(
                width: parseResult.width,
                height: parseResult.height,
                hotspotX: parseResult.hotspotX,
                hotspotY: parseResult.hotspotY,
                frameCount: maxFrameCount,
                frameDuration: adjustedDuration,
                image: downsampledImage,
                filename: filename
            )
        }

        // No downsampling needed
        return WindowsCursorResult(
            width: parseResult.width,
            height: parseResult.height,
            hotspotX: parseResult.hotspotX,
            hotspotY: parseResult.hotspotY,
            frameCount: parseResult.frameCount,
            frameDuration: parseResult.frameDuration,
            image: parseResult.image,
            filename: filename
        )
    }

    /// Validate single frame size to prevent importing oversized frames
    /// - Parameters:
    ///   - width: Frame width in pixels
    ///   - height: Frame height in pixels
    ///   - filename: Filename for error reporting
    /// - Throws: WindowsCursorError.imageTooLarge if frame exceeds maximum dimensions
    private func validateSingleFrameSize(width: Int, height: Int, filename: String) throws {
        let maxFrameSize = CursorImageScaler.maxImportSize  // Maximum individual frame size
        if width > maxFrameSize || height > maxFrameSize {
            debugLog("Frame '\(filename)' is too large: \(width)x\(height), max is \(maxFrameSize)x\(maxFrameSize)")
            throw WindowsCursorError.imageTooLarge(width: width, height: height)
        }
    }

    /// Downsample a sprite sheet by extracting evenly distributed frames
    /// - Parameters:
    ///   - spriteSheet: Original sprite sheet CGImage
    ///   - fromFrameCount: Original number of frames
    ///   - toFrameCount: Target number of frames
    ///   - frameWidth: Width of each frame
    ///   - frameHeight: Height of each frame
    /// - Returns: Downsampled sprite sheet as CGImage
    private func downsampleSpriteSheet(_ spriteSheet: CGImage, fromFrameCount: Int, toFrameCount: Int, frameWidth: Int, frameHeight: Int) -> CGImage? {
        guard fromFrameCount > toFrameCount else { return nil }

        // Calculate which frames to keep (uniform sampling)
        let step = Double(fromFrameCount - 1) / Double(toFrameCount - 1)
        var frameIndices: [Int] = []
        for i in 0..<toFrameCount {
            let sourceIndex = Int(round(Double(i) * step))
            let clampedIndex = min(sourceIndex, fromFrameCount - 1)
            frameIndices.append(clampedIndex)
        }

        // Create new sprite sheet with selected frames
        let newSheetHeight = frameHeight * toFrameCount
        guard let context = CGContext(
            data: nil,
            width: frameWidth,
            height: newSheetHeight,
            bitsPerComponent: 8,
            bytesPerRow: frameWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Clear to transparent
        context.clear(CGRect(x: 0, y: 0, width: frameWidth, height: newSheetHeight))

        // Draw selected frames
        // Note: CGImage.cropping uses top-left origin (Y=0 at top)
        // CGContext.draw uses bottom-left origin (Y=0 at bottom)
        // Frame 0 is at the TOP of the sprite sheet
        for (destIndex, sourceIndex) in frameIndices.enumerated() {
            // Source: CGImage uses top-left origin, frame 0 is at Y=0
            let srcY = sourceIndex * frameHeight
            // Destination: CGContext uses bottom-left origin, frame 0 should be at top (highest Y)
            let dstY = newSheetHeight - (destIndex + 1) * frameHeight

            if let croppedFrame = spriteSheet.cropping(to: CGRect(x: 0, y: srcY, width: frameWidth, height: frameHeight)) {
                context.draw(croppedFrame, in: CGRect(x: 0, y: dstY, width: frameWidth, height: frameHeight))
            }
        }

        guard let newCGImage = context.makeImage() else { return nil }
        return newCGImage
    }

}

// MARK: - NSBitmapImageRep Extension

extension WindowsCursorResult {

    /// Create NSBitmapImageRep from the result
    /// For animated cursors, returns a sprite sheet with all frames stacked vertically
    func createBitmapImageRep() -> NSBitmapImageRep? {
        return NSBitmapImageRep(cgImage: image)
    }
}
