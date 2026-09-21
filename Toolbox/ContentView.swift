import SwiftUI

struct ContentView: View {
    @State private var selection = "video"

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("创作") {
                    Label("视频转换", systemImage: "film.stack")
                        .tag("video")
                }
            }
            .navigationTitle("Toolbox")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            VideoConverterView()
        }
        .frame(minWidth: 1120, minHeight: 680)
    }
}
