import AppKit
import SwiftUI

@MainActor
private final class ToolboxAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FinderServiceProvider.shared.register()
    }
}

@main
struct ToolboxApp: App {
    @NSApplicationDelegateAdaptor(ToolboxAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1280, height: 780)
        .windowResizability(.contentMinSize)
    }
}
