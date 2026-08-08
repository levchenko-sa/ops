import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ops_object.dart';
import '../repositories/ops_repository.dart';
import 'object_detail_screen.dart';

class ObjectsScreen extends StatefulWidget {
  const ObjectsScreen({super.key});

  @override
  State<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends State<ObjectsScreen> {
  final _repo = OpsRepository();
  final _search = TextEditingController();

  Timer? _debounce;
  late Future<List<OpsObject>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _future = _repo.getObjects(
      search: _search.text,
      limit: 300,
    );
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () {
        if (!mounted) return;
        setState(_reload);
      },
    );
  }

  Future<void> _open(OpsObject object) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ObjectDetailScreen(object: object),
      ),
    );

    if (!mounted) return;
    setState(_reload);
  }

  IconData _connectionIcon(String connection) {
    final value = connection.toLowerCase();
    if (value.contains('ethernet') || value.contains('lan')) {
      return Icons.lan_outlined;
    }
    return Icons.sim_card_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Объекты')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Адрес объекта',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(_reload);
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<OpsObject>>(
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
                    child: Text('Объекты не найдены'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final object = items[index];

                    return Card(
                      child: ListTile(
                        onTap: () => _open(object),
                        leading: Icon(
                          _connectionIcon(object.connection),
                        ),
                        title: Text(object.address),
                        subtitle: Text(
                          '${object.system} • ${object.connection}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
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
