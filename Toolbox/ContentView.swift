import SwiftUI

struct ContentView: View {
    @StateObject private var finderInbox = FinderActionInbox.shared
    @StateObject private var clipboardStore = ClipboardHistoryStore()
    @StateObject private var sleepController = SleepPreventionController()
    @StateObject private var ddnsModel = CloudflareDDNSViewModel()
    @StateObject private var videoModel = VideoConverterViewModel()
    @StateObject private var recordingModel = VideoConverterViewModel(mode: .recordingFix)
    @State private var selectedTool: ToolboxTool = .videoConverter
    @State private var favoriteTools = ToolFavorites.load()
    @State private var activeFinderAction: FinderPendingAction?

    var body: some View {
        HSplitView {
            ToolboxSidebar(selection: $selectedTool, favorites: $favoriteTools)
                .frame(minWidth: 190, idealWidth: 210, maxWidth: 240)

            toolContent
                .frame(minWidth: 860, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1080, minHeight: 700)
        .onChange(of: favoriteTools) { _, tools in
            ToolFavorites.save(tools)
        }
        .onAppear(perform: routeNextFinderAction)
        .onAppear(perform: clipboardStore.startMonitoring)
        .onAppear(perform: ddnsModel.start)
        .onReceive(NotificationCenter.default.publisher(for: .finderPendingActionAdded)) { _ in
            routeNextFinderAction()
        }
    }

    @ViewBuilder
    private var toolContent: some View {
        switch selectedTool {
        case .videoConverter:
            VideoConverterView(
                model: videoModel,
                finderAction: activeFinderAction?.kind == .convertVideo ? activeFinderAction : nil,
                onFinderActionHandled: finishFinderAction
            )
        case .recordingFix:
            VideoConverterView(model: recordingModel)
        case .textDiff:
            TextDiffView(
                finderAction: activeFinderAction?.kind == .compareText ? activeFinderAction : nil,
                onFinderActionHandled: finishFinderAction
            )
        case .subtitleConverter:
            SubtitleConverterView()
        case .uuidGenerator:
            UUIDRandomGeneratorView()
        case .passwordTools:
            PasswordToolsView()
        case .networkTools:
            NetworkToolsView()
        case .clipboardHistory:
            ClipboardHistoryView(store: clipboardStore)
        case .sleepPrevention:
            SleepPreventionView(controller: sleepController)
        case .cloudflareDDNS:
            CloudflareDDNSView(model: ddnsModel)
        }
    }

    private func routeNextFinderAction() {
        guard activeFinderAction == nil,
              let action = finderInbox.consumeNext() else { return }
        activeFinderAction = action
        selectedTool = action.kind == .compareText ? .textDiff : .videoConverter
    }

    private func finishFinderAction() {
        activeFinderAction = nil
        routeNextFinderAction()
    }
}

enum ToolboxTool: String, CaseIterable, Identifiable, Hashable {
    case videoConverter
    case recordingFix
    case subtitleConverter
    case textDiff
    case uuidGenerator
    case passwordTools
    case networkTools
    case clipboardHistory
    case sleepPrevention
    case cloudflareDDNS

    var id: Self { self }

    var title: String {
        switch self {
        case .videoConverter: "Video Converter"
        case .recordingFix: "Recording Fix"
        case .subtitleConverter: "SRT Converter"
        case .textDiff: "Text Diff"
        case .uuidGenerator: "UUID & Random"
        case .passwordTools: "Password Tools"
        case .networkTools: "Network Tools"
        case .clipboardHistory: "Clipboard History"
        case .sleepPrevention: "Sleep Prevention"
        case .cloudflareDDNS: "Cloudflare DDNS"
        }
    }

    var icon: String {
        switch self {
        case .videoConverter: "film.stack"
        case .recordingFix: "record.circle"
        case .subtitleConverter: "captions.bubble"
        case .textDiff: "arrow.left.arrow.right"
        case .uuidGenerator: "number"
        case .passwordTools: "key.horizontal"
        case .networkTools: "network"
        case .clipboardHistory: "clipboard"
        case .sleepPrevention: "moon.zzz"
        case .cloudflareDDNS: "cloud"
        }
    }

    var category: ToolCategory {
        switch self {
        case .videoConverter, .recordingFix, .subtitleConverter: .creative
        case .textDiff, .uuidGenerator: .developer
        case .passwordTools: .security
        case .networkTools: .network
        case .clipboardHistory, .sleepPrevention: .system
        case .cloudflareDDNS: .network
        }
    }
}

enum ToolCategory: String, CaseIterable {
    case creative = "Creative"
    case developer = "Text & Developer"
    case security = "Privacy & Security"
    case network = "Network"
    case system = "System & Productivity"
}

private struct ToolboxSidebar: View {
    @Binding var selection: ToolboxTool
    @Binding var favorites: Set<ToolboxTool>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Toolbox")
                .font(.title2.bold())
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

            List(selection: $selection) {
                if !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(ToolboxTool.allCases.filter(favorites.contains)) { tool in
                            toolRow(tool)
                        }
                    }
                }

                ForEach(ToolCategory.allCases, id: \.self) { category in
                    Section(category.rawValue) {
                        ForEach(ToolboxTool.allCases.filter { $0.category == category }) { tool in
                            toolRow(tool)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func toolRow(_ tool: ToolboxTool) -> some View {
        HStack(spacing: 8) {
            Label(tool.title, systemImage: tool.icon)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                toggleFavorite(tool)
            } label: {
                Image(systemName: favorites.contains(tool) ? "star.fill" : "star")
                    .foregroundStyle(favorites.contains(tool) ? Color.yellow : Color.secondary)
            }
            .buttonStyle(.borderless)
            .help(favorites.contains(tool) ? "Remove from Favorites" : "Add to Favorites")
        }
        .tag(tool)
        .contextMenu {
            Button(favorites.contains(tool) ? "Remove from Favorites" : "Add to Favorites") {
                toggleFavorite(tool)
            }
        }
    }

    private func toggleFavorite(_ tool: ToolboxTool) {
        if favorites.contains(tool) {
            favorites.remove(tool)
        } else {
            favorites.insert(tool)
        }
    }
}
