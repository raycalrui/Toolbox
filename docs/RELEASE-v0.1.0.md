# Toolbox 0.1.0 — Public Preview

The first open-source preview of Toolbox, a native macOS utility collection.

## Download

- `Toolbox-0.1.0.dmg`: Universal app for Apple Silicon and Intel, macOS 15+.
- `SHA256SUMS`: SHA-256 checksum for the DMG.
- Drag Toolbox to Applications to install.

**Signing:** the app and DMG are Developer ID signed, but this preview is
**not notarized**. macOS may block first launch. Review the download and use
the per-app option in System Settings > Privacy & Security if you choose to
proceed, or build from source. Do not disable Gatekeeper globally.

## Included tools

- Video Converter with per-file export settings, presets and progress.
- Recording Fix: batch MOV to constant 60 fps HEVC/hvc1 with copied audio.
- SRT Converter: offline Simplified Chinese to Taiwan Traditional Chinese
  with regional vocabulary; preserves timing and supported source encoding.
- Text Diff, UUID/random strings and offline password tools.
- Network interfaces, public IP lookup, Ping and CIDR analysis.
- Cloudflare A/AAAA DDNS with selectable IP sources and Keychain tokens.
- Local clipboard history with images, sleep prevention and favorites.
- Finder Services for text and video files.

Video tools require a separate FFmpeg installation: `brew install ffmpeg`.
FFmpeg is not included in the DMG. Other offline tools do not require it.

## Privacy and limitations

Clipboard monitoring starts while the app is running; pause and retention
controls are available. Unmarked password text cannot be reliably detected.
DDNS schedules run only while Toolbox is open. Real QuickTime-to-DaVinci
workflows, Cloudflare DNS updates and the CZL lookup service still need broader
real-world testing. Review subtitle vocabulary and names before publishing.
The origami icon is provisional; Apple-template/Icon Composer production
artwork remains planned in UX-003.

## Validation

Universal Release build, strict App/DMG signature verification, read-only DMG
mount and image checksum verification passed. All six OpenCC dictionaries,
Apache-2.0 attribution and project MIT license are included. Subtitle checks
and Recording Fix command/queue tests passed on Apple Silicon; Intel was
compiled but has not been tested on an Intel Mac.

Source code is MIT licensed; bundled OpenCC dictionaries retain Apache-2.0.
