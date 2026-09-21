import SwiftUI
import UniformTypeIdentifiers

struct VideoConverterView: View {
    @StateObject private var model = VideoConverterViewModel()
    @State private var presetName = ""
    @State private var showingPresetName = false

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                header
                Divider()
                fileArea
                Divider()
                footer
            }
            .frame(minWidth: 480)

            PresetEditorView(
                preset: $model.selectedPreset,
                presets: model.presetStore.allPresets,
                selectPreset: model.selectPreset,
                savePreset: { showingPresetName = true },
                updatePreset: model.updateSelectedPreset,
                deletePreset: model.deleteSelectedPreset
            )
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 440)
        }
        .alert("转换错误", isPresented: Binding(
            get: { model.presentedError != nil },
            set: { if !$0 { model.presentedError = nil } }
        )) {
            Button("好") { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "未知错误")
        }
        .sheet(isPresented: $showingPresetName) {
            VStack(alignment: .leading, spacing: 16) {
                Text("保存导出预设").font(.headline)
                TextField("预设名称", text: $presetName)
                HStack {
                    Spacer()
                    Button("取消") { showingPresetName = false }
                    Button("保存") {
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

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("视频转换").font(.title2.bold())
                Text(model.ffmpegStatus)
                    .font(.caption)
                    .foregroundStyle(model.ffmpegStatus == "FFmpeg 已就绪" ? Color.secondary : Color.red)
            }
            Spacer()
            Button("添加视频", systemImage: "plus", action: model.chooseVideos)
        }
        .padding()
    }

    @ViewBuilder
    private var fileArea: some View {
        if model.items.isEmpty {
            ContentUnavailableView {
                Label("添加要转换的视频", systemImage: "film.stack")
            } description: {
                Text("拖入视频，或点击“添加视频”选择多个文件")
            } actions: {
                Button("选择视频", action: model.chooseVideos)
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
                    model.outputDirectory?.path(percentEncoded: false) ?? "选择导出文件夹",
                    systemImage: "folder"
                )
                .lineLimit(1)
            }
            .help(model.outputDirectory?.path(percentEncoded: false) ?? "选择导出文件夹")

            Spacer()

            if let estimatedOutputSize = model.estimatedOutputSize {
                Text("预计约 \(estimatedOutputSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if model.isConverting {
                Button("取消", role: .destructive, action: model.cancelConversion)
            } else {
                Button("开始转换", systemImage: "play.fill", action: model.startConversion)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.items.isEmpty || model.outputDirectory == nil || model.ffmpegStatus != "FFmpeg 已就绪")
            }
        }
        .padding()
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
                    Button("在 Finder 中显示", systemImage: "folder", action: reveal)
                        .labelStyle(.iconOnly)
                } else if item.status == .ready {
                    Button("移除", systemImage: "xmark", action: remove)
                        .labelStyle(.iconOnly)
                }
            }

            if item.status == .converting || item.progress > 0 {
                ProgressView(value: item.progress)
            }

            HStack {
                Text(item.status.label)
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
}
