import SwiftUI

struct PhotoGridItem: View {
    let photo: Photo
    let imageURL: URL?

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(WeWereColors.surfaceContainerHigh)
                    .aspectRatio(photo.aspectRatio, contentMode: .fill)
                    .shimmer()

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(photo.aspectRatio, contentMode: .fill)
                    .clipped()

            case .failure:
                Rectangle()
                    .fill(WeWereColors.surfaceContainerHigh)
                    .aspectRatio(photo.aspectRatio, contentMode: .fill)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(WeWereColors.outline)
                    )

            @unknown default:
                Rectangle()
                    .fill(WeWereColors.surfaceContainerHigh)
                    .aspectRatio(photo.aspectRatio, contentMode: .fill)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.md))
    }
}
