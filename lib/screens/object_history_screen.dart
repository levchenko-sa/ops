import 'package:flutter/material.dart';

import '../models/object_history_entry.dart';
import '../models/ops_object.dart';
import '../repositories/ops_repository.dart';
import 'history_entry_screen.dart';

class ObjectHistoryScreen extends StatefulWidget {
  final OpsObject object;

  const ObjectHistoryScreen({
    super.key,
    required this.object,
  });

  @override
  State<ObjectHistoryScreen> createState() => _ObjectHistoryScreenState();
}

class _ObjectHistoryScreenState extends State<ObjectHistoryScreen> {
  final _repo = OpsRepository();
  final _noteController = TextEditingController();

  late Future<List<ObjectHistoryEntry>> _history;
  late Future<List<Map<String, Object?>>> _notes;
  late Future<Map<String, Object?>> _stats;
  late Future<String> _assistantHint;
  int _historyLimit = 50;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _history = _repo.getObjectHistory(
      widget.object.id!,
      limit: _historyLimit,
    );
    _notes = _repo.getObjectNotes(widget.object.id!);
    _stats = _repo.getObjectHistoryStats(widget.object.id!);
    _assistantHint = _repo.getObjectAssistantHint(widget.object.id!);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    await _repo.addObjectNote(widget.object.id!, text);
    _noteController.clear();

    if (!mounted) return;
    setState(_reload);
  }

  String _shortDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  Widget _historyCard(ObjectHistoryEntry entry) {
    final cause = entry.cause?.trim();
    final subtitle = [
      _shortDate(entry.createdAt),
      entry.status,
      if (cause != null && cause.isNotEmpty)
        'Причина: $cause',
      if (entry.photoCount > 0)
        'Фото на телефоне: ${entry.photoCount}',
      if (entry.archivedPhotoCount > 0)
        'Фото в архиве: ${entry.archivedPhotoCount}',
    ].join('\n');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${entry.priority}'),
        ),
        title: Text(entry.type),
        subtitle: Text(subtitle),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HistoryEntryScreen(
              address: widget.object.address,
              entry: entry,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('История • ${widget.object.address}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<Map<String, Object?>>(
            future: _stats,
            builder: (context, snapshot) {
              final data = snapshot.data;
              final total = data?['total'] ?? '—';
              final completed = data?['completed'] ?? '—';
              final top = data?['top_type'] ?? '—';
              final topCount = data?['top_type_count'] ?? 0;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      Text('Всего событий: $total'),
                      Text('Закрыто: $completed'),
                      Text('Чаще всего: $top ($topCount)'),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: _assistantHint,
            builder: (context, snapshot) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.psychology_alt_outlined),
                  title: const Text('Помощник'),
                  subtitle: Text(
                    snapshot.data ?? 'Анализирую историю объекта...',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Заметка по объекту',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        'Например: ШС-2 идёт через подвал 2 подъезда...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addNote,
                icon: const Icon(Icons.add),
                tooltip: 'Добавить заметку',
              ),
            ],
          ),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _notes,
            builder: (context, snapshot) {
              final notes = snapshot.data ?? const [];
              if (notes.isEmpty) return const SizedBox.shrink();

              return Column(
                children: notes.take(5).map((note) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.sticky_note_2_outlined),
                      title: Text(note['text'] as String? ?? ''),
                      subtitle: Text(
                        _shortDate(note['created_at'] as String? ?? ''),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Выезды и неисправности',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<ObjectHistoryEntry>>(
            future: _history,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('История пока пустая'),
                  ),
                );
              }

              return Column(
                children: <Widget>[
                  for (final entry in items) _historyCard(entry),
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: items.length < _historyLimit
                            ? null
                            : () {
                                setState(() {
                                  _historyLimit += 50;
                                  _reload();
                                });
                              },
                        icon: const Icon(Icons.expand_more),
                        label: Text(
                          items.length < _historyLimit
                              ? 'Вся история загружена'
                              : 'Показать ещё 50',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
