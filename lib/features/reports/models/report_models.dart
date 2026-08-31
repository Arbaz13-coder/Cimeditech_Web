import 'dart:convert';

class ReportCompany {
  const ReportCompany({
    required this.id,
    required this.name,
    required this.displayName,
    required this.tradeName,
    required this.lastSyncOn,
  });

  final int id;
  final String name;
  final String displayName;
  final String tradeName;
  final DateTime? lastSyncOn;

  String get effectiveName {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (tradeName.trim().isNotEmpty) return tradeName.trim();
    return name.trim().isEmpty ? 'Company $id' : name.trim();
  }

  factory ReportCompany.fromJson(Map<String, dynamic> json) {
    return ReportCompany(
      id: _asInt(json['o_id']),
      name: _asString(json['o_name']),
      displayName: _asString(json['o_name_display']),
      tradeName: _asString(json['o_trade_name']),
      lastSyncOn: _asDateTime(json['last_sync_on']),
    );
  }
}

class ReportCatalogItem {
  const ReportCatalogItem({
    required this.id,
    required this.name,
    required this.displayName,
    required this.code,
    required this.type,
    required this.subtype,
    required this.isDefault,
    required this.definitionVersion,
    required this.canExport,
  });

  final int id;
  final String name;
  final String displayName;
  final String code;
  final String type;
  final String subtype;
  final bool isDefault;
  final int definitionVersion;
  final bool canExport;

  String get effectiveName => displayName.trim().isEmpty ? name : displayName;

  factory ReportCatalogItem.fromJson(Map<String, dynamic> json) {
    return ReportCatalogItem(
      id: _asInt(json['report_id']),
      name: _asString(json['report_name']),
      displayName: _asString(json['display_name']),
      code: _asString(json['report_code']),
      type: _asString(json['report_type']),
      subtype: _asString(json['report_subtype']),
      isDefault: _asBool(json['is_default']),
      definitionVersion: _asInt(json['definition_version']),
      canExport: _asBool(json['can_export']),
    );
  }
}

class ReportDefinition {
  const ReportDefinition({
    required this.id,
    required this.name,
    required this.displayName,
    required this.code,
    required this.type,
    required this.subtype,
    required this.isDefault,
    required this.isActive,
    required this.canExport,
    required this.defaultPageSize,
    required this.maxPageSize,
    required this.timeoutSeconds,
    required this.definitionVersion,
    required this.parameters,
    required this.columns,
    required this.actions,
  });

  final int id;
  final String name;
  final String displayName;
  final String code;
  final String type;
  final String subtype;
  final bool isDefault;
  final bool isActive;
  final bool canExport;
  final int defaultPageSize;
  final int maxPageSize;
  final int timeoutSeconds;
  final int definitionVersion;
  final List<ReportParameter> parameters;
  final List<ReportColumn> columns;
  final List<ReportAction> actions;

  String get effectiveName => displayName.trim().isEmpty ? name : displayName;

  List<ReportParameter> get activeParameters =>
      parameters.where((item) => item.isActive).toList(growable: false);

  List<ReportColumn> get visibleColumns => columns
      .where((item) => item.isActive && item.isVisible)
      .toList(growable: false);

  factory ReportDefinition.fromJson(Map<String, dynamic> json) {
    final parameters = _objectList(json['parameters'])
        .map(ReportParameter.fromJson)
        .toList(growable: true)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final columns = _objectList(json['columns'])
        .map(ReportColumn.fromJson)
        .toList(growable: true)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final actions = _objectList(json['actions'])
        .map(ReportAction.fromJson)
        .toList(growable: true)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return ReportDefinition(
      id: _asInt(json['report_id']),
      name: _asString(json['report_name']),
      displayName: _asString(json['display_name']),
      code: _asString(json['report_code']),
      type: _asString(json['report_type']),
      subtype: _asString(json['report_subtype']),
      isDefault: _asBool(json['is_default']),
      isActive: _asBool(json['is_active'], fallback: true),
      canExport: _asBool(json['can_export']),
      defaultPageSize: _asInt(json['default_page_size'], fallback: 100),
      maxPageSize: _asInt(json['max_page_size'], fallback: 500),
      timeoutSeconds: _asInt(json['timeout_seconds'], fallback: 60),
      definitionVersion: _asInt(json['definition_version']),
      parameters: List<ReportParameter>.unmodifiable(parameters),
      columns: List<ReportColumn>.unmodifiable(columns),
      actions: List<ReportAction>.unmodifiable(actions),
    );
  }
}

