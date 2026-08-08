import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../core/app_constants.dart';
import '../database/app_database.dart';

class BackupResult {
  final String path;
  final int objectCount;
  final int requestCount;
  final int photoCount;

  const BackupResult({
    required this.path,
    required this.objectCount,
    required this.requestCount,
    required this.photoCount,
  });
}

class RestoreResult {
  final String sourceFile;
  final int objectCount;
  final int requestCount;
  final int photoCount;
  final String safetyBackupPath;

  const RestoreResult({
    required this.sourceFile,
    required this.objectCount,
    required this.requestCount,
    required this.photoCount,
    required this.safetyBackupPath,
  });
}

class BackupService {
  static const _dataTables = <String>[
    'objects',
    'requests',
    'materials',
    'engineers',
    'engineer_stock',
    'stock_transfers',
    'stock_transfer_items',
    'work_reports',
    'photos',
    'object_notes',
    'object_equipment',
    'photo_archives',
    'reference_values',
    'request_materials',
    'stock_movements',
    'organization_profile',
    'inventory_documents',
    'inventory_document_items',
    'goods_receipts',
    'goods_receipt_items',
    'stock_batches',
    'engineer_stock_batches',
    'request_material_batch_allocations',
    'app_settings',
    'sync_queue',
  ];

  Future<Directory> _backupDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'ops_backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<BackupResult> createBackup({
    bool share = false,
    String kind = 'manual',
  }) async {
    final db = await AppDatabase.instance.database;
    final tables = <String, List<Map<String, Object?>>>{};

    for (final table in _dataTables) {
      if (table == 'requests' ||
          table == 'work_reports' ||
          table == 'photos') {
        tables[table] = await db.query(
          table,
          where: 'is_test = 0',
        );
      } else {
        tables[table] = await db.query(table);
      }
    }

    final photoFiles = <String, String>{};
    final photoRows = tables['photos'] ?? const [];

    for (final row in photoRows) {
      final id = row['id'];
      final path = row['path'] as String?;
      if (id == null || path == null || path.isEmpty) continue;

      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      photoFiles['photo_$id'] = base64Encode(bytes);
    }

    final payload = <String, Object?>{
      'format': 'OPS_CONTROL_BACKUP',
      'format_version': AppConstants.backupFormatVersion,
      'database_version': AppConstants.databaseVersion,
      'app_version': AppConstants.appVersion,
      'created_at': DateTime.now().toIso8601String(),
      'tables': tables,
      'photo_files': photoFiles,
    };

    final raw = utf8.encode(jsonEncode(payload));
    final compressed = gzip.encode(raw);

    final dir = await _backupDirectory();
    final fileName = 'OPS_Control_${kind}_${_stamp()}.opsbackup';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(compressed, flush: true);

    await db.insert('backup_history', {
      'file_name': fileName,
      'created_at': DateTime.now().toIso8601String(),
      'type': kind,
    });

    if (share) {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Резервная копия OPS Control',
          files: [XFile(file.path)],
        ),
      );
    }

    return BackupResult(
      path: file.path,
      objectCount: tables['objects']?.length ?? 0,
      requestCount: tables['requests']?.length ?? 0,
      photoCount: photoRows.length,
    );
  }

  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['opsbackup'],
      allowMultiple: false,
    );
    return result?.files.single.path;
  }

  Future<RestoreResult> restoreFromFile(String sourcePath) async {
    // Перед любым импортом автоматически сохраняем текущее состояние.
    final safetyBackup = await createBackup(
      share: false,
      kind: 'pre_import',
    );

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw Exception('Файл резервной копии не найден');
    }

    final compressed = await source.readAsBytes();
    final decodedBytes = gzip.decode(compressed);
    final root = jsonDecode(utf8.decode(decodedBytes));

    if (root is! Map<String, dynamic>) {
      throw Exception('Неверный формат резервной копии');
    }

    if (root['format'] != 'OPS_CONTROL_BACKUP') {
      throw Exception('Это не резервная копия OPS Control');
    }

    final formatVersion = (root['format_version'] as num?)?.toInt() ?? 0;
    if (formatVersion > AppConstants.backupFormatVersion) {
      throw Exception(
        'Копия создана более новой версией приложения. '
        'Сначала обновите OPS Control.',
      );
    }

    final databaseVersion = (root['database_version'] as num?)?.toInt() ?? 0;
    if (databaseVersion > AppConstants.databaseVersion) {
      throw Exception(
        'Версия базы в копии новее установленной. '
        'Сначала обновите приложение.',
      );
    }

    final tableData = root['tables'];
    if (tableData is! Map<String, dynamic>) {
      throw Exception('В копии отсутствуют таблицы данных');
    }

    final photoData = root['photo_files'];
    final photoFiles = photoData is Map<String, dynamic>
        ? photoData
        : <String, dynamic>{};

    final docs = await getApplicationDocumentsDirectory();
    final restoreRoot = Directory(
      p.join(
        docs.path,
        'ops_photos_restored',
        DateTime.now().millisecondsSinceEpoch.toString(),
      ),
    );
    await restoreRoot.create(recursive: true);

    // Готовим новые пути фотографий до транзакции.
    final restoredPhotoPaths = <int, String>{};
    final rawPhotos = tableData['photos'];

    if (rawPhotos is List) {
      for (final item in rawPhotos) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final id = (row['id'] as num?)?.toInt();
        if (id == null) continue;

        final encoded = photoFiles['photo_$id'];
        if (encoded is! String || encoded.isEmpty) continue;

        final oldPath = row['path'] as String? ?? '';
        final ext = p.extension(oldPath).isEmpty ? '.jpg' : p.extension(oldPath);
        final newFile = File(p.join(restoreRoot.path, 'photo_$id$ext'));
        await newFile.writeAsBytes(base64Decode(encoded), flush: true);
        restoredPhotoPaths[id] = newFile.path;
      }
    }

    final db = await AppDatabase.instance.database;

    try {
      await db.transaction((txn) async {
        // Удаляем зависимые таблицы текущей версии всегда.
        // Это позволяет безопасно восстановить и старый backup,
        // в котором этих таблиц ещё не существовало.
        await txn.delete('stock_transfer_items');
        await txn.delete('stock_transfers');
        await txn.delete('engineer_stock_batches');
        await txn.delete('engineer_stock');
        await txn.delete('request_material_batch_allocations');
        await txn.delete('stock_batches');
        await txn.delete('goods_receipt_items');
        await txn.delete('goods_receipts');
        await txn.delete('inventory_document_items');
        await txn.delete('inventory_documents');

        await txn.delete('stock_movements');
        await txn.delete('request_materials');
        await txn.delete('photos');
        await txn.delete('work_reports');
        await txn.delete('photo_archives');
        await txn.delete('object_equipment');
        await txn.delete('object_notes');
        await txn.delete('requests');
        await txn.delete('sync_queue');
        await txn.delete('materials');
        await txn.delete('engineers');
        await txn.delete('objects');

        if (tableData['reference_values'] is List) {
          await txn.delete('reference_values');
        }
        if (tableData['organization_profile'] is List) {
          await txn.delete('organization_profile');
        }
        if (tableData['app_settings'] is List) {
          await txn.delete('app_settings');
        }

        Future<void> insertRows(String table) async {
          final rawRows = tableData[table];
          if (rawRows is! List) return;

          for (final item in rawRows) {
            if (item is! Map) continue;
            final row = Map<String, Object?>.from(item);

            if (table == 'photos') {
              final id = (row['id'] as num?)?.toInt();
              if (id == null || !restoredPhotoPaths.containsKey(id)) {
                continue;
              }
              row['path'] = restoredPhotoPaths[id];
            }

            await txn.insert(
              table,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }

        await insertRows('objects');
        await insertRows('object_equipment');
        await insertRows('materials');
        await insertRows('engineers');
        await insertRows('engineer_stock');
        await insertRows('stock_transfers');
        await insertRows('stock_transfer_items');
        await insertRows('requests');
        await insertRows('work_reports');
        await insertRows('photos');
        await insertRows('object_notes');
        await insertRows('photo_archives');
        await insertRows('request_materials');
        await insertRows('stock_movements');
        await insertRows('reference_values');
        await insertRows('organization_profile');
        await insertRows('inventory_documents');
        await insertRows('inventory_document_items');
        await insertRows('goods_receipts');
        await insertRows('goods_receipt_items');
        await insertRows('stock_batches');
        await insertRows('engineer_stock_batches');
        await insertRows('request_material_batch_allocations');
        await insertRows('app_settings');
        await insertRows('sync_queue');

        await txn.insert('import_history', {
          'file_name': p.basename(sourcePath),
          'imported_at': DateTime.now().toIso8601String(),
          'mode': 'replace_safe',
          'result': 'ok',
        });
      });
    } catch (_) {
      if (await restoreRoot.exists()) {
        await restoreRoot.delete(recursive: true);
      }
      rethrow;
    }

    final objects = await db.rawQuery('SELECT COUNT(*) AS cnt FROM objects');
    final requests = await db.rawQuery('SELECT COUNT(*) AS cnt FROM requests');
    final photos = await db.rawQuery('SELECT COUNT(*) AS cnt FROM photos');

    int count(List<Map<String, Object?>> rows) =>
        (rows.first['cnt'] as num?)?.toInt() ?? 0;

    return RestoreResult(
      sourceFile: sourcePath,
      objectCount: count(objects),
      requestCount: count(requests),
      photoCount: count(photos),
      safetyBackupPath: safetyBackup.path,
    );
  }
}
