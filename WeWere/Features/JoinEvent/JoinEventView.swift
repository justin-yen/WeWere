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
                // Header bar
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundStyle(WeWereColors.onSurface)

                    Spacer()

                    Text("WEWERE")
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 18))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "bell")
                        .font(.system(size: 20))
                        .foregroundStyle(WeWereColors.onSurface)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                // Invitation label
                Text("INVITATION NO. 882-01 | 2024 ED.")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                    .foregroundStyle(WeWereColors.outline)
                    .tracking(2)
                    .padding(.bottom, 20)

                // Event banner placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(WeWereColors.surfaceContainerHigh)
                    .frame(height: 180)
                    .overlay {
                        if let event = viewModel.event,
                           let coverUrl = event.coverImageUrl,
                           let url = URL(string: coverUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                EmptyView()
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                // Event name
                if let event = viewModel.event {
                    Text(event.name)
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 24))
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)

                    // Location / time
                    Text(event.startTime, style: .date)
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                        .foregroundStyle(WeWereColors.outline)
                        + Text(" at ")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                        .foregroundStyle(WeWereColors.outline)
                        + Text(event.startTime, style: .time)
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                        .foregroundStyle(WeWereColors.outline)
                } else if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.vertical, 20)
                }

                // Divider
                RadialGradient(
                    colors: [WeWereColors.outlineVariant, Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)

                // Identity section
                VStack(alignment: .leading, spacing: 12) {
                    Text("IDENTITY")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                        .foregroundStyle(WeWereColors.outline)
                        .tracking(2)

                    TextField("", text: $viewModel.displayName, prompt:
                        Text("ENTER YOUR NAME")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                            .foregroundStyle(WeWereColors.outlineVariant)
                    )
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color(hex: "191919"))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                // Join button
                Button {
                    Task {
                        do {
                            try await viewModel.joinEvent()
                            dismiss()
                        } catch {
                            viewModel.error = error.localizedDescription
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("JOIN EVENT")
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 14))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
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
                .disabled(viewModel.isJoining || viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Terms text
                Text("By joining, you agree to share photos taken during this event with all attendees.")
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 9))
                    .foregroundStyle(WeWereColors.outlineVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)

                // Footer
                if let event = viewModel.event {
                    HStack {
                        Text(event.startTime, style: .date)
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                            .foregroundStyle(WeWereColors.outline)

                        Spacer()

                        Text(event.status == .live ? "LIVE" : "ENDED")
                            .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                            .foregroundStyle(WeWereColors.outline)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
        }
        .background(WeWereColors.surface.ignoresSafeArea())
        .task {
            await viewModel.loadEvent()
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}
