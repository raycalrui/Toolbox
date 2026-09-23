import Darwin
import Foundation

protocol CloudflareDDNSServiceProtocol: Sendable {
    func fetchPublicAddress(for family: DDNSAddressFamily, source: DDNSAddressSource) async throws -> String
    func updateRecord(
        zoneID: String,
        recordID: String,
        name: String,
        address: String,
        family: DDNSAddressFamily,
        proxied: Bool,
        token: String
    ) async throws
}

struct CloudflareDDNSService: CloudflareDDNSServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchPublicAddress(for family: DDNSAddressFamily, source: DDNSAddressSource) async throws -> String {
        guard let url = source.lookupURL(for: family) else { throw DDNSError.invalidResponse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            throw DDNSError.requestFailed("Could not fetch the current \(family.rawValue) address.")
        }
        let address: String
        switch source {
        case .publicLookup:
            address = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .czlPublicLookup:
            guard let result = try? JSONDecoder().decode(CZLAddressResponse.self, from: data),
                  result.code == 200,
                  result.data.ipVersion == "IPv4" else {
                throw DDNSError.requestFailed("ip.czl.net did not return a valid IPv4 response.")
            }
            address = result.data.ip.trimmingCharacters(in: .whitespacesAndNewlines)
        case .networkInterface:
            throw DDNSError.invalidResponse
        }
        guard Self.isValid(address, family: family) else {
            throw DDNSError.invalidPublicAddress(family)
        }
        return address
    }

    func updateRecord(
        zoneID: String,
        recordID: String,
        name: String,
        address: String,
        family: DDNSAddressFamily,
        proxied: Bool,
        token: String
    ) async throws {
        let escapedZone = zoneID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let escapedRecord = recordID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        guard !escapedZone.isEmpty, !escapedRecord.isEmpty,
              let url = URL(string: "https://api.cloudflare.com/client/v4/zones/\(escapedZone)/dns_records/\(escapedRecord)") else {
            throw DDNSError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(UpdateRequest(
            type: family.recordType,
            name: name,
            content: address,
            ttl: 1,
            proxied: proxied
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw DDNSError.invalidResponse }
        let envelope = try? JSONDecoder().decode(CloudflareEnvelope.self, from: data)
        guard (200...299).contains(httpResponse.statusCode), envelope?.success == true else {
            let message = envelope?.errors
                .map(\.message)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            throw DDNSError.requestFailed(
                message?.isEmpty == false ? message! : "Cloudflare rejected the update (HTTP \(httpResponse.statusCode))."
            )
        }
    }

    private static func isValid(_ address: String, family: DDNSAddressFamily) -> Bool {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        return address.withCString { pointer in
            family == .ipv4
                ? inet_pton(AF_INET, pointer, &ipv4) == 1
                : inet_pton(AF_INET6, pointer, &ipv6) == 1
        }
    }
}

private struct CZLAddressResponse: Decodable {
    struct AddressData: Decodable {
        let ip: String
        let ipVersion: String
    }

    let code: Int
    let data: AddressData
}

private struct UpdateRequest: Encodable {
    let type: String
    let name: String
    let content: String
    let ttl: Int
    let proxied: Bool
}

private struct CloudflareEnvelope: Decodable {
    struct APIError: Decodable { let message: String }
    let success: Bool
    let errors: [APIError]
}
