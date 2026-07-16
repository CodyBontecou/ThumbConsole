import UIKit

@MainActor
final class ThumbConsoleApplicationDelegate: NSObject, UIApplicationDelegate {
    private var supportedOrientationMask: UIInterfaceOrientationMask = ThumbConsoleApplicationDelegate.automaticMask

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        supportedOrientationMask
    }

    func setSupportedOrientationMask(_ mask: UIInterfaceOrientationMask) {
        supportedOrientationMask = mask
    }

    static var automaticMask: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }
}

@MainActor
final class GamepadOrientationCoordinator: ObservableObject {
    private(set) var lastRequestedPreference: GamepadProfileOrientationPreference = .automatic

    /// Reapplies the authoritative profile preference. Active inputs are released
    /// before the delegate mask changes or a scene geometry request is made.
    func apply(
        _ preference: GamepadProfileOrientationPreference,
        releaseActiveInputs: () -> Void
    ) {
        releaseActiveInputs()
        lastRequestedPreference = preference

        let mask = interfaceOrientationMask(for: preference)
        (UIApplication.shared.delegate as? ThumbConsoleApplicationDelegate)?
            .setSupportedOrientationMask(mask)

        guard let scene = activeWindowScene else { return }
        for window in scene.windows {
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        // Geometry updates can be rejected during iPad multitasking, transitions,
        // or when the scene is not active. The error handler intentionally absorbs
        // those recoverable failures; scene activation will reapply the preference.
        let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
        scene.requestGeometryUpdate(preferences) { _ in }
    }

    func interfaceOrientationMask(
        for preference: GamepadProfileOrientationPreference
    ) -> UIInterfaceOrientationMask {
        switch GamepadSupportedOrientationSet(preference) {
        case .automatic: ThumbConsoleApplicationDelegate.automaticMask
        case .portrait: .portrait
        case .landscape: .landscape
        }
    }

    private var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first(where: { $0.activationState == .foregroundInactive })
    }
}
