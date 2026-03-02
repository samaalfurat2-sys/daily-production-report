#!/usr/bin/env bash
set -euo pipefail
PROJECT_PATH="${1:-production_report_app}"
TARGET="${2:-apk}"

pushd "$PROJECT_PATH" >/dev/null
if [[ "$TARGET" == "apk" ]]; then
  flutter build apk --release
  echo "$PROJECT_PATH/build/app/outputs/flutter-apk/app-release.apk"
else
  flutter build appbundle --release
  echo "$PROJECT_PATH/build/app/outputs/bundle/release/app-release.aab"
fi
popd >/dev/null
