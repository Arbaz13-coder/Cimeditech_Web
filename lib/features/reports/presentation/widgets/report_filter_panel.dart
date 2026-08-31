import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/report_models.dart';
import 'report_lookup_field.dart';

typedef ReportFilterChanged = void Function(String name, Object? value);
typedef ReportParameterLookup = Future<List<ReportLookupOption>> Function(
  ReportParameter parameter,
  String search,
);

class ReportFilterPanel extends StatelessWidget {
  const ReportFilterPanel({
    super.key,
    required this.definition,
    required this.values,
    required this.errors,
    required this.loading,
    required this.onChanged,
    required this.onLookup,
    required this.onReset,
    required this.onRun,
  });

  final ReportDefinition definition;
  final Map<String, dynamic> values;
  final Map<String, String> errors;
  final bool loading;
  final ReportFilterChanged onChanged;
  final ReportParameterLookup onLookup;
  final VoidCallback onReset;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final parameters = definition.activeParameters;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.tune_rounded,
                        size: 18,
                        color: Color(0xFF175CD3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report filters',
                          style: TextStyle(
                            color: Color(0xFF101828),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          parameters.isEmpty
                              ? 'This report has no input parameters'
                              : '${parameters.length} parameter${parameters.length == 1 ? '' : 's'} configured',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: loading ? null : onReset,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Reset'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: loading ? null : onRun,
                      icon: loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 19),
                      label: Text(loading ? 'Running…' : 'Run report'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (parameters.isNotEmpty) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fieldWidth = _fieldWidth(constraints.maxWidth);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: parameters
                          .map(
                            (parameter) => SizedBox(
                              width: fieldWidth,
                              child: _buildField(context, parameter),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _fieldWidth(double available) {
    if (available < 560) return available;
    if (available < 980) return (available - 12) / 2;
    return math.max(250.0, (available - 24) / 3);
  }

  Widget _buildField(BuildContext context, ReportParameter parameter) {
    final value = values[parameter.name];
    final error = errors[parameter.name];
    final enabled = !loading;

    if (parameter.usesRemoteLookup) {
      return ReportLookupField(
        key: ValueKey('lookup-${definition.id}-${parameter.name}'),
        parameter: parameter,
        value: value,
        enabled: enabled,
        errorText: error,
        loader: (search) => onLookup(parameter, search),
        onChanged: (next) => onChanged(parameter.name, next),
      );
    }

    final localOptions = parameter.localOptions;
    if (localOptions.isNotEmpty &&
        (parameter.uiElementType == 'DROPDOWN' ||
            parameter.uiElementType == 'MULTISELECT')) {
      return ReportLookupField(
        key: ValueKey('local-${definition.id}-${parameter.name}'),
        parameter: parameter,
        value: value,
        enabled: enabled,
        errorText: error,
        loader: (search) async {
          final normalized = search.trim().toLowerCase();
          if (normalized.isEmpty) return localOptions;
          return localOptions
              .where((item) => item.label.toLowerCase().contains(normalized))
              .toList(growable: false);
        },
        onChanged: (next) => onChanged(parameter.name, next),
      );
    }

    if (parameter.isBoolean) {
      return _BooleanParameterField(
        parameter: parameter,
        value: value is bool ? value : false,
        enabled: enabled,
        errorText: error,
        onChanged: (next) => onChanged(parameter.name, next),
      );
    }

    if (parameter.uiElementType == 'DATE_RANGE' &&
        parameter.dataType == 'JSON') {
      return _DateRangeParameterField(
        parameter: parameter,
        value: value,
        enabled: enabled,
        errorText: error,
        onChanged: (next) => onChanged(parameter.name, next),
      );
    }

    if (parameter.isDate) {
      return _DateParameterField(
        parameter: parameter,
        value: value?.toString() ?? '',
        enabled: enabled,
        errorText: error,
        onChanged: (next) => onChanged(parameter.name, next),
      );
    }

    if (parameter.isDateTime) {
      return _DateTimeParameterField(
        parameter: parameter,
        value: value?.toString() ?? '',
        enabled: enabled,
        errorText: error,
        onChanged: (next) => onChanged(parameter.name, next),
      );
    }

    final rawValue = value is ReportLookupOption ? value.value : value;
    final textValue = parameter.dataType == 'JSON' &&
            rawValue != null &&
            rawValue is! String
        ? jsonEncode(rawValue)
        : rawValue?.toString() ?? '';
    return _TextParameterField(
      key: ValueKey('text-${definition.id}-${parameter.name}'),
      parameter: parameter,
      value: textValue,
      enabled: enabled,
      errorText: error,
      maxLines: parameter.uiElementType == 'TEXTAREA' ||
              parameter.dataType == 'JSON'
          ? 3
          : 1,
      keyboardType: parameter.isNumeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      onChanged: (next) => onChanged(parameter.name, next),
    );
  }
}

class _TextParameterField extends StatefulWidget {
  const _TextParameterField({
    super.key,
    required this.parameter,
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.maxLines,
    required this.keyboardType,
    required this.onChanged,
  });

  final ReportParameter parameter;
  final String value;
  final bool enabled;
  final String? errorText;
  final int maxLines;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  @override
  State<_TextParameterField> createState() => _TextParameterFieldState();
}

class _TextParameterFieldState extends State<_TextParameterField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TextParameterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && _controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      minLines: widget.maxLines == 1 ? 1 : 2,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.parameter.label,
        hintText: widget.parameter.hintText.isEmpty
            ? 'Enter ${widget.parameter.displayName.toLowerCase()}'
            : widget.parameter.hintText,
        errorText: widget.errorText,
      ),
    );
  }
}

