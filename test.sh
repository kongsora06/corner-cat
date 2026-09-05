#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/cornercat-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc "$project_dir/Source/GameCore.swift" "$project_dir/Tests/GameCoreTests.swift" -o "$test_dir/game-tests"
"$test_dir/game-tests"
xcrun swiftc "$project_dir/Source/FishingCore.swift" "$project_dir/Tests/FishingTests.swift" -o "$test_dir/fishing-tests"
"$test_dir/fishing-tests"
if [ "${1:-}" = "--desktop" ]; then
    xcrun swiftc -swift-version 5 -D TESTING "$project_dir"/Source/*.swift "$project_dir/Tests/DesktopSmokeTests.swift" \
        -framework AppKit -framework SwiftUI -framework Carbon -o "$test_dir/desktop-tests"
    "$test_dir/desktop-tests"
fi
