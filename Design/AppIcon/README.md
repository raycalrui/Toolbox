# Current Toolbox icon

The user selected the second displayed image from the creative-reset round:
**A — origami utility container on warm ivory** (2026-10-01).
This is the folded orange container, not the interwoven loops or colored tiles.

`selected-origami.png` is the unchanged imagegen original. `selected-wrench.png`
is preserved as the earlier provisional icon. Earlier candidates are
preserved in `../IconCandidates/`. No new image generation is needed for export.

## Export

From the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift -module-cache-path /tmp/Toolbox-Icon-ModuleCache Design/AppIcon/export.swift
```

The AppKit export script scales the selected artwork into a rounded macOS tile
with transparent outside margins, then writes 16–1024 px PNGs to
`Toolbox/Assets.xcassets/AppIcon.appiconset`. This is the conventional macOS asset
catalog path for the current macOS 15+ target, not a layered Icon Composer asset.
The existing Debug/Release `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` setting
and synchronized project group include the catalog without project-file edits.

Original generation brief: an orange/coral folded ribbon forming a compact open
utility container with peach interior planes on ivory, architectural geometry,
restrained light and no text. Generated with the built-in imagegen tool.

This raster catalog is provisional. TODO UX-003 tracks rebuilding the artwork
in a dedicated design app and Icon Composer with Apple templates, layered
resources, appearance variants, and real Dock comparison before release.
