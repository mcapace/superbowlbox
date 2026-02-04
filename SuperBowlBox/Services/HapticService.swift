import UIKit

// MARK: - Haptic feedback (UIImpactFeedbackGenerator, UINotificationFeedbackGenerator)

enum HapticService {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    static func prepare() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }

    /// Light tap — selections, toggles, subtle confirmations
    static func impactLight() {
        lightGenerator.impactOccurred()
    }

    /// Medium tap — button presses, card taps, list row select
    static func impactMedium() {
        mediumGenerator.impactOccurred()
    }

    /// Heavy tap — major actions (scan complete, pool created, delete)
    static func impactHeavy() {
        heavyGenerator.impactOccurred()
    }

    /// Success — scan succeeded, pool saved, winner updated
    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    /// Warning — validation failed, retry suggested
    static func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Error — scan failed, network error
    static func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    /// Selection change — tab switch, picker, segment
    static func selection() {
        selectionGenerator.selectionChanged()
    }
}
