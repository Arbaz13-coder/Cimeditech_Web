import 'dart:math' as math;

import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.onOpenReports,
    this.onOpenUserMapping,
  });

  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenUserMapping;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedCompany = 'Demo Company Pvt Ltd';
  String _selectedPeriod = 'Current FY';
  bool _refreshing = false;

  static const _companies = <String>[
    'Demo Company Pvt Ltd',
    'CMX Industries',
    'CMX Trading Company',
  ];

  static const _periods = <String>[
    'Current FY',
    'This Month',
    'Last Month',
    'Last 90 Days',
  ];

  Future<void> _refreshDashboard() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Dashboard refreshed.')),
      );
  }

  void _openPlaceholder(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$label drill-down will open its report here.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F7FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final pagePadding = width < 640 ? 14.0 : width < 1050 ? 18.0 : 22.0;

          return RefreshIndicator(
            onRefresh: _refreshDashboard,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(pagePadding, 18, pagePadding, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1580),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DashboardHeader(
                        selectedCompany: _selectedCompany,
                        companies: _companies,
                        selectedPeriod: _selectedPeriod,
                        periods: _periods,
                        refreshing: _refreshing,
                        onCompanyChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedCompany = value);
                        },
                        onPeriodChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedPeriod = value);
                        },
                        onRefresh: _refreshDashboard,
                      ),
                      const SizedBox(height: 18),
                      _KpiGrid(onTap: _openPlaceholder),
                      const SizedBox(height: 18),
                      _AdaptiveTwoColumn(
                        leftFlex: 1.18,
                        rightFlex: .82,
                        left: _SalesOverviewCard(onTap: _openPlaceholder),
                        right: _OutstandingCard(onTap: _openPlaceholder),
                      ),
                      const SizedBox(height: 18),
                      _InventoryHealthCard(onTap: _openPlaceholder),
                      const SizedBox(height: 18),
                      _AdaptiveTwoColumn(
                        leftFlex: 1,
                        rightFlex: 1,
                        left: _TopOutstandingCustomersCard(onTap: _openPlaceholder),
                        right: _InventoryMovementCard(onTap: _openPlaceholder),
                      ),
                      const SizedBox(height: 18),
                      _AdaptiveTwoColumn(
                        leftFlex: 1,
                        rightFlex: 1,
                        left: _TopSellingItemsCard(onTap: _openPlaceholder),
                        right: _CashFlowCard(onTap: _openPlaceholder),
                      ),
                      const SizedBox(height: 18),
                      _AdaptiveTwoColumn(
                        leftFlex: 1.35,
                        rightFlex: .65,
                        left: _ActionRequiredCard(onTap: _openPlaceholder),
                        right: _QuickActionsCard(
                          onOpenReports: widget.onOpenReports,
                          onOpenUserMapping: widget.onOpenUserMapping,
                          onRefresh: _refreshDashboard,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _RecentTransactionsCard(onTap: _openPlaceholder),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.selectedCompany,
    required this.companies,
    required this.selectedPeriod,
    required this.periods,
    required this.refreshing,
    required this.onCompanyChanged,
    required this.onPeriodChanged,
    required this.onRefresh,
  });

  final String selectedCompany;
  final List<String> companies;
  final String selectedPeriod;
  final List<String> periods;
  final bool refreshing;
  final ValueChanged<String?> onCompanyChanged;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 850;

        final filters = Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _CompactDropdown(
              width: compact ? math.min(330, constraints.maxWidth) : 250,
              icon: Icons.business_outlined,
              value: selectedCompany,
              items: companies,
              onChanged: onCompanyChanged,
            ),
            _CompactDropdown(
              width: compact ? math.min(220, constraints.maxWidth) : 180,
              icon: Icons.calendar_month_outlined,
              value: selectedPeriod,
              items: periods,
              onChanged: onPeriodChanged,
            ),
            OutlinedButton.icon(
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(refreshing ? 'Refreshing' : 'Refresh'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(108, 44),
                side: const BorderSide(color: Color(0xFFD0D5DD)),
                foregroundColor: const Color(0xFF344054),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardIntro(),
              const SizedBox(height: 14),
              filters,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(child: _DashboardIntro()),
            const SizedBox(width: 24),
            Flexible(flex: 2, child: filters),
          ],
        );
      },
    );
  }
}

