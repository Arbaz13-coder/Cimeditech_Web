import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../data/mock_report_data.dart';
import '../../models/report_models.dart';
import '../../services/report_pdf_service.dart';
import '../widgets/report_canvas_preview.dart';
import 'report_preview_page.dart';

class ReportDesignerPage extends StatefulWidget {
  const ReportDesignerPage({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<ReportDesignerPage> createState() => _ReportDesignerPageState();
}

class _ReportDesignerPageState extends State<ReportDesignerPage> {
  static const _pdfService = ReportPdfService();

  late String _selectedTemplateId;
  late String _reportTitle;
  late bool _landscape;
  late List<ReportElement> _elements;
  String? _selectedElementId;
  int _customId = 1000;
  String _fieldSearch = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _applyTemplate(MockReportData.templates.first, notify: false);
  }

  List<ReportElement> _zoneElements(ReportZone zone) =>
      _elements.where((element) => element.zone == zone).toList();

  ReportElement? get _selectedElement {
    final id = _selectedElementId;
    if (id == null) return null;
    for (final element in _elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  void _applyTemplate(ReportTemplate template, {bool notify = true}) {
    void assign() {
      _selectedTemplateId = template.id;
      _reportTitle = template.reportTitle;
      _landscape = template.landscape;
      _elements = template.elements.map((element) => element.copyWith()).toList();
      _selectedElementId = null;
    }

    if (notify) {
      setState(assign);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${template.name} design loaded.')),
      );
    } else {
      assign();
    }
  }

  void _addField(BackendField field, ReportZone zone) {
    final element = ReportElement(
      id: 'custom_${_customId++}',
      fieldKey: field.key,
      label: field.label,
      zone: zone,
      width: zone == ReportZone.detail ? 120 : 160,
      alignment: _defaultAlignment(field.type),
      type: field.type,
    );
    setState(() {
      _elements = [..._elements, element];
      _selectedElementId = element.id;
    });
  }

  ReportAlignment _defaultAlignment(ReportFieldType type) {
    switch (type) {
      case ReportFieldType.number:
      case ReportFieldType.currency:
      case ReportFieldType.percentage:
        return ReportAlignment.right;
      case ReportFieldType.date:
      case ReportFieldType.text:
        return ReportAlignment.left;
    }
  }

  void _updateElement(ReportElement updated) {
    setState(() {
      _elements = _elements
          .map((element) => element.id == updated.id ? updated : element)
          .toList();
    });
  }

  void _removeSelected() {
    final selected = _selectedElement;
    if (selected == null) return;
    setState(() {
      _elements = _elements.where((element) => element.id != selected.id).toList();
      _selectedElementId = null;
    });
  }

  void _reorderZone(ReportZone zone, int oldIndex, int newIndex) {
    final items = _zoneElements(zone);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    setState(() {
      _elements = [
        ...(zone == ReportZone.header ? items : _zoneElements(ReportZone.header)),
        ...(zone == ReportZone.detail ? items : _zoneElements(ReportZone.detail)),
        ...(zone == ReportZone.footer ? items : _zoneElements(ReportZone.footer)),
      ];
    });
  }

  Future<void> _openPreview() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportPreviewPage(
          reportTitle: _reportTitle.trim().isEmpty ? 'Untitled Report' : _reportTitle.trim(),
          elements: List<ReportElement>.unmodifiable(_elements),
          rows: MockReportData.sampleRows,
          landscape: _landscape,
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final title = _reportTitle.trim().isEmpty ? 'Untitled Report' : _reportTitle.trim();
      final bytes = await _pdfService.buildPdf(
        reportTitle: title,
        elements: _elements,
        rows: MockReportData.sampleRows,
        landscape: _landscape,
      );
      final filename = '${_safeName(title)}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not export PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _safeName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    return safe.isEmpty ? 'cmx_report' : safe.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final body = LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            _DesignerToolbar(
              templates: MockReportData.templates,
              selectedTemplateId: _selectedTemplateId,
              reportTitle: _reportTitle,
              landscape: _landscape,
              onTemplateSelected: _applyTemplate,
              onReportTitleChanged: (value) => setState(() => _reportTitle = value),
              onOrientationChanged: (value) => setState(() => _landscape = value),
              onPreview: _openPreview,
              onDownload: _downloadPdf,
              exporting: _exporting,
            ),
            const Divider(height: 1),
            Expanded(
              child: constraints.maxWidth >= 1180
                  ? _wideLayout()
                  : _compactLayout(),
            ),
          ],
        );
      },
    );

    if (widget.embedded) {
      return ColoredBox(
        color: const Color(0xFFF6F8FB),
        child: body,
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report Designer'),
            Text(
              'Frontend prototype · hardcoded data fields',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Preview report',
            onPressed: _openPreview,
            icon: const Icon(Icons.visibility_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: _exporting ? null : _downloadPdf,
              icon: _exporting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
              label: const Text('PDF'),
            ),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _wideLayout() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 280,
            child: SingleChildScrollView(
              child: _FieldPalette(
                fields: MockReportData.backendFields,
                search: _fieldSearch,
                onSearchChanged: (value) => setState(() => _fieldSearch = value),
                onAdd: _addField,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _designerCenter()),
          const SizedBox(width: 12),
          SizedBox(
            width: 310,
            child: SingleChildScrollView(
              child: _PropertiesPanel(
                selected: _selectedElement,
                backendFields: MockReportData.backendFields,
                onChanged: _updateElement,
                onRemove: _removeSelected,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _FieldPalette(
            fields: MockReportData.backendFields,
            search: _fieldSearch,
            onSearchChanged: (value) => setState(() => _fieldSearch = value),
            onAdd: _addField,
          ),
          const SizedBox(height: 12),
          _designerCenter(scrollable: false),
          const SizedBox(height: 12),
          _PropertiesPanel(
            selected: _selectedElement,
            backendFields: MockReportData.backendFields,
            onChanged: _updateElement,
            onRemove: _removeSelected,
          ),
        ],
      ),
    );
  }

  Widget _designerCenter({bool scrollable = true}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: 'Design Surface',
          subtitle: 'Drag a backend field from the left panel into a section. Reorder mapped fields inside each section.',
          child: Column(
            children: [
              _ZoneEditor(
                zone: ReportZone.header,
                title: 'Header / Report Information',
                icon: Icons.view_headline_outlined,
                elements: _zoneElements(ReportZone.header),
                selectedId: _selectedElementId,
                onBackendFieldDropped: (field) => _addField(field, ReportZone.header),
                onSelected: (element) => setState(() => _selectedElementId = element.id),
                onReorder: (oldIndex, newIndex) => _reorderZone(ReportZone.header, oldIndex, newIndex),
              ),
              const SizedBox(height: 10),
              _ZoneEditor(
                zone: ReportZone.detail,
                title: 'Detail Columns',
                icon: Icons.table_chart_outlined,
                elements: _zoneElements(ReportZone.detail),
                selectedId: _selectedElementId,
                onBackendFieldDropped: (field) => _addField(field, ReportZone.detail),
                onSelected: (element) => setState(() => _selectedElementId = element.id),
                onReorder: (oldIndex, newIndex) => _reorderZone(ReportZone.detail, oldIndex, newIndex),
              ),
              const SizedBox(height: 10),
              _ZoneEditor(
                zone: ReportZone.footer,
                title: 'Footer / Summary',
                icon: Icons.functions_outlined,
                elements: _zoneElements(ReportZone.footer),
                selectedId: _selectedElementId,
                onBackendFieldDropped: (field) => _addField(field, ReportZone.footer),
                onSelected: (element) => setState(() => _selectedElementId = element.id),
                onReorder: (oldIndex, newIndex) => _reorderZone(ReportZone.footer, oldIndex, newIndex),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Live Report Preview',
          subtitle: 'Sample rows are hardcoded for now. API data can replace them later without changing the report layout model.',
          trailing: OutlinedButton.icon(
            onPressed: _openPreview,
            icon: const Icon(Icons.open_in_full, size: 18),
            label: const Text('Full Preview'),
          ),
          child: Container(
            color: const Color(0xFFF2F4F7),
            padding: const EdgeInsets.all(12),
            child: ReportCanvasPreview(
              title: _reportTitle.trim().isEmpty ? 'Untitled Report' : _reportTitle.trim(),
              elements: _elements,
              rows: MockReportData.sampleRows,
              landscape: _landscape,
            ),
          ),
        ),
      ],
    );

    if (!scrollable) return content;
    return SingleChildScrollView(child: content);
  }
}

class _DesignerToolbar extends StatelessWidget {
  const _DesignerToolbar({
    required this.templates,
    required this.selectedTemplateId,
    required this.reportTitle,
    required this.landscape,
    required this.onTemplateSelected,
    required this.onReportTitleChanged,
    required this.onOrientationChanged,
    required this.onPreview,
    required this.onDownload,
    required this.exporting,
  });

  final List<ReportTemplate> templates;
  final String selectedTemplateId;
  final String reportTitle;
  final bool landscape;
  final ValueChanged<ReportTemplate> onTemplateSelected;
  final ValueChanged<String> onReportTitleChanged;
  final ValueChanged<bool> onOrientationChanged;
  final VoidCallback onPreview;
  final VoidCallback onDownload;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    final selectedTemplate = templates.firstWhere(
      (template) => template.id == selectedTemplateId,
      orElse: () => templates.first,
    );

    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                value: selectedTemplateId,
                decoration: const InputDecoration(
                  labelText: 'Default design',
                  isDense: true,
                ),
                items: templates
                    .map(
                      (template) => DropdownMenuItem(
                        value: template.id,
                        child: Text(template.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  onTemplateSelected(templates.firstWhere((item) => item.id == id));
                },
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                selectedTemplate.description,
                style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
              ),
            ),
            SizedBox(
              width: 260,
              child: TextFormField(
                key: ValueKey(selectedTemplateId),
                initialValue: reportTitle,
                decoration: const InputDecoration(
                  labelText: 'Report title',
                  isDense: true,
                ),
                onChanged: onReportTitleChanged,
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.stay_current_portrait), label: Text('Portrait')),
                ButtonSegment(value: true, icon: Icon(Icons.stay_current_landscape), label: Text('Landscape')),
              ],
              selected: {landscape},
              onSelectionChanged: (selection) => onOrientationChanged(selection.first),
            ),
            OutlinedButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View'),
            ),
            FilledButton.icon(
              onPressed: exporting ? null : onDownload,
              icon: exporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Download PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldPalette extends StatelessWidget {
  const _FieldPalette({
    required this.fields,
    required this.search,
    required this.onSearchChanged,
    required this.onAdd,
  });

  final List<BackendField> fields;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final void Function(BackendField field, ReportZone zone) onAdd;

  @override
  Widget build(BuildContext context) {
    final query = search.trim().toLowerCase();
    final filtered = fields.where((field) {
      if (query.isEmpty) return true;
      return field.label.toLowerCase().contains(query) ||
          field.key.toLowerCase().contains(query) ||
          field.group.toLowerCase().contains(query);
    }).toList();
    final groups = <String, List<BackendField>>{};
    for (final field in filtered) {
      groups.putIfAbsent(field.group, () => []).add(field);
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Search backend fields',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF8FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Drag the handle into a report section, or use + to bind the field.',
            style: TextStyle(fontSize: 12, color: Color(0xFF175CD3)),
          ),
        ),
        const SizedBox(height: 8),
        ...groups.entries.map(
          (entry) => ExpansionTile(
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: EdgeInsets.zero,
            title: Text(
              entry.key,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            children: entry.value.map((field) => _BackendFieldTile(field: field, onAdd: onAdd)).toList(),
          ),
        ),
      ],
    );

    return _SectionCard(
      title: 'Backend Fields',
      subtitle: '${filtered.length} hardcoded fields available',
      child: content,
    );
  }
}

