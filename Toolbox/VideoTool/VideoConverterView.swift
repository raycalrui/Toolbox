import SwiftUI
import UniformTypeIdentifiers

struct VideoConverterView: View {
    @StateObject private var model = VideoConverterViewModel()
    @State private var presetName = ""
    @State private var showingPresetName = false
    @State private var isInspectorVisible = true

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
    }

    private var mainPanel: some View {
        VStack(spacing: 0) {
            header
            Divider()
            fileArea
            Divider()
            footer
        }
    }

    private var inspector: some View {
        PresetEditorView(
            preset: $model.selectedPreset,
            presets: model.presetStore.allPresets,
            selectPreset: model.selectPreset,
            savePreset: { showingPresetName = true },
            updatePreset: model.updateSelectedPreset,
            deletePreset: model.deleteSelectedPreset
        )
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
            List {
                ForEach(model.items) { item in
                    VideoItemRow(
                        item: item,
                        remove: { model.remove(item) },
                        reveal: { model.reveal(item) }
                    )
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
                    .disabled(model.items.isEmpty || model.outputDirectory == nil || !model.isFFmpegAvailable)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func inspectorWidth(for availableWidth: CGFloat) -> CGFloat {
        min(max(availableWidth * 0.35, 360), 420)
    }
}

private struct VideoItemRow: View {
    let item: VideoItem
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
                } else if item.status == .ready {
                    Button("Remove", systemImage: "xmark", action: remove)
                        .labelStyle(.iconOnly)
                }
            }

            if item.status == .converting {
                ProgressView(value: item.progress)
            }

            HStack {
                Label(item.status.label, systemImage: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
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
}
