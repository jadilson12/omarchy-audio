#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
swift build -c "$configuration" --product OmarchyAudio
binary="$(swift build -c "$configuration" --show-bin-path)/OmarchyAudio"
app="build/Omarchy Audio.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" build/AppIcon.iconset
if [[ ! -f Resources/AppIcon.icns ]]; then
    swift scripts/make-icon.swift build/AppIcon.iconset
    iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
fi
# Replace the inode: truncating a running signed executable can make macOS kill
# that instance when it next faults a code page into memory.
cp "$binary" "$app/Contents/MacOS/OmarchyAudio.next"
mv -f "$app/Contents/MacOS/OmarchyAudio.next" "$app/Contents/MacOS/OmarchyAudio"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$app/Contents/PkgInfo"
codesign --force --sign - --identifier dev.jadilson.omarchy-audio "$app"
printf '\nApp pronto: %s/%s\n' "$PWD" "$app"
