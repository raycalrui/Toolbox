import AppKit
import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var store: ClipboardHistoryStore
    @State private var searchText = ""
    @State private var showsSettings = false
    @State private var showsClearConfirmation = false

    private var filteredItems: [ClipboardHistoryItem] {
        guard !searchText.isEmpty else { return store.items }
        return store.items.filter { $0.searchableText.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.items.isEmpty {
                ContentUnavailableView(
                    "No Clipboard History",
                    systemImage: store.isPaused ? "pause.circle" : "clipboard",
                    description: Text(store.isPaused
                        ? "Recording is paused. Resume it to capture copied text and images."
                        : "Copy text or an image in another app and it will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredItems) { item in
                    ClipboardHistoryRow(
                        item: item,
                        image: store.image(for: item),
                        copyAction: { store.copy(item) },
                        pinAction: { store.togglePinned(item) },
                        deleteAction: { store.delete(item) }
                    )
                }
                .listStyle(.inset)
            }

            Divider()
            footer
        }
        .frame(minWidth: 700, minHeight: 560)
        .confirmationDialog(
            "Clear Clipboard History?",
            isPresented: $showsClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear Unpinned Items", role: .destructive) { store.clearUnpinned() }
            Button("Clear Everything", role: .destructive) { store.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Cleared items cannot be recovered.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clipboard History")
                        .font(.title2.bold())
                    Text("Text and images stay on this Mac and are never uploaded.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.isPaused {
                    Button("Resume", systemImage: "play.fill") {
                        store.isPaused = false
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Pause", systemImage: "pause.fill") {
                        store.isPaused = true
                    }
                    .buttonStyle(.bordered)
                }

                Button("Settings", systemImage: "gearshape") {
                    showsSettings.toggle()
                }
                .popover(isPresented: $showsSettings, arrowEdge: .bottom) {
                    ClipboardHistorySettingsView(store: store)
                }

                Button("Clear", systemImage: "trash") {
                    showsClearConfirmation = true
                }
                .disabled(store.items.isEmpty)
            }

            TextField("Search clipboard history", text: $searchText)
                .textFieldStyle(.roundedBorder)
        }
        .padding(24)
    }

    private var footer: some View {
        HStack {
            Label(
                store.isPaused ? "Recording paused" : "Recording clipboard history",
                systemImage: store.isPaused ? "pause.circle.fill" : "record.circle"
            )
            .foregroundStyle(store.isPaused ? .orange : .green)
            Spacer()
            Text("\(store.items.count) items · \(store.pinnedCount) pinned")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

private struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    let image: NSImage?
    let copyAction: () -> Void
    let pinAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isPinned ? "pin.fill" : item.isImage ? "photo" : "doc.on.clipboard")
                .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 5) {
                if item.isImage {
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 280, maxHeight: 180, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Label("Image unavailable", systemImage: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    }
                    Text(item.imageMetadataText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let text = item.text {
                    Text(text)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Copy", systemImage: "doc.on.doc", action: copyAction)
                .labelStyle(.iconOnly)
                .help("Copy")
            Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin", action: pinAction)
                .labelStyle(.iconOnly)
                .help(item.isPinned ? "Unpin" : "Pin")
            Button("Delete", systemImage: "trash", role: .destructive, action: deleteAction)
                .labelStyle(.iconOnly)
                .help("Delete")
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button("Copy", systemImage: "doc.on.doc", action: copyAction)
            Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin", action: pinAction)
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive, action: deleteAction)
        }
    }
}

private struct ClipboardHistorySettingsView: View {
    @ObservedObject var store: ClipboardHistoryStore

    var body: some View {
        Form {
            Picker("Maximum Items", selection: $store.maximumItemCount) {
                ForEach([25, 50, 100, 250], id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            Picker("Keep History", selection: $store.retention) {
                ForEach(ClipboardRetention.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            Text("Text and images stay on this Mac. Images larger than 20 MB are ignored. Pinned items are kept until you delete them. Password managers that mark copied data as concealed or transient are ignored.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding(.vertical, 8)
    }
}

#Preview {
    ClipboardHistoryView(store: ClipboardHistoryStore())
}
