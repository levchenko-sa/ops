import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'backup_service.dart';

class StorageStats {
  final int databaseBytes;
  final int photoBytes;
  final int backupBytes;
  final int objectCount;
  final int requestCount;
  final int photoCount;
  final int pendingSyncCount;
  final int sentSyncCount;

  const StorageStats({
    required this.databaseBytes,
    required this.photoBytes,
    required this.backupBytes,
    required this.objectCount,
    required this.requestCount,
    required this.photoCount,
    required this.pendingSyncCount,
    required this.sentSyncCount,
  });

  int get totalBytes => databaseBytes + photoBytes + backupBytes;
}

class MaintenanceResult {
  final int removedMissingPhotoRows;
  final int removedSentSyncRows;
  final int deletedOldBackups;
  final int beforeDatabaseBytes;
  final int afterDatabaseBytes;

  const MaintenanceResult({
    required this.removedMissingPhotoRows,
    required this.removedSentSyncRows,
    required this.deletedOldBackups,
    required this.beforeDatabaseBytes,
    required this.afterDatabaseBytes,
  });
}



class PhotoArchiveResult {
  final String backupPath;
  final int archivedPhotoRows;
  final int deletedPhotoFiles;
  final int freedBytes;

  const PhotoArchiveResult({
    required this.backupPath,
    required this.archivedPhotoRows,
    required this.deletedPhotoFiles,
    required this.freedBytes,
  });
}


