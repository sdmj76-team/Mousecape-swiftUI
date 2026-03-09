//
//  AnimatingCursorView.swift
//  Mousecape
//
//  Pure SwiftUI animated cursor view with sprite animation
//  Replaces MMAnimatingImageView for SwiftUI usage
//

import SwiftUI
import AppKit

/// SwiftUI view for displaying animated cursor sprites
struct AnimatingCursorView: View {
    let cursor: Cursor
    var showHotspot: Bool = false
    var refreshTrigger: Int = 0
    /// Scale factor for rendering (1.0 = original size, 0.5 = half size)
    var scale: CGFloat = 1.0

    @State private var currentFrame: Int = 0
    @State private var animationTimer: Timer?
    @State private var cachedFrames: [NSImage] = []
    @AppStorage("showPreviewAnimations") private var showPreviewAnimations = true
    @Environment(AppState.self) private var appState

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Cursor sprite frame
                if let frameImage = getFrameImage(at: currentFrame) {
                    let displaySize = CGSize(
                        width: frameImage.size.width * scale,
                        height: frameImage.size.height * scale
                    )
                    Image(nsImage: frameImage)
                        .interpolation(.high)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                } else {
                    // Placeholder
                    Image(systemName: "cursorarrow")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }

                // Hotspot indicator
                if showHotspot, let frameImage = getFrameImage(at: 0) {
                    HotspotIndicator(
                        hotspot: cursor.hotSpot,
                        frameSize: CGSize(width: frameImage.size.width, height: frameImage.size.height),
                        viewSize: geometry.size,
                        scale: scale
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            buildFrameCache()
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
            cachedFrames = []
        }
        .onChange(of: cursor.frameCount) { _, _ in
            buildFrameCache()
            restartAnimation()
        }
        .onChange(of: cursor.frameDuration) { _, _ in
            restartAnimation()
        }
        .onChange(of: cursor.id) { _, _ in
            currentFrame = 0
            buildFrameCache()
            restartAnimation()
        }
        .onChange(of: refreshTrigger) { _, _ in
            // Force refresh - rebuild cache and restart animation
            buildFrameCache()
            restartAnimation()
        }
        .onChange(of: showPreviewAnimations) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
                currentFrame = 0
            }
        }
        .onChange(of: appState.isWindowVisible) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .accessibilityLabel("Animated cursor preview")
        .accessibilityValue(cursor.frameCount > 1 ? "\(cursor.frameCount) frames" : "Static")
    }

    /// Get a cached frame image at the given index
    private func getFrameImage(at frameIndex: Int) -> NSImage? {
        guard frameIndex >= 0, frameIndex < cachedFrames.count else {
            // Fallback: try to build cache if empty
            if cachedFrames.isEmpty { buildFrameCache() }
            guard frameIndex >= 0, frameIndex < cachedFrames.count else { return nil }
            return cachedFrames[frameIndex]
        }
        return cachedFrames[frameIndex]
    }

    /// Build frame cache from sprite sheet using CGImage.cropping
    private func buildFrameCache() {
        guard let image = cursor.image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            cachedFrames = []
            return
        }

        let frameCount = max(1, cursor.frameCount)
        let totalHeight = cgImage.height
        let frameHeight = totalHeight / frameCount
        let frameWidth = cgImage.width

        // Use NSImage logical size (points) for display, not pixel dimensions
        let logicalWidth = image.size.width
        let logicalFrameHeight = image.size.height / CGFloat(frameCount)

        guard frameWidth > 0, frameHeight > 0 else {
            cachedFrames = []
            return
        }

        var frames: [NSImage] = []
        frames.reserveCapacity(frameCount)

        for i in 0..<frameCount {
            // CGImage origin is top-left, frames are stacked top to bottom
            let cropRect = CGRect(x: 0, y: i * frameHeight, width: frameWidth, height: frameHeight)
            guard let croppedCG = cgImage.cropping(to: cropRect) else { continue }
            let nsImage = NSImage(cgImage: croppedCG, size: NSSize(width: logicalWidth, height: logicalFrameHeight))
            frames.append(nsImage)
        }

        cachedFrames = frames
    }

    private func startAnimation() {
        guard cursor.frameCount > 1, cursor.frameDuration > 0, showPreviewAnimations, appState.isWindowVisible else {
            currentFrame = 0
            return
        }

        let frameCount = cursor.frameCount
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: cursor.frameDuration, repeats: true) { [self] _ in
            Task { @MainActor in
                currentFrame = (currentFrame + 1) % frameCount
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func restartAnimation() {
        stopAnimation()
        currentFrame = 0
        startAnimation()
    }
}

/// Hotspot indicator overlay
private struct HotspotIndicator: View {
    let hotspot: NSPoint
    let frameSize: CGSize
    let viewSize: CGSize
    let scale: CGFloat

    var body: some View {
        // Calculate the scaled image size
        let scaledWidth = frameSize.width * scale
        let scaledHeight = frameSize.height * scale

        // Calculate offset to center the image in the view
        let offsetX = (viewSize.width - scaledWidth) / 2
        let offsetY = (viewSize.height - scaledHeight) / 2

        // Hotspot position - hotspot.y is from top of image, SwiftUI y is also from top
        let x = offsetX + hotspot.x * scale
        let y = offsetY + hotspot.y * scale

        Circle()
            .fill(Color.red)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(Color.primary.opacity(0.5), lineWidth: 0.5)
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
            )
            .position(x: x, y: y)
            .accessibilityLabel("Hotspot position")
            .accessibilityValue("X: \(Int(hotspot.x)), Y: \(Int(hotspot.y))")
    }
}

