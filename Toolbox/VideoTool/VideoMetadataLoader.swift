import AVFoundation
import CoreMedia
import Foundation

enum VideoMetadataLoader {
    static func load(from url: URL) async throws -> VideoMetadata {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)

        guard let track = tracks.first else {
            throw VideoToolError.noVideoTrack
        }

        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let descriptions = try await track.load(.formatDescriptions)
        let transformedSize = naturalSize.applying(preferredTransform)
        let codec = descriptions.first.map(codecName) ?? "未知编码"
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])

        return VideoMetadata(
            duration: duration.seconds.isFinite ? duration.seconds : 0,
            width: Int(abs(transformedSize.width).rounded()),
            height: Int(abs(transformedSize.height).rounded()),
            frameRate: Double(nominalFrameRate),
            fileSize: Int64(resourceValues.fileSize ?? 0),
            codec: codec
        )
    }

    private static func codecName(_ description: CMFormatDescription) -> String {
        let subtype = CMFormatDescriptionGetMediaSubType(description)
        let characters: [Character] = [24, 16, 8, 0].compactMap { shift in
            guard let scalar = UnicodeScalar((subtype >> shift) & 0xff), scalar.isASCII else { return nil }
            return Character(scalar)
        }
        let code = String(characters).trimmingCharacters(in: .whitespaces)

        switch code.lowercased() {
        case "avc1": return "H.264"
        case "hvc1", "hev1": return "HEVC"
        case "apcn": return "Apple ProRes 422"
        case "apch": return "Apple ProRes 422 HQ"
        case "ap4h": return "Apple ProRes 4444"
        default: return code.isEmpty ? "未知编码" : code
        }
    }
}

enum VideoToolError: LocalizedError {
    case noVideoTrack
    case ffmpegNotFound
    case invalidOutputDirectory
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack: "文件中没有可用的视频轨道。"
        case .ffmpegNotFound: "没有找到 FFmpeg。请先通过 Homebrew 安装 FFmpeg。"
        case .invalidOutputDirectory: "请选择有效的导出文件夹。"
        case let .conversionFailed(message): message.isEmpty ? "FFmpeg 转换失败。" : message
        }
    }
}
