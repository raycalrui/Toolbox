import Foundation

enum DDNSAddressFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case ipv4 = "IPv4"
    case ipv6 = "IPv6"

    var id: Self { self }
    var recordType: String { self == .ipv4 ? "A" : "AAAA" }
    var ipifyURL: URL {
        URL(string: self == .ipv4 ? "https://api.ipify.org" : "https://api6.ipify.org")!
    }
}

struct DDNSRecordConfiguration: Codable, Equatable, Sendable {
    var isEnabled = false
    var name = ""
    var recordID = ""
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
    case invalidResponse
    case requestFailed(String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingToken: "Save a Cloudflare API token first."
        case .missingZoneID: "Enter a Cloudflare Zone ID."
        case .noRecordsEnabled: "Enable at least one DNS record."
        case .incompleteRecord(let family): "Enter both the record name and Record ID for \(family.rawValue)."
        case .invalidPublicAddress(let family): "ipify returned an invalid \(family.rawValue) address."
        case .invalidResponse: "The server returned an invalid response."
        case .requestFailed(let message): message
        case .keychain(let status): "Keychain operation failed (\(status))."
        }
    }
}
