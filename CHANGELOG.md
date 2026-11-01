# Changelog

Implemented user-visible changes only. Plans and unfinished acceptance belong in TODO.md.

## 0.1.0 — 2026-11-01 (Public Preview)

Published the MIT source and Universal Developer ID-signed app/DMG to GitHub. Anonymous DMG download and SHA-256 equality passed. This preview is not notarized; installation guidance states the resulting first-launch limitation.

### Added

- Native macOS SwiftUI multi-tool app with an English interface, grouped sidebar, and local Favorites.
- Video Converter: batch open/drop, media metadata, MP4/MOV, VideoToolbox H.264/HEVC/ProRes 422, AAC/PCM, independent per-file resolution/frame rate/bitrate/audio settings, presets, estimated size, progress percentage/elapsed/FPS/ETA, cancellation, and Finder reveal.
- Editable output base names with selected parameter suffixes; completed items are skipped on subsequent starts and finished/cancelled/failed items remain removable.
- External FFmpeg dependency guidance with Homebrew/FFmpeg distinction, copyable commands, brew.sh, and Check Again.
- Recording Fix: separate batch-MOV queue using fixed constant 60 fps HEVC/hvc1 conversion and copied audio, with original quality defaults, output collision numbering, source protection, cancellation cleanup, and retained state across tool switches.
- Offline SRT Converter using bundled OpenCC dictionaries: Simplified Chinese to Taiwan Traditional Chinese and regional terminology, original/result previews, copy/save, preserved timing/numbering/markup/line endings/encodings, and source overwrite protection.
- Text Diff with line/word and side-by-side/unified views, highlighting, UTF-8 file drops, and copy.
- Secure UUID v4/random-string batches and offline password generation/strength checks.
- Network interfaces, public IPv4/IPv6 on demand, Ping, and IP/CIDR parsing.
- Clipboard History for local text/images with thumbnails, search, pin/copy/delete/pause, retention/count controls, and sensitive-type exclusion.
- System/display Sleep Prevention with durations and countdown.
- Finder Services for selected text files and videos.
- Cloudflare DDNS with Keychain tokens, independent A/AAAA, manual/app-running schedules, proxy control, per-record source/interface selection, previews, and protocol-specific errors.
- Provisional orange origami utility-container AppIcon with original artwork and reproducible size exports.
- First-release packaging script, MIT licensing and bundled third-party notices, English project documentation, and installation guidance.

### Fixed

- Video layout/sidebar/settings overflow and completed progress remnants.
- Text Diff editor/result sizing and aligned upper/lower central dividers across window sizes.
- Per-item export settings, completed-item skipping, and removal after cancellation.
- DDNS source/interface configuration is available before a record is enabled.
- CZL IPv4 queries force IPv4 and distinguish service/format/address-family failures. Revised live app retesting remains pending.
- App startup explicitly loads the bundled icon following reports of a generic cached running icon.

### Distribution status

- Universal Release app and DMG have been built; Developer ID signatures for both were verified.
- Apple notarization is not complete because a usable local notarytool Keychain profile is unavailable.
- No public release upload or download verification is claimed yet. See REL-001.
