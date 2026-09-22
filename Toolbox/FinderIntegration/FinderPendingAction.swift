import Foundation

enum FinderActionKind: String, Codable, Sendable {
    case compareText
    case convertVideo
}

struct FinderPendingAction: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: FinderActionKind
    let urls: [URL]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: FinderActionKind,
        urls: [URL],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.urls = urls
        self.createdAt = createdAt
    }
}
