# Decisions

Long-lived product and technical decisions. Historical decisions retain their IDs; later entries supersede earlier ones where stated.

## DEC-023 — First public source and DMG release

- Date: 2026-11-01. Status: authorized and being prepared.
- Publish raycalrui/Toolbox as a public MIT project and prepare v0.1.0 preview DMG. OpenCC remains Apache-2.0 with attribution. Repository creation is complete; release upload/verification is pending.
- Universal Release build and Developer ID signatures for app and DMG have been verified. Notarization remains incomplete because no usable local notarytool profile is available. Never describe signing as notarization.
- External FFmpeg remains separately installed; do not bundle the local Homebrew executable.

## DEC-022 — Provisional origami icon

- Date: 2026-10-01. Status: selected.
- Use the second displayed image from the creative-reset round: orange origami utility container on ivory. Preserve earlier wrench artwork.
- Current PNG AppIcon is provisional. Dedicated editable design and Icon Composer layering/template/appearance checks are deferred to UX-003.

## DEC-021 — Provisional slotted wrench

- Date: 2026-09-30. Status: superseded by DEC-022.
- Selected the first displayed slotted-handle orange wrench, with 16–1024 px exports. Retain historical artwork and export script.

## DEC-020 — Fixed Recording Fix command

- Date: 2026-09-28. Status: implemented.
- Separate queue/entry using the shared engine with -hwaccel videotoolbox -i INPUT -vf fps=60 -c:v hevc_videotoolbox -tag:v hvc1 -c:a copy OUTPUT.
- Add safety/progress arguments only; do not inject ordinary presets, scaling, pixel format, track overrides, quality, or bitrate. Preserve FFmpeg defaults.
- Hidden temporary MOV becomes final only after success. Root-owned independent models survive tool switching. No persisted queues/login helper added. Re-encoding is not lossless.

## DEC-019 — Offline Taiwan subtitle dictionaries

- Date: 2026-09-28. Status: implemented.
- Bundle OpenCC 1.1.9 s2twp dictionary stages with Apache-2.0 attribution. Independent Swift forward longest matching, not the C++ segmentation runtime.
- Convert subtitle text while preserving structure/tags; phrases do not cross lines/tags. Human review for names/ambiguity. Default _zh-TW.srt, source protection, original supported encoding, no automatic persistence/network dependency.

## DEC-001 — Native macOS first

- Date: 2026-09-21. Status: confirmed.
- SwiftUI with AppKit/public APIs where needed for clipboard, files, power, networking, and Finder. Web version requires a separate selection.

## DEC-002 — User chooses implementation order

- Date: 2026-09-21. Status: confirmed.
- Record ideas as candidates until selected; do not implement easy features ahead of the user's priorities.

## DEC-003 — Local Git before public authorization

- Date: 2026-09-21. Status: historical phase completed.
- Initially no GitHub remote/publication. Explicit first-public-release authority was granted 2026-11-01 under DEC-023.

## DEC-004 — Initial project configuration

- Date: 2026-09-21. Status: current starting configuration.
- Toolbox, com.raycal.Toolbox, Swift 6, macOS 15 minimum. Final product name/identifier/compatibility can be reconsidered with explicit scope.

## DEC-005 — Video first

- Date: 2026-09-21. Status: implemented.
- User selected VID-001 as the first feature; other tools followed only after selection.

## DEC-006 — Hybrid media architecture

- Date: 2026-09-21. Status: implemented; packaging superseded by DEC-010.
- SwiftUI/AVFoundation handles UI and metadata; FFmpeg handles conversion with VideoToolbox hardware encoders.
- App Sandbox currently disabled for invoking external development tools. The initial distribution-bundling proposal was superseded by DEC-010.

## DEC-007 — English product and documentation

- Date: 2026-09-21; updated 2026-11-01 to follow the user's latest repository instructions. Status: confirmed.
- UI, user-visible states/errors/dialogs, filenames, README, and project documentation use English. Communicate with the user in Simplified Chinese by default.
- Earlier Chinese collaboration documents are being translated for the public release.

## DEC-008 — Parameterized export filenames

- Date: 2026-09-21. Status: implemented.
- Editable base name plus resolution/FPS/codec/bitrate suffix, e.g. name_4K60_H265_40M.mp4; append collision numbering.
- ProRes does not append a user bitrate label.

## DEC-009 — Per-item settings and state

- Date: 2026-09-21. Status: implemented.
- Each video owns an independent preset. Start handles ready/failed/cancelled items, skipping completed output. Active items are not editable/removable; finished items remain removable.

## DEC-010 — External Homebrew FFmpeg

- Date: 2026-09-21. Status: confirmed.
- Do not bundle/auto-install FFmpeg. Detect Apple Silicon/Intel Homebrew paths and provide commands/recheck.
- Avoid bundled binary maintenance, signing, size, and licensing overhead. First video use can require Homebrew/FFmpeg.

## DEC-011 — Independent tools and shared sidebar

- Date: 2026-09-21. Status: implemented.
- Module folders, root views, local tool state, grouped navigation. Shared shell selects content rather than owning unrelated business logic.
- Password-tool input is view-local and not persisted.

## DEC-012 — Explicit public-IP queries

- Date: 2026-09-21. Status: implemented.
- Network Tools queries ipify HTTPS endpoints only on Refresh, identifies the provider, and does not persist results. DDNS has separate explicit update schedules.

## DEC-013 — Long-running controller ownership

- Date: 2026-09-22. Status: implemented.
- Root owns Clipboard/Sleep/DDNS controllers so navigation does not interrupt them. App exit stops monitoring/schedules and releases power assertions.

## DEC-014 — Separate credentials from settings

- Date: 2026-09-22. Status: implemented.
- Tokens in Keychain; ordinary settings, clipboard text/metadata, and favorites in UserDefaults; clipboard PNGs in Application Support.
- All local, no synchronization. Retention/deletion cleans image files; maximum 20 MB per image.

## DEC-015 — Finder MVP uses NSServices

- Date: 2026-09-22. Status: implemented.
- Compare Text in Toolbox and Convert Video in Toolbox, with persisted inbox routing. Finder Services/Quick Actions instead of a standalone Finder Sync target. Local service registration can depend on installation/session state.

## DEC-016 — Local Favorites

- Date: 2026-09-22. Status: implemented.
- Sidebar stars/top group backed by UserDefaults. No sync/account/homepage.

## DEC-017 — Per-record DDNS address source

- Date: 2026-09-23. Status: implemented.
- A/AAAA independently choose public lookup or interface name. Reread addresses; IPv6 system flags reject temporary/deprecated/not-ready candidates; filter non-public scopes.
- Multiple eligible addresses require explicit selection. Interface/address loss fails visibly, without silent fallback. Configuration remains editable before enabling the record.

## DEC-018 — User-selectable IPv4 echo service

- Date: 2026-09-23. Status: implemented, real app retest pending.
- IPv4 can use documented ip.czl.net HTTPS API, ipify, or interface; only suitable choices appear for IPv6.
- Preview/update share the selected source and validation. CZL uses system curl --ipv4 because its API reports the actual connection family. No silent source fallback. This cannot guarantee bypassing VPN/proxy routing.
