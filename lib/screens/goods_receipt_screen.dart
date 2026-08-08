import 'package:flutter/material.dart';

import '../models/inventory_document.dart';
import '../models/material_item.dart';
import '../repositories/ops_repository.dart';
import 'goods_receipt_detail_screen.dart';

class GoodsReceiptScreen extends StatefulWidget {
  final InventoryDocument? initialPurchaseDocument;

  const GoodsReceiptScreen({
    super.key,
    this.initialPurchaseDocument,
  });

  @override
  State<GoodsReceiptScreen> createState() =>
      _GoodsReceiptScreenState();
}

class _ReceiptLine {
  final MaterialItem material;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController comment;

  _ReceiptLine({
    required this.material,
    required double quantityValue,
    required double unitPriceValue,
    String commentValue = '',
  })  : quantity = TextEditingController(
          text: quantityValue == quantityValue.roundToDouble()
              ? quantityValue.toStringAsFixed(0)
              : quantityValue.toStringAsFixed(2),
        ),
        unitPrice = TextEditingController(
          text: unitPriceValue <= 0
              ? ''
              : unitPriceValue.toStringAsFixed(2),
        ),
        comment = TextEditingController(text: commentValue);

  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
    comment.dispose();
  }
}

class _GoodsReceiptScreenState extends State<GoodsReceiptScreen> {
  final _repo = OpsRepository();

  final _supplier = TextEditingController();
  final _supplierInn = TextEditingController();
  final _supplierDocNo = TextEditingController();
  final _supplierDocDate = TextEditingController();
  final _notes = TextEditingController();

