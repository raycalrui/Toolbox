import Foundation

@MainActor
final class CloudflareDDNSViewModel: ObservableObject {
    @Published var configuration: DDNSConfiguration {
        didSet { configurationStore.saveConfiguration(configuration) }
    }
    @Published var interval: DDNSUpdateInterval {
        didSet {
            configurationStore.saveInterval(interval)
            restartSchedule()
        }
    }
    @Published var tokenInput = ""
    @Published private(set) var hasSavedToken = false
    @Published private(set) var tokenMessage: String?
    @Published private(set) var ipv4Status: DDNSProtocolStatus = .idle
    @Published private(set) var ipv6Status: DDNSProtocolStatus = .idle
    @Published private(set) var isUpdating = false
    @Published private(set) var nextUpdateAt: Date?
    @Published private(set) var localAddresses: [NetworkInterfaceAddress] = []
    @Published private(set) var localAddressError: String?
    @Published private(set) var publicAddressPreviews: [DDNSAddressFamily: RemoteValueState] = [:]

    private let service: any CloudflareDDNSServiceProtocol
    private let networkService: any NetworkServiceProtocol
    private let keychain: DDNSKeychainStore
    private let configurationStore: DDNSConfigurationStore
    private var updateTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?
    private var previewTasks: [DDNSAddressFamily: Task<Void, Never>] = [:]

    init(
        service: any CloudflareDDNSServiceProtocol = CloudflareDDNSService(),
        networkService: any NetworkServiceProtocol = NetworkService(),
        keychain: DDNSKeychainStore = DDNSKeychainStore(),
        configurationStore: DDNSConfigurationStore = DDNSConfigurationStore()
    ) {
        self.service = service
        self.networkService = networkService
        self.keychain = keychain
        self.configurationStore = configurationStore
        configuration = configurationStore.loadConfiguration()
        interval = configurationStore.loadInterval()
        hasSavedToken = (try? keychain.loadToken()) != nil
    }

    deinit {
        updateTask?.cancel()
        scheduleTask?.cancel()
        previewTasks.values.forEach { $0.cancel() }
    }

    func start() {
        restartSchedule()
    }

    func stop() {
        updateTask?.cancel()
        scheduleTask?.cancel()
    }

