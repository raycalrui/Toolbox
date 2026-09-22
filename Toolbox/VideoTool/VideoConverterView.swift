import SwiftUI
import UniformTypeIdentifiers

struct VideoConverterView: View {
    let finderAction: FinderPendingAction?
    let onFinderActionHandled: () -> Void

    @StateObject private var model = VideoConverterViewModel()
    @State private var presetName = ""
    @State private var showingPresetName = false
    @State private var isInspectorVisible = true

    init(
        finderAction: FinderPendingAction? = nil,
        onFinderActionHandled: @escaping () -> Void = {}
    ) {
        self.finderAction = finderAction
        self.onFinderActionHandled = onFinderActionHandled
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                mainPanel
                    .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)

                if isInspectorVisible {
                    Divider()
                    inspector
                        .frame(width: inspectorWidth(for: proxy.size.width))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isInspectorVisible)
        .alert("Conversion Error", isPresented: Binding(
            get: { model.presentedError != nil },
            set: { if !$0 { model.presentedError = nil } }
        )) {
            Button("OK") { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "Unknown error")
        }
        .sheet(isPresented: $showingPresetName) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Save Export Preset").font(.headline)
                TextField("Preset Name", text: $presetName)
                HStack {
                    Spacer()
                    Button("Cancel") { showingPresetName = false }
                    Button("Save") {
                        model.saveCurrentAsPreset(named: presetName)
                        presetName = ""
                        showingPresetName = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
            .frame(width: 360)
        }
        .onChange(of: finderAction?.id, initial: true) { _, actionID in
            guard actionID != nil, let finderAction else { return }
            model.add(urls: finderAction.urls)
            onFinderActionHandled()
        }
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !model.isFFmpegAvailable {
                FFmpegDependencyBanner(
                    status: model.ffmpegDependencyStatus,
                    copyCommand: model.copyFFmpegInstallCommand,
                    checkAgain: model.refreshFFmpegAvailability
                )
                Divider()
            }
            fileArea
            Divider()
            footer
        }
    }

    private var inspector: some View {
        Group {
            if let selectedItem = model.selectedItem {
                PresetEditorView(
                    preset: Binding(
                        get: { model.editorPreset },
                        set: model.updateEditorPreset
                    ),
                    presets: model.presetStore.allPresets,
                    selectPreset: model.selectPreset,
                    savePreset: { showingPresetName = true },
                    updatePreset: model.updateSelectedPreset,
                    deletePreset: model.deleteSelectedPreset
                )
                .disabled(!selectedItem.status.canStart)
            } else {
                ContentUnavailableView(
                    "Select a Video",
                    systemImage: "film.stack",
                    description: Text("Choose a queue item to edit its export settings.")
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Video Converter").font(.title2.bold())
                Text(model.ffmpegStatus)
                    .font(.caption)
                    .foregroundStyle(model.isFFmpegAvailable ? Color.secondary : Color.red)
            }
            Spacer()
            Button("Add Videos", systemImage: "plus", action: model.chooseVideos)
            Button {
                isInspectorVisible.toggle()
            } label: {
                Label(
                    isInspectorVisible ? "Hide Export Settings" : "Show Export Settings",
                    systemImage: "sidebar.right"
                )
            }
            .labelStyle(.iconOnly)
            .help(isInspectorVisible ? "Hide Export Settings" : "Show Export Settings")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var fileArea: some View {
        if model.items.isEmpty {
            ContentUnavailableView {
                Label("Add Videos to Convert", systemImage: "film.stack")
            } description: {
                Text("Drop videos here, or click Add Videos to select multiple files.")
            } actions: {
                Button("Choose Videos", action: model.chooseVideos)
            }
            .contentShape(Rectangle())
            .onDrop(of: [.fileURL], isTargeted: nil, perform: model.add(providers:))
        } else {
            List(selection: $model.selectedItemID) {
                ForEach($model.items) { $item in
                    VideoItemRow(
                        item: $item,
                        outputFileName: model.outputFileName(for: item),
                        remove: { model.remove(item) },
                        reveal: { model.reveal(item) }
                    )
                    .tag(item.id)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                model.add(urls: urls)
                return true
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button(action: model.chooseOutputDirectory) {
                Label(
                    model.outputDirectory?.lastPathComponent ?? "Choose Output Folder",
                    systemImage: "folder"
                )
                .lineLimit(1)
            }
            .frame(maxWidth: 240, alignment: .leading)
            .help(model.outputDirectory?.path(percentEncoded: false) ?? "Choose Output Folder")

            Spacer()

            if let estimatedOutputSize = model.estimatedOutputSize {
                Text("Estimated: ~\(estimatedOutputSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.isConverting {
                Button("Cancel", role: .destructive, action: model.cancelConversion)
            } else {
                Button("Start Conversion", systemImage: "play.fill", action: model.startConversion)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.hasRunnableItems || model.outputDirectory == nil || !model.isFFmpegAvailable)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func inspectorWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.35, 360), 420)
    }
}

private struct FFmpegDependencyBanner: View {
    let status: FFmpegDependencyStatus
    let copyCommand: () -> Void
    let checkAgain: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.semibold)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("brew install ffmpeg")
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            Spacer()
            if status == .homebrewMissing {
                Link("Get Homebrew", destination: URL(string: "https://brew.sh")!)
            }
            Button("Copy Command", action: copyCommand)
            Button("Check Again", action: checkAgain)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.08))
    }

    private var title: String {
        status == .homebrewMissing ? "Homebrew and FFmpeg Required" : "FFmpeg Required"
    }

    private var message: String {
        if status == .homebrewMissing {
            return "Install Homebrew from brew.sh, then run the command below. Toolbox never installs software automatically."
        }
        return "Install FFmpeg with Homebrew, then check again. Toolbox never installs software automatically."
    }
}

