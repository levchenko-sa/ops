#!/usr/bin/env bash
set -u
printf 'Flutter: '
command -v flutter || true
printf 'Dart: '
command -v dart || true
printf 'Java: '
command -v java || true
printf 'ADB: '
command -v adb || true
printf '\n'
flutter --version 2>/dev/null || true
printf '\n'
flutter doctor -v 2>/dev/null || true