class _DashboardIntro extends StatelessWidget {
  const _DashboardIntro();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Business Snapshot',
          style: TextStyle(
            color: Color(0xFF101828),
            fontSize: 23,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -.25,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Receivables, inventory, sales and cash flow at a glance.',
          style: TextStyle(
            color: Color(0xFF667085),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  const _CompactDropdown({
    required this.width,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final IconData icon;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 44,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF475467)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
          ),
        ),
        style: const TextStyle(
          color: Color(0xFF344054),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        items: items
            .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.onTap});

  final ValueChanged<String> onTap;

  static const _items = <_KpiData>[
    _KpiData(
      title: 'Total Receivables',
      value: '₹ 12.48L',
      helper: '32 customers',
      delta: '+8.4%',
      positive: true,
      icon: Icons.groups_2_outlined,
      accent: Color(0xFF039855),
      accentSoft: Color(0xFFECFDF3),
    ),
    _KpiData(
      title: 'Total Payables',
      value: '₹ 8.76L',
      helper: '18 suppliers',
      delta: '+4.1%',
      positive: false,
      icon: Icons.account_balance_outlined,
      accent: Color(0xFFD92D20),
      accentSoft: Color(0xFFFEF3F2),
    ),
    _KpiData(
      title: 'Inventory Value',
      value: '₹ 25.34L',
      helper: '1,248 items',
      delta: '+5.0%',
      positive: true,
      icon: Icons.inventory_2_outlined,
      accent: Color(0xFF175CD3),
      accentSoft: Color(0xFFEFF4FF),
    ),
    _KpiData(
      title: 'Cash + Bank',
      value: '₹ 14.20L',
      helper: '8 accounts',
      delta: '+3.2%',
      positive: true,
      icon: Icons.account_balance_wallet_outlined,
      accent: Color(0xFF6941C6),
      accentSoft: Color(0xFFF4F3FF),
    ),
    _KpiData(
      title: 'Sales',
      value: '₹ 18.92L',
      helper: '286 invoices',
      delta: '+15.3%',
      positive: true,
      icon: Icons.trending_up_rounded,
      accent: Color(0xFF026AA2),
      accentSoft: Color(0xFFF0F9FF),
    ),
    _KpiData(
      title: 'Purchases',
      value: '₹ 13.40L',
      helper: '174 invoices',
      delta: '+6.8%',
      positive: false,
      icon: Icons.shopping_cart_outlined,
      accent: Color(0xFFB54708),
      accentSoft: Color(0xFFFFFAEB),
    ),
    _KpiData(
      title: 'Gross Profit',
      value: '₹ 5.52L',
      helper: '29.1% margin',
      delta: '+2.7%',
      positive: true,
      icon: Icons.show_chart_rounded,
      accent: Color(0xFF027A48),
      accentSoft: Color(0xFFECFDF3),
    ),
    _KpiData(
      title: 'Net Profit',
      value: '₹ 3.86L',
      helper: '20.4% margin',
      delta: '+1.9%',
      positive: true,
      icon: Icons.savings_outlined,
      accent: Color(0xFF7F56D9),
      accentSoft: Color(0xFFF4F3FF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1380
            ? 4
            : constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 540
                    ? 2
                    : 1;
        final gap = 12.0;
        final itemWidth = (constraints.maxWidth - (gap * (count - 1))) / count;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: _items
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _KpiCard(
                    data: item,
                    onTap: () => onTap(item.title),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data, required this.onTap});

  final _KpiData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: data.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: data.accent, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475467),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.value,
                    style: const TextStyle(
                      color: Color(0xFF101828),
                      fontSize: 21,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.helper,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _DeltaBadge(value: data.delta, positive: data.positive),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.value, required this.positive});

  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF027A48) : const Color(0xFFB42318);
    final background = positive ? const Color(0xFFECFDF3) : const Color(0xFFFEF3F2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveTwoColumn extends StatelessWidget {
  const _AdaptiveTwoColumn({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  final Widget left;
  final Widget right;
  final double leftFlex;
  final double rightFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [left, const SizedBox(height: 18), right],
          );
        }

        final total = leftFlex + rightFlex;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: (leftFlex / total * 1000).round(), child: left),
            const SizedBox(width: 18),
            Expanded(flex: (rightFlex / total * 1000).round(), child: right),
          ],
        );
      },
    );
  }
}

