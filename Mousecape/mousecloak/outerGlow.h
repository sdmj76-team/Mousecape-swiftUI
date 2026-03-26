#import <CoreGraphics/CoreGraphics.h>

/// Applies an outer glow effect to a cursor image.
/// Adds a soft white halo around the cursor shape edges for better visibility.
/// @param image The source CGImage (typically RGBA, 8-bpc)
/// @param radius Glow radius in pixels (blur spread). Default 6.0.
/// @param intensity Glow opacity 0.0-1.0. Default 0.5.
/// @return A new CGImage with outer glow applied. Caller must CGImageRelease.
///         Returns NULL if the input is invalid or processing fails.
CGImageRef MCApplyOuterGlow(CGImageRef image, float radius, float intensity);
