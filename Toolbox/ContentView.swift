import SwiftUI

struct ContentView: View {
    @State private var selectedTool: ToolboxTool = .videoConverter

    var body: some View {
        HSplitView {
            ToolboxSidebar(selection: $selectedTool)
                .frame(minWidth: 190, idealWidth: 210, maxWidth: 240)

            toolContent
                .frame(minWidth: 860, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1080, minHeight: 700)
    }

    @ViewBuilder
    private var toolContent: some View {
        switch selectedTool {
        case .videoConverter:
            VideoConverterView()
        case .textDiff:
            TextDiffView()
        case .uuidGenerator:
            UUIDRandomGeneratorView()
        case .passwordTools:
            PasswordToolsView()
        case .networkTools:
            NetworkToolsView()
        }
    }
}

private enum ToolboxTool: String, CaseIterable, Identifiable {
    case videoConverter
    case textDiff
    case uuidGenerator
    case passwordTools
    case networkTools

    var id: Self { self }

    var title: String {
        switch self {
        case .videoConverter: "Video Converter"
        case .textDiff: "Text Diff"
        case .uuidGenerator: "UUID & Random"
        case .passwordTools: "Password Tools"
        case .networkTools: "Network Tools"
        }
    }

    var icon: String {
        switch self {
        case .videoConverter: "film.stack"
        case .textDiff: "arrow.left.arrow.right"
        case .uuidGenerator: "number"
        case .passwordTools: "key.horizontal"
        case .networkTools: "network"
        }
    }

    var category: ToolCategory {
        switch self {
        case .videoConverter: .creative
        case .textDiff, .uuidGenerator: .developer
        case .passwordTools: .security
        case .networkTools: .network
        }
    }
}

private enum ToolCategory: String, CaseIterable {
    case creative = "Creative"
    case developer = "Text & Developer"
    case security = "Privacy & Security"
    case network = "Network"
}

private struct ToolboxSidebar: View {
    @Binding var selection: ToolboxTool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Toolbox")
                .font(.title2.bold())
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

            List(selection: $selection) {
                ForEach(ToolCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(ToolboxTool.allCases.filter { $0.category == category }) { tool in
                            Label(tool.title, systemImage: tool.icon)
                                .tag(tool)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
