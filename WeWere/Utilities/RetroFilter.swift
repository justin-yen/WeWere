import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies a Kodak Portra 400-inspired film filter to photos.
///
/// Portra 400 characteristics:
/// - Soft, muted tones with excellent skin reproduction
/// - Very subtle warmth (not as aggressive as Gold)
/// - Low contrast with smooth tonal rolloff
/// - Lifted shadows with a slight pink/peach cast
/// - Fine grain structure
/// - Gentle highlight rolloff (highlights don't clip harshly)
enum RetroFilter {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Apply the Portra 400 filter pipeline. Returns filtered JPEG data.
    static func apply(to imageData: Data) -> Data? {
        guard let uiImage = UIImage(data: imageData),
              let normalizedImage = normalizeOrientation(uiImage),
              let normalizedData = normalizedImage.jpegData(compressionQuality: 1.0),
              let inputImage = CIImage(data: normalizedData) else { return nil }

        var image = inputImage

        // 1. Subtle warmth -- Portra is warm but not orange
        image = applyWarmth(to: image)

        // 2. Gentle desaturation -- Portra has muted, pastel tones
        image = adjustColorControls(image, saturation: 0.88, brightness: 0.015, contrast: 1.0)

        // 3. Low contrast -- Portra is known for soft, flat contrast
        image = adjustColorControls(image, saturation: 1.0, brightness: 0.0, contrast: 0.95)

        // 4. Lifted shadows with pink/peach cast -- signature Portra look
        image = portraShadowLift(image)

        // 5. Soft highlight rolloff -- compress highlights gently
        image = highlightRolloff(image)

        // 6. Gentle vignette -- much softer than Kodak Gold
        image = applyVignette(to: image)

        // 7. Fine grain -- Portra has very fine, subtle grain
        image = applyGrain(to: image)

        // Render to JPEG
        guard let cgImage = context.createCGImage(image, from: inputImage.extent) else { return nil }
        let outputImage = UIImage(cgImage: cgImage)
        return outputImage.jpegData(compressionQuality: 0.85)
    }

    // MARK: - Pipeline Steps

    /// Subtle warmth -- less aggressive than Kodak Gold
    private static func applyWarmth(to image: CIImage) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: 6200, y: 0)
        filter.targetNeutral = CIVector(x: 5400, y: -10) // slight warmth + tiny magenta shift
        return filter.outputImage ?? image
    }

    /// General color controls adjustment
    private static func adjustColorControls(_ image: CIImage, saturation: Float, brightness: Float, contrast: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = saturation
        filter.brightness = brightness
        filter.contrast = contrast
        return filter.outputImage ?? image
    }

    /// Portra's signature shadow lift with a slight pink/peach cast
    /// Blacks become a warm dark gray rather than pure black
    private static func portraShadowLift(_ image: CIImage) -> CIImage {
        let filter = CIFilter.colorClamp()
        filter.inputImage = image
        // Lift shadows: R slightly more than G and B for peach cast
        filter.minComponents = CIVector(x: 0.035, y: 0.025, z: 0.03, w: 0)
        // Soft highlight ceiling -- don't clip whites harshly
        filter.maxComponents = CIVector(x: 0.98, y: 0.97, z: 0.96, w: 1)
        return filter.outputImage ?? image
    }

    /// Compress highlights gently -- Portra's smooth highlight rolloff
    private static func highlightRolloff(_ image: CIImage) -> CIImage {
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = image
        filter.highlightAmount = 0.85 // pull highlights down slightly
        filter.shadowAmount = 0.15    // open shadows a touch
        return filter.outputImage ?? image
    }

    /// Gentle vignette -- softer and less noticeable than Gold
    private static func applyVignette(to image: CIImage) -> CIImage {
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = 0.6  // much lighter than Gold's 1.2
        filter.radius = 2.5     // wider falloff
        return filter.outputImage ?? image
    }

    /// Fine film grain -- Portra 400 has subtle, fine-structured grain
    private static func applyGrain(to image: CIImage) -> CIImage {
        let noiseFilter = CIFilter.randomGenerator()
        guard let noise = noiseFilter.outputImage else { return image }

        // Desaturate and darken the noise
        let whitening = CIFilter.colorControls()
        whitening.inputImage = noise
        whitening.saturation = 0
        whitening.brightness = -0.5
        whitening.contrast = 2.5  // less harsh than Gold
        guard let whiteNoise = whitening.outputImage else { return image }

        let croppedNoise = whiteNoise.cropped(to: image.extent)

        // Very subtle grain blend -- 4% opacity (finer than Gold's 6%)
        let multiply = CIFilter.multiplyBlendMode()
        multiply.inputImage = croppedNoise.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.04)
        ])
        multiply.backgroundImage = image
        return multiply.outputImage ?? image
    }

    /// Normalize image orientation so pixels match the visual orientation.
    private static func normalizeOrientation(_ image: UIImage) -> UIImage? {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized
    }
}
