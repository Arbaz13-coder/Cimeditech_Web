import '../../../core/models/api_response.dart';

class DashboardSnapshot {
  DashboardSnapshot(this.data) {
    if (data['schema_version'] != 1 ||
        data['o_id'] is! num ||
        [
          'activity',
          'outstanding',
          'inventory',
          'cash',
        ].any((k) => data[k] is! Map)) {
      throw const ApiException(
        'Incomplete dashboard response. Please update the API and retry.',
      );
    }
    final numericPaths = [
      for (final period in ['current', 'previous'])
        for (final metric in [
          'sales',
          'purchases',
          'receipts',
          'payments',
          'voucher_count',
        ])
          'activity.$period.$metric',
      'outstanding.receivables',
      'outstanding.payables',
      'inventory.value',
      'cash.cash',
      'cash.bank',
    ];
    final arrayPaths = [
      'activity.trend',
      'activity.top_items',
      'activity.recent',
      'outstanding.ageing',
      'outstanding.top_customers',
      'inventory.movement',
    ];
    if (numericPaths.any((p) => value(p) is! num) ||
        arrayPaths.any((p) => value(p) is! List) ||
        value('cash.available') is! bool) {
      throw const ApiException(
        'Incomplete dashboard totals. Please update the API and retry.',
      );
    }
  }
  final Map<String, dynamic> data;
  int get companyId => number('o_id').toInt();
  Object? value(String path) {
    Object? v = data;
    for (final k in path.split('.')) {
      v = v is Map ? v[k] : null;
    }
    return v;
  }

  double number(String p) => dashboardNumber(value(p));
  String text(String p) => value(p)?.toString() ?? '';
  bool flag(String p) => value(p) == true;
  List<Map<String, dynamic>> rows(String p) => dashboardRows(value(p));
  double? change(String metric) {
    final p = number('activity.previous.$metric');
    return p == 0
        ? null
        : (number('activity.current.$metric') - p) / p.abs() * 100;
  }
}

double dashboardNumber(Object? v) {
  final n = v is num ? v.toDouble() : double.tryParse('$v');
  return n != null && n.isFinite ? n : 0;
}

List<Map<String, dynamic>> dashboardRows(Object? v) => v is List
    ? v
          .whereType<Map>()
          .map((r) => r.map((k, v) => MapEntry(k.toString(), v)))
          .toList()
    : [];
String dashboardMoney(double amount) {
  final n = amount.abs();
  final s = n >= 10000000
      ? '${(n / 10000000).toStringAsFixed(2)} Cr'
      : n >= 100000
      ? '${(n / 100000).toStringAsFixed(2)} L'
      : n >= 1000
      ? '${(n / 1000).toStringAsFixed(2)} K'
      : n.toStringAsFixed(2);
  return '${amount < 0 ? '−' : ''}₹$s';
}

String dashboardDate(Object? v) {
  final d = DateTime.tryParse('$v');
  return d == null
      ? 'Not available'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String dashboardIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
({DateTime from, DateTime to}) dashboardPeriod(String period, DateTime now) {
  final t = DateTime.utc(now.year, now.month, now.day);
  return switch (period) {
    'This Month' => (from: DateTime.utc(t.year, t.month), to: t),
    'Last Month' => (
      from: DateTime.utc(t.year, t.month - 1),
      to: DateTime.utc(t.year, t.month, 0),
    ),
    'Last 90 Days' => (from: t.subtract(const Duration(days: 89)), to: t),
    _ => (from: DateTime.utc(t.month < 4 ? t.year - 1 : t.year, 4), to: t),
  };
}
