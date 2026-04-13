import SwiftUI

struct PastEventsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sharedViewModel: SharedEventsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: WeWereSpacing.lg) {
                // Create New Event button
                Button {
                    appState.presentedSheet = .createEvent
                } label: {
                    Text("CREATE NEW EVENT")
                        .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                        .italic()
                        .tracking(1.5)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color(hex: "a0a0a0"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "2a2a2a"), Color(hex: "1a1a1a")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(WeWereColors.outlineVariant.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Past Events header with count
                HStack {
                    Text("PAST EVENTS")
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 20))
                        .tracking(2)
                        .foregroundStyle(WeWereColors.onSurface)

                    Spacer()

                    Text("TOTAL / \(sharedViewModel.developedEvents.count)")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                        .foregroundStyle(WeWereColors.outline)
                }

                if sharedViewModel.developedEvents.isEmpty && !sharedViewModel.isLoading {
                    VStack(spacing: WeWereSpacing.md) {
                        Spacer().frame(height: 80)

                        Image(systemName: "film.stack")
                            .font(.system(size: 40))
                            .foregroundStyle(WeWereColors.outlineVariant)

                        Text("NO DEVELOPED EVENTS")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 14))
                            .tracking(2)
                            .foregroundStyle(WeWereColors.onSurfaceVariant)

                        Text("Events you've developed\nwill appear here.")
                            .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                            .foregroundStyle(WeWereColors.outline)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // 2x2 grid of event cards
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(sharedViewModel.developedEvents) { event in
                            NavigationLink(value: Route.album(event.id)) {
                                EventGridCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, WeWereSpacing.md)
            .padding(.top, WeWereSpacing.sm)
        }
        .background(Color(hex: "#131313").ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Event Grid Card

struct EventGridCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover image placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1a1a2e"), Color(hex: "0f0f0f")],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .aspectRatio(1, contentMode: .fill)

                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(WeWereColors.outlineVariant.opacity(0.5))

                    Text("EVENT COVER")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 8))
                        .tracking(1)
                        .foregroundStyle(WeWereColors.outlineVariant.opacity(0.4))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Event name -- matches Stitch: bold, white, compact
            Text(event.name.uppercased())
                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 13))
                .tracking(1)
                .foregroundStyle(WeWereColors.onSurface)
                .lineLimit(2)

            // Date
            Text(formattedDate(event.endTime))
                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                .foregroundStyle(WeWereColors.outline)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date).uppercased()
    }
}
