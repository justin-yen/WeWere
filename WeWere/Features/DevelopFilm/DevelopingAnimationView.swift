import SwiftUI

struct DevelopingAnimationView: View {
    let eventId: UUID

    @EnvironmentObject var appState: AppState

    @State private var polaroidOffset: CGFloat = 200
    @State private var photoBlur: CGFloat = 30
    @State private var developingOpacity: Double = 0.3
    @State private var hasNavigated = false
    @State private var developingPhrase = Self.phrases.randomElement()!

    private static let phrases = [
        "Developing your\nmidnight vision.",
        "Pulling memories\nfrom the silver halide.",
        "Your night is\ncoming into focus.",
        "Washing the light\nthrough chemistry.",
        "The emulsion\nremembers everything.",
        "Coaxing ghosts\nfrom the grain.",
        "Every frame holds\na secret.",
        "The darkroom\nnever lies.",
        "Fixing the moments\nyou almost forgot.",
        "Silver and light,\ndoing their thing.",
        "Patience. The best\nshots take time.",
        "Your memories are\nstill wet.",
        "The negative knows\nmore than you think.",
        "Letting the\nchemistry do its work.",
        "Stop bath applied.\nAlmost there.",
        "The fixer is\nworking its magic.",
        "Agitating gently.\nDon't rush art.",
        "Your film has\nstories to tell.",
        "The red light\nis on.",
        "Somewhere between\nlight and memory.",
        "Analog patience\nin a digital world.",
        "The grain is\nthe texture of time.",
        "Each crystal holds\na tiny universe.",
        "Your night,\npreserved in silver.",
        "The developer\nnever forgets.",
        "36 chances to\ncapture forever.",
        "Some moments only\nexist on film.",
        "Trust the process.\nTrust the grain.",
        "The light you saw\nis still in there.",
        "Rendering warmth\nfrom cold chemistry.",
        "This is the part\nwhere magic happens.",
        "Your memories are\nbeing born.",
        "The wait is\npart of the art.",
        "Exposures becoming\nexperiences.",
        "Turning photons\ninto feelings.",
        "The latent image\nis revealing itself.",
        "Slow down.\nGood things develop.",
        "Your night in\n4800 dpi.",
        "Chemical reactions\nmaking art.",
        "The enlarger hums.\nThe print emerges.",
        "From darkness,\nlight.",
        "Every print is\na small miracle.",
        "The tray rocks.\nThe image appears.",
        "Burnt amber tones\nloading.",
        "Calibrating\nnostalgia levels.",
        "Reconstructing\nthe golden hour.",
        "Processing the\nin-between moments.",
        "The best photos\nare worth waiting for.",
        "Film speed:\nthe pace of memory.",
        "Your highlights\nare blooming.",
        "Dodging shadows,\nburning memories.",
        "The contact sheet\nof your night.",
        "Hanging prints\non the line.",
        "The squeegee\nof truth.",
        "One more rinse.\nAlmost perfect.",
        "Your night,\nunfiltered. Almost.",
        "Scanning the\nnegatives of now.",
        "The aperture\nof your evening.",
        "Shutter speed:\none heartbeat.",
        "ISO of\npure feeling.",
        "Focus was never\nthe point.",
        "Bokeh dreams\nand sharp memories.",
        "The viewfinder\nsaw what you felt.",
        "Rewind. Develop.\nRemember.",
        "Click. Wind.\nRepeat. Reveal.",
        "Your disposable\nmoments, made permanent.",
        "The flash fades.\nThe image stays.",
        "What the lens\ncaptured, the heart knew.",
        "Proof that\nyou were there.",
        "These moments\nwere worth saving.",
    ]

