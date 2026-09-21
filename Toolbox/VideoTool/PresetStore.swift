import Foundation

@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var customPresets: [ConversionPreset] = []

    private let defaultsKey = "video.custom-presets"

    var allPresets: [ConversionPreset] {
        ConversionPreset.builtIns + customPresets
    }

    init() {
        load()
    }

    func save(_ preset: ConversionPreset) {
        var preset = preset
        preset.isBuiltIn = false

        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
        } else {
            customPresets.append(preset)
        }
        persist()
    }

    func delete(_ preset: ConversionPreset) {
        guard !preset.isBuiltIn else { return }
        customPresets.removeAll { $0.id == preset.id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let presets = try? JSONDecoder().decode([ConversionPreset].self, from: data) else { return }
        customPresets = presets
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(customPresets) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
