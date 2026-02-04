import SwiftUI

// Google brand colors for the "G" icon (#EA4335, #4285F4, #FBBC05, #34A853)
private let _googleRed = Color(red: 234/255, green: 67/255, blue: 53/255)
private let _googleBlue = Color(red: 66/255, green: 133/255, blue: 244/255)
private let _googleYellow = Color(red: 251/255, green: 188/255, blue: 5/255)
private let _googleGreen = Color(red: 52/255, green: 168/255, blue: 83/255)

// MARK: - Google Sign-In button (material style, matches web gsi-material-button)
// Uses official Google brand colors for the "G" icon; label: "Continue with Google"

struct GoogleSignInButton: View {
    var action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GoogleLogoView(size: 24)
                Text("Continue with Google")
                    .font(AppTypography.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
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
