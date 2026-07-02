import AppKit
import SwiftUI

@main
struct PocketPadMacApp: App {
    @StateObject private var server = MacControllerServer()

    var body: some Scene {
        WindowGroup {
            MacContentView()
                .environmentObject(server)
                .frame(minWidth: 840, minHeight: 620)
                .onAppear { server.start() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    server.releaseAll(reason: "Mac helper quitting")
                }
        }
        .windowResizability(.contentMinSize)
    }
}
