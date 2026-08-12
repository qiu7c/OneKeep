import SwiftUI
import UIKit

enum OKColor {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 15 / 255, green: 15 / 255, blue: 16 / 255, alpha: 1)
            : UIColor(red: 245 / 255, green: 245 / 255, blue: 243 / 255, alpha: 1)
    })

    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
            : .white
    })

    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 209 / 255, green: 209 / 255, blue: 214 / 255, alpha: 1)
            : UIColor(red: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1)
    })

    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 161 / 255, green: 161 / 255, blue: 166 / 255, alpha: 1)
            : UIColor(red: 110 / 255, green: 110 / 255, blue: 115 / 255, alpha: 1)
    })

    static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 56 / 255, green: 56 / 255, blue: 58 / 255, alpha: 1)
            : UIColor(red: 216 / 255, green: 216 / 255, blue: 220 / 255, alpha: 1)
    })
}

struct OKCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(OKColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(OKColor.border, lineWidth: 0.5)
            }
    }
}

extension View {
    func okCard() -> some View {
        modifier(OKCardModifier())
    }
}

struct OKPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(OKColor.background)
            .background(OKColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
