import Darwin
import Foundation

protocol NetworkServiceProtocol: Sendable {
    func fetchPublicAddress(for family: NetworkAddressFamily) async throws -> String
    func localInterfaceAddresses() throws -> [NetworkInterfaceAddress]
    func ping(host: String, family: NetworkAddressFamily, count: Int) async throws -> String
}

struct NetworkService: NetworkServiceProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchPublicAddress(for family: NetworkAddressFamily) async throws -> String {
        let urlString = family == .ipv4 ? "https://api.ipify.org" : "https://api6.ipify.org"
        guard let url = URL(string: urlString) else { throw NetworkToolError.requestFailed("Invalid service URL.") }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkToolError.requestFailed("The public IP service returned an error.")
        }
        let value = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = try? IPAddressParser.parse(value), parsed.version == family else {
            throw NetworkToolError.requestFailed("The public IP service returned an invalid address.")
        }
        return parsed.normalizedAddress
    }

    func localInterfaceAddresses() throws -> [NetworkInterfaceAddress] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            throw NetworkToolError.requestFailed("Could not read local network interfaces.")
        }
        defer { freeifaddrs(pointer) }

        var values: [NetworkInterfaceAddress] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let item = cursor?.pointee {
            defer { cursor = item.ifa_next }
            guard let socketAddress = item.ifa_addr else { continue }
            let familyValue = Int32(socketAddress.pointee.sa_family)
            guard familyValue == AF_INET || familyValue == AF_INET6 else { continue }
            guard (item.ifa_flags & UInt32(IFF_UP)) != 0 else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length: socklen_t = familyValue == AF_INET
                ? socklen_t(MemoryLayout<sockaddr_in>.size)
                : socklen_t(MemoryLayout<sockaddr_in6>.size)
            guard getnameinfo(socketAddress, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
                continue
            }
            let utf8 = host.prefix { $0 != 0 }.map(UInt8.init(bitPattern:))
            let address = String(decoding: utf8, as: UTF8.self)
            let family: NetworkAddressFamily = familyValue == AF_INET ? .ipv4 : .ipv6
            var ipv6Flags: Int32?
            if familyValue == AF_INET6 {
                var queriedFlags: Int32 = 0
                let result = socketAddress.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
                    ToolboxIPv6AddressFlags(item.ifa_name, $0, &queriedFlags)
                }
                if result == 0 { ipv6Flags = queriedFlags }
            }
            values.append(NetworkInterfaceAddress(
                name: String(cString: item.ifa_name),
                family: family,
                address: address,
                ipv6Flags: ipv6Flags
            ))
        }
        return values.sorted {
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            if $0.family != $1.family { return $0.family == .ipv4 }
            return $0.address < $1.address
        }
    }

    func ping(host: String, family: NetworkAddressFamily, count: Int = 4) async throws -> String {
        guard IPAddressParser.isValidHost(host, family: family) else { throw NetworkToolError.invalidHost }
        let executable = family == .ipv4 ? "/sbin/ping" : "/sbin/ping6"
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw NetworkToolError.commandUnavailable
        }

        return try await PingProcess.run(
            executable: executable,
            arguments: ["-n", "-c", String(min(max(count, 1), 10)), host]
        )
    }
}

private enum PingProcess {
    private final class Storage: @unchecked Sendable {
        let lock = NSLock()
        var process: Process?
        var cancelled = false

        func set(_ process: Process?) {
            lock.lock()
            self.process = process
            lock.unlock()
        }

        func terminate() {
            lock.lock()
            cancelled = true
            let runningProcess = process
            lock.unlock()
            if runningProcess?.isRunning == true { runningProcess?.terminate() }
        }

        var wasCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }
    }

    static func run(executable: String, arguments: [String]) async throws -> String {
        let storage = Storage()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                let process = Process()
                let output = Pipe()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = output
                process.standardError = output
                storage.set(process)

                guard !storage.wasCancelled else {
                    storage.set(nil)
                    continuation.resume(throwing: CancellationError())
                    return
                }

                process.terminationHandler = { process in
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    let text = String(decoding: data, as: UTF8.self)
                    storage.set(nil)
                    if storage.wasCancelled {
                        continuation.resume(throwing: CancellationError())
                    } else if process.terminationStatus == 0 {
                        continuation.resume(returning: text)
                    } else {
                        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        continuation.resume(throwing: NetworkToolError.requestFailed(
                            message.isEmpty ? "Ping failed." : message
                        ))
                    }
                }

                do {
                    try process.run()
                } catch {
                    storage.set(nil)
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            storage.terminate()
        }
    }
}
