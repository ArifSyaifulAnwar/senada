#!/usr/bin/env bash
set -euo pipefail
TARGET="${1:-android}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"
BUILD_NAME="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+)(\+[0-9]+)?[[:space:]]*$/\1/p' pubspec.yaml | head -n 1)"
BUILD_NUMBER="$(( $(date -u +%s) / 60 ))"
[[ -n "$BUILD_NAME" ]] || { printf '%s\n' 'Version tidak ditemukan di pubspec.yaml.' >&2; exit 1; }
printf 'Build target : %s\nBuild name   : %s\nBuild number : %s\n' "$TARGET" "$BUILD_NAME" "$BUILD_NUMBER"
printf '%s\n' 'pubspec.yaml tidak akan diubah.'
flutter clean
flutter pub get
build_android() {
  flutter build appbundle --release --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
  cp build/app/outputs/bundle/release/app-release.aab "build/app/outputs/bundle/release/senada-$BUILD_NAME+$BUILD_NUMBER.aab"
}
build_ios() {
  [[ "$(uname -s)" == "Darwin" ]] || { printf '%s\n' 'Build iOS hanya dapat dijalankan di macOS dengan Xcode.' >&2; exit 1; }
  flutter build ipa --release --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER"
}
build_web() {
  flutter build web --release --build-name="$BUILD_NAME" --build-number="$BUILD_NUMBER" \
    --dart-define="APP_VERSION=$BUILD_NAME" --dart-define="APP_BUILD_NUMBER=$BUILD_NUMBER"
}
case "$TARGET" in
  android) build_android ;;
  ios) build_ios ;;
  web) build_web ;;
  all)
    build_android
    build_web
    if [[ "$(uname -s)" == "Darwin" ]]; then build_ios; else printf '%s\n' 'iOS dilewati karena bukan macOS.'; fi
    ;;
  *) printf 'Target tidak dikenal: %s\n' "$TARGET" >&2; exit 1 ;;
esac
