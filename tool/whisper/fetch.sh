#!/bin/sh
# Fetches the prebuilt whisper.cpp xcframework the transcriber plugin links
# against. Pinned by release tag and zip hash; the checkout never carries it.
set -e
TAG=b4938
SHA256=dcc6cdc6d6902d11893434ceda70c23a2a64450f65a1b570035c9908988dfedd

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEST="$ROOT/packages/transcriber/ios/transcriber/whisper.xcframework"
STAMP="$DEST.tag"

if [ -d "$DEST" ] && [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$TAG $SHA256" ]; then
  echo "whisper.xcframework $TAG present"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
URL="https://github.com/ggml-org/whisper.cpp/releases/download/$TAG/whisper-$TAG-xcframework.zip"
curl -fsSL "$URL" -o "$TMP/whisper.zip"
echo "$SHA256  $TMP/whisper.zip" | shasum -a 256 -c - >/dev/null \
  || { echo "whisper-$TAG-xcframework.zip does not match the pinned sha256" >&2; exit 1; }
unzip -q "$TMP/whisper.zip" -d "$TMP/unzipped"
rm -rf "$DEST" "$STAMP"
mv "$TMP/unzipped/build-apple/whisper.xcframework" "$DEST"
echo "$TAG $SHA256" > "$STAMP"
echo "whisper.xcframework $TAG fetched"
