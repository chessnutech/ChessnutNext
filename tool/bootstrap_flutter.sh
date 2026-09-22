#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter CLI was not found. Install Flutter SDK first, then rerun this script." >&2
  exit 1
fi

flutter create --platforms=android,ios,web,macos,windows,linux .
flutter pub get

echo
echo "Chessnut Flutter export is ready."
echo "Run: flutter run"
