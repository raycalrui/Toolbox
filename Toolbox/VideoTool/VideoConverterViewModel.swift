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

    var isFFmpegAvailable: Bool { engine.executableURL != nil }

    var ffmpegStatus: String {
        isFFmpegAvailable ? "FFmpeg Ready" : "FFmpeg Not Found"
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
                    items.append(VideoItem(url: url, metadata: metadata))
                    outputDirectory = outputDirectory ?? url.deletingLastPathComponent()
                } catch {
                    presentedError = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
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
            items[index].elapsedTime = 0
            items[index].processingFPS = 0
            items[index].outputURL = nil
        }

        let preset = normalizedPreset(selectedPreset)
        conversionTask = Task {
            for itemID in items.map(\.id) {
                guard !Task.isCancelled, let itemIndex = index(for: itemID) else { break }
                let item = items[itemIndex]
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
        let preset = normalizedPreset(selectedPreset)
        return generatedFileName(for: item, preset: preset)
            .appending(".\(preset.container.fileExtension)")
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
