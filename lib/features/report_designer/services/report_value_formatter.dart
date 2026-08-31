import '../models/report_models.dart';

class ReportValueFormatter {
  ReportValueFormatter._();

  static String format(Object? value, ReportFieldType type) {
    if (value == null) return '';

    switch (type) {
      case ReportFieldType.currency:
        final number = _toDouble(value);
        return number == null ? value.toString() : 'Rs. ${_formatNumber(number, 2)}';
      case ReportFieldType.number:
        final number = _toDouble(value);
        if (number == null) return value.toString();
        final decimals = number == number.roundToDouble() ? 0 : 2;
        return _formatNumber(number, decimals);
      case ReportFieldType.percentage:
        final number = _toDouble(value);
        return number == null ? value.toString() : '${_formatNumber(number, 2)}%';
      case ReportFieldType.date:
      case ReportFieldType.text:
        return value.toString();
    }
  }

  static double? _toDouble(Object value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _formatNumber(double value, int decimals) {
    final parts = value.toStringAsFixed(decimals).split('.');
    final whole = parts.first;
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;
    final buffer = StringBuffer();

    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    final prefix = negative ? '-' : '';
    if (decimals == 0) return '$prefix$buffer';
    return '$prefix$buffer.${parts.length > 1 ? parts[1] : ''.padRight(decimals, '0')}';
  }
}
