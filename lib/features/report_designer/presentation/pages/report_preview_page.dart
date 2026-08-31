import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/report_models.dart';
import '../../services/report_pdf_service.dart';
import '../widgets/report_canvas_preview.dart';

class ReportPreviewPage extends StatefulWidget {
  const ReportPreviewPage({
    super.key,
    required this.reportTitle,
    required this.elements,
    required this.rows,
    required this.landscape,
  });

  final String reportTitle;
  final List<ReportElement> elements;
  final List<Map<String, Object>> rows;
  final bool landscape;

  @override
  State<ReportPreviewPage> createState() => _ReportPreviewPageState();
}

class _ReportPreviewPageState extends State<ReportPreviewPage> {
  static const _pdfService = ReportPdfService();
  bool _downloading = false;

  Future<void> _downloadPdf() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await _pdfService.buildPdf(
        reportTitle: widget.reportTitle,
        elements: widget.elements,
        rows: widget.rows,
        landscape: widget.landscape,
      );
      final filename = '${_safeName(widget.reportTitle)}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _showPdfPreview() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('${widget.reportTitle} - PDF')),
          body: PdfPreview(
            build: (_) => _pdfService.buildPdf(
              reportTitle: widget.reportTitle,
              elements: widget.elements,
              rows: widget.rows,
              landscape: widget.landscape,
            ),
          ),
        ),
      ),
    );
  }

  String _safeName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return safe.isEmpty ? 'cmx_report' : safe.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Preview'),
        actions: [
          TextButton.icon(
            onPressed: _showPdfPreview,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('View PDF'),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _downloading ? null : _downloadPdf,
              icon: _downloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('Download PDF'),
            ),
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF2F4F7),
        padding: const EdgeInsets.all(18),
        child: Center(
          child: SingleChildScrollView(
            child: ReportCanvasPreview(
              title: widget.reportTitle,
              elements: widget.elements,
              rows: widget.rows,
              landscape: widget.landscape,
            ),
          ),
        ),
      ),
    );
  }
}
