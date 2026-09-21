import SwiftUI

struct ContentView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Toolbox", systemImage: "shippingbox")
        } description: {
            Text("请选择第一个要开发的工具")
        }
        .frame(minWidth: 720, minHeight: 480)
    }
}
