class ParsedReportItem {
  final String address;
  final String type;
  final int priority;

  const ParsedReportItem({
    required this.address,
    required this.type,
    required this.priority,
  });
}

class ReportParser {
  static const _categoryAliases = <String, String>{
    'нет контрольного события': 'Нет контрольного события',
    'нет кс': 'Нет контрольного события',
    'не ставится на охрану': 'Не ставится на охрану',
    'сработки': 'Сработка',
    'сработка': 'Сработка',
    'связь потеряна': 'Потеря связи',
    'потеря связи': 'Потеря связи',
    'акб разряжена': 'АКБ разряжена',
    'акб отключена': 'АКБ отключена',
  };

  static int _priorityFor(String type) {
    switch (type) {
      case 'Сработка':
        return 3;
      case 'Не ставится на охрану':
      case 'Потеря связи':
        return 2;
      default:
        return 1;
    }
  }

  List<ParsedReportItem> parse(String raw) {
    final result = <ParsedReportItem>[];
    String? currentType;

    for (final sourceLine in raw.split('\n')) {
      var line = sourceLine.trim();
      if (line.isEmpty) continue;

      line = line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
      final normalized = line
          .toLowerCase()
          .replaceAll(':', '')
          .trim();

      if (_categoryAliases.containsKey(normalized)) {
        currentType = _categoryAliases[normalized];
        continue;
      }

      if (currentType == null) continue;

      final address = line
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceFirst(RegExp(r'^[\-\–\—]\s*'), '')
          .trim();

      if (address.length < 4) continue;

      result.add(
        ParsedReportItem(
          address: address,
          type: currentType,
          priority: _priorityFor(currentType),
        ),
      );
    }

    return result;
  }
}
