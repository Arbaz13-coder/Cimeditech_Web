import 'dart:convert';

import '../models/report_models.dart';

class ReportFilterBuildResult {
  const ReportFilterBuildResult({
    required this.filters,
    required this.errors,
  });

  final Map<String, dynamic> filters;
  final Map<String, String> errors;

  bool get isValid => errors.isEmpty;
}

class ReportFilterCodec {
  ReportFilterCodec._();

  static Map<String, dynamic> initialValues(
    ReportDefinition definition, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final values = <String, dynamic>{};

    for (final parameter in definition.activeParameters) {
      if (parameter.defaultValue != null) {
        values[parameter.name] = parameter.defaultValue;
        continue;
      }

      if (parameter.isBoolean) {
        values[parameter.name] = false;
        continue;
      }

      if (!parameter.isRequired) continue;

      if (parameter.uiElementType == 'DATE_RANGE' &&
          parameter.dataType == 'JSON') {
        values[parameter.name] = <String, dynamic>{
          'from': _dateText(_financialYearStart(current)),
          'to': _dateText(current),
        };
      } else if (parameter.isDate) {
        final name = parameter.name.toLowerCase();
        values[parameter.name] = _dateText(
          name.contains('from') || name.contains('start')
              ? _financialYearStart(current)
              : current,
        );
      }
    }

    return values;
  }

  static ReportFilterBuildResult build(
    List<ReportParameter> parameters,
    Map<String, dynamic> values,
  ) {
    final filters = <String, dynamic>{};
    final errors = <String, String>{};

    for (final parameter in parameters.where((item) => item.isActive)) {
      final raw = unwrapValue(values[parameter.name]);

      if (_isEmpty(raw)) {
        if (parameter.isRequired) {
          errors[parameter.name] = '${parameter.displayName} is required.';
        }
        continue;
      }

      final converted = _convert(parameter, raw);
      if (!converted.isValid) {
        errors[parameter.name] = converted.error;
        continue;
      }

      final validationError = _validateMetadata(
        parameter,
        converted.value,
      );
      if (validationError != null) {
        errors[parameter.name] = validationError;
        continue;
      }

      filters[parameter.name] = converted.value;
    }

    return ReportFilterBuildResult(
      filters: Map<String, dynamic>.unmodifiable(filters),
      errors: Map<String, String>.unmodifiable(errors),
    );
  }

  static Map<String, dynamic> dependenciesFor(
    ReportParameter parameter,
    Map<String, dynamic> values,
  ) {
    final dependencies = <String, dynamic>{};
    for (final name in parameter.dependencies) {
      final value = unwrapValue(values[name]);
      if (!_isEmpty(value)) dependencies[name] = value;
    }
    return dependencies;
  }

  static Object? unwrapValue(Object? value) {
    if (value is ReportLookupOption) return value.value;
    if (value is List) {
      return value.map(unwrapValue).toList(growable: false);
    }
    return value;
  }

  static _FilterConversion _convert(
    ReportParameter parameter,
    Object? raw,
  ) {
    final multiple = parameter.acceptsMultiple;
    if (multiple) {
      if (raw is! List) {
        return _FilterConversion.error(
          '${parameter.displayName} must contain one or more selected values.',
        );
      }

      final elementType = switch (parameter.dataType) {
        'ID_LIST' => 'ID',
        'STRING_LIST' => 'STRING',
        _ => parameter.dataType,
      };
      final values = <Object?>[];
      for (final item in raw) {
        final converted = _convertScalar(
          elementType,
          unwrapValue(item),
          parameter.displayName,
        );
        if (!converted.isValid) return converted;
        values.add(converted.value);
      }
      return _FilterConversion.success(values);
    }

    if (raw is List) {
      return _FilterConversion.error(
        '${parameter.displayName} accepts only one value.',
      );
    }

    return _convertScalar(
      parameter.dataType,
      raw,
      parameter.displayName,
    );
  }

