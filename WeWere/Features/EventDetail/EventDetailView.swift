import SwiftUI
import MapKit

struct EventDetailView: View {
    @StateObject var viewModel: EventDetailViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    init(eventId: UUID) {
        _viewModel = StateObject(wrappedValue: EventDetailViewModel(eventId: eventId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ZStack {
                    Color(hex: "#131313").ignoresSafeArea()
                    ProgressView()
                        .tint(WeWereColors.outline)
                }
            } else {
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
            }
        }
        .background(Color(hex: "#131313").ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(hex: "#131313"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .task {
            viewModel.authService = authService
            await viewModel.load()
            viewModel.subscribeToUpdates()
            viewModel.subscribeToEventEnd()
        }
        .onChange(of: viewModel.eventWasEnded) { _, ended in
            if ended && !viewModel.isHost {
                // Attendee: pop back to home when host ends the event
                appState.navigationPath = NavigationPath()
            }
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
            .frame(height: 150)

            // Bottom fade
            LinearGradient(
                colors: [.clear, Color(hex: "#131313")],
                startPoint: .center,
                endPoint: .bottom
            )
            .frame(height: 150)

            // Live badge
            if viewModel.event?.isLive == true {
                liveBadge
                    .padding(WeWereSpacing.md)
            }
        }
        .frame(height: 150)
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
            Text("Invite friends")
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurfaceVariant)

            if let event = viewModel.event {
                ShareLink(item: event.shareText) {
                    HStack(spacing: WeWereSpacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Share film roll")
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                        Spacer()
                        Text(event.shareCode)
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                            .foregroundStyle(WeWereColors.outline)
                    }
                    .foregroundStyle(WeWereColors.onSurface)
                    .padding(WeWereSpacing.sm)
                    .background(WeWereColors.surfaceContainerHigh)
                    .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
                }
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

    @State private var showMapActionSheet = false

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
            Text("LOCATION")
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurfaceVariant)

            if let event = viewModel.event,
               let lat = event.locationLat,
               let lng = event.locationLng {
                // Interactive map preview
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                let region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )

                Map(initialPosition: .region(region), interactionModes: []) {
                    Marker(event.locationName ?? event.location ?? "Event", coordinate: coordinate)
                }
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
                .onTapGesture {
                    showMapActionSheet = true
                }
                .confirmationDialog("Open in Maps", isPresented: $showMapActionSheet) {
                    Button("Open in Apple Maps") {
                        let name = (event.locationName ?? event.location ?? "Event")
                            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        if let url = URL(string: "http://maps.apple.com/?ll=\(lat),\(lng)&q=\(name)") {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Open in Google Maps") {
                        let name = (event.locationName ?? event.location ?? "Event")
                            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        let googleMapsApp = URL(string: "comgooglemaps://?center=\(lat),\(lng)&q=\(name)")!
                        if UIApplication.shared.canOpenURL(googleMapsApp) {
                            UIApplication.shared.open(googleMapsApp)
                        } else if let webURL = URL(string: "https://www.google.com/maps/search/?api=1&query=\(lat),\(lng)") {
                            UIApplication.shared.open(webURL)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

                // Location name and address below the map
                VStack(alignment: .leading, spacing: 2) {
                    if let name = event.locationName {
                        Text(name)
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                            .foregroundStyle(WeWereColors.onSurface)
                    }
                    if let address = event.locationAddress {
                        Text(address)
                            .font(.custom(WeWereFontFamily.jakartaRegular, size: 12))
                            .foregroundStyle(WeWereColors.outline)
                    }
                }
            } else if let event = viewModel.event, let location = event.location, !location.isEmpty {
                // Plain text location (no coordinates)
                HStack(spacing: WeWereSpacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(WeWereColors.outline)
                    Text(location)
                        .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                        .foregroundStyle(WeWereColors.onSurface)
                }
                .padding(WeWereSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(WeWereColors.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
            } else {
                // No location set
                RoundedRectangle(cornerRadius: WeWereRadius.xl)
                    .fill(WeWereColors.surfaceContainerHigh)
                    .frame(height: 160)
                    .overlay(
                        VStack(spacing: WeWereSpacing.xs) {
                            Image(systemName: "map")
                                .font(.system(size: 24))
                                .foregroundStyle(WeWereColors.outlineVariant)
                            Text("No location set")
                                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                                .foregroundStyle(WeWereColors.outline)
                        }
                    )
            }
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
