import SwiftUI

enum ReadingTheme {
    static let appBackground = Color(red: 0.955, green: 0.950, blue: 0.935)
    static let sidebarBackground = Color(red: 0.925, green: 0.923, blue: 0.905)
    static let paper = Color(red: 0.995, green: 0.992, blue: 0.980)
    static let inspector = Color(red: 0.972, green: 0.968, blue: 0.953)
    static let ink = Color(red: 0.105, green: 0.120, blue: 0.125)
    static let secondaryInk = Color(red: 0.340, green: 0.355, blue: 0.350)
    static let mutedInk = Color(red: 0.490, green: 0.500, blue: 0.485)
    static let accent = Color(red: 0.105, green: 0.325, blue: 0.305)
    static let accentSoft = Color(red: 0.865, green: 0.910, blue: 0.890)
    static let divider = Color.black.opacity(0.09)
    static let note = Color(red: 0.955, green: 0.925, blue: 0.810)
    static let danger = Color(red: 0.615, green: 0.220, blue: 0.180)

    static let serif = Font.system(size: 16, weight: .regular, design: .serif)
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ReadingTheme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(ReadingTheme.divider, lineWidth: 1)
            }
    }
}

extension View {
    func readingCard(padding: CGFloat = 16) -> some View {
        modifier(CardStyle(padding: padding))
    }
}
