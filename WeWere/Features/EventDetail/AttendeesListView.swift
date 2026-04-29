import SwiftUI

struct AttendeesListView: View {
    let eventId: UUID
    @StateObject private var viewModel: EventDetailViewModel
    @EnvironmentObject var authService: AuthService

    init(eventId: UUID) {
        self.eventId = eventId
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(eventId: eventId))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
                // Title
                HStack {
                    Text("ATTENDEES")
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 24))
                        .tracking(2)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("\(viewModel.members.count)")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 16))
                        .foregroundStyle(WeWereColors.outline)
                }
                .padding(.horizontal, WeWereSpacing.md)
                .padding(.top, WeWereSpacing.md)

                // List
                VStack(spacing: 0) {
                    ForEach(viewModel.members, id: \.0.id) { member, user in
                        AttendeeRow(member: member, user: user)
                            .padding(.horizontal, WeWereSpacing.md)

                        if member.id != viewModel.members.last?.0.id {
                            Divider()
                                .overlay(WeWereColors.outlineVariant.opacity(0.3))
                                .padding(.horizontal, WeWereSpacing.md)
                        }
                    }
                }
                .padding(.vertical, WeWereSpacing.xs)
                .background(WeWereColors.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
                .padding(.horizontal, WeWereSpacing.md)

                Spacer(minLength: 100)
            }
        }
        .background(Color(hex: "#131313").ignoresSafeArea())
        .navigationBarHidden(true)
        .enableSwipeBack()
        .task {
            viewModel.authService = authService
            await viewModel.load()
        }
    }
}
