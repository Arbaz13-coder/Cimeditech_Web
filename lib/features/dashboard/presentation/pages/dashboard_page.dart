import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/models/api_response.dart';
import '../../../reports/models/report_models.dart';
import '../../../reports/services/report_file_downloader.dart';
import '../../data/dashboard_repository.dart';
import '../../models/dashboard_snapshot.dart';

const _blue = Color(0xFF2563EB),
    _ink = Color(0xFF182230),
    _muted = Color(0xFF667085),
    _green = Color(0xFF079455),
    _red = Color(0xFFD92D20);

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.repository,
    this.onSessionExpired,
    this.onOpenReports,
    this.onOpenUserMapping,
  });
  final DashboardSource repository;
  final VoidCallback? onSessionExpired, onOpenReports, onOpenUserMapping;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<ReportCompany> _companies = [];
  int? _companyId;
  String _period = 'Current FY';
  late DateTime _appliedFrom, _appliedTo;
  final _fromDate = TextEditingController();
  final _toDate = TextEditingController();
  String? _dateError;
  DashboardSnapshot? _snapshot;
  String? _error;
  bool _companiesLoading = true, _loading = false, _exporting = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _setPeriodDates(_period);
    _loadCompanies();
  }

  @override
  void dispose() {
    _generation++;
    _fromDate.dispose();
    _toDate.dispose();
    super.dispose();
  }

  String _dateInput(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';

  DateTime? _parseDate(String text) {
    final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text.trim());
    if (match == null) return null;
    final day = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final year = int.parse(match[3]!);
    if (year < 1) return null;
    final date = DateTime.utc(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  bool get _datesPending =>
      _fromDate.text.trim() != _dateInput(_appliedFrom) ||
      _toDate.text.trim() != _dateInput(_appliedTo);

  void _setPeriodDates(String period) {
    final range = dashboardPeriod(period, DateTime.now().toUtc());
    _appliedFrom = range.from;
    _appliedTo = range.to;
    _fromDate.text = _dateInput(range.from);
    _toDate.text = _dateInput(range.to);
    _dateError = null;
  }

  void _dateEdited() => setState(() {
    _period = 'Custom';
    _dateError = null;
  });

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now().toUtc();
    final today = DateTime(now.year, now.month, now.day);
    final controller = from ? _fromDate : _toDate;
    final date =
        _parseDate(controller.text) ?? (from ? _appliedFrom : _appliedTo);
    final localDate = DateTime(date.year, date.month, date.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: localDate.isAfter(today) ? today : localDate,
      firstDate: DateTime(1),
      lastDate: today,
      helpText: from ? 'Select From Date' : 'Select To Date',
    );
    if (!mounted || selected == null) return;
    controller.text = _dateInput(selected);
    _dateEdited();
  }

  Future<void> _applyDates() async {
    final from = _parseDate(_fromDate.text);
    final to = _parseDate(_toDate.text);
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final error = from == null || to == null
        ? 'Enter valid From Date and To Date in DD/MM/YYYY format.'
        : from.isAfter(to)
        ? 'From Date must be on or before To Date.'
        : to.isAfter(today)
        ? 'To Date cannot be later than today (UTC).'
        : to.difference(from).inDays > 365
        ? 'Select a date range of at most 366 days.'
        : null;
    setState(() => _dateError = error);
    if (error != null || from == null || to == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _appliedFrom = from;
      _appliedTo = to;
      _fromDate.text = _dateInput(from);
      _toDate.text = _dateInput(to);
    });
    await _loadOverview();
  }

  Future<void> _loadCompanies() async {
    final ticket = ++_generation;
    setState(() {
      _companiesLoading = true;
      _loading = false;
      _error = null;
      _snapshot = null;
    });
    try {
      final companies = await widget.repository.companies();
      if (!mounted || ticket != _generation) return;
      setState(() {
        _companies = companies;
        if (!companies.any((c) => c.id == _companyId)) {
          _companyId = companies.firstOrNull?.id;
        }
        _companiesLoading = false;
      });
      if (_companyId != null) await _loadOverview();
    } catch (e) {
      _failed(e, ticket);
    }
  }

  Future<void> _loadOverview() async {
    final id = _companyId;
    if (id == null) return;
    final ticket = ++_generation;
    final from = _appliedFrom;
    final to = _appliedTo;
    setState(() {
      _loading = true;
      _error = null;
      _snapshot = null;
    });
    try {
      final result = await widget.repository.overview(
        companyId: id,
        from: from,
        to: to,
      );
      if (!mounted || ticket != _generation) return;
      setState(() {
        _snapshot = result;
        _loading = false;
      });
    } catch (e) {
      _failed(e, ticket);
    }
  }

  void _failed(Object e, int ticket) {
    if (!mounted || ticket != _generation) return;
    setState(() {
      _loading = false;
      _companiesLoading = false;
      _snapshot = null;
      _error = e is ApiException
          ? e.message
          : 'Unable to load the dashboard. Please retry.';
    });
    if (e is ApiException && e.isUnauthorized) widget.onSessionExpired?.call();
  }

  Future<void> _export() async {
    final d = _snapshot;
    if (d == null || _exporting || _datesPending) return;
    setState(() => _exporting = true);
    String cell(Object? v) {
      var s = '$v';
      if (RegExp(r'^\s*[=+\-@\t\r]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    final rows = <List<Object?>>[
      ['Company', d.text('company_name')],
      ['From', d.text('from_date')],
      ['To', d.text('to_date')],
      ['Snapshot date', d.text('as_of_date')],
      ['Metric', 'Amount (INR)', 'Basis'],
      for (final k in ['sales', 'purchases', 'receipts', 'payments'])
        [
          k,
          d.number('activity.current.$k'),
          'Selected period; permitted party and voucher types',
        ],
      for (final k in [
        'receivables',
        'payables',
        'customer_credits',
        'supplier_advances',
      ])
        [k, d.number('outstanding.$k'), 'Latest pending bills'],
      ['Inventory', d.number('inventory.value'), 'Latest permitted stock'],
      [
        'Cash',
        d.flag('cash.available') ? d.number('cash.cash') : 'Unavailable',
        'Latest current FY balance',
      ],
      [
        'Bank',
        d.flag('cash.available') ? d.number('cash.bank') : 'Unavailable',
        'Latest current FY balance',
      ],
    ];
    try {
      await downloadReportFile(
        fileName: 'dashboard_${d.companyId}_${d.text('to_date')}.csv',
        mimeType: 'text/csv;charset=utf-8',
        bytes: Uint8List.fromList(
          utf8.encode(
            '\uFEFF${rows.map((r) => r.map(cell).join(',')).join('\r\n')}',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download could not start. Retry in your browser.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF5F7FA),
    child: LayoutBuilder(
      builder: (context, c) => RefreshIndicator(
        onRefresh: _loadCompanies,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(c.maxWidth < 640 ? 14 : 22),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(
                    math.min(1580, c.maxWidth - (c.maxWidth < 640 ? 28 : 44)),
                  ),
                  const SizedBox(height: 18),
                  if (_loading || _companiesLoading)
                    const _Panel(
                      title: 'Loading your dashboard',
                      subtitle:
                          'Fetching the data you have permission to view.',
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  if (_error != null)
                    _Panel(
                      title: 'Dashboard unavailable',
                      subtitle: _error!,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _loadCompanies,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ),
                    ),
                  if (!_loading &&
                      !_companiesLoading &&
                      _error == null &&
                      _companies.isEmpty)
                    const _Panel(
                      title: 'No companies assigned',
                      subtitle:
                          'Ask your administrator to map your account to a company.',
                      child: _Empty(
                        'Your accessible companies will appear here.',
                      ),
                    ),
                  if (_snapshot case final d?) ..._content(d),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _header(double width) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Business Snapshot',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: _ink,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Your company performance, from synced Tally data.',
        style: TextStyle(color: _muted),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: math.min(320, width),
            child: DropdownButtonFormField<int>(
              key: ValueKey('company-$_companyId-${_companies.length}'),
              initialValue: _companyId,
              isExpanded: true,
              decoration: _input('Company', Icons.business_outlined),
              hint: const Text('Select a company'),
              items: _companies
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        c.effectiveName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _companiesLoading
                  ? null
                  : (id) {
                      if (id == null || id == _companyId) return;
                      setState(() => _companyId = id);
                      _loadOverview();
                    },
            ),
          ),
          SizedBox(
            width: math.min(180, width),
            child: DropdownButtonFormField<String>(
              key: ValueKey('period-$_period'),
              initialValue: _period,
              isExpanded: true,
              decoration: _input('Period', Icons.calendar_month_outlined),
              items: [
                'Current FY',
                'This Month',
                'Last Month',
                'Last 90 Days',
                'Custom',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: _companiesLoading
                  ? null
                  : (s) {
                      if (s == null || s == _period) return;
                      setState(() {
                        _period = s;
                        if (s != 'Custom') _setPeriodDates(s);
                      });
                      if (s != 'Custom') _loadOverview();
                    },
            ),
          ),
          _dateField(from: true, width: width),
          _dateField(from: false, width: width),
          FilledButton.icon(
            key: const ValueKey('apply-dashboard-dates'),
            onPressed: _companiesLoading || _companyId == null
                ? null
                : _applyDates,
            icon: const Icon(Icons.filter_alt_outlined, size: 18),
            label: const Text('Apply'),
          ),
          OutlinedButton.icon(
            onPressed: _loading || _companiesLoading ? null : _loadCompanies,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
          ),
          OutlinedButton.icon(
            onPressed: _snapshot == null || _exporting || _datesPending
                ? null
                : _export,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: Text(_exporting ? 'Preparing…' : 'Download summary'),
          ),
        ],
      ),
      if (_dateError != null || _datesPending) ...[
        const SizedBox(height: 10),
        Semantics(
          liveRegion: true,
          child: Text(
            _dateError ?? 'Dates changed. Click Apply to update the dashboard.',
            style: TextStyle(color: _dateError == null ? _muted : _red),
          ),
        ),
      ],
    ],
  );
  Widget _dateField({required bool from, required double width}) => SizedBox(
    width: math.min(205, width),
    child: TextField(
      key: ValueKey(from ? 'dashboard-from-date' : 'dashboard-to-date'),
      controller: from ? _fromDate : _toDate,
      enabled: !_companiesLoading,
      keyboardType: TextInputType.datetime,
      decoration:
          _input(
            from ? 'From Date' : 'To Date',
            Icons.date_range_outlined,
          ).copyWith(
            hintText: 'DD/MM/YYYY',
            suffixIcon: IconButton(
              tooltip: from ? 'Choose From Date' : 'Choose To Date',
              onPressed: _companiesLoading ? null : () => _pickDate(from: from),
              icon: const Icon(Icons.calendar_month_outlined, size: 19),
            ),
          ),
      onChanged: (_) => _dateEdited(),
      onSubmitted: (_) => _applyDates(),
    ),
  );
  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 19),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
    ),
  );
  List<Widget> _content(DashboardSnapshot d) {
    String money(String p) => dashboardMoney(d.number(p));
    String count(String p) => d.number(p).toInt().toString();
    final inventory =
        d.flag('inventory.has_item_access') &&
        d.flag('inventory.has_warehouse_access');
    final cash = d.flag('cash.available');
    return [
      _Notice(
        'Period: ${dashboardDate(d.value('from_date'))} – ${dashboardDate(d.value('to_date'))} • Company data through: ${dashboardDate(d.value('last_sync_on'))}\nOutstanding, inventory and cash are latest snapshots. Changing the period affects vouchers and sales charts.',
      ),
      const SizedBox(height: 16),
      _Metrics(
        values: [
          _Metric(
            'Total Receivables',
            money('outstanding.receivables'),
            '${count('outstanding.customers')} customers • latest bills',
            Icons.call_received,
            _green,
          ),
          _Metric(
            'Total Payables',
            money('outstanding.payables'),
            '${count('outstanding.suppliers')} suppliers • latest bills',
            Icons.call_made,
            _red,
          ),
          _Metric(
            'Inventory Value',
            inventory ? money('inventory.value') : 'No access',
            '${count('inventory.items')} items • permitted warehouses',
            Icons.inventory_2_outlined,
            _blue,
          ),
          _Metric(
            'Sales',
            money('activity.current.sales'),
            '${count('activity.current.sales_count')} invoices • selected period',
            Icons.trending_up,
            const Color(0xFF7F56D9),
            d.change('sales'),
          ),
          _Metric(
            'Purchases',
            money('activity.current.purchases'),
            '${count('activity.current.purchase_count')} invoices • selected period',
            Icons.shopping_bag_outlined,
            _blue,
            d.change('purchases'),
          ),
          _Metric(
            'Receipts',
            money('activity.current.receipts'),
            'Permitted party vouchers • selected period',
            Icons.south_west,
            _green,
            d.change('receipts'),
          ),
          _Metric(
            'Payments',
            money('activity.current.payments'),
            'Permitted party vouchers • selected period',
            Icons.north_east,
            const Color(0xFFDC6803),
            d.change('payments'),
          ),
          _Metric(
            'Cash & Bank',
            cash
                ? dashboardMoney(d.number('cash.cash') + d.number('cash.bank'))
                : 'Unavailable',
            cash
                ? 'Latest current FY balances'
                : 'Check ledger mapping and balance sync',
            Icons.account_balance_outlined,
            _muted,
          ),
        ],
      ),
      const SizedBox(height: 18),
      _Pair(
        left: _Panel(
          title: 'Sales Performance',
          subtitle: 'Gross Sales and Purchase vouchers • selected period',
          child: _Trend(rows: d.rows('activity.trend')),
        ),
        right: _Panel(
          title: 'Outstanding Ageing',
          subtitle: 'Days past due • latest pending bills',
          child: _Ageing(rows: d.rows('outstanding.ageing')),
        ),
      ),
      const SizedBox(height: 18),
      _Panel(
        title: 'Inventory Health',
        subtitle: inventory
            ? 'Latest stock snapshot: ${dashboardDate(d.value('inventory.last_sync_on'))}. Counts are item/unit combinations.'
            : 'Item and warehouse mappings are required to view inventory.',
        child: inventory
            ? Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _stat(
                    'Negative stock',
                    count('inventory.negative_stock'),
                    _red,
                  ),
                  _stat(
                    'Out of stock',
                    count('inventory.out_of_stock'),
                    _muted,
                  ),
                  _stat(
                    'Low stock',
                    d.number('inventory.configured_thresholds') == 0
                        ? 'Not configured'
                        : count('inventory.low_stock'),
                    const Color(0xFFDC6803),
                  ),
                  _stat(
                    'No outward in 90 days',
                    count('inventory.no_outward_90_days'),
                    const Color(0xFF7F56D9),
                  ),
                ],
              )
            : const _Empty('No permitted inventory data.'),
      ),
      const SizedBox(height: 18),
      _Pair(
        left: _Panel(
          title: 'Top Outstanding Customers',
          subtitle: 'Positive pending balances; credits are separate.',
          child: _Ranked(
            rows: d.rows('outstanding.top_customers'),
            detail: (r) => r['overdue_days'] == null
                ? 'Due date unavailable'
                : '${r['overdue_days']} days overdue',
          ),
        ),
        right: _Panel(
          title: 'Inventory Movement',
          subtitle:
              'Last outward movement • positive-stock item/unit combinations',
          child: _Movement(rows: d.rows('inventory.movement')),
        ),
      ),
      const SizedBox(height: 18),
      _Pair(
        left: _Panel(
          title: 'Top Selling Items',
          subtitle: 'By line amount • selected period • permitted items',
          child: _Ranked(
            rows: d.rows('activity.top_items'),
            detail: (r) =>
                '${dashboardNumber(r['quantity']).toStringAsFixed(2)} ${r['unit'] ?? ''}',
          ),
        ),
        right: _Panel(
          title: 'Cash & Party Flows',
          subtitle:
              'Receipt/payment vouchers follow your party and voucher-type permissions.',
          child: Column(
            children: [
              _value(
                'Receipts in period',
                money('activity.current.receipts'),
                _green,
              ),
              _value(
                'Payments in period',
                money('activity.current.payments'),
                _red,
              ),
              const Divider(height: 28),
              _value(
                'Cash balance • current FY',
                cash ? money('cash.cash') : 'Unavailable',
                _ink,
              ),
              _value(
                'Bank balance • current FY',
                cash ? money('cash.bank') : 'Unavailable',
                _ink,
              ),
              if (!cash)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Sync LedgerBalancesFY after the API update. Only balances scoped to this company are included.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      _Pair(
        left: _Panel(
          title: 'Attention Required',
          subtitle: 'Based on your latest accessible snapshots.',
          child: Column(
            children: [
              _value(
                'Overdue receivables',
                money('outstanding.overdue_receivables'),
                _red,
              ),
              _value(
                'Overdue payables',
                money('outstanding.overdue_payables'),
                _red,
              ),
              _value(
                'Payables due within 7 days',
                money('outstanding.upcoming_payables'),
                _ink,
              ),
              _value(
                'Bills without a due date',
                money('outstanding.undated'),
                _muted,
              ),
              _value(
                'Customer credits',
                money('outstanding.customer_credits'),
                _muted,
              ),
              _value(
                'Supplier advances',
                money('outstanding.supplier_advances'),
                _muted,
              ),
            ],
          ),
        ),
        right: _Panel(
          title: 'Quick Actions',
          subtitle: 'Continue into your workspace.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: widget.onOpenReports,
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Open Reports'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: widget.onOpenUserMapping,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('User Mapping'),
              ),
              const SizedBox(height: 14),
              const Text(
                'All figures follow the selected company and your master mappings. Changes to access apply on the next refresh.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      _Panel(
        title: 'Recent Transactions',
        subtitle: 'Latest 10 permitted vouchers in the selected period.',
        child: _Transactions(rows: d.rows('activity.recent')),
      ),
      const SizedBox(height: 12),
      Text(
        d.text('activity.basis'),
        style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
      ),
    ];
  }

  Widget _stat(String title, String value, Color color) => Container(
    width: 218,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

Widget _value(String title, String value, Color color) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Expanded(
        child: Text(title, style: const TextStyle(fontSize: 13, color: _muted)),
      ),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    ],
  ),
);

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE4E7EC)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: _ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, color: _blue, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF344054),
              height: 1.7,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, height: 1.5),
      ),
    ),
  );
}

