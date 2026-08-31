import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/report_models.dart';

class ReportCatalogPanel extends StatefulWidget {
  const ReportCatalogPanel({
    super.key,
    required this.reports,
    required this.selectedReportId,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSelected,
  });

  final List<ReportCatalogItem> reports;
  final int? selectedReportId;
  final bool loading;
  final String error;
  final VoidCallback onRetry;
  final ValueChanged<ReportCatalogItem> onSelected;

  @override
  State<ReportCatalogPanel> createState() => _ReportCatalogPanelState();
}

class _ReportCatalogPanelState extends State<ReportCatalogPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ReportCatalogItem> get _filtered => _filterReports(
        widget.reports,
        _search,
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Report catalog',
                        style: TextStyle(
                          color: Color(0xFF101828),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Choose a report to run',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${widget.reports.length}',
                    style: const TextStyle(
                      color: Color(0xFF175CD3),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _searchController,
              enabled: !widget.loading && widget.reports.isNotEmpty,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search reports…',
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 17),
                      ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildContent()),
          if (widget.loading) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.loading && widget.reports.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error.isNotEmpty && widget.reports.isEmpty) {
      return _CatalogMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load reports',
        message: widget.error,
        actionLabel: 'Retry',
        onAction: widget.onRetry,
      );
    }

    if (widget.reports.isEmpty) {
      return const _CatalogMessage(
        icon: Icons.assignment_outlined,
        title: 'No reports assigned',
        message: 'No active reports are available for this company and user.',
      );
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return const _CatalogMessage(
        icon: Icons.search_off_rounded,
        title: 'No matching reports',
        message: 'Try a different report name, type or code.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final report = filtered[index];
        final selected = report.id == widget.selectedReportId;
        return Material(
          color: selected ? const Color(0xFFEFF4FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.loading ? null : () => widget.onSelected(report),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFD1E0FF)
                          : const Color(0xFFF2F4F7),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      _reportIcon(report.type),
                      size: 18,
                      color: selected
                          ? const Color(0xFF175CD3)
                          : const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.effectiveName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFF1849A9)
                                : const Color(0xFF344054),
                            fontSize: 12,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          report.subtype.trim().isEmpty
                              ? report.type
                              : '${report.type} · ${report.subtype}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF98A2B3),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: selected
                        ? const Color(0xFF175CD3)
                        : const Color(0xFFD0D5DD),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<ReportCatalogItem?> showReportPickerDialog(
  BuildContext context, {
  required List<ReportCatalogItem> reports,
  required int? selectedReportId,
}) {
  return showDialog<ReportCatalogItem>(
    context: context,
    builder: (context) => _ReportPickerDialog(
      reports: reports,
      selectedReportId: selectedReportId,
    ),
  );
}

class _ReportPickerDialog extends StatefulWidget {
  const _ReportPickerDialog({
    required this.reports,
    required this.selectedReportId,
  });

  final List<ReportCatalogItem> reports;
  final int? selectedReportId;

  @override
  State<_ReportPickerDialog> createState() => _ReportPickerDialogState();
}

class _ReportPickerDialogState extends State<_ReportPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final reports = _filterReports(widget.reports, _search);
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: const Text(
        'Select report',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: math.max(240.0, math.min(620.0, size.width - 64)),
        height: math.max(260.0, math.min(560.0, size.height - 190)),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Search by report name, type or code…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: reports.isEmpty
                  ? const Center(child: Text('No matching reports found.'))
                  : ListView.separated(
                      itemCount: reports.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        final selected = report.id == widget.selectedReportId;
                        return ListTile(
                          leading: Icon(
                            _reportIcon(report.type),
                            color: selected
                                ? const Color(0xFF175CD3)
                                : const Color(0xFF667085),
                          ),
                          title: Text(
                            report.effectiveName,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            report.subtype.isEmpty
                                ? report.code
                                : '${report.subtype} · ${report.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF175CD3),
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(report),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: const Color(0xFF98A2B3)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF344054),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 11),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<ReportCatalogItem> _filterReports(
  List<ReportCatalogItem> reports,
  String search,
) {
  final normalized = search.trim().toLowerCase();
  if (normalized.isEmpty) return reports;
  return reports.where((report) {
    return report.effectiveName.toLowerCase().contains(normalized) ||
        report.name.toLowerCase().contains(normalized) ||
        report.code.toLowerCase().contains(normalized) ||
        report.type.toLowerCase().contains(normalized) ||
        report.subtype.toLowerCase().contains(normalized);
  }).toList(growable: false);
}

IconData _reportIcon(String type) {
  return switch (type.toUpperCase()) {
    'CHART' => Icons.bar_chart_rounded,
    'SUMMARY' => Icons.analytics_outlined,
    'MASTER_DETAIL' => Icons.account_tree_outlined,
    'DOCUMENT' => Icons.description_outlined,
    _ => Icons.table_chart_outlined,
  };
}
