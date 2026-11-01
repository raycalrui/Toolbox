# Toolbox

<img src="Design/AppIcon/selected-origami.png" width="128" alt="Toolbox origami icon">

A native, local-first macOS toolbox for video, text, networking, privacy, and everyday system tasks. Built with SwiftUI and AppKit, with an English interface.

## Release status

The public repository is [raycalrui/Toolbox](https://github.com/raycalrui/Toolbox). Its first **v0.1.0 preview** release is being prepared; release asset upload and final verification are tracked in [TODO.md](TODO.md).

The DMG contains a Universal app for Apple Silicon and Intel Macs running **macOS 15 or later**. The app and DMG have verified Developer ID signatures, but **Apple notarization is not complete**. Signing does not imply notarization; macOS may block a downloaded preview. See [installation instructions](docs/INSTALL.md) and the actual release notes for final artifact status.

## Tools

| Tool | Capabilities |
| --- | --- |
| Video Converter | Batch MP4/MOV exports, hardware H.264/HEVC/ProRes 422, per-file settings, presets, custom resolution/frame rate/bitrate, progress, elapsed time, FPS, and ETA. |
| Recording Fix | Convert QuickTime MOV recordings to constant 60 fps HEVC/hvc1 MOV, retain resolution, and copy audio using the original FFmpeg command's defaults. |
| SRT Converter | Offline Simplified Chinese to Taiwan Traditional Chinese, including regional terminology; preserves timing, numbering, markup, line endings, and supported encodings. |
| Text Diff | Line/word comparison, side-by-side/unified views, change highlighting, text-file drops, and result copying. |
| UUID & Random String | Secure UUID v4, configurable length and character sets, batch generation, and copying. |
| Password Tools | Strong password generation, ambiguous-character exclusion, and offline strength checks. |
| Network Tools | Local interfaces, on-demand public IPv4/IPv6, Ping, and IPv4/IPv6/CIDR information. |
| Cloudflare DDNS | Independent A/AAAA updates, public-IP or local-interface sources, address preview, Keychain token storage, and schedules while the app runs. |
| Clipboard History | Local text/image history, thumbnails, search, pinning, copying, deletion, pause, and retention controls. |
| Sleep Prevention | Prevent system or display sleep, with timed expiry and countdown. |
| Favorites & Finder Services | Star tools; send selected text files or videos from Finder Services. |

Video exports preserve sources and avoid output-name collisions. Each item owns independent settings; completed items are skipped on subsequent starts. Video Converter and Recording Fix maintain separate queues across tool switches. Output names can include selected parameters, such as `name_4K60_H265_40M.mp4`.

## FFmpeg dependency

FFmpeg is **not bundled** or automatically installed. The video tools require a local Homebrew installation:

```sh
brew install ffmpeg
```

Toolbox checks `/opt/homebrew/bin/ffmpeg` and `/usr/local/bin/ffmpeg`. If Homebrew or FFmpeg is missing, it explains the dependency, provides a copyable command, and offers **Check Again**. Other tools do not need FFmpeg.

Recording Fix uses this fixed media pipeline, without quality or bitrate overrides:

```sh
ffmpeg -hwaccel videotoolbox -i INPUT.mov -vf fps=60 \
  -c:v hevc_videotoolbox -tag:v hvc1 -c:a copy OUTPUT.mov
```

The app adds queue safety and progress arguments. It writes `_60fps_h265.mov` beside each input by default, with an optional shared output folder and collision numbering.

## Privacy and networking

- No telemetry or cloud account is implemented. Media, subtitles, text, password generation, and password checks run locally.
- Password-tool input is not saved or uploaded. Cloudflare tokens are stored in macOS Keychain, separately from non-sensitive preferences.
- Clipboard history intentionally persists local content: text/metadata in UserDefaults and PNGs in Application Support. Default retention is **100 items for one week**. Limits are 25/50/100/250 items and one day/week/month/forever. Removal or expiry removes stored images. Images larger than 20 MB are not recorded.
- Concealed/transient clipboard types are ignored. Passwords copied as unmarked ordinary text by other apps cannot reliably be identified as sensitive.
- Public-IP lookup uses an identified third-party service. Network Tools queries ipify only on **Refresh**, without persisting results. DDNS queries its selected source for previews/updates, including configured schedules.
- DDNS supports ipify, ip.czl.net for IPv4, or local interfaces. Multiple eligible addresses require an explicit choice. IPv6 filtering excludes temporary and unsuitable addresses. Proxies/VPNs can affect detected public addresses: check the preview.
- DDNS schedules work **only while Toolbox is running**. No login helper is installed.

## Build from source

Open `Toolbox.xcodeproj` in a current Xcode and run the **Toolbox** scheme on your Mac. The project uses Swift 6, targets macOS 15+, and uses bundle identifier `com.raycal.Toolbox`. App Sandbox is not enabled because the app invokes locally installed command-line tools.

For Release build and DMG packaging:

```sh
bash scripts/build-dmg.sh
```

Outputs: `dist/Toolbox-0.1.0.dmg` and `dist/SHA256SUMS`. Set `SIGN_IDENTITY` locally for Developer ID signing; otherwise the script uses ad-hoc signing. Optional `NOTARY_PROFILE` enables app and DMG notarization/stapling. Credentials belong in the local Keychain, never Git.

## Known limitations

- Recording Fix converts every imported MOV without VFR detection. FFmpeg's default track selection applies; not every audio/data track is guaranteed. Synthetic VFR-to-CFR checks passed; real QuickTime-to-DaVinci Resolve acceptance remains outstanding.
- SRT conversion uses OpenCC 1.1.9 dictionaries with an independent Swift longest-match engine, not the C++ segmentation runtime. Phrases do not span lines or tags; names and ambiguous terms need review. One file up to 5 MB, with UTF-8, UTF-8 BOM, or BOM-marked UTF-16 LE/BE.
- The revised ip.czl.net lookup forces IPv4 and distinguishes service/format/address errors; app-side retesting is pending. Failures do not silently switch sources or update DNS.
- Real Cloudflare DNS writes with user credentials were not part of recorded validation.
- Finder uses macOS **Services**, not Finder Sync. Registration depends on local installation/session state.
- The origami icon is provisional. Editable layers and Apple Icon Composer production are tracked as **UX-003**.

## License and project notes

Toolbox uses the [MIT License](LICENSE). Bundled OpenCC dictionaries retain Apache-2.0 licensing and attribution; see [third-party notices](THIRD_PARTY_NOTICES.md). External FFmpeg is installed and licensed separately.

[TODO.md](TODO.md) tracks work and evidence, [DECISIONS.md](DECISIONS.md) records product decisions, and [CHANGELOG.md](CHANGELOG.md) records implemented changes. Project documentation and user-visible text use English.
