import SwiftUI

struct DevelopFilmView: View {
    let eventId: UUID

    @StateObject private var viewModel: DevelopFilmViewModel
    @EnvironmentObject var appState: AppState

    init(eventId: UUID) {
        self.eventId = eventId
        _viewModel = StateObject(wrappedValue: DevelopFilmViewModel(eventId: eventId))
    }

    var body: some View {
        ZStack {
            // Background with darkroom glow
            WeWereColors.surface
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // MARK: - Wordmark
                    Text("WEWERE")
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 16))
                        .tracking(3)
                        .foregroundStyle(WeWereColors.onSurface)
                        .padding(.top, WeWereSpacing.lg)

                    // MARK: - Archive label
                    Text("ARCHIVE SERIES // 004")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                        .tracking(2)
                        .foregroundStyle(WeWereColors.outline)
                        .padding(.top, WeWereSpacing.xl)

                    // MARK: - Headline
                    Text("THE EVENT IS OVER")
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 32))
                        .tracking(3)
                        .foregroundStyle(.white)
                        .padding(.top, WeWereSpacing.sm)

                    // MARK: - Exposure count
                    Text("\(viewModel.photoCount) EXPOSURES READY")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 12))
                        .tracking(2)
                        .foregroundStyle(WeWereColors.onSurfaceVariant)
                        .padding(.top, WeWereSpacing.xs)

                    // MARK: - Film strip icon area
                    ZStack {
                        RoundedRectangle(cornerRadius: WeWereRadius.lg)
                            .fill(WeWereColors.surfaceContainerHigh)
                            .frame(width: 200, height: 160)

                        Image(systemName: "film.stack")
                            .font(.system(size: 48))
                            .foregroundStyle(WeWereColors.outline)
                    }
                    .padding(.top, WeWereSpacing.xl)

                    // MARK: - REC indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)

                        Text("REC")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                            .foregroundStyle(.red)
                    }
                    .padding(.top, WeWereSpacing.md)

                    // MARK: - Develop button
                    Button {
                        Task {
                            try? await viewModel.developFilm()
                            NotificationCenter.default.post(name: .eventUpdated, object: nil)
                            appState.navigationPath.append(Route.developingAnimation(eventId))
                        }
                    } label: {
                        Text("DEVELOP FILM")
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                            .foregroundStyle(Color(hex: "1a1c1c"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [.white, Color(hex: "d4d4d4")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
                    }
                    .disabled(viewModel.isDeveloping)
                    .opacity(viewModel.isDeveloping ? 0.6 : 1.0)
                    .padding(.horizontal, WeWereSpacing.lg)
                    .padding(.top, WeWereSpacing.xl)

                    // MARK: - Chemical process note
                    Text("CHEMICAL PROCESS WILL TAKE APPROXIMATELY 24 HOURS.")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                        .foregroundStyle(WeWereColors.outline)
                        .multilineTextAlignment(.center)
                        .padding(.top, WeWereSpacing.sm)

                    // MARK: - Footer metadata
                    HStack(alignment: .top, spacing: WeWereSpacing.md) {
                        // Location column
                        HStack(spacing: WeWereSpacing.xs) {
                            Rectangle()
                                .fill(Color(hex: "D4A853"))
                                .frame(width: 2)

                            VStack(alignment: .leading, spacing: WeWereSpacing.xxs) {
                                Text("LOCATION")
                                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                                    .foregroundStyle(WeWereColors.outline)
                                    .tracking(1.5)

                                Text(viewModel.event?.location ?? "Unknown")
                                    .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                                    .foregroundStyle(.white)
                            }
                        }

                        Spacer()

                        // Peak time column
                        HStack(spacing: WeWereSpacing.xs) {
                            Rectangle()
                                .fill(Color(hex: "D4A853"))
                                .frame(width: 2)

                            VStack(alignment: .leading, spacing: WeWereSpacing.xxs) {
                                Text("PEAK TIME")
                                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                                    .foregroundStyle(WeWereColors.outline)
                                    .tracking(1.5)

                                Text(formattedPeakTime)
                                    .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(WeWereSpacing.md)
                    .background(WeWereColors.surfaceContainerLowest)
                    .padding(.top, WeWereSpacing.lg)
                    .padding(.bottom, WeWereSpacing.xxl)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WeWereColors.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(.white)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Helpers

    private var formattedPeakTime: String {
        guard let peakTime = viewModel.peakTime else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, hh:mm a"
        return formatter.string(from: peakTime).uppercased()
    }
}

#Preview {
    NavigationStack {
        DevelopFilmView(eventId: UUID())
            .environmentObject(AppState())
    }
}
