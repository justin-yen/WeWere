import SwiftUI

struct PhoneEntryView: View {
    @EnvironmentObject var authService: AuthService

    @Binding var phoneNumber: String
    @Binding var errorMessage: String?

    let onContinue: () -> Void

    @State private var isLoading = false

    private var formattedPhone: String {
        "+1\(phoneNumber)"
    }

    private var isValid: Bool {
        phoneNumber.count >= 10
    }

    var body: some View {
        VStack(spacing: WeWereSpacing.lg) {
            Text("Enter your phone number to get started")
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                .foregroundStyle(WeWereColors.outline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, WeWereSpacing.xl)

            // Phone number field
            HStack(spacing: 0) {
                Text("+1")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 16))
                    .foregroundStyle(WeWereColors.onSurfaceVariant)
                    .padding(.leading, WeWereSpacing.md)

                TextField("(555) 123-4567", text: $phoneNumber)
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 16))
                    .foregroundStyle(WeWereColors.onSurface)
                    .keyboardType(.numberPad)
                    .padding(.horizontal, WeWereSpacing.xs)
                    .padding(.vertical, WeWereSpacing.sm)
            }
            .frame(height: 48)
            .background(Color(hex: "191919"))
            .cornerRadius(WeWereRadius.lg)
            .padding(.horizontal, WeWereSpacing.lg)

            if let error = errorMessage {
                Text(error)
                    .font(.custom(WeWereFontFamily.jakartaRegular, size: 12))
                    .foregroundStyle(WeWereColors.error)
                    .padding(.horizontal, WeWereSpacing.lg)
            }

            // Continue button
            Button {
                sendOTP()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(WeWereColors.onPrimary)
                    } else {
                        Text("CONTINUE")
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

            Spacer()

            #if DEBUG
            // Test login buttons (simulator / debug builds only)
            VStack(spacing: WeWereSpacing.xs) {
                Text("DEV TEST ACCOUNTS")
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
                    .foregroundStyle(WeWereColors.outlineVariant)
                    .tracking(1)

                HStack(spacing: WeWereSpacing.xs) {
                    ForEach(["test1", "test2", "test3"], id: \.self) { testId in
                        Button {
                            testLogin(testId: testId)
                        } label: {
                            Text(testId.uppercased())
                                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 11))
                                .foregroundStyle(WeWereColors.onSurface)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(WeWereColors.surfaceContainerHigh)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(isLoading)
                    }
                }
            }
            .padding(.bottom, WeWereSpacing.md)
            #endif

            Text("By continuing, you agree to our Terms")
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 11))
                .foregroundStyle(WeWereColors.outlineVariant)
                .padding(.bottom, WeWereSpacing.xl)
        }
    }

    #if DEBUG
    private func testLogin(testId: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.testLogin(testId: testId)
            } catch {
                errorMessage = "Test login failed: \(error.localizedDescription)"
                print("Test login error: \(error)")
            }
            isLoading = false
        }
    }
    #endif

    private func sendOTP() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.sendOTP(phoneNumber: formattedPhone)
                onContinue()
            } catch {
                errorMessage = "Failed to send code. Please try again."
                print("OTP send error: \(error)")
            }
            isLoading = false
        }
    }
}
