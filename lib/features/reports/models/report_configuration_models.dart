import 'dart:convert';

const reportTypes = <String>[
  'TABLE',
  'SUMMARY',
  'MASTER_DETAIL',
  'CHART',
  'DOCUMENT',
];

const reportParameterDataTypes = <String>[
  'STRING',
  'TEXT',
  'DATE',
  'DATETIME',
  'INTEGER',
  'LONG',
  'DECIMAL',
  'BOOLEAN',
  'ID',
  'ID_LIST',
  'STRING_LIST',
  'JSON',
];

const reportParameterUiTypes = <String>[
  'TEXTBOX',
  'TEXTAREA',
  'DATE_PICKER',
  'DATE_RANGE',
  'DROPDOWN',
  'MULTISELECT',
  'REMOTE_DROPDOWN',
  'REMOTE_MULTISELECT',
  'CHECKBOX',
  'NUMBER',
];

const reportColumnDataTypes = <String>[
  'STRING',
  'TEXT',
  'DATE',
  'DATETIME',
  'INTEGER',
  'LONG',
  'DECIMAL',
  'BOOLEAN',
  'ID',
  'JSON',
];

const reportColumnAlignments = <String>['LEFT', 'CENTER', 'RIGHT'];
const reportActionScopes = <String>['TOOLBAR', 'ROW', 'SELECTION'];

int _draftIdentity = 0;
int _nextDraftIdentity() => ++_draftIdentity;

class ReportConfigurationSummary {
  const ReportConfigurationSummary({
    required this.id,
    required this.name,
    required this.displayName,
    required this.code,
    required this.type,
    required this.subtype,
    required this.dataFunction,
    required this.isDefault,
    required this.isActive,
    required this.definitionVersion,
    required this.updatedOn,
  });

  final int id;
  final String name;
  final String displayName;
  final String code;
  final String type;
  final String subtype;
  final String dataFunction;
  final bool isDefault;
  final bool isActive;
  final int definitionVersion;
  final DateTime? updatedOn;

  String get effectiveName => displayName.trim().isEmpty ? name : displayName;

  factory ReportConfigurationSummary.fromJson(Map<String, dynamic> json) {
    return ReportConfigurationSummary(
      id: _asInt(json['report_id']),
      name: _asString(json['report_name']),
      displayName: _asString(
        json['report_display_name'] ?? json['display_name'],
      ),
      code: _asString(json['report_code']),
      type: _asString(json['report_type']).toUpperCase(),
      subtype: _asString(json['report_subtype']),
      dataFunction: _asString(
        json['report_data_function'] ?? json['data_function'],
      ),
      isDefault: _asBool(json['report_is_default'] ?? json['is_default']),
      isActive: _asBool(
        json['report_is_active'] ?? json['is_active'],
        fallback: true,
      ),
      definitionVersion: _asInt(
        json['report_definition_version'] ?? json['definition_version'],
      ),
      updatedOn: _asDateTime(json['updated_on']),
    );
  }
}

class ReportConfigurationDraft {
  ReportConfigurationDraft({
    required this.reportId,
    required this.reportName,
    required this.displayName,
    required this.reportCode,
    required this.reportType,
    required this.reportSubtype,
    required this.dataFunction,
    required this.isDefault,
    required this.isActive,
    required this.defaultPageSize,
    required this.maxPageSize,
    required this.timeoutSeconds,
    required this.definitionVersion,
    required this.parameters,
    required this.columns,
    required this.actions,
    required this.assignments,
  });

  int reportId;
  String reportName;
  String displayName;
  String reportCode;
  String reportType;
  String reportSubtype;
  String dataFunction;
  bool isDefault;
  bool isActive;
  int defaultPageSize;
  int maxPageSize;
  int timeoutSeconds;
  int definitionVersion;
  List<ReportParameterDraft> parameters;
  List<ReportColumnDraft> columns;
  List<ReportActionDraft> actions;
  List<ReportAssignmentDraft> assignments;

  bool get isNew => reportId <= 0;

