import SwiftUI

struct PasswordToolsView: View {
    @State private var tool = PasswordToolKind.generator

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Password Tools")
                    .font(.title2.bold())
                Text("Generate and evaluate passwords entirely on this Mac.")
                    .foregroundStyle(.secondary)
            }

            Picker("Password Tool", selection: $tool) {
                ForEach(PasswordToolKind.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch tool {
                case .generator:
                    PasswordGeneratorPane()
                case .strength:
                    PasswordStrengthPane()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(24)
        .frame(minWidth: 620, minHeight: 560)
    }
}

private struct PasswordGeneratorPane: View {
    @State private var length = 20
    @State private var batchCount = 5
    @State private var groups: Set<CharacterGroup> = Set(CharacterGroup.allCases)
    @State private var excludesAmbiguous = true
    @State private var values: [GeneratedValue] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Options") {
                VStack(spacing: 14) {
                    NumericOptionRow(title: "Length", value: $length, range: 4...256, step: 1)
                    Divider()
                    NumericOptionRow(title: "Quantity", value: $batchCount, range: 1...100, step: 1)
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Characters")
                        CharacterGroupPicker(selection: $groups)
                    }
                    Divider()
                    Toggle("Exclude ambiguous characters (0, O, 1, I, l)", isOn: $excludesAmbiguous)
                }
                .padding(10)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Generate Passwords", systemImage: "key.fill", action: generate)
                    .buttonStyle(.borderedProminent)
                    .disabled(groups.isEmpty || length < groups.count)
                Button("Clear") {
                    values = []
                    errorMessage = nil
                }
                .disabled(values.isEmpty)
            }

            if length < groups.count {
                Text("Length must be at least the number of selected character groups.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            GeneratedValuesView(values: values)
                .frame(maxHeight: .infinity)
        }
    }

    private func generate() {
        do {
            values = try (0..<batchCount).map { _ in
                GeneratedValue(value: try SecurePasswordGenerator.generate(
                    length: length,
                    groups: groups,
                    excludingAmbiguous: excludesAmbiguous
                ))
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

private struct PasswordStrengthPane: View {
    @State private var password = ""
    @State private var revealsPassword = false

    private var assessment: PasswordAssessment {
        PasswordStrengthEvaluator.evaluate(password)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Password") {
                HStack {
                    Group {
                        if revealsPassword {
                            TextField("Enter a password", text: $password)
                        } else {
                            SecureField("Enter a password", text: $password)
                        }
                    }
                    .textFieldStyle(.roundedBorder)

                    Button(revealsPassword ? "Hide" : "Show", systemImage: revealsPassword ? "eye.slash" : "eye") {
                        revealsPassword.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .help(revealsPassword ? "Hide Password" : "Show Password")

                    Button("Clear", systemImage: "xmark.circle") {
                        password = ""
                    }
                    .labelStyle(.iconOnly)
                    .help("Clear")
                    .disabled(password.isEmpty)
                }
                .padding(10)
            }

            GroupBox("Assessment") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(assessment.level.rawValue, systemImage: assessment.level.systemImage)
                            .font(.headline)
                        Spacer()
                        Text("Estimated entropy: \(assessment.estimatedEntropy) bits")
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 5) {
                        ForEach(1...5, id: \.self) { index in
                            Capsule()
                                .fill(index <= assessment.score ? Color.accentColor : Color.secondary.opacity(0.2))
                                .frame(height: 7)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(assessment.feedback, id: \.self) { feedback in
                            Label(feedback, systemImage: "checkmark.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Label(
                "Your password is evaluated locally and is never saved or sent anywhere.",
                systemImage: "lock.shield"
            )
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PasswordToolsView()
}
