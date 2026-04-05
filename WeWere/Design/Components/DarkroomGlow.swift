import SwiftUI

struct DarkroomGlow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.05),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
            )
    }
}

extension View {
    func darkroomGlow() -> some View {
        self.modifier(DarkroomGlow())
    }
}

#Preview {
    ZStack {
        WeWereColors.surface
            .ignoresSafeArea()

        Text("WeWere")
            .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 36))
            .foregroundStyle(WeWereColors.onSurface)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .darkroomGlow()
    }
}
