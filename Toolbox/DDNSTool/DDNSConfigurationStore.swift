import Foundation

struct DDNSConfigurationStore {
    private let defaults: UserDefaults
    private let configurationKey = "cloudflareDDNS.configuration.v1"
    private let intervalKey = "cloudflareDDNS.intervalMinutes.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadConfiguration() -> DDNSConfiguration {
        guard let data = defaults.data(forKey: configurationKey),
              let configuration = try? JSONDecoder().decode(DDNSConfiguration.self, from: data) else {
            return DDNSConfiguration()
        }
        return configuration
    }

    func saveConfiguration(_ configuration: DDNSConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: configurationKey)
    }

    func loadInterval() -> DDNSUpdateInterval {
        DDNSUpdateInterval(rawValue: defaults.integer(forKey: intervalKey)) ?? .manual
    }

    func saveInterval(_ interval: DDNSUpdateInterval) {
        defaults.set(interval.rawValue, forKey: intervalKey)
    }
}
