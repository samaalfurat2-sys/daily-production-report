#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:-production_report_app}"
TEMPLATE_PATH="${2:-../frontend_template}"

mkdir -p "$PROJECT_PATH"
pushd "$PROJECT_PATH" >/dev/null
flutter create . --platforms=android,windows
popd >/dev/null

cp -R "$TEMPLATE_PATH"/. "$PROJECT_PATH"/
pushd "$PROJECT_PATH" >/dev/null
flutter pub get
# Generate localisation files (AppLocalizations) required by all screens.
# 'generate: true' in pubspec.yaml is not always honoured in CI without
# running this explicitly, causing "undefined getter AppLocalizations"
# compilation errors on both Android and Windows targets.
flutter gen-l10n
popd >/dev/null
echo "Ready."
