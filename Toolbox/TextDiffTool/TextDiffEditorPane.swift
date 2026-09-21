import SwiftUI
import UniformTypeIdentifiers

struct TextDiffEditorPane: View {
    let title: String
    @Binding var text: String
    let onFileDrop: (URL) -> Void

    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(text.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)

                if text.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                        Text("Type or drop a text file here")
                    }
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.22),
                        lineWidth: isDropTargeted ? 2 : 1
                    )
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                onFileDrop(url)
                return true
            } isTargeted: { isTargeted in
                isDropTargeted = isTargeted
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
