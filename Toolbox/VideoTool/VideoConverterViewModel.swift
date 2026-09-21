import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class VideoConverterViewModel: ObservableObject {
    @Published var items: [VideoItem] = []
    @Published var selectedPreset: ConversionPreset
    @Published var outputDirectory: URL?
    @Published var isConverting = false
    @Published var presentedError: String?

    let presetStore = PresetStore()
    private let engine = FFmpegEngine()
    private var conversionTask: Task<Void, Never>?

    init() {
        selectedPreset = ConversionPreset.builtIns[0]
    }

    var ffmpegStatus: String {
        engine.executableURL == nil ? "未找到 FFmpeg" : "FFmpeg 已就绪"
    }

    var estimatedOutputSize: String? {
        guard !items.isEmpty,
              selectedPreset.videoCodec.supportsBitrate,
              let videoBitrate = selectedPreset.videoBitrateMbps else { return nil }

        let totalDuration = items.reduce(0) { $0 + $1.metadata.duration }
        let audioBitrate = selectedPreset.audioCodec == .aac ? selectedPreset.audioBitrateKbps * 1_000 : 1_536_000
        let bytes = Int64(totalDuration * Double(videoBitrate * 1_000_000 + audioBitrate) / 8)
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func chooseVideos() {
        let panel = NSOpenPanel()
        panel.title = "选择要转换的视频"
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择导出文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK {
            outputDirectory = panel.url
        }
    }

    func add(providers: [NSItemProvider]) -> Bool {
        let type = UTType.fileURL.identifier
        let supported = providers.filter { $0.hasItemConformingToTypeIdentifier(type) }

        for provider in supported {
            provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = item as? URL
                }
                guard let url else { return }
                Task { @MainActor in self?.add(urls: [url]) }
            }
        }
        return !supported.isEmpty
    }

    func add(urls: [URL]) {
        let existing = Set(items.map(\.url))
        let newURLs = urls.filter { !existing.contains($0) }

        for url in newURLs {
            Task {
                do {
                    let metadata = try await VideoMetadataLoader.load(from: url)
                    items.append(VideoItem(url: url, metadata: metadata))
                    outputDirectory = outputDirectory ?? url.deletingLastPathComponent()
                } catch {
                    presentedError = "无法读取 \(url.lastPathComponent)：\(error.localizedDescription)"
                }
            }
        }
    }

    func remove(_ item: VideoItem) {
        guard !isConverting else { return }
        items.removeAll { $0.id == item.id }
    }

    func selectPreset(_ preset: ConversionPreset) {
        selectedPreset = preset
    }

    func startConversion() {
        guard !isConverting, !items.isEmpty else { return }
        guard let outputDirectory else {
            presentedError = VideoToolError.invalidOutputDirectory.localizedDescription
            return
        }

        isConverting = true
        for index in items.indices {
            items[index].status = .ready
            items[index].progress = 0
            items[index].outputURL = nil
        }

        let preset = normalizedPreset(selectedPreset)
        conversionTask = Task {
            for itemID in items.map(\.id) {
                guard !Task.isCancelled, let itemIndex = index(for: itemID) else { break }
                let item = items[itemIndex]
                let outputURL = uniqueOutputURL(for: item.url, in: outputDirectory, preset: preset)
                items[itemIndex].status = .converting

                do {
                    try await engine.convert(
                        input: item.url,
                        output: outputURL,
                        preset: preset,
                        duration: item.metadata.duration
                    ) { progress in
                        guard let currentIndex = self.index(for: itemID) else { return }
                        self.items[currentIndex].progress = progress
                    }

                    if let completedIndex = index(for: itemID) {
                        items[completedIndex].status = .completed
                        items[completedIndex].progress = 1
                        items[completedIndex].outputURL = outputURL
                    }
                } catch is CancellationError {
                    if let cancelledIndex = index(for: itemID) {
                        items[cancelledIndex].status = .cancelled
                    }
                    break
                } catch {
                    if let failedIndex = index(for: itemID) {
                        items[failedIndex].status = .failed(error.localizedDescription)
                    }
                    presentedError = "\(item.url.lastPathComponent) 转换失败：\(error.localizedDescription)"
                }
            }
            isConverting = false
            conversionTask = nil
        }
    }

    func cancelConversion() {
        conversionTask?.cancel()
        engine.cancel()
    }

    func reveal(_ item: VideoItem) {
        guard let outputURL = item.outputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([outputURL])
    }

    func saveCurrentAsPreset(named name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var preset = selectedPreset
        preset.id = UUID()
        preset.name = name
        preset.isBuiltIn = false
        presetStore.save(preset)
        selectedPreset = preset
    }

    func deleteSelectedPreset() {
        guard !selectedPreset.isBuiltIn else { return }
        presetStore.delete(selectedPreset)
        selectedPreset = ConversionPreset.builtIns[0]
    }

    func updateSelectedPreset() {
        guard !selectedPreset.isBuiltIn else { return }
        presetStore.save(selectedPreset)
    }

    private func index(for id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    private func normalizedPreset(_ preset: ConversionPreset) -> ConversionPreset {
        var result = preset
        if let requiredContainer = result.videoCodec.requiredContainer {
            result.container = requiredContainer
        }
        if result.container == .mp4, result.audioCodec == .pcm {
            result.audioCodec = .aac
            result.audioBitrateKbps = 192
        }
        return result
    }

    private func uniqueOutputURL(for input: URL, in directory: URL, preset: ConversionPreset) -> URL {
        let base = input.deletingPathExtension().lastPathComponent
        var candidate = directory
            .appendingPathComponent("\(base)-converted")
            .appendingPathExtension(preset.container.fileExtension)
        var counter = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(base)-converted-\(counter)")
                .appendingPathExtension(preset.container.fileExtension)
            counter += 1
        }
        return candidate
    }
}
