import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report_models.dart';
import 'dynamic_report_formatter.dart';
import 'report_file_downloader.dart';

enum ReportExportFormat { pdf, excel }

class ReportExportService {
  const ReportExportService();

  Future<String> download({
    required ReportExportFormat format,
    required ReportDefinition definition,
    required String companyName,
    required List<Map<String, dynamic>> rows,
    required Map<String, dynamic> filters,
  }) async {
    final columns = definition.columns
        .where(
          (column) => column.isActive &&
              column.isVisible &&
              column.isExportable,
        )
        .toList(growable: false);
    if (columns.isEmpty) {
      throw const FormatException(
        'This report does not have any exportable columns.',
      );
    }

    final timestamp = DateTime.now();
    final baseName = _safeFileName(
      '${definition.code}_${_compactTimestamp(timestamp)}',
    );

    switch (format) {
      case ReportExportFormat.pdf:
        final fileName = '$baseName.pdf';
        final bytes = await _buildPdf(
          definition: definition,
          companyName: companyName,
          rows: rows,
          columns: columns,
          filters: filters,
          exportedOn: timestamp,
        );
        await downloadReportFile(
          fileName: fileName,
          mimeType: 'application/pdf',
          bytes: bytes,
        );
        return fileName;
      case ReportExportFormat.excel:
        final fileName = '$baseName.xls';
        final bytes = _buildExcelXml(
          definition: definition,
          companyName: companyName,
          rows: rows,
          columns: columns,
          filters: filters,
          exportedOn: timestamp,
        );
        await downloadReportFile(
          fileName: fileName,
          mimeType: 'application/vnd.ms-excel',
          bytes: bytes,
        );
        return fileName;
    }
  }

