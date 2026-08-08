import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

class StressTestResult {
  final int requestCount;
  final int reportCount;
  final int photoCount;
  final int insertMs;
  final int historyQueryMs;
  final int openRequestsQueryMs;
  final int databaseBytes;

  const StressTestResult({
    required this.requestCount,
    required this.reportCount,
    required this.photoCount,
    required this.insertMs,
    required this.historyQueryMs,
    required this.openRequestsQueryMs,
    required this.databaseBytes,
  });
}

class StressTestCounts {
  final int requests;
  final int reports;
  final int photos;

  const StressTestCounts({
    required this.requests,
    required this.reports,
    required this.photos,
  });

  bool get hasData => requests > 0 || reports > 0 || photos > 0;
}

class StressTestService {
  static const _eventTypes = <String>[
    'Сработка',
    'Нет контрольного события',
    'Не ставится на охрану',
    'Потеря связи',
    'АКБ разряжена',
  ];

  static const _causes = <String>[
    'Обрыв линии',
    'Нарушение контакта',
    'Разряжена АКБ',
    'Потеря канала связи',
    'Неисправность датчика',
  ];

  static const _workDone = <String>[
    'Восстановлено соединение',
    'Зачищены и протянуты контакты',
    'Заменена АКБ',
    'Проверен и восстановлен канал связи',
    'Заменён датчик',
  ];

  Future<StressTestCounts> counts() async {
    final db = await AppDatabase.instance.database;

    Future<int> count(String table) async {
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM $table WHERE is_test = 1',
      );
      return (rows.first['cnt'] as num?)?.toInt() ?? 0;
    }

