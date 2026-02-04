import SwiftUI
import AuthenticationServices

/// SwiftUI wrapper for ASAuthorizationAppleIDButton. On tap, runs the given action (e.g. authService.signInWithApple()).
struct SignInWithAppleButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            SignInWithAppleButtonRepresentable()
                .frame(height: 50)
        }
        .buttonStyle(.plain)
    }
}

private struct SignInWithAppleButtonRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = 12
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}
