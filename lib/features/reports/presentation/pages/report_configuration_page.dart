import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/api_response.dart';
import '../../data/report_repository.dart';
import '../../models/report_configuration_models.dart';
import '../../models/report_models.dart';
import '../widgets/report_configuration_editor.dart';

class ReportConfigurationPage extends StatefulWidget {
  const ReportConfigurationPage({
    super.key,
    required this.repository,
    required this.onSessionExpired,
  });

  final ReportRepository repository;
  final VoidCallback onSessionExpired;

  @override
  State<ReportConfigurationPage> createState() =>
      _ReportConfigurationPageState();
}

class _ReportConfigurationPageState extends State<ReportConfigurationPage> {
  List<ReportConfigurationSummary> _reports =
      const <ReportConfigurationSummary>[];
  List<ReportCompany> _companies = const <ReportCompany>[];
  ReportConfigurationSummary? _selected;
  ReportConfigurationDraft? _draft;
  ReportSetupSection _section = ReportSetupSection.overview;
  List<String> _validationErrors = const <String>[];
  String _listError = '';
  String _detailError = '';
  String _companiesError = '';
  bool _loadingList = true;
  bool _loadingCompanies = true;
  bool _loadingDetail = false;
  bool _saving = false;
  bool _dirty = false;
  int _listRequest = 0;
  int _companyRequest = 0;
  int _detailRequest = 0;
  int _editorVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadList();
  }

  @override
  void dispose() {
    _listRequest++;
    _companyRequest++;
    _detailRequest++;
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    final request = ++_companyRequest;
    setState(() {
      _loadingCompanies = true;
      _companiesError = '';
    });
    try {
      final companies = await widget.repository.getCompanies();
      if (!mounted || request != _companyRequest) return;
      setState(() => _companies = companies);
    } on ApiException catch (error) {
      if (!mounted || request != _companyRequest) return;
      if (_handleSession(error)) return;
      setState(() => _companiesError = error.message);
    } finally {
      if (mounted && request == _companyRequest) {
        setState(() => _loadingCompanies = false);
      }
    }
  }

  Future<void> _loadList({int? selectReportId}) async {
    final request = ++_listRequest;
    _detailRequest++;
    setState(() {
      _loadingList = true;
      _loadingDetail = false;
      _listError = '';
    });

    ReportConfigurationSummary? target;
    try {
      final reports = await widget.repository.getConfigurationList();
      if (!mounted || request != _listRequest) return;
      final wantedId = selectReportId ?? _selected?.id;
      target = _findReport(reports, wantedId) ??
          (selectReportId == null && _draft == null && reports.isNotEmpty
              ? reports.first
              : null);
      setState(() {
        _reports = reports;
        _selected = target;
      });
    } on ApiException catch (error) {
      if (!mounted || request != _listRequest) return;
      if (_handleSession(error)) return;
      setState(() => _listError = error.message);
    } finally {
      if (mounted && request == _listRequest) {
        setState(() => _loadingList = false);
      }
    }

    if (target != null && mounted && request == _listRequest) {
      await _loadDetail(target);
    }
  }

  Future<void> _loadDetail(ReportConfigurationSummary report) async {
    final request = ++_detailRequest;
    setState(() {
      _selected = report;
      _loadingDetail = true;
      _detailError = '';
      _validationErrors = const <String>[];
      _draft = null;
      _dirty = false;
      _section = ReportSetupSection.overview;
    });

    try {
      final draft = await widget.repository.getConfiguration(reportId: report.id);
      if (!mounted || request != _detailRequest || _selected?.id != report.id) {
        return;
      }
      setState(() {
        _draft = draft;
        _editorVersion++;
      });
    } on ApiException catch (error) {
      if (!mounted || request != _detailRequest) return;
      if (_handleSession(error)) return;
      setState(() => _detailError = error.message);
    } finally {
      if (mounted && request == _detailRequest) {
        setState(() => _loadingDetail = false);
      }
    }
  }

  Future<void> _selectReport(ReportConfigurationSummary report) async {
    if (_saving || (_selected?.id == report.id && _draft != null)) return;
    final discard = await _confirmDiscard();
    if (!mounted || !discard) return;
    await _loadDetail(report);
  }

  Future<void> _newReport() async {
    if (_saving) return;
    final discard = await _confirmDiscard();
    if (!mounted || !discard) return;
    _detailRequest++;
    setState(() {
      _selected = null;
      _draft = ReportConfigurationDraft.empty();
      _section = ReportSetupSection.overview;
      _validationErrors = const <String>[];
      _detailError = '';
      _loadingDetail = false;
      _dirty = false;
      _editorVersion++;
    });
  }

  Future<void> _refresh() async {
    if (_saving) return;
    final discard = await _confirmDiscard();
    if (!mounted || !discard) return;
    setState(() {
      _draft = null;
      _dirty = false;
    });
    await _loadList(selectReportId: _selected?.id);
    if (mounted) await _loadCompanies();
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    final validation = draft.validate();
    if (!validation.isValid) {
      setState(() {
        _validationErrors = validation.errors;
        _section = _sectionFor(validation.errors);
      });
      return;
    }

    setState(() {
      _saving = true;
      _validationErrors = const <String>[];
      _detailError = '';
    });
    try {
      final result = await widget.repository.saveConfiguration(draft);
      if (!mounted) return;
      setState(() => _dirty = false);
      _showMessage(
        result.wasCreated
            ? 'Report configuration created successfully.'
            : 'Report configuration updated to version ${result.definitionVersion}.',
      );
      await _loadList(selectReportId: result.reportId);
    } on FormatException {
      if (mounted) {
        setState(() {
          _validationErrors = const <String>[
            'One of the JSON configuration fields is invalid.',
          ];
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      if (_handleSession(error)) return;
      setState(() => _detailError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _mutate(VoidCallback mutation) {
    if (_saving) return;
    setState(() {
      mutation();
      _dirty = true;
      _validationErrors = const <String>[];
      _detailError = '';
    });
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: const Text(
              'The current report configuration has changes that have not been saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openMobilePicker() async {
    if (_loadingList || _reports.isEmpty) return;
    final report = await showDialog<ReportConfigurationSummary>(
      context: context,
      builder: (context) => _ConfigurationPickerDialog(
        reports: _reports,
        selectedId: _selected?.id,
      ),
    );
    if (report != null && mounted) await _selectReport(report);
  }

  bool _handleSession(ApiException error) {
    if (!error.isUnauthorized) return false;
    widget.onSessionExpired();
    return true;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SetupHeader(
            count: _reports.length,
            loading: _loadingList,
            onNew: _newReport,
            onRefresh: _refresh,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 980;
                if (desktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 300,
                        child: _ConfigurationCatalog(
                          reports: _reports,
                          selectedId: _selected?.id,
                          loading: _loadingList,
                          error: _listError,
                          onSelected: _selectReport,
                          onRetry: _loadList,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildEditor()),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MobileConfigurationSelector(
                      selected: _selected,
                      creatingNew: _draft?.isNew ?? false,
                      count: _reports.length,
                      loading: _loadingList,
                      error: _listError,
                      onTap: _openMobilePicker,
                      onRetry: _loadList,
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildEditor()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    if (_listError.isNotEmpty && _reports.isEmpty && _draft == null) {
      return _SetupState(
        icon: Icons.admin_panel_settings_outlined,
        title: _isPermissionError(_listError)
            ? 'Administrator access required'
            : 'Unable to load report setup',
        message: _listError,
        actionLabel: 'Retry',
        onAction: _loadList,
        isError: true,
      );
    }
    if (_loadingDetail) {
      return const _SetupState(
        icon: Icons.settings_suggest_outlined,
        title: 'Loading configuration',
        message: 'Fetching report metadata and assignments…',
        loading: true,
      );
    }
    if (_detailError.isNotEmpty && _draft == null) {
      return _SetupState(
        icon: Icons.error_outline_rounded,
        title: 'Unable to load configuration',
        message: _detailError,
        actionLabel: _selected == null ? null : 'Retry',
        onAction: _selected == null ? null : () => _loadDetail(_selected!),
        isError: true,
      );
    }
    final draft = _draft;
    if (draft == null) {
      return _SetupState(
        icon: Icons.post_add_rounded,
        title: _reports.isEmpty ? 'Create your first report' : 'Select a report',
        message: _reports.isEmpty
            ? 'Register a PostgreSQL report function and its metadata.'
            : 'Choose a report configuration from the catalog or create a new one.',
        actionLabel: 'New report',
        onAction: _newReport,
      );
    }

    return ReportConfigurationEditor(
      key: ValueKey('report-editor-$_editorVersion'),
      draft: draft,
      section: _section,
      dirty: _dirty,
      saving: _saving,
      apiError: _detailError,
      validationErrors: _validationErrors,
      companies: _companies,
      loadingCompanies: _loadingCompanies,
      companiesError: _companiesError,
      onSectionChanged: (section) => setState(() => _section = section),
      onMutate: _mutate,
      onSave: _save,
    );
  }

  ReportConfigurationSummary? _findReport(
    List<ReportConfigurationSummary> reports,
    int? reportId,
  ) {
    if (reportId == null) return null;
    for (final report in reports) {
      if (report.id == reportId) return report;
    }
    return null;
  }

  ReportSetupSection _sectionFor(List<String> errors) {
    if (errors.any((error) => error.startsWith('Parameter'))) {
      return ReportSetupSection.parameters;
    }
    if (errors.any(
      (error) => error.startsWith('Column') || error.contains('report column'),
    )) {
      return ReportSetupSection.columns;
    }
    if (errors.any((error) => error.startsWith('Action'))) {
      return ReportSetupSection.actions;
    }
    if (errors.any(
      (error) => error.startsWith('Assignment') || error.contains('assignment'),
    )) {
      return ReportSetupSection.assignments;
    }
    return ReportSetupSection.overview;
  }

  bool _isPermissionError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('admin') ||
        normalized.contains('permission') ||
        normalized.contains('forbidden');
  }
}

class _SetupHeader extends StatelessWidget {
  const _SetupHeader({
    required this.count,
    required this.loading,
    required this.onNew,
    required this.onRefresh,
  });

  final int count;
  final bool loading;
  final VoidCallback onNew;
  final VoidCallback onRefresh;

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
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 500;
                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7F56D9), Color(0xFF6941C6)],
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.settings_suggest_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Report Setup',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF101828),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '$count configured report${count == 1 ? '' : 's'} · Admin only',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh configurations',
                      onPressed: loading ? null : onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    const SizedBox(width: 4),
                    if (compact)
                      IconButton.filled(
                        tooltip: 'New report',
                        onPressed: loading ? null : onNew,
                        icon: const Icon(Icons.add_rounded, size: 18),
                      )
                    else
                      FilledButton.icon(
                        onPressed: loading ? null : onNew,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('New report'),
                      ),
                  ],
                );
              },
            ),
          ),
          if (loading)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _ConfigurationCatalog extends StatefulWidget {
  const _ConfigurationCatalog({
    required this.reports,
    required this.selectedId,
    required this.loading,
    required this.error,
    required this.onSelected,
    required this.onRetry,
  });

  final List<ReportConfigurationSummary> reports;
  final int? selectedId;
  final bool loading;
  final String error;
  final ValueChanged<ReportConfigurationSummary> onSelected;
  final VoidCallback onRetry;

  @override
  State<_ConfigurationCatalog> createState() => _ConfigurationCatalogState();
}

class _ConfigurationCatalogState extends State<_ConfigurationCatalog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _search.trim().toLowerCase();
    final reports = normalized.isEmpty
        ? widget.reports
        : widget.reports.where((item) {
            return item.effectiveName.toLowerCase().contains(normalized) ||
                item.code.toLowerCase().contains(normalized) ||
                item.type.toLowerCase().contains(normalized) ||
                item.subtype.toLowerCase().contains(normalized) ||
                item.dataFunction.toLowerCase().contains(normalized);
          }).toList(growable: false);

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
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Search configurations…',
                prefixIcon: Icon(Icons.search_rounded, size: 19),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.error.isNotEmpty && widget.reports.isEmpty
                ? _CatalogState(
                    icon: Icons.error_outline_rounded,
                    message: widget.error,
                    actionLabel: 'Retry',
                    onAction: widget.onRetry,
                  )
                : widget.loading && widget.reports.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : reports.isEmpty
                        ? const _CatalogState(
                            icon: Icons.search_off_rounded,
                            message: 'No matching report configurations.',
                          )
                        : ListView.separated(
                            itemCount: reports.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final report = reports[index];
                              final selected = report.id == widget.selectedId;
                              return Material(
                                color: selected
                                    ? const Color(0xFFF4F3FF)
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () => widget.onSelected(report),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      13,
                                      10,
                                      10,
                                      10,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: report.isActive
                                                ? const Color(0xFFECFDF3)
                                                : const Color(0xFFF2F4F7),
                                            borderRadius:
                                                BorderRadius.circular(9),
                                          ),
                                          child: Icon(
                                            _typeIcon(report.type),
                                            size: 18,
                                            color: report.isActive
                                                ? const Color(0xFF039855)
                                                : const Color(0xFF98A2B3),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                report.effectiveName,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: const Color(0xFF101828),
                                                  fontSize: 12,
                                                  fontWeight: selected
                                                      ? FontWeight.w800
                                                      : FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                '${report.code} · v${report.definitionVersion}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFF667085),
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (report.isDefault)
                                          const Tooltip(
                                            message: 'Default report',
                                            child: Icon(
                                              Icons.public_rounded,
                                              size: 16,
                                              color: Color(0xFF7F56D9),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _MobileConfigurationSelector extends StatelessWidget {
  const _MobileConfigurationSelector({
    required this.selected,
    required this.creatingNew,
    required this.count,
    required this.loading,
    required this.error,
    required this.onTap,
    required this.onRetry,
  });

  final ReportConfigurationSummary? selected;
  final bool creatingNew;
  final int count;
  final bool loading;
  final String error;
  final VoidCallback onTap;
  final VoidCallback onRetry;

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
      child: InkWell(
        onTap: loading || count == 0 ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, color: Color(0xFF6941C6)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creatingNew
                          ? 'New report configuration'
                          : selected?.effectiveName ?? 'Select configuration',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF101828),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      error.isNotEmpty
                          ? error
                          : loading
                              ? 'Loading configurations…'
                              : '$count reports available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: error.isNotEmpty
                            ? const Color(0xFFD92D20)
                            : const Color(0xFF667085),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (error.isNotEmpty)
                TextButton(onPressed: onRetry, child: const Text('Retry'))
              else if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfigurationPickerDialog extends StatefulWidget {
  const _ConfigurationPickerDialog({
    required this.reports,
    required this.selectedId,
  });

  final List<ReportConfigurationSummary> reports;
  final int? selectedId;

  @override
  State<_ConfigurationPickerDialog> createState() =>
      _ConfigurationPickerDialogState();
}

class _ConfigurationPickerDialogState
    extends State<_ConfigurationPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _search.trim().toLowerCase();
    final reports = widget.reports.where((item) {
      return normalized.isEmpty ||
          item.effectiveName.toLowerCase().contains(normalized) ||
          item.code.toLowerCase().contains(normalized) ||
          item.type.toLowerCase().contains(normalized);
    }).toList(growable: false);
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: const Text('Select report configuration'),
      content: SizedBox(
        width: math.max(240.0, math.min(620.0, size.width - 64)),
        height: math.max(260.0, math.min(560.0, size.height - 190)),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _search = value),
              decoration: const InputDecoration(
                hintText: 'Search report name or code…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: reports.isEmpty
                  ? const Center(child: Text('No matching configurations.'))
                  : ListView.separated(
                      itemCount: reports.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final report = reports[index];
                        final selected = report.id == widget.selectedId;
                        return ListTile(
                          leading: Icon(
                            _typeIcon(report.type),
                            color: selected
                                ? const Color(0xFF6941C6)
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
                            '${report.code} · v${report.definitionVersion}',
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: Color(0xFF6941C6),
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

class _CatalogState extends StatelessWidget {
  const _CatalogState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: const Color(0xFF98A2B3)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupState extends StatelessWidget {
  const _SetupState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFD92D20) : const Color(0xFF6941C6);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator()
              else
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isError
                        ? const Color(0xFFFEF3F2)
                        : const Color(0xFFF4F3FF),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(icon, color: color, size: 29),
                ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF101828),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF667085)),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 15),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

IconData _typeIcon(String type) {
  return switch (type.toUpperCase()) {
    'CHART' => Icons.bar_chart_rounded,
    'SUMMARY' => Icons.analytics_outlined,
    'MASTER_DETAIL' => Icons.account_tree_outlined,
    'DOCUMENT' => Icons.description_outlined,
    _ => Icons.table_chart_outlined,
  };
}
