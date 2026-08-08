# Build status — OPS Control v9.5.6

## Выполнено в текущей среде

- функциональный baseline v9.5.5 скопирован без изменений схемы данных;
- app version повышена до 9.5.6+1;
- SQLite schema оставлена v15;
- стабильный Android application ID зафиксирован как `ru.opscontrol.app`;
- добавлен воспроизводимый Android scaffold generator;
- добавлен GitHub Actions build pipeline на Flutter 3.44.8 stable;
- добавлены unit tests для утреннего parser и QR parser;
- добавлен SQL migration checker;
- SQL schema v1 -> v15 реально исполнена в SQLite: PASS;
- проверены relative Dart imports: PASS;
- AndroidManifest XML: PASS;
- shell scripts syntax: PASS.

## Что ещё НЕ подтверждено

В текущем runtime отсутствуют Flutter SDK, Dart SDK, Android SDK и ADB.
Поэтому здесь пока невозможно честно поставить отметки:

```text
flutter pub get   NOT RUN
flutter analyze   NOT RUN
flutter test      NOT RUN
flutter build apk NOT RUN
```

Это не заменено структурными проверками.

## Следующий gate

Запустить `.github/workflows/android-build.yml` в GitHub Actions либо
`bash tool/build_debug.sh` на машине с Flutter/Android SDK.

Первый успешный результат должен дать:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

После этого начинается установка на реальный Android-телефон и smoke-test.
