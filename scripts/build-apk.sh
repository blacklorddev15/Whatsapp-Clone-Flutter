#!/usr/bin/env bash
#
# Builds the release APK and saves it under the product name, so the artifact a user
# downloads is "Varnox-App.apk" rather than Flutter's default "app-release.apk".
#
#   ./scripts/build-apk.sh            # release APK, signed with the debug key by default
#   ./scripts/build-apk.sh --split    # per-ABI APKs, each renamed with its ABI
#
# Requires the Flutter SDK on PATH. This project pins Dart <3.0.0 in pubspec.yaml, so it needs
# Flutter 2.x (Flutter 3 ships Dart 3 and will refuse to resolve the dependencies).
#
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is not on PATH. Install Flutter 2.x (Dart <3.0.0) and retry." >&2
  exit 1
fi

echo "Flutter: $(flutter --version | head -1)"
flutter pub get
flutter build apk --release "$@"

out_dir="build/app/outputs/flutter-apk"
if [ ! -d "$out_dir" ]; then
  echo "Expected build output in $out_dir, found nothing." >&2
  exit 1
fi

# --split-per-abi produces app-<abi>-release.apk; otherwise a single app-release.apk.
if [ -f "$out_dir/app-release.apk" ]; then
  cp "$out_dir/app-release.apk" "Varnox-App.apk"
  echo "wrote Varnox-App.apk ($(du -h Varnox-App.apk | cut -f1))"
else
  found=0
  for f in "$out_dir"/app-*-release.apk; do
    [ -f "$f" ] || continue
    abi=$(basename "$f" | sed 's/^app-//; s/-release\.apk$//')
    cp "$f" "Varnox-App-$abi.apk"
    echo "wrote Varnox-App-$abi.apk ($(du -h "Varnox-App-$abi.apk" | cut -f1))"
    found=1
  done
  [ "$found" = "1" ] || { echo "No APK produced in $out_dir." >&2; exit 1; }
fi
