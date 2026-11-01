# TODO

This is the source of truth for requirements and execution status. Unselected ideas remain candidates. States: Candidate, Selected, In progress, Blocked, Completed. Completion refers to stated implementation and checks, with outstanding acceptance limits retained below.

## Current milestone

The multi-tool local MVP is implemented. The first public source repository and v0.1.0 preview DMG are being prepared.

### REL-001 — Public GitHub repository and DMG — In progress

- Authorized 2026-11-01: create a public open-source GitHub project and publish a DMG. Intended repository: raycalrui/Toolbox; release: v0.1.0 preview. User selected MIT; retain OpenCC attribution/license.
- Public repository raycalrui/Toolbox created. Universal Release app and approximately 4 MB DMG built with scripts/build-dmg.sh. Outputs: dist/Toolbox-0.1.0.dmg and dist/SHA256SUMS.
- Recorded verification: Developer ID signatures on app/DMG; mounted DMG contents; icon, OpenCC dictionaries, and license notices present; 24 subtitle checks and recording queue batch/naming/protection/skip/cancel/retry/cleanup/failure checks passed. Release upload/public download verification remain pending.
- Developer ID certificate available; no usable notarytool Keychain profile found. Notarization remains incomplete. Signing is not notarization.
- Acceptance: source/history privacy review, third-party notices, relevant existing checks, architectures/signature/icon/dictionaries, DMG contents/checksum, reviewed-source push, and verified published assets.
- The releasing agent must record actual final results and publication before marking complete.

## Creative and video

### VID-001 — Video Converter — Completed

- Batch select/drop, metadata, MP4/MOV, VideoToolbox H.264/HEVC/ProRes 422, AAC/PCM, resolution/frame rate/bitrate/audio controls, estimated size, and built-in/custom presets.
- Independent per-file settings; editable base name with parameter suffix, e.g. name_4K60_H265_40M.mp4. Completed items are skipped; completed/cancelled/failed items are removable.
- Percentage, elapsed time, live FPS, ETA, cancel/retry/Finder reveal. Resolution/frame-rate menus start with Keep Original and end with Custom.
- Recorded verification: Debug build, three hardware codecs, actual 3840×2160/60 fps HEVC output, per-item independence, preset/UI/resizing checks, and cancellation/removal.

### VID-002 — FFmpeg dependency guidance — Completed

- Detect external Homebrew FFmpeg; distinguish missing Homebrew/FFmpeg, copy install commands, link brew.sh, and Check Again without restart. Never install automatically.
- Recorded path, ready-state, guidance, and build verification passed.

### VID-003 — Recording Fix — Completed

- Separate batch-MOV queue retaining the user pipeline: -hwaccel videotoolbox -vf fps=60 -c:v hevc_videotoolbox -tag:v hvc1 -c:a copy.
- Fixed 60 fps; original resolution and default quality/track behavior. No bitrate/quality overrides. Default adjacent _60fps_h265.mov; optional shared folder; collision numbering; preserve originals.
- Progress/elapsed/FPS/ETA, cancel/retry/reveal, skip completed items, and independent queues retained across tool switches.
- Recorded verification: exact command, 3-second VFR intervals 1/30 and 1/20 converted into 180 constant 1/60-second frames; HEVC/hvc1, 640×360 unchanged, identical AAC packet SHA-256. Queue tests covered collisions, source/existing-output protection, skipping, cancel/retry, temporary cleanup, and failed-item removal. App sample conversion and switching passed.
- Outstanding: real QuickTime-to-DaVinci acceptance. No VFR detection or guarantee of retaining every track.

### SUB-001 — SRT to Taiwan Traditional Chinese — Completed

- Offline character/regional-terminology conversion using OpenCC 1.1.9 s2twp dictionary stages and an independent Swift longest-match engine.
- Open/drop one SRT up to 5 MB, read-only previews, copy, save _zh-TW.srt; protect source including symlinks/equivalent identities.
- Preserve cues/timing/line endings/tags/attributes/entities and UTF-8/BOM UTF-8/BOM UTF-16 LE/BE; reject malformed/unsupported input.
- Recorded: Debug build, 24 core terminology/structure/markup/encoding/error checks, 10,000 cues about 0.73 seconds, app open/preview, and save default name. Final Save click/drop UI acceptance remains outstanding.
- No cross-line/tag phrase merging, semantic translation, or exact C++ runtime equivalence. Review names/ambiguity manually.

## Text and development

### TXT-001 — Text Diff — Completed

- Two editors; line/word, side-by-side/unified, added/deleted/modified and inline highlighting; UTF-8 drops up to 5 MB; unified-result copy.
- Core results and UI switching verified. Editors/results fill resized windows and central dividers align.

### DEV-001 — UUID and Random String — Completed

- Secure UUID v4, string length/character groups/batches, individual/all copy. Recorded 100 correct v4 UUIDs, build, and UI-generation checks.

## Network