class _BackendFieldTile extends StatelessWidget {
  const _BackendFieldTile({required this.field, required this.onAdd});

  final BackendField field;
  final void Function(BackendField field, ReportZone zone) onAdd;

  @override
  Widget build(BuildContext context) {
    final dragHandle = Draggable<BackendField>(
      data: field,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.data_object, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
      childWhenDragging: const Icon(Icons.drag_indicator, color: Color(0xFFD0D5DD)),
      child: const Tooltip(message: 'Drag field', child: Icon(Icons.drag_indicator, size: 20)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      child: Row(
        children: [
          dragHandle,
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(field.key, style: const TextStyle(fontSize: 10, color: Color(0xFF667085))),
              ],
            ),
          ),
          PopupMenuButton<ReportZone>(
            tooltip: 'Bind field',
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onSelected: (zone) => onAdd(field, zone),
            itemBuilder: (_) => const [
              PopupMenuItem(value: ReportZone.header, child: Text('Add to Header')),
              PopupMenuItem(value: ReportZone.detail, child: Text('Add to Detail')),
              PopupMenuItem(value: ReportZone.footer, child: Text('Add to Footer')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ZoneEditor extends StatelessWidget {
  const _ZoneEditor({
    required this.zone,
    required this.title,
    required this.icon,
    required this.elements,
    required this.selectedId,
    required this.onBackendFieldDropped,
    required this.onSelected,
    required this.onReorder,
  });

  final ReportZone zone;
  final String title;
  final IconData icon;
  final List<ReportElement> elements;
  final String? selectedId;
  final ValueChanged<BackendField> onBackendFieldDropped;
  final ValueChanged<ReportElement> onSelected;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return DragTarget<BackendField>(
      onWillAccept: (_) => true,
      onAccept: onBackendFieldDropped,
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFEFF8FF) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? const Color(0xFF2E90FA) : const Color(0xFFEAECF0),
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: const Color(0xFF475467)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  Text('${elements.length} field${elements.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
                ],
              ),
              const SizedBox(height: 8),
              if (elements.isEmpty)
                Container(
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD0D5DD)),
                  ),
                  child: Text(
                    active ? 'Drop field here' : 'Drag a backend field here',
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: elements.length,
                  onReorder: onReorder,
                  itemBuilder: (context, index) {
                    final element = elements[index];
                    final selected = element.id == selectedId;
                    return Container(
                      key: ValueKey(element.id),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFFEFF8FF) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? const Color(0xFF2E90FA) : const Color(0xFFE4E7EC)),
                      ),
                      child: ListTile(
                        dense: true,
                        onTap: () => onSelected(element),
                        leading: const Icon(Icons.link, size: 18),
                        title: Text(element.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        subtitle: Text('${element.fieldKey} · ${_fieldTypeName(element.type)}', style: const TextStyle(fontSize: 10)),
                        trailing: const Icon(Icons.drag_handle, size: 18),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PropertiesPanel extends StatelessWidget {
  const _PropertiesPanel({
    required this.selected,
    required this.backendFields,
    required this.onChanged,
    required this.onRemove,
  });

  final ReportElement? selected;
  final List<BackendField> backendFields;
  final ValueChanged<ReportElement> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final element = selected;
    if (element == null) {
      return const _SectionCard(
        title: 'Field Properties',
        subtitle: 'Select a mapped field to edit its binding and display settings.',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(Icons.tune, size: 42, color: Color(0xFF98A2B3)),
              SizedBox(height: 12),
              Text(
                'Nothing selected',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                'Click a field in Header, Detail or Footer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return _SectionCard(
      title: 'Field Properties',
      subtitle: 'Map and format ${element.label}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: element.fieldKey,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Backend field binding'),
            items: backendFields
                .map(
                  (field) => DropdownMenuItem(
                    value: field.key,
                    child: Text('${field.label}  ·  ${field.key}', overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (key) {
              if (key == null) return;
              final field = backendFields.firstWhere((item) => item.key == key);
              onChanged(element.copyWith(fieldKey: key, type: field.type));
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(element.id),
            initialValue: element.label,
            decoration: const InputDecoration(labelText: 'Display label'),
            onChanged: (value) => onChanged(element.copyWith(label: value)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReportZone>(
            value: element.zone,
            decoration: const InputDecoration(labelText: 'Report section'),
            items: const [
              DropdownMenuItem(value: ReportZone.header, child: Text('Header')),
              DropdownMenuItem(value: ReportZone.detail, child: Text('Detail Columns')),
              DropdownMenuItem(value: ReportZone.footer, child: Text('Footer / Summary')),
            ],
            onChanged: (zone) {
              if (zone != null) onChanged(element.copyWith(zone: zone));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReportFieldType>(
            value: element.type,
            decoration: const InputDecoration(labelText: 'Value format'),
            items: ReportFieldType.values
                .map((type) => DropdownMenuItem(value: type, child: Text(_fieldTypeName(type))))
                .toList(),
            onChanged: (type) {
              if (type != null) onChanged(element.copyWith(type: type));
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ReportAlignment>(
            value: element.alignment,
            decoration: const InputDecoration(labelText: 'Alignment'),
            items: const [
              DropdownMenuItem(value: ReportAlignment.left, child: Text('Left')),
              DropdownMenuItem(value: ReportAlignment.center, child: Text('Center')),
              DropdownMenuItem(value: ReportAlignment.right, child: Text('Right')),
            ],
            onChanged: (alignment) {
              if (alignment != null) onChanged(element.copyWith(alignment: alignment));
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('Column width', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${element.width.round()} px', style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
            ],
          ),
          Slider(
            value: element.width.clamp(60.0, 260.0).toDouble(),
            min: 60,
            max: 260,
            divisions: 20,
            onChanged: (width) => onChanged(element.copyWith(width: width)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bold value', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            value: element.bold,
            onChanged: (value) => onChanged(element.copyWith(bold: value)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove field'),
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF667085))),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _fieldTypeName(ReportFieldType type) {
  switch (type) {
    case ReportFieldType.text:
      return 'Text';
    case ReportFieldType.number:
      return 'Number';
    case ReportFieldType.currency:
      return 'Currency';
    case ReportFieldType.date:
      return 'Date';
    case ReportFieldType.percentage:
      return 'Percentage';
  }
}
