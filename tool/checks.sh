#!/bin/sh
# The four-suite check CI runs, runnable locally. Keep codemagic.yaml calling this.
set -e
flutter analyze
(cd packages/transcriber && flutter analyze)
(cd packages/reflections && flutter analyze)
dart format --output=none --set-exit-if-changed lib test packages/transcriber packages/reflections
flutter test
(cd packages/transcriber && flutter test)
(cd packages/reflections && flutter test)
(cd packages/liquid && flutter test)

V=$(grep '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//; s/\+.*//')
grep -q "^## $V " CHANGELOG.md || { echo "CHANGELOG.md has no section for $V"; exit 1; }