  factory ReportConfigurationDraft.empty() {
    return ReportConfigurationDraft(
      reportId: 0,
      reportName: '',
      displayName: '',
      reportCode: '',
      reportType: 'TABLE',
      reportSubtype: '',
      dataFunction: 'rpt.',
      isDefault: false,
      isActive: true,
      defaultPageSize: 100,
      maxPageSize: 500,
      timeoutSeconds: 60,
      definitionVersion: 0,
      parameters: <ReportParameterDraft>[],
      columns: <ReportColumnDraft>[],
      actions: <ReportActionDraft>[],
      assignments: <ReportAssignmentDraft>[],
    );
  }

  factory ReportConfigurationDraft.fromJson(Map<String, dynamic> json) {
    final parameters = _objectList(json['parameters'])
        .map(ReportParameterDraft.fromJson)
        .toList(growable: true)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final columns = _objectList(json['columns'])
        .map(ReportColumnDraft.fromJson)
        .toList(growable: true)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final actions = _objectList(json['actions'])
        .map(ReportActionDraft.fromJson)
        .toList(growable: true)
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return ReportConfigurationDraft(
      reportId: _asInt(json['report_id']),
      reportName: _asString(json['report_name']),
      displayName: _asString(json['display_name']),
      reportCode: _asString(json['report_code']),
      reportType: _asString(json['report_type']).toUpperCase(),
      reportSubtype: _asString(json['report_subtype']),
      dataFunction: _asString(json['data_function']),
      isDefault: _asBool(json['is_default']),
      isActive: _asBool(json['is_active'], fallback: true),
      defaultPageSize: _asInt(json['default_page_size'], fallback: 100),
      maxPageSize: _asInt(json['max_page_size'], fallback: 500),
      timeoutSeconds: _asInt(json['timeout_seconds'], fallback: 60),
      definitionVersion: _asInt(json['definition_version']),
      parameters: parameters,
      columns: columns,
      actions: actions,
      assignments: _objectList(json['assignments'])
          .map(ReportAssignmentDraft.fromJson)
          .toList(growable: true),
    );
  }

  ReportConfigurationValidation validate() {
    final errors = <String>[];
    final codePattern = RegExp(r'^[a-z][a-z0-9._-]{1,99}$');
    final namePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,99}$');
    final functionPattern = RegExp(r'^rpt\.[a-z_][a-z0-9_]{0,62}$');

    if (reportName.trim().isEmpty) errors.add('Report name is required.');
    if (displayName.trim().isEmpty) errors.add('Display name is required.');
    if (reportName.trim().length > 150) {
      errors.add('Report name cannot exceed 150 characters.');
    }
    if (displayName.trim().length > 200) {
      errors.add('Display name cannot exceed 200 characters.');
    }
    if (reportSubtype.trim().length > 60) {
      errors.add('Report subtype cannot exceed 60 characters.');
    }
    if (!codePattern.hasMatch(reportCode.trim().toLowerCase())) {
      errors.add('Report code must use lowercase letters, numbers, dot, underscore or hyphen.');
    }
    if (!reportTypes.contains(reportType.toUpperCase())) {
      errors.add('Select a valid report type.');
    }
    if (!functionPattern.hasMatch(dataFunction.trim().toLowerCase())) {
      errors.add('Data function must be a lowercase rpt.function_name.');
    }
    if (defaultPageSize < 1 || defaultPageSize > 5000) {
      errors.add('Default page size must be between 1 and 5000.');
    }
    if (maxPageSize < defaultPageSize || maxPageSize > 10000) {
      errors.add('Maximum page size must be between the default size and 10000.');
    }
    if (timeoutSeconds < 1 || timeoutSeconds > 900) {
      errors.add('Timeout must be between 1 and 900 seconds.');
    }
    if (columns.isEmpty || !columns.any((item) => item.isActive)) {
      errors.add('Add at least one active report column.');
    }
    if (isActive &&
        !isDefault &&
        !assignments.any(
          (item) => item.isActive && item.canView,
        )) {
      errors.add(
        'An active non-default report needs a view-enabled assignment.',
      );
    }

