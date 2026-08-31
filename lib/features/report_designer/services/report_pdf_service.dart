import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report_models.dart';
import 'report_value_formatter.dart';

class ReportPdfService {
  const ReportPdfService();

  Future<Uint8List> buildPdf({
    required String reportTitle,
    required List<ReportElement> elements,
    required List<Map<String, Object>> rows,
    required bool landscape,
  }) async {
    final document = pw.Document();
    final pageFormat = landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    final header = elements.where((e) => e.zone == ReportZone.header).toList();
    final detail = elements.where((e) => e.zone == ReportZone.detail).toList();
    final footer = elements.where((e) => e.zone == ReportZone.footer).toList();
    final firstRow = rows.isEmpty ? const <String, Object>{} : rows.first;

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.Text(
            reportTitle,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          if (header.isNotEmpty) _headerBlock(header, firstRow),
          if (header.isNotEmpty) pw.SizedBox(height: 16),
          if (detail.isNotEmpty) _detailTable(detail, rows),
          if (footer.isNotEmpty) pw.SizedBox(height: 16),
          if (footer.isNotEmpty) _footerBlock(footer, firstRow, rows),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _headerBlock(
    List<ReportElement> elements,
    Map<String, Object> row,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.7),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Wrap(
        spacing: 18,
        runSpacing: 10,
        children: elements.map((element) {
          final value = _resolveValue(element, row, const []);
          return pw.Container(
            width: 230,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  element.label,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  value,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: element.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  pw.Widget _detailTable(
    List<ReportElement> elements,
    List<Map<String, Object>> rows,
  ) {
    final widths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < elements.length; i++) {
      widths[i] = pw.FlexColumnWidth(elements[i].width.clamp(60.0, 260.0).toDouble());
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: widths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: elements
              .map(
                (element) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
                  child: pw.Text(
                    element.label,
                    textAlign: _textAlign(element.alignment),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: elements
                .map(
                  (element) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(
                      _resolveValue(element, row, rows),
                      textAlign: _textAlign(element.alignment),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: element.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _footerBlock(
    List<ReportElement> elements,
    Map<String, Object> firstRow,
    List<Map<String, Object>> rows,
  ) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 280,
        child: pw.Column(
          children: elements.map((element) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      element.label,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: element.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                      ),
                    ),
                  ),
                  pw.Text(
                    _resolveValue(element, firstRow, rows, aggregate: true),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: element.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _resolveValue(
    ReportElement element,
    Map<String, Object> row,
    List<Map<String, Object>> rows, {
    bool aggregate = false,
  }) {
    Object? value = row[element.fieldKey];

    if (aggregate && rows.isNotEmpty && _isNumeric(element.type)) {
      final values = rows
          .map((item) => item[element.fieldKey])
          .whereType<num>()
          .map((number) => number.toDouble())
          .toList();
      if (values.isNotEmpty) {
        value = values.fold<double>(0, (sum, item) => sum + item);
      }
    }

    return ReportValueFormatter.format(value, element.type);
  }

  bool _isNumeric(ReportFieldType type) {
    return type == ReportFieldType.currency ||
        type == ReportFieldType.number ||
        type == ReportFieldType.percentage;
  }

  pw.TextAlign _textAlign(ReportAlignment alignment) {
    switch (alignment) {
      case ReportAlignment.left:
        return pw.TextAlign.left;
      case ReportAlignment.center:
        return pw.TextAlign.center;
      case ReportAlignment.right:
        return pw.TextAlign.right;
    }
  }
}
