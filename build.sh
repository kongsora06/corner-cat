#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
app_path="${1:-$project_dir/../角落有喵.app}"
stage_dir="$(mktemp -d /private/tmp/cornercat-build.XXXXXX)"
trap 'rm -rf "$stage_dir"' EXIT
bundle_path="$stage_dir/$(basename "$app_path")"
archive_path="${app_path%.app}-macOS.zip"
bundle_id="studio.cornercat.desktop"
if [ "${2:-}" = "qa" ]; then bundle_id="studio.cornercat.desktop.qa"; fi
mkdir -p "$bundle_path/Contents/MacOS" "$bundle_path/Contents/Resources"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
    "$project_dir"/Source/*.swift \
    -framework AppKit -framework SwiftUI -framework Carbon \
    -o "$bundle_path/Contents/MacOS/CornerCat"
cp "$project_dir/Assets/AppIcon.icns" "$bundle_path/Contents/Resources/AppIcon.icns"
cat > "$bundle_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CornerCat</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleName</key><string>CornerCat</string>
<key>CFBundleDisplayName</key><string>角落有喵</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticTermination</key><false/>
</dict></plist>
PLIST
# Sign and archive outside synced folders, which can attach Finder metadata to
# an app after signing. The ZIP keeps the signed bundle independent of that.
codesign --force --sign - "$bundle_path"
codesign --verify --deep --strict "$bundle_path"
ditto -c -k --norsrc --noextattr --keepParent "$bundle_path" "$stage_dir/game.zip"
mkdir -p "$(dirname "$app_path")"
cp "$stage_dir/game.zip" "$archive_path"
ditto --norsrc --noextattr "$bundle_path" "$app_path"
printf 'Built: %s\n' "$app_path"
printf 'Verified archive: %s\n' "$archive_path"
