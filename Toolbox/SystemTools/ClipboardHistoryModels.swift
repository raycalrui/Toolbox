import Foundation

struct ClipboardHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String?
    let imageFileName: String?
    let imageContentHash: String?
    let imageByteCount: Int?
    let imagePixelWidth: Int?
    let imagePixelHeight: Int?
    let createdAt: Date
    var isPinned: Bool

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, isPinned: Bool = false) {
        self.id = id
        self.text = text
        imageFileName = nil
        imageContentHash = nil
        imageByteCount = nil
        imagePixelWidth = nil
        imagePixelHeight = nil
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    init(
        id: UUID = UUID(),
        imageFileName: String,
        imageContentHash: String,
        imageByteCount: Int,
        imagePixelWidth: Int,
        imagePixelHeight: Int,
        createdAt: Date = .now,
        isPinned: Bool = false
    ) {
        self.id = id
        text = nil
        self.imageFileName = imageFileName
        self.imageContentHash = imageContentHash
        self.imageByteCount = imageByteCount
        self.imagePixelWidth = imagePixelWidth
        self.imagePixelHeight = imagePixelHeight
        self.createdAt = createdAt
        self.isPinned = isPinned
    }

    var isImage: Bool { imageFileName != nil }

    var searchableText: String {
        if let text { return text }
        return "Image \(imagePixelWidth ?? 0) × \(imagePixelHeight ?? 0)"
    }

    var imageMetadataText: String {
        let dimensions = "\(imagePixelWidth ?? 0) × \(imagePixelHeight ?? 0)"
        guard let imageByteCount else { return dimensions }
        return "\(dimensions) · \(ByteCountFormatter.string(fromByteCount: Int64(imageByteCount), countStyle: .file))"
    }
}

enum ClipboardRetention: String, Codable, CaseIterable, Identifiable {
    case oneDay
    case oneWeek
    case oneMonth
    case forever

    var id: Self { self }

    var title: String {
        switch self {
        case .oneDay: "1 Day"
        case .oneWeek: "1 Week"
        case .oneMonth: "1 Month"
        case .forever: "Forever"
        }
    }

    var cutoffDate: Date? {
        let calendar = Calendar.current
        switch self {
        case .oneDay:
            return calendar.date(byAdding: .day, value: -1, to: .now)
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: .now)
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: .now)
        case .forever:
            return nil
        }
    }
}
