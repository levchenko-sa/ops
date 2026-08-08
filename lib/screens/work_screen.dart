import 'dart:io';
import 'package:flutter/material.dart';

import '../models/work_request.dart';
import '../models/material_item.dart';
import '../models/engineer.dart';
import '../models/request_material.dart';
import '../repositories/ops_repository.dart';
import '../services/photo_service.dart';
import '../services/simple_workflow_service.dart';

class WorkScreen extends StatefulWidget {
  final WorkRequest request;

  const WorkScreen({
    super.key,
    required this.request,
  });

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  final _repo = OpsRepository();
  final _workflow = SimpleWorkflowService();
  final _photos = PhotoService();

  final _battery = TextEditingController();
  final _resistance = TextEditingController();
  final _cause = TextEditingController();
  final _work = TextEditingController();
  final _result =
      TextEditingController(text: 'Работоспособность восстановлена');

  String? _beforePath;
  String? _afterPath;
  bool _saving = false;
  bool _started = false;
  bool _detailPhotoMode = false;
  int? _beforeBytes;
  int? _afterBytes;
  late Future<List<RequestMaterial>> _usedMaterials;

  @override
  void initState() {
    super.initState();
    _reloadMaterials();
  }

  void _reloadMaterials() {
    _usedMaterials = _repo.getRequestMaterials(
      widget.request.id!,
    );
  }

  @override
  void dispose() {
    _battery.dispose();
    _resistance.dispose();
    _cause.dispose();
    _work.dispose();
    _result.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await _repo.updateRequestStatus(widget.request.id!, 'В работе');
    if (!mounted) return;
    setState(() => _started = true);
  }

  Future<void> _take(String type) async {
    final photo = await _photos.takeAndPersist(
      requestId: widget.request.id!,
      type: type,
      detailMode: _detailPhotoMode,
    );
    if (photo == null) return;

    await _repo.addPhoto(
      requestId: widget.request.id!,
      type: type,
      path: photo.path,
      fileSizeBytes: photo.bytes,
      captureMode: photo.mode,
    );

    if (!mounted) return;
    setState(() {
      if (type == 'before') {
        _beforePath = photo.path;
        _beforeBytes = photo.bytes;
      } else {
        _afterPath = photo.path;
        _afterBytes = photo.bytes;
      }
    });
  }

