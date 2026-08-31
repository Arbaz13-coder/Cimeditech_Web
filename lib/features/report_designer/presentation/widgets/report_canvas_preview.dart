import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import '../../services/report_value_formatter.dart';

class ReportCanvasPreview extends StatelessWidget {
  const ReportCanvasPreview({
    super.key,
    required this.title,
    required this.elements,
    required this.rows,
    required this.landscape,
  });

  final String title;
  final List<ReportElement> elements;
  final List<Map<String, Object>> rows;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final header = elements.where((e) => e.zone == ReportZone.header).toList();
    final detail = elements.where((e) => e.zone == ReportZone.detail).toList();
    final footer = elements.where((e) => e.zone == ReportZone.footer).toList();
    final firstRow = rows.isEmpty ? const <String, Object>{} : rows.first;
    final pageWidth = landscape ? 980.0 : 720.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        width: pageWidth,
        constraints: const BoxConstraints(minHeight: 680),
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFFD0D5DD)),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              offset: Offset(0, 6),
              color: Color(0x14000000),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 18),
            if (header.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 28,
                  runSpacing: 14,
                  children: header
                      .map(
                        (element) => SizedBox(
                          width: 205,
                          child: _LabelValue(
                            label: element.label,
                            value: _value(element, firstRow),
                            bold: element.bold,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            if (header.isNotEmpty) const SizedBox(height: 18),
            if (detail.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Table(
                  border: TableBorder.all(color: const Color(0xFFE4E7EC)),
                  columnWidths: {
                    for (var i = 0; i < detail.length; i++)
                      i: FlexColumnWidth(detail[i].width.clamp(60.0, 260.0).toDouble()),
                  },
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF2F4F7)),
                      children: detail
                          .map(
                            (element) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
                              child: Text(
                                element.label,
                                textAlign: _textAlign(element.alignment),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ...rows.map(
                      (row) => TableRow(
                        children: detail
                            .map(
                              (element) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                                child: Text(
                                  _value(element, row),
                                  textAlign: _textAlign(element.alignment),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: element.bold ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            if (footer.isNotEmpty) const SizedBox(height: 18),
            if (footer.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 310,
                  child: Column(
                    children: footer
                        .map(
                          (element) => Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFE4E7EC))),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    element.label,
                                    style: TextStyle(
                                      fontWeight: element.bold ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  _aggregateValue(element),
                                  style: TextStyle(
                                    fontWeight: element.bold ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _value(ReportElement element, Map<String, Object> row) {
    return ReportValueFormatter.format(row[element.fieldKey], element.type);
  }

  String _aggregateValue(ReportElement element) {
    if (_numeric(element.type)) {
      final numbers = rows
          .map((row) => row[element.fieldKey])
          .whereType<num>()
          .map((value) => value.toDouble())
          .toList();
      if (numbers.isNotEmpty) {
        final total = numbers.fold<double>(0, (sum, item) => sum + item);
        return ReportValueFormatter.format(total, element.type);
      }
    }
    return rows.isEmpty ? '' : _value(element, rows.first);
  }

  bool _numeric(ReportFieldType type) =>
      type == ReportFieldType.number ||
      type == ReportFieldType.currency ||
      type == ReportFieldType.percentage;

  TextAlign _textAlign(ReportAlignment alignment) {
    switch (alignment) {
      case ReportAlignment.left:
        return TextAlign.left;
      case ReportAlignment.center:
        return TextAlign.center;
      case ReportAlignment.right:
        return TextAlign.right;
    }
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    required this.bold,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF667085),
              ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
        ),
      ],
    );
  }
}
