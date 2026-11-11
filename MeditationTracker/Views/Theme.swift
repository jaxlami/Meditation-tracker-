import SwiftUI
import UIKit

/// The v2 design system: paper & ink, one sage accent, clay for warmth, serif display type.
enum Theme {
    // MARK: Colors (light / dark)

    static let paper = dynamic(light: 0xF5F1EA, dark: 0x161513)
    static let surface = dynamic(light: 0xFBF9F5, dark: 0x1F1E1B)
    static let ink = dynamic(light: 0x1F1D1A, dark: 0xEDE8DF)
    static let inkSecondary = dynamic(light: 0x6E685F, dark: 0x9C958A)
    static let inkTertiary = dynamic(light: 0xA39D93, dark: 0x6A645B)
    static let hairline = dynamic(light: 0xDDD6CA, dark: 0x34312C)
    static let sage = dynamic(light: 0x7D8B6A, dark: 0x9CAA88)
    static let sageSoft = dynamic(light: 0xE3E6DA, dark: 0x2A2E24)
    static let clay = dynamic(light: 0xB5714F, dark: 0xD08D6B)

    static var uiPaper: UIColor { uiDynamic(light: 0xF5F1EA, dark: 0x161513) }
    static var uiInk: UIColor { uiDynamic(light: 0x1F1D1A, dark: 0xEDE8DF) }
    static var uiInkTertiary: UIColor { uiDynamic(light: 0xA39D93, dark: 0x6A645B) }
    static var uiHairline: UIColor { uiDynamic(light: 0xDDD6CA, dark: 0x34312C) }

    // MARK: Type

    static func display(_ size: CGFloat = 34, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func numeral(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight, design: .serif).monospacedDigit()
    }

    static let title = Font.system(.title2, design: .serif)
    static let headline = Font.system(.headline, design: .serif).weight(.regular)
    static let eyebrow = Font.system(size: 11, weight: .semibold)

    // MARK: Helpers

    private static func uiDynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiDynamic(light: light, dark: dark))
    }

    /// Paper-coloured navigation and tab bars with hairline separators, applied once at launch.
    static func applyAppearance() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = uiPaper
        tab.shadowColor = uiHairline
        for layout in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            layout.normal.iconColor = uiInkTertiary
            layout.normal.titleTextAttributes = [.foregroundColor: uiInkTertiary]
            layout.selected.iconColor = uiInk
            layout.selected.titleTextAttributes = [.foregroundColor: uiInk]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // Serif titles via the plain title properties. (A custom UINavigationBarAppearance hides
        // large titles on iOS 26+, so the bar keeps the system's own background.)
        let bar = UINavigationBar.appearance()
        if let serif = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif) {
            bar.largeTitleTextAttributes = [.font: UIFont(descriptor: serif, size: 34), .foregroundColor: uiInk]
        }
        if let serif = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).withDesign(.serif) {
            bar.titleTextAttributes = [.font: UIFont(descriptor: serif, size: 17), .foregroundColor: uiInk]
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Backgrounds

struct PaperBackground: View {
    var body: some View {
        Theme.paper.ignoresSafeArea()
    }
}

extension View {
    /// Paper behind a screen, and hides the default list/form background.
    func paperBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(PaperBackground())
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .serif))
            .tracking(0.3)
            .foregroundStyle(Theme.paper)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Capsule().fill(Theme.ink))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// Small hairline pill used for presets and quick picks.
struct ChipStyle: ButtonStyle {
    var selected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(selected ? Theme.paper : Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selected ? Theme.ink : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1)
            )
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Text styles

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.inkSecondary

    init(_ text: String, color: Color = Theme.inkSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.eyebrow)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}
