import Foundation

struct DDNSAddressResolver: Sendable {
    let publicAddressService: any CloudflareDDNSServiceProtocol
    let networkService: any NetworkServiceProtocol

    func localAddresses() throws -> [NetworkInterfaceAddress] {
        try networkService.localInterfaceAddresses()
    }

    func resolve(
        for family: DDNSAddressFamily,
        record: DDNSRecordConfiguration
    ) async throws -> String {
        switch record.addressSource {
        case .publicLookup:
            return try await publicAddressService.fetchPublicAddress(for: family)
        case .networkInterface:
            let interfaceName = record.interfaceName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !interfaceName.isEmpty else { throw DDNSError.missingInterface(family) }
            let addresses = try localAddresses()
            let candidates = Self.candidates(in: addresses, for: family, interfaceName: interfaceName)
            guard !candidates.isEmpty else {
                throw DDNSError.noEligibleInterfaceAddress(family, interfaceName)
            }
            if candidates.count == 1 { return candidates[0].address }
            guard let preferred = candidates.first(where: { $0.address == record.preferredAddress }) else {
                throw DDNSError.ambiguousInterfaceAddress(family, interfaceName)
            }
            return preferred.address
        }
    }

    static func candidates(
        in addresses: [NetworkInterfaceAddress],
        for family: DDNSAddressFamily,
        interfaceName: String
    ) -> [NetworkInterfaceAddress] {
        addresses.filter {
            $0.name == interfaceName &&
            $0.family == family.networkFamily &&
            $0.isEligibleForDDNS
        }
        .sorted { $0.address < $1.address }
    }
}
