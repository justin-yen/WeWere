import SwiftUI

struct FilmGrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            let dotCount = Int(size.width * size.height) / 40

            for _ in 0..<dotCount {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let brightness = CGFloat.random(in: 0.3...1.0)

                let color = Color(
                    .sRGB,
                    red: brightness,
                    green: brightness,
                    blue: brightness,
                    opacity: 0.03
                )

                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(Path(rect), with: .color(color))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - View Modifier

extension View {
    func filmGrainOverlay() -> some View {
        self.overlay(FilmGrainOverlay())
    }
}

#Preview {
    ZStack {
        WeWereColors.surface
            .ignoresSafeArea()

        FilmGrainOverlay()
    }
}
