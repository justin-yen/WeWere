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
        ZStack(alignment: .bottom) {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: WeWereSpacing.lg) {
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
            // FAB: Create Event
            ChromeCreateButton {
                appState.presentedSheet = .createEvent
            }
            .padding(.bottom, 110)
        }
        .background(Color(hex: "#131313").ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Chrome Create Button

struct ChromeCreateButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.0) / 3.0

                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                    Text("Create Event")
                        .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                }
                .foregroundStyle(Color(hex: "1a1c1c"))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        // Chrome base
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "e8e8e8"),
                                        Color(hex: "c0c0c0"),
                                        Color(hex: "d8d8d8"),
                                        Color(hex: "a8a8a8"),
                                        Color(hex: "d0d0d0"),
                                        Color(hex: "e0e0e0"),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        // Animated wavy shine — diagonal sweep
                        ChromeShineCanvas(phase: phase)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .allowsHitTesting(false)

                        // Top specular highlight
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .padding(.horizontal, 1)
                            .padding(.top, 1)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .white.opacity(0.12), radius: 4, y: -1)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
            }
        }
    }
}

// MARK: - Chrome Shine Canvas

private struct ChromeShineCanvas: View {
    let phase: Double

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 3
            let w = size.width
            let h = size.height
            let twoPi = Double.pi * 2.0
            let phaseShift = phase * 2.0

            var y: CGFloat = 0
            while y <= h {
                let ny = Double(y / h)
                var x: CGFloat = 0
                while x <= w {
                    let nx = Double(x / w)
                    let diagonal = (nx + ny) * 3.0 - phaseShift
                    let wave = sin(diagonal * twoPi)
                    let ripple = sin((nx * 5.0 + ny * 2.0 - phase * 3.0) * Double.pi)
                    let combined = wave * 0.6 + ripple * 0.4
                    let alpha = max(0.0, combined) * 0.3
                    if alpha > 0.01 {
                        let rect = CGRect(x: x, y: y, width: step, height: step)
                        context.fill(Path(rect), with: .color(.white.opacity(alpha)))
                    }
                    x += step
                }
                y += step
            }
        }
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
