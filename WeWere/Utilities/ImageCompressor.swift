import UIKit

enum ImageCompressor {
    static func compress(imageData: Data, maxDimension: CGFloat = 2048, quality: CGFloat = 0.8) -> Data? {
        guard let image = UIImage(data: imageData) else { return nil }

        let size = image.size
        let longestEdge = max(size.width, size.height)

        let scaledImage: UIImage
        if longestEdge > maxDimension {
            let scale = maxDimension / longestEdge
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            scaledImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            scaledImage = image
        }

        return scaledImage.jpegData(compressionQuality: quality)
    }
}
