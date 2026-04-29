import SwiftUI

struct WeWereHeader: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            Text("WEWERE")
                .font(.custom(WeWereFontFamily.clashDisplaySemibold, size: 18))
                .tracking(4)
                .foregroundStyle(.white)

            HStack {
                if appState.canGoBack {
                    Button {
                        appState.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                Button {
                    // Notifications action
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(WeWereColors.onSurfaceVariant)
                }
            }
        }
        .padding(.horizontal, WeWereSpacing.md)
        .padding(.vertical, WeWereSpacing.xs)
        .background(Color(hex: "#131313").opacity(0.85))
        .background(.ultraThinMaterial.opacity(0.5))
    }
}
