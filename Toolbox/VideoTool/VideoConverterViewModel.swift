import AppKit
import Foundation
import UniformTypeIdentifiers

enum VideoConversionMode {
    case standard
    case recordingFix
}

@MainActor
final class VideoConverterViewModel: ObservableObject {
    let mode: VideoConversionMode
    @Published var items: [VideoItem] = []
    @Published var defaultPreset: ConversionPreset
    @Published var selectedItemID: UUID?
    @Published var outputDirectory: URL?
    @Published var isConverting = false
    @Published private(set) var importingCount = 0
    @Published var presentedError: String?
    @Published private(set) var ffmpegDependencyStatus: FFmpegDependencyStatus

    let presetStore = PresetStore()
    private let engine = FFmpegEngine()
    private var conversionTask: Task<Void, Never>?
    private var importingURLs: Set<URL> = []

    init(mode: VideoConversionMode = .standard) {
        self.mode = mode
        defaultPreset = ConversionPreset.builtIns[0]
        ffmpegDependencyStatus = FFmpegLocator.dependencyStatus()
    }

    var isRecordingFix: Bool { mode == .recordingFix }
    var canStartConversion: Bool {
        hasRunnableItems && importingCount == 0 && isFFmpegAvailable && (isRecordingFix || outputDirectory != nil)
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

    var isFFmpegAvailable: Bool { ffmpegDependencyStatus.executableURL != nil }

    var ffmpegStatus: String {
        isFFmpegAvailable ? "FFmpeg Ready" : "FFmpeg Not Found"
    }

    func refreshFFmpegAvailability() {
        ffmpegDependencyStatus = FFmpegLocator.dependencyStatus()
    }

    func copyFFmpegInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("brew install ffmpeg", forType: .string)
    }

    var estimatedOutputSize: String? {
        guard !isRecordingFix else { return nil }
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
        panel.title = isRecordingFix ? "Choose QuickTime Recordings" : "Choose Videos to Convert"
        panel.allowedContentTypes = isRecordingFix ? [.quickTimeMovie] : [.movie, .video]
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
        for originalURL in urls {
            let url = originalURL.standardizedFileURL
            guard url.isFileURL else { continue }
            if isRecordingFix, url.pathExtension.lowercased() != "mov" {
                presentedError = "Recording Fix accepts MOV files only."
                continue
            }
            guard !items.contains(where: { $0.url == url }), !importingURLs.contains(url) else { continue }
            importingURLs.insert(url)
            importingCount += 1
            Task {
                defer {
                    importingURLs.remove(url)
                    importingCount -= 1
                }
                do {
                    guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
                        throw VideoToolError.noVideoTrack
                    }
                    let metadata = try await VideoMetadataLoader.load(from: url)
                    let item = VideoItem(url: url, metadata: metadata, preset: defaultPreset)
                    items.append(item)
                    selectedItemID = selectedItemID ?? item.id
                    if !isRecordingFix {
                        outputDirectory = outputDirectory ?? url.deletingLastPathComponent()
                    }
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
        guard !isConverting, hasRunnableItems, importingCount == 0 else { return }
        refreshFFmpegAvailability()
        guard isFFmpegAvailable else {
            presentedError = VideoToolError.ffmpegNotFound.localizedDescription
            return
        }
        guard isRecordingFix || outputDirectory != nil else {
            presentedError = VideoToolError.invalidOutputDirectory.localizedDescription
            return
        }

        isConverting = true
        let selectedOutputDirectory = outputDirectory
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
                let directory = selectedOutputDirectory ?? item.url.deletingLastPathComponent()
                let outputURL = uniqueOutputURL(for: item, in: directory, preset: preset)
                // Only publish a finished Recording Fix file, never a cancelled partial MOV.
                let workURL = isRecordingFix
                    ? directory.appendingPathComponent(".toolbox-recording-\(UUID().uuidString).mov")
                    : outputURL
                defer {
                    if isRecordingFix { try? FileManager.default.removeItem(at: workURL) }
                }
                items[itemIndex].status = .converting

                do {
                    let progress: @MainActor (ConversionProgress) -> Void = { update in
                        guard let currentIndex = self.index(for: itemID),
                              self.items[currentIndex].status == .converting else { return }
                        self.items[currentIndex].progress = update.fraction
                        self.items[currentIndex].elapsedTime = update.elapsedTime
                        self.items[currentIndex].processingFPS = update.framesPerSecond
                    }
                    if isRecordingFix {
                        try await engine.convertRecording(input: item.url, output: workURL,
                                                          duration: item.metadata.duration, progress: progress)
                        try Task.checkCancellation()
                        // moveItem refuses to overwrite if another process created this name meanwhile.
                        try FileManager.default.moveItem(at: workURL, to: outputURL)
                    } else {
                        try await engine.convert(input: item.url, output: workURL, preset: preset,
                                                 duration: item.metadata.duration, progress: progress)
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
        if let outputURL = item.outputURL { return outputURL.lastPathComponent }
        if isRecordingFix { return item.url.deletingPathExtension().lastPathComponent + "_60fps_h265.mov" }
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
        let fileName = isRecordingFix
            ? item.url.deletingPathExtension().lastPathComponent + "_60fps_h265"
            : generatedFileName(for: item, preset: preset)
        let fileExtension = isRecordingFix ? "mov" : preset.container.fileExtension
        var candidate = directory
            .appendingPathComponent(fileName)
            .appendingPathExtension(fileExtension)
        var counter = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(fileName)_\(counter)")
                .appendingPathExtension(fileExtension)
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
