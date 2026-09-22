#!/usr/bin/env bash
#
# Vercel build for the Flutter web target.
#
# Vercel has no Flutter runtime, so this fetches the SDK, then builds the static web bundle
# into build/web (which vercel.json publishes as the output directory).
#
# Why 2.5.3: pubspec.yaml declares `sdk: ">=2.7.0 <3.0.0"`, so the project needs Flutter 2.x, and
# the resolved dependency versions pin it further. Flutter 2.10 ships Dart 2.16, which no longer
# has io.Platform.packageRoot (the transitive `platform` 2.2.1 package still calls it) nor
# BasicMessageChannel.setMockMessageHandler (video_player_platform_interface 2.2.0 still calls
# that), so 2.10 fails to compile code that this project never touches. Flutter 2.5.3 carries
# Dart 2.14, where both APIs still exist, and matches the era of these dependencies (camera 0.7,
# video_player 1.0, shared_preferences 0.5 are all early-2021).
#
# Override at build time if needed:  FLUTTER_VERSION=2.2.3 bash scripts/vercel-build-web.sh
#
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-2.5.3}"
FLUTTER_ROOT="/tmp/flutter-sdk"
ARCHIVE="/tmp/flutter-linux.tar.xz"

if [ ! -x "$FLUTTER_ROOT/flutter/bin/flutter" ]; then
  echo "==> Fetching Flutter $FLUTTER_VERSION"
  mkdir -p "$FLUTTER_ROOT"
  curl -fsSL --retry 3 --retry-delay 2 \
    -o "$ARCHIVE" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  echo "==> Extracting ($(du -h "$ARCHIVE" | cut -f1))"
  tar -xJf "$ARCHIVE" -C "$FLUTTER_ROOT"
  rm -f "$ARCHIVE"
else
  echo "==> Reusing cached Flutter at $FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/flutter/bin:$PATH"

# Flutter shells out to git for its own version reporting and refuses to run in a repository
# it considers unsafe (Vercel checks out as a different user than the one that owns the tree).
git config --global --add safe.directory "$FLUTTER_ROOT/flutter" || true
git config --global --add safe.directory "$PWD" || true

flutter --version
flutter config --enable-web
flutter precache --web

echo "==> Resolving dependencies"
flutter pub get

echo "==> Building web bundle"
# The html renderer avoids shipping the CanvasKit wasm payload, which is the safer default for
# a Flutter 2.x build and keeps the first paint fast on mobile browsers.
flutter build web --release --web-renderer html

echo "==> Build output"
ls -la build/web | head -20
