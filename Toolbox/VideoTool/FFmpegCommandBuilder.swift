import Foundation

struct FFmpegCommandBuilder {
    static func arguments(
        input: URL,
        output: URL,
        preset: ConversionPreset
    ) -> [String] {
        var arguments = [
            "-hide_banner",
            "-y",
            "-i", input.path,
            "-map", "0:v:0",
            "-map", "0:a?",
            "-map_metadata", "0"
        ]

        if let width = preset.width, let height = preset.height {
            arguments += [
                "-vf",
                "scale=\(width):\(height):force_original_aspect_ratio=decrease:force_divisible_by=2"
            ]
        }

        if let frameRate = preset.frameRate {
            arguments += ["-r", number(frameRate)]
        }

        arguments += ["-c:v", preset.videoCodec.ffmpegName]

        switch preset.videoCodec {
        case .h264VideoToolbox:
            arguments += ["-allow_sw", "1", "-profile:v", "high", "-pix_fmt", "yuv420p"]
        case .hevcVideoToolbox:
            arguments += ["-allow_sw", "1", "-tag:v", "hvc1", "-pix_fmt", "yuv420p"]
        case .proResVideoToolbox:
            arguments += ["-allow_sw", "1", "-profile:v", "2", "-pix_fmt", "yuv422p10le"]
        }

        if preset.videoCodec.supportsBitrate, let bitrate = preset.videoBitrateMbps {
            arguments += ["-b:v", "\(bitrate)M", "-maxrate", "\(bitrate)M", "-bufsize", "\(bitrate * 2)M"]
        }

        switch preset.audioCodec {
        case .aac:
            arguments += ["-c:a", "aac", "-b:a", "\(preset.audioBitrateKbps)k"]
        case .pcm:
            arguments += ["-c:a", "pcm_s16le"]
        }

        if preset.container == .mp4 || preset.container == .mov {
            arguments += ["-movflags", "+faststart"]
        }

        arguments += ["-progress", "pipe:1", "-nostats", output.path]
        return arguments
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