private struct VideoItemRow: View {
    @Binding var item: VideoItem
    let outputFileName: String
    let remove: () -> Void
    let reveal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.url.lastPathComponent).fontWeight(.medium).lineLimit(1)
                    Text("\(item.metadata.resolutionText) · \(item.metadata.frameRateText) · \(item.metadata.durationText) · \(item.metadata.codec) · \(item.metadata.fileSizeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if item.status == .completed {
                    Button("Reveal in Finder", systemImage: "folder", action: reveal)
                        .labelStyle(.iconOnly)
                }
                if item.status != .converting {
                    Button("Remove", systemImage: "xmark", action: remove)
                        .labelStyle(.iconOnly)
                }
            }

            HStack(spacing: 8) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Output Name", text: $item.outputBaseName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(item.status != .ready)
            }
            Text("Output: \(outputFileName)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(outputFileName)

            if item.status == .converting {
                HStack(spacing: 10) {
                    ProgressView(value: item.progress)
                    Text(item.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.monospacedDigit())
                        .frame(width: 38, alignment: .trailing)
                }
            }

            HStack(spacing: 12) {
                Label(item.status.label, systemImage: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                if item.elapsedTime > 0 {
                    Text("Elapsed \(elapsedTimeText)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if item.processingFPS > 0 {
                    Text("\(item.processingFPS, specifier: "%.1f") fps")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if let remainingTimeText {
                    Text("Remaining \(remainingTimeText)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                if case let .failed(message) = item.status {
                    Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        switch item.status {
        case .completed: .green
        case .failed: .red
        case .cancelled: .orange
        default: .secondary
        }
    }

    private var statusIcon: String {
        switch item.status {
        case .ready: "clock"
        case .converting: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    private var elapsedTimeText: String {
        durationText(item.elapsedTime)
    }

    private var remainingTimeText: String? {
        guard item.status == .converting,
              item.progress > 0.005,
              item.progress < 1,
              item.elapsedTime > 0 else { return nil }
        let remaining = item.elapsedTime * (1 - item.progress) / item.progress
        guard remaining.isFinite, remaining >= 0 else { return nil }
        return durationText(remaining)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        if totalSeconds >= 3600 {
            return String(format: "%02d:%02d:%02d", totalSeconds / 3600, (totalSeconds % 3600) / 60, totalSeconds % 60)
        }
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