    _validateParameters(errors, namePattern, functionPattern);
    _validateColumns(errors, namePattern);
    _validateActions(errors, namePattern);
    _validateAssignments(errors);
    return ReportConfigurationValidation(List<String>.unmodifiable(errors));
  }

  Map<String, dynamic> toPayload() {
    return <String, dynamic>{
      'operation': 'Save',
      'report_id': reportId,
      'report_name': reportName.trim(),
      'display_name': displayName.trim(),
      'report_code': reportCode.trim(),
      'report_type': reportType.trim().toUpperCase(),
      'report_subtype': reportSubtype.trim(),
      'data_function': dataFunction.trim(),
      'is_default': isDefault,
      'is_active': isActive,
      'default_page_size': defaultPageSize,
      'max_page_size': maxPageSize,
      'timeout_seconds': timeoutSeconds,
      'parameters': parameters.map((item) => item.toJson()).toList(growable: false),
      'columns': columns.map((item) => item.toJson()).toList(growable: false),
      'actions': actions.map((item) => item.toJson()).toList(growable: false),
      'assignments': assignments.map((item) => item.toJson()).toList(growable: false),
    };
  }

  void _validateParameters(
    List<String> errors,
    RegExp namePattern,
    RegExp functionPattern,
  ) {
    final names = <String>{};
    final orders = <int>{};
    const reserved = <String>{'rid', 'oid', 'uid', 'r_id', 'o_id', 'u_id'};
    for (var index = 0; index < parameters.length; index++) {
      final item = parameters[index];
      final label = 'Parameter ${index + 1}';
      final name = item.name.trim();
      if (!namePattern.hasMatch(name)) errors.add('$label has an invalid name.');
      if (reserved.contains(name.toLowerCase())) {
        errors.add("Parameter name '$name' is reserved for server context.");
      }
      if (name.isNotEmpty && !names.add(name.toLowerCase())) {
        errors.add("Parameter name '$name' is duplicated.");
      }
      if (!orders.add(item.displayOrder)) {
        errors.add("Parameter display order ${item.displayOrder} is duplicated.");
      }
      if (item.displayName.trim().isEmpty) errors.add('$label needs a display name.');
      if (item.displayName.trim().length > 150) {
        errors.add('$label display name cannot exceed 150 characters.');
      }
      if (!reportParameterDataTypes.contains(item.dataType.toUpperCase())) {
        errors.add('$label has an invalid data type.');
      }
      if (!reportParameterUiTypes.contains(item.uiElementType.toUpperCase())) {
        errors.add('$label has an invalid UI element type.');
      }
      if (item.dataFunction.trim().isNotEmpty &&
          !functionPattern.hasMatch(item.dataFunction.trim().toLowerCase())) {
        errors.add('$label lookup function must be a lowercase rpt.function_name.');
      }
      if (item.displayOrder < 0) {
        errors.add('$label display order cannot be negative.');
      }
      _validateJson(item.defaultValueJson, '$label default value', errors, allowEmpty: true);
      _validateJson(item.validationJson, '$label validation', errors, expected: Map);
      _validateJson(item.dependenciesJson, '$label dependencies', errors, expected: List);
    }
  }

  void _validateColumns(List<String> errors, RegExp namePattern) {
    final names = <String>{};
    final orders = <int>{};
    for (var index = 0; index < columns.length; index++) {
      final item = columns[index];
      final label = 'Column ${index + 1}';
      final name = item.name.trim();
      if (!namePattern.hasMatch(name) || name.startsWith('__')) {
        errors.add('$label has an invalid or reserved name.');
      }
      if (name.isNotEmpty && !names.add(name.toLowerCase())) {
        errors.add("Column name '$name' is duplicated.");
      }
      if (!orders.add(item.displayOrder)) {
        errors.add("Column display order ${item.displayOrder} is duplicated.");
      }
      if (item.displayName.trim().isEmpty) errors.add('$label needs a display name.');
      if (item.displayName.trim().length > 150) {
        errors.add('$label display name cannot exceed 150 characters.');
      }
      if (item.format.trim().length > 50) {
        errors.add('$label format cannot exceed 50 characters.');
      }
      if (item.aggregateType.trim().length > 20) {
        errors.add('$label aggregate type cannot exceed 20 characters.');
      }
      if (!reportColumnDataTypes.contains(item.dataType.toUpperCase())) {
        errors.add('$label has an invalid data type.');
      }
      if (!reportColumnAlignments.contains(item.alignment.toUpperCase())) {
        errors.add('$label has an invalid alignment.');
      }
      if (item.displayOrder < 0) {
        errors.add('$label display order cannot be negative.');
      }
      if (item.width != null && item.width! <= 0) {
        errors.add('$label width must be greater than zero.');
      }
    }
  }

  void _validateActions(List<String> errors, RegExp namePattern) {
    final codes = <String>{};
    final orders = <int>{};
    for (var index = 0; index < actions.length; index++) {
      final item = actions[index];
      final label = 'Action ${index + 1}';
      final code = item.code.trim();
      if (!namePattern.hasMatch(code)) errors.add('$label has an invalid code.');
      if (code.isNotEmpty && !codes.add(code.toLowerCase())) {
        errors.add("Action code '$code' is duplicated.");
      }
      if (!orders.add(item.displayOrder)) {
        errors.add("Action display order ${item.displayOrder} is duplicated.");
      }
      if (item.displayName.trim().isEmpty) errors.add('$label needs a display name.');
      if (code.length > 80) errors.add('$label code cannot exceed 80 characters.');
      if (item.displayName.trim().length > 150) {
        errors.add('$label display name cannot exceed 150 characters.');
      }
      if (!reportActionScopes.contains(item.scope.toUpperCase())) {
        errors.add('$label has an invalid scope.');
      }
      if (item.handlerKey.trim().isEmpty) errors.add('$label needs a handler key.');
      if (item.handlerKey.trim().length > 150) {
        errors.add('$label handler key cannot exceed 150 characters.');
      }
      if (item.displayOrder < 0) {
        errors.add('$label display order cannot be negative.');
      }
      _validateJson(item.configJson, '$label configuration', errors, expected: Map);
    }
  }

  void _validateAssignments(List<String> errors) {
    final identities = <String>{};
    for (var index = 0; index < assignments.length; index++) {
      final item = assignments[index];
      final label = 'Assignment ${index + 1}';
      if (item.oId <= 0) errors.add('$label needs a valid company ID.');
      if (item.uId != null && item.uId! <= 0) errors.add('$label user ID must be positive.');
      final registration = item.rId <= 0 ? 'current' : item.rId.toString();
      final identity = '$registration:${item.oId}:${item.uId ?? 'company'}';
      if (!identities.add(identity)) errors.add('$label duplicates another assignment.');
    }
  }

  void _validateJson(
    String source,
    String label,
    List<String> errors, {
    Type? expected,
    bool allowEmpty = false,
  }) {
    if (source.trim().isEmpty && allowEmpty) return;
    try {
      final decoded = jsonDecode(source.trim().isEmpty
          ? expected == List
              ? '[]'
              : '{}'
          : source);
      if (expected == Map && decoded is! Map) errors.add('$label must be a JSON object.');
      if (expected == List && decoded is! List) errors.add('$label must be a JSON array.');
    } on FormatException {
      errors.add('$label contains invalid JSON.');
    }
  }
}

