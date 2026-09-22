import AppKit
import Foundation

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

    private let pasteboard: NSPasteboard
    private let defaults: UserDefaults
    private var lastObservedChangeCount: Int
    private var monitoringTask: Task<Void, Never>?

    init(
        pasteboard: NSPasteboard = .general,
        defaults: UserDefaults = .standard
    ) {
        self.pasteboard = pasteboard
        self.defaults = defaults
        lastObservedChangeCount = pasteboard.changeCount

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
        pasteboard.setString(item.text, forType: .string)
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
        persist()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        persist()
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    private func pollPasteboard() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastObservedChangeCount else { return }
        lastObservedChangeCount = changeCount
        guard !isPaused, !containsSensitiveMarker else { return }
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
        if let cutoffDate = retention.cutoffDate {
            items.removeAll { !$0.isPinned && $0.createdAt < cutoffDate }
        }

        sortItems()
        let pinned = items.filter(\.isPinned)
        let availableRegularSlots = max(0, maximumItemCount - pinned.count)
        let regular = items.filter { !$0.isPinned }.prefix(availableRegularSlots)
        items = pinned + regular
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
}
