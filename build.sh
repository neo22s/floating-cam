#!/usr/bin/env bash
# Floating Camera — MIT License. See LICENSE.
set -euo pipefail

APP_NAME="FloatingCamera"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
SOURCES_DIR="$ROOT/Sources"
INFO_PLIST="$ROOT/Info.plist"
ENTITLEMENTS="$ROOT/FloatingCamera.entitlements"
ICON="$ROOT/AppIcon.icns"
MIN_MACOS="14.0"

ARCH="$(uname -m)"
UNIVERSAL=false
INSTALL=false
SIGN_IDENTITY=""

usage() {
    cat <<'EOF'
Usage: ./build.sh [options]

Options:
  --universal          Build a universal binary (arm64 + x86_64)
  --arm64              Build for Apple Silicon only
  --intel              Build for Intel only
  --install            Build, install to /Applications and launch
  --sign IDENTITY      Code sign with a Developer ID identity
  -h, --help           Show this help

Examples:
  ./build.sh
  ./build.sh --universal
  ./build.sh --install
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --universal) UNIVERSAL=true; shift ;;
        --arm64)     ARCH="arm64"; shift ;;
        --intel)     ARCH="x86_64"; shift ;;
        --install)   INSTALL=true; shift ;;
        --sign)
            if [[ $# -lt 2 || "$2" == --* ]]; then
                echo "error: --sign requires an identity" >&2
                exit 1
            fi
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if ! command -v swiftc >/dev/null 2>&1; then
    echo "error: swiftc not found. Install Xcode Command Line Tools: xcode-select --install" >&2
    exit 1
fi

if [[ ! -d "$SOURCES_DIR" || ! -f "$INFO_PLIST" ]]; then
    echo "error: run this script from the project root" >&2
    exit 1
fi

echo "Building Floating Camera..."
swiftc --version | head -1

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$INFO_PLIST" "$APP_BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

GITHUB_OWNER="${FC_GITHUB_OWNER:-}"
GITHUB_REPO="${FC_GITHUB_REPO:-}"
if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
    GITHUB_OWNER="${GITHUB_REPOSITORY%%/*}"
    GITHUB_REPO="${GITHUB_REPOSITORY#*/}"
fi
if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" ]]; then
    REMOTE_URL="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
    if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+)$ ]]; then
        GITHUB_OWNER="${BASH_REMATCH[1]}"
        GITHUB_REPO="${BASH_REMATCH[2]%.git}"
    fi
fi
if [[ -n "$GITHUB_OWNER" && -n "$GITHUB_REPO" ]]; then
    /usr/libexec/PlistBuddy -c "Set :FCGitHubOwner $GITHUB_OWNER" "$APP_BUNDLE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :FCGitHubRepo $GITHUB_REPO" "$APP_BUNDLE/Contents/Info.plist"
    echo "Updates: $GITHUB_OWNER/$GITHUB_REPO"
else
    echo "Updates: disabled (set GITHUB_REPOSITORY=owner/repo or FC_GITHUB_OWNER/FC_GITHUB_REPO)"
fi
[[ -f "$ICON" ]] && cp "$ICON" "$RESOURCES_DIR/AppIcon.icns"
if [[ -d "$ROOT/Resources" ]]; then
    cp -R "$ROOT/Resources/." "$RESOURCES_DIR/"
fi

COMMON_FLAGS=(
    -O
    -framework AppKit
    -framework AVFoundation
    -framework CoreMedia
    -framework QuartzCore
    -framework Carbon
)

build_binary() {
    local arch="$1"
    local output="$2"
    swiftc "${COMMON_FLAGS[@]}" -target "${arch}-apple-macos${MIN_MACOS}" \
        "$SOURCES_DIR"/*.swift -o "$output"
}

if $UNIVERSAL; then
    echo "Compiling arm64 and x86_64..."
    build_binary arm64 "/tmp/${APP_NAME}_arm64"
    build_binary x86_64 "/tmp/${APP_NAME}_x86_64"
    lipo -create "/tmp/${APP_NAME}_arm64" "/tmp/${APP_NAME}_x86_64" \
        -output "$MACOS_DIR/$APP_NAME"
    rm -f "/tmp/${APP_NAME}_arm64" "/tmp/${APP_NAME}_x86_64"
else
    echo "Compiling $ARCH..."
    build_binary "$ARCH" "$MACOS_DIR/$APP_NAME"
fi

chmod +x "$MACOS_DIR/$APP_NAME"

if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "Signing with: $SIGN_IDENTITY"
    codesign --force --deep --sign "$SIGN_IDENTITY" \
        --entitlements "$ENTITLEMENTS" --options runtime "$APP_BUNDLE"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
fi
codesign --verify --deep --strict "$APP_BUNDLE"
echo "Built: $APP_BUNDLE"

if $INSTALL; then
    echo "Installing to /Applications..."
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP_BUNDLE" "/Applications/"
    open "/Applications/$APP_NAME.app"
    echo "Installed: /Applications/$APP_NAME.app"
else
    echo "Run with: open \"$APP_BUNDLE\""
fi
