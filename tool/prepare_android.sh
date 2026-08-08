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

echo "== Generate clean Android scaffold with current Flutter =="
flutter create \
  --platforms=android \
  --org ru.opscontrol \
  --project-name app \
  --no-pub \
  "$TMP/app"

rm -rf "$ROOT/android"
cp -a "$TMP/app/android" "$ROOT/android"

MANIFEST="$ROOT/android/app/src/main/AndroidManifest.xml"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ОШИБКА: AndroidManifest.xml не создан Flutter SDK." >&2
  exit 3
fi

# IMPORTANT:
# Do NOT replace Flutter's generated manifest. Keep its exact modern
# embedding configuration and only patch label + permissions.
python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")

permissions = [
    '<uses-permission android:name="android.permission.INTERNET"/>',
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>',
    '<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>',
    '<uses-permission android:name="android.permission.CAMERA"/>',
]

# Insert only missing permissions, immediately after <manifest ...>.
missing = [x for x in permissions if x not in text]
if missing:
    end = text.find(">")
    if end < 0:
        raise SystemExit("Invalid AndroidManifest.xml")
    insertion = "\n    " + "\n    ".join(missing)
    text = text[:end+1] + insertion + text[end+1:]

# Preserve all Flutter-generated application attributes; change label only.
text = text.replace('android:label="app"', 'android:label="OPS Control"')

p.write_text(text, encoding="utf-8")
PY

# Copy documentation only; never overwrite the generated manifest.
mkdir -p "$ROOT/android"
[[ -f "$ROOT/tool/android_docs/LITE_BUILD.md" ]] && \
  cp "$ROOT/tool/android_docs/LITE_BUILD.md" "$ROOT/android/LITE_BUILD.md"
[[ -f "$ROOT/tool/android_docs/UPDATE_RULES.md" ]] && \
  cp "$ROOT/tool/android_docs/UPDATE_RULES.md" "$ROOT/android/UPDATE_RULES.md"

echo "== Android embedding preflight =="

# Flutter's own current check classifies the app as v2 only when this marker
# is present with value 2.
if ! grep -A2 -B1 'android:name="flutterEmbedding"' "$MANIFEST" | \
     grep -q 'android:value="2"'; then
  echo "ОШИБКА: flutterEmbedding=2 отсутствует." >&2
  cat "$MANIFEST" >&2
  exit 4
fi

if grep -R --fixed-strings 'io.flutter.app.FlutterApplication' \
    "$ROOT/android/app/src" >/dev/null 2>&1; then
  echo "ОШИБКА: найден FlutterApplication из Android embedding v1." >&2
  grep -R -n --fixed-strings 'io.flutter.app.FlutterApplication' \
    "$ROOT/android/app/src" >&2 || true
  exit 5
fi

if grep -R --fixed-strings 'io.flutter.app.FlutterActivity' \
    "$ROOT/android/app/src" >/dev/null 2>&1; then
  echo "ОШИБКА: найден FlutterActivity из Android embedding v1." >&2
  grep -R -n --fixed-strings 'io.flutter.app.FlutterActivity' \
    "$ROOT/android/app/src" >&2 || true
  exit 6
fi

if ! grep -R --fixed-strings 'io.flutter.embedding.android.FlutterActivity' \
    "$ROOT/android/app/src/main" >/dev/null 2>&1; then
  echo "ОШИБКА: современный FlutterActivity v2 не найден." >&2
  find "$ROOT/android/app/src/main" -maxdepth 8 -type f -print >&2
  exit 7
fi

if ! grep -R --fixed-strings 'ru.opscontrol.app' \
    "$ROOT/android/app" >/dev/null 2>&1; then
  echo "ОШИБКА: стабильный application id ru.opscontrol.app не найден." >&2
  exit 8
fi

echo "Android scaffold OK"
echo "Application ID: ru.opscontrol.app"
echo "--- AndroidManifest.xml ---"
cat "$MANIFEST"
echo "--- MainActivity ---"
MAIN_ACTIVITY="$(find "$ROOT/android/app/src/main" \( -name MainActivity.kt -o -name MainActivity.java \) | head -n1 || true)"
if [[ -z "$MAIN_ACTIVITY" ]]; then
  echo "ОШИБКА: MainActivity не создан." >&2
  exit 9
fi
cat "$MAIN_ACTIVITY"
