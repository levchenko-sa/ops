import 'package:flutter/material.dart';

import '../models/reference_value.dart';
import '../repositories/ops_repository.dart';

class ReferenceBooksScreen extends StatefulWidget {
  const ReferenceBooksScreen({super.key});

  @override
  State<ReferenceBooksScreen> createState() =>
      _ReferenceBooksScreenState();
}

class _ReferenceBooksScreenState extends State<ReferenceBooksScreen> {
  final _repo = OpsRepository();

  static const _categories = <String, String>{
    'request_type': 'Типы заявок',
    'fault_cause': 'Причины неисправностей',
    'work_result': 'Результаты работ',
  };

  String _category = 'request_type';
  late Future<List<ReferenceValue>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.getReferenceValues(
      _category,
      activeOnly: false,
    );
  }

  Future<String?> _valueDialog({
    required String title,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Значение',
          ),
          onSubmitted: (_) {
            final value = controller.text.trim();
            if (value.isNotEmpty) Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _add() async {
    final value = await _valueDialog(
      title: 'Добавить значение',
    );
    if (value == null) return;

    try {
      await _repo.addReferenceValue(
        category: _category,
        value: value,
      );
      if (mounted) setState(_reload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Такое значение уже существует в этом справочнике',
          ),
        ),
      );
    }
  }

  Future<void> _edit(ReferenceValue item) async {
    final value = await _valueDialog(
      title: 'Изменить значение',
      initial: item.value,
    );
    if (value == null || value == item.value) return;

    try {
      await _repo.updateReferenceValue(
        item.id!,
        value: value,
      );
      if (mounted) setState(_reload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось изменить значение'),
        ),
      );
    }
  }

  Future<void> _delete(ReferenceValue item) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить из справочника?'),
            content: Text(
              '«${item.value}» будет удалено из списка выбора. '
              'Старые заявки и отчёты с этим текстом сохранятся.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await _repo.deleteReferenceValue(item.id!);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Справочники'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Справочник',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
              items: _categories.entries
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _category = value;
                  _reload();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ReferenceValue>>(
              future: _future,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Справочник пуст'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => _edit(item),
                          leading: Icon(
                            item.active
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                          ),
                          title: Text(item.value),
                          subtitle: Text(
                            item.active
                                ? 'Используется в формах'
                                : 'Скрыто из новых форм',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: item.active,
                                onChanged: (value) async {
                                  await _repo.setReferenceValueActive(
                                    item.id!,
                                    value,
                                  );
                                  if (mounted) setState(_reload);
                                },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _edit(item);
                                  if (value == 'delete') _delete(item);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Изменить'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
