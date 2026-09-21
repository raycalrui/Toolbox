import Foundation

enum TextDiffGranularity: String, CaseIterable, Identifiable {
    case line = "Line"
    case word = "Word"

    var id: Self { self }
}

enum TextDiffPresentation: String, CaseIterable, Identifiable {
    case sideBySide = "Side by Side"
    case unified = "Unified"

    var id: Self { self }
}

enum TextDiffKind: Equatable {
    case unchanged
    case addition
    case deletion
    case modification
}

struct TextDiffSegment: Identifiable {
    enum Emphasis {
        case normal
        case added
        case removed
    }

    let id = UUID()
    let text: String
    let emphasis: Emphasis
}

struct TextDiffRow: Identifiable {
    let id = UUID()
    let kind: TextDiffKind
    let leftLineNumber: Int?
    let rightLineNumber: Int?
    let leftSegments: [TextDiffSegment]
    let rightSegments: [TextDiffSegment]

    var leftText: String {
        leftSegments.map(\.text).joined()
    }

    var rightText: String {
        rightSegments.map(\.text).joined()
    }
}
