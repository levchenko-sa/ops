import 'package:flutter/material.dart';

import '../models/goods_receipt.dart';
import '../models/goods_receipt_item.dart';
import '../repositories/ops_repository.dart';

class GoodsReceiptDetailScreen extends StatefulWidget {
  final int receiptId;

  const GoodsReceiptDetailScreen({
    super.key,
    required this.receiptId,
  });

  @override
  State<GoodsReceiptDetailScreen> createState() =>
      _GoodsReceiptDetailScreenState();
}

class _GoodsReceiptDetailScreenState
    extends State<GoodsReceiptDetailScreen> {
  final _repo = OpsRepository();

  late Future<GoodsReceipt?> _receipt;
  late Future<List<GoodsReceiptItem>> _items;

  @override
  void initState() {
    super.initState();
    _receipt = _repo.getGoodsReceipt(widget.receiptId);
    _items = _repo.getGoodsReceiptItems(widget.receiptId);
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GoodsReceipt?>(
      future: _receipt,
      builder: (context, snapshot) {
        final receipt = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              receipt == null
                  ? 'Поступление'
                  : receipt.receiptNumber,
            ),
          ),
          body: receipt == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.inventory_2_outlined,
                            ),
                            title: Text(
                              'Поступление ${receipt.receiptNumber}',
                            ),
                            subtitle: Text(
                              '${receipt.supplierName}\n'
                              '${receipt.supplierDocumentType} '
                              '№ ${receipt.supplierDocumentNumber} '
                              'от ${receipt.supplierDocumentDate}',
                            ),
                            isThreeLine: true,
                          ),
                          const Divider(),
                          if (receipt.purchaseDocumentId != null)
                            ListTile(
                              dense: true,
                              title: const Text(
                                'Связано с заявкой на закупку',
                              ),
                              subtitle: Text(
                                'Документ OPS Control '
                                'ID ${receipt.purchaseDocumentId}',
                              ),
                            ),
                          ListTile(
                            dense: true,
                            title: const Text('Сумма поступления'),
                            trailing: Text(
                              '${receipt.totalAmount.toStringAsFixed(2)} ₽',
                            ),
                          ),
                          if (receipt.notes.isNotEmpty)
                            ListTile(
                              dense: true,
                              title: const Text('Примечание'),
                              subtitle: Text(receipt.notes),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Принято на склад',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<GoodsReceiptItem>>(
                      future: _items,
                      builder: (context, itemsSnapshot) {
                        if (!itemsSnapshot.hasData) {
                          return const LinearProgressIndicator();
                        }

                        return Column(
                          children: itemsSnapshot.data!.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                child: ListTile(
                                  title: Text(item.itemName),
                                  subtitle: Text(
                                    '${_fmt(item.quantity)} ${item.unit} '
                                    '× ${item.unitPrice.toStringAsFixed(2)} ₽'
                                    '${item.comment.isEmpty ? '' : '\n${item.comment}'}',
                                  ),
                                  trailing: Text(
                                    '${item.amount.toStringAsFixed(2)} ₽',
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Остатки склада уже увеличены. По каждой '
                          'позиции создана партия с фактической ценой '
                          'поставки и запись в журнале движения склада.',
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
