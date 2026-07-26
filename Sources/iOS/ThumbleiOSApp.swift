import SwiftUI

@main
struct ThumbleiOSApp: App {
    @UIApplicationDelegateAdaptor(ThumbleApplicationDelegate.self) private var applicationDelegate
    @StateObject private var client = ControllerClient()
    @StateObject private var orientationCoordinator = GamepadOrientationCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IOSContentView()
                .environmentObject(client)
                .onAppear {
                    applySelectedProfileOrientation()
                }
                .onChange(of: client.selectedGamepadProfileID) { _, _ in
                    applySelectedProfileOrientation()
                }
                .onChange(of: client.gamepadProfiles) { _, _ in
                    applySelectedProfileOrientation()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .inactive:
                        TouchCaptureUIView.deactivateAllRegisteredTouches()
                        client.appWillBecomeInactive()
                    case .background:
                        TouchCaptureUIView.deactivateAllRegisteredTouches()
                        client.appDidEnterBackground()
                    case .active:
                        client.appDidBecomeActive()
                        applySelectedProfileOrientation()
                    default:
                        break
                    }
                }
        }
    }

    private func applySelectedProfileOrientation() {
        orientationCoordinator.apply(client.selectedGamepadProfileOrientationPreference) {
            TouchCaptureUIView.deactivateAllRegisteredTouches()
            client.releaseAll()
        }
    }
}