class _SalesOverviewCard extends StatelessWidget {
  const _SalesOverviewCard({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sales Performance',
      subtitle: 'Monthly sales compared with purchases',
      actionLabel: 'Open sales report',
      onAction: () => onTap('Sales report'),
      child: Column(
        children: [
          const Wrap(
            spacing: 26,
            runSpacing: 12,
            children: [
              _MiniMetric(label: 'This Month', value: '₹ 18.92L'),
              _MiniMetric(label: 'Purchase', value: '₹ 13.40L'),
              _MiniMetric(label: 'Gross Profit', value: '₹ 5.52L'),
              _MiniMetric(label: 'Margin', value: '29.1%'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 235,
            child: CustomPaint(
              painter: _SalesTrendPainter(
                sales: const [21, 22, 19, 24, 25, 30, 27, 31, 21, 23, 20, 28],
                purchases: const [12, 13, 12, 14, 16, 22, 20, 21, 17, 16, 18, 24],
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(label: 'Sales', color: Color(0xFF175CD3)),
              SizedBox(width: 18),
              _LegendDot(label: 'Purchase', color: Color(0xFF12B76A)),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Outstanding',
      subtitle: 'Receivable and payable position',
      actionLabel: 'View ageing',
      onAction: () => onTap('Outstanding ageing'),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: _OutstandingSummary(
                  label: 'Receivable',
                  value: '₹ 12.48L',
                  helper: '₹ 4.65L overdue',
                  color: Color(0xFF039855),
                  background: Color(0xFFECFDF3),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _OutstandingSummary(
                  label: 'Payable',
                  value: '₹ 8.76L',
                  helper: '₹ 2.10L due this week',
                  color: Color(0xFFD92D20),
                  background: Color(0xFFFEF3F2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Receivable ageing',
              style: TextStyle(color: Color(0xFF344054), fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          const _AgeingBar(label: '0–30 days', amount: '₹ 5.20L', value: .78, color: Color(0xFF12B76A)),
          const SizedBox(height: 12),
          const _AgeingBar(label: '31–60 days', amount: '₹ 3.15L', value: .52, color: Color(0xFFF79009)),
          const SizedBox(height: 12),
          const _AgeingBar(label: '61–90 days', amount: '₹ 2.01L', value: .34, color: Color(0xFFF04438)),
          const SizedBox(height: 12),
          const _AgeingBar(label: '90+ days', amount: '₹ 2.12L', value: .36, color: Color(0xFFD92D20)),
          const SizedBox(height: 20),
          const _OutstandingFooter(),
        ],
      ),
    );
  }
}

class _OutstandingSummary extends StatelessWidget {
  const _OutstandingSummary({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final String helper;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF475467), fontSize: 10, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Color(0xFF101828), fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(helper, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AgeingBar extends StatelessWidget {
  const _AgeingBar({required this.label, required this.amount, required this.value, required this.color});

  final String label;
  final String amount;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 10, fontWeight: FontWeight.w600))),
            Text(amount, style: const TextStyle(color: Color(0xFF344054), fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: const Color(0xFFF2F4F7),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _OutstandingFooter extends StatelessWidget {
  const _OutstandingFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEC84B).withValues(alpha: .45)),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule_rounded, color: Color(0xFFB54708), size: 17),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '5 customers are overdue by more than 60 days',
              style: TextStyle(color: Color(0xFF7A2E0E), fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryHealthCard extends StatelessWidget {
  const _InventoryHealthCard({required this.onTap});

  final ValueChanged<String> onTap;

  static const _stats = <_InventoryStatData>[
    _InventoryStatData('Stock Value', '₹ 25.34L', Icons.inventory_2_outlined, Color(0xFF175CD3), Color(0xFFEFF4FF)),
    _InventoryStatData('Low Stock', '18', Icons.south_east_rounded, Color(0xFFF79009), Color(0xFFFFFAEB)),
    _InventoryStatData('Out of Stock', '6', Icons.remove_shopping_cart_outlined, Color(0xFFD92D20), Color(0xFFFEF3F2)),
    _InventoryStatData('Negative Stock', '3', Icons.warning_amber_rounded, Color(0xFFB42318), Color(0xFFFEF3F2)),
    _InventoryStatData('Slow Moving', '42', Icons.speed_rounded, Color(0xFF6941C6), Color(0xFFF4F3FF)),
    _InventoryStatData('Dead Stock', '16', Icons.hourglass_disabled_rounded, Color(0xFF475467), Color(0xFFF2F4F7)),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Inventory Health',
      subtitle: 'Items that need stock or movement attention',
      actionLabel: 'Open inventory',
      onAction: () => onTap('Inventory'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth >= 1250
              ? 6
              : constraints.maxWidth >= 820
                  ? 3
                  : constraints.maxWidth >= 500
                      ? 2
                      : 1;
          final gap = 10.0;
          final width = (constraints.maxWidth - gap * (count - 1)) / count;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: _stats
                .map(
                  (stat) => SizedBox(
                    width: width,
                    child: _InventoryStat(
                      data: stat,
                      onTap: () => onTap(stat.label),
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _InventoryStat extends StatelessWidget {
  const _InventoryStat({required this.data, required this.onTap});

  final _InventoryStatData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFCFCFD),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFEAECF0)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: data.background, borderRadius: BorderRadius.circular(11)),
                child: Icon(data.icon, color: data.color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.value, style: const TextStyle(color: Color(0xFF101828), fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(data.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w600, fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopOutstandingCustomersCard extends StatelessWidget {
  const _TopOutstandingCustomersCard({required this.onTap});

  final ValueChanged<String> onTap;

  static const _rows = <_OutstandingParty>[
    _OutstandingParty('ABC Traders', '₹ 2.45L', 45, .95),
    _OutstandingParty('Shree Enterprises', '₹ 1.86L', 32, .76),
    _OutstandingParty('Global Industries', '₹ 1.24L', 28, .51),
    _OutstandingParty('Kamal Traders', '₹ 98.45K', 20, .40),
    _OutstandingParty('National Supplies', '₹ 87.32K', 15, .36),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Top Outstanding Customers',
      subtitle: 'Highest receivable exposure',
      actionLabel: 'View all',
      onAction: () => onTap('Receivables'),
      child: Column(
        children: _rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onTap(row.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF344054), fontSize: 11, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: row.share,
                                  minHeight: 4,
                                  backgroundColor: const Color(0xFFF2F4F7),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF84ADFF)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 74,
                          child: Text(row.amount, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF101828), fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 12),
                        _DaysBadge(days: row.days),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _DaysBadge extends StatelessWidget {
  const _DaysBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final severe = days > 30;
    final medium = days > 20;
    final color = severe
        ? const Color(0xFFB42318)
        : medium
            ? const Color(0xFFB54708)
            : const Color(0xFF027A48);
    final background = severe
        ? const Color(0xFFFEF3F2)
        : medium
            ? const Color(0xFFFFFAEB)
            : const Color(0xFFECFDF3);

    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text('$days d', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }
}

class _InventoryMovementCard extends StatelessWidget {
  const _InventoryMovementCard({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Inventory Movement',
      subtitle: 'Stock movement classification',
      actionLabel: 'Stock report',
      onAction: () => onTap('Stock report'),
      child: Column(
        children: [
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 430) {
                return const Column(
                  children: [
                    _MovementRing(),
                    SizedBox(height: 18),
                    _MovementLegend(),
                  ],
                );
              }
              return const Row(
                children: [
                  Expanded(child: Center(child: _MovementRing())),
                  SizedBox(width: 18),
                  Expanded(child: _MovementLegend()),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAECF0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, size: 17, color: Color(0xFF175CD3)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '58 items have had no movement for more than 60 days.',
                    style: TextStyle(color: Color(0xFF475467), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementRing extends StatelessWidget {
  const _MovementRing();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 164,
      height: 164,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(164),
            painter: _DonutPainter(
              values: const [.52, .27, .14, .07],
              colors: const [Color(0xFF12B76A), Color(0xFFF79009), Color(0xFF7F56D9), Color(0xFF98A2B3)],
            ),
          ),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('279', style: TextStyle(color: Color(0xFF101828), fontSize: 25, fontWeight: FontWeight.w800)),
              Text('Tracked items', style: TextStyle(color: Color(0xFF667085), fontSize: 9, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MovementLegend extends StatelessWidget {
  const _MovementLegend();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _MovementLegendRow(label: 'Fast Moving', count: '145', percent: '52%', color: Color(0xFF12B76A)),
        SizedBox(height: 13),
        _MovementLegendRow(label: 'Slow Moving', count: '76', percent: '27%', color: Color(0xFFF79009)),
        SizedBox(height: 13),
        _MovementLegendRow(label: 'Non Moving', count: '42', percent: '14%', color: Color(0xFF7F56D9)),
        SizedBox(height: 13),
        _MovementLegendRow(label: 'Dead Stock', count: '16', percent: '7%', color: Color(0xFF98A2B3)),
      ],
    );
  }
}

class _MovementLegendRow extends StatelessWidget {
  const _MovementLegendRow({required this.label, required this.count, required this.percent, required this.color});

  final String label;
  final String count;
  final String percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF475467), fontSize: 10, fontWeight: FontWeight.w600))),
        Text(count, style: const TextStyle(color: Color(0xFF101828), fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        SizedBox(width: 28, child: Text(percent, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

class _TopSellingItemsCard extends StatelessWidget {
  const _TopSellingItemsCard({required this.onTap});

  final ValueChanged<String> onTap;

  static const _rows = <_SellingItem>[
    _SellingItem('MS Pipe', '₹ 4.32L', '1,820 KGS', .92),
    _SellingItem('SS Sheet', '₹ 3.18L', '965 KGS', .74),
    _SellingItem('Copper Wire', '₹ 2.45L', '640 KGS', .58),
    _SellingItem('PVC Granules', '₹ 1.86L', '1,145 KGS', .44),
    _SellingItem('Aluminium Rod', '₹ 1.55L', '420 KGS', .37),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Top Selling Items',
      subtitle: 'Highest sales value this period',
      actionLabel: 'View items',
      onAction: () => onTap('Top selling items'),
      child: Column(
        children: _rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index == _rows.length - 1 ? 0 : 12),
            child: InkWell(
              onTap: () => onTap(row.name),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(9)),
                      child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF175CD3), fontWeight: FontWeight.w800, fontSize: 10)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(row.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF344054), fontWeight: FontWeight.w700, fontSize: 11))),
                              Text(row.amount, style: const TextStyle(color: Color(0xFF101828), fontWeight: FontWeight.w800, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: row.share,
                                    minHeight: 4,
                                    backgroundColor: const Color(0xFFF2F4F7),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF528BFF)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(width: 64, child: Text(row.quantity, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 8, fontWeight: FontWeight.w600))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _CashFlowCard extends StatelessWidget {
  const _CashFlowCard({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Cash Flow',
      subtitle: 'Receipts and payments for this period',
      actionLabel: 'Cash / Bank book',
      onAction: () => onTap('Cash / Bank book'),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(child: _CashMetric(label: 'Receipts', value: '₹ 6.45L', icon: Icons.south_west_rounded, color: Color(0xFF039855), background: Color(0xFFECFDF3))),
              SizedBox(width: 10),
              Expanded(child: _CashMetric(label: 'Payments', value: '₹ 4.32L', icon: Icons.north_east_rounded, color: Color(0xFFD92D20), background: Color(0xFFFEF3F2))),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEEF4FF), Color(0xFFF9F5FF)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6E4FF)),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net Cash Flow', style: TextStyle(color: Color(0xFF475467), fontSize: 10, fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('₹ 2.13L', style: TextStyle(color: Color(0xFF101828), fontSize: 24, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF175CD3), size: 32),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _CashLine(label: 'Cash Balance', value: '₹ 3.25L'),
          const Divider(height: 20, color: Color(0xFFEAECF0)),
          const _CashLine(label: 'Bank Balance', value: '₹ 10.95L'),
          const Divider(height: 20, color: Color(0xFFEAECF0)),
          const _CashLine(label: 'Expected Collections', value: '₹ 3.75L', helper: 'next 7 days'),
          const Divider(height: 20, color: Color(0xFFEAECF0)),
          const _CashLine(label: 'Upcoming Payments', value: '₹ 2.10L', helper: 'next 7 days'),
        ],
      ),
    );
  }
}

class _CashMetric extends StatelessWidget {
  const _CashMetric({required this.label, required this.value, required this.icon, required this.color, required this.background});

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 9, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Color(0xFF101828), fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CashLine extends StatelessWidget {
  const _CashLine({required this.label, required this.value, this.helper});

  final String label;
  final String value;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 10, fontWeight: FontWeight.w600)),
        ),
        if (helper != null) ...[
          Text(helper!, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 8, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
        ],
        Text(value, style: const TextStyle(color: Color(0xFF101828), fontSize: 11, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _ActionRequiredCard extends StatelessWidget {
  const _ActionRequiredCard({required this.onTap});

  final ValueChanged<String> onTap;

  static const _alerts = <_AlertData>[
    _AlertData(Icons.schedule_rounded, '5 customers overdue more than 60 days', '₹ 2.12L exposed', Color(0xFFD92D20), Color(0xFFFEF3F2)),
    _AlertData(Icons.warning_amber_rounded, '3 items have negative stock', 'Review stock transactions', Color(0xFFD92D20), Color(0xFFFEF3F2)),
    _AlertData(Icons.inventory_2_outlined, '18 items below minimum stock', 'Reorder may be required', Color(0xFFF79009), Color(0xFFFFFAEB)),
    _AlertData(Icons.payments_outlined, '₹ 2.10L supplier payments due this week', '7 suppliers', Color(0xFFF79009), Color(0xFFFFFAEB)),
    _AlertData(Icons.currency_rupee_rounded, '₹ 3.75L customer collections expected', 'Next 7 days', Color(0xFF039855), Color(0xFFECFDF3)),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Action Required',
      subtitle: 'Exceptions that need your attention',
      actionLabel: 'View alerts',
      onAction: () => onTap('Alerts'),
      child: Column(
        children: _alerts.asMap().entries.map((entry) {
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: entry.key == _alerts.length - 1 ? 0 : 9),
            child: Material(
              color: item.background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onTap(item.title),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(9)),
                        child: Icon(item.icon, color: item.color, size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(color: Color(0xFF344054), fontSize: 10, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(item.helper, style: const TextStyle(color: Color(0xFF667085), fontSize: 8, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: item.color, size: 19),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onOpenReports,
    required this.onOpenUserMapping,
    required this.onRefresh,
  });

  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenUserMapping;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Quick Actions',
      subtitle: 'Jump to frequent tasks',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final oneColumn = constraints.maxWidth < 300;
          final gap = 10.0;
          final width = oneColumn ? constraints.maxWidth : (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              _QuickAction(width: width, icon: Icons.analytics_outlined, label: 'View Reports', onTap: onOpenReports),
              _QuickAction(width: width, icon: Icons.admin_panel_settings_outlined, label: 'User Mapping', onTap: onOpenUserMapping),
              _QuickAction(width: width, icon: Icons.refresh_rounded, label: 'Refresh Data', onTap: onRefresh),
              _QuickAction(
                width: width,
                icon: Icons.download_outlined,
                label: 'Export Summary',
                onTap: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Dashboard export will be connected with the dashboard API.')));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.width, required this.icon, required this.label, required this.onTap});

  final double width;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 86,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFEAECF0)), borderRadius: BorderRadius.circular(12)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: const Color(0xFF175CD3), size: 23),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: Color(0xFF344054), fontSize: 9, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({required this.onTap});

  final ValueChanged<String> onTap;

  static const _rows = <_TransactionData>[
    _TransactionData('04 Sep 2026', 'S-001245', 'Sales', 'ABC Traders', '₹ 2,45,000'),
    _TransactionData('04 Sep 2026', 'RC-000452', 'Receipt', 'Shree Enterprises', '₹ 1,20,000'),
    _TransactionData('03 Sep 2026', 'P-000987', 'Purchase', 'Steel Corp', '₹ 1,86,500'),
    _TransactionData('03 Sep 2026', 'PY-000321', 'Payment', 'Metro Distributors', '₹ 85,000'),
    _TransactionData('02 Sep 2026', 'S-001244', 'Sales', 'Global Industries', '₹ 1,45,300'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Recent Transactions',
      subtitle: 'Latest business activity from synced vouchers',
      actionLabel: 'View all transactions',
      onAction: () => onTap('Recent transactions'),
      contentPadding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 700) {
            return Column(
              children: _rows
                  .map(
                    (row) => InkWell(
                      onTap: () => onTap(row.voucher),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            _TransactionTypeBadge(type: row.type),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(row.party, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF344054), fontSize: 11, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text('${row.date}  •  ${row.voucher}', style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 8, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(row.amount, style: const TextStyle(color: Color(0xFF101828), fontSize: 11, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          }

          return Column(
            children: [
              Container(
                color: const Color(0xFFF9FAFB),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                child: const Row(
                  children: [
                    _TableHeader(width: 115, text: 'DATE'),
                    _TableHeader(width: 130, text: 'VOUCHER'),
                    _TableHeader(width: 120, text: 'TYPE'),
                    Expanded(child: _TableHeader(text: 'PARTY')),
                    _TableHeader(width: 130, text: 'AMOUNT', align: TextAlign.right),
                  ],
                ),
              ),
              ..._rows.map(
                (row) => InkWell(
                  onTap: () => onTap(row.voucher),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEAECF0)))),
                    child: Row(
                      children: [
                        SizedBox(width: 115, child: Text(row.date, style: const TextStyle(color: Color(0xFF667085), fontSize: 10, fontWeight: FontWeight.w600))),
                        SizedBox(width: 130, child: Text(row.voucher, style: const TextStyle(color: Color(0xFF344054), fontSize: 10, fontWeight: FontWeight.w700))),
                        SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: _TransactionTypeBadge(type: row.type))),
                        Expanded(child: Text(row.party, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF344054), fontSize: 10, fontWeight: FontWeight.w600))),
                        SizedBox(width: 130, child: Text(row.amount, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF101828), fontSize: 10, fontWeight: FontWeight.w800))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({this.width, required this.text, this.align = TextAlign.left});

  final double? width;
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final child = Text(text, textAlign: align, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: .55));
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

class _TransactionTypeBadge extends StatelessWidget {
  const _TransactionTypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    late Color color;
    late Color background;
    switch (type) {
      case 'Sales':
        color = const Color(0xFF027A48);
        background = const Color(0xFFECFDF3);
        break;
      case 'Purchase':
        color = const Color(0xFFB42318);
        background = const Color(0xFFFEF3F2);
        break;
      case 'Receipt':
        color = const Color(0xFF175CD3);
        background = const Color(0xFFEFF4FF);
        break;
      default:
        color = const Color(0xFF6941C6);
        background = const Color(0xFFF4F3FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(type, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.contentPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets contentPadding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Color(0xFF101828), fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      foregroundColor: const Color(0xFF175CD3),
                    ),
                    child: Text(actionLabel!, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          Padding(padding: contentPadding, child: child),
        ],
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovered ? const Color(0xFFB2CCFF) : const Color(0xFFE4E7EC)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF101828).withValues(alpha: _hovered ? .08 : .035),
              blurRadius: _hovered ? 20 : 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(onTap: widget.onTap, borderRadius: BorderRadius.circular(16), child: widget.child),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: Color(0xFF101828), fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SalesTrendPainter extends CustomPainter {
  const _SalesTrendPainter({required this.sales, required this.purchases});

  final List<double> sales;
  final List<double> purchases;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 28.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final axisPaint = Paint()..color = const Color(0xFFEAECF0);
    final salesPaint = Paint()..color = const Color(0xFF175CD3);
    final purchasePaint = Paint()..color = const Color(0xFF12B76A);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * (i / 4);
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), axisPaint);
      final value = 40 - (i * 10);
      textPainter.text = TextSpan(
        text: value == 0 ? '0' : '${value}L',
        style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 8, fontWeight: FontWeight.w500),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, y - textPainter.height / 2));
    }

    const months = <String>['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
    final slot = chartWidth / months.length;
    final barWidth = math.min(11.0, slot * .26);

    for (var i = 0; i < months.length; i++) {
      final center = left + slot * i + slot / 2;
      final salesHeight = chartHeight * (sales[i] / 40);
      final purchaseHeight = chartHeight * (purchases[i] / 40);
      final radius = Radius.circular(math.min(3, barWidth / 2));

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(center - barWidth - 1.5, top + chartHeight - salesHeight, barWidth, salesHeight),
          radius,
        ),
        salesPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(center + 1.5, top + chartHeight - purchaseHeight, barWidth, purchaseHeight),
          radius,
        ),
        purchasePaint,
      );

      textPainter.text = TextSpan(
        text: months[i],
        style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 7.5, fontWeight: FontWeight.w500),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(center - textPainter.width / 2, top + chartHeight + 9));
    }
  }

  @override
  bool shouldRepaint(covariant _SalesTrendPainter oldDelegate) {
    return oldDelegate.sales != sales || oldDelegate.purchases != purchases;
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    var start = -math.pi / 2;
    const gap = .035;

    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * values[i];
      paint.color = colors[i];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start + gap / 2, sweep - gap, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => false;
}

class _KpiData {
  const _KpiData({
    required this.title,
    required this.value,
    required this.helper,
    required this.delta,
    required this.positive,
    required this.icon,
    required this.accent,
    required this.accentSoft,
  });

  final String title;
  final String value;
  final String helper;
  final String delta;
  final bool positive;
  final IconData icon;
  final Color accent;
  final Color accentSoft;
}

class _InventoryStatData {
  const _InventoryStatData(this.label, this.value, this.icon, this.color, this.background);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;
}

class _OutstandingParty {
  const _OutstandingParty(this.name, this.amount, this.days, this.share);

  final String name;
  final String amount;
  final int days;
  final double share;
}

class _SellingItem {
  const _SellingItem(this.name, this.amount, this.quantity, this.share);

  final String name;
  final String amount;
  final String quantity;
  final double share;
}

class _AlertData {
  const _AlertData(this.icon, this.title, this.helper, this.color, this.background);

  final IconData icon;
  final String title;
  final String helper;
  final Color color;
  final Color background;
}

class _TransactionData {
  const _TransactionData(this.date, this.voucher, this.type, this.party, this.amount);

  final String date;
  final String voucher;
  final String type;
  final String party;
  final String amount;
}
