import SwiftUI

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Color Tokens

enum WeWereColors {
    // Surface
    static let surface = Color(hex: "131313")
    static let surfaceBright = Color(hex: "393939")
    static let surfaceContainer = Color(hex: "1e1e1e")
    static let surfaceContainerLow = Color(hex: "191919")
    static let surfaceContainerHigh = Color(hex: "282828")
    static let surfaceContainerHighest = Color(hex: "353535")
    static let surfaceContainerLowest = Color(hex: "0e0e0e")

    // On-Surface
    static let onSurface = Color(hex: "e2e2e2")
    static let onSurfaceVariant = Color(hex: "c7c6c6")

    // Primary
    static let primary = Color.white
    static let onPrimary = Color(hex: "1a1c1c")

    // Secondary
    static let secondary = Color(hex: "c7c6c6")
    static let secondaryContainer = Color(hex: "464747")

    // Tertiary
    static let tertiary = Color(hex: "e2e2e2")
    static let tertiaryContainer = Color(hex: "909191")

    // Outline
    static let outline = Color(hex: "919191")
    static let outlineVariant = Color(hex: "474747")

    // Error
    static let error = Color(hex: "ffb4ab")
    static let errorContainer = Color(hex: "93000a")
}

// MARK: - Font Families

enum WeWereFontFamily {
    static let clashDisplaySemibold = "ClashDisplay-Semibold"

    static let jakartaRegular = "PlusJakartaSans-Regular"
    static let jakartaBold = "PlusJakartaSans-Bold"

    static let spaceGroteskRegular = "SpaceGrotesk-Regular"
    static let spaceGroteskMedium = "SpaceGrotesk-Medium"
}

// MARK: - Type Scale

enum WeWereTypeScale {
    case displayLg
    case headlineMd
    case titleLg
    case titleSm
    case bodyLg
    case bodyMd
    case labelLg
    case labelMd
    case labelSm

    var size: CGFloat {
        switch self {
        case .displayLg:  return 36
        case .headlineMd: return 24
        case .titleLg:    return 20
        case .titleSm:    return 14
        case .bodyLg:     return 16
        case .bodyMd:     return 14
        case .labelLg:    return 14
        case .labelMd:    return 12
        case .labelSm:    return 10
        }
    }

    var fontName: String {
        switch self {
        case .displayLg:
            return WeWereFontFamily.clashDisplaySemibold
        case .headlineMd:
            return WeWereFontFamily.jakartaBold
        case .titleLg:
            return WeWereFontFamily.jakartaBold
        case .titleSm:
            return WeWereFontFamily.jakartaRegular
        case .bodyLg:
            return WeWereFontFamily.jakartaRegular
        case .bodyMd:
            return WeWereFontFamily.jakartaRegular
        case .labelLg:
            return WeWereFontFamily.spaceGroteskMedium
        case .labelMd:
            return WeWereFontFamily.spaceGroteskRegular
        case .labelSm:
            return WeWereFontFamily.spaceGroteskRegular
        }
    }

    var font: Font {
        .custom(fontName, size: size)
    }
}

// MARK: - View Extension for Type Scale

extension View {
    func weWereFont(_ scale: WeWereTypeScale) -> some View {
        self.font(scale.font)
    }
}

// MARK: - Corner Radius

enum WeWereRadius {
    static let sm: CGFloat = 2
    static let md: CGFloat = 4
    static let lg: CGFloat = 8
    static let xl: CGFloat = 12
    static let full: CGFloat = 9999
}

// MARK: - Spacing Scale

enum WeWereSpacing {
    static let xxxs: CGFloat = 2
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
}
