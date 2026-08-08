#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK не найден в PATH." >&2
  exit 2
fi

cd "$ROOT"

# Генерируем Android scaffold именно тем Flutter SDK, которым будет
# выполняться сборка. Проект temp называется app, поэтому package id
# шаблона сразу получается ru.opscontrol.app.
flutter create \
  --platforms=android \
  --org ru.opscontrol \
  --project-name app \
  --no-pub \
  "$TMP/app"

rm -rf "$ROOT/android"
cp -a "$TMP/app/android" "$ROOT/android"

# Наши разрешения/label поверх чистого Flutter scaffold.
cp "$ROOT/tool/android_overlay/AndroidManifest.xml" \
   "$ROOT/android/app/src/main/AndroidManifest.xml"

cp "$ROOT/tool/android_docs/LITE_BUILD.md" "$ROOT/android/LITE_BUILD.md"
cp "$ROOT/tool/android_docs/UPDATE_RULES.md" "$ROOT/android/UPDATE_RULES.md"

# Защита стабильного Android ID.
if ! grep -R --fixed-strings 'ru.opscontrol.app' "$ROOT/android/app" >/dev/null 2>&1; then
  echo "ОШИБКА: ru.opscontrol.app не найден в Android scaffold." >&2
  exit 3
fi

MAIN_ACTIVITY="$(find "$ROOT/android/app/src/main" -name MainActivity.kt -o -name MainActivity.java | head -n1 || true)"
if [[ -z "$MAIN_ACTIVITY" ]]; then
  echo "ОШИБКА: MainActivity не создан." >&2
  exit 4
fi

echo "Android scaffold подготовлен: $ROOT/android"
echo "Application ID: ru.opscontrol.app"
