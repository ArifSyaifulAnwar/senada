#!/usr/bin/env bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_NAME="$(sed -nE 's/^version:[[:space:]]*([^+[:space:]]+)(\+[0-9]+)?[[:space:]]*$/\1/p' "$PROJECT_ROOT/pubspec.yaml" | head -n 1)"
BUILD_NUMBER="$(( $(date -u +%s) / 60 ))"
printf '%s+%s\n' "$BUILD_NAME" "$BUILD_NUMBER"
printf '%s\n' 'pubspec.yaml tidak diubah.'
