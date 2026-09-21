import Foundation

@MainActor
final class NetworkToolViewModel: ObservableObject {
    @Published private(set) var publicIPv4: RemoteValueState = .idle
    @Published private(set) var publicIPv6: RemoteValueState = .idle
    @Published private(set) var localAddresses: [NetworkInterfaceAddress] = []
    @Published private(set) var localAddressError: String?
    @Published var pingHost = ""
    @Published var pingFamily: NetworkAddressFamily = .ipv4
    @Published private(set) var isPinging = false
    @Published private(set) var pingOutput = ""
    @Published var parserInput = ""
    @Published private(set) var parserResult: IPParseResult?
    @Published private(set) var parserError: String?

    private let service: any NetworkServiceProtocol
    private var publicAddressTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?

    init(service: any NetworkServiceProtocol = NetworkService()) {
        self.service = service
    }

    deinit {
        publicAddressTask?.cancel()
        pingTask?.cancel()
    }

    func refreshAll() {
        refreshLocalAddresses()
        refreshPublicAddresses()
    }

    func refreshLocalAddresses() {
        do {
            localAddresses = try service.localInterfaceAddresses()
            localAddressError = nil
        } catch {
            localAddresses = []
            localAddressError = error.localizedDescription
        }
    }

    func refreshPublicAddresses() {
        publicAddressTask?.cancel()
        publicIPv4 = .loading
        publicIPv6 = .loading
        let service = service

        publicAddressTask = Task { [weak self] in
            async let ipv4 = Self.fetch(.ipv4, using: service)
            async let ipv6 = Self.fetch(.ipv6, using: service)
            let results = await (ipv4, ipv6)
            guard !Task.isCancelled, let self else { return }
            publicIPv4 = results.0
            publicIPv6 = results.1
        }
    }

    func startPing() {
        let host = pingHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard IPAddressParser.isValidHost(host, family: pingFamily) else {
            pingOutput = NetworkToolError.invalidHost.localizedDescription
            return
        }
        pingTask?.cancel()
        isPinging = true
        pingOutput = "Pinging \(host)…"
        let service = service
        let family = pingFamily

        pingTask = Task { [weak self] in
            do {
                let output = try await service.ping(host: host, family: family, count: 4)
                guard !Task.isCancelled else { return }
                self?.pingOutput = output
            } catch is CancellationError {
                guard let self else { return }
                pingOutput = "Ping cancelled."
            } catch {
                guard let self else { return }
                pingOutput = error.localizedDescription
            }
            self?.isPinging = false
        }
    }

    func cancelPing() {
        pingTask?.cancel()
    }

    func parseAddress() {
        do {
            parserResult = try IPAddressParser.parse(parserInput)
            parserError = nil
        } catch {
            parserResult = nil
            parserError = error.localizedDescription
        }
    }

    private nonisolated static func fetch(
        _ family: NetworkAddressFamily,
        using service: any NetworkServiceProtocol
    ) async -> RemoteValueState {
        do {
            return .loaded(try await service.fetchPublicAddress(for: family))
        } catch is CancellationError {
            return .idle
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
