import SwiftUI

struct CreateEventView: View {
    @StateObject private var viewModel = CreateEventViewModel()
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    private let hours = Array(0...23)
    private let minutes = [0, 30]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("CREATE EVENT")
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 24))
                        .foregroundStyle(.white)
                        .tracking(2)
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

                    Spacer(minLength: 32)

                    // Create button
                    Button {
                        Task {
                            do {
                                let event = try await viewModel.createEvent()
                                NotificationCenter.default.post(name: .eventCreated, object: nil)
                                dismiss()
                                // Navigate to the new event detail after sheet dismisses
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    appState.navigationPath.append(Route.eventDetail(event.id))
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
