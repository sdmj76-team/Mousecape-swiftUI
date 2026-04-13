import AppKit
import CoreGraphics
import Foundation
import QuickLookThumbnailing

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let image: CGImage
            if let parsed = try? WindowsCursorParser.parse(fileURL: request.fileURL) {
                image = Self.firstFrameImage(from: parsed)
            } else {
                image = Self.fallbackImage(for: request.fileURL)
            }

            let centeredImage = Self.trimForegroundBounds(from: image) ?? image

            let canvas = CGSize(width: request.maximumSize.width, height: request.maximumSize.height)
            let reply = QLThumbnailReply(contextSize: canvas) { context in
                context.clear(CGRect(origin: .zero, size: canvas))

                let drawingBounds = CGRect(origin: .zero, size: canvas).insetBy(dx: 6, dy: 6)

                let fitRect = Self.aspectFitRect(
                    contentSize: CGSize(width: centeredImage.width, height: centeredImage.height),
                    in: drawingBounds
                )

                // Preserve pixel crispness for low-res cursor assets.
                context.interpolationQuality = .none
                context.draw(centeredImage, in: fitRect)
                return true
            }

            handler(reply, nil)
        }
    }

    private static func firstFrameImage(from parsed: WindowsCursorParseResult) -> CGImage {
        guard parsed.frameCount > 1 else { return parsed.image }
        let cropRect = CGRect(x: 0, y: 0, width: parsed.width, height: parsed.height)
        return parsed.image.cropping(to: cropRect) ?? parsed.image
    }

    private static func fallbackImage(for fileURL: URL) -> CGImage {
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = NSSize(width: 256, height: 256)

        if let cg = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }

        let width = 64
        let height = 64
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let data = Data(repeating: 0, count: width * height * 4)
        let provider = CGDataProvider(data: data as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private static func aspectFitRect(contentSize: CGSize, in bounds: CGRect) -> CGRect {
        guard contentSize.width > 0, contentSize.height > 0 else { return bounds }
        let scale = min(bounds.width / contentSize.width, bounds.height / contentSize.height)
        let width = floor(contentSize.width * scale)
        let height = floor(contentSize.height * scale)
        let x = floor(bounds.midX - width / 2)
        let y = floor(bounds.midY - height / 2)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func trimForegroundBounds(from image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }

        let pixels = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)

        // Estimate background color from the 4 corners. This helps with cursor frames
        // where alpha may be fully opaque but visual content still occupies a small region.
        func pixelAt(x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
            let offset = y * bytesPerRow + x * bytesPerPixel
            return (pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3])
        }
        let corners = [
            pixelAt(x: 0, y: 0),
            pixelAt(x: max(0, width - 1), y: 0),
            pixelAt(x: 0, y: max(0, height - 1)),
            pixelAt(x: max(0, width - 1), y: max(0, height - 1)),
        ]
        let bgR = Int(corners.map { Int($0.0) }.reduce(0, +) / max(1, corners.count))
        let bgG = Int(corners.map { Int($0.1) }.reduce(0, +) / max(1, corners.count))
        let bgB = Int(corners.map { Int($0.2) }.reduce(0, +) / max(1, corners.count))
        let bgA = Int(corners.map { Int($0.3) }.reduce(0, +) / max(1, corners.count))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
                let a = Int(pixels[offset + 3])

                // Foreground when it is sufficiently visible and differs from background.
                let colorDelta = abs(r - bgR) + abs(g - bgG) + abs(b - bgB) + abs(a - bgA)
                let isForeground = (a > 16 && colorDelta > 20) || (a > 48 && bgA < 12)

                if isForeground {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        let cropRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
        return image.cropping(to: cropRect)
    }
}
