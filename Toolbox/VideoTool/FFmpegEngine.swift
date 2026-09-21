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
        progress: @escaping @MainActor (ConversionProgress) -> Void
    ) async throws {
        guard let executableURL else { throw VideoToolError.ffmpegNotFound }

        let process = Process()
        let progressPipe = Pipe()
        let errorPipe = Pipe()
        let errorCollector = OutputCollector()
        let progressParser = ProgressParser(duration: duration)
        let startTime = Date()

        process.executableURL = executableURL
        process.arguments = FFmpegCommandBuilder.arguments(input: input, output: output, preset: preset)
        process.standardOutput = progressPipe
        process.standardError = errorPipe
        currentProcess = process

        progressPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let snapshots = progressParser.consume(data)
            for snapshot in snapshots {
                let update = ConversionProgress(
                    fraction: snapshot.fraction,
                    elapsedTime: Date().timeIntervalSince(startTime),
                    framesPerSecond: snapshot.framesPerSecond
                )
                Task { @MainActor in progress(update) }
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
            progress(ConversionProgress(
                fraction: 1,
                elapsedTime: Date().timeIntervalSince(startTime),
                framesPerSecond: progressParser.latestFramesPerSecond
            ))
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
    private var framesPerSecond = 0.0

    struct Snapshot {
        var fraction: Double
        var framesPerSecond: Double
    }

    init(duration: Double) {
        self.duration = duration
    }

    var latestFramesPerSecond: Double {
        lock.lock()
        defer { lock.unlock() }
        return framesPerSecond
    }

    func consume(_ data: Data) -> [Snapshot] {
        lock.lock()
        defer { lock.unlock() }

        buffer += String(decoding: data, as: UTF8.self)
        let lines = buffer.split(separator: "\n", omittingEmptySubsequences: false)
        buffer = String(lines.last ?? "")

        guard duration > 0 else { return [] }
        var snapshots: [Snapshot] = []
        for line in lines.dropLast() {
            if line.hasPrefix("fps="), let fps = Double(line.dropFirst("fps=".count)) {
                framesPerSecond = fps
            } else if line.hasPrefix("out_time_us="),
                      let microseconds = Double(line.dropFirst("out_time_us=".count)) {
                snapshots.append(Snapshot(
                    fraction: min(max(microseconds / 1_000_000 / duration, 0), 1),
                    framesPerSecond: framesPerSecond
                ))
            }
        }
        return snapshots
    }
}
