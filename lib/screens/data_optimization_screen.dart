import 'package:flutter/material.dart';

import '../services/data_maintenance_service.dart';
import 'stress_test_screen.dart';
import 'photo_settings_screen.dart';

class DataOptimizationScreen extends StatefulWidget {
  const DataOptimizationScreen({super.key});

  @override
  State<DataOptimizationScreen> createState() =>
      _DataOptimizationScreenState();
}

class _DataOptimizationScreenState extends State<DataOptimizationScreen> {
  final _service = DataMaintenanceService();

  late Future<StorageStats> _stats;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _stats = _service.stats();
  }

  String _size(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;

    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} ГБ';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} МБ';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} КБ';
    return '$bytes Б';
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
  }) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );

    return value ?? false;
  }

  Future<void> _optimize() async {
    setState(() {
      _busy = true;
      _status = 'Выполняю безопасную оптимизацию...';
    });

    try {
      final result = await _service.safeOptimize();

      if (!mounted) return;
      setState(() {
        _status =
            'Оптимизация завершена.\n'
            'Удалено битых ссылок на фото: '
            '${result.removedMissingPhotoRows}\n'
            'Удалено старых подтверждённых записей синхронизации: '
            '${result.removedSentSyncRows}\n'
            'Удалено лишних обычных backup: '
            '${result.deletedOldBackups}\n'
            'SQLite: ${_size(result.beforeDatabaseBytes)} → '
            '${_size(result.afterDatabaseBytes)}';
        _reload();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка оптимизации: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archivePhotos() async {
    final ok = await _confirm(
      title: 'Архивировать старые фото?',
      text:
          'Фото закрытых работ старше 180 дней будут сначала сохранены '
          'в отдельную резервную копию .opsbackup, а затем удалены из '
          'активного хранилища телефона. Текстовая история ремонтов, '
          'измерения и заявки останутся в приложении. Архив можно '
          'импортировать обратно.',
      action: 'Архивировать',
    );

    if (!ok) return;

    setState(() {
      _busy = true;
      _status = 'Создаю архив и освобождаю место...';
    });

    try {
      final result = await _service.archiveOldPhotos(
        olderThanDays: 180,
      );

      if (!mounted) return;
      setState(() {
        _status =
            'Архивация завершена.\n'
            'Фото убрано из активной базы: '
            '${result.archivedPhotoRows}\n'
            'Файлов удалено с телефона: '
            '${result.deletedPhotoFiles}\n'
            'Освобождено: ${_size(result.freedBytes)}\n'
            'Архив: ${result.backupPath}';
        _reload();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка архивации: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оптимизация данных')),
      body: FutureBuilder<StorageStats>(
        future: _stats,
        builder: (context, snapshot) {
          final stats = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!snapshot.hasData)
                const LinearProgressIndicator(),
              if (stats != null) ...[
                _statCard(
                  'Всего занято OPS Control',
                  _size(stats.totalBytes),
                  Icons.storage,
                ),
                _statCard(
                  'База SQLite',
                  _size(stats.databaseBytes),
                  Icons.table_chart,
                ),
                _statCard(
                  'Фото',
                  _size(stats.photoBytes),
                  Icons.photo_library,
                ),
                _statCard(
                  'Резервные копии',
                  _size(stats.backupBytes),
                  Icons.backup,
                ),
                _statCard(
                  'Заявки',
                  '${stats.requestCount}',
                  Icons.assignment,
                ),
                _statCard(
                  'Фото в активной истории',
                  '${stats.photoCount}',
                  Icons.image,
                ),
                _statCard(
                  'Ожидает синхронизации',
                  '${stats.pendingSyncCount}',
                  Icons.cloud_upload,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _optimize,
                icon: const Icon(Icons.speed),
                label: const Text('Безопасно оптимизировать'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PhotoSettingsScreen(),
                          ),
                        ),
                icon: const Icon(Icons.photo_size_select_large),
                label: const Text('Размер и качество фото'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _archivePhotos,
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Архивировать фото старше 180 дней'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StressTestScreen(),
                          ),
                        ),
                icon: const Icon(Icons.science_outlined),
                label: const Text('Нагрузочный тест базы'),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'OPS Control не удаляет старые заявки и историю ремонтов '
                    'ради ускорения. Большие списки читаются страницами по 50 '
                    'записей, фотографии загружаются только при открытии '
                    'конкретного ремонта. Основной объём обычно занимают '
                    'фотографии — их можно архивировать отдельно.',
                  ),
                ),
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_status != null) ...[
                const SizedBox(height: 12),
                SelectableText(_status!),
              ],
            ],
          );
        },
      ),
    );
  }
}
