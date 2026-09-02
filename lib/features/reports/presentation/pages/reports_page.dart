import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/api_response.dart';
import '../../data/report_repository.dart';
import '../../models/report_models.dart';
import '../../services/dynamic_report_formatter.dart';
import '../../services/report_export_service.dart';
import '../../services/report_filter_codec.dart';
import '../widgets/report_catalog_panel.dart';
import '../widgets/report_data_grid.dart';
import '../widgets/report_filter_panel.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({
    super.key,
    required this.repository,
    required this.onSessionExpired,
  });

  final ReportRepository repository;
  final VoidCallback onSessionExpired;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const int _maximumPdfRows = 5000;
  static const int _maximumExcelRows = 25000;

  final Map<String, ReportDefinition> _definitionCache =
      <String, ReportDefinition>{};
  final ReportExportService _exportService = const ReportExportService();

  List<ReportCompany> _companies = const <ReportCompany>[];
  List<ReportCatalogItem> _reports = const <ReportCatalogItem>[];
  ReportCompany? _selectedCompany;
  ReportCatalogItem? _selectedReport;
  ReportDefinition? _definition;
  ReportResult? _result;
  Map<String, dynamic> _filterValues = <String, dynamic>{};
  Map<String, String> _filterErrors = <String, String>{};
  List<ReportSort> _sort = const <ReportSort>[];

  bool _loadingCompanies = true;
  bool _loadingCatalog = false;
  bool _loadingDefinition = false;
  bool _loadingExecution = false;
  bool _exporting = false;
  bool _filtersDirty = false;
  bool _filtersExpanded = true;
  String _companiesError = '';
  String _catalogError = '';
  String _definitionError = '';
  String _executionError = '';
  String _exportError = '';
  String _exportStatus = '';
  int _pageNo = 1;
  int _pageSize = 100;
  int _companiesRequest = 0;
  int _catalogRequest = 0;
  int _definitionRequest = 0;
  int _executionRequest = 0;
  int _exportRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _companiesRequest++;
    _catalogRequest++;
    _definitionRequest++;
    _executionRequest++;
    _exportRequest++;
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    final request = ++_companiesRequest;
    final previousCompanyId = _selectedCompany?.id;
    final previousReportCode = _selectedReport?.code;
    setState(() {
      _loadingCompanies = true;
      _companiesError = '';
    });

    ReportCompany? companyToLoad;
    try {
      final companies = await widget.repository.getCompanies();
      if (!mounted || request != _companiesRequest) return;

      companyToLoad = _findCompany(companies, previousCompanyId) ??
          _findCompany(companies, AppConfig.defaultCompanyId) ??
          (companies.isEmpty ? null : companies.first);

      setState(() {
        _companies = companies;
        _selectedCompany = companyToLoad;
        _loadingCompanies = false;
      });
    } on ApiException catch (error) {
      if (!mounted || request != _companiesRequest) return;
      if (_handleSessionExpired(error)) return;
      setState(() => _companiesError = error.message);
    } finally {
      if (mounted && request == _companiesRequest && _loadingCompanies) {
        setState(() => _loadingCompanies = false);
      }
    }

    if (companyToLoad != null && mounted && request == _companiesRequest) {
      await _loadCatalog(
        companyToLoad.id,
        preserveReport: companyToLoad.id == previousCompanyId &&
            previousReportCode != null,
      );
    }
  }

  Future<void> _loadCatalog(
    int companyId, {
    bool preserveReport = false,
  }) async {
    final request = ++_catalogRequest;
    _definitionRequest++;
    _executionRequest++;
    _exportRequest++;
    final previousCode = preserveReport ? _selectedReport?.code : null;

    setState(() {
      _loadingCatalog = true;
      _catalogError = '';
      _definitionError = '';
      _executionError = '';
      _exportError = '';
      _exportStatus = '';
      _exporting = false;
      _loadingDefinition = false;
      _loadingExecution = false;
      if (!preserveReport) {
        _reports = const <ReportCatalogItem>[];
        _selectedReport = null;
        _definition = null;
        _result = null;
        _filterValues = <String, dynamic>{};
        _filterErrors = <String, String>{};
        _filtersDirty = false;
        _filtersExpanded = true;
      }
    });

    ReportCatalogItem? reportToRestore;
    try {
      final reports = await widget.repository.getCatalog(companyId: companyId);
      if (!mounted || request != _catalogRequest) return;
      if (_selectedCompany?.id != companyId) return;

      if (previousCode != null) {
        for (final report in reports) {
          if (report.code == previousCode) {
            reportToRestore = report;
            break;
          }
        }
      }

      setState(() {
        _reports = reports;
        _selectedReport = reportToRestore;
        if (reportToRestore == null) {
          _definition = null;
          _result = null;
        }
      });
    } on ApiException catch (error) {
      if (!mounted || request != _catalogRequest) return;
      if (_handleSessionExpired(error)) return;
      setState(() => _catalogError = error.message);
    } finally {
      if (mounted && request == _catalogRequest) {
        setState(() => _loadingCatalog = false);
      }
    }

    if (reportToRestore != null && mounted && request == _catalogRequest) {
      await _selectReport(reportToRestore, forceDefinitionRefresh: true);
    }
  }

  Future<void> _changeCompany(int companyId) async {
    if (_selectedCompany?.id == companyId) return;
    final company = _findCompany(_companies, companyId);
    if (company == null) return;

    setState(() {
      _selectedCompany = company;
      _selectedReport = null;
      _definition = null;
      _result = null;
      _filterValues = <String, dynamic>{};
      _filterErrors = <String, String>{};
      _sort = const <ReportSort>[];
      _filtersDirty = false;
      _filtersExpanded = true;
    });
    await _loadCatalog(company.id);
  }

  Future<void> _selectReport(
    ReportCatalogItem report, {
    bool forceDefinitionRefresh = false,
  }) async {
    final company = _selectedCompany;
    if (company == null) return;
    if (!forceDefinitionRefresh &&
        _selectedReport?.id == report.id &&
        _definition != null) {
      return;
    }

    final request = ++_definitionRequest;
    _executionRequest++;
    _exportRequest++;
    setState(() {
      _selectedReport = report;
      _definition = null;
      _result = null;
      _loadingDefinition = true;
      _loadingExecution = false;
      _definitionError = '';
      _executionError = '';
      _exportError = '';
      _exportStatus = '';
      _exporting = false;
      _filterValues = <String, dynamic>{};
      _filterErrors = <String, String>{};
      _sort = const <ReportSort>[];
      _filtersDirty = false;
      _filtersExpanded = true;
      _pageNo = 1;
    });

    final cacheKey = _definitionCacheKey(company.id, report);
    ReportDefinition? definitionForAutoRun;
    try {
      final cached = forceDefinitionRefresh ? null : _definitionCache[cacheKey];
      final resolvedDefinition = cached ??
          await widget.repository.getDefinition(
            companyId: company.id,
            reportCode: report.code,
          );
      if (!mounted || request != _definitionRequest) return;
      if (_selectedCompany?.id != company.id || _selectedReport?.id != report.id) {
        return;
      }

      definitionForAutoRun = resolvedDefinition;
      _definitionCache[cacheKey] = resolvedDefinition;
      final initialValues = ReportFilterCodec.initialValues(resolvedDefinition);
      setState(() {
        _definition = resolvedDefinition;
        _filterValues = initialValues;
        _pageSize = resolvedDefinition.defaultPageSize
            .clamp(1, resolvedDefinition.maxPageSize)
            .toInt();
      });
    } on ApiException catch (error) {
      if (!mounted || request != _definitionRequest) return;
      if (_handleSessionExpired(error)) return;
      setState(() => _definitionError = error.message);
    } finally {
      if (mounted && request == _definitionRequest) {
        setState(() => _loadingDefinition = false);
      }
    }

    if (definitionForAutoRun != null &&
        mounted &&
        request == _definitionRequest) {
      final validation = ReportFilterCodec.build(
        definitionForAutoRun.activeParameters,
        _filterValues,
      );
      if (validation.isValid) {
        await _execute(showValidationErrors: false);
      }
    }
  }

  Future<void> _execute({bool showValidationErrors = true}) async {
    if (_exporting) return;
    final company = _selectedCompany;
    final report = _selectedReport;
    final definition = _definition;
    if (company == null || report == null || definition == null) return;

    final validation = ReportFilterCodec.build(
      definition.activeParameters,
      _filterValues,
    );
    if (!validation.isValid) {
      if (showValidationErrors && mounted) {
        setState(() {
          _filterErrors = Map<String, String>.from(validation.errors);
          _executionError = 'Please correct the highlighted report filters.';
          _filtersExpanded = true;
        });
      }
      return;
    }

    final request = ++_executionRequest;
    setState(() {
      _loadingExecution = true;
      _executionError = '';
      _exportError = '';
      _filterErrors = <String, String>{};
    });

    try {
      final result = await widget.repository.execute(
        companyId: company.id,
        reportCode: report.code,
        filters: validation.filters,
        pageNo: _pageNo,
        pageSize: _pageSize,
        sort: _sort,
        timeoutSeconds: definition.timeoutSeconds,
      );
      if (!mounted || request != _executionRequest) return;
      if (_selectedCompany?.id != company.id || _selectedReport?.id != report.id) {
        return;
      }

      setState(() {
        _result = result;
        _pageNo = result.page.pageNo;
        _pageSize = result.page.pageSize;
        _filtersDirty = false;
        _filtersExpanded = false;
      });
    } on ApiException catch (error) {
      if (!mounted || request != _executionRequest) return;
      if (_handleSessionExpired(error)) return;
      setState(() {
        _executionError = error.message;
        if (_result == null) _filtersExpanded = true;
      });
    } finally {
      if (mounted && request == _executionRequest) {
        setState(() => _loadingExecution = false);
      }
    }
  }

  void _changeFilter(String name, Object? value) {
    final definition = _definition;
    if (definition == null) return;

    setState(() {
      if (value == null) {
        _filterValues.remove(name);
      } else {
        _filterValues[name] = value;
      }
      _filterErrors.remove(name);
      _executionError = '';
      _exportError = '';
      _filtersDirty = true;
      _clearDependentValues(definition, name, <String>{});
    });
  }

  void _clearDependentValues(
    ReportDefinition definition,
    String changedName,
    Set<String> visited,
  ) {
    if (!visited.add(changedName)) return;
    for (final parameter in definition.activeParameters) {
      if (!parameter.dependencies.contains(changedName)) continue;
      _filterValues.remove(parameter.name);
      _filterErrors.remove(parameter.name);
      _clearDependentValues(definition, parameter.name, visited);
    }
  }

  Future<List<ReportLookupOption>> _lookup(
    ReportParameter parameter,
    String search,
  ) async {
    final company = _selectedCompany;
    final report = _selectedReport;
    if (company == null || report == null) {
      throw const ApiException('Select a company and report first.');
    }

    try {
      return await widget.repository.lookup(
        companyId: company.id,
        reportCode: report.code,
        parameterName: parameter.name,
        search: search,
        dependencies: ReportFilterCodec.dependenciesFor(
          parameter,
          _filterValues,
        ),
      );
    } on ApiException catch (error) {
      _handleSessionExpired(error);
      rethrow;
    }
  }

  void _resetFilters() {
    final definition = _definition;
    if (definition == null) return;
    _executionRequest++;
    setState(() {
      _filterValues = ReportFilterCodec.initialValues(definition);
      _filterErrors = <String, String>{};
      _sort = const <ReportSort>[];
      _pageNo = 1;
      _pageSize = definition.defaultPageSize
          .clamp(1, definition.maxPageSize)
          .toInt();
      _result = null;
      _executionError = '';
      _exportError = '';
      _exportStatus = '';
      _loadingExecution = false;
      _filtersDirty = false;
      _filtersExpanded = true;
    });
  }

  void _sortBy(ReportColumn column) {
    if (_loadingExecution || !column.isSortable) return;
    final current = _sort.isEmpty ? null : _sort.first;
    final direction = current?.columnName == column.name && current!.ascending
        ? 'DESC'
        : 'ASC';
    setState(() {
      _sort = <ReportSort>[
        ReportSort(columnName: column.name, direction: direction),
      ];
      _pageNo = 1;
    });
    _execute();
  }

  void _changePage(int pageNo) {
    if (_loadingExecution || pageNo < 1) return;
    // If filters changed while an older result page is still visible, always
    // start the new filter set at page one instead of skipping its first rows.
    setState(() => _pageNo = _filtersDirty ? 1 : pageNo);
    _execute();
  }

  void _changePageSize(int pageSize) {
    if (_loadingExecution || pageSize == _pageSize) return;
    setState(() {
      _pageSize = pageSize;
      _pageNo = 1;
    });
    _execute();
  }

  Future<void> _copyCurrentPage() async {
    final result = _result;
    final definition = _definition;
    if (result == null || definition == null || result.rows.isEmpty) return;

    final columns = result.columns.isEmpty
        ? definition.columns
        : result.columns;
    final csv = DynamicReportFormatter.toCsv(result.rows, columns);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Current report page copied as CSV.'),
        ),
      );
  }

  Future<void> _downloadReport(ReportExportFormat format) async {
    if (_exporting || _loadingExecution) return;
    final company = _selectedCompany;
    final report = _selectedReport;
    final definition = _definition;
    if (company == null || report == null || definition == null) return;

    final validation = ReportFilterCodec.build(
      definition.activeParameters,
      _filterValues,
    );
    if (!validation.isValid) {
      setState(() {
        _filterErrors = Map<String, String>.from(validation.errors);
        _exportError = 'Please correct the highlighted filters before exporting.';
        _filtersExpanded = true;
      });
      return;
    }

    final maximumRows = format == ReportExportFormat.pdf
        ? _maximumPdfRows
        : _maximumExcelRows;
    final request = ++_exportRequest;
    setState(() {
      _exporting = true;
      _exportError = '';
      _exportStatus = 'Preparing ${_exportLabel(format)}…';
      _filterErrors = <String, String>{};
    });

    try {
      final rows = <Map<String, dynamic>>[];
      var pageNo = 1;
      final pageSize = math.min(
        definition.maxPageSize.clamp(1, 1000).toInt(),
        maximumRows,
      ).toInt();

      while (true) {
        final page = await widget.repository.execute(
          companyId: company.id,
          reportCode: report.code,
          filters: validation.filters,
          pageNo: pageNo,
          pageSize: pageSize,
          sort: _sort,
          timeoutSeconds: definition.timeoutSeconds,
        );
        if (!mounted || request != _exportRequest) return;
        if (_selectedCompany?.id != company.id ||
            _selectedReport?.id != report.id) {
          return;
        }

        final totalCount = page.page.totalCount;
        if (totalCount != null && totalCount > maximumRows) {
          throw ApiException(
            '${_exportLabel(format)} export supports up to '
            '${_groupDigits(maximumRows)} rows in the browser. '
            'Narrow the report filters and retry.',
          );
        }
        if (rows.length + page.rows.length > maximumRows) {
          throw ApiException(
            '${_exportLabel(format)} export supports up to '
            '${_groupDigits(maximumRows)} rows in the browser. '
            'Narrow the report filters and retry.',
          );
        }

        rows.addAll(page.rows);
        setState(() {
          _exportStatus = 'Preparing ${_exportLabel(format)} · '
              '${_groupDigits(rows.length)} rows loaded';
        });

        if (!page.page.hasMore || page.rows.isEmpty) break;
        if (rows.length >= maximumRows) {
          throw ApiException(
            'The report is larger than the safe browser export limit of '
            '${_groupDigits(maximumRows)} rows.',
          );
        }
        pageNo++;
        if (pageNo > 1000) {
          throw const ApiException(
            'The report returned too many result pages to export safely.',
          );
        }
      }

      final fileName = await _exportService.download(
        format: format,
        definition: definition,
        companyName: company.effectiveName,
        rows: rows,
        filters: validation.filters,
      );
      if (!mounted || request != _exportRequest) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '$fileName downloaded with ${_groupDigits(rows.length)} rows.',
            ),
          ),
        );
    } on ApiException catch (error) {
      if (!mounted || request != _exportRequest) return;
      if (_handleSessionExpired(error)) return;
      setState(() => _exportError = error.message);
    } on FormatException catch (error) {
      if (mounted && request == _exportRequest) {
        setState(() => _exportError = error.message);
      }
    } on UnsupportedError catch (error) {
      if (mounted && request == _exportRequest) {
        setState(() => _exportError = error.message?.toString() ?? error.toString());
      }
    } catch (_) {
      if (mounted && request == _exportRequest) {
        setState(() {
          _exportError =
              'The report file could not be created. Please retry the export.';
        });
      }
    } finally {
      if (mounted && request == _exportRequest) {
        setState(() {
          _exporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _openMobileReportPicker() async {
    if (_reports.isEmpty || _loadingCatalog) return;
    final report = await showReportPickerDialog(
      context,
      reports: _reports,
      selectedReportId: _selectedReport?.id,
    );
    if (report != null && mounted) await _selectReport(report);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCompanies && _companies.isEmpty) {
      return const _FullPageLoading(message: 'Loading your companies…');
    }

    if (_companiesError.isNotEmpty && _companies.isEmpty) {
      return _FullPageError(
        message: _companiesError,
        onRetry: _loadCompanies,
      );
    }

    if (_companies.isEmpty) {
      return const _FullPageEmpty(
        icon: Icons.business_outlined,
        title: 'No company available',
        message: 'Your login is not mapped to an active company.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompanyHeader(
            companies: _companies,
            selectedCompany: _selectedCompany,
            loading: _loadingCompanies || _loadingCatalog || _exporting,
            onChanged: _changeCompany,
            onRefresh: _loadingCompanies || _loadingCatalog || _exporting
                ? null
                : () => _loadCompanies(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 980;
                if (desktop) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 286,
                        child: ReportCatalogPanel(
                          reports: _reports,
                          selectedReportId: _selectedReport?.id,
                          loading: _loadingCatalog,
                          error: _catalogError,
                          onRetry: () => _loadCatalog(
                            _selectedCompany!.id,
                          ),
                          onSelected: (report) => _selectReport(report),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildRunner()),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MobileReportSelector(
                      selectedReport: _selectedReport,
                      reportCount: _reports.length,
                      loading: _loadingCatalog,
                      error: _catalogError,
                      onTap: _openMobileReportPicker,
                      onRetry: () => _loadCatalog(_selectedCompany!.id),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: _buildRunner()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunner() {
    final report = _selectedReport;
    final definition = _definition;

    if (report == null) {
      return const _FullPageEmpty(
        icon: Icons.assessment_outlined,
        title: 'Select a report',
        message: 'Choose a report from the catalog to load its filters and data.',
        compact: true,
      );
    }

    if (_loadingDefinition) {
      return const _FullPageLoading(
        message: 'Loading report definition…',
        compact: true,
      );
    }

    if (_definitionError.isNotEmpty || definition == null) {
      return _FullPageError(
        message: _definitionError.isEmpty
            ? 'The report definition is unavailable.'
            : _definitionError,
        onRetry: () => _selectReport(
          report,
          forceDefinitionRefresh: true,
        ),
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportFilterPanel(
          definition: definition,
          values: _filterValues,
          errors: _filterErrors,
          loading: _loadingExecution || _exporting,
          expanded: _filtersExpanded,
          onChanged: _changeFilter,
          onLookup: _lookup,
          onReset: _resetFilters,
          onToggle: () => setState(
            () => _filtersExpanded = !_filtersExpanded,
          ),
          onRun: () {
            setState(() => _pageNo = 1);
            _execute();
          },
        ),
        if (_executionError.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InlineNotice(
            icon: Icons.error_outline_rounded,
            message: _executionError,
            isError: true,
            actionLabel: _result == null ? 'Retry' : null,
            onAction: _result == null ? () => _execute() : null,
          ),
        ] else if (_filtersDirty && _result != null) ...[
          const SizedBox(height: 8),
          const _InlineNotice(
            icon: Icons.info_outline_rounded,
            message: 'Filters changed. Run the report to refresh the result.',
          ),
        ],
        if (_exporting || _exportError.isNotEmpty) ...[
          const SizedBox(height: 8),
          _InlineNotice(
            icon: _exporting
                ? Icons.downloading_rounded
                : Icons.error_outline_rounded,
            message: _exporting ? _exportStatus : _exportError,
            isError: !_exporting,
          ),
        ],
        if (_result?.summary.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          _SummaryStrip(summary: _result!.summary),
        ],
        const SizedBox(height: 8),
        Expanded(child: _buildResult(definition)),
      ],
    );
  }

  Widget _buildResult(ReportDefinition definition) {
    final result = _result;
    if (_loadingExecution && result == null) {
      return const _FullPageLoading(
        message: 'Running report…',
        compact: true,
      );
    }

    if (result == null) {
      return const _FullPageEmpty(
        icon: Icons.play_circle_outline_rounded,
        title: 'Ready to run',
        message: 'Complete the filters above and select Run report.',
        compact: true,
      );
    }

    return ReportDataGrid(
      definition: definition,
      result: result,
      loading: _loadingExecution || _exporting,
      exporting: _exporting,
      sort: _sort,
      onSort: _sortBy,
      onPageChanged: _changePage,
      onPageSizeChanged: _changePageSize,
      onRefresh: () => _execute(),
      onCopyPage: _copyCurrentPage,
      onDownloadPdf: () => _downloadReport(ReportExportFormat.pdf),
      onDownloadExcel: () => _downloadReport(ReportExportFormat.excel),
    );
  }

  ReportCompany? _findCompany(
    List<ReportCompany> companies,
    int? id,
  ) {
    if (id == null) return null;
    for (final company in companies) {
      if (company.id == id) return company;
    }
    return null;
  }

  String _definitionCacheKey(int companyId, ReportCatalogItem report) {
    return '$companyId:${report.id}:${report.definitionVersion}';
  }

  bool _handleSessionExpired(ApiException error) {
    if (!error.isUnauthorized) return false;
    widget.onSessionExpired();
    return true;
  }

  String _exportLabel(ReportExportFormat format) {
    return format == ReportExportFormat.pdf ? 'PDF' : 'Excel';
  }
}

class _CompanyHeader extends StatelessWidget {
  const _CompanyHeader({
    required this.companies,
    required this.selectedCompany,
    required this.loading,
    required this.onChanged,
    required this.onRefresh,
  });

  final List<ReportCompany> companies;
  final ReportCompany? selectedCompany;
  final bool loading;
  final ValueChanged<int> onChanged;
  final VoidCallback? onRefresh;

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
                final narrow = constraints.maxWidth < 720;
                final title = Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2970FF), Color(0xFF155EEF)],
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.analytics_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dynamic Reports',
                            style: TextStyle(
                              color: Color(0xFF101828),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Select a company, choose a report and run it',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF667085),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final selector = Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedCompany?.id,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Company',
                          prefixIcon: Icon(Icons.business_outlined, size: 19),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: companies
                            .map(
                              (company) => DropdownMenuItem<int>(
                                value: company.id,
                                child: Text(
                                  company.effectiveName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: loading
                            ? null
                            : (value) {
                                if (value != null) onChanged(value);
                              },
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Refresh companies and reports',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      title,
                      const SizedBox(height: 10),
                      selector,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 18),
                    SizedBox(width: 390, child: selector),
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

class _MobileReportSelector extends StatelessWidget {
  const _MobileReportSelector({
    required this.selectedReport,
    required this.reportCount,
    required this.loading,
    required this.error,
    required this.onTap,
    required this.onRetry,
  });

  final ReportCatalogItem? selectedReport;
  final int reportCount;
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
        onTap: loading || reportCount == 0 ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: Color(0xFF175CD3),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedReport?.effectiveName ?? 'Select a report',
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
                              ? 'Loading report catalog…'
                              : '$reportCount reports available',
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

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    this.isError = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final background = isError ? const Color(0xFFFEF3F2) : const Color(0xFFEFF8FF);
    final foreground = isError ? const Color(0xFFB42318) : const Color(0xFF175CD3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: summary.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = summary.entries.elementAt(index);
          return Container(
            constraints: const BoxConstraints(minWidth: 130, maxWidth: 230),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE4E7EC)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _humanize(entry.key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  entry.value?.toString() ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF101828),
                  fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FullPageLoading extends StatelessWidget {
  const _FullPageLoading({required this.message, this.compact = false});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _StateSurface(
      compact: compact,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullPageError extends StatelessWidget {
  const _FullPageError({
    required this.message,
    required this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _StateSurface(
      compact: compact,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: Color(0xFFD92D20),
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load reports',
            style: TextStyle(
              color: Color(0xFF101828),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _FullPageEmpty extends StatelessWidget {
  const _FullPageEmpty({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _StateSurface(
      compact: compact,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: const Color(0xFF175CD3), size: 28),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF101828),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateSurface extends StatelessWidget {
  const _StateSurface({required this.child, required this.compact});

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final body = Center(child: Padding(padding: const EdgeInsets.all(24), child: child));
    if (!compact) return body;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE4E7EC)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: body,
    );
  }
}

String _humanize(String value) {
  final words = value.replaceAll('_', ' ').trim().split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
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