### NET-001 — Local/public IP — Completed

- Show interfaces/IPv4/IPv6; public ipify queries only on explicit Refresh, provider identified, results not persisted.

### NET-002 — Ping — Completed

- Four-packet IPv4/IPv6 system ping/ping6, statistics/output/cancel, strict host validation, Process argument arrays rather than shell interpolation.

### NET-003 — IP/CIDR parsing — Completed

- Normalize IPv4/IPv6, prefixes, network/range/count/scope. Recorded /24, /64, private/documentation scope, and invalid-input checks.

### NET-004 — Cloudflare DDNS — Completed

- Keychain token, non-sensitive local settings, independent A/AAAA PATCH updates, manual or 5/15/30/60-minute schedules, proxy and protocol-level errors/status.
- Only while app runs; no login helper. Swift 6 build and static Keychain/API review passed. No real user-credential DNS mutation was performed in validation.

### NET-005 — DDNS source/interface selection — Completed

- Independent public or named-interface source; reread current addresses each update. IPv6 excludes temporary/deprecated/not-ready and unsuitable addresses; IPv4 filters common non-public ranges.
- Multiple eligible addresses require explicit selection. Missing/changed selected addresses or interfaces stop that update without silent fallback.
- Source/interface settings editable before enabling records. Check IP previews; actual update rechecks.
- Recorded simulated public IPv4/stable en0 IPv6/temporary-ULA exclusion/multiple-address/migration checks; local IPv6 flags and Debug build passed. No external DNS write.

### NET-006 — China-region IPv4 service — Blocked: app retest pending

- IPv4 menu includes ip.czl.net alongside ipify/interfaces. IPv6 lists suitable sources only. Preview/update share source; changes clear preview; failures never silently fall back or update that record.
- Initial result was a generic invalid-IPv4 error. Revised lookup uses system curl --ipv4 and separate service/non-JSON/missing-address/wrong-family errors. Build passed; revised live app retest pending.
- Earlier ipify checks returned valid IPv4; 4.ipw.cn was omitted after failed local requests and its documented personal-testing restriction. No successful live agent-side CZL check is claimed.
- Endpoint changes/forced IPv4 cannot guarantee bypassing proxies or VPN/TUN; verify previews.

## Privacy and system

### SEC-001 — Strong password generation — Completed

- Length/groups/batches, individual/all copy, ambiguous-character exclusion. SecRandomCopyBytes, unbiased sampling, at least one character per selected group.

### SEC-002 — Offline strength check — Completed

- Length/pool/common-password/repetition/sequence estimates and suggestions; no input saving/upload. Recorded weak/random-password checks passed; view-local input.

### SYS-001 — Clipboard History — Completed

- Text and PNG/TIFF/JPEG/Finder-copied images, thumbnails/dimensions/size, recopy, search/pin/delete/pause/clear.
- 25/50/100/250 entries; day/week/month/forever; defaults 100 and one week. UserDefaults text/metadata, Application Support PNGs up to 20 MB; deletion/expiry removes files.
- Skip empty/repeated/concealed/transient items. Unmarked text cannot reliably be identified as passwords.

### SYS-002 — Sleep Prevention — Completed

- Public IOPMAssertion system/display modes; 30 minutes/one hour/two hours/indefinite; countdown. Release on disable/expiry/controller destruction. No menu-bar entry.

### SYS-003 — Finder Services — Completed

- NSServices Compare Text in Toolbox (up to two files) and Convert Video in Toolbox (multiple videos), with persisted inbox routing.
- Finder Services/possibly Quick Actions, not Finder Sync. Installation/launch/new-session registration may be required.

### UX-001 — Favorites — Completed

- Sidebar stars/context menu/top Favorites; local UserDefaults, no cloud sync/homepage/drag sorting.

### UX-002 — Provisional icon integration — Completed

- Earlier candidates retained. Current selected image: Design/AppIcon/selected-origami.png; reproducible 16–1024 px assets.
- Recorded build/packaging and 32/128 px inspection passed. Startup explicitly loads bundled AppIcon following reports of a generic running icon. Runtime icon read succeeded; Dock screenshot timed out, so screenshot acceptance is not claimed.
- Origami selected 2026-10-01, replacing provisional wrench.

### UX-003 — Formal Apple icon production — Candidate

- Rebuild editable geometry in dedicated design software and Apple Icon Composer layers, using current templates/safe areas/system masking.
- Acceptance: default/dark/other supported appearances, real Dock size/visual-weight comparison beside Finder/Safari, and fallback on minimum macOS.
- Current raster is provisional, not completed formal icon acceptance.

## Outside current scope

- DDNS login helper that survives app exit.
- Independent Finder Sync extension or menu-bar entry.
- Unselected features. Public source/DMG distribution is explicitly authorized in REL-001.

## Documentation checks

Keep states and evidence accurate; update README/decisions/changelog together. Distinguish implementation, build, UI acceptance, signing, notarization, and publication.
