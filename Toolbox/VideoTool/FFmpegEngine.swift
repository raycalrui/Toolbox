import Foundation

@MainActor
final class FFmpegEngine {
    private var currentProcess: Process?

    var executableURL: URL? {
        if let bundled = Bundle.main.url(forResource: "ffmpeg", withExtension: nil) {
            return bundled
        }

        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg"
        ]

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    func cancel() {
        guard let currentProcess, currentProcess.isRunning else { return }
        currentProcess.interrupt()
    }

    func convert(
        input: URL,
        output: URL,
        preset: ConversionPreset,
        duration: Double,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        guard let executableURL else { throw VideoToolError.ffmpegNotFound }

        let process = Process()
        let progressPipe = Pipe()
        let errorPipe = Pipe()
        let errorCollector = OutputCollector()
        let progressParser = ProgressParser(duration: duration)

        process.executableURL = executableURL
        process.arguments = FFmpegCommandBuilder.arguments(input: input, output: output, preset: preset)
        process.standardOutput = progressPipe
        process.standardError = errorPipe
        currentProcess = process

        progressPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let values = progressParser.consume(data)
            for value in values {
                Task { @MainActor in progress(value) }
            }
        }

        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty { errorCollector.append(data) }
        }

        defer {
            progressPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            currentProcess = nil
        }

        try process.run()
        let status = await terminationStatus(of: process)
        progressPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        errorCollector.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

        if status == 0 {
            progress(1)
            return
        }

        if Task.isCancelled || process.terminationReason == .uncaughtSignal {
            throw CancellationError()
        }

        let message = errorCollector.text
            .split(separator: "\n")
            .suffix(8)
            .joined(separator: "\n")
        throw VideoToolError.conversionFailed(message)
    }

    private func terminationStatus(of process: Process) async -> Int32 {
        await withCheckedContinuation { continuation in
            process.terminationHandler = { finishedProcess in
                continuation.resume(returning: finishedProcess.terminationStatus)
            }
        }
    }
}

private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}

private final class ProgressParser: @unchecked Sendable {
    private let lock = NSLock()
    private let duration: Double
    private var buffer = ""

    init(duration: Double) {
        self.duration = duration
    }

    func consume(_ data: Data) -> [Double] {
        lock.lock()
        defer { lock.unlock() }

        buffer += String(decoding: data, as: UTF8.self)
        let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false)
        buffer = String(lines.last ?? "")

        guard duration > 0 else { return [] }
        return lines.dropLast().compactMap { line in
            guard line.hasPrefix("out_time_us="),
                  let microseconds = Double(line.dropFirst("out_time_us=".count)) else { return nil }
            return min(max(microseconds / 1_000_000 / duration, 0), 1)
        }
    }
}
