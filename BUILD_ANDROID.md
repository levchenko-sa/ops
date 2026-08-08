# OPS Control v9.5.6 — Android build candidate

## Зафиксированная среда

- Flutter: **3.44.8 stable**
- Dart: версия, поставляемая с Flutter 3.44.8
- Android applicationId: **ru.opscontrol.app**
- SQLite schema: **v15**
- Java для CI: **17**

Flutter 3.44.8 выбран как стабильная hotfix-ветка 3.44. Android scaffold не хранится как вручную собранный набор Gradle-файлов: перед сборкой он воспроизводимо генерируется самим закреплённым Flutter SDK. Это уменьшает риск несовместимости Gradle / AGP / Kotlin.

## Один локальный запуск

На компьютере с установленными Flutter и Android SDK:

```bash
bash tool/doctor.sh
bash tool/build_debug.sh
```

После успешной сборки APK находится здесь:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

Рядом создаётся SHA-256 checksum.

## Что делает build_debug.sh

1. Генерирует чистый Android scaffold через `flutter create`.
2. Проверяет стабильный package id `ru.opscontrol.app`.
3. Накладывает AndroidManifest OPS Control с Camera / Location / Internet.
4. Исполняет SQL миграций v1 -> v15 в тестовой SQLite базе.
5. Выполняет `flutter pub get`.
6. Выполняет `flutter analyze`.
7. Выполняет unit tests.
8. Собирает debug APK.
9. Считает SHA-256 APK.

## GitHub Actions

В проект добавлен workflow:

```text
.github/workflows/android-build.yml
```

После помещения проекта в GitHub он автоматически выполняет те же проверки и прикладывает `app-debug.apk` как artifact сборки.

## Почему пока debug, а не release

Для полевого пилота сначала нужен воспроизводимый APK и исправление фактических compile/runtime ошибок. Постоянный release signing key создаётся только после успешного пилота. После выпуска 1.0 этот ключ нельзя терять: все обновления Android должны подписываться тем же ключом.

## Критерий прохождения этапа

Этап сборки завершён только если одновременно выполнено:

```text
migration check  PASS
flutter analyze  PASS без errors
flutter test     PASS
flutter build apk --debug PASS
app-debug.apk существует
```

Структурная проверка исходников сама по себе этим критерием не считается.
