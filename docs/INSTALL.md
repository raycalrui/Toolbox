Toolbox 0.1.0 — Installation

Requirements: macOS 15 or later. Universal binary: Apple Silicon and Intel.

Open the DMG and drag Toolbox into Applications. Eject the disk image, then
launch Toolbox from Applications.

This initial release is a preview. The published DMG is Developer ID signed
but NOT notarized. macOS may block its first launch. If you have verified the
download and want to proceed, review the blocked app in System Settings >
Privacy & Security and use the per-app Open Anyway option if available.
Do not disable Gatekeeper globally. You can also build the app from source.

Video Converter and Recording Fix require a separately installed FFmpeg:

    brew install ffmpeg

Other offline tools do not need FFmpeg. Toolbox never installs it automatically.
Public IP detection and Cloudflare DDNS use network services only as described
in the app. DDNS schedules run only while Toolbox is open.

Clipboard History starts monitoring while Toolbox runs. Review its pause,
retention, and clear controls before copying sensitive information. Password
clipboard markers are respected when provided by the originating application,
but unmarked password text cannot be reliably identified.

Source and release notes: https://github.com/raycalrui/Toolbox