class ReportParameter {
  const ReportParameter({
    required this.id,
    required this.name,
    required this.displayName,
    required this.dataType,
    required this.uiElementType,
    required this.displayOrder,
    required this.isRequired,
    required this.allowMultiple,
    required this.defaultValue,
    required this.validation,
    required this.dependencies,
    required this.hasDataFunction,
    required this.isActive,
  });

  final int id;
  final String name;
  final String displayName;
  final String dataType;
  final String uiElementType;
  final int displayOrder;
  final bool isRequired;
  final bool allowMultiple;
  final Object? defaultValue;
  final Map<String, dynamic> validation;
  final List<String> dependencies;
  final bool hasDataFunction;
  final bool isActive;

  bool get acceptsMultiple =>
      allowMultiple || dataType == 'ID_LIST' || dataType == 'STRING_LIST';

  bool get usesRemoteLookup => hasDataFunction ||
      uiElementType == 'REMOTE_DROPDOWN' ||
      uiElementType == 'REMOTE_MULTISELECT';

  bool get isDate => dataType == 'DATE';
  bool get isDateTime => dataType == 'DATETIME';
  bool get isBoolean => dataType == 'BOOLEAN' || uiElementType == 'CHECKBOX';
  bool get isNumeric =>
      dataType == 'INTEGER' ||
      dataType == 'LONG' ||
      dataType == 'ID' ||
      dataType == 'DECIMAL';

  String get label => isRequired ? '$displayName *' : displayName;

  String get hintText =>
      _asString(validation['hint'] ?? validation['hint_text']);

