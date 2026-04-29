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

                        // MARK: - Share Link
                        if let url = viewModel.event?.shareURL {
                            shareLinkSection(url: url)
                        }

                        // MARK: - Attendees
                        attendeesSection

                        // MARK: - Location
                        locationSection

                        // MARK: - End Event (Host Only)
                        if viewModel.isHost && viewModel.event?.isLive == true {
                            endEventButton
                        }

                        Spacer(minLength: WeWereSpacing.xxxl)
                    }
                }
            }
        }
        .background(Color(hex: "#131313").ignoresSafeArea())
        .navigationBarHidden(true)
        .enableSwipeBack()
        .task {
            viewModel.authService = authService
            await viewModel.load()
            viewModel.subscribeToUpdates()
            viewModel.subscribeToEventEnd()
        }
        .onChange(of: viewModel.eventWasEnded) { _, ended in
            if ended {
                // Everyone pops back to home — host sees their event now in "Ready to Develop",
                // attendees see it moved out of live events.
                withAnimation(.easeInOut(duration: 0.35)) {
                    appState.navigationPath = NavigationPath()
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Cover photo or gradient fallback
            if let urlString = viewModel.event?.coverPhotoUrl,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 240)
                            .clipped()
                    default:
                        heroGradient
                    }
                }
                .frame(height: 240)
            } else {
                heroGradient
            }

            // Bottom fade
            LinearGradient(
                colors: [.clear, Color(hex: "#131313")],
                startPoint: .center,
                endPoint: .bottom
            )

            // Overlay content: title + camera button stacked
            VStack(alignment: .leading, spacing: WeWereSpacing.sm) {
                Spacer()

                // Live badge
                if viewModel.event?.isLive == true {
                    liveBadge
                }

                if let event = viewModel.event {
                    Text(event.name)
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 28))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }

                HStack {
                    // Photo count
                    HStack(spacing: WeWereSpacing.xxs) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13))
                        Text("\(viewModel.photoCount)")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 16))
                    }
                    .foregroundStyle(WeWereColors.onSurfaceVariant)

                    Spacer()

                    if viewModel.event?.isLive == true {
                        Button {
                            appState.presentedSheet = .camera(viewModel.eventId)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13))
                                Text("Open Camera")
                                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: WeWereRadius.lg)
                                    .stroke(.white, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, WeWereSpacing.md)
            .padding(.bottom, WeWereSpacing.md)
        }
        .frame(height: 240)
    }

    private var heroGradient: some View {
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
            Text("INVITE FRIENDS")
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

            NavigationLink(value: Route.attendees(viewModel.eventId)) {
                HStack(spacing: WeWereSpacing.xs) {
                    GeometryReader { geo in
                        attendeeCircles(maxWidth: geo.size.width)
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: 36)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(WeWereColors.outline)
                }
                .padding(WeWereSpacing.sm)
                .background(WeWereColors.surfaceContainerHigh)
                .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WeWereSpacing.md)
    }

    private func attendeeCircles(maxWidth: CGFloat) -> some View {
        // Each circle is 36pt, overlapping by 8pt → 28pt effective after the first.
        let circleSize: CGFloat = 36
        let overlap: CGFloat = 8
        let step = circleSize - overlap // 28
        let total = viewModel.members.count

        // How many circles can fit in the available width?
        // width = circleSize + step * (count - 1)  →  count = (width - circleSize) / step + 1
        let maxFit = max(1, Int((maxWidth - circleSize) / step) + 1)

        let circlesToShow: Int
        let overflowCount: Int
        let showOverflow: Bool

        if total <= maxFit {
            circlesToShow = total
            showOverflow = false
            overflowCount = 0
        } else {
            // Reserve the last slot for the "+N" badge
            circlesToShow = maxFit - 1
            overflowCount = total - circlesToShow
            showOverflow = true
        }

        return HStack(spacing: -overlap) {
            ForEach(0..<circlesToShow, id: \.self) { index in
                let user = viewModel.members[index].1
                initialCircle(text: initials(for: user), isOverflow: false)
            }

            if showOverflow {
                initialCircle(text: "+\(overflowCount)", isOverflow: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func initialCircle(text: String, isOverflow: Bool) -> some View {
        Circle()
            .fill(isOverflow ? WeWereColors.surfaceContainerHighest : WeWereColors.secondaryContainer)
            .frame(width: 36, height: 36)
            .overlay(
                Text(text)
                    .font(.custom(WeWereFontFamily.jakartaBold, size: isOverflow ? 12 : 13))
                    .foregroundStyle(.white)
            )
            .overlay(
                Circle()
                    .stroke(WeWereColors.surfaceContainerHigh, lineWidth: 2)
            )
    }

    private func initials(for user: AppUser) -> String {
        let first = user.firstName.first.map { String($0) } ?? ""
        let last = user.lastName.first.map { String($0) } ?? ""
        let combined = (first + last).uppercased()
        return combined.isEmpty ? String(user.resolvedDisplayName.prefix(1)).uppercased() : combined
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
