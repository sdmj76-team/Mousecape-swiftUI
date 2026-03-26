#import <CoreGraphics/CoreGraphics.h>

/// Applies an inner shadow effect to a cursor image.
/// Darkens pixels near the edges of the cursor shape from inside.
/// @param image The source CGImage (typically RGBA, 8-bpc)
/// @param radius Shadow radius in pixels (blur spread). Default 4.0.
/// @param intensity Shadow darkness 0.0-1.0. Default 0.4.
/// @return A new CGImage with inner shadow applied. Caller must CGImageRelease.
///         Returns NULL if the input is invalid or processing fails.
CGImageRef MCApplyInnerShadow(CGImageRef image, float radius, float intensity);