class ReportParameterDraft {
  ReportParameterDraft({
    int? localId,
    required this.name,
    required this.displayName,
    required this.dataType,
    required this.uiElementType,
    required this.dataFunction,
    required this.displayOrder,
    required this.isRequired,
    required this.allowMultiple,
    required this.defaultValueJson,
    required this.validationJson,
    required this.dependenciesJson,
    required this.isActive,
  }) : localId = localId ?? _nextDraftIdentity();

  final int localId;
  String name;
  String displayName;
  String dataType;
  String uiElementType;
  String dataFunction;
  int displayOrder;
  bool isRequired;
  bool allowMultiple;
  String defaultValueJson;
  String validationJson;
  String dependenciesJson;
  bool isActive;

  factory ReportParameterDraft.empty(int displayOrder) {
    return ReportParameterDraft(
      name: '',
      displayName: '',
      dataType: 'STRING',
      uiElementType: 'TEXTBOX',
      dataFunction: '',
      displayOrder: displayOrder,
      isRequired: false,
      allowMultiple: false,
      defaultValueJson: '',
      validationJson: '{}',
      dependenciesJson: '[]',
      isActive: true,
    );
  }

  factory ReportParameterDraft.fromJson(Map<String, dynamic> json) {
    return ReportParameterDraft(
      name: _asString(json['name']),
      displayName: _asString(json['display_name']),
      dataType: _asString(json['data_type']).toUpperCase(),
      uiElementType: _asString(json['ui_element_type']).toUpperCase(),
      dataFunction: _asString(json['data_function']),
      displayOrder: _asInt(json['display_order'], fallback: 1),
      isRequired: _asBool(json['is_required']),
      allowMultiple: _asBool(json['allow_multiple']),
      defaultValueJson: _jsonText(json['default_value'], emptyForNull: true),
      validationJson: _jsonText(json['validation'], fallback: '{}'),
      dependenciesJson: _jsonText(json['dependencies'], fallback: '[]'),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name.trim(),
        'display_name': displayName.trim(),
        'data_type': dataType.toUpperCase(),
        'ui_element_type': uiElementType.toUpperCase(),
        'data_function': dataFunction.trim().isEmpty ? null : dataFunction.trim(),
        'display_order': displayOrder,
        'is_required': isRequired,
        'allow_multiple': allowMultiple,
        'default_value': defaultValueJson.trim().isEmpty
            ? null
            : jsonDecode(defaultValueJson),
        'validation': jsonDecode(validationJson.trim().isEmpty ? '{}' : validationJson),
        'dependencies': jsonDecode(
          dependenciesJson.trim().isEmpty ? '[]' : dependenciesJson,
        ),
        'is_active': isActive,
      };
}

class ReportColumnDraft {
  ReportColumnDraft({
    int? localId,
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
  }) : localId = localId ?? _nextDraftIdentity();

