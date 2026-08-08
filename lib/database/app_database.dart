import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_constants.dart';
import 'migrations.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<String> get databasePath async {
    final root = await getDatabasesPath();
    return join(root, 'ops_control.db');
  }

  Future<Database> get database async {
    if (_db != null) return _db!;

    _db = await openDatabase(
      await databasePath,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA busy_timeout = 5000');
        await db.execute('PRAGMA temp_store = MEMORY');
        // Отрицательное значение cache_size задаётся в KiB:
        // около 4 МБ RAM на SQLite-кэш.
        await db.execute('PRAGMA cache_size = -4096');
      },
      onCreate: (db, version) async {
        await _createV1(db);
        await DatabaseMigrations.migrate(db, 1, version);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // sqflite запускает onUpgrade в транзакции.
        // При ошибке миграция откатывается, а существующие данные остаются.
        await DatabaseMigrations.migrate(db, oldVersion, newVersion);
      },
    );

    return _db!;
  }

  Future<void> close() async {
    final current = _db;
    _db = null;
    if (current != null) {
      await current.close();
    }
  }

  Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE objects(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT NOT NULL UNIQUE,
        system TEXT NOT NULL,
        latitude REAL,
        longitude REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE requests(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        object_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'Новая',
        comment TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(object_id) REFERENCES objects(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE materials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        min_quantity REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seed(Database db) async {
    final objects = [
      ['Энгельса 31', 'Си-Норд AirPro', 56.8350, 60.6170],
      ['Мичурина 214', 'Си-Норд AirPro', 56.8240, 60.6260],
      ['Куйбышева 76', 'Си-Норд AirPro', 56.8230, 60.6090],
      ['Белинского 167', 'Си-Норд AirPro', 56.8038, 60.6307],
      ['Луначарского 181', 'Си-Норд AirPro', 56.8388, 60.6262],
      ['Машинная 40', 'Си-Норд AirPro', 56.8086, 60.6268],
      ['Мичурина 171', 'Си-Норд AirPro', 56.8321, 60.6260],
      ['Тверитина 13', 'Си-Норд AirPro', 56.8218, 60.6207],
      ['Декабристов 51', 'Си-Норд AirPro', 56.8257, 60.6030],
      ['Карла Маркса 50', 'Си-Норд AirPro', 56.8316, 60.6244],
      ['Луначарского 137', 'Си-Норд AirPro', 56.8448, 60.6195],
      ['Мичурина 59', 'Си-Норд AirPro', 56.8500, 60.6167],
      ['Мичурина 76', 'Си-Норд AirPro', 56.8476, 60.6211],
      ['Куйбышева 86/2', 'Си-Норд AirPro', 56.8256, 60.6221],
      ['Энгельса 38', 'Си-Норд AirPro', 56.8330, 60.6212],
    ];

    for (final row in objects) {
      await db.insert('objects', {
        'address': row[0],
        'system': row[1],
        'latitude': row[2],
        'longitude': row[3],
      });
    }

    final materials = [
      ['АКБ 12В 7Ач', 'шт', 8.0, 3.0],
      ['Резистор 2.2 кОм', 'шт', 50.0, 15.0],
      ['Кабель сигнальный', 'м', 120.0, 30.0],
      ['Датчик магнитоконтактный', 'шт', 12.0, 4.0],
      ['SIM-карта', 'шт', 6.0, 2.0],
    ];

    for (final row in materials) {
      await db.insert('materials', {
        'name': row[0],
        'unit': row[1],
        'quantity': row[2],
        'min_quantity': row[3],
      });
    }
  }
}