  Future<void> _addMaterial() async {
    final choices = <Map<String, Object?>>[];

    final defaultEngineerId = await _workflow.defaultEngineerId();
    Engineer? defaultEngineer;

    if (defaultEngineerId != null) {
      final engineers = await _repo.getEngineers();
      for (final engineer in engineers) {
        if (engineer.id == defaultEngineerId) {
          defaultEngineer = engineer;
          break;
        }
      }

      if (defaultEngineer != null) {
        final mobileStock = await _repo.getEngineerStock(
          defaultEngineer.id!,
        );

        for (final item in mobileStock.where((e) => e.quantity > 0)) {
          choices.add({
            'source_kind': 'engineer',
            'source_name': 'У меня',
            'engineer': defaultEngineer,
            'material_id': item.materialId,
            'name': item.materialName,
            'unit': item.unit,
            'quantity': item.quantity,
            'low': false,
          });
        }
      }
    }

    final warehouse = await _repo.getMaterials();
    for (final item in warehouse.where((e) => e.quantity > 0)) {
      choices.add({
        'source_kind': 'warehouse',
        'source_name': 'Основной склад',
        'material_id': item.id!,
        'name': item.name,
        'unit': item.unit,
        'quantity': item.quantity,
        'low': item.lowStock,
      });
    }

    if (!mounted) return;

    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных материалов'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Что использовано?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (defaultEngineer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Сначала показан ваш мобильный запас. '
                  'Основной склад доступен ниже.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ...choices.map(
              (item) => ListTile(
                leading: Icon(
                  item['source_kind'] == 'engineer'
                      ? Icons.local_shipping_outlined
                      : item['low'] == true
                          ? Icons.warning_amber_rounded
                          : Icons.warehouse_outlined,
                ),
                title: Text(item['name'] as String),
                subtitle: Text(
                  '${item['source_name']} • '
                  '${_formatQuantity(item['quantity'] as double)} '
                  '${item['unit']}',
                ),
                onTap: () => Navigator.pop(context, item),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final available = selected['quantity'] as double;
    final unit = selected['unit'] as String;
    final materialName = selected['name'] as String;
    final materialId = selected['material_id'] as int;
    final sourceKind = selected['source_kind'] as String;
    final sourceName = selected['source_name'] as String;
    final engineer = selected['engineer'] as Engineer?;

    final controller = TextEditingController(text: '1');

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(materialName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$sourceName • доступно '
              '${_formatQuantity(available)} $unit',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Сколько использовано, $unit',
              ),
              onSubmitted: (_) {
                final value = double.tryParse(
                  controller.text.replaceAll(',', '.').trim(),
                );
                if (value != null &&
                    value > 0 &&
                    value <= available) {
                  Navigator.pop(context, value);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(
                controller.text.replaceAll(',', '.').trim(),
              );
              if (value == null ||
                  value <= 0 ||
                  value > available) {
                return;
              }
              Navigator.pop(context, value);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null) return;

    try {
      if (sourceKind == 'engineer' && engineer != null) {
        await _repo.consumeEngineerMaterialForRequest(
          requestId: widget.request.id!,
          engineerId: engineer.id!,
          materialId: materialId,
          quantity: result,
        );
      } else {
        await _repo.consumeMaterialForRequest(
          requestId: widget.request.id!,
          materialId: materialId,
          quantity: result,
        );
      }

      if (!mounted) return;
      setState(_reloadMaterials);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$materialName • ${_formatQuantity(result)} $unit',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _removeMaterial(RequestMaterial item) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Отменить списание?'),
            content: Text(
              '${item.materialName}: '
              '${_formatQuantity(item.quantity)} ${item.unit}\n\n'
              '${item.sourceKind == 'engineer'
                  ? 'Количество будет возвращено инженеру ${item.sourceEngineerName}.'
                  : 'Количество будет возвращено на основной склад.'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Не менять'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Вернуть'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    await _repo.removeRequestMaterial(item.id!);
    if (!mounted) return;
    setState(_reloadMaterials);
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  Future<void> _pickReference({
    required String category,
    required String title,
    required TextEditingController controller,
  }) async {
    final values = await _repo.getReferenceValues(category);
    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...values.map(
              (item) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(item.value),
                onTap: () => Navigator.pop(
                  context,
                  item.value,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      controller.text = selected;
    }
  }

  Future<void> _complete() async {
    if (_work.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Коротко укажите, что сделали'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    await _repo.saveWorkReport(
      requestId: widget.request.id!,
      batteryVoltage:
          double.tryParse(_battery.text.replaceAll(',', '.').trim()),
      loopResistanceKohm:
          double.tryParse(_resistance.text.replaceAll(',', '.').trim()),
      cause: _cause.text.trim().isEmpty
          ? 'Не установлена'
          : _cause.text.trim(),
      workDone: _work.text.trim(),
      result: _result.text.trim().isEmpty
          ? 'Работоспособность восстановлена'
          : _result.text.trim(),
    );

    if (await _workflow.autoPrepareWriteoffEnabled()) {
      try {
        await _repo.prepareWriteoffIfPossible(widget.request.id!);
      } catch (_) {
        // Документы не должны мешать инженеру закрыть работу.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Widget _photoCard(
    String title,
    String? path,
    int? bytes,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 150,
          child: path == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_camera, size: 36),
                      const SizedBox(height: 8),
                      Text(title),
                    ],
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: 640,
                      filterQuality: FilterQuality.low,
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black54,
                        child: Text(
                          bytes == null
                              ? title
                              : '$title • ${(bytes / 1024).round()} КБ',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.request.address),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${widget.request.priority}'),
              ),
              title: Text(widget.request.type),
              subtitle: Text(
                _started
                    ? 'Статус: В работе'
                    : 'Статус: ${widget.request.status}',
              ),
              trailing: !_started
                  ? FilledButton(
                      onPressed: _start,
                      child: const Text('Начать'),
                    )
                  : const Icon(Icons.build_circle),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Измерения',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _battery,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'АКБ, В',
              hintText: '13.6',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _resistance,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Сопротивление ШС, кОм',
              hintText: '2.2',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Материалы',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                onPressed: _addMaterial,
                icon: const Icon(Icons.add),
                tooltip: 'Добавить использованный материал',
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<RequestMaterial>>(
            future: _usedMaterials,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('Материалы не использовались'),
                    subtitle: Text(
                      'Нажмите +, если при ремонте что-то использовали.',
                    ),
                  ),
                );
              }

              return Column(
                children: items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.build_outlined),
                        title: Text(item.materialName),
                        subtitle: Text(
                          '${_formatQuantity(item.quantity)} ${item.unit}\n'
                          '${item.sourceKind == 'engineer'
                              ? 'Из запаса: ${item.sourceEngineerName}'
                              : 'Основной склад'}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          onPressed: () => _removeMaterial(item),
                          icon: const Icon(Icons.undo),
                          tooltip: 'Отменить списание и вернуть в источник',
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Фото',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _detailPhotoMode,
            onChanged: (value) {
              setState(() => _detailPhotoMode = value);
            },
            title: Text(
              _detailPhotoMode
                  ? 'Детальный режим фото'
                  : 'Лёгкий режим фото',
            ),
            subtitle: Text(
              _detailPhotoMode
                  ? '2048 px • JPEG 82% • для мелкой маркировки'
                  : 'Сжатый снимок • режим по умолчанию',
            ),
            secondary: Icon(
              _detailPhotoMode
                  ? Icons.high_quality
                  : Icons.data_saver_on,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _photoCard(
                  'До ремонта',
                  _beforePath,
                  _beforeBytes,
                  () => _take('before'),
                ),
              ),
              Expanded(
                child: _photoCard(
                  'После ремонта',
                  _afterPath,
                  _afterBytes,
                  () => _take('after'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cause,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Причина (если известна)',
              alignLabelWithHint: true,
              suffixIcon: IconButton(
                onPressed: () => _pickReference(
                  category: 'fault_cause',
                  title: 'Причина неисправности',
                  controller: _cause,
                ),
                icon: const Icon(Icons.menu_book_outlined),
                tooltip: 'Выбрать из справочника',
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _work,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Что сделано *',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _result,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Результат (по умолчанию: восстановлено)',
              alignLabelWithHint: true,
              suffixIcon: IconButton(
                onPressed: () => _pickReference(
                  category: 'work_result',
                  title: 'Результат работы',
                  controller: _result,
                ),
                icon: const Icon(Icons.menu_book_outlined),
                tooltip: 'Выбрать из справочника',
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _complete,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.task_alt),
            label: const Text('Завершить работу'),
          ),
        ],
      ),
    );
  }
}