class DataMaintenanceService {
  final _backup = BackupService();

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {}
      }
    }
    return total;
  }

  Future<int> _count(Database db, String sql, [List<Object?>? args]) async {
    final rows = await db.rawQuery(sql, args);
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<StorageStats> stats() async {
    final db = await AppDatabase.instance.database;
    final dbPath = await AppDatabase.instance.databasePath;
    final dbFile = File(dbPath);

    final docs = await getApplicationDocumentsDirectory();
    final photoDir = Directory(p.join(docs.path, 'ops_photos'));
    final restoredPhotoDir = Directory(p.join(docs.path, 'ops_photos_restored'));
    final backupDir = Directory(p.join(docs.path, 'ops_backups'));

    final photoBytes =
        await _dirSize(photoDir) + await _dirSize(restoredPhotoDir);

    return StorageStats(
      databaseBytes: await dbFile.exists() ? await dbFile.length() : 0,
      photoBytes: photoBytes,
      backupBytes: await _dirSize(backupDir),
      objectCount: await _count(db, 'SELECT COUNT(*) AS cnt FROM objects'),
      requestCount: await _count(db, 'SELECT COUNT(*) AS cnt FROM requests'),
      photoCount: await _count(db, 'SELECT COUNT(*) AS cnt FROM photos'),
      pendingSyncCount: await _count(
        db,
        'SELECT COUNT(*) AS cnt FROM sync_queue WHERE synced_at IS NULL',
      ),
      sentSyncCount: await _count(
        db,
        'SELECT COUNT(*) AS cnt FROM sync_queue WHERE synced_at IS NOT NULL',
      ),
    );
  }

  Future<MaintenanceResult> safeOptimize({
    int sentSyncRetentionDays = 30,
    int keepLatestBackups = 5,
  }) async {
    // Перед обслуживанием создаём страховочную копию.
    await _backup.createBackup(
      share: false,
      kind: 'pre_optimize',
    );

    final db = await AppDatabase.instance.database;
    final dbPath = await AppDatabase.instance.databasePath;
    final dbFile = File(dbPath);
    final before = await dbFile.exists() ? await dbFile.length() : 0;

    // 1. Убираем из БД только ссылки на реально отсутствующие файлы.
    var removedMissingPhotoRows = 0;
    final photos = await db.query('photos', columns: ['id', 'path']);
    for (final row in photos) {
      final id = row['id'] as int?;
      final path = row['path'] as String?;
      if (id == null || path == null || path.isEmpty) continue;
      if (!await File(path).exists()) {
        removedMissingPhotoRows += await db.delete(
          'photos',
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    }

    // 2. Удаляем ТОЛЬКО подтверждённые сервером элементы sync_queue.
    // Непереданные данные никогда не трогаем.
    final cutoff = DateTime.now()
        .subtract(Duration(days: sentSyncRetentionDays))
        .toIso8601String();

    final removedSentSyncRows = await db.delete(
      'sync_queue',
      where: 'synced_at IS NOT NULL AND synced_at < ?',
      whereArgs: [cutoff],
    );

    // 3. Ротируем только технические pre_optimize-копии.
    // Пользовательские manual/pre_import/archive копии автоматически
    // не удаляем, чтобы оптимизация не приводила к потере архивов.
    final docs = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docs.path, 'ops_backups'));
    var deletedOldBackups = 0;

    if (await backupDir.exists()) {
      final files = await backupDir
          .list()
          .where(
            (e) =>
                e is File &&
                e.path.endsWith('.opsbackup') &&
                p.basename(e.path).contains('_pre_optimize_'),
          )
          .cast<File>()
          .toList();

      files.sort((a, b) {
        final am = a.statSync().modified;
        final bm = b.statSync().modified;
        return bm.compareTo(am);
      });

      if (files.length > keepLatestBackups) {
        for (final file in files.skip(keepLatestBackups)) {
          await file.delete();
          deletedOldBackups++;
        }
      }
    }

    // 4. Оптимизируем планировщик запросов и физический размер SQLite.
    await db.execute('ANALYZE');
    await db.execute('PRAGMA optimize');

    // VACUUM нельзя выполнять внутри транзакции.
    await db.execute('VACUUM');

    final after = await dbFile.exists() ? await dbFile.length() : 0;

    return MaintenanceResult(
      removedMissingPhotoRows: removedMissingPhotoRows,
      removedSentSyncRows: removedSentSyncRows,
      deletedOldBackups: deletedOldBackups,
      beforeDatabaseBytes: before,
      afterDatabaseBytes: after,
    );
  }


  Future<PhotoArchiveResult> archiveOldPhotos({
    int olderThanDays = 180,
  }) async {
    // Сначала создаём отдельный архив, который автоочистка не удаляет.
    final backup = await _backup.createBackup(
      share: false,
      kind: 'archive_photos',
    );

    final db = await AppDatabase.instance.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .toIso8601String();

    final rows = await db.rawQuery("""
      SELECT p.id, p.request_id, p.path
      FROM photos p
      JOIN requests r ON r.id = p.request_id
      WHERE r.status = 'Выполнена'
        AND r.is_test = 0
        AND r.updated_at < ?
      ORDER BY r.updated_at ASC
    """, [cutoff]);

    final archivedPerRequest = <int, int>{};
    var archivedRows = 0;
    var deletedFiles = 0;
    var freedBytes = 0;

    // Фото уже находятся в archive backup. После этого удаляем
    // только локальные бинарные файлы и их строки из активной БД.
    for (final row in rows) {
      final id = row['id'] as int?;
      final requestId = row['request_id'] as int?;
      final path = row['path'] as String?;
      if (id == null || requestId == null) continue;

      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          try {
            freedBytes += await file.length();
            await file.delete();
            deletedFiles++;
          } catch (_) {
            // Если файл не удалось удалить, строку не удаляем:
            // история остаётся согласованной.
            continue;
          }
        }
      }

      final deleted = await db.delete(
        'photos',
        where: 'id = ?',
        whereArgs: [id],
      );
      archivedRows += deleted;
      if (deleted > 0) {
        archivedPerRequest.update(
          requestId,
          (value) => value + deleted,
          ifAbsent: () => deleted,
        );
      }
    }

    for (final entry in archivedPerRequest.entries) {
      await db.insert('photo_archives', {
        'request_id': entry.key,
        'photo_count': entry.value,
        'archive_file': backup.path,
        'archived_at': DateTime.now().toIso8601String(),
      });
    }

    await db.execute('ANALYZE');
    await db.execute('PRAGMA optimize');

    return PhotoArchiveResult(
      backupPath: backup.path,
      archivedPhotoRows: archivedRows,
      deletedPhotoFiles: deletedFiles,
      freedBytes: freedBytes,
    );
  }

  Future<void> markSyncItemSent(int id) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'sync_queue',
      {'synced_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