  String _supplierDocType = 'УПД';
  InventoryDocument? _purchase;
  List<InventoryDocument> _openPurchases = const [];
  final List<_ReceiptLine> _lines = [];

  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _purchase = widget.initialPurchaseDocument;
    _load();
  }

  @override
  void dispose() {
    _supplier.dispose();
    _supplierInn.dispose();
    _supplierDocNo.dispose();
    _supplierDocDate.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    _openPurchases = await _repo.getOpenPurchaseRequests();

    if (_purchase != null) {
      await _fillFromPurchase(_purchase!);
    }

    if (mounted) setState(() => _loading = false);
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _fillFromPurchase(
    InventoryDocument purchase,
  ) async {
    final remaining =
        await _repo.getPurchaseRequestRemainingItems(purchase.id!);
    final materials = await _repo.getMaterials();
    final byId = <int, MaterialItem>{
      for (final item in materials)
        if (item.id != null) item.id!: item,
    };

    for (final line in _lines) {
      line.dispose();
    }
    _lines.clear();

    for (final row in remaining) {
      final materialId = (row['material_id'] as num?)?.toInt();
      if (materialId == null) continue;

      final requested =
          (row['requested_quantity'] as num).toDouble();
      final received =
          (row['received_quantity'] as num).toDouble();
      final rest = requested - received;

      if (rest <= 0) continue;

      final material = byId[materialId];
      if (material == null) continue;

      _lines.add(
        _ReceiptLine(
          material: material,
          quantityValue: rest,
          unitPriceValue:
              (row['planned_unit_price'] as num?)?.toDouble() ??
                  material.accountingPrice,
          commentValue:
              'По заявке ${purchase.documentNumber}',
        ),
      );
    }
  }

  Future<void> _selectPurchase(
    InventoryDocument? purchase,
  ) async {
    setState(() {
      _purchase = purchase;
      _loading = true;
    });

    if (purchase != null) {
      await _fillFromPurchase(purchase);
    } else {
      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addMaterial() async {
    final materials = await _repo.getMaterials();
    if (!mounted) return;

    final existingIds =
        _lines.map((e) => e.material.id).whereType<int>().toSet();
    final available = materials
        .where((item) => !existingIds.contains(item.id))
        .toList();

    final selected = await showModalBottomSheet<MaterialItem>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Добавить материал',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...available.map(
              (item) => ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(item.name),
                subtitle: Text(
                  'Склад: ${_fmt(item.quantity)} ${item.unit}',
                ),
                onTap: () => Navigator.pop(context, item),
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _lines.add(
        _ReceiptLine(
          material: selected,
          quantityValue: 1,
          unitPriceValue: selected.accountingPrice,
        ),
      );
    });
  }

  void _removeLine(_ReceiptLine line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  Future<void> _post() async {
    if (_supplier.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите поставщика')),
      );
      return;
    }

    if (_supplierDocNo.text.trim().isEmpty ||
        _supplierDocDate.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Укажите номер и дату документа поставщика',
          ),
        ),
      );
      return;
    }

    final items = <Map<String, Object?>>[];

    for (final line in _lines) {
      final quantity = double.tryParse(
        line.quantity.text.replaceAll(',', '.').trim(),
      );
      final price = double.tryParse(
            line.unitPrice.text.replaceAll(',', '.').trim(),
          ) ??
          0;

      if (quantity == null || quantity <= 0 || price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Проверьте количество и цену: ${line.material.name}',
            ),
          ),
        );
        return;
      }

      items.add({
        'material_id': line.material.id,
        'item_name': line.material.name,
        'unit': line.material.unit,
        'quantity': quantity,
        'unit_price': price,
        'comment': line.comment.text.trim(),
      });
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одну позицию')),
      );
      return;
    }

    setState(() => _posting = true);

    try {
      final id = await _repo.postGoodsReceipt(
        purchaseDocumentId: _purchase?.id,
        supplierName: _supplier.text,
        supplierInn: _supplierInn.text,
        supplierDocumentType: _supplierDocType,
        supplierDocumentNumber: _supplierDocNo.text,
        supplierDocumentDate: _supplierDocDate.text,
        notes: _notes.text,
        items: items,
      );

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GoodsReceiptDetailScreen(
            receiptId: id,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поступление материалов')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: _purchase?.id,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Заявка на закупку',
                    prefixIcon: Icon(Icons.shopping_cart_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Без внутренней заявки'),
                    ),
                    ..._openPurchases.map(
                      (doc) => DropdownMenuItem<int?>(
                        value: doc.id,
                        child: Text(
                          '${doc.documentNumber} • ${doc.status}',
                        ),
                      ),
                    ),
                  ],
                  onChanged: (id) {
                    InventoryDocument? selected;
                    if (id != null) {
                      for (final doc in _openPurchases) {
                        if (doc.id == id) {
                          selected = doc;
                          break;
                        }
                      }
                    }
                    _selectPurchase(selected);
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Документ поставщика',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _supplier,
                  decoration: const InputDecoration(
                    labelText: 'Поставщик *',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _supplierInn,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ИНН поставщика',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _supplierDocType,
                  decoration: const InputDecoration(
                    labelText: 'Вид документа',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'УПД',
                      child: Text('УПД'),
                    ),
                    DropdownMenuItem(
                      value: 'Товарная накладная',
                      child: Text('Товарная накладная'),
                    ),
                    DropdownMenuItem(
                      value: 'Акт',
                      child: Text('Акт'),
                    ),
                    DropdownMenuItem(
                      value: 'Иное',
                      child: Text('Иное'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _supplierDocType = value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _supplierDocNo,
                        decoration: const InputDecoration(
                          labelText: 'Номер *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _supplierDocDate,
                        decoration: const InputDecoration(
                          labelText: 'Дата *',
                          hintText: '08.08.2026',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Фактически принято',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: _addMaterial,
                      icon: const Icon(Icons.add),
                      tooltip: 'Добавить позицию',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_lines.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.inventory_2_outlined),
                      title: Text('Позиции не добавлены'),
                    ),
                  )
                else
                  ..._lines.map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      line.material.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _removeLine(line),
                                    icon: const Icon(Icons.close),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: line.quantity,
                                      keyboardType:
                                          const TextInputType
                                              .numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: InputDecoration(
                                        labelText:
                                            'Количество, ${line.material.unit}',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: line.unitPrice,
                                      keyboardType:
                                          const TextInputType
                                              .numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Цена, ₽/ед.',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: line.comment,
                                decoration: const InputDecoration(
                                  labelText: 'Примечание',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Примечание к поступлению',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'OPS Control фиксирует складское поступление '
                      'на основании документа поставщика. Запись '
                      'поступления не заменяет УПД, накладную или другой '
                      'первичный документ поставщика.',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _posting ? null : _post,
                  icon: const Icon(Icons.inventory),
                  label: const Text(
                    'Провести поступление на склад',
                  ),
                ),
                if (_posting) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
    );
  }
}
