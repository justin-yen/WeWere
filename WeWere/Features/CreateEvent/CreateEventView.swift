import SwiftUI

struct CreateEventView: View {
    @StateObject private var viewModel = CreateEventViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var showCoverPhotoPicker = false

    private let hours = Array(0...23)
    private let minutes = [0, 30]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title + test button
                    HStack {
                        Text("CREATE EVENT")
                            .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 24))
                            .foregroundStyle(.white)
                            .tracking(2)

                        Spacer()

                        #if DEBUG
                        Button {
                            viewModel.fillTestEventData()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "flask.fill")
                                    .font(.system(size: 11))
                                Text("TEST")
                                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                                    .tracking(1.5)
                            }
                            .foregroundStyle(WeWereColors.onSurfaceVariant)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(WeWereColors.outlineVariant, lineWidth: 1)
                            )
                        }
                        .disabled(viewModel.isCreating)
                        #endif
                    }
                    .padding(.top, 16)

                    // Event name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EVENT NAME")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                            .foregroundStyle(WeWereColors.outline)
                            .tracking(2)

                        TextField("", text: $viewModel.name, prompt:
                            Text("Enter event name")
                                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                                .foregroundStyle(WeWereColors.outlineVariant)
                        )
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 48)
                        .background(Color(hex: "191919"))
                        .cornerRadius(8)
                        .onChange(of: viewModel.name) { _, newValue in
                            if newValue.count > 40 {
                                viewModel.name = String(newValue.prefix(40))
                            }
                        }

                        HStack {
                            Spacer()
                            Text("\(viewModel.name.count)/40")
                                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                                .foregroundStyle(viewModel.name.count >= 36 ? WeWereColors.error : WeWereColors.outline)
                        }
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DESCRIPTION")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                            .foregroundStyle(WeWereColors.outline)
                            .tracking(2)

                        TextField("", text: $viewModel.description, prompt:
                            Text("Optional description")
                                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                                .foregroundStyle(WeWereColors.outlineVariant),
                            axis: .vertical
                        )
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                        .foregroundStyle(.white)
                        .lineLimit(3...6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(hex: "191919"))
                        .cornerRadius(8)
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("LOCATION")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                            .foregroundStyle(WeWereColors.outline)
                            .tracking(2)

                        LocationSearchView(
                            locationText: $viewModel.location,
                            onLocationSelected: { name, address, lat, lng in
                                viewModel.setLocation(name: name, address: address, lat: lat, lng: lng)
                            },
                            onCleared: {
                                viewModel.clearLocation()
                            }
                        )
                    }

                    // Start time
                    VStack(alignment: .leading, spacing: 8) {
                        Text("START")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                            .foregroundStyle(WeWereColors.outline)
                            .tracking(2)

                        DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(.white)
                            .colorScheme(.dark)

                        timePickerRow(hour: $viewModel.startHour, minute: $viewModel.startMinute)
                    }

                    // End time (optional)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("END")
                                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                                .foregroundStyle(WeWereColors.outline)
                                .tracking(2)

                            Spacer()

                            Toggle("", isOn: $viewModel.hasEndTime)
                                .labelsHidden()
                                .tint(WeWereColors.secondaryContainer)
                        }

                        if !viewModel.hasEndTime {
                            Text("Event will stay live until you end it manually.")
                                .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 12))
                                .foregroundStyle(WeWereColors.outline)
                        } else {
                            DatePicker("", selection: $viewModel.endDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(.white)
                                .colorScheme(.dark)

                            timePickerRow(hour: $viewModel.endHour, minute: $viewModel.endMinute)
                        }
                    }

                    // Cover photo
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COVER PHOTO")
                            .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                            .foregroundStyle(WeWereColors.outline)
                            .tracking(2)

                        if let url = viewModel.coverPhotoUrl, let imageURL = URL(string: url) {
                            // Selected photo preview
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: imageURL) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(16/9, contentMode: .fill)
                                            .clipped()
                                    case .empty:
                                        Rectangle()
                                            .fill(WeWereColors.surfaceContainerLow)
                                            .aspectRatio(16/9, contentMode: .fit)
                                            .overlay(ProgressView().tint(.white))
                                    default:
                                        Rectangle()
                                            .fill(WeWereColors.surfaceContainerLow)
                                            .aspectRatio(16/9, contentMode: .fit)
                                    }
                                }
                                .cornerRadius(8)

                                // Change / remove buttons
                                HStack(spacing: 8) {
                                    Button {
                                        showCoverPhotoPicker = true
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }

                                    Button {
                                        viewModel.coverPhotoUrl = nil
                                        viewModel.coverPhotoAttribution = nil
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 28, height: 28)
                                            .background(.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(8)
                            }

                            if let attribution = viewModel.coverPhotoAttribution {
                                Text(attribution)
                                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 10))
                                    .foregroundStyle(WeWereColors.outline)
                            }
                        } else {
                            // Add cover photo button
                            Button {
                                showCoverPhotoPicker = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 16))
                                    Text("Add a cover photo")
                                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 14))
                                }
                                .foregroundStyle(WeWereColors.onSurfaceVariant)
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(WeWereColors.surfaceContainerLow)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            WeWereColors.surfaceContainerHigh,
                                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                                        )
                                )
                            }
                            .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).count < 3)
                            .opacity(viewModel.name.trimmingCharacters(in: .whitespaces).count < 3 ? 0.4 : 1.0)
                        }
                    }

                    Spacer(minLength: 32)

                    // Create button
                    Button {
                        Task {
                            do {
                                let event = try await viewModel.createEvent()
                                if viewModel.shouldPopulateTestAttendees {
                                    await viewModel.populateTestAttendees(eventId: event.id)
                                }
                                NotificationCenter.default.post(name: .eventCreated, object: nil)
                                dismiss()
                                // Switch to home tab with animation, then navigate to event detail
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        appState.selectedTab = .home
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        appState.navigationPath.append(Route.eventDetail(event.id))
                                    }
                                }
                            } catch {
                                print("Failed to create event: \(error)")
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("CREATE EVENT")
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
                    .disabled(!viewModel.isValid || viewModel.isCreating)
                    .opacity(viewModel.isValid ? 1.0 : 0.5)
                }
                .padding(.horizontal, 20)
            }
            .background(WeWereColors.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(WeWereColors.onSurface)
                    }
                }
            }
            .toolbarBackground(WeWereColors.surface, for: .navigationBar)
            .sheet(isPresented: $showCoverPhotoPicker) {
                CoverPhotoPickerView(
                    eventName: viewModel.name,
                    eventDescription: viewModel.description,
                    onSelect: { photo in
                        viewModel.coverPhotoUrl = photo.urlRegular
                        viewModel.coverPhotoAttribution = "Photo by \(photo.photographer) on Unsplash"
                    },
                    onSkip: {}
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Time Picker Row

    private func timePickerRow(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            // Hour picker
            Picker("Hour", selection: hour) {
                ForEach(hours, id: \.self) { h in
                    Text(String(format: "%d", h))
                        .tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60, height: 100)
            .clipped()

            Text(":")
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 20))
                .foregroundStyle(.white)

            // Minute picker (only :00 and :30)
            Picker("Minute", selection: minute) {
                ForEach(minutes, id: \.self) { m in
                    Text(String(format: "%02d", m))
                        .tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 60, height: 100)
            .clipped()

            Spacer()

            // Display formatted time
            Text(formattedTime(hour: hour.wrappedValue, minute: minute.wrappedValue))
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 16))
                .foregroundStyle(WeWereColors.onSurface)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "191919"))
        .cornerRadius(8)
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }
}
