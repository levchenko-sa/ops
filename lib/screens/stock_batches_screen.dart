import 'package:flutter/material.dart';

import '../models/material_item.dart';
import '../models/stock_batch.dart';
import '../repositories/ops_repository.dart';

class StockBatchesScreen extends StatefulWidget {
  final MaterialItem material;

  const StockBatchesScreen({
    super.key,
    required this.material,
  });

  @override
  State<StockBatchesScreen> createState() =>
      _StockBatchesScreenState();
}

class _StockBatchesScreenState extends State<StockBatchesScreen> {
  final _repo = OpsRepository();
  late Future<List<StockBatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getStockBatches(
      widget.material.id!,
      limit: 100,
    );
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Партии • ${widget.material.name}'),
      ),
      body: FutureBuilder<List<StockBatch>>(
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
              child: Text('Поступивших партий пока нет'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(
                    '${_fmt(item.quantityReceived)} '
                    '${widget.material.unit} • '
                    '${item.unitPrice.toStringAsFixed(2)} ₽/ед.',
                  ),
                  subtitle: Text(
                    '${item.supplierName}'
                    '${item.supplierDocument.isEmpty ? '' : '\n${item.supplierDocument}'}',
                  ),
                  trailing: Text(
                    'Приход №${item.receiptId}',
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
