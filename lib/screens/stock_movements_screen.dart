import 'package:flutter/material.dart';

import '../models/material_item.dart';
import '../models/stock_movement.dart';
import '../repositories/ops_repository.dart';

class StockMovementsScreen extends StatefulWidget {
  final MaterialItem material;

  const StockMovementsScreen({
    super.key,
    required this.material,
  });

  @override
  State<StockMovementsScreen> createState() =>
      _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  final _repo = OpsRepository();
  late Future<List<StockMovement>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.getStockMovements(
      materialId: widget.material.id,
      limit: 200,
    );
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  String _typeText(String type) {
    switch (type) {
      case 'consume':
        return 'Списание на заявку';
      case 'return':
        return 'Возврат';
      case 'manual_issue':
        return 'Ручное списание';
      case 'receipt':
        return 'Поступление';
      case 'issue_engineer':
        return 'Выдача инженеру';
      case 'return_warehouse':
        return 'Возврат от инженера';
      case 'consume_engineer':
        return 'Расход из запаса инженера';
      case 'return_engineer':
        return 'Возврат в запас инженера';
      default:
        return type;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'return':
        return Icons.undo;
      case 'consume':
        return Icons.build_outlined;
      case 'receipt':
        return Icons.inventory_2_outlined;
      case 'issue_engineer':
        return Icons.outbox_outlined;
      case 'return_warehouse':
        return Icons.move_to_inbox_outlined;
      case 'consume_engineer':
        return Icons.engineering_outlined;
      case 'return_engineer':
        return Icons.undo;
      default:
        return Icons.swap_vert;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.material.name),
      ),
      body: FutureBuilder<List<StockMovement>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('Движений пока нет'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final sign = item.quantity > 0 ? '+' : '';

              return Card(
                child: ListTile(
                  leading: Icon(_icon(item.movementType)),
                  title: Text(_typeText(item.movementType)),
                  subtitle: Text(
                    'Изменение: $sign${_fmt(item.quantity)} '
                    '${widget.material.unit}\n'
                    'Остаток после операции: '
                    '${_fmt(item.balanceAfter)} '
                    '${widget.material.unit}'
                    '${item.requestId == null ? '' : '\nЗаявка №${item.requestId}'}'
                    '${item.comment.trim().isEmpty ? '' : '\n${item.comment}'}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
