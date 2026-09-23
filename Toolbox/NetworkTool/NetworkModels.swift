import Darwin
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
    /// Per-address IPv6 flags. Nil means the system query failed, so this address is not eligible for DDNS.
    let ipv6Flags: Int32?

    var id: String { "\(name)-\(family.rawValue)-\(address)" }

    var isTemporary: Bool {
        guard let ipv6Flags else { return false }
        return ipv6Flags & Int32(IN6_IFF_TEMPORARY) != 0
    }

    var isUsable: Bool {
        guard family == .ipv6, let ipv6Flags else { return false }
        let disallowed = Int32(IN6_IFF_TENTATIVE | IN6_IFF_DUPLICATED | IN6_IFF_DETACHED |
            IN6_IFF_DEPRECATED | IN6_IFF_TEMPORARY | IN6_IFF_OPTIMISTIC)
        return ipv6Flags & disallowed == 0
    }

    var isEligibleForDDNS: Bool {
        switch family {
        case .ipv4:
            var parsed = in_addr()
            guard inet_pton(AF_INET, address, &parsed) == 1 else { return false }
            let bytes = withUnsafeBytes(of: parsed) { Array($0) }
            let (a, b, c) = (bytes[0], bytes[1], bytes[2])
            return a != 0 && a != 10 && a != 127 && a < 224 &&
                !(a == 100 && (64...127).contains(b)) &&
                !(a == 169 && b == 254) &&
                !(a == 172 && (16...31).contains(b)) &&
                !(a == 192 && b == 0 && (c == 0 || c == 2)) &&
                !(a == 192 && b == 88 && c == 99) &&
                !(a == 192 && b == 168) &&
                !(a == 198 && (b == 18 || b == 19 || (b == 51 && c == 100))) &&
                !(a == 203 && b == 0 && c == 113)
        case .ipv6:
            guard isUsable else { return false }
            var parsed = in6_addr()
            guard inet_pton(AF_INET6, address, &parsed) == 1 else { return false }
            let bytes = withUnsafeBytes(of: parsed) { Array($0) }
            guard bytes.count == 16, bytes[0] & 0xe0 == 0x20 else { return false } // 2000::/3
            return !(bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0d && bytes[3] == 0xb8)
        }
    }
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
