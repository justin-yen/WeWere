import SwiftUI

/// A shimmer/skeleton loading effect using TimelineView for reliable animation
struct ShimmerModifier: ViewModifier {
    let duration: Double = 2.0

    func body(content: Content) -> some View {
        content
            .overlay(
                TimelineView(.animation) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    let t = CGFloat(now.truncatingRemainder(dividingBy: duration) / duration)
                    // Map t from 0...1 to -0.5...1.5 so the gradient sweeps fully across
                    let center = t * 2.0 - 0.5

                    let s0 = max(0, min(1, center - 0.4))
                    let s1 = max(s0, min(1, center - 0.15))
                    let s2 = max(s1, min(1, center))
                    let s3 = max(s2, min(1, center + 0.15))
                    let s4 = max(s3, min(1, center + 0.4))

                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: s0),
                            .init(color: Color.white.opacity(0.03), location: s1),
                            .init(color: Color.white.opacity(0.06), location: s2),
                            .init(color: Color.white.opacity(0.03), location: s3),
                            .init(color: .clear, location: s4),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .clipped()
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

/// Matches PhotoGridItem layout exactly
struct PhotoSkeletonCell: View {
    var body: some View {
        Rectangle()
            .fill(WeWereColors.surfaceContainerHigh)
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .frame(minWidth: 0, maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.md))
            .shimmer()
    }
}
