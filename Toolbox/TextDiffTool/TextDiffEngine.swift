import Foundation

enum TextDiffEngine {
    private enum Operation {
        case equal(String)
        case insert(String)
        case remove(String)
    }

    static func compare(
        left: String,
        right: String,
        granularity: TextDiffGranularity
    ) -> [TextDiffRow] {
        switch granularity {
        case .line:
            return lineRows(left: left, right: right)
        case .word:
            return wordRows(left: left, right: right)
        }
    }

    static func copyableResult(from rows: [TextDiffRow]) -> String {
        rows.flatMap { row -> [String] in
            switch row.kind {
            case .unchanged:
                return ["  \(row.leftText)"]
            case .deletion:
                return ["- \(row.leftText)"]
            case .addition:
                return ["+ \(row.rightText)"]
            case .modification:
                return ["- \(row.leftText)", "+ \(row.rightText)"]
            }
        }
        .joined(separator: "\n")
    }

    private static func lineRows(left: String, right: String) -> [TextDiffRow] {
        let leftLines = lines(in: left)
        let rightLines = lines(in: right)
        let operations = diff(leftLines, rightLines)

        var rows: [TextDiffRow] = []
        var leftNumber = 1
        var rightNumber = 1
        var index = 0

        while index < operations.count {
            if case .equal(let text) = operations[index] {
                rows.append(
                    TextDiffRow(
                        kind: .unchanged,
                        leftLineNumber: leftNumber,
                        rightLineNumber: rightNumber,
                        leftSegments: [segment(text)],
                        rightSegments: [segment(text)]
                    )
                )
                leftNumber += 1
                rightNumber += 1
                index += 1
                continue
            }

            var removed: [String] = []
            var inserted: [String] = []
            while index < operations.count {
                switch operations[index] {
                case .remove(let text):
                    removed.append(text)
                case .insert(let text):
                    inserted.append(text)
                case .equal:
                    break
                }
                if case .equal = operations[index] { break }
                index += 1
            }

            let pairedCount = min(removed.count, inserted.count)
            for pairIndex in 0..<pairedCount {
                let segmentPair = changedWordSegments(
                    left: removed[pairIndex],
                    right: inserted[pairIndex]
                )
                rows.append(
                    TextDiffRow(
                        kind: .modification,
                        leftLineNumber: leftNumber,
                        rightLineNumber: rightNumber,
                        leftSegments: segmentPair.left,
                        rightSegments: segmentPair.right
                    )
                )
                leftNumber += 1
                rightNumber += 1
            }

            for text in removed.dropFirst(pairedCount) {
                rows.append(
                    TextDiffRow(
                        kind: .deletion,
                        leftLineNumber: leftNumber,
                        rightLineNumber: nil,
                        leftSegments: [segment(text, emphasis: .removed)],
                        rightSegments: []
                    )
                )
                leftNumber += 1
            }

            for text in inserted.dropFirst(pairedCount) {
                rows.append(
                    TextDiffRow(
                        kind: .addition,
                        leftLineNumber: nil,
                        rightLineNumber: rightNumber,
                        leftSegments: [],
                        rightSegments: [segment(text, emphasis: .added)]
                    )
                )
                rightNumber += 1
            }
        }

        return rows
    }

    private static func wordRows(left: String, right: String) -> [TextDiffRow] {
        guard !left.isEmpty || !right.isEmpty else { return [] }
        let operations = diff(tokens(in: left), tokens(in: right))
        var leftSegments: [TextDiffSegment] = []
        var rightSegments: [TextDiffSegment] = []
        var hasRemoval = false
        var hasInsertion = false

        for operation in operations {
            switch operation {
            case .equal(let text):
                leftSegments.append(segment(text))
                rightSegments.append(segment(text))
            case .remove(let text):
                hasRemoval = true
                leftSegments.append(segment(text, emphasis: .removed))
            case .insert(let text):
                hasInsertion = true
                rightSegments.append(segment(text, emphasis: .added))
            }
        }

        let kind: TextDiffKind
        if hasRemoval && hasInsertion {
            kind = .modification
        } else if hasRemoval {
            kind = .deletion
        } else if hasInsertion {
            kind = .addition
        } else {
            kind = .unchanged
        }

        return [
            TextDiffRow(
                kind: kind,
                leftLineNumber: left.isEmpty ? nil : 1,
                rightLineNumber: right.isEmpty ? nil : 1,
                leftSegments: leftSegments,
                rightSegments: rightSegments
            )
        ]
    }

    private static func changedWordSegments(
        left: String,
        right: String
    ) -> (left: [TextDiffSegment], right: [TextDiffSegment]) {
        let operations = diff(tokens(in: left), tokens(in: right))
        var leftSegments: [TextDiffSegment] = []
        var rightSegments: [TextDiffSegment] = []

        for operation in operations {
            switch operation {
            case .equal(let text):
                leftSegments.append(segment(text))
                rightSegments.append(segment(text))
            case .remove(let text):
                leftSegments.append(segment(text, emphasis: .removed))
            case .insert(let text):
                rightSegments.append(segment(text, emphasis: .added))
            }
        }

        return (leftSegments, rightSegments)
    }

    private static func lines(in text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        return text.components(separatedBy: .newlines)
    }

    private static func tokens(in text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let pattern = #"\s+|[\p{L}\p{N}_]+|[^\s\p{L}\p{N}_]"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    private static func diff(_ left: [String], _ right: [String]) -> [Operation] {
        let difference = right.difference(from: left)
        var removals: [Int: String] = [:]
        var insertions: [Int: String] = [:]
        for change in difference {
            switch change {
            case .remove(let offset, let element, _):
                removals[offset] = element
            case .insert(let offset, let element, _):
                insertions[offset] = element
            }
        }

        var operations: [Operation] = []
        var leftIndex = 0
        var rightIndex = 0
        while leftIndex < left.count || rightIndex < right.count {
            if let removed = removals[leftIndex] {
                operations.append(.remove(removed))
                leftIndex += 1
            } else if let inserted = insertions[rightIndex] {
                operations.append(.insert(inserted))
                rightIndex += 1
            } else if leftIndex < left.count, rightIndex < right.count {
                operations.append(.equal(left[leftIndex]))
                leftIndex += 1
                rightIndex += 1
            } else if leftIndex < left.count {
                operations.append(.remove(left[leftIndex]))
                leftIndex += 1
            } else if rightIndex < right.count {
                operations.append(.insert(right[rightIndex]))
                rightIndex += 1
            }
        }

        return operations
    }

    private static func segment(
        _ text: String,
        emphasis: TextDiffSegment.Emphasis = .normal
    ) -> TextDiffSegment {
        TextDiffSegment(text: text, emphasis: emphasis)
    }
}
