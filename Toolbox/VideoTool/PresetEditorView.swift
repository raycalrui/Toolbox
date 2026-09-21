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
                Text("Export Settings")
                    .font(.title3.bold())

                InspectorSection("Presets") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Preset", selection: presetSelection) {
                            ForEach(presets) { item in
                                Text(item.name).tag(item.id)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        HStack(spacing: 8) {
                            Button("Save As", action: savePreset)
                            Button("Update", action: updatePreset)
                                .disabled(preset.isBuiltIn)
                            Spacer(minLength: 0)
                            Button("Delete", role: .destructive, action: deletePreset)
                                .disabled(preset.isBuiltIn)
                        }
                    }
                }

                InspectorSection("Video") {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
                        SettingRow("Container") {
                            Picker("Container", selection: $preset.container) {
                                ForEach(OutputContainer.allCases) { container in
                                    Text(container.displayName).tag(container)
                                }
                            }
                            .labelsHidden()
                            .disabled(preset.videoCodec.requiredContainer != nil)
                        }

                        SettingDivider()

                        SettingRow("Codec") {
                            Picker("Codec", selection: $preset.videoCodec) {
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

                        SettingRow("Resolution") {
                            ResolutionControl(width: $preset.width, height: $preset.height)
                                .id(preset.id)
                        }

                        SettingDivider()

                        SettingRow("Frame Rate") {
                            FrameRateControl(value: $preset.frameRate)
                                .id(preset.id)
                        }

                        SettingDivider()

                        SettingRow("Video Bitrate") {
                            if preset.videoCodec.supportsBitrate {
                                OptionalIntegerControl(value: $preset.videoBitrateMbps, suffix: "Mbps", defaultValue: 12)
                            } else {
                                Text("Determined by ProRes")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }

                InspectorSection("Audio") {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
                        SettingRow("Codec") {
                            Picker("Audio Codec", selection: $preset.audioCodec) {
                                Text("AAC").tag(AudioCodec.aac)
                                if preset.container == .mov {
                                    Text("Linear PCM").tag(AudioCodec.pcm)
                                }
                            }
                            .labelsHidden()
                        }

                        if preset.audioCodec == .aac {
                            SettingDivider()
                            SettingRow("Audio Bitrate") {
                                HStack(spacing: 8) {
                                    Spacer(minLength: 0)
                                    Text("\(preset.audioBitrateKbps) Kbps")
                                        .monospacedDigit()
                                    Stepper("Audio Bitrate", value: $preset.audioBitrateKbps, in: 64...512, step: 32)
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

private struct ResolutionControl: View {
    @Binding var width: Int?
    @Binding var height: Int?
    @State private var keepsCustomEditorVisible = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Picker("Resolution", selection: selection) {
                ForEach(ResolutionOption.options) { option in
                    Text(option.label).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 190)

            if selectedOption == .custom,
               let currentWidth = width,
               let currentHeight = height {
                HStack(spacing: 5) {
                    CompactIntegerField(value: Binding(get: { currentWidth }, set: { width = max($0, 2) }))
                    Text("×").foregroundStyle(.secondary)
                    CompactIntegerField(value: Binding(get: { currentHeight }, set: { height = max($0, 2) }))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var selectedOption: ResolutionOption {
        if keepsCustomEditorVisible { return .custom }
        guard let width, let height else { return .original }
        return ResolutionOption.options.first {
            guard case let .size(optionWidth, optionHeight, _) = $0 else { return false }
            return optionWidth == width && optionHeight == height
        } ?? .custom
    }

    private var selection: Binding<ResolutionOption> {
        Binding(
            get: { selectedOption },
            set: { option in
                switch option {
                case .original:
                    keepsCustomEditorVisible = false
                    width = nil
                    height = nil
                case let .size(selectedWidth, selectedHeight, _):
                    keepsCustomEditorVisible = false
                    width = selectedWidth
                    height = selectedHeight
                case .custom:
                    keepsCustomEditorVisible = true
                    width = width ?? 1920
                    height = height ?? 1080
                }
            }
        )
    }
}

private enum ResolutionOption: Hashable, Identifiable {
    case original
    case size(Int, Int, String)
    case custom

    static let options: [ResolutionOption] = [
        .original,
        .size(1280, 720, "720p — 1280 × 720"),
        .size(1920, 1080, "1080p — 1920 × 1080"),
        .size(2560, 1440, "1440p — 2560 × 1440"),
        .size(3840, 2160, "4K UHD — 3840 × 2160"),
        .size(7680, 4320, "8K UHD — 7680 × 4320"),
        .custom
    ]

    var id: String { label }
    var label: String {
        switch self {
        case .original: "Keep Original"
        case let .size(_, _, label): label
        case .custom: "Custom…"
        }
    }

}

private struct FrameRateControl: View {
    @Binding var value: Double?
    @State private var keepsCustomEditorVisible = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Picker("Frame Rate", selection: selection) {
                ForEach(FrameRateOption.options) { option in
                    Text(option.label).tag(option)
                }
            }
            .labelsHidden()
            .frame(width: 190)

            if selectedOption == .custom, let currentValue = value {
                HStack(spacing: 6) {
                    TextField("Value", value: Binding(get: { currentValue }, set: { value = max($0, 1) }), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 68)
                    Text("fps").foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var selectedOption: FrameRateOption {
        if keepsCustomEditorVisible { return .custom }
        guard let value else { return .original }
        return FrameRateOption.options.first {
            guard let rate = $0.frameRate else { return false }
            return abs(rate - value) < 0.001
        } ?? .custom
    }

    private var selection: Binding<FrameRateOption> {
        Binding(
            get: { selectedOption },
            set: { option in
                switch option {
                case .original:
                    keepsCustomEditorVisible = false
                    value = nil
                case let .rate(rate, _):
                    keepsCustomEditorVisible = false
                    value = rate
                case .custom:
                    keepsCustomEditorVisible = true
                    value = value ?? 30
                }
            }
        )
    }
}

private enum FrameRateOption: Hashable, Identifiable {
    case original
    case rate(Double, String)
    case custom

    static let options: [FrameRateOption] = [
        .original,
        .rate(23.976, "23.976 fps"),
        .rate(24, "24 fps"),
        .rate(25, "25 fps"),
        .rate(29.97, "29.97 fps"),
        .rate(30, "30 fps"),
        .rate(50, "50 fps"),
        .rate(59.94, "59.94 fps"),
        .rate(60, "60 fps"),
        .rate(120, "120 fps"),
        .custom
    ]

    var id: String { label }
    var label: String {
        switch self {
        case .original: "Keep Original"
        case let .rate(_, label): label
        case .custom: "Custom…"
        }
    }

    var frameRate: Double? {
        guard case let .rate(rate, _) = self else { return nil }
        return rate
    }
}

private struct OptionalIntegerControl: View {
    @Binding var value: Int?
    let suffix: String
    let defaultValue: Int

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Toggle("Auto", isOn: isAutomatic)
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
        TextField("Value", value: $value, format: .number)
            .multilineTextAlignment(.trailing)
            .frame(width: 68)
    }
}
