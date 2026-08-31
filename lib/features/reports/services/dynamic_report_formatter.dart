import 'dart:convert';

import '../models/report_models.dart';

class DynamicReportFormatter {
  DynamicReportFormatter._();

  static const _months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  static String format(Object? value, ReportColumn column) {
    if (value == null) return '';

    if (column.dataType == 'BOOLEAN') {
      if (value is bool) return value ? 'Yes' : 'No';
      final normalized = value.toString().toLowerCase();
      if (normalized == 'true' || normalized == '1') return 'Yes';
      if (normalized == 'false' || normalized == '0') return 'No';
    }

    if (column.dataType == 'DATE' || column.format == 'DATE') {
      return _formatDate(value, includeTime: false);
    }

    if (column.dataType == 'DATETIME' || column.format == 'DATETIME') {
      return _formatDate(value, includeTime: true);
    }

    if (column.dataType == 'JSON' || value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }

    final number = value is num ? value : num.tryParse(value.toString());
    if (number != null && _isNumeric(column)) {
      final decimals = _decimalPlaces(column, number);
      final formatted = _formatNumber(number.toDouble(), decimals);
      if (column.format.contains('PERCENT')) return '$formatted%';
      if (column.format.contains('CURRENCY')) return '₹ $formatted';
      return formatted;
    }

    return value.toString();
  }

  static String toCsv(
    List<Map<String, dynamic>> rows,
    List<ReportColumn> columns,
  ) {
    final exportColumns = columns
        .where((item) => item.isActive && item.isVisible && item.isExportable)
        .toList(growable: false);
    final lines = <String>[
      exportColumns.map((item) => _csvCell(item.displayName)).join(','),
    ];

    for (final row in rows) {
      lines.add(
        exportColumns
            .map((column) => _csvCell(
                  _spreadsheetSafe(
                    format(row[column.name], column),
                    numeric: _isNumeric(column),
                  ),
                ))
            .join(','),
      );
    }
    return lines.join('\r\n');
  }

  static bool _isNumeric(ReportColumn column) {
    return column.dataType == 'INTEGER' ||
        column.dataType == 'LONG' ||
        column.dataType == 'DECIMAL' ||
        column.dataType == 'ID';
  }

  static int _decimalPlaces(ReportColumn column, num value) {
    final match = RegExp(r'_(\d+)$').firstMatch(column.format);
    if (match != null) {
      final parsed = int.tryParse(match.group(1) ?? '');
      if (parsed != null) return parsed.clamp(0, 6).toInt();
    }
    if (column.dataType == 'INTEGER' ||
        column.dataType == 'LONG' ||
        column.dataType == 'ID') {
      return 0;
    }
    return value == value.roundToDouble() ? 0 : 2;
  }

  static String _formatDate(Object value, {required bool includeTime}) {
    final text = value.toString().trim();
    final date = DateTime.tryParse(text);
    if (date == null) return text;

    final local = date.isUtc ? date.toLocal() : date;
    final dateText = '${local.day.toString().padLeft(2, '0')}-'
        '${_months[local.month - 1]}-${local.year}';
    if (!includeTime) return dateText;

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$dateText $hour:$minute';
  }

  static String _formatNumber(double value, int decimals) {
    final parts = value.toStringAsFixed(decimals).split('.');
    final whole = parts.first;
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;
    final buffer = StringBuffer();

    for (var index = 0; index < digits.length; index++) {
      final remaining = digits.length - index;
      buffer.write(digits[index]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
    }

    final prefix = negative ? '-' : '';
    if (decimals == 0) return '$prefix$buffer';
    return '$prefix$buffer.${parts.length > 1 ? parts[1] : ''.padRight(decimals, '0')}';
  }

  static String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static String _spreadsheetSafe(String value, {required bool numeric}) {
    if (numeric || value.isEmpty) return value;
    final first = value[0];
    return first == '=' || first == '+' || first == '-' || first == '@'
        ? "'$value"
        : value;
  }
}
