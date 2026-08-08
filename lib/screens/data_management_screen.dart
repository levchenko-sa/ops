import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import 'data_optimization_screen.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  final _backup = BackupService();

  bool _busy = false;
  String _status = 'Резервная копия ещё не создавалась в этой сессии.';

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = 'Создаю резервную копию...';
    });

    try {
      final result = await _backup.createBackup(share: true);
      if (!mounted) return;
      setState(() {
        _status =
            'Экспорт готов: ${result.objectCount} объектов, '
            '${result.requestCount} заявок, ${result.photoCount} фото.\n'
            '${result.path}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Ошибка экспорта: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmRestore() async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Импортировать резервную копию?'),
        content: const Text(
          'Текущие данные будут заменены данными из выбранной копии. '
          'Перед импортом OPS Control автоматически создаст страховую '
          'резервную копию текущего состояния.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Импортировать'),
          ),
        ],
      ),
    );

    return value ?? false;
  }

  Future<void> _import() async {
    final source = await _backup.pickBackupFile();
    if (source == null) return;

    if (!mounted) return;
    if (!await _confirmRestore()) return;

    setState(() {
      _busy = true;
      _status = 'Проверяю и импортирую резервную копию...';
    });

    try {
      final result = await _backup.restoreFromFile(source);

      if (!mounted) return;
      setState(() {
        _status =
            'Импорт завершён.\n'
            'Объекты: ${result.objectCount}\n'
            'Заявки: ${result.requestCount}\n'
            'Фото: ${result.photoCount}\n'
            'Страховая копия до импорта:\n'
            '${result.safetyBackupPath}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Импорт отменён/не выполнен: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Данные и резервные копии')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: const ListTile(
              leading: Icon(Icons.system_update_alt),
              title: Text('Безопасные обновления'),
              subtitle: Text(
                'Структура базы обновляется миграциями. '
                'Переустановка поверх старой версии не должна удалять данные, '
                'если не меняются package ID и ключ подписи.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.upload_file),
            label: const Text('Экспортировать всё'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.download_for_offline),
            label: const Text('Импортировать резервную копию'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DataOptimizationScreen(),
                      ),
                    ),
            icon: const Icon(Icons.speed),
            label: const Text('Оптимизация и минимализация данных'),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          SelectableText(_status),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Формат .opsbackup содержит объекты, заявки, отчёты, '
                'склад, очередь синхронизации и фотографии. '
                'Файл сжат и переносим между устройствами.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
