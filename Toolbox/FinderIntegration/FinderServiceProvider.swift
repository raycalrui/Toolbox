import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let finderPendingActionAdded = Notification.Name("finderPendingActionAdded")
}

@MainActor
final class FinderServiceProvider: NSObject {
    static let shared = FinderServiceProvider()

    private var isRegistered = false

    /// Call once during app launch (for example from an NSApplicationDelegate).
    func register() {
        guard !isRegistered else { return }
        NSApplication.shared.servicesProvider = self
        NSUpdateDynamicServices()
        isRegistered = true
    }

    @objc(compareTextInToolbox:userData:error:)
    func compareTextInToolbox(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = fileURLs(from: pasteboard).filter(isTextFile).prefix(2)
        enqueue(Array(urls), kind: .compareText, emptySelectionError: "Select one or two text files in Finder.", error: error)
    }

    @objc(convertVideoInToolbox:userData:error:)
    func convertVideoInToolbox(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        let urls = fileURLs(from: pasteboard).filter(isVideoFile)
        enqueue(urls, kind: .convertVideo, emptySelectionError: "Select one or more video files in Finder.", error: error)
    }

    private func enqueue(
        _ urls: [URL],
        kind: FinderActionKind,
        emptySelectionError: String,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard !urls.isEmpty else {
            error.pointee = emptySelectionError as NSString
            return
        }

        let action = FinderPendingAction(kind: kind, urls: urls)
        FinderActionInbox.shared.enqueue(action)
        NotificationCenter.default.post(name: .finderPendingActionAdded, object: action)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        return (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }

    private func isTextFile(_ url: URL) -> Bool {
        contentType(for: url)?.conforms(to: .text) == true
    }

    private func isVideoFile(_ url: URL) -> Bool {
        contentType(for: url)?.conforms(to: .movie) == true
            || contentType(for: url)?.conforms(to: .video) == true
    }

    private func contentType(for url: URL) -> UTType? {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type
        }
        return UTType(filenameExtension: url.pathExtension)
    }
}
