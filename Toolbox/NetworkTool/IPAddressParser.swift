import Darwin
import Foundation

enum IPAddressParser {
    static func parse(_ input: String) throws -> IPParseResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NetworkToolError.invalidAddress }

        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count <= 2, let addressPart = components.first, !addressPart.isEmpty else {
            throw NetworkToolError.invalidAddress
        }

        let address = String(addressPart)
        if let bytes = parseIPv4(address) {
            let prefix = try prefixLength(from: components, maximum: 32)
            return makeResult(bytes: bytes, version: .ipv4, prefix: prefix)
        }
        if let bytes = parseIPv6(address) {
            let prefix = try prefixLength(from: components, maximum: 128)
            return makeResult(bytes: bytes, version: .ipv6, prefix: prefix)
        }
        throw NetworkToolError.invalidAddress
    }

    static func isValidHost(_ input: String, family: NetworkAddressFamily) -> Bool {
        let host = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, host.count <= 253 else { return false }

        if let parsed = try? parse(host) {
            return parsed.version == family && !host.contains("/")
        }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }
        if host.allSatisfy({ $0.isNumber || $0 == "." }) { return false }
        return labels.allSatisfy { label in
            guard !label.isEmpty, label.count <= 63,
                  label.first != "-", label.last != "-" else { return false }
            return label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }

    private static func prefixLength(from components: [Substring], maximum: Int) throws -> Int {
        guard components.count == 2 else { return maximum }
        guard let prefix = Int(components[1]), (0...maximum).contains(prefix) else {
            throw NetworkToolError.invalidPrefix
        }
        return prefix
    }

    private static func parseIPv4(_ address: String) -> [UInt8]? {
        var value = in_addr()
        guard address.withCString({ inet_pton(AF_INET, $0, &value) }) == 1 else { return nil }
        return withUnsafeBytes(of: value) { Array($0) }
    }

    private static func parseIPv6(_ address: String) -> [UInt8]? {
        var value = in6_addr()
        guard address.withCString({ inet_pton(AF_INET6, $0, &value) }) == 1 else { return nil }
        return withUnsafeBytes(of: value) { Array($0) }
    }

    private static func makeResult(
        bytes: [UInt8],
        version: NetworkAddressFamily,
        prefix: Int
    ) -> IPParseResult {
        var network = bytes
        var end = bytes
        for index in bytes.indices {
            let bitsBeforeByte = index * 8
            let remaining = prefix - bitsBeforeByte
            let mask: UInt8
            if remaining >= 8 {
                mask = 0xff
            } else if remaining <= 0 {
                mask = 0
            } else {
                mask = UInt8(0xff << (8 - remaining))
            }
            network[index] &= mask
            end[index] = network[index] | ~mask
        }

        return IPParseResult(
            version: version,
            normalizedAddress: format(bytes, version: version),
            prefixLength: prefix,
            networkAddress: format(network, version: version),
            rangeStart: format(network, version: version),
            rangeEnd: format(end, version: version),
            totalAddresses: addressCount(version: version, prefix: prefix),
            scope: scope(of: bytes, version: version)
        )
    }

    private static func format(_ bytes: [UInt8], version: NetworkAddressFamily) -> String {
        var bytes = bytes
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        let family = version == .ipv4 ? AF_INET : AF_INET6
        return bytes.withUnsafeMutableBytes { pointer in
            guard inet_ntop(family, pointer.baseAddress, &buffer, socklen_t(buffer.count)) != nil else {
                return ""
            }
            let utf8 = buffer.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
            return String(decoding: utf8, as: UTF8.self)
        }
    }

    private static func addressCount(version: NetworkAddressFamily, prefix: Int) -> String {
        let hostBits = (version == .ipv4 ? 32 : 128) - prefix
        if hostBits < 64 {
            return NumberFormatter.localizedString(from: NSNumber(value: UInt64(1) << hostBits), number: .decimal)
        }
        if hostBits == 64 { return "18,446,744,073,709,551,616" }
        return "2^\(hostBits)"
    }

    private static func scope(of bytes: [UInt8], version: NetworkAddressFamily) -> String {
        if version == .ipv4 {
            if bytes == [0, 0, 0, 0] { return "Unspecified" }
            if bytes[0] == 127 { return "Loopback" }
            if bytes[0] == 10 || (bytes[0] == 172 && (16...31).contains(bytes[1])) || (bytes[0] == 192 && bytes[1] == 168) {
                return "Private"
            }
            if bytes[0] == 169 && bytes[1] == 254 { return "Link-local" }
            if (224...239).contains(bytes[0]) { return "Multicast" }
            if bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 2 ||
                bytes[0] == 198 && bytes[1] == 51 && bytes[2] == 100 ||
                bytes[0] == 203 && bytes[1] == 0 && bytes[2] == 113 {
                return "Documentation"
            }
            return "Global or special-use"
        }

        if bytes.allSatisfy({ $0 == 0 }) { return "Unspecified" }
        if bytes.dropLast().allSatisfy({ $0 == 0 }) && bytes.last == 1 { return "Loopback" }
        if bytes[0] == 0xff { return "Multicast" }
        if bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80 { return "Link-local" }
        if (bytes[0] & 0xfe) == 0xfc { return "Unique local" }
        if bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0d && bytes[3] == 0xb8 {
            return "Documentation"
        }
        return "Global or special-use"
    }
}
