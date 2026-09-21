import Foundation
import Security

enum SecureRandomError: LocalizedError {
    case generationFailed(OSStatus)
    case emptyAlphabet

    var errorDescription: String? {
        switch self {
        case let .generationFailed(status):
            "Secure random generation failed (\(status))."
        case .emptyAlphabet:
            "Select at least one character group."
        }
    }
}

enum SecureRandom {
    static func uuidV4() throws -> UUID {
        var bytes = try randomBytes(count: 16)
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    static func string(length: Int, alphabet: [Character]) throws -> String {
        guard !alphabet.isEmpty else { throw SecureRandomError.emptyAlphabet }
        return String(try (0..<max(length, 0)).map { _ in
            alphabet[try uniformIndex(upperBound: alphabet.count)]
        })
    }

    static func shuffled(_ characters: [Character]) throws -> [Character] {
        guard characters.count > 1 else { return characters }
        var result = characters
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            let destination = try uniformIndex(upperBound: index + 1)
            result.swapAt(index, destination)
        }
        return result
    }

    static func uniformIndex(upperBound: Int) throws -> Int {
        precondition(upperBound > 0)
        let bound = UInt64(upperBound)
        let acceptedRange = UInt64.max - UInt64.max % bound

        while true {
            let value = try randomUInt64()
            if value < acceptedRange {
                return Int(value % bound)
            }
        }
    }

    private static func randomUInt64() throws -> UInt64 {
        var value: UInt64 = 0
        let status = withUnsafeMutableBytes(of: &value) { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw SecureRandomError.generationFailed(status)
        }
        return value
    }

    private static func randomBytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw SecureRandomError.generationFailed(status)
        }
        return bytes
    }
}