  static _FilterConversion _convertScalar(
    String dataType,
    Object? raw,
    String displayName,
  ) {
    switch (dataType) {
      case 'STRING':
      case 'TEXT':
        return _FilterConversion.success(raw?.toString().trim() ?? '');
      case 'DATE': {
        final value = raw?.toString().trim() ?? '';
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
            DateTime.tryParse(value) == null) {
          return _FilterConversion.error(
            '$displayName must be a valid date.',
          );
        }
        return _FilterConversion.success(value);
      }
      case 'DATETIME': {
        if (raw is DateTime) {
          return _FilterConversion.success(raw.toIso8601String());
        }
        final value = raw?.toString().trim() ?? '';
        if (DateTime.tryParse(value) == null) {
          return _FilterConversion.error(
            '$displayName must be a valid date and time.',
          );
        }
        return _FilterConversion.success(value);
      }
      case 'INTEGER':
      case 'LONG':
      case 'ID': {
        if (raw is int) return _FilterConversion.success(raw);
        final value = int.tryParse(raw?.toString().trim() ?? '');
        return value == null
            ? _FilterConversion.error('$displayName must be a whole number.')
            : _FilterConversion.success(value);
      }
      case 'DECIMAL': {
        if (raw is num) return _FilterConversion.success(raw);
        final value = num.tryParse(raw?.toString().trim() ?? '');
        return value == null
            ? _FilterConversion.error('$displayName must be a number.')
            : _FilterConversion.success(value);
      }
      case 'BOOLEAN': {
        if (raw is bool) return _FilterConversion.success(raw);
        final value = raw?.toString().trim().toLowerCase();
        if (value == 'true' || value == '1' || value == 'yes') {
          return _FilterConversion.success(true);
        }
        if (value == 'false' || value == '0' || value == 'no') {
          return _FilterConversion.success(false);
        }
        return _FilterConversion.error('$displayName must be Yes or No.');
      }
      case 'JSON': {
        if (raw is Map || raw is List || raw is num || raw is bool) {
          return _FilterConversion.success(raw);
        }
        try {
          final decoded = jsonDecode(raw?.toString() ?? '');
          if (decoded == null) {
            return _FilterConversion.error('$displayName cannot be null.');
          }
          return _FilterConversion.success(decoded);
        } on FormatException {
          return _FilterConversion.error('$displayName must contain valid JSON.');
        }
      }
      default:
        return _FilterConversion.error(
          '$displayName uses unsupported data type $dataType.',
        );
    }
  }

  static String? _validateMetadata(
    ReportParameter parameter,
    Object? value,
  ) {
    final validation = parameter.validation;
    if (validation.isEmpty) return null;

    if (value is String) {
      final minLength = _validationInt(
        validation,
        const <String>['min_length', 'minLength'],
      );
      final maxLength = _validationInt(
        validation,
        const <String>['max_length', 'maxLength'],
      );
      if (minLength != null && value.length < minLength) {
        return '${parameter.displayName} must have at least $minLength characters.';
      }
      if (maxLength != null && value.length > maxLength) {
        return '${parameter.displayName} cannot exceed $maxLength characters.';
      }

      final pattern = validation['pattern']?.toString() ?? '';
      if (pattern.isNotEmpty) {
        try {
          if (!RegExp(pattern).hasMatch(value)) {
            return '${parameter.displayName} has an invalid format.';
          }
        } on FormatException {
          // Invalid metadata should not make the report page unusable.
        }
      }
    }

    if (value is num) {
      final minimum = _validationNumber(
        validation,
        const <String>['min', 'minimum'],
      );
      final maximum = _validationNumber(
        validation,
        const <String>['max', 'maximum'],
      );
      if (minimum != null && value < minimum) {
        return '${parameter.displayName} must be at least $minimum.';
      }
      if (maximum != null && value > maximum) {
        return '${parameter.displayName} cannot be greater than $maximum.';
      }
    }

    if (value is List) {
      final minItems = _validationInt(
        validation,
        const <String>['min_items', 'minItems'],
      );
      final maxItems = _validationInt(
        validation,
        const <String>['max_items', 'maxItems'],
      );
      if (minItems != null && value.length < minItems) {
        return 'Select at least $minItems values for ${parameter.displayName}.';
      }
      if (maxItems != null && value.length > maxItems) {
        return 'Select no more than $maxItems values for ${parameter.displayName}.';
      }
    }

    return null;
  }

  static bool _isEmpty(Object? value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  static int? _validationInt(
    Map<String, dynamic> validation,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = int.tryParse(validation[key]?.toString() ?? '');
      if (value != null) return value;
    }
    return null;
  }

  static num? _validationNumber(
    Map<String, dynamic> validation,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = num.tryParse(validation[key]?.toString() ?? '');
      if (value != null) return value;
    }
    return null;
  }

  static DateTime _financialYearStart(DateTime date) {
    final year = date.month >= 4 ? date.year : date.year - 1;
    return DateTime(year, 4, 1);
  }

  static String _dateText(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class _FilterConversion {
  const _FilterConversion._({
    required this.isValid,
    required this.value,
    required this.error,
  });

  final bool isValid;
  final Object? value;
  final String error;

  factory _FilterConversion.success(Object? value) => _FilterConversion._(
        isValid: true,
        value: value,
        error: '',
      );

  factory _FilterConversion.error(String error) => _FilterConversion._(
        isValid: false,
        value: null,
        error: error,
      );
}
