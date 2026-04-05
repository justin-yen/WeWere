import SwiftUI

struct LiveEventCard: View {
    let event: Event
    var photoCount: Int = 0
    var memberCount: Int = 0
    var onCamera: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Dark cinematic gradient background
            LinearGradient(
                colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f0f0f")
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            // Bottom overlay gradient for text legibility
            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: WeWereSpacing.xs) {
                Spacer()

                Text(event.name)
                    .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 28))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: WeWereSpacing.md) {
                    HStack(spacing: WeWereSpacing.xxs) {
                        Image(systemName: "camera")
                            .font(.system(size: 11))
                        Text("\(photoCount)")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                    }

                    HStack(spacing: WeWereSpacing.xxs) {
                        Image(systemName: "person.2")
                            .font(.system(size: 11))
                        Text("\(memberCount)")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                    }
                }
                .foregroundStyle(WeWereColors.onSurfaceVariant)
            }
            .padding(WeWereSpacing.lg)

            // Camera quick-access button (bottom right)
            if let onCamera {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            onCamera()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13))
                                Text("Expose")
                                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                            }
                            .foregroundStyle(Color(hex: "1a1c1c"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [.white, Color(hex: "d4d4d4")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.lg))
                        }
                    }
                }
                .padding(WeWereSpacing.lg)
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
    }
}

#Preview {
    LiveEventCard(
        event: Event(
            id: UUID(),
            hostId: UUID(),
            name: "Saturday Night",
            description: nil,
            location: nil,
            coverImageUrl: nil,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            status: .live,
            shareCode: "ABC123",
            createdAt: Date()
        ),
        photoCount: 24,
        memberCount: 8,
        onCamera: {}
    )
    .padding()
    .background(WeWereColors.surface)
}
