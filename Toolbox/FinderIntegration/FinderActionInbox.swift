import Combine
import Foundation

@MainActor
final class FinderActionInbox: ObservableObject {
    static let shared = FinderActionInbox()

    @Published private(set) var pendingActions: [FinderPendingAction]

    private let defaults: UserDefaults
    private let storageKey = "finder.pending-actions"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pendingActions = Self.restore(from: defaults, key: storageKey)
    }

    func enqueue(_ action: FinderPendingAction) {
        pendingActions.append(action)
        persist()
    }

    @discardableResult
    func consumeNext() -> FinderPendingAction? {
        guard !pendingActions.isEmpty else { return nil }
        let action = pendingActions.removeFirst()
        persist()
        return action
    }

    @discardableResult
    func consume(id: FinderPendingAction.ID) -> FinderPendingAction? {
        guard let index = pendingActions.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let action = pendingActions.remove(at: index)
        persist()
        return action
    }

    func removeAll() {
        pendingActions.removeAll()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(pendingActions) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func restore(from defaults: UserDefaults, key: String) -> [FinderPendingAction] {
        guard let data = defaults.data(forKey: key),
              let actions = try? JSONDecoder().decode([FinderPendingAction].self, from: data) else {
            return []
        }
        return actions
    }
}