class _Pair extends StatelessWidget {
  const _Pair({required this.left, required this.right});
  final Widget left, right;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 980
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 18), right],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 18),
              Expanded(child: right),
            ],
          ),
  );
}

class _Metric {
  const _Metric(
    this.title,
    this.value,
    this.helper,
    this.icon,
    this.color, [
    this.change,
  ]);
  final String title, value, helper;
  final IconData icon;
  final Color color;
  final double? change;
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.values});
  final List<_Metric> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final columns = c.maxWidth >= 1150
          ? 4
          : c.maxWidth >= 520
          ? 2
          : 1;
      final width = (c.maxWidth - (columns - 1) * 14) / columns;
      return Wrap(
        spacing: 14,
        runSpacing: 14,
        children: values
            .map(
              (m) => SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE4E7EC)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.title,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _muted,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: m.color.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(m.icon, size: 18, color: m.color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        m.value,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.helper,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                      if (m.change != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${m.change! > 0 ? '+' : ''}${m.change!.toStringAsFixed(1)}% vs previous equal-length period',
                            style: const TextStyle(fontSize: 10, color: _muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _Trend extends StatelessWidget {
  const _Trend({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    final max = rows.fold<double>(
      0,
      (v, r) => math.max(
        v,
        math.max(dashboardNumber(r['sales']), dashboardNumber(r['purchases'])),
      ),
    );
    if (max == 0) {
      return const _Empty(
        'No permitted Sales or Purchase vouchers in this period.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.circle, size: 9, color: _blue),
            SizedBox(width: 6),
            Text('Sales', style: TextStyle(fontSize: 12)),
            SizedBox(width: 18),
            Icon(Icons.circle, size: 9, color: _green),
            SizedBox(width: 6),
            Text('Purchases', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: math.max(c.maxWidth, rows.length * 66),
              height: 230,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: rows.map((r) {
                  final date = DateTime.tryParse('${r['month']}');
                  const months = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec',
                  ];
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _bar(
                              dashboardNumber(r['sales']),
                              max,
                              _blue,
                              'Sales',
                            ),
                            const SizedBox(width: 5),
                            _bar(
                              dashboardNumber(r['purchases']),
                              max,
                              _green,
                              'Purchases',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          date == null
                              ? ''
                              : '${months[date.month - 1]}\n${date.year}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: _muted),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Peak monthly amount: ${dashboardMoney(max)} • hover on a bar for its value',
          style: const TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    );
  }

  Widget _bar(double value, double max, Color color, String label) => Tooltip(
    message: '$label: ${dashboardMoney(value)}',
    child: Container(
      width: 16,
      height: math.max(2, value / max * 170),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    ),
  );
}

class _Ageing extends StatelessWidget {
  const _Ageing({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Row(
        children: [
          Expanded(
            child: Text(
              'Past due',
              style: TextStyle(color: _muted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              'Receivable',
              textAlign: TextAlign.right,
              style: TextStyle(color: _green, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              'Payable',
              textAlign: TextAlign.right,
              style: TextStyle(color: _blue, fontSize: 11),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${r['label']}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ),
              Expanded(
                child: Text(
                  dashboardMoney(dashboardNumber(r['receivables'])),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  dashboardMoney(dashboardNumber(r['payables'])),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

class _Ranked extends StatelessWidget {
  const _Ranked({required this.rows, required this.detail});
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) detail;
  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const _Empty('No permitted records to display.')
      : Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(0xFFEFF6FF),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 11, color: _blue),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rows[i]['name']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            detail(rows[i]),
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dashboardMoney(dashboardNumber(rows[i]['amount'])),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _ink,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
}

class _Movement extends StatelessWidget {
  const _Movement({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(
      0,
      (n, r) => n + dashboardNumber(r['count']),
    );
    if (total == 0) return const _Empty('No permitted positive-stock items.');
    const colors = [_green, _blue, Color(0xFFDC6803), Color(0xFF7F56D9)];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: Column(
              children: [
                _value(
                  '${rows[i]['label']}',
                  dashboardNumber(rows[i]['count']).toInt().toString(),
                  colors[i % 4],
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: dashboardNumber(rows[i]['count']) / total,
                    minHeight: 7,
                    color: colors[i % 4],
                    backgroundColor: const Color(0xFFF2F4F7),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Transactions extends StatelessWidget {
  const _Transactions({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) => rows.isEmpty
      ? const _Empty('No permitted vouchers in the selected period.')
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(Color(0xFFF8FAFC)),
            columnSpacing: 28,
            dataRowMinHeight: 48,
            dataRowMaxHeight: 60,
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Voucher')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Party')),
              DataColumn(label: Text('Amount'), numeric: true),
            ],
            rows: rows
                .map(
                  (r) => DataRow(
                    cells: [
                      DataCell(Text(dashboardDate(r['date']))),
                      DataCell(Text('${r['voucher']}')),
                      DataCell(Text('${r['type']}')),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: Text('${r['party']}'),
                        ),
                      ),
                      DataCell(
                        Text(dashboardMoney(dashboardNumber(r['amount']))),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        );
}
