import Foundation

enum PasswordStrengthLevel: String {
    case veryWeak = "Very Weak"
    case weak = "Weak"
    case fair = "Fair"
    case strong = "Strong"
    case veryStrong = "Very Strong"

    var systemImage: String {
        switch self {
        case .veryWeak: "exclamationmark.shield.fill"
        case .weak: "shield.lefthalf.filled"
        case .fair: "shield"
        case .strong: "checkmark.shield"
        case .veryStrong: "checkmark.shield.fill"
        }
    }
}

struct PasswordAssessment {
    let level: PasswordStrengthLevel
    let score: Int
    let estimatedEntropy: Int
    let feedback: [String]
}

enum PasswordStrengthEvaluator {
    private static let commonPasswords = [
        "password", "password1", "123456", "12345678", "qwerty", "letmein",
        "admin", "welcome", "iloveyou", "abc123"
    ]

    static func evaluate(_ password: String) -> PasswordAssessment {
        guard !password.isEmpty else {
            return PasswordAssessment(
                level: .veryWeak,
                score: 0,
                estimatedEntropy: 0,
                feedback: ["Enter a password to check its strength."]
            )
        }

        let characters = Array(password)
        let length = characters.count
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigits = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbols = password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil

        var poolSize = 0
        if hasLowercase { poolSize += 26 }
        if hasUppercase { poolSize += 26 }
        if hasDigits { poolSize += 10 }
        if hasSymbols { poolSize += 32 }

        let rawEntropy = poolSize > 0 ? Double(length) * log2(Double(poolSize)) : 0
        var penalty = 0.0
        var feedback: [String] = []
        let normalized = password.lowercased()

        if commonPasswords.contains(normalized) {
            penalty += 60
            feedback.append("This is a commonly used password. Choose a unique one.")
        }
        if hasRepeatedRun(characters) {
            penalty += 12
            feedback.append("Avoid repeated characters or simple patterns.")
        }
        if hasSequence(normalized) {
            penalty += 14
            feedback.append("Avoid sequences such as 1234, abcd, or keyboard patterns.")
        }
        if length < 12 {
            feedback.append("Use at least 12 characters; 16 or more is better.")
        }

        let groupCount = [hasLowercase, hasUppercase, hasDigits, hasSymbols].filter { $0 }.count
        if groupCount < 3 {
            feedback.append("Mix uppercase, lowercase, numbers, and symbols.")
        }

        let entropy = max(0, Int((rawEntropy - penalty).rounded()))
        let score: Int
        switch entropy {
        case ..<28: score = 1
        case ..<45: score = 2
        case ..<65: score = 3
        case ..<90: score = 4
        default: score = 5
        }

        let level: PasswordStrengthLevel = switch score {
        case 1: .veryWeak
        case 2: .weak
        case 3: .fair
        case 4: .strong
        default: .veryStrong
        }

        if feedback.isEmpty {
            feedback.append("Good length and character variety.")
        }

        return PasswordAssessment(
            level: level,
            score: score,
            estimatedEntropy: entropy,
            feedback: feedback
        )
    }

    private static func hasRepeatedRun(_ characters: [Character]) -> Bool {
        guard characters.count >= 3 else { return false }
        return (2..<characters.count).contains { index in
            characters[index] == characters[index - 1]
                && characters[index - 1] == characters[index - 2]
        }
    }

    private static func hasSequence(_ password: String) -> Bool {
        let patterns = ["0123456789", "9876543210", "abcdefghijklmnopqrstuvwxyz", "qwertyuiop"]
        return patterns.contains { pattern in
            guard password.count >= 4 else { return false }
            return (0...(pattern.count - 4)).contains { offset in
                let start = pattern.index(pattern.startIndex, offsetBy: offset)
                let end = pattern.index(start, offsetBy: 4)
                return password.contains(pattern[start..<end])
            }
        }
    }
}
