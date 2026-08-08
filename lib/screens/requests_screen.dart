import 'package:flutter/material.dart';

import '../models/work_request.dart';
import '../repositories/ops_repository.dart';
import 'manual_request_screen.dart';
import 'work_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _repo = OpsRepository();
  late Future<List<WorkRequest>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.getOpenRequests();
  }

  Future<void> _setStatus(
    WorkRequest item,
    String status,
  ) async {
    await _repo.updateRequestStatus(item.id!, status);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _openWork(WorkRequest item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkScreen(request: item),
      ),
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _newRequest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ManualRequestScreen(),
      ),
    );

    if (created == true && mounted) {
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Открытые заявки')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newRequest,
        icon: const Icon(Icons.add),
        label: const Text('Новая'),
      ),
      body: FutureBuilder<List<WorkRequest>>(
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
              child: Text('Открытых заявок нет'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              final sourceText = item.source == 'import'
                  ? 'Импорт'
                  : item.source == 'manual'
                      ? 'Вручную'
                      : item.source;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: () => _openWork(item),
                    leading: CircleAvatar(
                      child: Text('${item.priority}'),
                    ),
                    title: Text(
                      item.isTest
                          ? '[ТЕСТ] ${item.address}'
                          : item.address,
                    ),
                    subtitle: Text(
                      '${item.type}\n'
                      '${item.status} • $sourceText',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) =>
                          _setStatus(item, value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'Новая',
                          child: Text('Новая'),
                        ),
                        PopupMenuItem(
                          value: 'В работе',
                          child: Text('В работе'),
                        ),
                        PopupMenuItem(
                          value: 'Выполнена',
                          child: Text('Выполнена'),
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
    );
  }
}