  List<ReportLookupOption> get localOptions {
    final raw = validation['options'] ?? validation['values'];
    if (raw is! List) return const <ReportLookupOption>[];

    return raw.map((item) {
      if (item is Map) {
        return ReportLookupOption.fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
      return ReportLookupOption(value: item, label: item?.toString() ?? '');
    }).where((item) => item.label.isNotEmpty).toList(growable: false);
  }

  factory ReportParameter.fromJson(Map<String, dynamic> json) {
    final rawDependencies = json['dependencies'];
    final dependencies = rawDependencies is List
        ? rawDependencies
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    return ReportParameter(
      id: _asInt(json['parameter_id']),
      name: _asString(json['name']),
      displayName: _asString(json['display_name']),
      dataType: _asString(json['data_type']).toUpperCase(),
      uiElementType: _asString(json['ui_element_type']).toUpperCase(),
      displayOrder: _asInt(json['display_order']),
      isRequired: _asBool(json['is_required']),
      allowMultiple: _asBool(json['allow_multiple']),
      defaultValue: json['default_value'],
      validation: _asMap(json['validation']),
      dependencies: dependencies,
      hasDataFunction: _asBool(json['has_data_function']),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }
}

class ReportColumn {
  const ReportColumn({
    required this.name,
    required this.displayName,
    required this.displayOrder,
    required this.dataType,
    required this.format,
    required this.alignment,
    required this.width,
    required this.isVisible,
    required this.isSortable,
    required this.isFilterable,
    required this.isExportable,
    required this.isTotal,
    required this.aggregateType,
    required this.isActive,
  });

  final String name;
  final String displayName;
  final int displayOrder;
  final String dataType;
  final String format;
  final String alignment;
  final double? width;
  final bool isVisible;
  final bool isSortable;
  final bool isFilterable;
  final bool isExportable;
  final bool isTotal;
  final String aggregateType;
  final bool isActive;

  factory ReportColumn.fromJson(Map<String, dynamic> json) {
    return ReportColumn(
      name: _asString(json['name']),
      displayName: _asString(json['display_name']),
      displayOrder: _asInt(json['display_order']),
      dataType: _asString(json['data_type']).toUpperCase(),
      format: _asString(json['format']).toUpperCase(),
      alignment: _asString(json['alignment']).toUpperCase(),
      width: _asDoubleOrNull(json['width']),
      isVisible: _asBool(json['is_visible'], fallback: true),
      isSortable: _asBool(json['is_sortable']),
      isFilterable: _asBool(json['is_filterable']),
      isExportable: _asBool(json['is_exportable'], fallback: true),
      isTotal: _asBool(json['is_total']),
      aggregateType: _asString(json['aggregate_type']).toUpperCase(),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }
}

class ReportAction {
  const ReportAction({
    required this.code,
    required this.displayName,
    required this.scope,
    required this.displayOrder,
    required this.config,
    required this.isActive,
  });

  final String code;
  final String displayName;
  final String scope;
  final int displayOrder;
  final Map<String, dynamic> config;
  final bool isActive;

  factory ReportAction.fromJson(Map<String, dynamic> json) {
    return ReportAction(
      code: _asString(json['action_code']),
      displayName: _asString(json['display_name']),
      scope: _asString(json['scope']),
      displayOrder: _asInt(json['display_order']),
      config: _asMap(json['config']),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }
}

class ReportLookupOption {
  const ReportLookupOption({
    required this.value,
    required this.label,
    this.metadata = const <String, dynamic>{},
  });

  final Object? value;
  final String label;
  final Map<String, dynamic> metadata;

  String get identity {
    final raw = value;
    if (raw is Map || raw is List) return jsonEncode(raw);
    return raw?.toString() ?? 'null';
  }

  factory ReportLookupOption.fromJson(Map<String, dynamic> json) {
    final value = json['value'];
    final label = _asString(json['label']);
    return ReportLookupOption(
      value: value,
      label: label.isEmpty ? value?.toString() ?? '' : label,
      metadata: Map<String, dynamic>.unmodifiable(json),
    );
  }

  factory ReportLookupOption.fromValue(Object? value) {
    return ReportLookupOption(
      value: value,
      label: value?.toString() ?? '',
    );
  }
}

class ReportSort {
  const ReportSort({required this.columnName, required this.direction});

  final String columnName;
  final String direction;

  bool get ascending => direction.toUpperCase() == 'ASC';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'column_name': columnName,
        'direction': direction.toUpperCase(),
      };
}

class ReportPageInfo {
  const ReportPageInfo({
    required this.pageNo,
    required this.pageSize,
    required this.rowCount,
    required this.hasMore,
    required this.totalCount,
    required this.totalPages,
  });

  final int pageNo;
  final int pageSize;
  final int rowCount;
  final bool hasMore;
  final int? totalCount;
  final int? totalPages;

  factory ReportPageInfo.fromJson(Map<String, dynamic> json) {
    return ReportPageInfo(
      pageNo: _asInt(json['page_no'], fallback: 1),
      pageSize: _asInt(json['page_size'], fallback: 100),
      rowCount: _asInt(json['row_count']),
      hasMore: _asBool(json['has_more']),
      totalCount: _asNullableInt(json['total_count']),
      totalPages: _asNullableInt(json['total_pages']),
    );
  }
}

class ReportResult {
  const ReportResult({
    required this.reportId,
    required this.reportCode,
    required this.displayName,
    required this.definitionVersion,
    required this.companyId,
    required this.columns,
    required this.rows,
    required this.summary,
    required this.page,
    required this.executionId,
  });

  final int reportId;
  final String reportCode;
  final String displayName;
  final int definitionVersion;
  final int companyId;
  final List<ReportColumn> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> summary;
  final ReportPageInfo page;
  final int executionId;

  factory ReportResult.fromJson(Map<String, dynamic> json) {
    final columns = _objectList(json['columns'])
        .map(ReportColumn.fromJson)
        .toList(growable: false);

    return ReportResult(
      reportId: _asInt(json['report_id']),
      reportCode: _asString(json['report_code']),
      displayName: _asString(json['display_name']),
      definitionVersion: _asInt(json['definition_version']),
      companyId: _asInt(json['o_id']),
      columns: columns,
      rows: _objectList(json['rows']),
      summary: _asMap(json['summary']),
      page: ReportPageInfo.fromJson(_asMap(json['page'])),
      executionId: _asInt(json['execution_id']),
    );
  }
}

List<Map<String, dynamic>> _objectList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList(growable: false);
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is! Map) return const <String, dynamic>{};
  return value.map((key, value) => MapEntry(key.toString(), value));
}

String _asString(Object? value) => value?.toString() ?? '';

int _asInt(Object? value, {int fallback = 0}) =>
    int.tryParse(value?.toString() ?? '') ?? fallback;

int? _asNullableInt(Object? value) =>
    value == null ? null : int.tryParse(value.toString());

double? _asDoubleOrNull(Object? value) =>
    value == null ? null : double.tryParse(value.toString());

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return fallback;
}

DateTime? _asDateTime(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text);
}
