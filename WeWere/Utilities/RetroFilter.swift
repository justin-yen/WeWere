import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Applies a Kodak Gold 200-inspired retro film filter to photos.
/// Pipeline: warm tint → desaturate → boost contrast → vignette → grain
enum RetroFilter {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Apply the full retro filter pipeline to image data. Returns filtered JPEG data.
    static func apply(to imageData: Data) -> Data? {
        guard let inputImage = CIImage(data: imageData) else { return nil }

        var image = inputImage

        // 1. Warm color temperature (Kodak Gold warmth)
        image = applyWarmth(to: image)

        // 2. Desaturate slightly (-15%)
        image = adjustSaturation(image, amount: 0.85)

        // 3. Boost contrast (+12%)
        image = adjustContrast(image, amount: 1.12)

        // 4. Lift shadows / fade blacks (film look)
        image = fadeShadows(image)

        // 5. Vignette (darken edges)
        image = applyVignette(to: image)

        // 6. Film grain overlay
        image = applyGrain(to: image)

        // 7. Subtle light leak (amber glow in top-right corner)
        image = applyLightLeak(to: image)

        // Render to JPEG
        guard let cgImage = context.createCGImage(image, from: inputImage.extent) else { return nil }
        let uiImage = UIImage(cgImage: cgImage)
        return uiImage.jpegData(compressionQuality: 0.85)
    }

    // MARK: - Pipeline Steps

    /// Shift color temperature warmer (boost reds/yellows, reduce blues)
    private static func applyWarmth(to image: CIImage) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: 5800, y: 0)   // slightly warm neutral point
        filter.targetNeutral = CIVector(x: 4500, y: 0)  // push warmer
        return filter.outputImage ?? image
    }

    /// Adjust saturation (1.0 = normal, <1.0 = desaturated)
    private static func adjustSaturation(_ image: CIImage, amount: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = amount
        filter.brightness = 0.02  // very slight brightness lift
        filter.contrast = 1.0
        return filter.outputImage ?? image
    }

    /// Adjust contrast
    private static func adjustContrast(_ image: CIImage, amount: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.contrast = amount
        filter.saturation = 1.0
        filter.brightness = 0.0
        return filter.outputImage ?? image
    }

    /// Fade/lift the shadows to get that classic film look (blacks aren't pure black)
    private static func fadeShadows(_ image: CIImage) -> CIImage {
        // Use a curves-like approach: map 0 -> 0.06 (lift blacks)
        let filter = CIFilter.colorClamp()
        filter.inputImage = image
        filter.minComponents = CIVector(x: 0.04, y: 0.03, z: 0.02, w: 0) // warm lifted blacks
        filter.maxComponents = CIVector(x: 1, y: 0.98, z: 0.95, w: 1)    // slightly reduced highlights
        return filter.outputImage ?? image
    }

    /// Add edge vignette
    private static func applyVignette(to image: CIImage) -> CIImage {
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = 1.2
        filter.radius = 2.0
        return filter.outputImage ?? image
    }

    /// Add subtle film grain noise
    private static func applyGrain(to image: CIImage) -> CIImage {
        // Generate noise
        let noiseFilter = CIFilter.randomGenerator()
        guard let noise = noiseFilter.outputImage else { return image }

        // Scale and desaturate the noise
        let whitening = CIFilter.colorControls()
        whitening.inputImage = noise
        whitening.saturation = 0
        whitening.brightness = -0.4
        whitening.contrast = 3.0
        guard let whiteNoise = whitening.outputImage else { return image }

        // Crop noise to image size
        let croppedNoise = whiteNoise.cropped(to: image.extent)

        // Blend noise with original at low opacity
        let blend = CIFilter.sourceOverCompositing()
        let opacity = CIFilter.colorControls()
        opacity.inputImage = croppedNoise
        opacity.brightness = 0
        opacity.contrast = 1.0
        opacity.saturation = 0
        guard let adjustedNoise = opacity.outputImage else { return image }

        // Use multiply blend at very low opacity for subtle grain
        let multiply = CIFilter.multiplyBlendMode()
        multiply.inputImage = adjustedNoise.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.06) // 6% opacity
        ])
        multiply.backgroundImage = image
        return multiply.outputImage ?? image
    }

    /// Add a subtle amber/orange light leak in the top-right corner
    private static func applyLightLeak(to image: CIImage) -> CIImage {
        let extent = image.extent

        // Create a radial gradient for the light leak
        let center = CGPoint(x: extent.width * 0.85, y: extent.height * 0.85)

        let gradient = CIFilter.radialGradient()
        gradient.center = center
        gradient.radius0 = 0
        gradient.radius1 = Float(min(extent.width, extent.height) * 0.5)
        gradient.color0 = CIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.08) // warm amber, very subtle
        gradient.color1 = CIColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 0.0)
        guard let leak = gradient.outputImage?.cropped(to: extent) else { return image }

        // Add the light leak on top
        let composite = CIFilter.additionCompositing()
        composite.inputImage = leak
        composite.backgroundImage = image
        return composite.outputImage ?? image
    }
}
