import SwiftUI

struct ProfileSetupView: View {
    @EnvironmentObject var authService: AuthService

    let phoneNumber: String
    @Binding var errorMessage: String?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var instagramHandle = ""
    @State private var isLoading = false

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: WeWereSpacing.lg) {
            Text("SET UP YOUR PROFILE")
                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 20))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurface)
                .padding(.bottom, WeWereSpacing.xs)

            // First name
            VStack(alignment: .leading, spacing: WeWereSpacing.xxs) {
                Text("FIRST NAME")
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                    .tracking(1)
                    .foregroundStyle(WeWereColors.outline)

                TextField("First name", text: $firstName)
                    .font(.custom(WeWereFontFamily.jakartaRegular, size: 16))
                    .foregroundStyle(WeWereColors.onSurface)
                    .padding(.horizontal, WeWereSpacing.md)
                    .frame(height: 48)
                    .background(Color(hex: "191919"))
                    .cornerRadius(WeWereRadius.lg)
            }
            .padding(.horizontal, WeWereSpacing.lg)

            // Last name
            VStack(alignment: .leading, spacing: WeWereSpacing.xxs) {
                Text("LAST NAME")
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                    .tracking(1)
                    .foregroundStyle(WeWereColors.outline)

                TextField("Last name", text: $lastName)
                    .font(.custom(WeWereFontFamily.jakartaRegular, size: 16))
                    .foregroundStyle(WeWereColors.onSurface)
                    .padding(.horizontal, WeWereSpacing.md)
                    .frame(height: 48)
                    .background(Color(hex: "191919"))
                    .cornerRadius(WeWereRadius.lg)
            }
            .padding(.horizontal, WeWereSpacing.lg)

            // Instagram handle (optional)
            VStack(alignment: .leading, spacing: WeWereSpacing.xxs) {
                Text("INSTAGRAM (OPTIONAL)")
                    .font(.custom(WeWereFontFamily.spaceGroteskRegular, size: 11))
                    .tracking(1)
                    .foregroundStyle(WeWereColors.outline)

                HStack(spacing: 0) {
                    Text("@")
                        .font(.custom(WeWereFontFamily.jakartaRegular, size: 16))
                        .foregroundStyle(WeWereColors.onSurfaceVariant)
                        .padding(.leading, WeWereSpacing.md)

                    TextField("username", text: $instagramHandle)
                        .font(.custom(WeWereFontFamily.jakartaRegular, size: 16))
                        .foregroundStyle(WeWereColors.onSurface)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal, WeWereSpacing.xxs)
                }
                .frame(height: 48)
                .background(Color(hex: "191919"))
                .cornerRadius(WeWereRadius.lg)
            }
            .padding(.horizontal, WeWereSpacing.lg)

            if let error = errorMessage {
                Text(error)
                    .font(.custom(WeWereFontFamily.jakartaRegular, size: 12))
                    .foregroundStyle(WeWereColors.error)
                    .padding(.horizontal, WeWereSpacing.lg)
            }

            // Submit button
            Button {
                createProfile()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(WeWereColors.onPrimary)
                    } else {
                        Text("LET'S GO")
                            .font(.custom(WeWereFontFamily.jakartaBold, size: 14))
                    }
                }
                .foregroundStyle(WeWereColors.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    LinearGradient(
                        colors: [.white, Color(hex: "d4d4d4")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: WeWereRadius.xl))
            }
            .disabled(!isValid || isLoading)
            .opacity(isValid ? 1.0 : 0.5)
            .padding(.horizontal, WeWereSpacing.lg)
            .padding(.top, WeWereSpacing.xs)
        }
    }

    private func createProfile() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil

        let handle = instagramHandle.trimmingCharacters(in: .whitespaces)
        let igHandle: String? = handle.isEmpty ? nil : handle

        Task {
            do {
                try await authService.createProfile(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    instagramHandle: igHandle,
                    phoneNumber: "+1\(phoneNumber)"
                )
            } catch {
                errorMessage = "Failed to create profile. Please try again."
                print("Profile creation error: \(error)")
            }
            isLoading = false
        }
    }
}