// MARK: - Static Cursor Image View

/// A simpler view for non-animated cursor display
struct StaticCursorImageView: View {
    let cursor: Cursor
    let size: CGFloat

    init(cursor: Cursor, size: CGFloat = 48) {
        self.cursor = cursor
        self.size = size
    }

    var body: some View {
        if let image = cursor.previewImage(size: size) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "cursorarrow")
                .font(.system(size: size * 0.5))
                .foregroundStyle(.tertiary)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Static Cursor Frame View (for Hero Animation)

/// Static cursor frame view without Timer animation
/// Used for matchedGeometryEffect transitions to avoid animation conflicts
struct StaticCursorFrameView: View {
    let cursor: Cursor
    var frameIndex: Int = 0
    var scale: CGFloat = 1.0

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if let frameImage = getFrameImage(at: frameIndex) {
                    let displaySize = CGSize(
                        width: frameImage.size.width * scale,
                        height: frameImage.size.height * scale
                    )
                    Image(nsImage: frameImage)
                        .interpolation(.high)
                        .resizable()
                        .frame(width: displaySize.width, height: displaySize.height)
                } else {
                    Image(systemName: "cursorarrow")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Extract a single frame from the sprite sheet using CGImage.cropping
    private func getFrameImage(at frameIndex: Int) -> NSImage? {
        guard let image = cursor.image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let frameCount = max(1, cursor.frameCount)
        let totalHeight = cgImage.height
        let frameHeight = totalHeight / frameCount
        let frameWidth = cgImage.width

        // Use NSImage logical size (points) for display
        let logicalWidth = image.size.width
        let logicalFrameHeight = image.size.height / CGFloat(frameCount)

        guard frameWidth > 0, frameHeight > 0 else { return nil }

        // CGImage origin is top-left, frames are stacked top to bottom
        let cropRect = CGRect(x: 0, y: frameIndex * frameHeight, width: frameWidth, height: frameHeight)
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
        return NSImage(cgImage: croppedCG, size: NSSize(width: logicalWidth, height: logicalFrameHeight))
    }
}

// MARK: - Cursor Thumbnail View

/// Small thumbnail for cursor preview
struct CursorThumbnailView: View {
    let cursor: Cursor
    let size: CGFloat
    let scale: CGFloat
    @State private var isAnimating = false

    init(cursor: Cursor, size: CGFloat = 32, scale: CGFloat = 1.0) {
        self.cursor = cursor
        self.size = size
        self.scale = scale
    }

    var body: some View {
        if cursor.isAnimated {
            AnimatingCursorView(cursor: cursor, showHotspot: false, scale: scale)
                .frame(width: size, height: size)
        } else {
            StaticCursorImageView(cursor: cursor, size: size)
        }
    }
}

// MARK: - Preview

#Preview("Animating Cursor View") {
    VStack(spacing: 20) {
        AnimatingCursorView(
            cursor: Cursor(identifier: "com.apple.coregraphics.Arrow"),
            showHotspot: true
        )
        .frame(width: 64, height: 64)
        .border(Color.gray.opacity(0.3))

        StaticCursorImageView(
            cursor: Cursor(identifier: "com.apple.coregraphics.Wait"),
            size: 48
        )
    }
    .padding()
}
