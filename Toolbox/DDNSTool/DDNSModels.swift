import Foundation

enum DDNSAddressFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"

    var id: Self { self }
    var recordType: String { self == .ipv4 ? "A" : "AAAA" }
    var networkFamily: NetworkAddressFamily { self == .ipv4 ? .ipv4 : .ipv6 }
    var ipifyURL: URL {
        URL(string: self == .ipv4 ? "https://api.ipify.org" : "https://api6.ipify.org")!
    }
}

enum DDNSAddressSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case publicLookup
    case czlPublicLookup
    case networkInterface

    var id: Self { self }
    var label: String {
        switch self {
        case .publicLookup: "Detect public IP (ipify.org)"
        case .czlPublicLookup: "Detect public IP (ip.czl.net)"
        case .networkInterface: "Local network interface"
        }
    }

    func isAvailable(for family: DDNSAddressFamily) -> Bool {
        self != .czlPublicLookup || family == .ipv4
    }

    func lookupURL(for family: DDNSAddressFamily) -> URL? {
        switch self {
        case .publicLookup: family.ipifyURL
        case .czlPublicLookup: family == .ipv4 ? URL(string: "https://ip.czl.net/api/query") : nil
        case .networkInterface: nil
        }
    }
}

struct DDNSRecordConfiguration: Codable, Equatable, Sendable {
    var isEnabled = false
    var name = ""
    var recordID = ""
    var addressSource: DDNSAddressSource = .publicLookup
    var interfaceName = ""
    var preferredAddress = ""

    private enum CodingKeys: String, CodingKey {
        case isEnabled, name, recordID, addressSource, interfaceName, preferredAddress
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        name = try container.decode(String.self, forKey: .name)
        recordID = try container.decode(String.self, forKey: .recordID)
        addressSource = try container.decodeIfPresent(DDNSAddressSource.self, forKey: .addressSource) ?? .publicLookup
        interfaceName = try container.decodeIfPresent(String.self, forKey: .interfaceName) ?? ""
        preferredAddress = try container.decodeIfPresent(String.self, forKey: .preferredAddress) ?? ""
    }
}

struct DDNSConfiguration: Codable, Equatable, Sendable {
    var zoneID = ""
    var ipv4 = DDNSRecordConfiguration()
    var ipv6 = DDNSRecordConfiguration()
    var proxied = false

    func record(for family: DDNSAddressFamily) -> DDNSRecordConfiguration {
        family == .ipv4 ? ipv4 : ipv6
    }
}

enum DDNSUpdateInterval: Int, CaseIterable, Identifiable, Sendable {
    case manual = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case sixtyMinutes = 60

    var id: Int { rawValue }
    var label: String { rawValue == 0 ? "Manual only" : "Every \(rawValue) minutes" }
    var duration: Duration { .seconds(rawValue * 60) }
}

enum DDNSProtocolStatus: Equatable, Sendable {
    case idle
    case updating
    case success(address: String, date: Date)
    case failed(String)
}

enum DDNSError: LocalizedError, Sendable {
    case missingToken
    case missingZoneID
    case noRecordsEnabled
    case incompleteRecord(DDNSAddressFamily)
    case invalidPublicAddress(DDNSAddressFamily)
    case missingInterface(DDNSAddressFamily)
    case noEligibleInterfaceAddress(DDNSAddressFamily, String)
    case ambiguousInterfaceAddress(DDNSAddressFamily, String)
    case invalidResponse
    case requestFailed(String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingToken: "Save a Cloudflare API token first."
        case .missingZoneID: "Enter a Cloudflare Zone ID."
        case .noRecordsEnabled: "Enable at least one DNS record."
        case .incompleteRecord(let family): "Enter both the record name and Record ID for \(family.rawValue)."
        case .invalidPublicAddress(let family): "The address service returned an invalid \(family.rawValue) address."
        case .missingInterface(let family): "Select a network interface for \(family.rawValue)."
        case .noEligibleInterfaceAddress(let family, let name): "No usable public \(family.rawValue) address is available on \(name)."
        case .ambiguousInterfaceAddress(let family, let name): "Multiple public \(family.rawValue) addresses are available on \(name). Select one in the record settings."
        case .invalidResponse: "The server returned an invalid response."
        case .requestFailed(let message): message
        case .keychain(let status): "Keychain operation failed (\(status))."
        }
    }
}
