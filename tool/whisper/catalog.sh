#!/bin/sh
# Prints the byte count and sha256 of every model and Core ML encoder in the
# whisper catalog, the only source for the numbers in whisper_catalog.dart.
# Downloads ~3.4 GB.
set -e
HOST="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
FILES="ggml-tiny-q5_1.bin ggml-base-q5_1.bin ggml-small-q5_1.bin ggml-medium-q5_0.bin ggml-large-v3-turbo-q5_0.bin"
FILES="$FILES ggml-tiny-encoder.mlmodelc.zip ggml-base-encoder.mlmodelc.zip ggml-small-encoder.mlmodelc.zip ggml-medium-encoder.mlmodelc.zip ggml-large-v3-turbo-encoder.mlmodelc.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for m in $FILES; do
  curl -fsSL "$HOST/$m" -o "$TMP/$m"
  printf '%s %s %s\n' "$m" "$(wc -c < "$TMP/$m" | tr -d ' ')" "$(shasum -a 256 "$TMP/$m" | cut -d' ' -f1)"
  rm -f "$TMP/$m"
done
