import Foundation

enum OutputContainer: String, Codable, CaseIterable, Identifiable {
    case mp4
    case mov

    var id: Self { self }
    var displayName: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }
}

enum VideoCodec: String, Codable, CaseIterable, Identifiable {
    case h264VideoToolbox
    case hevcVideoToolbox
    case proResVideoToolbox

    var id: Self { self }

    var displayName: String {
        switch self {
        case .h264VideoToolbox: "H.264 (Hardware)"
        case .hevcVideoToolbox: "HEVC (Hardware)"
        case .proResVideoToolbox: "Apple ProRes 422 (Hardware)"
        }
    }

    var ffmpegName: String {
        switch self {
        case .h264VideoToolbox: "h264_videotoolbox"
        case .hevcVideoToolbox: "hevc_videotoolbox"
        case .proResVideoToolbox: "prores_videotoolbox"
        }
    }

    var supportsBitrate: Bool { self != .proResVideoToolbox }
    var fileNameTag: String {
        switch self {
        case .h264VideoToolbox: "H264"
        case .hevcVideoToolbox: "H265"
        case .proResVideoToolbox: "PRORES422"
        }
    }
    var requiredContainer: OutputContainer? {
        self == .proResVideoToolbox ? .mov : nil
    }
}
enum AudioCodec: String, Codable, CaseIterable, Identifiable {
    case aac
    case pcm

    var id: Self { self }
    var displayName: String {
        switch self {
        case .aac: "AAC"
        case .pcm: "Linear PCM"
        }
    }
}

struct ConversionPreset: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var container: OutputContainer
    var videoCodec: VideoCodec
    var width: Int?
    var height: Int?
    var frameRate: Double?
    var videoBitrateMbps: Int?
    var audioCodec: AudioCodec
    var audioBitrateKbps: Int
    var isBuiltIn: Bool

    static let builtIns: [ConversionPreset] = [
        ConversionPreset(
            id: UUID(uuidString: "D429734B-6310-45CF-9F9B-870E31CD6A01")!,
            name: "Fast 1080p H.264",
            container: .mp4,
            videoCodec: .h264VideoToolbox,
            width: 1920,
            height: 1080,
            frameRate: 30,
            videoBitrateMbps: 12,
            audioCodec: .aac,
            audioBitrateKbps: 192,
            isBuiltIn: true
        ),
        ConversionPreset(
            id: UUID(uuidString: "98B177BC-97F2-4871-BAC6-CE4A87F1C702")!,
            name: "Efficient 4K HEVC",
            container: .mp4,
            videoCodec: .hevcVideoToolbox,
            width: 3840,
            height: 2160,
            frameRate: 30,
            videoBitrateMbps: 35,
            audioCodec: .aac,
            audioBitrateKbps: 256,
            isBuiltIn: true
        ),
        ConversionPreset(
            id: UUID(uuidString: "7F128464-B8D0-45BC-B1E8-6D5C9EF20203")!,
            name: "ProRes 422 — Original Size",
            container: .mov,
            videoCodec: .proResVideoToolbox,
            width: nil,
            height: nil,
            frameRate: nil,
            videoBitrateMbps: nil,
            audioCodec: .pcm,
            audioBitrateKbps: 0,
            isBuiltIn: true
        )
    ]
}

struct VideoMetadata: Hashable {
    var duration: Double
    var width: Int
    var height: Int
    var frameRate: Double
    var fileSize: Int64
    var codec: String

    var durationText: String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        return String(format: "%02d:%02d:%02d", totalSeconds / 3600, (totalSeconds % 3600) / 60, totalSeconds % 60)
    }

    var resolutionText: String { "\(width) × \(height)" }

    var frameRateText: String {
        frameRate > 0 ? String(format: "%.2f fps", frameRate) : "Unknown Frame Rate"
    }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}

enum ConversionStatus: Equatable {
    case ready
    case converting
    case completed
    case failed(String)
    case cancelled

    var label: String {
        switch self {
        case .ready: "Ready"
        case .converting: "Converting"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    var canStart: Bool {
        switch self {
        case .ready, .failed, .cancelled: true
        case .converting, .completed: false
        }
    }
}

struct VideoItem: Identifiable {
    let id: UUID
    let url: URL
    var metadata: VideoMetadata
    var outputBaseName: String
    var preset: ConversionPreset
    var status: ConversionStatus = .ready
    var progress: Double = 0
    var elapsedTime: TimeInterval = 0
    var processingFPS: Double = 0
    var outputURL: URL?

    init(url: URL, metadata: VideoMetadata, preset: ConversionPreset) {
        id = UUID()
        self.url = url
        self.metadata = metadata
        outputBaseName = url.deletingPathExtension().lastPathComponent
        self.preset = preset
    }
}

struct ConversionProgress: Sendable {
    var fraction: Double
    var elapsedTime: TimeInterval
    var framesPerSecond: Double
}
