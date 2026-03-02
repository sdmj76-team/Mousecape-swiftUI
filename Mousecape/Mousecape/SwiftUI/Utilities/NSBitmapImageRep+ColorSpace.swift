//
//  NSBitmapImageRep+ColorSpace.swift
//  Mousecape
//
//  Swift extension for color space conversion
//

import AppKit

extension NSBitmapImageRep {
    /// Retag the bitmap to sRGB color space (or grayscale if appropriate)
    /// - Returns: A new bitmap with retagged color space
    func retaggedSRGBSpace() -> NSBitmapImageRep {
        var targetSpace = NSColorSpace.sRGB

        if let colorSpace = self.colorSpace,
           colorSpace.numberOfColorComponents == 1 {
            targetSpace = NSColorSpace.genericGamma22Gray
        }

        return bitmapImageRepByRetagging(with: targetSpace) ?? self
    }

    /// Convert the bitmap to sRGB color space (or grayscale if appropriate)
    /// - Returns: A new bitmap converted to the target color space
    func ensuredSRGBSpace() -> NSBitmapImageRep {
        var targetSpace = NSColorSpace.sRGB

        if let colorSpace = self.colorSpace,
           colorSpace.numberOfColorComponents == 1 {
            targetSpace = NSColorSpace.genericGamma22Gray
        }

        return bitmapImageRepByConverting(to: targetSpace,
                                          renderingIntent: .default) ?? self
    }
}
