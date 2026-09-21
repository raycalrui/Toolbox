import AppKit
import SwiftUI

enum ToolboxClipboard {
    static func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

struct CharacterGroupPicker: View {
    @Binding var selection: Set<CharacterGroup>

    var body: some View {
        HStack(spacing: 16) {
            ForEach(CharacterGroup.allCases) { group in
                Toggle(group.title, isOn: binding(for: group))
            }
        }
    }

    private func binding(for group: CharacterGroup) -> Binding<Bool> {
        Binding(
            get: { selection.contains(group) },
            set: { enabled in
                if enabled {
                    selection.insert(group)
                } else {
                    selection.remove(group)
                }
            }
        )
    }
}

struct GeneratedValuesView: View {
    let values: [GeneratedValue]

    var body: some View {
        GroupBox("Results") {
            if values.isEmpty {
                ContentUnavailableView(
                    "No Results Yet",
                    systemImage: "sparkles",
                    description: Text("Choose your options, then generate values.")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("\(values.count) generated")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Copy All", systemImage: "doc.on.doc") {
                            ToolboxClipboard.copy(values.map(\.value).joined(separator: "\n"))
                        }
                    }
                    .padding(.bottom, 8)

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(values) { item in
                                HStack(spacing: 12) {
                                    Text(item.value)
                                        .font(.system(.body, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Copy", systemImage: "doc.on.doc") {
                                        ToolboxClipboard.copy(item.value)
                                    }
                                    .labelStyle(.iconOnly)
                                    .help("Copy")
                                }
                                .padding(.vertical, 8)

                                if item.id != values.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(minHeight: 150)
                }
                .padding(10)
            }
        }
    }
}

struct NumericOptionRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Stepper(title, value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}
