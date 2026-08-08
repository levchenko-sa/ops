import 'package:flutter/material.dart';

import '../models/inventory_document.dart';
import '../repositories/ops_repository.dart';
import 'inventory_document_detail_screen.dart';
import 'organization_settings_screen.dart';
import 'goods_receipt_screen.dart';
import 'goods_receipt_detail_screen.dart';
import '../models/goods_receipt.dart';

class InventoryDocumentsScreen extends StatefulWidget {
  const InventoryDocumentsScreen({super.key});

  @override
  State<InventoryDocumentsScreen> createState() =>
      _InventoryDocumentsScreenState();
}

class _InventoryDocumentsScreenState
    extends State<InventoryDocumentsScreen> {
  final _repo = OpsRepository();

  late Future<List<InventoryDocument>> _future;
  late Future<List<GoodsReceipt>> _receipts;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _repo.getInventoryDocuments(limit: 100);
    _receipts = _repo.getGoodsReceipts(limit: 30);
  }

  Future<void> _open(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryDocumentDetailScreen(
          documentId: id,
        ),
      ),
    );

    if (mounted) setState(_reload);
  }

  Future<void> _purchaseRequest() async {
    setState(() => _busy = true);

    try {
      final id = await _repo.createPurchaseRequestFromLowStock();
      if (!mounted) return;
      await _open(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newReceipt() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GoodsReceiptScreen(),
      ),
    );

    if (mounted) setState(_reload);
  }

  Future<void> _openReceipt(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoodsReceiptDetailScreen(receiptId: id),
      ),
    );

    if (mounted) setState(_reload);
  }

  String _typeName(String type) {
    return type == 'writeoff_act'
        ? 'Акт списания'
        : 'Заявка на закупку';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Складские документы'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const OrganizationSettingsScreen(),
                ),
              );
              if (mounted) setState(_reload);
            },
            icon: const Icon(Icons.business_outlined),
            tooltip: 'Реквизиты организации',
          ),
        ],
      ),
      body: FutureBuilder<List<InventoryDocument>>(
        future: _future,
        builder: (context, snapshot) {
          final docs = snapshot.data ?? const <InventoryDocument>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _purchaseRequest,
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text(
                  'Сформировать заявку по низким остаткам',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _newReceipt,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Оприходовать поставку'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const OrganizationSettingsScreen(),
                  ),
                ),
                icon: const Icon(Icons.business_outlined),
                label: const Text('Реквизиты для печатных документов'),
              ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 20),
              Text(
                'Документы',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (!snapshot.hasData)
                const LinearProgressIndicator()
              else if (docs.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.description_outlined),
                    title: Text('Документов пока нет'),
                  ),
                )
              else
                ...docs.map(
                  (doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        onTap: () => _open(doc.id!),
                        leading: Icon(
                          doc.documentType == 'writeoff_act'
                              ? Icons.receipt_long_outlined
                              : Icons.shopping_cart_outlined,
                        ),
                        title: Text(
                          '${_typeName(doc.documentType)} '
                          '№ ${doc.documentNumber}',
                        ),
                        subtitle: Text(
                          doc.basis.isEmpty ? 'Без основания' : doc.basis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Последние поступления',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<GoodsReceipt>>(
                future: _receipts,
                builder: (context, receiptSnapshot) {
                  if (!receiptSnapshot.hasData) {
                    return const LinearProgressIndicator();
                  }

                  final receipts = receiptSnapshot.data!;
                  if (receipts.isEmpty) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.inventory_2_outlined),
                        title: Text('Поступлений пока нет'),
                      ),
                    );
                  }

                  return Column(
                    children: receipts.map((receipt) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            onTap: () => _openReceipt(receipt.id!),
                            leading: const Icon(
                              Icons.inventory_2_outlined,
                            ),
                            title: Text(
                              '${receipt.receiptNumber} • '
                              '${receipt.supplierName}',
                            ),
                            subtitle: Text(
                              '${receipt.supplierDocumentType} '
                              '№ ${receipt.supplierDocumentNumber} '
                              'от ${receipt.supplierDocumentDate}',
                            ),
                            trailing: Text(
                              '${receipt.totalAmount.toStringAsFixed(2)} ₽',
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
                    'Акт списания создаётся из фактически списанных '
                    'материалов конкретной заявки. Откройте выполненную '
                    'работу в истории и выберите «Акт списания».',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
