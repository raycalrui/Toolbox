import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SubtitleConverterView: View {
    @State private var source = ""
    @State private var result: SubtitleConversionResult?
    @State private var inputFile: SubtitleDecodedFile?
    @State private var sourceURL: URL?
    @State private var isBusy = false
    @State private var status = "Open or drop an SRT file to begin."
    @State private var errorMessage: String?
    @State private var operation: Task<Void, Never>?
    @State private var isDropTarget = false

    private var srtType: UTType { UTType(filenameExtension: "srt") ?? .plainText }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack {
                Label("Simplified Chinese → Traditional Chinese (Taiwan)", systemImage: "character.bubble")
                    .font(.headline)
                Spacer()
                Text("Offline · OpenCC dictionaries").foregroundStyle(.secondary)
            }
            .padding(16)
            Text("Converts characters and regional terms, such as 硬盘 → 硬碟 and 软件 → 軟體. Subtitle numbers, timestamps and formatting are preserved.")
                .font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.bottom, 12)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    preview("Original", text: source)
                        .frame(width: max(0, (geometry.size.width - 1) / 2))
                    Divider()
                    preview("Traditional Chinese (Taiwan)", text: result?.text ?? "")
                        .frame(width: max(0, (geometry.size.width - 1) / 2))
                }
            }
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor, lineWidth: 3)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard !isBusy else { return false }
            guard urls.count == 1, let url = urls.first else {
                errorMessage = "Drop one SRT file at a time."
                return false
            }
            importFile(url)
            return true
        } isTargeted: { isDropTarget = $0 }
        .alert("Subtitle Conversion Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onDisappear { operation?.cancel() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SRT Converter").font(.title2.bold())
                Text(sourceURL?.lastPathComponent ?? "Simplified to Taiwan Traditional")
                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            Button("Open SRT…", systemImage: "folder") { openFile() }
                .disabled(isBusy)
            Button("Clear", systemImage: "trash") {
                source = ""
                result = nil
                inputFile = nil
                sourceURL = nil
                status = "Open or drop an SRT file to begin."
            }
            .disabled(isBusy || source.isEmpty)
        }
        .padding(20)
    }

    private func preview(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            if text.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "captions.bubble").font(.largeTitle)
                    Text(title == "Original" ? "Drop an SRT file here" : "Converted subtitles appear here")
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SubtitleReadOnlyText(text: text)
                    .accessibilityLabel(title)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if isBusy { ProgressView().controlSize(.small) }
                Text(status).font(.callout).foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button("Copy Result", systemImage: "doc.on.doc") {
                    guard let result else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.text, forType: .string)
                }
                .disabled(result == nil || isBusy)
                Button("Save SRT…", systemImage: "square.and.arrow.down") { saveFile() }
                    .buttonStyle(.borderedProminent)
                    .disabled(result == nil || isBusy)
            }
            Text("Review regional wording before publishing. No subtitle data is uploaded or saved automatically.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.title = "Open SRT Subtitle"
        panel.allowedContentTypes = [srtType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(url)
    }

    private func importFile(_ url: URL) {
        guard url.isFileURL, url.pathExtension.lowercased() == "srt" else {
            errorMessage = "Choose a local .srt subtitle file."
            return
        }
        isBusy = true
        result = nil
        source = ""
        inputFile = nil
        sourceURL = nil
        status = "Converting subtitles…"
        operation = Task {
            defer { isBusy = false }
            do {
                let worker = Task.detached(priority: .userInitiated) {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    try Task.checkCancellation()
                    let decoded = try SubtitleFileCodec.read(url: url)
                    let result = try SubtitleConverter().convert(decoded.text)
                    return (decoded, result)
                }
                let converted = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                guard !Task.isCancelled else { return }
                inputFile = converted.0
                source = converted.0.text
                result = converted.1
                sourceURL = url
                status = "\(converted.1.cueCount) subtitles · \(converted.1.changedCueCount) changed · \(converted.0.encoding.displayName)"
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
                status = "Could not convert this file. Open another SRT to try again."
            }
        }
    }

    private func saveFile() {
        guard let result, let inputFile, let sourceURL else { return }
        let panel = NSSavePanel()
        panel.title = "Save Traditional Chinese Subtitle"
        panel.allowedContentTypes = [srtType]
        panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + "_zh-TW.srt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let sourceID = try? sourceURL.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        let targetID = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        let sameIdentity = sourceID != nil && targetID != nil && (sourceID as? NSObject)?.isEqual(targetID) == true
        guard !sameIdentity, url.resolvingSymlinksInPath().standardizedFileURL != sourceURL.resolvingSymlinksInPath().standardizedFileURL else {
            errorMessage = "Choose a different filename to preserve the original subtitle."
            return
        }
        do {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            try SubtitleFileCodec.encode(text: result.text, encoding: inputFile.encoding).write(to: url, options: .atomic)
            status = "Saved \(url.lastPathComponent)"
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct SubtitleReadOnlyText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        guard let editor = scroll.documentView as? NSTextView else { return scroll }
        editor.isEditable = false
        editor.isSelectable = true
        editor.drawsBackground = false
        editor.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        editor.textColor = .labelColor
        editor.textContainerInset = NSSize(width: 6, height: 8)
        editor.isHorizontallyResizable = false
        editor.textContainer?.widthTracksTextView = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? NSTextView, editor.string != text else { return }
        editor.string = text
        editor.scrollToBeginningOfDocument(nil)
    }
}

#Preview {
    SubtitleConverterView().frame(width: 1000, height: 700)
}
