import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class VideoConverterViewModel: ObservableObject {
    @Published var items: [VideoItem] = []
    @Published var defaultPreset: ConversionPreset
    @Published var selectedItemID: UUID?
    @Published var outputDirectory: URL?
    @Published var isConverting = false
    @Published var presentedError: String?

    let presetStore = PresetStore()
    private let engine = FFmpegEngine()
    private var conversionTask: Task<Void, Never>?

    init() {
        defaultPreset = ConversionPreset.builtIns[0]
    }

    var selectedItem: VideoItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    var editorPreset: ConversionPreset {
        selectedItem?.preset ?? defaultPreset
    }

    var hasRunnableItems: Bool {
        items.contains { $0.status.canStart }
    }

    var isFFmpegAvailable: Bool { engine.executableURL != nil }

    var ffmpegStatus: String {
        isFFmpegAvailable ? "FFmpeg Ready" : "FFmpeg Not Found"
    }

    var estimatedOutputSize: String? {
        let bytes = items
            .filter { $0.status.canStart }
            .reduce(Int64(0)) { total, item in
                let preset = normalizedPreset(item.preset)
                guard preset.videoCodec.supportsBitrate,
                      let videoBitrate = preset.videoBitrateMbps else { return total }
                let audioBitrate = preset.audioCodec == .aac ? preset.audioBitrateKbps * 1_000 : 1_536_000
                return total + Int64(item.metadata.duration * Double(videoBitrate * 1_000_000 + audioBitrate) / 8)
            }
        guard bytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func chooseVideos() {
        let panel = NSOpenPanel()
        panel.title = "Choose Videos to Convert"
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Output Folder"
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
                    let item = VideoItem(url: url, metadata: metadata, preset: defaultPreset)
                    items.append(item)
                    selectedItemID = selectedItemID ?? item.id
                    outputDirectory = outputDirectory ?? url.deletingLastPathComponent()
                } catch {
                    presentedError = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
        }
    }

    func remove(_ item: VideoItem) {
        guard item.status != .converting else { return }
        items.removeAll { $0.id == item.id }
        if selectedItemID == item.id {
            selectedItemID = items.first?.id
        }
    }

    func selectPreset(_ preset: ConversionPreset) {
        updateEditorPreset(preset)
    }

    func updateEditorPreset(_ preset: ConversionPreset) {
        if let selectedItemID, let itemIndex = index(for: selectedItemID) {
            items[itemIndex].preset = preset
        } else {
            defaultPreset = preset
        }
    }

    func startConversion() {
        guard !isConverting, hasRunnableItems else { return }
        guard let outputDirectory else {
            presentedError = VideoToolError.invalidOutputDirectory.localizedDescription
            return
        }

        isConverting = true
        let runnableIDs = items.filter { $0.status.canStart }.map(\.id)
        for index in items.indices where items[index].status.canStart {
            items[index].status = .ready
            items[index].progress = 0
            items[index].elapsedTime = 0
            items[index].processingFPS = 0
            items[index].outputURL = nil
        }

        conversionTask = Task {
            for itemID in runnableIDs {
                guard !Task.isCancelled else { break }
                guard let itemIndex = index(for: itemID) else { continue }
                let item = items[itemIndex]
                let preset = normalizedPreset(item.preset)
                let outputURL = uniqueOutputURL(for: item, in: outputDirectory, preset: preset)
                items[itemIndex].status = .converting

                do {
                    try await engine.convert(
                        input: item.url,
                        output: outputURL,
                        preset: preset,
                        duration: item.metadata.duration
                    ) { update in
                        guard let currentIndex = self.index(for: itemID) else { return }
                        self.items[currentIndex].progress = update.fraction
                        self.items[currentIndex].elapsedTime = update.elapsedTime
                        self.items[currentIndex].processingFPS = update.framesPerSecond
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
                    presentedError = "Conversion failed for \(item.url.lastPathComponent): \(error.localizedDescription)"
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

    func outputFileName(for item: VideoItem) -> String {
        let preset = normalizedPreset(item.preset)
        return generatedFileName(for: item, preset: preset)
            .appending(".\(preset.container.fileExtension)")
    }

    func saveCurrentAsPreset(named name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var preset = editorPreset
        preset.id = UUID()
        preset.name = name
        preset.isBuiltIn = false
        presetStore.save(preset)
        updateEditorPreset(preset)
    }

    func deleteSelectedPreset() {
        let preset = editorPreset
        guard !preset.isBuiltIn else { return }
        presetStore.delete(preset)
        updateEditorPreset(ConversionPreset.builtIns[0])
    }

    func updateSelectedPreset() {
        let preset = editorPreset
        guard !preset.isBuiltIn else { return }
        presetStore.save(preset)
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

    private func uniqueOutputURL(for item: VideoItem, in directory: URL, preset: ConversionPreset) -> URL {
        let fileName = generatedFileName(for: item, preset: preset)
        var candidate = directory
            .appendingPathComponent(fileName)
            .appendingPathExtension(preset.container.fileExtension)
        var counter = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(fileName)_\(counter)")
                .appendingPathExtension(preset.container.fileExtension)
            counter += 1
        }
        return candidate
    }

    private func generatedFileName(for item: VideoItem, preset: ConversionPreset) -> String {
        let customBase = sanitizedFileName(item.outputBaseName)
        let fallbackBase = sanitizedFileName(item.url.deletingPathExtension().lastPathComponent)
        let base = customBase.isEmpty ? fallbackBase : customBase
        let width = preset.width ?? item.metadata.width
        let height = preset.height ?? item.metadata.height
        let frameRate = preset.frameRate ?? item.metadata.frameRate

        var tags = ["\(resolutionTag(width: width, height: height))\(frameRateTag(frameRate))", preset.videoCodec.fileNameTag]
        if preset.videoCodec.supportsBitrate, let bitrate = preset.videoBitrateMbps {
            tags.append("\(bitrate)M")
        }
        return ([base] + tags).joined(separator: "_")
    }

    private func sanitizedFileName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: "/:"))
            .joined(separator: "-")
    }

    private func resolutionTag(width: Int, height: Int) -> String {
        switch (width, height) {
        case (7680, 4320): "8K"
        case (3840, 2160): "4K"
        case (2560, 1440): "1440P"
        case (1920, 1080): "1080P"
        case (1280, 720): "720P"
        default: "\(width)x\(height)"
        }
    }

    private func frameRateTag(_ frameRate: Double) -> String {
        guard frameRate > 0 else { return "" }
        if abs(frameRate.rounded() - frameRate) < 0.01 {
            return String(Int(frameRate.rounded()))
        }
        return String(format: "%.2f", frameRate).replacingOccurrences(of: ".", with: "p")
    }
}
