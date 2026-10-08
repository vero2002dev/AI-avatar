#!/bin/bash
set -euo pipefail

# Bootstrap the camera app on a Mac with Command Line Tools but no full Xcode.
# The Xcode project and GitHub Actions remain the build/test validation path.
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
architecture="$(uname -m)"
bundle_path="$repo_dir/build/AIAvatar.app"
mkdir -p "$bundle_path/Contents/MacOS" "$repo_dir/build/ModuleCache"

sources=()
while IFS= read -r -d '' source_path; do
    sources+=("$source_path")
done < <(find "$repo_dir/AIAvatar" -name '*.swift' -print0)

xcrun swiftc -parse-as-library -swift-version 5 -O \
    -target "$architecture-apple-macos14.0" \
    -sdk "$sdk_path" -module-name AIAvatar \
    -module-cache-path "$repo_dir/build/ModuleCache" \
    "${sources[@]}" -o "$bundle_path/Contents/MacOS/AIAvatar"

ditto "$repo_dir/AIAvatar/Info.plist" "$bundle_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable AIAvatar' "$bundle_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.vero2002.aiavatar' "$bundle_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName AIAvatar' "$bundle_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :LSMinimumSystemVersion 14.0' "$bundle_path/Contents/Info.plist"

codesign --force --sign - --options runtime \
    --entitlements "$repo_dir/AIAvatar/AIAvatar.entitlements" "$bundle_path"
codesign --verify --deep --strict "$bundle_path"
printf 'Built locally signed camera app: %s\n' "$bundle_path"
