import 'package:flutter/material.dart';
import '../repositories/ops_repository.dart';
import '../services/report_parser.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _controller = TextEditingController(
    text: '''нет контрольного события:
Белинского 167
Луначарского 181

не ставится на охрану:
Куйбышева 76

сработки:
Энгельса 31
Энгельса 38''',
  );

  final _repo = OpsRepository();
  final _parser = ReportParser();

  List<ParsedReportItem> _preview = [];

  void _parse() {
    setState(() {
      _preview = _parser.parse(_controller.text);
    });
  }

  Future<void> _import() async {
    final count = await _repo.importReport(_controller.text);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Создано заявок: $count')),
    );

    setState(() {
      _preview = [];
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Импорт отчёта')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            minLines: 10,
            maxLines: 18,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Вставьте отчёт',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _parse,
                  icon: const Icon(Icons.search),
                  label: const Text('Разобрать'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _import,
                  icon: const Icon(Icons.add_task),
                  label: const Text('Создать заявки'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_preview.isNotEmpty)
            Text(
              'Найдено событий: ${_preview.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ..._preview.map(
            (item) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${item.priority}'),
                ),
                title: Text(item.address),
                subtitle: Text(item.type),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
