#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

archive="${1:?Usage: bash scripts/package-dmg.sh path/to/app.zip}"
archive="$(cd "$(dirname "$archive")" && pwd)/$(basename "$archive")"
image="${archive%.zip}.dmg"
task_staging="$(mktemp -d "$PWD/build/dmg.XXXXXX")"
mounted=false
cleanup() {
    if [[ "$mounted" == true ]]; then
        hdiutil detach "$task_staging/mount" -quiet || return
    fi
    rm -rf "$task_staging"
}
trap cleanup EXIT

mkdir "$task_staging/content" "$task_staging/mount"
ditto -x -k "$archive" "$task_staging/content"
codesign --verify --deep --strict "$task_staging/content/Omarchy Audio.app"
ln -s /Applications "$task_staging/content/Applications"

hdiutil create -volname "Omarchy Audio" -srcfolder "$task_staging/content" \
    -format UDZO -ov "$image"
hdiutil verify "$image"
hdiutil attach "$image" -readonly -nobrowse -mountpoint "$task_staging/mount" -quiet
mounted=true
codesign --verify --deep --strict "$task_staging/mount/Omarchy Audio.app"
cmp "$task_staging/content/Omarchy Audio.app/Contents/MacOS/OmarchyAudio" \
    "$task_staging/mount/Omarchy Audio.app/Contents/MacOS/OmarchyAudio"
cmp "$task_staging/content/LICENSE" "$task_staging/mount/LICENSE"
[[ "$(readlink "$task_staging/mount/Applications")" == /Applications ]]
hdiutil detach "$task_staging/mount" -quiet
mounted=false

(
    cd "$(dirname "$archive")"
    shasum -a 256 "$(basename "$archive")" "$(basename "$image")" > SHA256SUMS.txt
    shasum -a 256 -c SHA256SUMS.txt
)
printf '\nDisk image: %s\n' "$image"
