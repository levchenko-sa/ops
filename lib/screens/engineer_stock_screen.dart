import 'package:flutter/material.dart';

import '../models/engineer.dart';
import '../models/engineer_stock_item.dart';
import '../models/material_item.dart';
import '../models/stock_transfer.dart';
import '../repositories/ops_repository.dart';
import '../services/simple_workflow_service.dart';

class EngineerStockScreen extends StatefulWidget {
  const EngineerStockScreen({super.key});

  @override
  State<EngineerStockScreen> createState() =>
      _EngineerStockScreenState();
}

class _EngineerStockScreenState extends State<EngineerStockScreen> {
  final _repo = OpsRepository();
  final _workflow = SimpleWorkflowService();
  int? _defaultEngineerId;
  late Future<List<Engineer>> _engineers;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadDefault();
  }

  Future<void> _loadDefault() async {
    final id = await _workflow.defaultEngineerId();
    if (!mounted) return;
    setState(() => _defaultEngineerId = id);
  }

  void _reload() {
    _engineers = _repo.getEngineers(activeOnly: false);
  }

  Future<void> _setDefault(Engineer engineer) async {
    final next = _defaultEngineerId == engineer.id
        ? null
        : engineer.id;
    await _workflow.setDefaultEngineerId(next);
    if (!mounted) return;
    setState(() => _defaultEngineerId = next);
  }

  Future<void> _addEngineer() async {
    final name = TextEditingController();
    final vehicle = TextEditingController();

    final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Инженер / автомобиль'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Имя / обозначение *',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: vehicle,
                  decoration: const InputDecoration(
                    labelText: 'Автомобиль / госномер',
                  ),
                ),
              ],
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
        ) ??
        false;

    if (ok) {
      final id = await _repo.addEngineer(
        name: name.text,
        vehicle: vehicle.text,
      );

      final currentDefault = await _workflow.defaultEngineerId();
      if (currentDefault == null) {
        await _workflow.setDefaultEngineerId(id);
        _defaultEngineerId = id;
      }

      if (mounted) setState(_reload);
    }

    name.dispose();
    vehicle.dispose();
  }

  Future<void> _open(Engineer engineer) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EngineerStockDetailScreen(
          engineer: engineer,
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мобильный запас')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addEngineer,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Добавить'),
      ),
      body: FutureBuilder<List<Engineer>>(
        future: _engineers,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text(
                'Добавьте себя или автомобиль.\n'
                'Звёздочкой отметьте свой основной мобильный запас.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final engineer = items[index];

              final isDefault =
                  engineer.id == _defaultEngineerId;

              return Card(
                child: ListTile(
                  onTap: () => _open(engineer),
                  leading: Icon(
                    engineer.active
                        ? Icons.engineering_outlined
                        : Icons.person_off_outlined,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(engineer.name)),
                      if (isDefault)
                        const Chip(
                          label: Text('Мой'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  subtitle: Text(
                    [
                      if (engineer.vehicle.isNotEmpty)
                        engineer.vehicle,
                      engineer.active ? 'Активен' : 'Отключён',
                    ].join(' • '),
                  ),
                  trailing: IconButton(
                    onPressed: engineer.active
                        ? () => _setDefault(engineer)
                        : null,
                    icon: Icon(
                      isDefault ? Icons.star : Icons.star_border,
                    ),
                    tooltip: isDefault
                        ? 'Убрать как мой запас'
                        : 'Использовать как мой запас',
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

class EngineerStockDetailScreen extends StatefulWidget {
  final Engineer engineer;

  const EngineerStockDetailScreen({
    super.key,
    required this.engineer,
  });

  @override
  State<EngineerStockDetailScreen> createState() =>
      _EngineerStockDetailScreenState();
}

class _EngineerStockDetailScreenState
    extends State<EngineerStockDetailScreen> {
  final _repo = OpsRepository();
  late Future<List<EngineerStockItem>> _stock;
  late Future<List<StockTransfer>> _transfers;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _stock = _repo.getEngineerStock(widget.engineer.id!);
    _transfers = _repo.getStockTransfers(
      engineerId: widget.engineer.id!,
      limit: 20,
    );
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<double?> _quantityDialog({
    required String title,
    required String unit,
    required double max,
  }) async {
    final controller = TextEditingController(text: '1');

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Доступно: ${_fmt(max)} $unit'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Количество, $unit',
              ),
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
              if (value == null || value <= 0 || value > max) return;
              Navigator.pop(context, value);
            },
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _issue() async {
    final materials = (await _repo.getMaterials())
        .where((item) => item.quantity > 0)
        .toList();

    if (!mounted) return;

    final selected = await showModalBottomSheet<MaterialItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Выдать с основного склада',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...materials.map(
              (item) => ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.name),
                subtitle: Text(
                  '${_fmt(item.quantity)} ${item.unit} на складе',
                ),
                onTap: () => Navigator.pop(context, item),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final qty = await _quantityDialog(
      title: selected.name,
      unit: selected.unit,
      max: selected.quantity,
    );
    if (qty == null) return;

    await _repo.transferMaterialToEngineer(
      engineerId: widget.engineer.id!,
      materialId: selected.id!,
      quantity: qty,
      comment: 'Выдача в мобильный запас',
    );

    if (mounted) setState(_reload);
  }

  Future<void> _return(EngineerStockItem item) async {
    final qty = await _quantityDialog(
      title: 'Вернуть: ${item.materialName}',
      unit: item.unit,
      max: item.quantity,
    );
    if (qty == null) return;

    await _repo.returnMaterialFromEngineer(
      engineerId: widget.engineer.id!,
      materialId: item.materialId,
      quantity: qty,
      comment: 'Возврат из мобильного запаса',
    );

    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.engineer.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _issue,
        icon: const Icon(Icons.move_to_inbox_outlined),
        label: const Text('Выдать'),
      ),
      body: FutureBuilder<List<EngineerStockItem>>(
        future: _stock,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final items = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(widget.engineer.name),
                  subtitle: Text(
                    widget.engineer.vehicle.isEmpty
                        ? 'Мобильный запас'
                        : widget.engineer.vehicle,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Выдача инженеру — внутреннее перемещение. '
                    'Материал остаётся запасом организации и будет '
                    'списан в расход только при использовании '
                    'на конкретной заявке.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Материалы у инженера',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('Запас пуст'),
                  ),
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.build_outlined),
                        title: Text(item.materialName),
                        subtitle: Text(
                          '${_fmt(item.quantity)} ${item.unit}\n'
                          'Основной склад: '
                          '${_fmt(item.warehouseQuantity)} ${item.unit}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          onPressed: () => _return(item),
                          icon: const Icon(Icons.keyboard_return),
                          tooltip: 'Вернуть на основной склад',
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'Последние перемещения',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<StockTransfer>>(
                future: _transfers,
                builder: (context, transferSnapshot) {
                  if (!transferSnapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final transfers = transferSnapshot.data!;
                  if (transfers.isEmpty) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.swap_horiz),
                        title: Text('Перемещений пока нет'),
                      ),
                    );
                  }

                  return Column(
                    children: transfers.map((transfer) {
                      final issue =
                          transfer.transferType == 'issue_to_engineer';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              issue
                                  ? Icons.outbox_outlined
                                  : Icons.move_to_inbox_outlined,
                            ),
                            title: Text(
                              issue
                                  ? 'Выдача со склада'
                                  : 'Возврат на склад',
                            ),
                            subtitle: Text(
                              transfer.comment.isEmpty
                                  ? 'Учтено автоматически'
                                  : transfer.comment,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
