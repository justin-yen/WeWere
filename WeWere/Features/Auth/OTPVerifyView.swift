import SwiftUI

struct OTPVerifyView: View {
    @EnvironmentObject var authService: AuthService

    @Binding var phoneNumber: String
    @Binding var errorMessage: String?

    let onVerified: () -> Void
    let onBack: () -> Void

    @State private var code = ""
    @State private var isLoading = false
    @State private var resendCooldown = 0
    @FocusState private var isCodeFocused: Bool

    private var formattedPhone: String {
        "+1\(phoneNumber)"
    }

    var body: some View {
        VStack(spacing: WeWereSpacing.lg) {
            Text("VERIFY")
                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 24))
                .tracking(2)
                .foregroundStyle(WeWereColors.onSurface)

            Text("We sent a code to +1 \(phoneNumber)")
                .font(.custom(WeWereFontFamily.jakartaRegular, size: 14))
                .foregroundStyle(WeWereColors.outline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, WeWereSpacing.xl)

            // OTP code field
            TextField("000000", text: $code)
                .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 32))
                .foregroundStyle(WeWereColors.onSurface)
                .multilineTextAlignment(.center)
                .keyboardType(.numberPad)
                .frame(height: 56)
                .background(Color(hex: "191919"))
                .cornerRadius(WeWereRadius.lg)
                .padding(.horizontal, WeWereSpacing.xxl)
                .focused($isCodeFocused)
                .onChange(of: code) { _, newValue in
                    // Only allow digits, max 6
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(6))
                    if filtered != newValue {
                        code = filtered
                    }
                    // Auto-submit when 6 digits entered
                    if filtered.count == 6 {
                        verifyCode()
                    }
                }

            if let error = errorMessage {
                Text(error)
                    .font(.custom(WeWereFontFamily.jakartaRegular, size: 12))
                    .foregroundStyle(WeWereColors.error)
                    .padding(.horizontal, WeWereSpacing.lg)
            }

            // Verify button
            Button {
                verifyCode()
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(WeWereColors.onPrimary)
                    } else {
                        Text("VERIFY")
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
            .disabled(code.count < 6 || isLoading)
            .opacity(code.count == 6 ? 1.0 : 0.5)
            .padding(.horizontal, WeWereSpacing.lg)

            // Resend / Back
            HStack(spacing: WeWereSpacing.lg) {
                Button {
                    onBack()
                } label: {
                    Text("Change number")
                        .font(.custom(WeWereFontFamily.jakartaRegular, size: 13))
                        .foregroundStyle(WeWereColors.outline)
                }

                if resendCooldown > 0 {
                    Text("Resend in \(resendCooldown)s")
                        .font(.custom(WeWereFontFamily.jakartaRegular, size: 13))
                        .foregroundStyle(WeWereColors.outlineVariant)
                } else {
                    Button {
                        resendOTP()
                    } label: {
                        Text("Resend code")
                            .font(.custom(WeWereFontFamily.jakartaRegular, size: 13))
                            .foregroundStyle(WeWereColors.onSurfaceVariant)
                    }
                }
            }
            .padding(.top, WeWereSpacing.xs)
        }
        .onAppear {
            isCodeFocused = true
            startResendCooldown()
        }
    }

    private func verifyCode() {
        guard code.count == 6, !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.verifyOTP(phoneNumber: formattedPhone, code: code)
                onVerified()
            } catch {
                errorMessage = "Invalid code. Please try again."
                print("OTP verify error: \(error)")
            }
            isLoading = false
        }
    }

    private func resendOTP() {
        errorMessage = nil
        Task {
            do {
                try await authService.sendOTP(phoneNumber: formattedPhone)
                startResendCooldown()
            } catch {
                errorMessage = "Failed to resend code."
            }
        }
    }

    private func startResendCooldown() {
        resendCooldown = 30
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            Task { @MainActor in
                if resendCooldown > 0 {
                    resendCooldown -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}
