import SwiftUI

struct ShutterButton: View {
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 72, height: 72)

                // Inner circle – brushed chrome gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(hex: "d4d4d4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 62, height: 62)
            }
        }
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .buttonStyle(.plain)
    }
}