    func saveToken() {
        let token = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            tokenMessage = "Enter an API token to save."
            return
        }
        do {
            try keychain.saveToken(token)
            tokenInput = ""
            hasSavedToken = true
            tokenMessage = "API token saved securely in Keychain."
        } catch {
            tokenMessage = error.localizedDescription
        }
    }

    func deleteToken() {
        do {
            try keychain.deleteToken()
            tokenInput = ""
            hasSavedToken = false
            tokenMessage = "Saved API token deleted."
        } catch {
            tokenMessage = error.localizedDescription
        }
    }

    func updateNow() {
        guard !isUpdating else { return }
        updateTask?.cancel()
        isUpdating = true
        tokenMessage = nil
        let service = service
        let resolver = DDNSAddressResolver(publicAddressService: service, networkService: networkService)
        let keychain = keychain
        let configuration = configuration

        updateTask = Task { [weak self] in
            guard let self else { return }
            do {
                let token = try keychain.loadToken()
                guard let token, !token.isEmpty else { throw DDNSError.missingToken }
                try Self.validate(configuration)

                async let ipv4Result = Self.update(
                    .ipv4, configuration: configuration, token: token, service: service, resolver: resolver
                )
                async let ipv6Result = Self.update(
                    .ipv6, configuration: configuration, token: token, service: service, resolver: resolver
                )
                if configuration.ipv4.isEnabled { ipv4Status = .updating }
                if configuration.ipv6.isEnabled { ipv6Status = .updating }
                let results = await (ipv4Result, ipv6Result)
                guard !Task.isCancelled else { return }
                ipv4Status = results.0
                ipv6Status = results.1
            } catch is CancellationError {
                return
            } catch {
                let message = error.localizedDescription
                if configuration.ipv4.isEnabled { ipv4Status = .failed(message) }
                if configuration.ipv6.isEnabled { ipv6Status = .failed(message) }
            }
            isUpdating = false
            scheduleNextDate()
        }
    }

    func refreshLocalInterfaces() {
        do {
            let resolver = DDNSAddressResolver(publicAddressService: service, networkService: networkService)
            localAddresses = try resolver.localAddresses()
            localAddressError = nil
        } catch {
            localAddresses = []
            localAddressError = error.localizedDescription
        }
    }

    func availableInterfaces(for family: DDNSAddressFamily) -> [String] {
        Array(Set(localAddresses.filter { $0.family == family.networkFamily }.map(\.name)))
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func eligibleAddresses(for family: DDNSAddressFamily) -> [NetworkInterfaceAddress] {
        let record = configuration.record(for: family)
        return DDNSAddressResolver.candidates(
            in: localAddresses,
            for: family,
            interfaceName: record.interfaceName
        )
    }

    func checkPublicAddress(for family: DDNSAddressFamily) {
        previewTasks[family]?.cancel()
        publicAddressPreviews[family] = .loading
        let service = service
        let source = configuration.record(for: family).addressSource
        previewTasks[family] = Task { [weak self] in
            let result: RemoteValueState
            do {
                result = .loaded(try await service.fetchPublicAddress(for: family, source: source))
            } catch is CancellationError {
                return
            } catch {
                result = .failed(error.localizedDescription)
            }
            guard !Task.isCancelled, let self else { return }
            publicAddressPreviews[family] = result
        }
    }

    func clearPublicAddressPreview(for family: DDNSAddressFamily) {
        previewTasks[family]?.cancel()
        previewTasks[family] = nil
        publicAddressPreviews[family] = .idle
    }

    private func restartSchedule() {
        scheduleTask?.cancel()
        nextUpdateAt = nil
        guard interval != .manual else { return }
        let duration = interval.duration
        nextUpdateAt = Date().addingTimeInterval(TimeInterval(interval.rawValue * 60))
        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: duration) } catch { return }
                guard let self, !Task.isCancelled else { return }
                updateNow()
                nextUpdateAt = Date().addingTimeInterval(TimeInterval(interval.rawValue * 60))
            }
        }
    }

    private func scheduleNextDate() {
        guard interval != .manual else { nextUpdateAt = nil; return }
        nextUpdateAt = Date().addingTimeInterval(TimeInterval(interval.rawValue * 60))
    }

    private nonisolated static func validate(_ configuration: DDNSConfiguration) throws {
        guard !configuration.zoneID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DDNSError.missingZoneID
        }
        guard configuration.ipv4.isEnabled || configuration.ipv6.isEnabled else {
            throw DDNSError.noRecordsEnabled
        }
        for family in DDNSAddressFamily.allCases where configuration.record(for: family).isEnabled {
            let record = configuration.record(for: family)
            guard !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !record.recordID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DDNSError.incompleteRecord(family)
            }
        }
    }

    private nonisolated static func update(
        _ family: DDNSAddressFamily,
        configuration: DDNSConfiguration,
        token: String,
        service: any CloudflareDDNSServiceProtocol,
        resolver: DDNSAddressResolver
    ) async -> DDNSProtocolStatus {
        let record = configuration.record(for: family)
        guard record.isEnabled else { return .idle }
        do {
            let address = try await resolver.resolve(for: family, record: record)
            try await service.updateRecord(
                zoneID: configuration.zoneID.trimmingCharacters(in: .whitespacesAndNewlines),
                recordID: record.recordID.trimmingCharacters(in: .whitespacesAndNewlines),
                name: record.name.trimmingCharacters(in: .whitespacesAndNewlines),
                address: address,
                family: family,
                proxied: configuration.proxied,
                token: token
            )
            return .success(address: address, date: Date())
        } catch is CancellationError {
            return .idle
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
