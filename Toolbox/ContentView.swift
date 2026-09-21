import SwiftUI

struct ContentView: View {
    var body: some View {
        HSplitView {
            ToolboxSidebar()
                .frame(minWidth: 190, idealWidth: 210, maxWidth: 240)

            VideoConverterView()
                .frame(minWidth: 860)
        }
        .frame(minWidth: 1080, minHeight: 700)
    }
}

private struct ToolboxSidebar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Toolbox")
                .font(.title2.bold())
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 22)

            Text("创作")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            Label("视频转换", systemImage: "film.stack")
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)

            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
