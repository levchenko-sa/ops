import 'package:flutter_test/flutter_test.dart';
import 'package:ops_control/services/report_parser.dart';

void main() {
  group('ReportParser', () {
    test('parses morning report categories and priorities', () {
      const raw = '''
нет контрольного события:
1. Белинского 167

не ставится на охрану:
Куйбышева 76

сработки:
1. Энгельса 31
''';

      final result = ReportParser().parse(raw);

      expect(result, hasLength(3));
      expect(result[0].address, 'Белинского 167');
      expect(result[0].type, 'Нет контрольного события');
      expect(result[0].priority, 1);
      expect(result[1].type, 'Не ставится на охрану');
      expect(result[1].priority, 2);
      expect(result[2].type, 'Сработка');
      expect(result[2].priority, 3);
    });

    test('supports short alias Нет КС', () {
      const raw = '''
Нет КС:
Мичурина 214
''';

      final result = ReportParser().parse(raw);
      expect(result.single.type, 'Нет контрольного события');
      expect(result.single.address, 'Мичурина 214');
    });
  });
}
