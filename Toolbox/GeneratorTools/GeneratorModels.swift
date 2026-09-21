import Foundation

enum CharacterGroup: String, CaseIterable, Identifiable {
    case lowercase
    case uppercase
    case digits
    case symbols

    var id: Self { self }

    var title: String {
        switch self {
        case .lowercase: "Lowercase"
        case .uppercase: "Uppercase"
        case .digits: "Numbers"
        case .symbols: "Symbols"
        }
    }

    var characters: [Character] {
        switch self {
        case .lowercase: Array("abcdefghijklmnopqrstuvwxyz")
        case .uppercase: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        case .digits: Array("0123456789")
        case .symbols: Array("!@#$%^&*()-_=+[]{};:,.?")
        }
    }

    var ambiguousCharacters: Set<Character> {
        switch self {
        case .lowercase: Set("ilo")
        case .uppercase: Set("IO")
        case .digits: Set("01")
        case .symbols: []
        }
    }

    func characters(excludingAmbiguous: Bool) -> [Character] {
        guard excludingAmbiguous else { return characters }
        return characters.filter { !ambiguousCharacters.contains($0) }
    }
}

struct GeneratedValue: Identifiable, Equatable {
    let id = UUID()
    let value: String
}

enum GeneratorKind: String, CaseIterable, Identifiable {
    case uuid = "UUID v4"
    case randomString = "Random String"

    var id: Self { self }
}

enum PasswordToolKind: String, CaseIterable, Identifiable {
    case generator = "Generator"
    case strength = "Strength Check"

    var id: Self { self }
}

enum SecurePasswordGenerator {
    static func generate(
        length: Int,
        groups: Set<CharacterGroup>,
        excludingAmbiguous: Bool
    ) throws -> String {
        let selectedGroups = CharacterGroup.allCases.filter(groups.contains)
        let alphabets = selectedGroups.map {
            $0.characters(excludingAmbiguous: excludingAmbiguous)
        }
        let combinedAlphabet = alphabets.flatMap { $0 }
        guard !alphabets.isEmpty, length >= alphabets.count else {
            throw SecureRandomError.emptyAlphabet
        }

        var password = try alphabets.map { alphabet in
            alphabet[try SecureRandom.uniformIndex(upperBound: alphabet.count)]
        }
        password += Array(try SecureRandom.string(
            length: length - password.count,
            alphabet: combinedAlphabet
        ))
        return String(try SecureRandom.shuffled(password))
    }
}
