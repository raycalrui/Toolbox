import SwiftUI

struct PresetEditorView: View {
    @Binding var preset: ConversionPreset
    let presets: [ConversionPreset]
    let selectPreset: (ConversionPreset) -> Void
    let savePreset: () -> Void
    let updatePreset: () -> Void
    let deletePreset: () -> Void

    var body: some View {
        Form {
            Section("导出预设") {
                Picker("预设", selection: Binding(
                    get: { preset.id },
                    set: { id in
                        if let selected = presets.first(where: { $0.id == id }) {
                            selectPreset(selected)
                        }
                    }
                )) {
                    ForEach(presets) { item in
                        Text(item.name).tag(item.id)
                    }
                }

                HStack {
                    Button("另存为新预设", action: savePreset)
                    Button("更新预设", action: updatePreset)
                        .disabled(preset.isBuiltIn)
                    Button("删除预设", role: .destructive, action: deletePreset)
                        .disabled(preset.isBuiltIn)
                }
            }

            Section("视频") {
                Picker("容器", selection: $preset.container) {
                    ForEach(OutputContainer.allCases) { container in
                        Text(container.displayName).tag(container)
                    }
                }
                .disabled(preset.videoCodec.requiredContainer != nil)

                Picker("编码", selection: $preset.videoCodec) {
                    ForEach(VideoCodec.allCases) { codec in
                        Text(codec.displayName).tag(codec)
                    }
                }
                .onChange(of: preset.videoCodec) { _, codec in
                    if let container = codec.requiredContainer {
                        preset.container = container
                        preset.audioCodec = .pcm
                    }
                }

                OptionalDimensionsEditor(width: $preset.width, height: $preset.height)
                OptionalNumberField(label: "帧率", value: $preset.frameRate, suffix: "fps")

                if preset.videoCodec.supportsBitrate {
                    OptionalIntegerField(label: "视频码率", value: $preset.videoBitrateMbps, suffix: "Mbps")
                } else {
                    LabeledContent("视频码率", value: "由 ProRes Profile 决定")
                }
            }

            Section("音频") {
                Picker("编码", selection: $preset.audioCodec) {
                    Text("AAC").tag(AudioCodec.aac)
                    if preset.container == .mov {
                        Text("Linear PCM").tag(AudioCodec.pcm)
                    }
                }

                if preset.audioCodec == .aac {
                    Stepper(value: $preset.audioBitrateKbps, in: 64...512, step: 32) {
                        LabeledContent("音频码率", value: "\(preset.audioBitrateKbps) Kbps")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct OptionalDimensionsEditor: View {
    @Binding var width: Int?
    @Binding var height: Int?

    var body: some View {
        HStack {
            Text("分辨率")
            Spacer()
            Toggle("保持原始", isOn: Binding(
                get: { width == nil || height == nil },
                set: { keepOriginal in
                    if keepOriginal {
                        width = nil
                        height = nil
                    } else {
                        width = 1920
                        height = 1080
                    }
                }
            ))
            .toggleStyle(.checkbox)

            if let currentWidth = width, let currentHeight = height {
                TextField("宽", value: Binding(get: { currentWidth }, set: { width = $0 }), format: .number)
                    .frame(width: 64)
                Text("×")
                TextField("高", value: Binding(get: { currentHeight }, set: { height = $0 }), format: .number)
                    .frame(width: 64)
            }
        }
    }
}

private struct OptionalNumberField: View {
    let label: String
    @Binding var value: Double?
    let suffix: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("保持原始", isOn: Binding(
                get: { value == nil },
                set: { value = $0 ? nil : 30 }
            ))
            .toggleStyle(.checkbox)
            if let currentValue = value {
                TextField(label, value: Binding(get: { currentValue }, set: { value = $0 }), format: .number)
                    .frame(width: 64)
                Text(suffix)
            }
        }
    }
}

private struct OptionalIntegerField: View {
    let label: String
    @Binding var value: Int?
    let suffix: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle("自动", isOn: Binding(
                get: { value == nil },
                set: { value = $0 ? nil : 12 }
            ))
            .toggleStyle(.checkbox)
            if let currentValue = value {
                TextField(label, value: Binding(get: { currentValue }, set: { value = max($0, 1) }), format: .number)
                    .frame(width: 64)
                Text(suffix)
            }
        }
    }
}
