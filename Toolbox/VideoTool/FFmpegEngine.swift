import Foundation

enum FFmpegDependencyStatus: Equatable {
    case ready(URL)
    case ffmpegMissing
    case homebrewMissing

    var executableURL: URL? {
        guard case let .ready(url) = self else { return nil }
        return url
    }
}

enum FFmpegLocator {
    private static let ffmpegPaths = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg"
    ]

    private static let homebrewPaths = [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]

    static func dependencyStatus(fileManager: FileManager = .default) -> FFmpegDependencyStatus {
        if let path = ffmpegPaths.first(where: fileManager.isExecutableFile(atPath:)) {
            return .ready(URL(fileURLWithPath: path))
        }
        if homebrewPaths.contains(where: fileManager.isExecutableFile(atPath:)) {
            return .ffmpegMissing
        }
        return .homebrewMissing
    }
}

@MainActor
final class FFmpegEngine {
    private var currentProcess: Process?
    private var cancellationRequested = false

    var executableURL: URL? {
        FFmpegLocator.dependencyStatus().executableURL
    }

    func cancel() {
        cancellationRequested = true
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
        try await run(arguments: FFmpegCommandBuilder.arguments(input: input, output: output, preset: preset),
                      duration: duration, progress: progress)
    }

    func convertRecording(
        input: URL,
        output: URL,
        duration: Double,
        progress: @escaping @MainActor (ConversionProgress) -> Void
    ) async throws {
        try await run(arguments: FFmpegCommandBuilder.recordingFixArguments(input: input, output: output),
                      duration: duration, requiresCompletion: true, progress: progress)
    }

    private func run(
        arguments: [String],
        duration: Double,
        requiresCompletion: Bool = false,
        progress: @escaping @MainActor (ConversionProgress) -> Void
    ) async throws {
        try Task.checkCancellation()
        guard let executableURL else { throw VideoToolError.ffmpegNotFound }
        cancellationRequested = false

        let process = Process()
        let progressPipe = Pipe()
        let errorPipe = Pipe()
        let errorCollector = OutputCollector()
        let progressParser = ProgressParser(duration: duration)
        let startTime = Date()

        process.executableURL = executableURL
        process.arguments = arguments
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

        let status = try await withTaskCancellationHandler {
            try await launchAndWait(process)
        } onCancel: {
            Task { @MainActor [weak self] in
                guard self?.currentProcess === process else { return }
                self?.cancel()
            }
        }
        progressPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        _ = progressParser.consume(progressPipe.fileHandleForReading.readDataToEndOfFile())
        errorCollector.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

        if cancellationRequested || Task.isCancelled || process.terminationReason == .uncaughtSignal {
            throw CancellationError()
        }

        if status == 0 && (!requiresCompletion || progressParser.didFinish) {
            progress(ConversionProgress(
                fraction: 1,
                elapsedTime: Date().timeIntervalSince(startTime),
                framesPerSecond: progressParser.latestFramesPerSecond
            ))
            return
        }

        let message = errorCollector.text
            .split(separator: "\n")
            .suffix(8)
            .joined(separator: "\n")
        throw VideoToolError.conversionFailed(message)
    }

    private func launchAndWait(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            // Install before launching: even immediate failures must resume the waiter.
            process.terminationHandler = { finishedProcess in
                continuation.resume(returning: finishedProcess.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                continuation.resume(throwing: error)
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
    private var finished = false

    var didFinish: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }

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

        var snapshots: [Snapshot] = []
        for line in lines.dropLast() {
            if line == "progress=end" {
                finished = true
            } else if line.hasPrefix("fps="), let fps = Double(line.dropFirst("fps=".count)) {
                framesPerSecond = fps
            } else if line.hasPrefix("out_time_us="),
                      let microseconds = Double(line.dropFirst("out_time_us=".count)), duration > 0 {
                snapshots.append(Snapshot(
                    fraction: min(max(microseconds / 1_000_000 / duration, 0), 1),
                    framesPerSecond: framesPerSecond
                ))
            }
        }
        return snapshots
    }
}
