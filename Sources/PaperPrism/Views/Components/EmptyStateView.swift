import SwiftUI

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(ReadingTheme.accent)
                .frame(width: 66, height: 66)
                .background(ReadingTheme.accentSoft)
                .clipShape(Circle())

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(ReadingTheme.ink)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(ReadingTheme.secondaryInk)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 340)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(ReadingTheme.accent)
            }
        }
        .padding(32)
    }
}
