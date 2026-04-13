import SwiftUI

enum WeWereTab: Int, CaseIterable {
    case home = 0
    case events = 1
    case profile = 2

    var title: String {
        switch self {
        case .home:    return "Home"
        case .events:  return "Events"
        case .profile: return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "house.fill"
        case .events:  return "film.stack"
        case .profile: return "person.fill"
        }
    }
}

struct WeWereTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack {
            ForEach(WeWereTab.allCases, id: \.rawValue) { tab in
                Spacer()
                tabItem(tab)
                Spacer()
            }
        }
        .padding(.top, WeWereSpacing.sm)
        .padding(.bottom, WeWereSpacing.lg)
        .background(WeWereColors.surfaceContainerLowest.opacity(0.85))
        .background(.ultraThinMaterial.opacity(0.5))
    }

    @ViewBuilder
    private func tabItem(_ tab: WeWereTab) -> some View {
        let isSelected = selectedTab == tab.rawValue

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab.rawValue
            }
        } label: {
            VStack(spacing: WeWereSpacing.xxs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                Text(tab.title)
                    .font(.custom(WeWereFontFamily.spaceGroteskMedium, size: 10))
            }
            .foregroundStyle(isSelected ? WeWereColors.primary : WeWereColors.outline)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }
}

#Preview {
    ZStack {
        WeWereColors.surface
            .ignoresSafeArea()

        VStack {
            Spacer()
            WeWereTabBar(selectedTab: .constant(0))
        }
    }
}
