import SwiftUI

struct TextDiffResultView: View {
    let rows: [TextDiffRow]
    let presentation: TextDiffPresentation

    var body: some View {
        Group {
            if rows.isEmpty {
                ContentUnavailableView(
                    "Nothing to Compare",
                    systemImage: "arrow.left.arrow.right",
                    description: Text("Enter or drop text into either editor.")
                )
            } else {
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if presentation == .sideBySide {
                            ForEach(rows) { row in
                                sideBySideRow(row)
                            }
                        } else {
                            ForEach(rows) { row in
                                unifiedRows(row)
                            }
                        }
                    }
                    .frame(minWidth: 700, alignment: .leading)
                    .padding(.vertical, 6)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
    }

    private func sideBySideRow(_ row: TextDiffRow) -> some View {
        HStack(alignment: .top, spacing: 0) {
            diffCell(
                number: row.leftLineNumber,
                segments: row.leftSegments,
                kind: row.kind,
                side: .left
            )
            Divider()
            diffCell(
                number: row.rightLineNumber,
                segments: row.rightSegments,
                kind: row.kind,
                side: .right
            )
        }
    }

    @ViewBuilder
    private func unifiedRows(_ row: TextDiffRow) -> some View {
        switch row.kind {
        case .unchanged:
            unifiedCell(prefix: " ", segments: row.leftSegments, kind: .unchanged)
        case .deletion:
            unifiedCell(prefix: "−", segments: row.leftSegments, kind: .deletion)
        case .addition:
            unifiedCell(prefix: "+", segments: row.rightSegments, kind: .addition)
        case .modification:
            unifiedCell(prefix: "−", segments: row.leftSegments, kind: .deletion)
            unifiedCell(prefix: "+", segments: row.rightSegments, kind: .addition)
        }
    }

    private enum Side {
        case left
        case right
    }

    private func diffCell(
        number: Int?,
        segments: [TextDiffSegment],
        kind: TextDiffKind,
        side: Side
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number.map(String.init) ?? "")
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)
            segmentText(segments)
                .textSelection(.enabled)
            Spacer(minLength: 12)
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 27, alignment: .topLeading)
        .background(background(for: kind, side: side))
    }

    private func unifiedCell(
        prefix: String,
        segments: [TextDiffSegment],
        kind: TextDiffKind
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(prefix)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            segmentText(segments)
                .textSelection(.enabled)
            Spacer(minLength: 12)
        }
        .font(.system(.body, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 27, alignment: .topLeading)
        .background(background(for: kind, side: .left))
    }

    private func segmentText(_ segments: [TextDiffSegment]) -> Text {
        segments.reduce(Text("")) { result, segment in
            result + Text(segment.text)
                .foregroundColor(color(for: segment.emphasis))
        }
    }

    private func color(for emphasis: TextDiffSegment.Emphasis) -> Color {
        switch emphasis {
        case .normal: .primary
        case .added: .green
        case .removed: .red
        }
    }

    private func background(for kind: TextDiffKind, side: Side) -> Color {
        switch kind {
        case .unchanged:
            return .clear
        case .addition:
            return side == .right ? .green.opacity(0.12) : .clear
        case .deletion:
            return side == .left ? .red.opacity(0.12) : .clear
        case .modification:
            return .orange.opacity(0.11)
        }
    }
}
