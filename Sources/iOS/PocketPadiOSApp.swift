import SwiftUI

@main
struct PocketPadiOSApp: App {
    @StateObject private var client = ControllerClient()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            IOSContentView()
                .environmentObject(client)
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
                    default:
                        break
                    }
                }
        }
    }
}
