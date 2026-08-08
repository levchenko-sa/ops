import 'package:flutter/material.dart';

import '../models/ops_object.dart';
import '../repositories/ops_repository.dart';

class ObjectEditScreen extends StatefulWidget {
  final OpsObject object;

  const ObjectEditScreen({
    super.key,
    required this.object,
  });

  @override
  State<ObjectEditScreen> createState() => _ObjectEditScreenState();
}

class _ObjectEditScreenState extends State<ObjectEditScreen> {
  final _repo = OpsRepository();

  late final TextEditingController _address;
  late final TextEditingController _system;
  late final TextEditingController _connection;
  late final TextEditingController _status;
  late final TextEditingController _entrances;
  late final TextEditingController _notes;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _address = TextEditingController(text: widget.object.address);
    _system = TextEditingController(text: widget.object.system);
    _connection = TextEditingController(text: widget.object.connection);
    _status = TextEditingController(text: widget.object.status);
    _entrances = TextEditingController(
      text: widget.object.entrances?.toString() ?? '',
    );
    _notes = TextEditingController(text: widget.object.notes);
  }

  @override
  void dispose() {
    _address.dispose();
    _system.dispose();
    _connection.dispose();
    _status.dispose();
    _entrances.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final address = _address.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите адрес')),
      );
      return;
    }

    setState(() => _saving = true);

    final updated = widget.object.copyWith(
      address: address,
      system: _system.text.trim(),
      connection: _connection.text.trim(),
      status: _status.text.trim(),
      notes: _notes.text.trim(),
      entrances: int.tryParse(_entrances.text.trim()),
    );

    await _repo.updateObjectPassport(updated);

    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Редактирование объекта')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Адрес',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _system,
            decoration: const InputDecoration(
              labelText: 'Система',
              prefixIcon: Icon(Icons.security_outlined),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: ['SIM', 'Ethernet', 'SIM + Ethernet']
                    .contains(_connection.text)
                ? _connection.text
                : null,
            decoration: const InputDecoration(
              labelText: 'Связь',
              prefixIcon: Icon(Icons.cell_tower_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'SIM', child: Text('SIM')),
              DropdownMenuItem(
                value: 'Ethernet',
                child: Text('Ethernet'),
              ),
              DropdownMenuItem(
                value: 'SIM + Ethernet',
                child: Text('SIM + Ethernet'),
              ),
            ],
            onChanged: (value) {
              if (value != null) _connection.text = value;
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: ['Норма', 'Внимание', 'Авария'].contains(_status.text)
                ? _status.text
                : null,
            decoration: const InputDecoration(
              labelText: 'Состояние',
              prefixIcon: Icon(Icons.monitor_heart_outlined),
            ),
            items: const [
              DropdownMenuItem(value: 'Норма', child: Text('Норма')),
              DropdownMenuItem(
                value: 'Внимание',
                child: Text('Внимание'),
              ),
              DropdownMenuItem(value: 'Авария', child: Text('Авария')),
            ],
            onChanged: (value) {
              if (value != null) _status.text = value;
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _entrances,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Подъездов',
              prefixIcon: Icon(Icons.door_front_door_outlined),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'Примечание',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить паспорт'),
          ),
        ],
      ),
    );
  }
}
