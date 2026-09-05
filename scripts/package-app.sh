#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/build-app.sh release

app="build/Omarchy Audio.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
architecture="$(uname -m)"
archive="Omarchy-Audio-v${version}-macos-${architecture}.zip"
staging="$(mktemp -d "$PWD/build/package.XXXXXX")"
trap 'rm -rf "$staging"' EXIT

codesign --verify --deep --strict "$app"
mkdir -p build/release
ditto "$app" "$staging/Omarchy Audio.app"
cp LICENSE "$staging/LICENSE"
ditto -c -k --sequesterRsrc "$staging" "build/release/$archive"

mkdir "$staging/verify"
ditto -x -k "build/release/$archive" "$staging/verify"
codesign --verify --deep --strict "$staging/verify/Omarchy Audio.app"
cmp LICENSE "$staging/verify/LICENSE"

(
    cd build/release
    shasum -a 256 "$archive" > SHA256SUMS.txt
    shasum -a 256 -c SHA256SUMS.txt
)
printf '\nRelease archive: %s/build/release/%s\n' "$PWD" "$archive"
