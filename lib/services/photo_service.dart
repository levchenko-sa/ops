import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'photo_settings_service.dart';

class CapturedPhoto {
  final String path;
  final int bytes;
  final String mode;

  const CapturedPhoto({
    required this.path,
    required this.bytes,
    required this.mode,
  });
}

class PhotoService {
  final ImagePicker _picker = ImagePicker();
  final PhotoSettingsService _settings = PhotoSettingsService();

  Future<CapturedPhoto?> takeAndPersist({
    required int requestId,
    required String type,
    bool detailMode = false,
  }) async {
    final profile = detailMode
        ? PhotoSettingsService.detailFallback
        : await _settings.liteProfile();

    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: profile.jpegQuality,
      maxWidth: profile.maxWidth,
      maxHeight: profile.maxHeight,
      requestFullMetadata: false,
    );

    if (shot == null) return null;

    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'ops_photos', '$requestId'));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // image_picker уже уменьшает и JPEG-сжимает снимок.
    // Повторное декодирование/сжатие не делаем: это экономит CPU,
    // RAM и не требует тяжёлой нативной библиотеки компрессии.
    final ext = p.extension(shot.path).isEmpty ? '.jpg' : p.extension(shot.path);
    final fileName =
        '${type}_${profile.mode}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final target = p.join(dir.path, fileName);

    File saved;
    try {
      saved = await File(shot.path).rename(target);
    } catch (_) {
      saved = await File(shot.path).copy(target);
    }
    final bytes = await saved.length();

    return CapturedPhoto(
      path: saved.path,
      bytes: bytes,
      mode: profile.mode,
    );
  }
}
