#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <manifest-url> <sha256> <output-directory>" >&2
  exit 2
fi

MANIFEST_URL="$1"
EXPECTED_SHA256="$2"
OUTPUT_DIR="$3"

mkdir -p "$OUTPUT_DIR"
MANIFEST_PATH="$OUTPUT_DIR/manifest.json"

curl --fail --location --proto '=https' --tlsv1.2 "$MANIFEST_URL" -o "$MANIFEST_PATH"
ACTUAL_SHA256="$(shasum -a 256 "$MANIFEST_PATH" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "SHA-256 mismatch for guest manifest" >&2
  echo "expected: $EXPECTED_SHA256" >&2
  echo "actual:   $ACTUAL_SHA256" >&2
  rm -f "$MANIFEST_PATH"
  exit 1
fi

echo "Guest manifest downloaded and checksum verified: $MANIFEST_PATH"
