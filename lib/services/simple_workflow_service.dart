import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class SimpleWorkflowService {
  Future<String?> _get(String key) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _set(String key, String value) async {
    final db = await AppDatabase.instance.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> simpleWorkflowEnabled() async {
    return (await _get('simple_workflow')) != '0';
  }

  Future<int?> defaultEngineerId() async {
    final value = await _get('default_engineer_id');
    return int.tryParse(value ?? '');
  }

  Future<void> setDefaultEngineerId(int? engineerId) async {
    await _set(
      'default_engineer_id',
      engineerId?.toString() ?? '',
    );
  }

  Future<bool> autoPrepareWriteoffEnabled() async {
    return (await _get('auto_prepare_writeoff')) != '0';
  }
}
