import Foundation

struct ClipboardHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date
    var isPinned: Bool

    init(id: UUID = UUID(), text: String, createdAt: Date = .now, isPinned: Bool = false) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
        self.isPinned = isPinned
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
