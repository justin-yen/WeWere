import SwiftUI

struct EventDetailView: View {
    @StateObject var viewModel: EventDetailViewModel
    @EnvironmentObject var appState: AppState

    init(eventId: UUID) {
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(eventId: eventId))
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: WeWereSpacing.lg) {
                // MARK: - Hero Area
                heroSection

                // MARK: - Event Info
                eventInfoSection

                // MARK: - Open Camera (Live Only)
                if viewModel.event?.isLive == true {
                    cameraButton
                }

                // MARK: - End Event (Host Only)
                if viewModel.isHost && viewModel.event?.isLive == true {
                    endEventButton
                }

                // MARK: - Share Link
                if let url = viewModel.event?.shareURL {
                    shareLinkSection(url: url)
                }

                // MARK: - Attendees
                attendeesSection

                // MARK: - Location
                locationSection

                Spacer(minLength: WeWereSpacing.xxxl)
            }
        }
        .background(Color(hex: "#131313").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
            viewModel.subscribeToUpdates()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient placeholder for cover image
            LinearGradient(
                colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f3460"),
                    Color(hex: "0f0f0f")
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .frame(height: 300)

            // Bottom fade
            LinearGradient(
                colors: [.clear, Color(hex: "#131313")],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 300)

            // Live badge
            if viewModel.event?.isLive == true {
                liveBadge
                    .padding(WeWereSpacing.md)
            }
        }
        .frame(height: 300)
    }

    private var liveBadge: some View {
        HStack(spacing: WeWereSpacing.xxs) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)

            Text("LIVE NOW")
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                .tracking(1.5)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, WeWereSpacing.sm)
        .padding(.vertical, WeWereSpacing.xxs + 2)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Event Info Section

    private var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.md) {
            if let event = viewModel.event {
                Text(event.name)
                    .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 32))
                    .foregroundStyle(.white)

                // Photo count
                HStack(spacing: WeWereSpacing.xs) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                    Text("\(viewModel.photoCount)")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 24))
                }
                .foregroundStyle(WeWereColors.onSurface)
            }
        }
        .padding(.horizontal, WeWereSpacing.md)
    }

    // MARK: - Camera Button

    private var cameraButton: some View {
        HStack {
            Spacer()
            BrushedChromeButton(title: "Open Camera", icon: "camera") {
                appState.presentedSheet = .camera(viewModel.eventId)
            }
            Spacer()
        }
        .padding(.horizontal, WeWereSpacing.md)
    }

    // MARK: - End Event Button

    private var endEventButton: some View {
        Button {
            viewModel.showEndConfirmation = true
        } label: {
            HStack(spacing: WeWereSpacing.xs) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 16))
                Text(viewModel.isEnding ? "ENDING..." : "END EVENT")
                    .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WeWereColors.errorContainer)
            .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
        }
        .disabled(viewModel.isEnding)
        .padding(.horizontal, WeWereSpacing.md)
        .alert("End Event", isPresented: $viewModel.showEndConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("End Event", role: .destructive) {
                Task { await viewModel.endEvent() }
            }
        } message: {
            Text("This will lock all photos and notify attendees that the film is ready to develop. This cannot be undone.")
        }
    }

    // MARK: - Share Link

    private func shareLinkSection(url: URL) -> some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.xs) {
            Text("SHARE LINK")
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurfaceVariant)

            ShareLink(item: url) {
                HStack(spacing: WeWereSpacing.xs) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                    Text(url.absoluteString)
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                }
                .foregroundStyle(WeWereColors.onSurface)
                .padding(WeWereSpacing.sm)
                .background(WeWereColors.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
            }
        }
        .padding(.horizontal, WeWereSpacing.md)
    }

    // MARK: - Attendees Section

    private var attendeesSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
            HStack {
                Text("ATTENDEES")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                    .tracking(2)
                    .foregroundStyle(WeWereColors.onSurfaceVariant)

                Text("\(viewModel.members.count)")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                    .foregroundStyle(WeWereColors.outline)
            }

            VStack(spacing: 0) {
                ForEach(viewModel.members, id: \.0.id) { member, user in
                    AttendeeRow(member: member, user: user)

                    if member.id != viewModel.members.last?.0.id {
                        Divider()
                            .overlay(WeWereColors.outlineVariant.opacity(0.3))
                    }
                }
            }
            .padding(WeWereSpacing.sm)
            .background(WeWereColors.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
        }
        .padding(.horizontal, WeWereSpacing.md)
    }

    // MARK: - Location Section

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
            Text("LOCATION")
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurfaceVariant)

            // Placeholder map area
            RoundedRectangle(cornerRadius: WeWereRadius.xl)
                .fill(WeWereColors.surfaceContainerHigh)
                .frame(height: 160)
                .overlay(
                    VStack(spacing: WeWereSpacing.xs) {
                        Image(systemName: "map")
                            .font(.system(size: 24))
                            .foregroundStyle(WeWereColors.outlineVariant)
                        Text("Map placeholder")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                            .foregroundStyle(WeWereColors.outline)
                    }
                )
        }
        .padding(.horizontal, WeWereSpacing.md)
    }
}

#Preview {
    NavigationStack {
        EventDetailView(eventId: UUID())
            .environmentObject(AppState())
    }
}
