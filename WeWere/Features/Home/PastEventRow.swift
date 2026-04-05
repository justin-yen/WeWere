import SwiftUI

struct PastEventRow: View {
    let event: Event
    var isReadyToDevelop: Bool = false

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: event.endTime)
    }

    var body: some View {
        HStack(spacing: WeWereSpacing.sm) {
            // Placeholder thumbnail
            RoundedRectangle(cornerRadius: WeWereRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "2a2a2a"), Color(hex: "1a1a1a")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundStyle(WeWereColors.outlineVariant)
                )

            VStack(alignment: .leading, spacing: WeWereSpacing.xxxs) {
                Text(event.name)
                    .font(.custom(WeWereFontFamily.jakartaBold, size: 16))
                    .foregroundStyle(WeWereColors.onSurface)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                    .foregroundStyle(WeWereColors.outline)
            }

            Spacer()

            if isReadyToDevelop {
                // Amber indicator for undeveloped events
                Circle()
                    .fill(Color(hex: "D4A853"))
                    .frame(width: 10, height: 10)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WeWereColors.outlineVariant)
            }
        }
        .padding(WeWereSpacing.sm)
        .background(WeWereColors.surfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
    }
}

#Preview {
    VStack(spacing: 12) {
        PastEventRow(
            event: Event(
                id: UUID(),
                hostId: UUID(),
                name: "Birthday Bash",
                description: nil,
                coverImageUrl: nil,
                startTime: Date(),
                endTime: Date(),
                status: .ended,
                shareCode: "XYZ789",
                createdAt: Date()
            ),
            isReadyToDevelop: true
        )

        PastEventRow(
            event: Event(
                id: UUID(),
                hostId: UUID(),
                name: "New Year's Eve",
                description: nil,
                coverImageUrl: nil,
                startTime: Date(),
                endTime: Date(),
                status: .ended,
                shareCode: "NYE456",
                createdAt: Date()
            ),
            isReadyToDevelop: false
        )
    }
    .padding()
    .background(WeWereColors.surface)
}
