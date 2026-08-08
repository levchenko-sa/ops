#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

"$ROOT/tool/prepare_android.sh"
python3 "$ROOT/tool/check_migrations.py"
flutter pub get
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
flutter build apk --debug

APK="$ROOT/build/app/outputs/flutter-apk/app-debug.apk"
if [[ ! -f "$APK" ]]; then
  echo "APK не найден после сборки: $APK" >&2
  exit 5
fi

sha256sum "$APK" | tee "$ROOT/build/app-debug.apk.sha256"
echo "Готово: $APK"
