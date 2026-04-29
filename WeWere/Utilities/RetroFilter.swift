import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Filter Style

enum FilterStyle: String, CaseIterable, Identifiable {
    case portra = "Portra 400"
    case gold = "Gold 200"
    case bw = "Tri-X 400"
    case chrome = "Chrome"
    case fade = "Fade"
    case none = "Original"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .portra: return "Soft, muted tones"
        case .gold: return "Warm, saturated"
        case .bw: return "High-contrast B&W"
        case .chrome: return "Cool, punchy"
        case .fade: return "Washed out, dreamy"
        case .none: return "No filter"
        }
    }

    var icon: String {
        switch self {
        case .portra: return "camera.filters"
        case .gold: return "sun.max"
        case .bw: return "circle.lefthalf.filled"
        case .chrome: return "sparkle"
        case .fade: return "aqi.medium"
        case .none: return "photo"
        }
    }
}

// MARK: - RetroFilter

enum RetroFilter {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Apply the given filter style to image data. Returns filtered UIImage.
    static func apply(style: FilterStyle, to imageData: Data) -> UIImage? {
        guard let uiImage = UIImage(data: imageData),
              let normalizedImage = normalizeOrientation(uiImage),
              let normalizedData = normalizedImage.jpegData(compressionQuality: 1.0),
              let inputImage = CIImage(data: normalizedData) else { return nil }

        let filtered: CIImage
        switch style {
        case .portra: filtered = applyPortra(to: inputImage)
        case .gold: filtered = applyGold(to: inputImage)
        case .bw: filtered = applyTriX(to: inputImage)
        case .chrome: filtered = applyChrome(to: inputImage)
        case .fade: filtered = applyFade(to: inputImage)
        case .none: return normalizedImage
        }

        guard let cgImage = context.createCGImage(filtered, from: inputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Legacy method — applies default Portra filter, returns JPEG data.
    static func apply(to imageData: Data) -> Data? {
        guard let image = apply(style: .portra, to: imageData) else { return nil }
        return image.jpegData(compressionQuality: 0.85)
    }

    // MARK: - Portra 400

    private static func applyPortra(to image: CIImage) -> CIImage {
        var img = image
        img = applyWarmth(to: img, neutral: 6200, target: 5400, tint: -10)
        img = adjustColorControls(img, saturation: 0.88, brightness: 0.015, contrast: 0.95)
        img = shadowLift(img, r: 0.035, g: 0.025, b: 0.03)
        img = highlightRolloff(img, highlight: 0.85, shadow: 0.15)
        img = applyVignette(to: img, intensity: 0.6, radius: 2.5)
        img = applyGrain(to: img, opacity: 0.04)
        return img
    }

    // MARK: - Gold 200

    private static func applyGold(to image: CIImage) -> CIImage {
        var img = image
        img = applyWarmth(to: img, neutral: 6500, target: 4800, tint: 5)
        img = adjustColorControls(img, saturation: 1.12, brightness: 0.02, contrast: 1.08)
        img = shadowLift(img, r: 0.04, g: 0.025, b: 0.015)
        img = highlightRolloff(img, highlight: 0.9, shadow: 0.1)
        img = applyVignette(to: img, intensity: 1.0, radius: 2.0)
        img = applyGrain(to: img, opacity: 0.06)
        return img
    }

    // MARK: - Tri-X 400 (B&W)

    private static func applyTriX(to image: CIImage) -> CIImage {
        var img = image
        // Desaturate fully
        img = adjustColorControls(img, saturation: 0.0, brightness: 0.0, contrast: 1.2)
        // High contrast with deep blacks
        img = shadowLift(img, r: 0.02, g: 0.02, b: 0.02)
        img = highlightRolloff(img, highlight: 0.95, shadow: 0.05)
        img = applyVignette(to: img, intensity: 0.8, radius: 2.0)
        img = applyGrain(to: img, opacity: 0.08)
        return img
    }

    // MARK: - Chrome

    private static func applyChrome(to image: CIImage) -> CIImage {
        var img = image
        // Cool temperature
        img = applyWarmth(to: img, neutral: 5500, target: 7000, tint: -5)
        img = adjustColorControls(img, saturation: 1.1, brightness: 0.0, contrast: 1.15)
        // Slightly blue shadows
        img = shadowLift(img, r: 0.015, g: 0.02, b: 0.035)
        img = highlightRolloff(img, highlight: 0.92, shadow: 0.08)
        img = applyVignette(to: img, intensity: 0.4, radius: 2.5)
        img = applyGrain(to: img, opacity: 0.03)
        return img
    }

    // MARK: - Fade

    private static func applyFade(to image: CIImage) -> CIImage {
        var img = image
        img = applyWarmth(to: img, neutral: 6000, target: 5800, tint: 0)
        img = adjustColorControls(img, saturation: 0.7, brightness: 0.04, contrast: 0.82)
        // Heavy shadow lift — washed out blacks
        img = shadowLift(img, r: 0.08, g: 0.07, b: 0.07)
        img = highlightRolloff(img, highlight: 0.88, shadow: 0.2)
        img = applyVignette(to: img, intensity: 0.3, radius: 3.0)
        img = applyGrain(to: img, opacity: 0.05)
        return img
    }

    // MARK: - Shared Pipeline Helpers

    private static func applyWarmth(to image: CIImage, neutral: CGFloat, target: CGFloat, tint: CGFloat) -> CIImage {
        let filter = CIFilter.temperatureAndTint()
        filter.inputImage = image
        filter.neutral = CIVector(x: neutral, y: 0)
        filter.targetNeutral = CIVector(x: target, y: tint)
        return filter.outputImage ?? image
    }

    private static func adjustColorControls(_ image: CIImage, saturation: Float, brightness: Float, contrast: Float) -> CIImage {
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = saturation
        filter.brightness = brightness
        filter.contrast = contrast
        return filter.outputImage ?? image
    }

    private static func shadowLift(_ image: CIImage, r: CGFloat, g: CGFloat, b: CGFloat) -> CIImage {
        let filter = CIFilter.colorClamp()
        filter.inputImage = image
        filter.minComponents = CIVector(x: r, y: g, z: b, w: 0)
        filter.maxComponents = CIVector(x: 0.98, y: 0.97, z: 0.96, w: 1)
        return filter.outputImage ?? image
    }

    private static func highlightRolloff(_ image: CIImage, highlight: Float, shadow: Float) -> CIImage {
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = image
        filter.highlightAmount = highlight
        filter.shadowAmount = shadow
        return filter.outputImage ?? image
    }

    private static func applyVignette(to image: CIImage, intensity: Float, radius: Float) -> CIImage {
        let filter = CIFilter.vignette()
        filter.inputImage = image
        filter.intensity = intensity
        filter.radius = radius
        return filter.outputImage ?? image
    }

    private static func applyGrain(to image: CIImage, opacity: CGFloat) -> CIImage {
        let noiseFilter = CIFilter.randomGenerator()
        guard let noise = noiseFilter.outputImage else { return image }

        let whitening = CIFilter.colorControls()
        whitening.inputImage = noise
        whitening.saturation = 0
        whitening.brightness = -0.5
        whitening.contrast = 2.5
        guard let whiteNoise = whitening.outputImage else { return image }

        let croppedNoise = whiteNoise.cropped(to: image.extent)

        let multiply = CIFilter.multiplyBlendMode()
        multiply.inputImage = croppedNoise.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: opacity)
        ])
        multiply.backgroundImage = image
        return multiply.outputImage ?? image
    }

    /// Normalize image orientation so pixels match the visual orientation.
    static func normalizeOrientation(_ image: UIImage) -> UIImage? {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized
    }
}
