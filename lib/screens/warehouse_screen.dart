import 'package:flutter/material.dart';

import '../models/material_item.dart';
import '../repositories/ops_repository.dart';
import 'stock_movements_screen.dart';
import 'stock_batches_screen.dart';
import 'engineer_stock_screen.dart';
import 'inventory_documents_screen.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final _repo = OpsRepository();
  late Future<List<MaterialItem>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.getMaterials();
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _openHistory(MaterialItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StockMovementsScreen(material: item),
      ),
    );

    if (mounted) setState(_reload);
  }

  Future<void> _editPlanning(MaterialItem item) async {
    final minQty = TextEditingController(
      text: _fmt(item.minQuantity),
    );
    final price = TextEditingController(
      text: item.accountingPrice <= 0
          ? ''
          : item.accountingPrice.toStringAsFixed(2),
    );

    final save = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(item.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: minQty,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Минимальный остаток, ${item.unit}',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: price,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Учетная цена, руб. за единицу',
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
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ) ??
        false;

    if (save) {
      final min = double.tryParse(
        minQty.text.replaceAll(',', '.').trim(),
      );
      final accountingPrice = double.tryParse(
            price.text.replaceAll(',', '.').trim(),
          ) ??
          0;

      if (min != null && min >= 0 && accountingPrice >= 0) {
        await _repo.updateMaterialPlanning(
          materialId: item.id!,
          minQuantity: min,
          accountingPrice: accountingPrice,
        );

        if (mounted) setState(_reload);
      }
    }

    minQty.dispose();
    price.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Склад'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EngineerStockScreen(),
              ),
            ),
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'Склад у инженеров',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const InventoryDocumentsScreen(),
              ),
            ),
            icon: const Icon(Icons.description_outlined),
            tooltip: 'Документы закупки и списания',
          ),
        ],
      ),
      body: FutureBuilder<List<MaterialItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    onTap: () => _openHistory(item),
                    leading: Icon(
                      item.lowStock
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2,
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      'Остаток: ${_fmt(item.quantity)} ${item.unit} • '
                      'минимум ${_fmt(item.minQuantity)}'
                      '${item.accountingPrice <= 0 ? '' : '\nУчетная цена: ${item.accountingPrice.toStringAsFixed(2)} ₽/${item.unit}'}',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'history') {
                          _openHistory(item);
                        } else if (value == 'price') {
                          _editPlanning(item);
                        } else if (value == 'batches') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  StockBatchesScreen(material: item),
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'history',
                          child: Text('Движение склада'),
                        ),
                        PopupMenuItem(
                          value: 'price',
                          child: Text('Минимум и учетная цена'),
                        ),
                        PopupMenuItem(
                          value: 'batches',
                          child: Text('Партии поступления'),
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