    var body: some View {
        ZStack {
            // Background
            WeWereColors.surface
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top metadata
                VStack(spacing: 4) {
                    Text("Processing Node AXON-B_v04")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                        .foregroundStyle(WeWereColors.outline)

                    Text("Roll ID #MN-90882-X")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                        .foregroundStyle(WeWereColors.outline)
                }
                .padding(.top, WeWereSpacing.xxl)

                Spacer()

                // MARK: - Polaroid frame
                VStack(spacing: 8) {
                    // White polaroid card
                    VStack(spacing: 0) {
                        // Photo area
                        ZStack {
                            Rectangle()
                                .fill(WeWereColors.surfaceContainerHigh)
                                .aspectRatio(1.0, contentMode: .fit)
                                .blur(radius: photoBlur)

                            Text("DEVELOPING...")
                                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                                .tracking(2)
                                .foregroundStyle(.white)
                                .opacity(developingOpacity)
                        }
                        .padding(16)
                        .padding(.bottom, 0)

                        // Bottom padding for polaroid look
                        Color.clear
                            .frame(height: 40)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                    )
                    .frame(width: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Metadata below polaroid
                    HStack(spacing: WeWereSpacing.md) {
                        Text(formattedDate)
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                            .foregroundStyle(WeWereColors.outline)

                        Text("Exposure +1.2")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                            .foregroundStyle(WeWereColors.outline)
                    }
                }
                .offset(y: polaroidOffset)

                Spacer()

                // MARK: - Title text
                Text(developingPhrase)
                    .font(.custom(WeWereFontFamily.jakartaBold, size: 24))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, WeWereSpacing.lg)

                // MARK: - Technical metadata
                VStack(spacing: 6) {
                    Text("LATENCY 42ms | PHASE RENDERING / 03")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                        .foregroundStyle(WeWereColors.outline)

                    Text("ISO 3200 | SHUTTER 1/250 | APERTURE f/1.8")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                        .foregroundStyle(WeWereColors.outline)
                }
                .padding(.top, WeWereSpacing.lg)
                .padding(.bottom, WeWereSpacing.xxl)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startAnimations()
            prefetchAlbum()
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Polaroid slide up
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            polaroidOffset = 0
        }

        // Photo blur reveal over the full duration
        withAnimation(.easeOut(duration: 7.0)) {
            photoBlur = 0
        }

        // Pulsing "DEVELOPING..." text
        withAnimation(
            .easeInOut(duration: 1.0)
            .repeatForever(autoreverses: true)
        ) {
            developingOpacity = 1.0
        }

        // Auto-navigate after 8 seconds: clear stack and go straight to album
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            guard !hasNavigated else { return }
            hasNavigated = true
            // Pop back to root, then push album so back goes to Home
            appState.navigationPath = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appState.navigationPath.append(Route.album(eventId))
            }
        }
    }

    // MARK: - Prefetching

    /// Warm the album cache during the developing animation so photos appear instantly.
    private func prefetchAlbum() {
        Task.detached(priority: .userInitiated) {
            let photoService = await PhotoService()
            do {
                let photoResponses = try await photoService.fetchPhotos(eventId: eventId)
                let photos = photoResponses.map { $0.toPhoto }

                // Build the URL map
                var urls: [UUID: URL] = [:]
                for pr in photoResponses {
                    if let signedUrlString = pr.signedUrl,
                       let url = URL(string: signedUrlString) {
                        urls[pr.id] = url
                    } else {
                        let photo = pr.toPhoto
                        if let url = await photoService.getFilteredPhotoURL(photo: photo) {
                            urls[photo.id] = url
                        }
                    }
                }

                // Populate AlbumViewModel static cache so the album renders instantly
                await MainActor.run {
                    AlbumViewModel.cachedPhotos[eventId] = photos
                    AlbumViewModel.cachedURLs[eventId] = urls
                }

                // Warm URLSession's disk cache by fetching the image bytes.
                // This makes AsyncImage hit the cache instead of going to the network.
                await withTaskGroup(of: Void.self) { group in
                    for url in urls.values {
                        group.addTask {
                            _ = try? await URLSession.shared.data(from: url)
                        }
                    }
                }
            } catch {
                print("Prefetch failed: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: Date())
    }
}

#Preview {
    NavigationStack {
        DevelopingAnimationView(eventId: UUID())
            .environmentObject(AppState())
    }
}
