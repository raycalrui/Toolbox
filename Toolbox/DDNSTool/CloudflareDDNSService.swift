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
        let data: Data
        if source == .czlPublicLookup {
            data = try await Self.fetchIPv4OnlyResponse(from: url)
        } else {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let (responseData, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode) else {
                throw DDNSError.requestFailed("Could not fetch the current \(family.rawValue) address.")
            }
            data = responseData
        }
        let address: String
        switch source {
        case .publicLookup:
            address = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .czlPublicLookup:
            guard let result = try? JSONDecoder().decode(CZLAddressResponse.self, from: data) else {
                throw DDNSError.requestFailed("ip.czl.net returned an unexpected response format.")
            }
            guard result.code == 200 else {
                throw DDNSError.requestFailed("ip.czl.net reported an error (code \(result.code)).")
            }
            guard let responseAddress = result.data?.ip,
                  let version = result.data?.ipVersion else {
                throw DDNSError.requestFailed("ip.czl.net returned no IP address.")
            }
            guard version == "IPv4" else {
                throw DDNSError.requestFailed("ip.czl.net returned \(version) instead of IPv4. Check your proxy or VPN route.")
            }
            address = responseAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        case .networkInterface:
            throw DDNSError.invalidResponse
        }
        guard Self.isValid(address, family: family) else {
            throw DDNSError.invalidPublicAddress(family)
        }
        return address
    }

    private static func fetchIPv4OnlyResponse(from url: URL) async throws -> Data {
        try await Task.detached(priority: .utility) {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = [
                "--ipv4", "--fail", "--silent", "--show-error", "--max-time", "10",
                "--proto", "=https", url.absoluteString
            ]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
            } catch {
                throw DDNSError.requestFailed("Could not start the macOS IPv4 network request.")
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw DDNSError.requestFailed("Could not reach ip.czl.net over IPv4 (curl error \(process.terminationStatus)).")
            }
            return data
        }.value
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
    let data: AddressData?
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
