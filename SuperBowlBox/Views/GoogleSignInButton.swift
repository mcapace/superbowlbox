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

// MARK: - Google Sign-In button (official branding: Light theme #FFF, stroke #747775, G logo, same size as Apple)
// Guidelines: https://developers.google.com/identity/branding-guidelines — same prominence as other sign-in buttons

struct GoogleSignInButton: View {
    var action: () -> Void
    var isDisabled: Bool = false
    /// Match Sign in with Apple: 52pt height, 12pt corner radius when true (onboarding/sign-in screens).
    var useLargeSize: Bool = true

    private var buttonHeight: CGFloat { useLargeSize ? 52 : 40 }
    private var cornerRadius: CGFloat { useLargeSize ? 12 : 4 }
    private var logoSize: CGFloat { useLargeSize ? 24 : 20 }
    private var fontSize: CGFloat { useLargeSize ? 17 : 14 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                OfficialGoogleLogoView(size: logoSize)
                Text("Sign in with Google")
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundColor(isDisabled ? _gsiText.opacity(0.38) : _gsiText)
            }
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(isDisabled ? _gsiDisabledBg : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(isDisabled ? _gsiDisabledBorder : _gsiBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 1, y: 1)
            .shadow(color: Color.black.opacity(0.04), radius: 3, y: 1)
            .cornerRadius(cornerRadius)
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
                RoundedRectangle(cornerRadius: 12)
                    .fill(_gsiPressedOverlay)
                    .opacity(configuration.isPressed && !isDisabled ? 1 : 0)
            )
            .animation(.easeInOut(duration: 0.218), value: configuration.isPressed)
    }
}

// MARK: - Official Google "G" logo (standard four-color; use asset from branding guidelines)
// Add "GoogleLogo" image to Assets from https://developers.google.com/static/identity/images/g-logo.png (or signin-assets.zip)
private struct OfficialGoogleLogoView: View {
    let size: CGFloat

    var body: some View {
        if let img = UIImage(named: "GoogleLogo") {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Fallback: four-color G per brand (blue, red, yellow, green quadrants)
            ZStack {
                GoogleLogoSegment(color: _googleBlue, start: 270, end: 360)
                GoogleLogoSegment(color: _googleGreen, start: 0, end: 90)
                GoogleLogoSegment(color: _googleYellow, start: 180, end: 270)
                GoogleLogoSegment(color: _googleRed, start: 90, end: 180)
            }
            .frame(width: size, height: size)
        }
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
