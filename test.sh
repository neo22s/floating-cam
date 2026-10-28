#!/usr/bin/env bash
# Floating Camera — MIT License. See LICENSE.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "▶  Building tests…"
swiftc -O \
    -target "$(uname -m)-apple-macos14.0" \
    -framework AppKit \
    -framework AVFoundation \
    "$ROOT/Sources/AppSettings.swift" \
    "$ROOT/Sources/Localization.swift" \
    "$ROOT/Sources/ShapeGeometry.swift" \
    "$ROOT/Sources/OverlayGeometry.swift" \
    "$ROOT/Sources/Version.swift" \
    "$ROOT/Sources/Updater.swift" \
    "$ROOT/Tests/Main.swift" \
    -o "$TMP/floatingcam-tests"

"$TMP/floatingcam-tests"