class _BooleanParameterField extends StatelessWidget {
  const _BooleanParameterField({
    required this.parameter,
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final ReportParameter parameter;
  final bool value;
  final bool enabled;
  final String? errorText;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: parameter.label,
        errorText: errorText,
        enabled: enabled,
        contentPadding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: enabled ? (next) => onChanged(next ?? false) : null,
          ),
          Expanded(
            child: Text(
              value ? 'Yes' : 'No',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateParameterField extends StatelessWidget {
  const _DateParameterField({
    required this.parameter,
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final ReportParameter parameter;
  final String value;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final parsed = DateTime.tryParse(value);
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (selected != null) onChanged(_dateText(selected));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: parameter.label,
          hintText: 'Select date',
          errorText: errorText,
          enabled: enabled,
          suffixIcon: value.isNotEmpty && enabled
              ? IconButton(
                  tooltip: 'Clear date',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: value.isEmpty
            ? const SizedBox(height: 20)
            : Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _DateTimeParameterField extends StatelessWidget {
  const _DateTimeParameterField({
    required this.parameter,
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final ReportParameter parameter;
  final String value;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final parsed = DateTime.tryParse(value) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(1900),
      lastDate: DateTime(DateTime.now().year + 20, 12, 31),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(parsed),
    );
    if (time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    onChanged(selected.toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: parameter.label,
          hintText: 'Select date and time',
          errorText: errorText,
          enabled: enabled,
          suffixIcon: value.isNotEmpty && enabled
              ? IconButton(
                  tooltip: 'Clear date and time',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              : const Icon(Icons.event_outlined, size: 18),
        ),
        child: value.isEmpty
            ? const SizedBox(height: 20)
            : Text(
                value.replaceFirst('T', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _DateRangeParameterField extends StatelessWidget {
  const _DateRangeParameterField({
    required this.parameter,
    required this.value,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final ReportParameter parameter;
  final Object? value;
  final bool enabled;
  final String? errorText;
  final ValueChanged<Object?> onChanged;

  Map<String, dynamic> get _range {
    final raw = value;
    if (raw is! Map) return const <String, dynamic>{};
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final from = DateTime.tryParse(_range['from']?.toString() ?? '') ?? now;
    final to = DateTime.tryParse(_range['to']?.toString() ?? '') ?? now;
    final initialStart = from.isAfter(to) ? to : from;
    final initialEnd = from.isAfter(to) ? from : to;
    final selected = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (selected == null) return;
    onChanged(<String, dynamic>{
      'from': _dateText(selected.start),
      'to': _dateText(selected.end),
    });
  }

  @override
  Widget build(BuildContext context) {
    final from = _range['from']?.toString() ?? '';
    final to = _range['to']?.toString() ?? '';
    final hasValue = from.isNotEmpty && to.isNotEmpty;

    return InkWell(
      onTap: enabled ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: !hasValue,
        decoration: InputDecoration(
          labelText: parameter.label,
          hintText: 'Select date range',
          errorText: errorText,
          enabled: enabled,
          suffixIcon: hasValue && enabled
              ? IconButton(
                  tooltip: 'Clear range',
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              : const Icon(Icons.date_range_outlined, size: 19),
        ),
        child: hasValue
            ? Text(
                '$from  →  $to',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              )
            : const SizedBox(height: 20),
      ),
    );
  }
}

String _dateText(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
