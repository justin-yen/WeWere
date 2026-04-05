import SwiftUI

struct AttendeeRow: View {
    let member: EventMember
    let user: AppUser
    var photoCount: Int? = nil

    var body: some View {
        HStack(spacing: WeWereSpacing.sm) {
            // Avatar placeholder
            Circle()
                .fill(WeWereColors.secondaryContainer)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                        .foregroundStyle(WeWereColors.onSurfaceVariant)
                )

            Text(user.displayName)
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                .foregroundStyle(WeWereColors.onSurface)
                .lineLimit(1)

            if member.isHost {
                Text("HOST")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 9))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(WeWereColors.outlineVariant)
                    .clipShape(Capsule())
            }

            Spacer()

            if let photoCount {
                HStack(spacing: WeWereSpacing.xxxs) {
                    Image(systemName: "camera")
                        .font(.system(size: 10))
                    Text("\(photoCount)")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                }
                .foregroundStyle(WeWereColors.outline)
            }
        }
        .padding(.vertical, WeWereSpacing.xxs)
    }
}

#Preview {
    VStack {
        AttendeeRow(
            member: EventMember(
                id: UUID(),
                eventId: UUID(),
                userId: UUID(),
                role: .host,
                hasDeveloped: false,
                developedAt: nil,
                joinedAt: Date()
            ),
            user: AppUser(
                id: UUID(),
                authId: UUID(),
                firstName: "Jane",
                lastName: "Doe",
                displayName: "Jane Doe",
                instagramHandle: nil,
                phoneNumber: nil,
                avatarUrl: nil,
                pushToken: nil,
                createdAt: Date()
            ),
            photoCount: 12
        )

        AttendeeRow(
            member: EventMember(
                id: UUID(),
                eventId: UUID(),
                userId: UUID(),
                role: .attendee,
                hasDeveloped: false,
                developedAt: nil,
                joinedAt: Date()
            ),
            user: AppUser(
                id: UUID(),
                authId: UUID(),
                firstName: "John",
                lastName: "Smith",
                displayName: "John Smith",
                instagramHandle: nil,
                phoneNumber: nil,
                avatarUrl: nil,
                pushToken: nil,
                createdAt: Date()
            ),
            photoCount: 5
        )
    }
    .padding()
    .background(WeWereColors.surface)
}