    return StressTestCounts(
      requests: await count('requests'),
      reports: await count('work_reports'),
      photos: await count('photos'),
    );
  }

  Future<String> _placeholderPhotoPath() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ops_stress_test'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(p.join(dir.path, 'stress_placeholder.png'));
    if (!await file.exists()) {
      // Валидный PNG 1x1. Один файл используется тысячами тестовых строк:
      // нагрузка идёт на БД/списки, не расходуя сотни мегабайт флеш-памяти.
      const pngBase64 =
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
          'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      await file.writeAsBytes(
        base64Decode(pngBase64),
        flush: true,
      );
    }
    return file.path;
  }

  Future<StressTestResult> generate({
    int requestCount = 10000,
    int photoCount = 3000,
  }) async {
    if (requestCount < 1 || requestCount > 100000) {
      throw ArgumentError('requestCount должен быть 1..100000');
    }
    if (photoCount < 0 || photoCount > 50000) {
      throw ArgumentError('photoCount должен быть 0..50000');
    }

    final existing = await counts();
    if (existing.hasData) {
      throw StateError(
        'Тестовые данные уже существуют. '
        'Сначала удалите предыдущий набор.',
      );
    }

    final db = await AppDatabase.instance.database;
    final objects = await db.query(
      'objects',
      columns: ['id'],
      orderBy: 'id',
    );

    if (objects.isEmpty) {
      throw StateError('Нет объектов для нагрузочного теста');
    }

    final objectIds = objects
        .map((row) => row['id'] as int)
        .toList(growable: false);

    final placeholderPath = await _placeholderPhotoPath();
    final requestIds = <int>[];
    var reportCount = 0;

    final insertWatch = Stopwatch()..start();

    await db.transaction((txn) async {
      for (var i = 0; i < requestCount; i++) {
        final created = DateTime.now()
            .subtract(Duration(minutes: i * 17))
            .toIso8601String();

        final type = _eventTypes[i % _eventTypes.length];
        final completed = i % 4 != 0;
        final status = completed
            ? 'Выполнена'
            : i % 8 == 0
                ? 'В работе'
                : 'Новая';

        final requestId = await txn.insert('requests', {
          'object_id': objectIds[i % objectIds.length],
          'type': type,
          'priority': type == 'Сработка' ? 3 : (i % 3 == 0 ? 2 : 1),
          'status': status,
          'comment': 'НАГРУЗОЧНЫЙ ТЕСТ #$i',
          'created_at': created,
          'updated_at': created,
          'is_test': 1,
        });

        requestIds.add(requestId);

        if (completed) {
          await txn.insert('work_reports', {
            'request_id': requestId,
            'battery_voltage': 12.0 + ((i % 18) / 10.0),
            'loop_resistance_kohm': 1.8 + ((i % 10) / 10.0),
            'cause': _causes[i % _causes.length],
            'work_done': _workDone[i % _workDone.length],
            'result': 'Работоспособность восстановлена',
            'created_at': created,
            'is_test': 1,
          });
          reportCount++;
        }
      }

      if (requestIds.isNotEmpty) {
        for (var i = 0; i < photoCount; i++) {
          await txn.insert('photos', {
            'request_id': requestIds[i % requestIds.length],
            'type': i.isEven ? 'before' : 'after',
            'path': placeholderPath,
            'created_at': DateTime.now()
                .subtract(Duration(minutes: i))
                .toIso8601String(),
            'is_test': 1,
          });
        }
      }
    });

    insertWatch.stop();

    await db.execute('ANALYZE');
    await db.execute('PRAGMA optimize');

    final historyWatch = Stopwatch()..start();
    await db.rawQuery("""
      SELECT
        r.id,
        r.type,
        r.status,
        wr.cause,
        (
          SELECT COUNT(*)
          FROM photos p
          WHERE p.request_id = r.id
        ) AS photo_count
      FROM requests r
      LEFT JOIN work_reports wr ON wr.request_id = r.id
      WHERE r.object_id = ?
      ORDER BY r.created_at DESC
      LIMIT 50
    """, [objectIds.first]);
    historyWatch.stop();

    final openWatch = Stopwatch()..start();
    await db.rawQuery("""
      SELECT r.id, r.type, r.priority, r.status, o.address
      FROM requests r
      JOIN objects o ON o.id = r.object_id
      WHERE r.status != 'Выполнена'
      ORDER BY r.priority DESC, r.created_at ASC
      LIMIT 200
    """);
    openWatch.stop();

    final dbPath = await AppDatabase.instance.databasePath;
    final dbFile = File(dbPath);
    final dbBytes = await dbFile.exists() ? await dbFile.length() : 0;

    await db.insert('stress_test_runs', {
      'created_at': DateTime.now().toIso8601String(),
      'request_count': requestCount,
      'photo_count': photoCount,
      'insert_ms': insertWatch.elapsedMilliseconds,
      'history_query_ms': historyWatch.elapsedMilliseconds,
      'open_requests_query_ms': openWatch.elapsedMilliseconds,
      'database_bytes': dbBytes,
    });

    return StressTestResult(
      requestCount: requestCount,
      reportCount: reportCount,
      photoCount: photoCount,
      insertMs: insertWatch.elapsedMilliseconds,
      historyQueryMs: historyWatch.elapsedMilliseconds,
      openRequestsQueryMs: openWatch.elapsedMilliseconds,
      databaseBytes: dbBytes,
    );
  }

  Future<StressTestResult> benchmarkCurrent() async {
    final db = await AppDatabase.instance.database;
    final countData = await counts();

    final objects = await db.query(
      'objects',
      columns: ['id'],
      orderBy: 'id',
      limit: 1,
    );
    if (objects.isEmpty) {
      throw StateError('Нет объектов');
    }

    final objectId = objects.first['id'] as int;

    final historyWatch = Stopwatch()..start();
    await db.rawQuery("""
      SELECT
        r.id,
        r.type,
        r.status,
        wr.cause,
        (
          SELECT COUNT(*)
          FROM photos p
          WHERE p.request_id = r.id
        ) AS photo_count
      FROM requests r
      LEFT JOIN work_reports wr ON wr.request_id = r.id
      WHERE r.object_id = ?
      ORDER BY r.created_at DESC
      LIMIT 50
    """, [objectId]);
    historyWatch.stop();

    final openWatch = Stopwatch()..start();
    await db.rawQuery("""
      SELECT r.id, r.type, r.priority, r.status, o.address
      FROM requests r
      JOIN objects o ON o.id = r.object_id
      WHERE r.status != 'Выполнена'
      ORDER BY r.priority DESC, r.created_at ASC
      LIMIT 200
    """);
    openWatch.stop();

    final dbPath = await AppDatabase.instance.databasePath;
    final dbFile = File(dbPath);

    return StressTestResult(
      requestCount: countData.requests,
      reportCount: countData.reports,
      photoCount: countData.photos,
      insertMs: 0,
      historyQueryMs: historyWatch.elapsedMilliseconds,
      openRequestsQueryMs: openWatch.elapsedMilliseconds,
      databaseBytes: await dbFile.exists() ? await dbFile.length() : 0,
    );
  }

  Future<StressTestCounts> purge() async {
    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      await txn.delete('photos', where: 'is_test = 1');
      await txn.delete('work_reports', where: 'is_test = 1');
      await txn.delete('requests', where: 'is_test = 1');
    });

    await db.execute('ANALYZE');
    await db.execute('PRAGMA optimize');
    await db.execute('VACUUM');

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ops_stress_test'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }

    return counts();
  }

  Future<List<Map<String, Object?>>> recentRuns() async {
    final db = await AppDatabase.instance.database;
    return db.query(
      'stress_test_runs',
      orderBy: 'created_at DESC',
      limit: 10,
    );
  }
}
