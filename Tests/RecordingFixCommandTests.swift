import Foundation

@main
struct RecordingFixCommandTests {
    static func main() async throws {
        let input = URL(fileURLWithPath: "/tmp/recording with spaces; $(test).mov")
        let output = URL(fileURLWithPath: "/tmp/recording_60fps_h265.mov")
        let arguments = FFmpegCommandBuilder.recordingFixArguments(input: input, output: output)
        precondition(arguments == ["-hide_banner", "-n", "-nostdin", "-hwaccel", "videotoolbox",
                                   "-i", input.path, "-vf", "fps=60", "-c:v", "hevc_videotoolbox",
                                   "-tag:v", "hvc1", "-c:a", "copy", "-progress", "pipe:1", "-nostats", output.path])
        print("PASS: exact recording command, literal paths, no overwrite, no extra encoding settings")
        if CommandLine.arguments.count == 3 {
            let engine = FFmpegEngine()
            try await engine.convertRecording(input: URL(fileURLWithPath: CommandLine.arguments[1]),
                                              output: URL(fileURLWithPath: CommandLine.arguments[2]),
                                              duration: 3) { _ in }
            let completedOutput = URL(fileURLWithPath: CommandLine.arguments[2])
            let originalData = try Data(contentsOf: completedOutput)
            do {
                try await engine.convertRecording(input: URL(fileURLWithPath: CommandLine.arguments[1]),
                                                  output: completedOutput, duration: 3) { _ in }
                preconditionFailure("Existing output must not be overwritten")
            } catch is CancellationError { preconditionFailure("Refusal is not cancellation") }
            catch { }
            let unchangedData = try Data(contentsOf: completedOutput)
            precondition(unchangedData == originalData)
            print("PASS: existing output remains byte-identical")
            // Repeated immediate FFmpeg exits exercise termination registration.
            for _ in 0..<5 {
                do {
                    try await engine.convertRecording(input: URL(fileURLWithPath: "/nonexistent/recording.mov"),
                                                      output: output, duration: 1) { _ in }
                    preconditionFailure("Missing input must fail")
                } catch is CancellationError { preconditionFailure("Failure is not cancellation") }
                catch { }
            }
            print("PASS: engine conversion and five immediate failures")
            let cancellationOutput = URL(fileURLWithPath: CommandLine.arguments[2] + ".cancelled.mov")
            let task = Task {
                try await engine.convertRecording(input: URL(fileURLWithPath: CommandLine.arguments[1]),
                                                  output: cancellationOutput, duration: 3) { _ in }
            }
            try await Task.sleep(for: .milliseconds(10))
            task.cancel()
            do {
                try await task.value
                preconditionFailure("Conversion should be cancelled")
            } catch is CancellationError {
                print("PASS: task cancellation terminates conversion")
            }
        }
    }
}
