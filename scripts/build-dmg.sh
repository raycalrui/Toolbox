#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/.." && pwd)"
task_build="$(mktemp -d /tmp/Toolbox-Release.XXXXXX)"
task_stage="$(mktemp -d /tmp/Toolbox-DMG.XXXXXX)"
task_version="0.1.0"
task_output="$task_root/dist/Toolbox-$task_version.dmg"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
mkdir -p "$task_root/dist"
if [[ -e "$task_output" ]]; then
    echo "Output already exists: $task_output. Move it aside before rebuilding." >&2
    exit 1
fi

xcodebuild -project "$task_root/Toolbox.xcodeproj" -scheme Toolbox \
    -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath "$task_build" ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO build > "$task_build/build.log" 2>&1 || {
    tail -n 60 "$task_build/build.log" >&2
    exit 1
}
task_app="$task_stage/Toolbox.app"
ditto "$task_build/Build/Products/Release/Toolbox.app" "$task_app"
mkdir -p "$task_app/Contents/Resources/Licenses"
cp "$task_root/LICENSE" "$task_app/Contents/Resources/Licenses/Toolbox-MIT.txt"
cp "$task_root/THIRD_PARTY_NOTICES.md" "$task_app/Contents/Resources/Licenses/"
cp "$task_root/Toolbox/SubtitleTool/OpenCC/LICENSE" "$task_app/Contents/Resources/Licenses/OpenCC-Apache-2.0.txt"
cp "$task_root/Toolbox/SubtitleTool/OpenCC/ATTRIBUTION.md" "$task_app/Contents/Resources/Licenses/OpenCC-ATTRIBUTION.md"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$task_app"
else
    codesign --force --sign - "$task_app"
fi
codesign --verify --strict --verbose=2 "$task_app"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    [[ -n "${SIGN_IDENTITY:-}" ]] || { echo "Notarization requires SIGN_IDENTITY" >&2; exit 1; }
    ditto -c -k --keepParent "$task_app" "$task_build/Toolbox.zip"
    xcrun notarytool submit "$task_build/Toolbox.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$task_app"
    xcrun stapler validate "$task_app"
fi

ln -s /Applications "$task_stage/Applications"
cp "$task_root/docs/INSTALL.md" "$task_stage/Installation.txt"
hdiutil create -volname Toolbox -srcfolder "$task_stage" -format UDZO "$task_output"
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --timestamp --sign "$SIGN_IDENTITY" "$task_output"
fi
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$task_output" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$task_output"
    xcrun stapler validate "$task_output"
fi
hdiutil verify "$task_output"
(cd "$task_root/dist" && shasum -a 256 "Toolbox-$task_version.dmg" > SHA256SUMS)
echo "Build log: $task_build/build.log"
echo "DMG: $task_output"
echo "Notarized: $([[ -n "${NOTARY_PROFILE:-}" ]] && echo yes || echo no)"
