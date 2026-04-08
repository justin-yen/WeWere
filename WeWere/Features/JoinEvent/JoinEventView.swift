import SwiftUI

struct JoinEventView: View {
    @StateObject private var viewModel: JoinEventViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    init(shareCode: String) {
        _viewModel = StateObject(wrappedValue: JoinEventViewModel(shareCode: shareCode))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("WEWERE")
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 18))
                        .tracking(4)
                        .foregroundStyle(.white)

                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(WeWereColors.onSurface)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)

                // Invitation label
                Text("YOU'VE BEEN INVITED")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                    .foregroundStyle(WeWereColors.outline)
                    .tracking(2)
                    .padding(.bottom, 24)

                // Event banner placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1a1a2e"), Color(hex: "0f0f0f")],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .frame(height: 180)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                if let event = viewModel.event {
                    // Event name
                    Text(event.name)
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 28))
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)

                    // Location
                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11))
                            Text(location)
                                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 13))
                        }
                        .foregroundStyle(WeWereColors.outline)
                        .padding(.bottom, 4)
                    }

                    // Date/time
                    Text(event.startTime, style: .date)
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                        .foregroundStyle(WeWereColors.outline)

                    // Status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(event.isLive ? .green : WeWereColors.outline)
                            .frame(width: 6, height: 6)
                        Text(event.isLive ? "LIVE NOW" : "ENDED")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                            .tracking(1)
                    }
                    .foregroundStyle(event.isLive ? .green : WeWereColors.outline)
                    .padding(.top, 12)

                } else if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 20)
                } else if viewModel.error != nil {
                    Text("Event not found")
                        .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                        .foregroundStyle(WeWereColors.error)
                }

                Spacer().frame(height: 40)

                // Join button
                if let event = viewModel.event, event.isLive {
                    if viewModel.hasJoined {
                        // Success state
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.green)
                            Text("You're in!")
                                .font(.custom(WeWereFontFamily.jakartaBold, size: 18))
                                .foregroundStyle(.white)
                        }
                        .padding(.bottom, 20)

                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                appState.navigationPath.append(Route.eventDetail(event.id))
                            }
                        } label: {
                            Text("GO TO EVENT")
                                .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                                .foregroundStyle(Color(hex: "1a1c1c"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [.white, Color(hex: "d4d4d4")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        Button {
                            Task { await viewModel.joinEvent() }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isJoining {
                                    ProgressView().tint(Color(hex: "1a1c1c"))
                                } else {
                                    Text("JOIN EVENT")
                                        .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .foregroundStyle(Color(hex: "1a1c1c"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [.white, Color(hex: "d4d4d4")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isJoining)
                        .padding(.horizontal, 20)
                    }
                }

                // Terms
                Text("By joining, you agree to share photos taken during this event with all attendees.")
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 9))
                    .foregroundStyle(WeWereColors.outlineVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 16)
            }
        }
        .background(WeWereColors.surface.ignoresSafeArea())
        .task {
            await viewModel.loadEvent()
        }
    }
}
