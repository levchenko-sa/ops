import 'package:flutter/material.dart';

import '../services/stress_test_service.dart';

class StressTestScreen extends StatefulWidget {
  const StressTestScreen({super.key});

  @override
  State<StressTestScreen> createState() => _StressTestScreenState();
}

class _StressTestScreenState extends State<StressTestScreen> {
  final _service = StressTestService();

  late Future<StressTestCounts> _counts;
  bool _busy = false;
  String? _resultText;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _counts = _service.counts();
  }

  String _grade(int ms) {
    if (ms <= 100) return 'быстро';
    if (ms <= 300) return 'допустимо';
    return 'требует оптимизации';
  }

  String _size(int bytes) {
    const kb = 1024;
    const mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} МБ';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} КБ';
    return '$bytes Б';
  }

  Future<bool> _confirm(
    String title,
    String text,
    String action,
  ) async {
    return await showDialog<bool>(
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
        ) ??
        false;
  }

  Future<void> _generate() async {
    final ok = await _confirm(
      'Создать нагрузочную базу?',
      'Будет создано 10 000 тестовых заявок, примерно 7 500 '
      'тестовых отчётов и 3 000 тестовых записей фотографий. '
      'Они помечаются как тестовые и не попадают в обычный экспорт.',
      'Создать',
    );
    if (!ok) return;

    setState(() {
      _busy = true;
      _resultText = 'Генерирую данные и выполняю benchmark...';
    });

    try {
      final result = await _service.generate(
        requestCount: 10000,
        photoCount: 3000,
      );

      if (!mounted) return;
      setState(() {
        _resultText =
            'Готово.\n'
            'Заявок: ${result.requestCount}\n'
            'Отчётов: ${result.reportCount}\n'
            'Фото-записей: ${result.photoCount}\n'
            'Запись набора: ${result.insertMs} мс\n'
            'История объекта (50 строк): '
            '${result.historyQueryMs} мс — '
            '${_grade(result.historyQueryMs)}\n'
            'Открытые заявки (200 строк): '
            '${result.openRequestsQueryMs} мс — '
            '${_grade(result.openRequestsQueryMs)}\n'
            'Размер SQLite: ${_size(result.databaseBytes)}';
        _reload();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultText = 'Ошибка: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _benchmark() async {
    setState(() {
      _busy = true;
      _resultText = 'Замеряю текущую базу...';
    });

    try {
      final result = await _service.benchmarkCurrent();
      if (!mounted) return;
      setState(() {
        _resultText =
            'Benchmark текущей базы:\n'
            'Тестовых заявок: ${result.requestCount}\n'
            'Тестовых отчётов: ${result.reportCount}\n'
            'Тестовых фото-записей: ${result.photoCount}\n'
            'История объекта (50 строк): '
            '${result.historyQueryMs} мс — '
            '${_grade(result.historyQueryMs)}\n'
            'Открытые заявки (200 строк): '
            '${result.openRequestsQueryMs} мс — '
            '${_grade(result.openRequestsQueryMs)}\n'
            'Размер SQLite: ${_size(result.databaseBytes)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultText = 'Ошибка benchmark: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _purge() async {
    final ok = await _confirm(
      'Удалить тестовые данные?',
      'Будут удалены только записи с признаком is_test=1. '
      'Рабочие объекты, реальные заявки, отчёты и фотографии '
      'не затрагиваются.',
      'Удалить тестовые',
    );
    if (!ok) return;

    setState(() {
      _busy = true;
      _resultText = 'Удаляю тестовые данные...';
    });

    try {
      final left = await _service.purge();
      if (!mounted) return;
      setState(() {
        _resultText =
            'Тестовый контур очищен.\n'
            'Осталось тестовых заявок: ${left.requests}\n'
            'Отчётов: ${left.reports}\n'
            'Фото: ${left.photos}';
        _reload();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _resultText = 'Ошибка очистки: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Нагрузочный тест')),
      body: FutureBuilder<StressTestCounts>(
        future: _counts,
        builder: (context, snapshot) {
          final counts = snapshot.data;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.science_outlined),
                  title: Text('Изолированный тестовый контур'),
                  subtitle: Text(
                    'Тестовые строки помечаются is_test=1. '
                    'Обычный резервный экспорт их не включает.',
                  ),
                ),
              ),
              if (counts != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        Text('Заявки: ${counts.requests}'),
                        Text('Отчёты: ${counts.reports}'),
                        Text('Фото: ${counts.photos}'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed:
                    _busy || (counts?.hasData ?? false) ? null : _generate,
                icon: const Icon(Icons.data_array),
                label: const Text(
                  'Создать 10 000 заявок + 3 000 фото',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _benchmark,
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Запустить benchmark'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed:
                    _busy || !(counts?.hasData ?? false) ? null : _purge,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Удалить только тестовые данные'),
              ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              if (_resultText != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: SelectableText(_resultText!),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    '3 000 тестовых фото используют один общий '
                    'миниатюрный PNG-файл. Это нагружает SQL-таблицы, '
                    'JOIN, счётчики и списки, но не забивает телефон '
                    'сотнями мегабайт бессмысленных изображений. '
                    'Отдельно реальный объём фотографий проверяется '
                    'эксплуатационным тестом на телефоне.',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
