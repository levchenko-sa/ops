import 'package:flutter/material.dart';

import '../models/object_equipment.dart';
import '../models/ops_object.dart';
import '../models/work_request.dart';
import '../repositories/ops_repository.dart';
import 'object_edit_screen.dart';
import 'object_history_screen.dart';
import 'work_screen.dart';
import 'manual_request_screen.dart';

class ObjectDetailScreen extends StatefulWidget {
  final OpsObject object;

  const ObjectDetailScreen({
    super.key,
    required this.object,
  });

  @override
  State<ObjectDetailScreen> createState() => _ObjectDetailScreenState();
}

class _ObjectDetailScreenState extends State<ObjectDetailScreen> {
  final _repo = OpsRepository();

  late OpsObject _object;
  late Future<List<WorkRequest>> _requests;
  late Future<List<ObjectEquipment>> _equipment;
  late Future<int> _openCount;

  @override
  void initState() {
    super.initState();
    _object = widget.object;
    _reload();
  }

  void _reload() {
    _requests = _repo.getOpenRequests(objectId: _object.id);
    _equipment = _repo.getObjectEquipment(_object.id!);
    _openCount = _repo.objectOpenRequestCount(_object.id!);
  }

  Future<void> _editObject() async {
    final updated = await Navigator.of(context).push<OpsObject>(
      MaterialPageRoute(
        builder: (_) => ObjectEditScreen(object: _object),
      ),
    );

    if (updated == null || !mounted) return;

    setState(() {
      _object = updated;
      _reload();
    });
  }

  Future<void> _newRequest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ManualRequestScreen(
          initialObject: _object,
        ),
      ),
    );

    if (created == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _openWork(WorkRequest request) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkScreen(request: request),
      ),
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _addEquipment() async {
    final name = TextEditingController();
    final model = TextEditingController();
    final location = TextEditingController();
    final serial = TextEditingController();
    final notes = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить оборудование'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Наименование *',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: model,
                  decoration: const InputDecoration(
                    labelText: 'Модель',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: location,
                  decoration: const InputDecoration(
                    labelText: 'Где установлено',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: serial,
                  decoration: const InputDecoration(
                    labelText: 'Серийный номер',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Примечание',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _repo.addObjectEquipment(
        objectId: _object.id!,
        name: name.text,
        model: model.text,
        location: location.text,
        serialNumber: serial.text,
        notes: notes.text,
      );
      if (mounted) setState(_reload);
    }

    name.dispose();
    model.dispose();
    location.dispose();
    serial.dispose();
    notes.dispose();
  }

  Future<void> _deleteEquipment(ObjectEquipment item) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить оборудование?'),
            content: Text(item.name),
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

    await _repo.deleteObjectEquipment(item.id!);
    if (mounted) setState(_reload);
  }

  Widget _passportRow(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    return ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value.isEmpty ? '—' : value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_object.address),
        actions: [
          IconButton(
            onPressed: _editObject,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Редактировать паспорт',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<int>(
            future: _openCount,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;

              return Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.apartment),
                      title: Text(
                        _object.address,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      subtitle: Text(_object.system),
                      trailing: Chip(
                        label: Text(
                          count == 0 ? 'Норма' : 'Заявок: $count',
                        ),
                      ),
                    ),
                    const Divider(),
                    _passportRow(
                      context,
                      Icons.cell_tower_outlined,
                      'Связь',
                      _object.connection,
                    ),
                    _passportRow(
                      context,
                      Icons.monitor_heart_outlined,
                      'Состояние',
                      _object.status,
                    ),
                    _passportRow(
                      context,
                      Icons.door_front_door_outlined,
                      'Подъездов',
                      _object.entrances?.toString() ?? '—',
                    ),
                    if (_object.notes.trim().isNotEmpty)
                      _passportRow(
                        context,
                        Icons.notes_outlined,
                        'Примечание',
                        _object.notes,
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _newRequest,
            icon: const Icon(Icons.add_task),
            label: const Text('Создать заявку по этому объекту'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ObjectHistoryScreen(object: _object),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('История'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _editObject,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Паспорт'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Оборудование',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                onPressed: _addEquipment,
                icon: const Icon(Icons.add),
                tooltip: 'Добавить оборудование',
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<ObjectEquipment>>(
            future: _equipment,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.developer_board_outlined),
                    title: Text('Оборудование ещё не заполнено'),
                    subtitle: Text(
                      'Добавьте прибор, блок питания, модем, датчики '
                      'или другое оборудование объекта.',
                    ),
                  ),
                );
              }

              return Column(
                children: items.map((item) {
                  final details = <String>[
                    if (item.model.isNotEmpty) item.model,
                    if (item.location.isNotEmpty) item.location,
                    if (item.serialNumber.isNotEmpty)
                      'S/N ${item.serialNumber}',
                  ].join(' • ');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.developer_board_outlined,
                        ),
                        title: Text(item.name),
                        subtitle: details.isEmpty
                            ? null
                            : Text(details),
                        trailing: IconButton(
                          onPressed: () => _deleteEquipment(item),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Удалить',
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Открытые заявки',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<WorkRequest>>(
            future: _requests,
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
                    leading: Icon(Icons.check_circle_outline),
                    title: Text('Открытых заявок нет'),
                  ),
                );
              }

              return Column(
                children: items.map((request) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text('${request.priority}'),
                        ),
                        title: Text(request.type),
                        subtitle: Text(request.status),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openWork(request),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
