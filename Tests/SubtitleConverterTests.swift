import Foundation

@main
struct SubtitleConverterTests {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let converter = try SubtitleConverter(resourceDirectory: root)
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message); checks += 1
        }
        func rejects(_ body: () throws -> Void) {
            do { try body(); preconditionFailure("Expected an error") } catch { checks += 1 }
        }
        let source = "1\r\n00:00:01,000 --> 00:00:03,000\r\n硬盘 软件 内存 鼠标 视频 网络 打印机\r\n\r\n2\r\n00:00:04,000 --> 00:00:05,000 X1:10\r\n<font face=\"软件\">软件</font> {\\fn软件}硬盘 &amp; Hello 😀\r\n"
        let result = try converter.convert(source)
        check(result.text.contains("硬碟 軟體 記憶體 滑鼠 影片 網路 印表機"), "Taiwan IT terms")
        check(result.text.contains("<font face=\"软件\">軟體</font> {\\fn软件}硬碟 &amp; Hello 😀"), "Markup protected")
        check(result.cueCount == 2 && result.changedCueCount == 2, "Cue counts")
        check(result.text.components(separatedBy: "\r\n").count == source.components(separatedBy: "\r\n").count, "CRLF retained")
        check(result.text.contains("00:00:04,000 --> 00:00:05,000 X1:10"), "Timing retained")
        check(try converter.convert(result.text).text == result.text, "Repeated conversion stable")
        for encoding in SubtitleEncoding.allCases {
            let encoded = try SubtitleFileCodec.encode(text: source, encoding: encoding)
            let decoded = try SubtitleFileCodec.decode(encoded)
            check(decoded.text == source && decoded.encoding == encoding, "Encoding round trip")
        }
        let mixed = "\u{FEFF}001\r00:00:00,000 --> 00:00:01,000\n软件\r\n\r\n"
        check(try converter.convert(mixed).text == mixed.replacingOccurrences(of: "软件", with: "軟體"), "BOM, mixed endings and number retained")
        check(try converter.convert("1\n00:00:00,000 --> 00:00:01,000\n软件").text.hasSuffix("軟體"), "No added final newline")
        rejects { _ = try converter.convert("") }
        rejects { _ = try converter.convert("hello") }
        rejects { _ = try converter.convert("1\n00:00:03,000 --> 00:00:01,000\n软件") }
        rejects { _ = try converter.convert("1\n00:90:00,000 --> 00:91:00,000\n软件") }
        rejects { _ = try converter.convert("1\n00:00:00,000 --> 00:00:01,000\n") }
        rejects { _ = try SubtitleFileCodec.decode(Data([0xFF, 0xFF, 0xFF])) }
        rejects { _ = try SubtitleFileCodec.decode(Data([0xFF, 0xFE, 0x00, 0xD8])) }
        rejects { _ = try SubtitleFileCodec.decode(Data([0xFF, 0xFE, 0x41])) }
        rejects { _ = try converter.convert("1\n00:00:00,000 --> 00:00:01,000\n软件\n2\n00:00:01,000 --> 00:00:02,000\n硬盘") }
        check(try converter.convert("1\n00:00:00,000 --> 00:00:01,000\n<font title=\"x > 软件\">软件</font>").text.contains("<font title=\"x > 软件\">軟體</font>"), "Quoted angle bracket attribute protected")
        rejects { _ = try SubtitleFileCodec.decode(Data(repeating: 65, count: SubtitleFileCodec.maximumBytes + 1)) }
        let large = (1...10_000).map { "\($0)\n00:00:00,000 --> 00:00:01,000\n硬盘软件\n\n" }.joined()
        let start = Date()
        let largeResult = try converter.convert(large)
        check(largeResult.cueCount == 10_000 && largeResult.changedCueCount == 10_000, "10,000 cues")
        print("PASS: \(checks) subtitle checks; 10,000 cues in \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
    }
}
