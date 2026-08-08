import 'package:flutter_test/flutter_test.dart';
import 'package:ops_control/services/qr_parser.dart';

void main() {
  group('QrParser', () {
    test('parses OPS prefix', () {
      expect(
        QrParser().parseAddress('OPS|Энгельса 31'),
        'Энгельса 31',
      );
    });

    test('accepts plain address', () {
      expect(
        QrParser().parseAddress('  Мичурина 214  '),
        'Мичурина 214',
      );
    });
  });
}
