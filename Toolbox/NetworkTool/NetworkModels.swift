import Foundation

enum NetworkAddressFamily: String, CaseIterable, Identifiable, Sendable {
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"

    var id: Self { self }
}

struct NetworkInterfaceAddress: Identifiable, Equatable, Sendable {
    let name: String
    let family: NetworkAddressFamily
    let address: String

    var id: String { "\(name)-\(family.rawValue)-\(address)" }
}

enum RemoteValueState: Equatable, Sendable {
    case idle
    case loading
    case loaded(String)
    case failed(String)
}

struct IPParseResult: Equatable, Sendable {
    let version: NetworkAddressFamily
    let normalizedAddress: String
    let prefixLength: Int
    let networkAddress: String
    let rangeStart: String
    let rangeEnd: String
    let totalAddresses: String
    let scope: String
}

enum NetworkToolError: LocalizedError, Equatable {
    case invalidHost
    case invalidAddress
    case invalidPrefix
    case commandUnavailable
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            "Enter a valid hostname or IP address."
        case .invalidAddress:
            "Enter a valid IPv4 or IPv6 address."
        case .invalidPrefix:
            "The CIDR prefix is outside the valid range for this address."
        case .commandUnavailable:
            "The system ping command is unavailable."
        case .requestFailed(let message):
            message
        }
    }
}
