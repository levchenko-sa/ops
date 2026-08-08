import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/inventory_document.dart';
import '../models/inventory_document_item.dart';
import '../repositories/ops_repository.dart';

class InventoryDocumentPdfService {
  final _repo = OpsRepository();

  Future<pw.Font> _loadSystemFont({
    required bool bold,
  }) async {
    final candidates = bold
        ? const [
            '/system/fonts/Roboto-Bold.ttf',
            '/system/fonts/RobotoStatic-Bold.ttf',
            '/system/fonts/NotoSans-Bold.ttf',
          ]
        : const [
            '/system/fonts/Roboto-Regular.ttf',
            '/system/fonts/RobotoStatic-Regular.ttf',
            '/system/fonts/NotoSans-Regular.ttf',
          ];

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        final data = await file.readAsBytes();
        return pw.Font.ttf(
          ByteData.sublistView(Uint8List.fromList(data)),
        );
      }
    }

    throw StateError(
      'На устройстве не найден системный шрифт с поддержкой кириллицы',
    );
  }

  String _date(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;

    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }

  String _quantity(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  String _money(double value) => value.toStringAsFixed(2);

  Future<File> generate(int documentId) async {
    final document = await _repo.getInventoryDocument(documentId);
    if (document == null) {
      throw StateError('Документ не найден');
    }

    final items = await _repo.getInventoryDocumentItems(documentId);
    if (items.isEmpty) {
      throw StateError('В документе отсутствуют позиции');
    }

    final regular = await _loadSystemFont(bold: false);
    final bold = await _loadSystemFont(bold: true);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
      ),
    );

    if (document.documentType == 'writeoff_act') {
      pdf.addPage(
        _writeoffPage(
          document: document,
          items: items,
        ),
      );
    } else {
      pdf.addPage(
        _purchasePage(
          document: document,
          items: items,
        ),
      );
    }

    final bytes = await pdf.save();
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(docs.path, 'ops_documents'),
    );

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final safeNumber = document.documentNumber
        .replaceAll(RegExp(r'[^0-9A-Za-zА-Яа-я_-]'), '_');

    final prefix = document.documentType == 'writeoff_act'
        ? 'act_writeoff'
        : 'purchase_request';

    final file = File(
      p.join(dir.path, '${prefix}_$safeNumber.pdf'),
    );

    await file.writeAsBytes(bytes, flush: true);
    await _repo.updateInventoryDocumentPdfPath(
      documentId,
      file.path,
    );

    return file;
  }

  pw.MultiPage _writeoffPage({
    required InventoryDocument document,
    required List<InventoryDocumentItem> items,
  }) {
    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 34),
      header: (context) => _header(document),
      footer: (context) => _footer(context),
      build: (context) => [
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'АКТ СПИСАНИЯ МАТЕРИАЛЬНЫХ ЦЕННОСТЕЙ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            '№ ${document.documentNumber} от ${_date(document.documentDate)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        pw.SizedBox(height: 14),
        _legalSubject(document),
        pw.SizedBox(height: 8),
        _field('Содержание факта хозяйственной жизни',
            document.contentDescription),
        _field('Основание', document.basis),
        if (document.sourceRequestId != null)
          _field(
            'Связанная заявка OPS Control',
            '№ ${document.sourceRequestId}',
          ),
        pw.SizedBox(height: 12),
        _itemsTable(items),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Итого по учетной стоимости: ${_money(total)} руб.',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Материальные ценности фактически использованы при выполнении '
          'указанных работ и подлежат отражению в учете организации '
          'в соответствии с принятой учетной политикой.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 18),
        _signatureBlock(
          'Ответственный за совершение операции',
          document.responsiblePosition,
          document.responsibleName,
        ),
        pw.SizedBox(height: 14),
        _signatureBlock(
          'Ответственный за оформление документа',
          document.creatorPosition,
          document.creatorName,
        ),
        if (document.accountantName.trim().isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _signatureBlock(
            'Бухгалтерский учет',
            document.accountantPosition,
            document.accountantName,
          ),
        ],
        pw.SizedBox(height: 14),
        _signatureBlock(
          'УТВЕРЖДАЮ',
          document.approverPosition,
          document.approverName,
        ),
        pw.SizedBox(height: 16),
        _approvalFormNote(document),
        pw.SizedBox(height: 8),
        _signatureWarning(),
      ],
    );
  }

  pw.MultiPage _purchasePage({
    required InventoryDocument document,
    required List<InventoryDocumentItem> items,
  }) {
    final total = items.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 34),
      header: (context) => _header(document),
      footer: (context) => _footer(context),
      build: (context) => [
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'ЗАЯВКА НА ЗАКУПКУ МАТЕРИАЛЬНЫХ ЦЕННОСТЕЙ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            '№ ${document.documentNumber} от ${_date(document.documentDate)}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        pw.SizedBox(height: 14),
        _legalSubject(document),
        pw.SizedBox(height: 8),
        _field('Цель закупки', document.contentDescription),
        _field('Основание потребности', document.basis),
        pw.SizedBox(height: 12),
        _itemsTable(items),
        pw.SizedBox(height: 8),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Ориентировочная сумма: ${_money(total)} руб.',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        if (document.procurementRegime == '44fz')
          _procurementWarning(
            'Организация отметила режим 44-ФЗ. Эта заявка является '
            'внутренним документом потребности и не заменяет планирование, '
            'обоснование, извещение, контракт и иные документы закупки, '
            'требуемые законодательством о контрактной системе.',
          ),
        if (document.procurementRegime == '223fz')
          _procurementWarning(
            'Организация отметила режим 223-ФЗ. Эта заявка является '
            'внутренним документом потребности и не заменяет процедуры '
            'и документы, предусмотренные положением о закупке заказчика.',
          ),
        pw.SizedBox(height: 14),
        _signatureBlock(
          'Инициатор закупки',
          document.creatorPosition,
          document.creatorName,
        ),
        pw.SizedBox(height: 14),
        _signatureBlock(
          'СОГЛАСОВАНО / УТВЕРЖДАЮ',
          document.approverPosition,
          document.approverName,
        ),
        pw.SizedBox(height: 16),
        _approvalFormNote(document),
        pw.SizedBox(height: 8),
        _signatureWarning(),
      ],
    );
  }

  pw.Widget _header(InventoryDocument document) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          document.organizationName.isEmpty
              ? 'Организация не указана'
              : document.organizationName,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
        ),
        if (document.organizationInn.isNotEmpty ||
            document.organizationKpp.isNotEmpty)
          pw.Text(
            'ИНН ${document.organizationInn}'
            '${document.organizationKpp.isEmpty ? '' : ' / КПП ${document.organizationKpp}'}',
            style: const pw.TextStyle(fontSize: 8.5),
          ),
        pw.Divider(thickness: 0.5),
      ],
    );
  }

  pw.Widget _legalSubject(InventoryDocument document) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey500,
          width: 0.6,
        ),
      ),
      child: pw.Text(
        'Экономический субъект: ${document.organizationName}'
        '${document.organizationInn.isEmpty ? '' : ', ИНН ${document.organizationInn}'}'
        '${document.organizationKpp.isEmpty ? '' : ', КПП ${document.organizationKpp}'}.',
        style: const pw.TextStyle(fontSize: 9),
      ),
    );
  }

  pw.Widget _field(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.RichText(
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 9),
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.TextSpan(
              text: value.trim().isEmpty ? '-' : value.trim(),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _itemsTable(List<InventoryDocumentItem> items) {
    final rows = <List<String>>[];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      rows.add([
        '${i + 1}',
        item.itemName,
        item.unit,
        _quantity(item.quantity),
        item.unitPrice <= 0 ? '-' : _money(item.unitPrice),
        item.amount <= 0 ? '-' : _money(item.amount),
        item.comment,
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: const [
        '№',
        'Наименование',
        'Ед.',
        'Кол-во',
        'Цена, руб.',
        'Сумма, руб.',
        'Примечание',
      ],
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 7.5,
      ),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.grey300,
      ),
      border: pw.TableBorder.all(
        color: PdfColors.grey500,
        width: 0.5,
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(22),
        1: const pw.FlexColumnWidth(2.8),
        2: const pw.FixedColumnWidth(35),
        3: const pw.FixedColumnWidth(42),
        4: const pw.FixedColumnWidth(58),
        5: const pw.FixedColumnWidth(62),
        6: const pw.FlexColumnWidth(1.8),
      },
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _signatureBlock(
    String label,
    String position,
    String name,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 3,
              child: pw.Text(
                position.trim().isEmpty ? 'Должность' : position,
                style: const pw.TextStyle(fontSize: 8.5),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                children: [
                  pw.Container(
                    height: 14,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(width: 0.6),
                      ),
                    ),
                  ),
                  pw.Text(
                    'подпись',
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              flex: 3,
              child: pw.Column(
                children: [
                  pw.Container(
                    height: 14,
                    alignment: pw.Alignment.bottomCenter,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(width: 0.6),
                      ),
                    ),
                    child: pw.Text(
                      name,
                      style: const pw.TextStyle(fontSize: 8.5),
                    ),
                  ),
                  pw.Text(
                    'Ф.И.О.',
                    style: const pw.TextStyle(fontSize: 6.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _approvalFormNote(
    InventoryDocument document,
  ) {
    final hasOrder =
        document.formsApprovalOrderNo.trim().isNotEmpty &&
        document.formsApprovalOrderDate.trim().isNotEmpty;

    return pw.Text(
      hasOrder
          ? 'Форма документа утверждена руководителем организации: '
              'приказ № ${document.formsApprovalOrderNo} '
              'от ${document.formsApprovalOrderDate}.'
          : 'ВНИМАНИЕ: в настройках не указан приказ руководителя, '
              'которым утверждена применяемая форма документа.',
      style: pw.TextStyle(
        fontSize: 7.5,
        color: hasOrder ? PdfColors.grey700 : PdfColors.red800,
      ),
    );
  }

  pw.Widget _signatureWarning() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(
          color: PdfColors.grey400,
          width: 0.5,
        ),
      ),
      child: pw.Text(
        'Печатная форма сформирована OPS Control. До подписания '
        'уполномоченными лицами на бумаге либо допустимой электронной '
        'подписью документ рассматривается как подготовленная форма.',
        style: const pw.TextStyle(fontSize: 7.3),
      ),
    );
  }

  pw.Widget _procurementWarning(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(
          color: PdfColors.amber700,
          width: 0.6,
        ),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Страница ${context.pageNumber} из ${context.pagesCount}',
        style: const pw.TextStyle(
          fontSize: 7,
          color: PdfColors.grey600,
        ),
      ),
    );
  }

  Future<void> share(int documentId) async {
    final file = await generate(documentId);

    await SharePlus.instance.share(
      ShareParams(
        text: 'Документ OPS Control',
        files: [XFile(file.path)],
      ),
    );
  }
}
