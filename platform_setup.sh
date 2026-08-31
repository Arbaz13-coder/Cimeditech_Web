#!/usr/bin/env bash
set -euo pipefail
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found in PATH. Install Flutter first."
  exit 1
fi
flutter create --platforms=android,ios,web --org com.cmx .
flutter pub get
echo "Platform files are ready."
