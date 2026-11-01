import AppKit
import Foundation

@main
struct RecordingFixQueueTests {
    @MainActor
    static func main() async throws {
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("recording-queue-\(UUID().uuidString)")
        let first = root.appendingPathComponent("a/input.mov")
        let second = root.appendingPathComponent("b/input.mov")
        let output = root.appendingPathComponent("output")
        for directory in [first.deletingLastPathComponent(), second.deletingLastPathComponent(), output] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        try fm.copyItem(at: source, to: first)
        try fm.copyItem(at: source, to: second)
        let original = try Data(contentsOf: source)
        let metadata = try await VideoMetadataLoader.load(from: first)
        func item(_ url: URL) -> VideoItem {
            VideoItem(url: url, metadata: metadata, preset: ConversionPreset.builtIns[0])
        }
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
        }
        func finished(_ model: VideoConverterViewModel) async throws {
            let deadline = Date().addingTimeInterval(30)
            while model.isConverting, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
            check(!model.isConverting, "Queue timed out")
        }

        let model = VideoConverterViewModel(mode: .recordingFix)
        check(model.outputDirectory == nil && model.estimatedOutputSize == nil, "No presets or output folder required")
        model.items = [item(first), item(second)]
        model.outputDirectory = output
        let protectedOutput = output.appendingPathComponent("input_60fps_h265.mov")
        let marker = Data("existing output must stay unchanged".utf8)
        try marker.write(to: protectedOutput)
        model.startConversion()
        try await finished(model)
        check(model.items.allSatisfy { $0.status == .completed }, "Batch completed")
        check(model.items.map { $0.outputURL!.lastPathComponent } == ["input_60fps_h265_2.mov", "input_60fps_h265_3.mov"], "Same-name inputs get unique output names")
        check(try Data(contentsOf: protectedOutput) == marker, "Existing output untouched")
        check(try Data(contentsOf: first) == original, "Original untouched")
        let filesBefore = try fm.contentsOfDirectory(atPath: output.path).sorted()
        model.startConversion()
        check(!model.isConverting, "Completed jobs skipped")
        check(try fm.contentsOfDirectory(atPath: output.path).sorted() == filesBefore, "No duplicate outputs")

        let cancelled = VideoConverterViewModel(mode: .recordingFix)
        cancelled.items = [item(first)]
        cancelled.startConversion()
        while cancelled.items[0].status == .ready { await Task.yield() }
        cancelled.cancelConversion()
        try await finished(cancelled)
        check(cancelled.items[0].status == .cancelled, "Cancel status")
        check(try fm.contentsOfDirectory(atPath: first.deletingLastPathComponent().path) == ["input.mov"], "Cancelled partial output removed")
        cancelled.startConversion()
        try await finished(cancelled)
        check(cancelled.items[0].status == .completed, "Cancelled job retried")
        check(cancelled.items[0].outputURL?.deletingLastPathComponent() == first.deletingLastPathComponent(), "Default saves next to source")
        cancelled.remove(cancelled.items[0])
        check(cancelled.items.isEmpty, "Completed item removable")

        model.items = [item(root.appendingPathComponent("missing.mov"))]
        model.startConversion()
        try await finished(model)
        if case .failed = model.items[0].status {} else { preconditionFailure("Missing input must fail") }
        check(try fm.contentsOfDirectory(atPath: output.path).allSatisfy { !$0.hasPrefix(".toolbox-recording-") }, "Failed partial output removed")
        model.remove(model.items[0])
        check(model.items.isEmpty, "Failed item removable")
        print("PASS: Recording Fix queue batch, naming, protection, skip, cancel, retry, cleanup and failure checks. Fixtures: \(root.path)")
    }
}
