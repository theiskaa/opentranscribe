#!/bin/sh
# The checks CI runs, runnable locally. Keep codemagic.yaml calling this.
set -e
flutter analyze
(cd packages/transcriber && flutter analyze)
(cd packages/reflections && flutter analyze)
dart format --output=none --set-exit-if-changed lib test packages/transcriber packages/reflections
flutter test
(cd packages/transcriber && flutter test)
(cd packages/reflections && flutter test)
(cd packages/liquid && flutter test)
# TranscriberCore's tests, the only Swift in the repo a check can run. Builds for
# the host, so TranscriberCore must stay free of iOS-only API.
(cd packages/transcriber/ios/transcriber/Core && swift test)

V=$(grep '^version:' pubspec.yaml | sed -E 's/version:[[:space:]]*//; s/\+.*//')
grep -q "^## $V " CHANGELOG.md || { echo "CHANGELOG.md has no section for $V"; exit 1; }
