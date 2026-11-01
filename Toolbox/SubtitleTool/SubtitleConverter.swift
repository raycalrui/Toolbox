import Foundation

enum SubtitleError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct SubtitleConversionResult: Sendable {
    let text: String
    let cueCount: Int
    let changedCueCount: Int
}

enum SubtitleEncoding: String, Sendable, CaseIterable {
    case utf8, utf8BOM, utf16LE, utf16BE
    var displayName: String {
        switch self {
        case .utf8: "UTF-8"
        case .utf8BOM: "UTF-8 with BOM"
        case .utf16LE: "UTF-16 LE with BOM"
        case .utf16BE: "UTF-16 BE with BOM"
        }
    }
}

struct SubtitleDecodedFile: Sendable {
    let text: String
    let encoding: SubtitleEncoding
}

enum SubtitleFileCodec {
    static let maximumBytes = 5 * 1024 * 1024

    static func read(url: URL) throws -> SubtitleDecodedFile {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw SubtitleError.message("Choose a regular SRT file.") }
        guard (values.fileSize ?? maximumBytes + 1) <= maximumBytes else {
            throw SubtitleError.message("SRT files must be 5 MB or smaller.")
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> SubtitleDecodedFile {
        guard data.count <= maximumBytes else { throw SubtitleError.message("SRT files must be 5 MB or smaller.") }
        let encoding: SubtitleEncoding
        let body: Data
        let foundationEncoding: String.Encoding
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            encoding = .utf8BOM; body = data.dropFirst(3); foundationEncoding = .utf8
        } else if data.starts(with: [0xFF, 0xFE]) {
            encoding = .utf16LE; body = data.dropFirst(2); foundationEncoding = .utf16LittleEndian
        } else if data.starts(with: [0xFE, 0xFF]) {
            encoding = .utf16BE; body = data.dropFirst(2); foundationEncoding = .utf16BigEndian
        } else {
            encoding = .utf8; body = data; foundationEncoding = .utf8
        }
        if encoding == .utf16LE || encoding == .utf16BE {
            let bytes = Array(body)
            guard bytes.count.isMultiple(of: 2) else { throw SubtitleError.message("Invalid UTF-16 data: incomplete code unit.") }
            var pendingHighSurrogate = false
            for index in stride(from: 0, to: bytes.count, by: 2) {
                let value = encoding == .utf16LE
                    ? UInt16(bytes[index]) | UInt16(bytes[index + 1]) << 8
                    : UInt16(bytes[index]) << 8 | UInt16(bytes[index + 1])
                if pendingHighSurrogate {
                    guard (0xDC00...0xDFFF).contains(value) else { throw SubtitleError.message("Invalid UTF-16 surrogate pair.") }
                    pendingHighSurrogate = false
                } else if (0xD800...0xDBFF).contains(value) { pendingHighSurrogate = true }
                else if (0xDC00...0xDFFF).contains(value) { throw SubtitleError.message("Invalid UTF-16 surrogate pair.") }
            }
            guard !pendingHighSurrogate else { throw SubtitleError.message("Invalid UTF-16 surrogate pair.") }
        }
        guard let text = String(data: body, encoding: foundationEncoding), !text.contains("\0") else {
            throw SubtitleError.message("Unsupported text encoding. Use UTF-8 or UTF-16 with a byte-order mark.")
        }
        return SubtitleDecodedFile(text: text, encoding: encoding)
    }

    static func encode(text: String, encoding: SubtitleEncoding) throws -> Data {
        let format: String.Encoding
        let prefix: [UInt8]
        switch encoding {
        case .utf8: format = .utf8; prefix = []
        case .utf8BOM: format = .utf8; prefix = [0xEF, 0xBB, 0xBF]
        case .utf16LE: format = .utf16LittleEndian; prefix = [0xFF, 0xFE]
        case .utf16BE: format = .utf16BigEndian; prefix = [0xFE, 0xFF]
        }
        guard let data = text.data(using: format) else { throw SubtitleError.message("Could not encode the subtitle file.") }
        return Data(prefix) + data
    }
}

/// Offline forward longest-match conversion using OpenCC 1.1.9 dictionaries.
/// Uses the s2twp dictionary stages, not the OpenCC C++ segmentation runtime.
struct SubtitleConverter: Sendable {
    private let stages: [PhraseDictionary]

