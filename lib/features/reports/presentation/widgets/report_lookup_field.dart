import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/report_models.dart';

typedef ReportLookupLoader = Future<List<ReportLookupOption>> Function(
  String search,
);

class ReportLookupField extends StatelessWidget {
  const ReportLookupField({
    super.key,
    required this.parameter,
    required this.value,
    required this.enabled,
    required this.loader,
    required this.onChanged,
    this.errorText,
  });

  final ReportParameter parameter;
  final Object? value;
  final bool enabled;
  final ReportLookupLoader loader;
  final ValueChanged<Object?> onChanged;
  final String? errorText;

  List<ReportLookupOption> get _selected {
    final raw = value;
    if (raw == null) return const <ReportLookupOption>[];
    if (raw is List) {
      return raw
          .map(
            (item) => item is ReportLookupOption
                ? item
                : ReportLookupOption.fromValue(item),
          )
          .toList(growable: false);
    }
    return <ReportLookupOption>[
      raw is ReportLookupOption
          ? raw
          : ReportLookupOption.fromValue(raw),
    ];
  }

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;
    final selected = await showDialog<List<ReportLookupOption>>(
      context: context,
      builder: (context) => _LookupDialog(
        title: parameter.displayName,
        multiple: parameter.acceptsMultiple,
        initialSelected: _selected,
        loader: loader,
      ),
    );
    if (selected == null) return;
    onChanged(
      parameter.acceptsMultiple
          ? selected
          : selected.isEmpty
              ? null
              : selected.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final hasValue = selected.isNotEmpty;

    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        isEmpty: !hasValue,
        decoration: InputDecoration(
          labelText: parameter.label,
          hintText: parameter.hintText.isEmpty
              ? 'Search and select'
              : parameter.hintText,
          errorText: errorText,
          enabled: enabled,
          suffixIcon: hasValue && enabled
              ? IconButton(
                  tooltip: 'Clear selection',
                  onPressed: () => onChanged(
                    parameter.acceptsMultiple
                        ? <ReportLookupOption>[]
                        : null,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                )
              : const Icon(Icons.search_rounded, size: 19),
        ),
        child: hasValue
            ? Text(
                parameter.acceptsMultiple
                    ? selected.length == 1
                        ? selected.first.label
                        : '${selected.length} values selected'
                    : selected.first.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontWeight: FontWeight.w600,
                ),
              )
            : const SizedBox(height: 20),
      ),
    );
  }
}

class _LookupDialog extends StatefulWidget {
  const _LookupDialog({
    required this.title,
    required this.multiple,
    required this.initialSelected,
    required this.loader,
  });

  final String title;
  final bool multiple;
  final List<ReportLookupOption> initialSelected;
  final ReportLookupLoader loader;

  @override
  State<_LookupDialog> createState() => _LookupDialogState();
}

class _LookupDialogState extends State<_LookupDialog> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, ReportLookupOption> _selected =
      <String, ReportLookupOption>{};
  List<ReportLookupOption> _options = const <ReportLookupOption>[];
  Timer? _debounce;
  int _requestVersion = 0;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    for (final item in widget.initialSelected) {
      _selected[item.identity] = item;
    }
    _load();
  }

  @override
  void dispose() {
    _requestVersion++;
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final options = await widget.loader(_searchController.text);
      if (!mounted || version != _requestVersion) return;
      setState(() => _options = options);
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  void _search(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  void _toggle(ReportLookupOption option, bool selected) {
    setState(() {
      if (selected) {
        _selected[option.identity] = option;
      } else {
        _selected.remove(option.identity);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final contentWidth = math.max(
      240.0,
      math.min(560.0, mediaSize.width - 64),
    );
    final contentHeight = math.max(
      260.0,
      math.min(500.0, mediaSize.height - 190),
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 14, 8),
      contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 4),
      actionsPadding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              color: Color(0xFF175CD3),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  widget.multiple
                      ? '${_selected.length} selected'
                      : 'Select one value',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: contentWidth,
        height: contentHeight,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _search,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type to search…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.multiple)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(
              _selected.values.toList(growable: false),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text('Use ${_selected.length} selected'),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_loading && _options.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty && _options.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 34,
              color: Color(0xFFD92D20),
            ),
            const SizedBox(height: 10),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_options.isEmpty) {
      return const Center(
        child: Text(
          'No matching values found.',
          style: TextStyle(color: Color(0xFF667085)),
        ),
      );
    }

    return Stack(
      children: [
        ListView.separated(
          itemCount: _options.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final option = _options[index];
            final selected = _selected.containsKey(option.identity);
            if (widget.multiple) {
              return CheckboxListTile(
                value: selected,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  option.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (value) => _toggle(option, value ?? false),
              );
            }

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? const Color(0xFF175CD3)
                    : const Color(0xFF98A2B3),
              ),
              title: Text(
                option.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(<ReportLookupOption>[
                option,
              ]),
            );
          },
        ),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}
