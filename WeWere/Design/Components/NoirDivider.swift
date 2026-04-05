import SwiftUI

struct NoirDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                RadialGradient(
                    colors: [
                        WeWereColors.outlineVariant,
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            )
            .frame(height: 1)
    }
}

#Preview {
    ZStack {
        WeWereColors.surface
            .ignoresSafeArea()

        VStack(spacing: 24) {
            Text("Above")
                .foregroundStyle(WeWereColors.onSurface)
            NoirDivider()
            Text("Below")
                .foregroundStyle(WeWereColors.onSurface)
        }
        .padding()
    }
}
