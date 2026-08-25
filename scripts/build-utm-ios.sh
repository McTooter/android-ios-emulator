#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UTM_DIR="$ROOT_DIR/vendor/UTM"
OUTPUT_DIR="${1:-$ROOT_DIR/artifacts}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script must run on macOS with Xcode installed." >&2
  exit 2
fi

mkdir -p "$OUTPUT_DIR"
cd "$UTM_DIR"

# UTM’s own dependency/sysroot setup is intentionally delegated to its upstream
# scripts. This produces an unsigned iOS archive for later user-side signing.
./scripts/build_dependencies.sh -p ios -a arm64
./scripts/build_utm.sh -k iphoneos -s iOS -a arm64 -o "$OUTPUT_DIR/UTM"

APP_PATH="$(find "$OUTPUT_DIR/UTM.xcarchive" -type d -name '*.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "UTM archive did not contain an application bundle." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/Payload"
cp -R "$APP_PATH" "$OUTPUT_DIR/Payload/"
ditto -c -k --sequesterRsrc --keepParent "$OUTPUT_DIR/Payload" "$OUTPUT_DIR/UTM-unsigned-payload.zip"
echo "Created unsigned UTM payload at $OUTPUT_DIR/UTM-unsigned-payload.zip"