    init(resourceDirectory: URL? = nil) throws {
        func load(_ name: String) throws -> String {
            try Task.checkCancellation()
            let url = resourceDirectory?.appendingPathComponent(name + ".txt")
                ?? Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "OpenCC")
                ?? Bundle.main.url(forResource: name, withExtension: "txt")
            guard let url else { throw SubtitleError.message("Missing offline conversion dictionary: \(name).") }
            return try String(contentsOf: url, encoding: .utf8)
        }
        stages = [
            PhraseDictionary(try [load("STPhrases"), load("STCharacters")]),
            PhraseDictionary(try [load("TWPhrasesIT"), load("TWPhrasesName"), load("TWPhrasesOther")]),
            PhraseDictionary(try [load("TWVariants")])
        ]
    }

    func convert(_ source: String) throws -> SubtitleConversionResult {
        guard source.utf8.count <= SubtitleFileCodec.maximumBytes else {
            throw SubtitleError.message("Subtitle text must be 5 MB or smaller.")
        }
        let hasBOM = source.hasPrefix("\u{FEFF}")
        let input = hasBOM ? String(source.dropFirst()) : source
        // Split on scalars so CRLF (a single Swift Character) remains exactly intact.
        let scalars = Array(input.unicodeScalars)
        var lines: [(text: String, ending: String)] = []
        var start = 0
        var index = 0
        while index < scalars.count {
            if scalars[index] == "\r" || scalars[index] == "\n" {
                let content = String(String.UnicodeScalarView(scalars[start..<index]))
                let endingStart = index
                if scalars[index] == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" { index += 1 }
                index += 1
                lines.append((content, String(String.UnicodeScalarView(scalars[endingStart..<index]))))
                start = index
            } else { index += 1 }
        }
        if start < scalars.count { lines.append((String(String.UnicodeScalarView(scalars[start...])), "")) }
        var cursor = 0
        var cues = 0
        var changed = 0
        while cursor < lines.count {
            try Task.checkCancellation()
            if lines[cursor].text.trimmingCharacters(in: .whitespaces).isEmpty { cursor += 1; continue }
            let cueLine = cursor + 1
            let number = lines[cursor].text.trimmingCharacters(in: .whitespaces)
            guard !number.isEmpty, number.utf8.allSatisfy({ (48...57).contains($0) }), Int(number) != nil else {
                throw SubtitleError.message("Invalid SRT cue number at line \(cueLine).")
            }
            cursor += 1
            guard cursor < lines.count, Self.validTiming(lines[cursor].text) else {
                throw SubtitleError.message("Invalid SRT timestamp at line \(cursor + 1). Expected HH:MM:SS,mmm --> HH:MM:SS,mmm.")
            }
            cursor += 1
            let textStart = cursor
            var cueChanged = false
            while cursor < lines.count, !lines[cursor].text.trimmingCharacters(in: .whitespaces).isEmpty {
                try Task.checkCancellation()
                if Self.validTiming(lines[cursor].text) {
                    throw SubtitleError.message("Missing blank line between SRT cues near line \(cursor + 1).")
                }
                let original = lines[cursor].text
                let converted = convertVisibleText(original)
                lines[cursor].text = converted
                cueChanged = cueChanged || original != converted
                cursor += 1
            }
            guard cursor > textStart else { throw SubtitleError.message("SRT cue at line \(cueLine) has no subtitle text.") }
            cues += 1
            if cueChanged { changed += 1 }
        }
        guard cues > 0 else { throw SubtitleError.message("No valid SRT cues found. Import an SRT file with numbered cues and timestamps.") }
        return SubtitleConversionResult(text: (hasBOM ? "\u{FEFF}" : "") + lines.map { $0.text + $0.ending }.joined(), cueCount: cues, changedCueCount: changed)
    }

    private static func validTiming(_ text: String) -> Bool {
        let pattern = #"^\s*(\d{2,}):([0-5]\d):([0-5]\d),(\d{3})[ \t]+-->[ \t]+(\d{2,}):([0-5]\d):([0-5]\d),(\d{3})(?:[ \t]+.*)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return false }
        let values = (1...8).compactMap { Range(match.range(at: $0), in: text).flatMap { Int64(text[$0]) } }
        guard values.count == 8, values[0] < 1_000_000, values[4] < 1_000_000 else { return false }
        func time(_ offset: Int) -> Int64 { ((values[offset] * 60 + values[offset + 1]) * 60 + values[offset + 2]) * 1000 + values[offset + 3] }
        return time(4) >= time(0)
    }

    private func convertVisibleText(_ line: String) -> String {
        // Keep tags/attributes, ASS override blocks and HTML entities byte-for-byte.
        let pattern = #"<(?:[^>\"']|\"[^\"]*\"|'[^']*')*>|\{\\[^}]*\}|&(?:#[xX][0-9a-fA-F]+|#\d+|[A-Za-z][A-Za-z0-9]*);"#
        let regex = try! NSRegularExpression(pattern: pattern)
        var output = ""
        var position = line.startIndex
        for match in regex.matches(in: line, range: NSRange(line.startIndex..., in: line)) {
            guard let range = Range(match.range, in: line) else { continue }
            output += transform(String(line[position..<range.lowerBound]))
            output += line[range]
            position = range.upperBound
        }
        output += transform(String(line[position...]))
        return output
    }

    private func transform(_ input: String) -> String {
        stages.reduce(input) { $1.convert($0) }
    }
}

private struct PhraseDictionary: Sendable {
    private struct Node: Sendable {
        var children: [Unicode.Scalar: Int] = [:]
        var replacement: String?
    }
    private var nodes = [Node()]

    init(_ sources: [String]) {
        for source in sources {
            for line in source.split(whereSeparator: \.isNewline) where !line.hasPrefix("#") {
                let pair = line.split(separator: "\t", maxSplits: 1)
                guard pair.count == 2, let first = pair[1].split(separator: " ").first else { continue }
                var node = 0
                for scalar in pair[0].unicodeScalars {
                    if let next = nodes[node].children[scalar] { node = next }
                    else {
                        let next = nodes.count
                        nodes.append(Node())
                        nodes[node].children[scalar] = next
                        node = next
                    }
                }
                if nodes[node].replacement == nil { nodes[node].replacement = String(first) }
            }
        }
    }

    func convert(_ source: String) -> String {
        let input = Array(source.unicodeScalars)
        var output = ""
        var index = 0
        while index < input.count {
            var node = 0
            var cursor = index
            var best: (end: Int, text: String)?
            while cursor < input.count, let child = nodes[node].children[input[cursor]] {
                node = child; cursor += 1
                if let replacement = nodes[node].replacement { best = (cursor, replacement) }
            }
            if let best { output += best.text; index = best.end }
            else { output.unicodeScalars.append(input[index]); index += 1 }
        }
        return output
    }
}
