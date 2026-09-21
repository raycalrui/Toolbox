import SwiftUI

@main
struct ToolboxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 1280, height: 780)
        .windowResizability(.contentMinSize)
    }
}
