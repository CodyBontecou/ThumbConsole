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
                        client.appWillBecomeInactive()
                    case .background:
                        client.appDidEnterBackground()
                    default:
                        break
                    }
                }
        }
    }
}
