import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService

    @State private var eventsAttended: Int = 0
    @State private var photosTaken: Int = 0
    @State private var isEditingName = false
    @State private var editedFirstName = ""
    @State private var editedLastName = ""
    @State private var editedInstagram = ""
    @State private var showSignOutConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 48)

            // Header
            Text("PROFILE")
                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 24))
                .foregroundStyle(.white)
                .tracking(2)
                .padding(.bottom, 32)

            // Avatar placeholder
            Circle()
                .fill(WeWereColors.secondaryContainer)
                .frame(width: 80, height: 80)
                .overlay {
                    Text(String((authService.currentUser?.firstName ?? "?").prefix(1)).uppercased())
                        .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 32))
                        .foregroundStyle(.white)
                }
                .padding(.bottom, 16)

            // Display name with edit
            if isEditingName {
                VStack(spacing: WeWereSpacing.xs) {
                    HStack(spacing: WeWereSpacing.xs) {
                        TextField("First", text: $editedFirstName)
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color(hex: "191919"))
                            .cornerRadius(8)

                        TextField("Last", text: $editedLastName)
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 16))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(Color(hex: "191919"))
                            .cornerRadius(8)
                    }

                    HStack(spacing: 0) {
                        Text("@")
                            .font(.custom(WeWereFontFamily.jakartaRegular, size: 16))
                            .foregroundStyle(WeWereColors.onSurfaceVariant)
                            .padding(.leading, 12)

                        TextField("instagram", text: $editedInstagram)
                            .font(.custom(WeWereFontFamily.jakartaRegular, size: 16))
                            .foregroundStyle(.white)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 4)
                    }
                    .frame(height: 44)
                    .background(Color(hex: "191919"))
                    .cornerRadius(8)

                    HStack(spacing: 12) {
                        Button {
                            saveProfile()
                        } label: {
                            Text("Save")
                                .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                                .foregroundStyle(WeWereColors.onPrimary)
                                .padding(.horizontal, WeWereSpacing.lg)
                                .padding(.vertical, WeWereSpacing.xs)
                                .background(
                                    LinearGradient(
                                        colors: [.white, Color(hex: "d4d4d4")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
                        }

                        Button {
                            isEditingName = false
                        } label: {
                            Text("Cancel")
                                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                                .foregroundStyle(WeWereColors.outline)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            } else {
                HStack(spacing: 8) {
                    Text(authService.currentUser?.displayName ?? "Guest")
                        .font(.custom(WeWereFontFamily.jakartaBold, size: 20))
                        .foregroundStyle(.white)

                    Button {
                        editedFirstName = authService.currentUser?.firstName ?? ""
                        editedLastName = authService.currentUser?.lastName ?? ""
                        editedInstagram = authService.currentUser?.instagramHandle ?? ""
                        isEditingName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundStyle(WeWereColors.outline)
                    }
                }
                .padding(.bottom, 4)

                // Instagram handle
                if let ig = authService.currentUser?.instagramHandle, !ig.isEmpty {
                    Text("@\(ig)")
                        .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                        .foregroundStyle(WeWereColors.onSurfaceVariant)
                        .padding(.bottom, 4)
                }

                // Phone number
                if let phone = authService.currentUser?.phoneNumber {
                    Text(phone)
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 13))
                        .foregroundStyle(WeWereColors.outline)
                }

                Spacer().frame(height: 24)
            }

            // Stats row
            HStack(spacing: 40) {
                VStack(spacing: 4) {
                    Text("\(eventsAttended)")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 20))
                        .foregroundStyle(.white)

                    Text("EVENTS")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                        .tracking(1)
                        .foregroundStyle(WeWereColors.outline)
                }

                Rectangle()
                    .fill(WeWereColors.outlineVariant.opacity(0.3))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("\(photosTaken)")
                        .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 20))
                        .foregroundStyle(.white)

                    Text("PHOTOS")
                        .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                        .tracking(1)
                        .foregroundStyle(WeWereColors.outline)
                }
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 40)
            .background(WeWereColors.surfaceContainerHigh)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            // Sign out button
            Button {
                showSignOutConfirm = true
            } label: {
                Text("SIGN OUT")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 13))
                    .tracking(1)
                    .foregroundStyle(WeWereColors.error)
                    .padding(.horizontal, WeWereSpacing.lg)
                    .padding(.vertical, WeWereSpacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: WeWereRadius.xl)
                            .stroke(WeWereColors.error.opacity(0.4), lineWidth: 1)
                    )
            }
            .padding(.bottom, WeWereSpacing.lg)

            // App info
            VStack(spacing: 4) {
                Text("WEWERE")
                    .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 12))
                    .tracking(3)
                    .foregroundStyle(WeWereColors.outlineVariant)

                Text("v1.0.0")
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                    .foregroundStyle(WeWereColors.outlineVariant.opacity(0.6))
            }
            .padding(.bottom, 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WeWereColors.surface.ignoresSafeArea())
        .alert("Sign Out", isPresented: $showSignOutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                Task {
                    try? await authService.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            await loadStats()
        }
    }

    private func saveProfile() {
        Task {
            let ig = editedInstagram.trimmingCharacters(in: .whitespaces)
            try? await authService.updateProfile(
                firstName: editedFirstName.trimmingCharacters(in: .whitespaces),
                lastName: editedLastName.trimmingCharacters(in: .whitespaces),
                instagramHandle: ig.isEmpty ? nil : ig
            )
            isEditingName = false
        }
    }

    private func loadStats() async {
        guard let user = authService.currentUser else { return }
        let client = SupabaseManager.shared.client

        struct IdOnly: Decodable { let id: UUID }

        do {
            let memberships: [IdOnly] = try await client
                .from("event_members")
                .select("id")
                .eq("user_id", value: user.id.uuidString)
                .execute()
                .value
            eventsAttended = memberships.count
        } catch {}

        do {
            let photos: [IdOnly] = try await client
                .from("photos")
                .select("id")
                .eq("user_id", value: user.id.uuidString)
                .execute()
                .value
            photosTaken = photos.count
        } catch {}
    }
}
