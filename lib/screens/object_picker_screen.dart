import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ops_object.dart';
import '../repositories/ops_repository.dart';

class ObjectPickerScreen extends StatefulWidget {
  const ObjectPickerScreen({super.key});

  @override
  State<ObjectPickerScreen> createState() => _ObjectPickerScreenState();
}

class _ObjectPickerScreenState extends State<ObjectPickerScreen> {
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
      limit: 100,
    );
  }

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 220),
      () {
        if (!mounted) return;
        setState(_reload);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите объект')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Начните вводить адрес',
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
                    child: Text('Ничего не найдено'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final object = items[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          onTap: () => Navigator.pop(
                            context,
                            object,
                          ),
                          leading: Icon(
                            object.connection
                                    .toLowerCase()
                                    .contains('ethernet')
                                ? Icons.lan_outlined
                                : Icons.sim_card_outlined,
                          ),
                          title: Text(object.address),
                          subtitle: Text(
                            '${object.system} • ${object.connection}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
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
