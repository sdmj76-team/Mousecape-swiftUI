#import "outerGlow.h"
#import "MCDefs.h"
#import <Accelerate/Accelerate.h>

CGImageRef MCApplyOuterGlow(CGImageRef image, float radius, float intensity) {
    @autoreleasepool {

        // --- Step 1: Validate input ---
        if (!image) {
            MMLog("MCApplyOuterGlow: image is NULL");
            return NULL;
        }

        size_t width = CGImageGetWidth(image);
        size_t height = CGImageGetHeight(image);

        if (width == 0 || height == 0) {
            MMLog("MCApplyOuterGlow: image has zero dimensions (%zux%zu)", width, height);
            return NULL;
        }

        // Clamp radius to at least 1.0
        int blurRadius = (int)radius;
        if (blurRadius < 1) {
            blurRadius = 1;
        }

        // Clamp intensity
        if (intensity < 0.0f) intensity = 0.0f;
        if (intensity > 1.0f) intensity = 1.0f;

        MMLog("MCApplyOuterGlow: processing %zux%zu image, radius=%d, intensity=%.2f",
              width, height, blurRadius, intensity);

        // --- Step 2: Create pixel buffer (8-bpc RGBA, non-premultiplied) ---
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        if (!colorSpace) {
            MMLog("MCApplyOuterGlow: failed to create color space");
            return NULL;
        }

        CGContextRef context = CGBitmapContextCreate(
            nil,
            width,
            height,
            8,
            width * 4,
            colorSpace,
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big
        );
        CGColorSpaceRelease(colorSpace);

        if (!context) {
            MMLog("MCApplyOuterGlow: failed to create bitmap context");
            return NULL;
        }

        // Draw source image into our normalized context
        CGRect rect = CGRectMake(0, 0, width, height);
        CGContextDrawImage(context, rect, image);

        // Get mutable pixel data
        uint8_t *pixels = (uint8_t *)CGBitmapContextGetData(context);
        if (!pixels) {
            MMLog("MCApplyOuterGlow: failed to get pixel data from context");
            CGContextRelease(context);
            return NULL;
        }

        size_t totalPixels = width * height;

        // --- Step 3: Extract alpha channel ---
        // Pixel format: ARGB (premultiplied first, big endian)
        // Byte order: A, R, G, B per pixel
        float *alpha = (float *)malloc(totalPixels * sizeof(float));
        if (!alpha) {
            MMLog("MCApplyOuterGlow: failed to allocate alpha buffer");
            CGContextRelease(context);
            return NULL;
        }

        for (size_t i = 0; i < totalPixels; i++) {
            alpha[i] = pixels[i * 4] / 255.0f; // Alpha is at byte offset 0 (premultiplied first)
        }

        // --- Step 4: Box blur the alpha using Accelerate vImage (3-pass separable) ---
        float *temp = (float *)malloc(totalPixels * sizeof(float));
        float *blurred = (float *)malloc(totalPixels * sizeof(float));

        if (!temp || !blurred) {
            MMLog("%s: failed to allocate blur buffers", __func__);
            free(alpha);
            if (temp) free(temp);
            if (blurred) free(blurred);
            CGContextRelease(context);
            return NULL;
        }

        int kSize = blurRadius * 2 + 1;
        float invK = 1.0f / kSize;

        // Create a uniform 1D kernel (all invK) — pre-divided so convolution result is averaged
        float *kernel = (float *)malloc(kSize * sizeof(float));
        if (!kernel) {
            MMLog("%s: failed to allocate kernel", __func__);
            free(alpha);
            free(temp);
            free(blurred);
            CGContextRelease(context);
            return NULL;
        }
        for (int i = 0; i < kSize; i++) {
            kernel[i] = invK;
        }

        // Set up vImage buffers
        vImage_Buffer srcBuf = { alpha, height, width, width * sizeof(float) };
        vImage_Buffer tempBuf = { temp, height, width, width * sizeof(float) };
        vImage_Buffer blurBuf = { blurred, height, width, width * sizeof(float) };

        // Pass 1: Horizontal — alpha → temp
        vImageConvolve_PlanarF(&srcBuf, &tempBuf, NULL, 0, 0,
                               kernel, 1, kSize, 0.0f,
                               kvImageEdgeExtend);

        // Pass 2: Vertical — temp → blurred
        vImageConvolve_PlanarF(&tempBuf, &blurBuf, NULL, 0, 0,
                               kernel, kSize, 1, 0.0f,
                               kvImageEdgeExtend);

        // Pass 3: Horizontal — blurred → temp
        vImageConvolve_PlanarF(&blurBuf, &tempBuf, NULL, 0, 0,
                               kernel, 1, kSize, 0.0f,
                               kvImageEdgeExtend);

        free(kernel);

        // temp now holds the final 3-pass blurred alpha
        float *blurredAlpha = temp;

        // --- Step 5: Compute outer glow and apply ---
        for (size_t i = 0; i < totalPixels; i++) {
            float glow = blurredAlpha[i] - alpha[i];
            if (glow < 0.0f) glow = 0.0f;
            if (glow > 1.0f) glow = 1.0f;
            glow *= intensity;

            // Pixel layout: A(0), R(1), G(2), B(3) — premultiplied first, big endian
            if (alpha[i] > 0.0f) {
                // Inside the cursor shape: keep original pixel unchanged
                continue;
            }

            // Outside the cursor shape: apply white glow if there is any
            if (glow > 0.0f) {
                uint8_t glowAlpha = (uint8_t)(glow * 255.0f + 0.5f); // round to nearest
                pixels[i * 4 + 0] = glowAlpha; // A
                pixels[i * 4 + 1] = glowAlpha; // R (premultiplied white)
                pixels[i * 4 + 2] = glowAlpha; // G (premultiplied white)
                pixels[i * 4 + 3] = glowAlpha; // B (premultiplied white)
            }
        }

        // --- Step 6: Create output CGImage ---
        CGImageRef outputImage = CGBitmapContextCreateImage(context);

        // --- Step 7: Clean up ---
        free(alpha);
        free(temp);
        free(blurred);
        CGContextRelease(context);

        if (!outputImage) {
            MMLog("MCApplyOuterGlow: failed to create output image");
            return NULL;
        }

        return outputImage;
    } // @autoreleasepool
}