  final int localId;
  String name;
  String displayName;
  int displayOrder;
  String dataType;
  String format;
  String alignment;
  int? width;
  bool isVisible;
  bool isSortable;
  bool isFilterable;
  bool isExportable;
  bool isTotal;
  String aggregateType;
  bool isActive;

  factory ReportColumnDraft.empty(int displayOrder) {
    return ReportColumnDraft(
      name: '',
      displayName: '',
      displayOrder: displayOrder,
      dataType: 'STRING',
      format: 'TEXT',
      alignment: 'LEFT',
      width: 160,
      isVisible: true,
      isSortable: false,
      isFilterable: false,
      isExportable: true,
      isTotal: false,
      aggregateType: '',
      isActive: true,
    );
  }

  factory ReportColumnDraft.fromJson(Map<String, dynamic> json) {
    return ReportColumnDraft(
      name: _asString(json['name']),
      displayName: _asString(json['display_name']),
      displayOrder: _asInt(json['display_order'], fallback: 1),
      dataType: _asString(json['data_type']).toUpperCase(),
      format: _asString(json['format']).toUpperCase(),
      alignment: _asString(json['alignment']).toUpperCase(),
      width: _asNullableInt(json['width']),
      isVisible: _asBool(json['is_visible'], fallback: true),
      isSortable: _asBool(json['is_sortable']),
      isFilterable: _asBool(json['is_filterable']),
      isExportable: _asBool(json['is_exportable'], fallback: true),
      isTotal: _asBool(json['is_total']),
      aggregateType: _asString(json['aggregate_type']).toUpperCase(),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name.trim(),
        'display_name': displayName.trim(),
        'display_order': displayOrder,
        'data_type': dataType.toUpperCase(),
        'format': format.trim().toUpperCase(),
        'alignment': alignment.toUpperCase(),
        'width': width,
        'is_visible': isVisible,
        'is_sortable': isSortable,
        'is_filterable': isFilterable,
        'is_exportable': isExportable,
        'is_total': isTotal,
        'aggregate_type': aggregateType.trim().toUpperCase(),
        'is_active': isActive,
      };
}

class ReportActionDraft {
  ReportActionDraft({
    int? localId,
    required this.code,
    required this.displayName,
    required this.scope,
    required this.handlerKey,
    required this.displayOrder,
    required this.configJson,
    required this.isActive,
  }) : localId = localId ?? _nextDraftIdentity();

