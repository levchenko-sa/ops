import 'dart:io';

import 'package:flutter/material.dart';

import '../models/object_history_entry.dart';
import '../models/photo_record.dart';
import '../models/request_material.dart';
import '../repositories/ops_repository.dart';
import 'inventory_document_detail_screen.dart';
import 'organization_settings_screen.dart';

class HistoryEntryScreen extends StatefulWidget {
  final String address;
  final ObjectHistoryEntry entry;

  const HistoryEntryScreen({
    super.key,
    required this.address,
    required this.entry,
  });

  @override
  State<HistoryEntryScreen> createState() => _HistoryEntryScreenState();
}

class _HistoryEntryScreenState extends State<HistoryEntryScreen> {
  final _repo = OpsRepository();
  late Future<List<PhotoRecord>> _photos;
  late Future<List<RequestMaterial>> _materials;

  @override
  void initState() {
    super.initState();
    _photos = _repo.getPhotos(widget.entry.requestId);
    _materials = _repo.getRequestMaterials(widget.entry.requestId);
  }

  String _value(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _createWriteoffAct() async {
    final existing = await _repo.getWriteoffDocumentIdForRequest(
      widget.entry.requestId,
    );

    if (!mounted) return;

    if (existing != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InventoryDocumentDetailScreen(
            documentId: existing,
          ),
        ),
      );
      return;
    }

    final materials = await _repo.getRequestMaterials(
      widget.entry.requestId,
    );

    if (!mounted) return;

    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('По этой работе материалы не использовались'),
        ),
      );
      return;
    }

    final profile = await _repo.getOrganizationProfile();

    if (!profile.hasMinimumLegalDetails) {
      final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Для печатного акта нужны реквизиты'),
              content: const Text(
                'Работа уже сохранена. Реквизиты можно заполнить '
                'один раз сейчас и больше к ним не возвращаться.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Не сейчас'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Заполнить'),
                ),
              ],
            ),
          ) ??
          false;

      if (openSettings && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const OrganizationSettingsScreen(),
          ),
        );
      }
      return;
    }

    final id = await _repo.createWriteoffDocumentForRequest(
      widget.entry.requestId,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryDocumentDetailScreen(
          documentId: id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;

    return Scaffold(
      appBar: AppBar(title: Text(widget.address)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _row('Событие', e.type),
                  _row('Статус', e.status),
                  _row('Дата', e.createdAt),
                  _row(
                    'АКБ',
                    e.batteryVoltage == null
                        ? '—'
                        : '${e.batteryVoltage} В',
                  ),
                  _row(
                    'ШС',
                    e.loopResistanceKohm == null
                        ? '—'
                        : '${e.loopResistanceKohm} кОм',
                  ),
                  _row('Причина', _value(e.cause)),
                  _row('Что сделано', _value(e.workDone)),
                  _row('Результат', _value(e.result)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Использованные материалы',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<RequestMaterial>>(
            future: _materials,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('Материалы не списывались'),
                  ),
                );
              }

              return Card(
                child: Column(
                  children: items.map((item) {
                    final qty = item.quantity ==
                            item.quantity.roundToDouble()
                        ? item.quantity.toStringAsFixed(0)
                        : item.quantity.toStringAsFixed(2);

                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.build_outlined),
                      title: Text(item.materialName),
                      subtitle: Text(
                        item.sourceKind == 'engineer'
                            ? 'Из запаса: ${item.sourceEngineerName}'
                            : 'Основной склад',
                      ),
                      trailing: Text('$qty ${item.unit}'),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _createWriteoffAct,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Акт списания'),
          ),
          const SizedBox(height: 12),
          Text(
            'Фото на телефоне (${e.photoCount})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (e.archivedPhotoCount > 0)
            Card(
              child: ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: Text(
                  'В архиве: ${e.archivedPhotoCount} фото',
                ),
                subtitle: const Text(
                  'Они удалены из активного хранилища для экономии '
                  'места и могут быть возвращены импортом архива.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          FutureBuilder<List<PhotoRecord>>(
            future: _photos,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.photo_outlined),
                    title: Text('Фотографий нет'),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final photo = items[index];
                  final file = File(photo.path);

                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          file,
                          fit: BoxFit.cover,
                          cacheWidth: 640,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(Icons.broken_image_outlined),
                            );
                          },
                        ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(6),
                            color: Colors.black54,
                            child: Text(
                              '${photo.type == 'before'
                                  ? 'До ремонта'
                                  : photo.type == 'after'
                                      ? 'После ремонта'
                                      : photo.type}'
                              '${photo.fileSizeBytes > 0
                                  ? ' • ${(photo.fileSizeBytes / 1024).round()} КБ'
                                  : ''}'
                              '${photo.captureMode == 'detail'
                                  ? ' • детально'
                                  : ''}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
