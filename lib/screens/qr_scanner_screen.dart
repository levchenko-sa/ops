import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../repositories/ops_repository.dart';
import '../services/qr_parser.dart';
import 'object_detail_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController();
  final _repo = OpsRepository();
  final _parser = QrParser();

  bool _busy = false;
  String? _message;

  Future<void> _handle(BarcodeCapture capture) async {
    if (_busy) return;

    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        raw = value;
        break;
      }
    }

    if (raw == null) return;

    setState(() => _busy = true);
    await _controller.stop();

    final address = _parser.parseAddress(raw);
    final object = await _repo.findObjectByAddress(address);

    if (!mounted) return;

    if (object == null) {
      setState(() {
        _message = 'Объект не найден: $address';
        _busy = false;
      });
      await _controller.start();
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ObjectDetailScreen(object: object),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR объекта')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handle,
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(width: 3, color: Colors.white),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _message ??
                        'Наведите камеру на QR. Формат: OPS|Энгельса 31',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
