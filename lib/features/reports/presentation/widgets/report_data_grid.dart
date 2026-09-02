import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../../services/dynamic_report_formatter.dart';

class ReportDataGrid extends StatefulWidget {
  const ReportDataGrid({
    super.key,
    required this.definition,
    required this.result,
    required this.loading,
    required this.exporting,
    required this.sort,
    required this.onSort,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    required this.onRefresh,
    required this.onCopyPage,
    required this.onDownloadPdf,
    required this.onDownloadExcel,
  });

  final ReportDefinition definition;
  final ReportResult result;
  final bool loading;
  final bool exporting;
  final List<ReportSort> sort;
  final ValueChanged<ReportColumn> onSort;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCopyPage;
  final VoidCallback onDownloadPdf;
  final VoidCallback onDownloadExcel;

  @override
  State<ReportDataGrid> createState() => _ReportDataGridState();
}

class _ReportDataGridState extends State<ReportDataGrid> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  List<ReportColumn> get _columns {
    final source = widget.result.columns.isEmpty
        ? widget.definition.columns
        : widget.result.columns;
    return source
        .where((item) => item.isActive && item.isVisible)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final columns = _columns;
    final page = widget.result.page;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GridHeader(
            result: widget.result,
            loading: widget.loading,
            canCopy: widget.definition.canExport &&
                widget.result.rows.isNotEmpty,
            canExport: widget.definition.canExport &&
                widget.result.rows.isNotEmpty,
            exporting: widget.exporting,
            onRefresh: widget.onRefresh,
            onCopyPage: widget.onCopyPage,
            onDownloadPdf: widget.onDownloadPdf,
            onDownloadExcel: widget.onDownloadExcel,
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                if (columns.isEmpty)
                  const _GridMessage(
                    icon: Icons.view_column_outlined,
                    title: 'No visible columns',
                    message: 'This report does not have any visible columns.',
                  )
                else if (widget.result.rows.isEmpty)
                  const _GridMessage(
                    icon: Icons.inbox_outlined,
                    title: 'No data found',
                    message: 'Try changing the report filters and run it again.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final preferredWidth = columns.fold<double>(0, (
                        total,
                        column,
                      ) {
                        return total +
                            (column.width ?? 160).clamp(90, 340).toDouble();
                      });
                      return Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        notificationPredicate: (notification) =>
                            notification.metrics.axis == Axis.vertical,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          child: Scrollbar(
                            controller: _horizontalController,
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              controller: _horizontalController,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: math.max(
                                    constraints.maxWidth,
                                    preferredWidth,
                                  ),
                                ),
                                child: _buildTable(columns),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                if (widget.loading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          _PaginationBar(
            page: page,
            maxPageSize: widget.definition.maxPageSize,
            loading: widget.loading,
            onPageChanged: widget.onPageChanged,
            onPageSizeChanged: widget.onPageSizeChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<ReportColumn> columns) {
    final firstSort = widget.sort.isEmpty ? null : widget.sort.first;
    final sortIndex = firstSort == null
        ? null
        : columns.indexWhere((item) => item.name == firstSort.columnName);

    return DataTable(
      showCheckboxColumn: false,
      headingRowHeight: 40,
      dataRowMinHeight: 36,
      dataRowMaxHeight: 40,
      horizontalMargin: 12,
      columnSpacing: 18,
      dividerThickness: .6,
      headingRowColor: WidgetStateProperty.all(const Color(0xFFF2F4F7)),
      sortColumnIndex: sortIndex != null && sortIndex >= 0 ? sortIndex : null,
      sortAscending: firstSort?.ascending ?? true,
      columns: columns
          .map(
            (column) => DataColumn(
              numeric: column.alignment == 'RIGHT',
              onSort: column.isSortable
                  ? (_, __) => widget.onSort(column)
                  : null,
              label: Tooltip(
                message: column.isSortable
                    ? 'Sort by ${column.displayName}'
                    : column.displayName,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (column.width ?? 180).clamp(90, 320).toDouble(),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          column.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF344054),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (column.isTotal) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.functions_rounded,
                          size: 13,
                          color: Color(0xFF98A2B3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
      rows: widget.result.rows.asMap().entries.map((entry) {
        final rowIndex = entry.key;
        final row = entry.value;
        return DataRow(
          color: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFFEFF8FF);
            }
            return rowIndex.isEven ? Colors.white : const Color(0xFFFCFCFD);
          }),
          cells: columns.map((column) {
            final text = DynamicReportFormatter.format(
              row[column.name],
              column,
            );
            return DataCell(
              Align(
                alignment: switch (column.alignment) {
                  'RIGHT' => Alignment.centerRight,
                  'CENTER' => Alignment.center,
                  _ => Alignment.centerLeft,
                },
                child: Tooltip(
                  message: text,
                  waitDuration: const Duration(milliseconds: 600),
                  child: Text(
                    text.isEmpty ? '—' : text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: text.isEmpty
                          ? const Color(0xFF98A2B3)
                          : const Color(0xFF344054),
                      fontSize: 12,
                      fontWeight: column.isTotal
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        );
      }).toList(growable: false),
    );
  }
}

class _GridHeader extends StatelessWidget {
  const _GridHeader({
    required this.result,
    required this.loading,
    required this.canCopy,
    required this.canExport,
    required this.exporting,
    required this.onRefresh,
    required this.onCopyPage,
    required this.onDownloadPdf,
    required this.onDownloadExcel,
  });

  final ReportResult result;
  final bool loading;
  final bool canCopy;
  final bool canExport;
  final bool exporting;
  final VoidCallback onRefresh;
  final VoidCallback onCopyPage;
  final VoidCallback onDownloadPdf;
  final VoidCallback onDownloadExcel;

  @override
  Widget build(BuildContext context) {
    final page = result.page;
    final firstRow = page.rowCount == 0
        ? 0
        : ((page.pageNo - 1) * page.pageSize) + 1;
    final lastRow = page.rowCount == 0 ? 0 : firstRow + page.rowCount - 1;
    final range = page.totalCount == null
        ? '${page.rowCount} rows on page ${page.pageNo}'
        : '$firstRow–$lastRow of ${_groupDigits(page.totalCount!)} rows';
    final execution = result.executionId > 0
        ? ' · execution #${result.executionId}'
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showDirectDownloads = constraints.maxWidth >= 760;
          final stackActions = constraints.maxWidth < 520;
          final title = Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.table_rows_outlined,
                  color: Color(0xFF027A48),
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report results',
                      style: TextStyle(
                        color: Color(0xFF101828),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$range$execution',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canCopy)
                IconButton(
                  tooltip: 'Copy current page as CSV',
                  visualDensity: VisualDensity.compact,
                  onPressed: loading ? null : onCopyPage,
                  icon: const Icon(Icons.content_copy_rounded, size: 18),
                ),
              if (canExport && showDirectDownloads) ...[
                _downloadButton(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  color: const Color(0xFFD92D20),
                  onPressed: loading ? null : onDownloadPdf,
                ),
                const SizedBox(width: 6),
                _downloadButton(
                  label: 'Excel',
                  icon: Icons.table_view_outlined,
                  color: const Color(0xFF027A48),
                  onPressed: loading ? null : onDownloadExcel,
                ),
              ] else if (canExport)
                _downloadMenu(),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Refresh report',
                visualDensity: VisualDensity.compact,
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 19),
              ),
            ],
          );

          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 5),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 10),
              if (exporting) ...[
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 7),
              ],
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _downloadButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: onPressed == null ? null : color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _downloadMenu() {
    return PopupMenuButton<_GridExportAction>(
      tooltip: 'Download report',
      enabled: !loading,
      onSelected: (action) {
        switch (action) {
          case _GridExportAction.pdf:
            onDownloadPdf();
            return;
          case _GridExportAction.excel:
            onDownloadExcel();
            return;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<_GridExportAction>(
          value: _GridExportAction.pdf,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.picture_as_pdf_outlined,
              color: Color(0xFFD92D20),
            ),
            title: Text('Download PDF'),
            subtitle: Text('Up to 5,000 rows'),
          ),
        ),
        PopupMenuItem<_GridExportAction>(
          value: _GridExportAction.excel,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.table_view_outlined,
              color: Color(0xFF039855),
            ),
            title: Text('Download Excel'),
            subtitle: Text('Up to 25,000 rows'),
          ),
        ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: exporting
              ? const Color(0xFFF2F4F7)
              : const Color(0xFFEFF4FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1E0FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exporting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.download_rounded,
                size: 16,
                color: Color(0xFF175CD3),
              ),
            const SizedBox(width: 5),
            Text(
              exporting ? 'Preparing…' : 'Download',
              style: const TextStyle(
                color: Color(0xFF175CD3),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _GridExportAction { pdf, excel }

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.maxPageSize,
    required this.loading,
    required this.onPageChanged,
    required this.onPageSizeChanged,
  });

  final ReportPageInfo page;
  final int maxPageSize;
  final bool loading;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    final sizes = <int>{25, 50, 100, 250, 500, page.pageSize}
        .where((value) => value > 0 && value <= maxPageSize)
        .toList(growable: true)
      ..sort();
    final hasPrevious = page.pageNo > 1;
    final hasNext = page.totalPages != null
        ? page.pageNo < page.totalPages!
        : page.hasMore;
    final totalText = page.totalCount == null
        ? '${page.rowCount} rows'
        : '${_groupDigits(page.totalCount!)} total rows';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            totalText,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rows:',
                style: TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
              const SizedBox(width: 6),
              DropdownButton<int>(
                value: page.pageSize,
                underline: const SizedBox.shrink(),
                isDense: true,
                items: sizes
                    .map(
                      (size) => DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) onPageSizeChanged(value);
                      },
              ),
              const SizedBox(width: 14),
              Text(
                page.totalPages == null
                    ? 'Page ${page.pageNo}'
                    : 'Page ${page.pageNo} of ${page.totalPages}',
                style: const TextStyle(
                  color: Color(0xFF344054),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Previous page',
                visualDensity: VisualDensity.compact,
                onPressed: loading || !hasPrevious
                    ? null
                    : () => onPageChanged(page.pageNo - 1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next page',
                visualDensity: VisualDensity.compact,
                onPressed: loading || !hasNext
                    ? null
                    : () => onPageChanged(page.pageNo + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridMessage extends StatelessWidget {
  const _GridMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF667085), size: 27),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF101828),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

String _groupDigits(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;
    buffer.write(digits[index]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}
