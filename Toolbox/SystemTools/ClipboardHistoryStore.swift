import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ClipboardHistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardHistoryItem] = []
    @Published var isPaused: Bool {
        didSet { defaults.set(isPaused, forKey: Keys.isPaused) }
    }
    @Published var maximumItemCount: Int {
        didSet {
            defaults.set(maximumItemCount, forKey: Keys.maximumItemCount)
            trimAndPersist()
        }
    }
    @Published var retention: ClipboardRetention {
        didSet {
            defaults.set(retention.rawValue, forKey: Keys.retention)
            trimAndPersist()
        }
    }

    private enum Keys {
        static let items = "clipboardHistory.items.v1"
        static let isPaused = "clipboardHistory.isPaused"
        static let maximumItemCount = "clipboardHistory.maximumItemCount"
        static let retention = "clipboardHistory.retention"
    }

    private static let concealedTypes = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    ]
    static let maximumImageByteCount = 20_000_000

    private let pasteboard: NSPasteboard
    private let defaults: UserDefaults
    private let imageDirectory: URL
    private var lastObservedChangeCount: Int
    private var monitoringTask: Task<Void, Never>?
    private var imageCache: [String: NSImage] = [:]

    init(
        pasteboard: NSPasteboard = .general,
        defaults: UserDefaults = .standard,
        storageDirectory: URL? = nil
    ) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        let baseDirectory = storageDirectory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Toolbox/ClipboardHistory", isDirectory: true)
        imageDirectory = baseDirectory.appendingPathComponent("Images", isDirectory: true)
        lastObservedChangeCount = pasteboard.changeCount

        try? FileManager.default.createDirectory(
            at: imageDirectory,
            withIntermediateDirectories: true
        )

        let savedMaximum = defaults.integer(forKey: Keys.maximumItemCount)
        maximumItemCount = savedMaximum > 0 ? savedMaximum : 100
        isPaused = defaults.bool(forKey: Keys.isPaused)
        retention = ClipboardRetention(
            rawValue: defaults.string(forKey: Keys.retention) ?? ""
        ) ?? .oneWeek

        if let data = defaults.data(forKey: Keys.items),
           let decoded = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) {
            items = decoded
        }
        removeMissingImageItems()
        trimAndPersist()
    }

    deinit {
        monitoringTask?.cancel()
    }

    var pinnedCount: Int {
        items.lazy.filter(\.isPinned).count
    }

    func startMonitoring() {
        guard monitoringTask == nil else { return }
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled, let self else { return }
                pollPasteboard()
            }
        }
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    func copy(_ item: ClipboardHistoryItem) {
        pasteboard.clearContents()
        if let text = item.text {
            pasteboard.setString(text, forType: .string)
        } else if let data = imageData(for: item), let image = NSImage(data: data) {
            pasteboard.writeObjects([image])
            pasteboard.setData(data, forType: .png)
        }
        lastObservedChangeCount = pasteboard.changeCount
    }

    func togglePinned(_ item: ClipboardHistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        sortItems()
        persist()
    }

    func delete(_ item: ClipboardHistoryItem) {
        items.removeAll { $0.id == item.id }
        removeImageFile(for: item)
        persist()
    }

    func clearUnpinned() {
        let removedItems = items.filter { !$0.isPinned }
        items.removeAll { !$0.isPinned }
        removeImageFiles(for: removedItems)
        persist()
    }

    func clearAll() {
        removeImageFiles(for: items)
        items.removeAll()
        persist()
    }

    func image(for item: ClipboardHistoryItem) -> NSImage? {
        guard let fileName = item.imageFileName else { return nil }
        if let cached = imageCache[fileName] { return cached }
        guard let image = NSImage(contentsOf: imageURL(fileName: fileName)) else { return nil }
        imageCache[fileName] = image
        return image
    }

    func captureCurrentClipboard() {
        pollPasteboard()
    }

    private func pollPasteboard() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastObservedChangeCount else { return }
        lastObservedChangeCount = changeCount
        guard !isPaused, !containsSensitiveMarker else { return }

        if let capturedImage = capturedImage() {
            addImage(capturedImage)
            return
        }

        guard let rawText = pasteboard.string(forType: .string) else { return }

        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if let existingIndex = items.firstIndex(where: { $0.text == text }) {
            let existing = items.remove(at: existingIndex)
            items.append(ClipboardHistoryItem(text: text, isPinned: existing.isPinned))
        } else {
            items.append(ClipboardHistoryItem(text: text))
        }
        trimAndPersist()
    }

    private var containsSensitiveMarker: Bool {
        let availableTypes = Set(pasteboard.types ?? [])
        return Self.concealedTypes.contains { availableTypes.contains($0) }
    }

    private func trimAndPersist() {
        let previousItems = items
        if let cutoffDate = retention.cutoffDate {
            items.removeAll { !$0.isPinned && $0.createdAt < cutoffDate }
        }

        sortItems()
        let pinned = items.filter(\.isPinned)
        let availableRegularSlots = max(0, maximumItemCount - pinned.count)
        let regular = items.filter { !$0.isPinned }.prefix(availableRegularSlots)
        items = pinned + regular
        let retainedIDs = Set(items.map(\.id))
        removeImageFiles(for: previousItems.filter { !retainedIDs.contains($0.id) })
        persist()
    }

    private func sortItems() {
        items.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.createdAt > $1.createdAt
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Keys.items)
        }
    }

    private struct CapturedImage {
        let pngData: Data
        let width: Int
        let height: Int
        let hash: String
    }

    private func capturedImage() -> CapturedImage? {
        let imageData: Data?
        if let pngData = pasteboard.data(forType: .png) {
            imageData = pngData
        } else if let tiffData = pasteboard.data(forType: .tiff) {
            imageData = tiffData
        } else if let jpegData = pasteboard.data(forType: NSPasteboard.PasteboardType(UTType.jpeg.identifier)) {
            imageData = jpegData
        } else {
            imageData = imageFileDataFromPasteboard()
        }

        guard let imageData,
              let bitmap = bitmapRepresentation(from: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]),
              pngData.count <= Self.maximumImageByteCount else { return nil }

        let hash = SHA256.hash(data: pngData).map { String(format: "%02x", $0) }.joined()
        return CapturedImage(
            pngData: pngData,
            width: bitmap.pixelsWide,
            height: bitmap.pixelsHigh,
            hash: hash
        )
    }

    private func imageFileDataFromPasteboard() -> Data? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              let imageURL = urls.first(where: { url in
                  (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.conforms(to: .image) == true
              }),
              let fileSize = try? imageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              fileSize <= Self.maximumImageByteCount * 5 else { return nil }
        return try? Data(contentsOf: imageURL, options: .mappedIfSafe)
    }

    private func bitmapRepresentation(from data: Data) -> NSBitmapImageRep? {
        if let bitmap = NSBitmapImageRep(data: data) {
            return bitmap
        }
        guard let image = NSImage(data: data),
              let tiffData = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: tiffData)
    }

    private func addImage(_ capturedImage: CapturedImage) {
        if let existingIndex = items.firstIndex(where: { $0.imageContentHash == capturedImage.hash }) {
            let existing = items.remove(at: existingIndex)
            removeImageFile(for: existing)
            saveImage(capturedImage, isPinned: existing.isPinned)
        } else {
            saveImage(capturedImage, isPinned: false)
        }
        trimAndPersist()
    }

    private func saveImage(_ capturedImage: CapturedImage, isPinned: Bool) {
        let id = UUID()
        let fileName = "\(id.uuidString).png"
        do {
            try capturedImage.pngData.write(to: imageURL(fileName: fileName), options: .atomic)
            items.append(ClipboardHistoryItem(
                id: id,
                imageFileName: fileName,
                imageContentHash: capturedImage.hash,
                imageByteCount: capturedImage.pngData.count,
                imagePixelWidth: capturedImage.width,
                imagePixelHeight: capturedImage.height,
                isPinned: isPinned
            ))
        } catch {
            return
        }
    }

    private func imageData(for item: ClipboardHistoryItem) -> Data? {
        guard let fileName = item.imageFileName else { return nil }
        return try? Data(contentsOf: imageURL(fileName: fileName), options: .mappedIfSafe)
    }

    private func imageURL(fileName: String) -> URL {
        imageDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    private func removeImageFile(for item: ClipboardHistoryItem) {
        guard let fileName = item.imageFileName else { return }
        imageCache[fileName] = nil
        try? FileManager.default.removeItem(at: imageURL(fileName: fileName))
    }

    private func removeImageFiles(for items: [ClipboardHistoryItem]) {
        items.forEach(removeImageFile(for:))
    }

    private func removeMissingImageItems() {
        items.removeAll { item in
            guard let fileName = item.imageFileName else { return false }
            return !FileManager.default.fileExists(atPath: imageURL(fileName: fileName).path)
        }
    }
}
