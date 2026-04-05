import SwiftUI

struct BrushedChromeButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: WeWereSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
            }
            .foregroundStyle(WeWereColors.onPrimary)
            .padding(.horizontal, WeWereSpacing.lg)
            .padding(.vertical, WeWereSpacing.sm)
        }
        .buttonStyle(BrushedChromeButtonStyle())
    }
}

// MARK: - Button Style

struct BrushedChromeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                LinearGradient(
                    colors: [.white, Color(hex: "d4d4d4")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        WeWereColors.surface
            .ignoresSafeArea()

        VStack(spacing: 20) {
            BrushedChromeButton(title: "Continue") {}
            BrushedChromeButton(title: "Upload", icon: "arrow.up") {}
        }
    }
}
