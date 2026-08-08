import 'dart:io';

import 'package:flutter/material.dart';

import '../models/inventory_document.dart';
import '../models/inventory_document_item.dart';
import '../repositories/ops_repository.dart';
import '../services/inventory_document_pdf_service.dart';
import 'goods_receipt_screen.dart';

class InventoryDocumentDetailScreen extends StatefulWidget {
  final int documentId;

  const InventoryDocumentDetailScreen({
    super.key,
    required this.documentId,
  });

  @override
  State<InventoryDocumentDetailScreen> createState() =>
      _InventoryDocumentDetailScreenState();
}

class _InventoryDocumentDetailScreenState
    extends State<InventoryDocumentDetailScreen> {
  final _repo = OpsRepository();
  final _pdf = InventoryDocumentPdfService();

  late Future<InventoryDocument?> _document;
  late Future<List<InventoryDocumentItem>> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _document = _repo.getInventoryDocument(widget.documentId);
    _items = _repo.getInventoryDocumentItems(widget.documentId);
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _editPurchaseItem(
    InventoryDocumentItem item,
  ) async {
    final quantity = TextEditingController(
      text: _fmt(item.quantity),
    );
    final price = TextEditingController(
      text: item.unitPrice <= 0
          ? ''
          : item.unitPrice.toStringAsFixed(2),
    );
    final comment = TextEditingController(
      text: item.comment,
    );

    final save = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(item.itemName),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Количество, ${item.unit}',
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
                      labelText: 'Ориентировочная цена, руб.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: comment,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Примечание',
                    ),
                  ),
                ],
              ),
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
      final q = double.tryParse(
        quantity.text.replaceAll(',', '.').trim(),
      );
      final p = double.tryParse(
            price.text.replaceAll(',', '.').trim(),
          ) ??
          0;

      if (q != null && q > 0 && p >= 0) {
        await _repo.updateInventoryDocumentItem(
          itemId: item.id!,
          quantity: q,
          unitPrice: p,
          comment: comment.text,
        );

        if (mounted) setState(_reload);
      }
    }

    quantity.dispose();
    price.dispose();
    comment.dispose();
  }

  Future<void> _receivePurchase(
    InventoryDocument document,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoodsReceiptScreen(
          initialPurchaseDocument: document,
        ),
      ),
    );

    if (mounted) setState(_reload);
  }

  Future<void> _share() async {
    setState(() => _busy = true);

    try {
      await _pdf.share(widget.documentId);
      if (!mounted) return;
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сформировать PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InventoryDocument?>(
      future: _document,
      builder: (context, snapshot) {
        final document = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              document?.documentNumber ?? 'Документ',
            ),
          ),
          floatingActionButton: document == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF / отправить'),
                ),
          body: document == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              document.documentType == 'writeoff_act'
                                  ? Icons.receipt_long_outlined
                                  : Icons.shopping_cart_outlined,
                            ),
                            title: Text(document.title),
                            subtitle: Text(
                              '№ ${document.documentNumber}\n'
                              '${document.organizationName}',
                            ),
                            isThreeLine: true,
                          ),
                          const Divider(),
                          ListTile(
                            dense: true,
                            title: const Text('Основание'),
                            subtitle: Text(
                              document.basis.isEmpty
                                  ? '—'
                                  : document.basis,
                            ),
                          ),
                          if (document.pdfPath.isNotEmpty)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.check_circle),
                              title: const Text('PDF сформирован'),
                              subtitle: Text(
                                File(document.pdfPath).path,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<List<InventoryDocumentItem>>(
                      future: _items,
                      builder: (context, itemsSnapshot) {
                        if (!itemsSnapshot.hasData) {
                          return const LinearProgressIndicator();
                        }

                        final items = itemsSnapshot.data!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Позиции',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge,
                            ),
                            const SizedBox(height: 8),
                            ...items.map(
                              (item) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: Card(
                                  child: ListTile(
                                    onTap: document.documentType ==
                                            'purchase_request'
                                        ? () => _editPurchaseItem(item)
                                        : null,
                                    title: Text(item.itemName),
                                    subtitle: Text(
                                      '${_fmt(item.quantity)} ${item.unit}'
                                      '${item.unitPrice <= 0 ? '' : ' • ${item.unitPrice.toStringAsFixed(2)} ₽/ед.'}'
                                      '${item.comment.isEmpty ? '' : '\n${item.comment}'}',
                                    ),
                                    trailing: item.amount <= 0
                                        ? null
                                        : Text(
                                            '${item.amount.toStringAsFixed(2)} ₽',
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (document.documentType ==
                        'purchase_request' &&
                        document.status != 'fulfilled') ...[
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _receivePurchase(document),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text(
                          'Оформить фактическое поступление',
                        ),
                      ),
                    ],
                    if (document.documentType ==
                        'purchase_request') ...[
                      const SizedBox(height: 8),
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text(
                            'Количество и цену можно уточнить',
                          ),
                          subtitle: Text(
                            'Нажмите на позицию до формирования PDF.',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Юридический статус: PDF является печатной '
                          'формой документа. Для первичного учетного '
                          'документа требуется подпись уполномоченных '
                          'лиц на бумаге либо допустимая электронная '
                          'подпись.',
                        ),
                      ),
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
        );
      },
    );
  }
}
