import SwiftUI

// Google brand colors for the "G" icon (#EA4335, #4285F4, #FBBC05, #34A853)
private let _googleRed = Color(red: 234/255, green: 67/255, blue: 53/255)
private let _googleBlue = Color(red: 66/255, green: 133/255, blue: 244/255)
private let _googleYellow = Color(red: 251/255, green: 188/255, blue: 5/255)
private let _googleGreen = Color(red: 52/255, green: 168/255, blue: 83/255)

// gsi-material-button colors from Google's official CSS
private let _gsiBorder = Color(red: 116/255, green: 119/255, blue: 117/255)       // #747775
private let _gsiText = Color(red: 31/255, green: 31/255, blue: 31/255)          // #1f1f1f
private let _gsiDisabledBg = Color.white.opacity(0.38)                          // #ffffff61
private let _gsiDisabledBorder = Color(red: 31/255, green: 31/255, blue: 31/255).opacity(0.12)  // #1f1f1f1f
private let _gsiPressedOverlay = Color(red: 48/255, green: 48/255, blue: 48/255).opacity(0.12)   // #303030 12%

// MARK: - Google Sign-In button (official gsi-material-button style)
// Matches Google's web CSS: white bg, 1px #747775 border, 4px radius, 40px height, 14pt font, "Sign in with Google"

struct GoogleSignInButton: View {
    var action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                GoogleLogoView(size: 20)
                Text("Sign in with Google")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDisabled ? _gsiText.opacity(0.38) : _gsiText)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isDisabled ? _gsiDisabledBg : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isDisabled ? _gsiDisabledBorder : _gsiBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 1, y: 1)
            .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
            .cornerRadius(4)
        }
        .buttonStyle(GsiMaterialButtonStyle(isDisabled: isDisabled))
        .disabled(isDisabled)
    }
}

private struct GsiMaterialButtonStyle: ButtonStyle {
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .fill(_gsiPressedOverlay)
                    .opacity(configuration.isPressed && !isDisabled ? 1 : 0)
            )
            .animation(.easeInOut(duration: 0.218), value: configuration.isPressed)
    }
}

// MARK: - Google "G" logo (four brand colors, SVG-style quadrants)
private struct GoogleLogoView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Google G quadrants: red top-left, green top-right, yellow bottom-left, blue bottom-right
            GoogleLogoSegment(color: _googleRed, start: 90, end: 180)
            GoogleLogoSegment(color: _googleGreen, start: 0, end: 90)
            GoogleLogoSegment(color: _googleYellow, start: 180, end: 270)
            GoogleLogoSegment(color: _googleBlue, start: 270, end: 360)
        }
        .frame(width: size, height: size)
    }
}

private struct GoogleLogoSegment: View {
    let color: Color
    let start: Double
    let end: Double

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            Path { p in
                p.move(to: center)
                p.addArc(center: center, radius: r, startAngle: .degrees(start), endAngle: .degrees(end), clockwise: false)
                p.closeSubpath()
            }
            .fill(color)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        GoogleSignInButton(action: {})
        GoogleSignInButton(action: {}, isDisabled: true)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
