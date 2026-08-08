import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

class PhotoProfile {
  final String mode;
  final int jpegQuality;
  final double maxWidth;
  final double maxHeight;
  final int previewCacheWidth;

  const PhotoProfile({
    required this.mode,
    required this.jpegQuality,
    required this.maxWidth,
    required this.maxHeight,
    required this.previewCacheWidth,
  });
}

class PhotoSettingsService {
  static const liteFallback = PhotoProfile(
    mode: 'lite',
    jpegQuality: 70,
    maxWidth: 1280,
    maxHeight: 1280,
    previewCacheWidth: 640,
  );

  static const detailFallback = PhotoProfile(
    mode: 'detail',
    jpegQuality: 82,
    maxWidth: 2048,
    maxHeight: 2048,
    previewCacheWidth: 900,
  );

  Future<PhotoProfile> liteProfile() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_settings',
      where: 'key IN (?, ?, ?, ?)',
      whereArgs: [
        'photo_jpeg_quality',
        'photo_max_width',
        'photo_max_height',
        'photo_preview_cache_width',
      ],
    );

    final values = <String, String>{};
    for (final row in rows) {
      values[row['key'] as String] = row['value'] as String;
    }

    return PhotoProfile(
      mode: 'lite',
      jpegQuality:
          int.tryParse(values['photo_jpeg_quality'] ?? '') ??
          liteFallback.jpegQuality,
      maxWidth:
          double.tryParse(values['photo_max_width'] ?? '') ??
          liteFallback.maxWidth,
      maxHeight:
          double.tryParse(values['photo_max_height'] ?? '') ??
          liteFallback.maxHeight,
      previewCacheWidth:
          int.tryParse(values['photo_preview_cache_width'] ?? '') ??
          liteFallback.previewCacheWidth,
    );
  }

  Future<void> saveLiteProfile({
    required int jpegQuality,
    required int maxDimension,
  }) async {
    final db = await AppDatabase.instance.database;

    Future<void> put(String key, String value) async {
      await db.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await put('photo_jpeg_quality', jpegQuality.toString());
    await put('photo_max_width', maxDimension.toString());
    await put('photo_max_height', maxDimension.toString());
  }
}
