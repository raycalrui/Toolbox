import SwiftUI

struct PresetEditorView: View {
    @Binding var preset: ConversionPreset
    let presets: [ConversionPreset]
    let selectPreset: (ConversionPreset) -> Void
    let savePreset: () -> Void
    let updatePreset: () -> Void
    let deletePreset: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("导出设置")
                    .font(.title3.bold())

                InspectorSection("预设") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("预设", selection: presetSelection) {
                            ForEach(presets) { item in
                                Text(item.name).tag(item.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 8) {
                            Button("另存为", action: savePreset)
                            Button("更新", action: updatePreset)
                                .disabled(preset.isBuiltIn)
                            Spacer(minLength: 0)
                            Button("删除", role: .destructive, action: deletePreset)
                                .disabled(preset.isBuiltIn)
                        }
                    }
                }

                InspectorSection("视频") {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
                        SettingRow("容器") {
                            Picker("容器", selection: $preset.container) {
                                ForEach(OutputContainer.allCases) { container in
                                    Text(container.displayName).tag(container)
                                }
                            }
                            .labelsHidden()
                            .disabled(preset.videoCodec.requiredContainer != nil)
                        }

                        SettingDivider()

                        SettingRow("编码") {
                            Picker("编码", selection: $preset.videoCodec) {
                                ForEach(VideoCodec.allCases) { codec in
                                    Text(codec.displayName).tag(codec)
                                }
                            }
                            .labelsHidden()
                            .onChange(of: preset.videoCodec) { _, codec in
                                if let container = codec.requiredContainer {
                                    preset.container = container
                                    preset.audioCodec = .pcm
                                }
                            }
                        }

                        SettingDivider()

                        SettingRow("分辨率") {
                            DimensionsControl(width: $preset.width, height: $preset.height)
                        }

                        SettingDivider()

                        SettingRow("帧率") {
                            OptionalDoubleControl(value: $preset.frameRate, suffix: "fps", defaultValue: 30)
                        }

                        SettingDivider()

                        SettingRow("视频码率") {
                            if preset.videoCodec.supportsBitrate {
                                OptionalIntegerControl(value: $preset.videoBitrateMbps, suffix: "Mbps", defaultValue: 12)
                            } else {
                                Text("由 ProRes 决定")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }

                InspectorSection("音频") {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
                        SettingRow("编码") {
                            Picker("音频编码", selection: $preset.audioCodec) {
                                Text("AAC").tag(AudioCodec.aac)
                                if preset.container == .mov {
                                    Text("Linear PCM").tag(AudioCodec.pcm)
                                }
                            }
                            .labelsHidden()
                        }

                        if preset.audioCodec == .aac {
                            SettingDivider()
                            SettingRow("音频码率") {
                                HStack(spacing: 8) {
                                    Spacer(minLength: 0)
                                    Text("\(preset.audioBitrateKbps) Kbps")
                                        .monospacedDigit()
                                    Stepper("音频码率", value: $preset.audioBitrateKbps, in: 64...512, step: 32)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var presetSelection: Binding<UUID> {
        Binding(
            get: { preset.id },
            set: { id in
                if let selected = presets.first(where: { $0.id == id }) {
                    selectPreset(selected)
                }
            }
        )
    }
}

private struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct SettingRow<Control: View>: View {
    let label: String
    @ViewBuilder let control: Control

    init(_ label: String, @ViewBuilder control: () -> Control) {
        self.label = label
        self.control = control()
    }

    var body: some View {
        GridRow(alignment: .center) {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.leading)
            control
                .frame(maxWidth: .infinity, alignment: .trailing)
                .gridColumnAlignment(.trailing)
        }
    }
}

private struct SettingDivider: View {
    var body: some View {
        Divider().gridCellColumns(2)
    }
}

private struct DimensionsControl: View {
    @Binding var width: Int?
    @Binding var height: Int?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Toggle("保持原始", isOn: keepOriginal)
                .toggleStyle(.checkbox)

            if let currentWidth = width, let currentHeight = height {
                HStack(spacing: 5) {
                    CompactIntegerField(value: Binding(get: { currentWidth }, set: { width = max($0, 2) }))
                    Text("×").foregroundStyle(.secondary)
                    CompactIntegerField(value: Binding(get: { currentHeight }, set: { height = max($0, 2) }))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var keepOriginal: Binding<Bool> {
        Binding(
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
        )
    }
}

private struct OptionalDoubleControl: View {
    @Binding var value: Double?
    let suffix: String
    let defaultValue: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Toggle("保持原始", isOn: isAutomatic)
                .toggleStyle(.checkbox)
            if let currentValue = value {
                HStack(spacing: 6) {
                    TextField("数值", value: Binding(get: { currentValue }, set: { value = max($0, 1) }), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 68)
                    Text(suffix).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var isAutomatic: Binding<Bool> {
        Binding(get: { value == nil }, set: { value = $0 ? nil : defaultValue })
    }
}

private struct OptionalIntegerControl: View {
    @Binding var value: Int?
    let suffix: String
    let defaultValue: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Toggle("自动", isOn: isAutomatic)
                .toggleStyle(.checkbox)
            if let currentValue = value {
                HStack(spacing: 6) {
                    CompactIntegerField(value: Binding(get: { currentValue }, set: { value = max($0, 1) }))
                    Text(suffix).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var isAutomatic: Binding<Bool> {
        Binding(get: { value == nil }, set: { value = $0 ? nil : defaultValue })
    }
}

private struct CompactIntegerField: View {
    @Binding var value: Int

    var body: some View {
        TextField("数值", value: $value, format: .number)
            .multilineTextAlignment(.trailing)
            .frame(width: 68)
    }
}
