import SwiftUI

enum AuthStep {
    case phoneEntry
    case otpVerify
    case profileSetup
}

struct AuthFlowView: View {
    @EnvironmentObject var authService: AuthService

    @State private var step: AuthStep = .phoneEntry
    @State private var phoneNumber = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            WeWereColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Branding
                Text("WEWERE")
                    .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 24))
                    .tracking(4)
                    .foregroundStyle(WeWereColors.onSurface)
                    .padding(.top, 80)
                    .padding(.bottom, 48)

                switch step {
                case .phoneEntry:
                    PhoneEntryView(
                        phoneNumber: $phoneNumber,
                        errorMessage: $errorMessage,
                        onContinue: {
                            step = .otpVerify
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))

                case .otpVerify:
                    OTPVerifyView(
                        phoneNumber: $phoneNumber,
                        errorMessage: $errorMessage,
                        onVerified: {
                            if authService.needsProfile {
                                step = .profileSetup
                            }
                            // If not needsProfile, authService.isAuthenticated is true
                            // and WeWereApp will show RootView automatically
                        },
                        onBack: {
                            step = .phoneEntry
                        }
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))

                case .profileSetup:
                    ProfileSetupView(
                        phoneNumber: phoneNumber,
                        errorMessage: $errorMessage
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
    }
}
