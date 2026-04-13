import AppKit
import CoreGraphics
import Foundation
import QuickLookUI
import OSLog

@MainActor
final class PreviewViewController: NSViewController, @preconcurrency QLPreviewingController {
    private struct PreviewPayload {
        let frames: [CGImage]
        let frameDuration: TimeInterval
        let width: Int
        let height: Int
    }

    private let logger = Logger(subsystem: "com.sdmj76.Mousecape.QuickLook", category: "PreviewProvider")
    private let imageView = NSImageView()
    private var animationFrames: [NSImage] = []
    private var animationTimer: Timer?
    private var currentFrameIndex = 0

    private func trace(_ message: String) {
        NSLog("[MousecapeQuickLook] \(message)")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageAlignment = .alignCenter
        // Do not upscale small cursor assets to avoid blur in a large preview window.
        imageView.imageScaling = .scaleProportionallyDown
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        imageView.layer?.magnificationFilter = .nearest
        imageView.layer?.minificationFilter = .nearest

        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor),
        ])

        view = container
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        trace("preparePreviewOfFile start: \(url.path)")
        logger.info("Start preview for \(url.lastPathComponent, privacy: .public)")
        stopAnimation()
        animationFrames = []
        currentFrameIndex = 0

        DispatchQueue.global(qos: .userInitiated).async {
            let payload = Self.decodePreviewPayload(for: url)

            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    handler(nil)
                    return
                }

                if let payload {
                    self.trace("parse success: \(payload.width)x\(payload.height), frames=\(payload.frames.count)")
                    self.logger.info("Parsed cursor: \(payload.width)x\(payload.height), frames=\(payload.frames.count)")
                    self.animationFrames = payload.frames.map {
                        NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height))
                    }
                    self.imageView.image = self.animationFrames.first
                    if self.animationFrames.count > 1 {
                        self.startAnimation(frameDuration: payload.frameDuration)
                    }
                } else {
                    self.trace("parse failed, using fallback")
                    self.logger.error("Cursor parse failed, using fallback icon")
                    let fallback = self.fallbackImage(for: url)
                    self.imageView.image = NSImage(cgImage: fallback, size: NSSize(width: fallback.width, height: fallback.height))
                }

                self.trace("preview image assigned")
                handler(nil)
            }
        }
    }

    private static func decodePreviewPayload(for fileURL: URL) -> PreviewPayload? {
        guard let parsed = try? WindowsCursorParser.parse(fileURL: fileURL) else {
            return nil
        }

        let frames = extractFrames(from: parsed)
        guard !frames.isEmpty else { return nil }

        // Keep frame duration within a sensible range for smooth but stable playback.
        let interval = min(max(parsed.frameDuration, 1.0 / 60.0), 1.0)
        return PreviewPayload(
            frames: frames,
            frameDuration: interval,
            width: parsed.width,
            height: parsed.height
        )
    }

    private static func extractFrames(from parsed: WindowsCursorParseResult) -> [CGImage] {
        if parsed.frameCount <= 1 {
            return [parsed.image]
        }

        var frames: [CGImage] = []
        let frameHeight = parsed.height
        let frameWidth = parsed.width
        guard frameHeight > 0, frameWidth > 0 else { return [parsed.image] }

        for index in 0..<parsed.frameCount {
            let y = index * frameHeight
            let rect = CGRect(x: 0, y: y, width: frameWidth, height: frameHeight)
            if let cropped = parsed.image.cropping(to: rect) {
                frames.append(cropped)
            }
        }

        return frames.isEmpty ? [parsed.image] : frames
    }

    private func startAnimation(frameDuration: TimeInterval) {
        guard animationFrames.count > 1 else { return }
        stopAnimation()
        let interval = max(frameDuration, 1.0 / 60.0)
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.currentFrameIndex = (self.currentFrameIndex + 1) % self.animationFrames.count
            self.imageView.image = self.animationFrames[self.currentFrameIndex]
        }
        if let animationTimer {
            RunLoop.main.add(animationTimer, forMode: .common)
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func fallbackImage(for fileURL: URL) -> CGImage {
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.size = NSSize(width: 256, height: 256)
        if let cg = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }

        let width = 128
        let height = 128
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            logger.fault("Failed to create fallback CGContext")
            return icon.cgImage(forProposedRect: nil, context: nil, hints: nil) ?? CGImage(
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: CGDataProvider(data: Data([200, 200, 200, 255]) as CFData)!,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )!
        }

        context.setFillColor(CGColor(gray: 0.85, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setStrokeColor(CGColor(gray: 0.65, alpha: 1.0))
        context.setLineWidth(4)
        context.stroke(CGRect(x: 8, y: 8, width: width - 16, height: height - 16))
        return context.makeImage()!
    }
}
