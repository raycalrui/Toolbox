import SwiftUI

struct UUIDRandomGeneratorView: View {
    @State private var kind = GeneratorKind.uuid
    @State private var length = 24
    @State private var batchCount = 5
    @State private var groups: Set<CharacterGroup> = [.lowercase, .uppercase, .digits]
    @State private var values: [GeneratedValue] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Picker("Generator Type", selection: $kind) {
                ForEach(GeneratorKind.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            GroupBox("Options") {
                VStack(spacing: 14) {
                    if kind == .randomString {
                        NumericOptionRow(title: "Length", value: $length, range: 1...256, step: 1)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Characters")
                            CharacterGroupPicker(selection: $groups)
                        }
                    }

                    if kind == .randomString {
                        Divider()
                    }
                    NumericOptionRow(title: "Quantity", value: $batchCount, range: 1...100, step: 1)
                }
                .padding(10)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Generate", systemImage: "sparkles", action: generate)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(kind == .randomString && groups.isEmpty)
                Button("Clear") {
                    values = []
                    errorMessage = nil
                }
                .disabled(values.isEmpty)
            }

            GeneratedValuesView(values: values)
                .frame(maxHeight: .infinity)
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 560)
        .onChange(of: kind) { _, _ in
            values = []
            errorMessage = nil
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("UUID & Random String")
                .font(.title2.bold())
            Text("Generate values locally with cryptographically secure randomness.")
                .foregroundStyle(.secondary)
        }
    }

    private func generate() {
        do {
            let generated: [String]
            switch kind {
            case .uuid:
                generated = try (0..<batchCount).map { _ in
                    try SecureRandom.uuidV4().uuidString.lowercased()
                }
            case .randomString:
                let alphabet = groups.flatMap(\.characters)
                generated = try (0..<batchCount).map { _ in
                    try SecureRandom.string(length: length, alphabet: alphabet)
                }
            }
            values = generated.map { GeneratedValue(value: $0) }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    UUIDRandomGeneratorView()
}
