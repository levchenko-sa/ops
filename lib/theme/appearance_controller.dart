import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'app_themes.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController._();

  static final AppearanceController instance = AppearanceController._();

  AppThemeChoice _themeChoice = AppThemeChoice.light;
  double _textScale = 1.0;

  AppThemeChoice get themeChoice => _themeChoice;
  double get textScale => _textScale;

  bool get largeText => _textScale > 1.03;

  Future<void> load() async {
    final db = await AppDatabase.instance.database;

    final rows = await db.query(
      'app_settings',
      where: 'key IN (?, ?)',
      whereArgs: [
        'appearance_theme',
        'appearance_text_scale',
      ],
    );

    final values = <String, String>{};
    for (final row in rows) {
      values[row['key'] as String] = row['value'] as String;
    }

    _themeChoice = AppThemeChoiceX.fromStorage(
      values['appearance_theme'],
    );

    final storedScale = double.tryParse(
      values['appearance_text_scale'] ?? '',
    );
    _textScale = (storedScale ?? 1.0).clamp(1.0, 1.12).toDouble();

    notifyListeners();
  }

  Future<void> setTheme(AppThemeChoice choice) async {
    if (_themeChoice == choice) return;

    _themeChoice = choice;
    notifyListeners();

    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {
        'key': 'appearance_theme',
        'value': choice.storageValue,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setLargeText(bool enabled) async {
    final next = enabled ? 1.08 : 1.0;
    if (_textScale == next) return;

    _textScale = next;
    notifyListeners();

    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {
        'key': 'appearance_text_scale',
        'value': next.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
