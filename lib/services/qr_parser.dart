class QrParser {
  String parseAddress(String raw) {
    final value = raw.trim();
    if (value.toUpperCase().startsWith('OPS|')) {
      return value.substring(4).trim();
    }
    return value;
  }
}