  final int localId;
  String code;
  String displayName;
  String scope;
  String handlerKey;
  int displayOrder;
  String configJson;
  bool isActive;

  factory ReportActionDraft.empty(int displayOrder) {
    return ReportActionDraft(
      code: '',
      displayName: '',
      scope: 'TOOLBAR',
      handlerKey: '',
      displayOrder: displayOrder,
      configJson: '{}',
      isActive: true,
    );
  }

  factory ReportActionDraft.fromJson(Map<String, dynamic> json) {
    return ReportActionDraft(
      code: _asString(json['action_code']),
      displayName: _asString(json['display_name']),
      scope: _asString(json['scope']).toUpperCase(),
      handlerKey: _asString(json['handler_key']),
      displayOrder: _asInt(json['display_order'], fallback: 1),
      configJson: _jsonText(json['config'], fallback: '{}'),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'action_code': code.trim(),
        'display_name': displayName.trim(),
        'scope': scope.toUpperCase(),
        'handler_key': handlerKey.trim(),
        'display_order': displayOrder,
        'config': jsonDecode(configJson.trim().isEmpty ? '{}' : configJson),
        'is_active': isActive,
      };
}

class ReportAssignmentDraft {
  ReportAssignmentDraft({
    int? localId,
    required this.rId,
    required this.oId,
    required this.uId,
    required this.canView,
    required this.canExport,
    required this.isActive,
  }) : localId = localId ?? _nextDraftIdentity();

  final int localId;
  int rId;
  int oId;
  int? uId;
  bool canView;
  bool canExport;
  bool isActive;

  factory ReportAssignmentDraft.empty() {
    return ReportAssignmentDraft(
      rId: 0,
      oId: 0,
      uId: null,
      canView: true,
      canExport: true,
      isActive: true,
    );
  }

  factory ReportAssignmentDraft.fromJson(Map<String, dynamic> json) {
    return ReportAssignmentDraft(
      rId: _asInt(json['r_id']),
      oId: _asInt(json['o_id']),
      uId: _asNullableInt(json['u_id']),
      canView: _asBool(json['can_view'], fallback: true),
      canExport: _asBool(json['can_export'], fallback: true),
      isActive: _asBool(json['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'r_id': rId,
        'o_id': oId,
        'u_id': uId,
        'can_view': canView,
        'can_export': canExport,
        'is_active': isActive,
      };
}

class ReportConfigurationValidation {
  const ReportConfigurationValidation(this.errors);
  final List<String> errors;
  bool get isValid => errors.isEmpty;
}

class ReportConfigurationSaveResult {
  const ReportConfigurationSaveResult({
    required this.reportId,
    required this.reportCode,
    required this.definitionVersion,
    required this.wasCreated,
  });

  final int reportId;
  final String reportCode;
  final int definitionVersion;
  final bool wasCreated;

  factory ReportConfigurationSaveResult.fromJson(Map<String, dynamic> json) {
    return ReportConfigurationSaveResult(
      reportId: _asInt(json['report_id']),
      reportCode: _asString(json['report_code']),
      definitionVersion: _asInt(json['definition_version']),
      wasCreated: _asBool(json['was_created']),
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

String _jsonText(
  Object? value, {
  String fallback = '',
  bool emptyForNull = false,
}) {
  if (value == null) return emptyForNull ? '' : fallback;
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return fallback;
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(text));
    } on FormatException {
      return text;
    }
  }
  return const JsonEncoder.withIndent('  ').convert(value);
}

String _asString(Object? value) => value?.toString() ?? '';

int _asInt(Object? value, {int fallback = 0}) =>
    int.tryParse(value?.toString() ?? '') ?? fallback;

int? _asNullableInt(Object? value) =>
    value == null ? null : int.tryParse(value.toString());

bool _asBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') return true;
  if (normalized == 'false' || normalized == '0' || normalized == 'no') return false;
  return fallback;
}

DateTime? _asDateTime(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text);
}
