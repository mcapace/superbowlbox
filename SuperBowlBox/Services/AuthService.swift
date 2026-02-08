import Foundation
import AuthenticationServices
import SwiftUI

// MARK: - Auth state

enum AuthProvider: String, Codable {
    case apple
    case google
    case email
}

struct AuthUser: Equatable {
    let provider: AuthProvider
    let id: String
    var email: String?
    var displayName: String?
}

// MARK: - Auth Service (Sign in with Apple + Google)

class AuthService: ObservableObject {
    @Published private(set) var currentUser: AuthUser?
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?

    private let appleUserKey = "squareUp.appleUserID"
    private let authUserKey = "squareUp.authUser"
    private let emailRefreshTokenKey = "squareUp.emailRefreshToken"

    init() {
        loadSavedUser()
    }

    var isSignedIn: Bool { currentUser != nil }

    // MARK: - Persistence

    private func loadSavedUser() {
        guard let data = UserDefaults.standard.data(forKey: authUserKey),
              let decoded = try? JSONDecoder().decode(AuthUserCodable.self, from: data) else {
            return
        }
        currentUser = decoded.toAuthUser()
    }

    private func saveUser(_ user: AuthUser?) {
        if let user = user {
            let codable = AuthUserCodable(from: user)
            if let data = try? JSONEncoder().encode(codable) {
                UserDefaults.standard.set(data, forKey: authUserKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: authUserKey)
            UserDefaults.standard.removeObject(forKey: appleUserKey)
            UserDefaults.standard.removeObject(forKey: emailRefreshTokenKey)
        }
        currentUser = user
    }

    // MARK: - Sign in with Apple

    func signInWithApple() {
        isSigningIn = true
        errorMessage = nil
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(authService: self)
        controller.delegate = delegate
        controller.presentationContextProvider = delegate
        controller.performRequests()
    }

    func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        DispatchQueue.main.async { [weak self] in
            self?.isSigningIn = false
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    self?.errorMessage = "Invalid Apple credential"
                    return
                }
                let userID = credential.user
                let email = credential.email
                var displayName: String?
                if let name = credential.fullName {
                    let parts = [name.givenName, name.familyName].compactMap { $0 }
                    displayName = parts.isEmpty ? nil : parts.joined(separator: " ")
                }
                let user = AuthUser(
                    provider: .apple,
                    id: userID,
                    email: email,
                    displayName: displayName
                )
                UserDefaults.standard.set(userID, forKey: self?.appleUserKey ?? "squareUp.appleUserID")
                self?.saveUser(user)
                LoginDatabaseService.recordLogin(user: user)
                self?.errorMessage = nil
            case .failure(let error):
                let nsError = error as NSError
                if nsError.code == ASAuthorizationError.canceled.rawValue {
                    self?.errorMessage = nil
                } else {
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Sign in with Google (requires GoogleSignIn package)
    /// Call from main thread only. AppAuth/Google access the presenting view controller and must run on main.

    @MainActor
    func signInWithGoogle(presenting: UIViewController) async {
        isSigningIn = true
        errorMessage = nil
        let result = await GoogleSignInBridge.signIn(presenting: presenting)
        isSigningIn = false
        switch result {
        case .success(let user):
            saveUser(user)
            LoginDatabaseService.recordLogin(user: user)
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign in with Email (Supabase Auth)

    @MainActor
    func signInWithEmail(email: String, password: String) async {
        guard SupabaseAuthService.isConfigured else {
            errorMessage = SupabaseAuthError.notConfigured.errorDescription
            return
        }
        isSigningIn = true
        errorMessage = nil
        do {
            let session = try await SupabaseAuthService.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            let rawEmail = session.user.email ?? email
            let displayName = rawEmail.split(separator: "@").first.map(String.init)
            let user = AuthUser(
                provider: .email,
                id: session.user.id,
                email: rawEmail,
                displayName: displayName
            )
            if let refresh = session.refreshToken {
                UserDefaults.standard.set(refresh, forKey: emailRefreshTokenKey)
            }
            saveUser(user)
            LoginDatabaseService.recordLogin(user: user)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }

    @MainActor
    func signUpWithEmail(email: String, password: String) async {
        guard SupabaseAuthService.isConfigured else {
            errorMessage = SupabaseAuthError.notConfigured.errorDescription
            return
        }
        isSigningIn = true
        errorMessage = nil
        do {
            let session = try await SupabaseAuthService.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
            let rawEmail = session.user.email ?? email
            let displayName = rawEmail.split(separator: "@").first.map(String.init)
            let user = AuthUser(
                provider: .email,
                id: session.user.id,
                email: rawEmail,
                displayName: displayName
            )
            if let refresh = session.refreshToken {
                UserDefaults.standard.set(refresh, forKey: emailRefreshTokenKey)
            }
            saveUser(user)
            LoginDatabaseService.recordLogin(user: user)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }

    // MARK: - Sign out

    func signOut() {
        if let user = currentUser {
            LoginDatabaseService.recordSignOut(provider: user.provider, providerUid: user.id)
        }
        #if canImport(GoogleSignIn)
        GIDSignInBridge.signOut()
        #endif
        saveUser(nil)
        errorMessage = nil
    }
}

// MARK: - Apple Sign-In delegate

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    weak var authService: AuthService?

    init(authService: AuthService) {
        self.authService = authService
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        DispatchQueue.main.async { [weak self] in
            self?.authService?.handleAppleSignInResult(.success(authorization))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.authService?.handleAppleSignInResult(.failure(error))
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return window
        }
        if let window = scenes.flatMap(\.windows).first {
            return window
        }
        if let scene = scenes.first {
            return ASPresentationAnchor(windowScene: scene)
        }
        fatalError("No window scene available for Sign in with Apple")
    }
}

// MARK: - Codable helper for AuthUser

private struct AuthUserCodable: Codable {
    let providerRaw: String
    let id: String
    let email: String?
    let displayName: String?

    init(from user: AuthUser) {
        providerRaw = user.provider.rawValue
        id = user.id
        email = user.email
        displayName = user.displayName
    }

    func toAuthUser() -> AuthUser? {
        guard let provider = AuthProvider(rawValue: providerRaw) else { return nil }
        return AuthUser(provider: provider, id: id, email: email, displayName: displayName)
    }
}

// MARK: - Google Sign-In bridge (compiles with or without GoogleSignIn package)

enum GoogleSignInBridge {
    static func signIn(presenting: UIViewController) async -> Result<AuthUser, Error> {
        #if canImport(GoogleSignIn)
        return await GoogleSignInImplementation.signIn(presenting: presenting)
        #else
        struct GoogleSignInNotConfigured: LocalizedError {
            var errorDescription: String? { "Google Sign-In is not configured. Add the GoogleSignIn-iOS package and GIDClientID in Info.plist." }
        }
        return .failure(GoogleSignInNotConfigured())
        #endif
    }
}

#if canImport(GoogleSignIn)
import GoogleSignIn

// MARK: - Main-thread-safe presentation anchor for AppAuth

/// AppAuth’s `presentationAnchorForWebAuthenticationSession` is invoked off the main thread but
/// accesses `presentingViewController.view.window`. This wrapper captures the window on the main
/// thread and exposes it via a view that returns the cached window from any thread.
private final class MainThreadPresentationAnchorViewController: UIViewController {
    private let cachedWindow: UIWindow?

    init(wrapping source: UIViewController) {
        assert(Thread.isMainThread, "Create wrapper on main thread only")
        self.cachedWindow = source.view.window
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        let anchorView = AnchorView()
        anchorView.setCachedWindow(cachedWindow)
        view = anchorView
    }
}

/// UIView that returns a cached window so `view.window` can be read from any thread without touching UIKit.
private final class AnchorView: UIView {
    private var _cachedWindow: UIWindow?

    func setCachedWindow(_ window: UIWindow?) { _cachedWindow = window }

    override var window: UIWindow? { _cachedWindow }
}

enum GIDSignInBridge {
    static func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}

private enum GoogleSignInImplementation {
    @MainActor
    static func signIn(presenting: UIViewController) async -> Result<AuthUser, Error> {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String else {
            struct MissingClientID: LocalizedError {
                var errorDescription: String? { "Add GIDClientID to Info.plist (from Google Cloud Console)." }
            }
            return .failure(MissingClientID())
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        let anchorVC = MainThreadPresentationAnchorViewController(wrapping: presenting)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: anchorVC)
            let user = AuthUser(
                provider: .google,
                id: result.user.userID ?? result.user.idToken?.tokenString ?? UUID().uuidString,
                email: result.user.profile?.email,
                displayName: result.user.profile?.name
            )
            return .success(user)
        } catch {
            return .failure(error)
        }
    }
}
#else
enum GIDSignInBridge {
    static func signOut() {}
}
#endif
