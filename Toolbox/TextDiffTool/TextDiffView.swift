import AppKit
import SwiftUI

struct TextDiffView: View {
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var granularity: TextDiffGranularity = .line
    @State private var presentation: TextDiffPresentation = .sideBySide
    @State private var fileError: FileImportError?

    private var rows: [TextDiffRow] {
        TextDiffEngine.compare(
            left: leftText,
            right: rightText,
            granularity: granularity
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            VSplitView {
                HSplitView {
                    TextDiffEditorPane(title: "Original", text: $leftText) { url in
                        importFile(url, into: $leftText)
                    }
                    .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)

                    TextDiffEditorPane(title: "Revised", text: $rightText) { url in
                        importFile(url, into: $rightText)
                    }
                    .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, minHeight: 180, idealHeight: 260, maxHeight: .infinity)

                TextDiffResultView(rows: rows, presentation: presentation)
                    .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Text Diff")
        .alert(item: $fileError) { error in
            Alert(
                title: Text("Could Not Open File"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var toolbar: some View {
        HStack(spacing: 16) {
            Text("Compare by")
                .fixedSize()
            Picker("Compare by", selection: $granularity) {
                ForEach(TextDiffGranularity.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 170)

            Text("View")
                .fixedSize()
            Picker("View", selection: $presentation) {
                ForEach(TextDiffPresentation.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)

            Spacer()

            Button("Clear", systemImage: "trash") {
                leftText = ""
                rightText = ""
            }
            .disabled(leftText.isEmpty && rightText.isEmpty)

            Button("Copy Result", systemImage: "doc.on.doc") {
                copyResult()
            }
            .disabled(rows.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func importFile(_ url: URL, into text: Binding<String>) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else {
                throw CocoaError(.fileReadUnsupportedScheme)
            }
            if let fileSize = values.fileSize, fileSize > 5_000_000 {
                throw FileImportError(message: "Choose a plain-text file smaller than 5 MB.")
            }
            text.wrappedValue = try String(contentsOf: url, encoding: .utf8)
        } catch let error as FileImportError {
            fileError = error
        } catch {
            fileError = FileImportError(
                message: "The file must be readable UTF-8 plain text. \(error.localizedDescription)"
            )
        }
    }

    private func copyResult() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(TextDiffEngine.copyableResult(from: rows), forType: .string)
    }
}

private struct FileImportError: Identifiable, Error {
    let id = UUID()
    let message: String
}

#Preview {
    TextDiffView()
        .frame(width: 1_100, height: 760)
}
