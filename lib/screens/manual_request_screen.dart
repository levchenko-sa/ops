import 'package:flutter/material.dart';

import '../models/ops_object.dart';
import '../models/reference_value.dart';
import '../repositories/ops_repository.dart';
import 'object_picker_screen.dart';

class ManualRequestScreen extends StatefulWidget {
  final OpsObject? initialObject;

  const ManualRequestScreen({
    super.key,
    this.initialObject,
  });

  @override
  State<ManualRequestScreen> createState() =>
      _ManualRequestScreenState();
}

class _ManualRequestScreenState extends State<ManualRequestScreen> {
  final _repo = OpsRepository();
  final _comment = TextEditingController();

  OpsObject? _object;
  String? _type;
  int _priority = 2;
  bool _saving = false;

  late Future<List<ReferenceValue>> _types;

  @override
  void initState() {
    super.initState();
    _object = widget.initialObject;
    _types = _repo.getReferenceValues('request_type');
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickObject() async {
    final object = await Navigator.of(context).push<OpsObject>(
      MaterialPageRoute(
        builder: (_) => const ObjectPickerScreen(),
      ),
    );

    if (object == null || !mounted) return;
    setState(() => _object = object);
  }

  Future<bool> _confirmDuplicate(String existingStatus) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Похожая заявка уже открыта'),
            content: Text(
              'На этот объект уже есть открытая заявка '
              '«$_type» со статусом «$existingStatus».\n\n'
              'Создать ещё одну?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Не создавать'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Создать всё равно'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    final object = _object;
    final type = _type;

    if (object?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите объект')),
      );
      return;
    }

    if (type == null || type.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите тип заявки')),
      );
      return;
    }

    final duplicate = await _repo.findOpenDuplicateRequest(
      objectId: object!.id!,
      type: type,
    );

    if (duplicate != null) {
      if (!mounted) return;
      final proceed = await _confirmDuplicate(duplicate.status);
      if (!proceed) return;
    }

    setState(() => _saving = true);

    await _repo.createRequest(
      objectId: object.id!,
      type: type,
      priority: _priority,
      comment: _comment.text.trim(),
      source: 'manual',
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Widget _priorityChoice(
    int value,
    String label,
    IconData icon,
  ) {
    return Expanded(
      child: ChoiceChip(
        selected: _priority == value,
        onSelected: (_) => setState(() => _priority = value),
        avatar: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новая заявка')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Объект',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              onTap: _pickObject,
              leading: const Icon(Icons.apartment),
              title: Text(
                _object?.address ?? 'Выбрать объект',
              ),
              subtitle: _object == null
                  ? const Text('Нажмите для поиска по адресу')
                  : Text(
                      '${_object!.system} • ${_object!.connection}',
                    ),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Тип заявки',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<ReferenceValue>>(
            future: _types,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final values = snapshot.data!;

              return DropdownButtonFormField<String>(
                isExpanded: true,
                value: values.any((e) => e.value == _type)
                    ? _type
                    : null,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.build_circle_outlined),
                  hintText: 'Выберите неисправность/работу',
                ),
                items: values
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.value,
                        child: Text(item.value),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _type = value);

                  if (value == 'Сработка') {
                    _priority = 3;
                  } else if (value == 'Плановое обслуживание') {
                    _priority = 1;
                  }
                  setState(() {});
                },
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Приоритет',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _priorityChoice(
                1,
                'Низкий',
                Icons.keyboard_arrow_down,
              ),
              const SizedBox(width: 8),
              _priorityChoice(
                2,
                'Средний',
                Icons.remove,
              ),
              const SizedBox(width: 8),
              _priorityChoice(
                3,
                'Высокий',
                Icons.priority_high,
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _comment,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Комментарий',
              hintText:
                  'Подъезд, этаж, зона, что сообщил диспетчер...',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.add_task),
            label: const Text('Создать заявку'),
          ),
        ],
      ),
    );
  }
}
