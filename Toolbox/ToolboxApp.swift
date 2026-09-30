import AppKit
import SwiftUI

@MainActor
private final class ToolboxAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Development builds can retain a cached generic Dock icon across
        // rebuilds. Load the bundled icon explicitly for the running app.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
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