  Future<Uint8List> _buildPdf({
    required ReportDefinition definition,
    required String companyName,
    required List<Map<String, dynamic>> rows,
    required List<ReportColumn> columns,
    required Map<String, dynamic> filters,
    required DateTime exportedOn,
  }) async {
    final document = pw.Document();
    final landscape = columns.length > 5;
    final pageFormat = landscape
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4;
    final filterText = _filterSummary(definition, filters);
    final columnWidths = <int, pw.TableColumnWidth>{};
    for (var index = 0; index < columns.length; index++) {
      final width = (columns[index].width ?? 150).clamp(70, 280).toDouble();
      columnWidths[index] = pw.FlexColumnWidth(width);
    }

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        maxPages: 500,
        margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 28),
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 10),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(
              color: PdfColors.grey700,
              fontSize: 8,
            ),
          ),
        ),
        build: (context) => <pw.Widget>[
          pw.Text(
            _pdfSafe(definition.effectiveName),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _pdfSafe(companyName),
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
            ),
          ),
          pw.Text(
            'Exported ${_readableTimestamp(exportedOn)} | ${rows.length} rows',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
          if (filterText.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(7),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                _pdfSafe('Filters: $filterText'),
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: .45,
            ),
            columnWidths: columnWidths,
            children: <pw.TableRow>[
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                children: columns
                    .map(
                      (column) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 6,
                        ),
                        child: pw.Text(
                          _pdfSafe(column.displayName),
                          textAlign: _pdfAlignment(column),
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              ...rows.map(
                (row) => pw.TableRow(
                  children: columns
                      .map(
                        (column) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 5,
                          ),
                          child: pw.Text(
                            _pdfSafe(
                              DynamicReportFormatter.format(
                                row[column.name],
                                column,
                              ),
                            ),
                            textAlign: _pdfAlignment(column),
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  Uint8List _buildExcelXml({
    required ReportDefinition definition,
    required String companyName,
    required List<Map<String, dynamic>> rows,
    required List<ReportColumn> columns,
    required Map<String, dynamic> filters,
    required DateTime exportedOn,
  }) {
    final filterText = _filterSummary(definition, filters);
    final headerRow = filterText.isEmpty ? 5 : 6;
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<?mso-application progid="Excel.Sheet"?>')
      ..writeln(
        '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
        'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">',
      )
      ..writeln('<Styles>')
      ..writeln(
        '<Style ss:ID="Title"><Font ss:Bold="1" ss:Size="16"/>'
        '<Alignment ss:Vertical="Center"/></Style>',
      )
      ..writeln(
        '<Style ss:ID="Meta"><Font ss:Color="#667085" ss:Size="9"/></Style>',
      )
      ..writeln(
        '<Style ss:ID="Header"><Font ss:Bold="1" ss:Color="#FFFFFF"/>'
        '<Interior ss:Color="#175CD3" ss:Pattern="Solid"/>'
        '<Alignment ss:Vertical="Center" ss:WrapText="1"/>'
        '<Borders><Border ss:Position="Bottom" ss:LineStyle="Continuous" '
        'ss:Weight="1" ss:Color="#D0D5DD"/></Borders></Style>',
      )
      ..writeln(
        '<Style ss:ID="Cell"><Alignment ss:Vertical="Top" '
        'ss:WrapText="1"/><Borders><Border ss:Position="Bottom" '
        'ss:LineStyle="Continuous" ss:Weight="1" '
        'ss:Color="#EAECF0"/></Borders></Style>',
      )
      ..writeln('</Styles>')
      ..writeln(
        '<Worksheet ss:Name="${_xml(_worksheetName(definition.effectiveName))}">',
      )
      ..writeln('<Table>');

    for (final column in columns) {
      final width = (column.width ?? 150).clamp(70, 280).toDouble();
      buffer.writeln('<Column ss:AutoFitWidth="0" ss:Width="$width"/>');
    }

    final mergeAcross = columns.length - 1;
    buffer
      ..writeln(
        '<Row ss:Height="24"><Cell ss:StyleID="Title" '
        'ss:MergeAcross="$mergeAcross"><Data ss:Type="String">'
        '${_xml(definition.effectiveName)}</Data></Cell></Row>',
      )
      ..writeln(
        '<Row><Cell ss:StyleID="Meta" ss:MergeAcross="$mergeAcross">'
        '<Data ss:Type="String">${_xml(companyName)}</Data></Cell></Row>',
      )
      ..writeln(
        '<Row><Cell ss:StyleID="Meta" ss:MergeAcross="$mergeAcross">'
        '<Data ss:Type="String">${_xml('Exported ${_readableTimestamp(exportedOn)} | ${rows.length} rows')}'
        '</Data></Cell></Row>',
      );

    if (filterText.isNotEmpty) {
      buffer.writeln(
        '<Row><Cell ss:StyleID="Meta" ss:MergeAcross="$mergeAcross">'
        '<Data ss:Type="String">${_xml('Filters: $filterText')}'
        '</Data></Cell></Row>',
      );
    }

    buffer
      ..writeln('<Row/>')
      ..writeln('<Row ss:Height="22">');
    for (final column in columns) {
      buffer.writeln(
        '<Cell ss:StyleID="Header"><Data ss:Type="String">'
        '${_xml(column.displayName)}</Data></Cell>',
      );
    }
    buffer.writeln('</Row>');

    for (final row in rows) {
      buffer.writeln('<Row>');
      for (final column in columns) {
        final value = DynamicReportFormatter.format(
          row[column.name],
          column,
        );
        buffer.writeln(
          '<Cell ss:StyleID="Cell"><Data ss:Type="String">'
          '${_xml(value)}</Data></Cell>',
        );
      }
      buffer.writeln('</Row>');
    }

    buffer
      ..writeln('</Table>')
      ..writeln(
        '<WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">'
        '<FreezePanes/><FrozenNoSplit/>'
        '<SplitHorizontal>$headerRow</SplitHorizontal>'
        '<TopRowBottomPane>$headerRow</TopRowBottomPane></WorksheetOptions>',
      )
      ..writeln('</Worksheet>')
      ..writeln('</Workbook>');

    return Uint8List.fromList(
      <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())],
    );
  }

  String _filterSummary(
    ReportDefinition definition,
    Map<String, dynamic> filters,
  ) {
    final labels = <String, String>{
      for (final parameter in definition.parameters)
        parameter.name: parameter.displayName,
    };
    return filters.entries
        .where((entry) => !_isBlank(entry.value))
        .map(
          (entry) => '${labels[entry.key] ?? entry.key}: ${_filterValue(entry.value)}',
        )
        .join(' | ');
  }

  bool _isBlank(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable) return value.isEmpty;
    return false;
  }

  String _filterValue(Object? value) {
    if (value is Iterable) return value.join(', ');
    if (value is Map) return jsonEncode(value);
    return value?.toString() ?? '';
  }

  pw.TextAlign _pdfAlignment(ReportColumn column) {
    return switch (column.alignment) {
      'RIGHT' => pw.TextAlign.right,
      'CENTER' => pw.TextAlign.center,
      _ => pw.TextAlign.left,
    };
  }

  String _worksheetName(String source) {
    final value = source.replaceAll(RegExp(r'[\\/:*?\[\]]'), ' ').trim();
    if (value.isEmpty) return 'Report';
    return value.length <= 31 ? value : value.substring(0, 31);
  }

  String _safeFileName(String source) {
    final value = source
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return value.isEmpty ? 'cmx_report' : value;
  }

  String _compactTimestamp(DateTime value) {
    return '${value.year}${_two(value.month)}${_two(value.day)}_'
        '${_two(value.hour)}${_two(value.minute)}${_two(value.second)}';
  }

  String _readableTimestamp(DateTime value) {
    return '${_two(value.day)}-${_two(value.month)}-${value.year} '
        '${_two(value.hour)}:${_two(value.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  String _xml(String value) => value
      .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

  String _pdfSafe(String value) => value.replaceAll('₹', 'INR ');
}
