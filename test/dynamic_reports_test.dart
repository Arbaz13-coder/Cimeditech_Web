import 'package:cmx_web_portal/features/reports/models/report_configuration_models.dart';
import 'package:cmx_web_portal/features/reports/models/report_models.dart';
import 'package:cmx_web_portal/features/reports/services/dynamic_report_formatter.dart';
import 'package:cmx_web_portal/features/reports/services/report_filter_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dynamic report models', () {
    test('parses a report definition and keeps display order', () {
      final definition = ReportDefinition.fromJson(<String, dynamic>{
        'report_id': 7,
        'report_name': 'Sales Register',
        'display_name': 'Sales Register',
        'report_code': 'sales.register',
        'report_type': 'TABLE',
        'report_subtype': 'Sales',
        'is_active': true,
        'can_export': true,
        'default_page_size': 100,
        'max_page_size': 500,
        'timeout_seconds': 60,
        'definition_version': 3,
        'parameters': <Map<String, dynamic>>[
          <String, dynamic>{
            'parameter_id': 2,
            'name': 'toDate',
            'display_name': 'To Date',
            'data_type': 'DATE',
            'ui_element_type': 'DATE_PICKER',
            'display_order': 2,
            'is_required': true,
            'allow_multiple': false,
            'validation': <String, dynamic>{},
            'dependencies': <String>[],
            'has_data_function': false,
            'is_active': true,
          },
          <String, dynamic>{
            'parameter_id': 1,
            'name': 'fromDate',
            'display_name': 'From Date',
            'data_type': 'DATE',
            'ui_element_type': 'DATE_PICKER',
            'display_order': 1,
            'is_required': true,
            'allow_multiple': false,
            'validation': <String, dynamic>{},
            'dependencies': <String>[],
            'has_data_function': false,
            'is_active': true,
          },
        ],
        'columns': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'amount',
            'display_name': 'Amount',
            'display_order': 2,
            'data_type': 'DECIMAL',
            'format': 'CURRENCY_2',
            'alignment': 'RIGHT',
            'is_visible': true,
            'is_sortable': false,
            'is_exportable': true,
            'is_active': true,
          },
          <String, dynamic>{
            'name': 'voucher_date',
            'display_name': 'Voucher Date',
            'display_order': 1,
            'data_type': 'DATE',
            'format': 'DATE',
            'alignment': 'LEFT',
            'is_visible': true,
            'is_sortable': true,
            'is_exportable': true,
            'is_active': true,
          },
        ],
        'actions': <Map<String, dynamic>>[],
      });

      expect(definition.id, 7);
      expect(definition.parameters.map((item) => item.name), <String>[
        'fromDate',
        'toDate',
      ]);
      expect(definition.columns.map((item) => item.name), <String>[
        'voucher_date',
        'amount',
      ]);
      expect(definition.canExport, isTrue);
    });

    test('parses paged execution results', () {
      final result = ReportResult.fromJson(<String, dynamic>{
        'report_id': 7,
        'report_code': 'sales.register',
        'display_name': 'Sales Register',
        'definition_version': 3,
        'o_id': 10,
        'columns': <Map<String, dynamic>>[],
        'rows': <Map<String, dynamic>>[
          <String, dynamic>{'voucher_no': 'S-001'},
        ],
        'summary': <String, dynamic>{'total_amount': 1250.50},
        'page': <String, dynamic>{
          'page_no': 1,
          'page_size': 100,
          'row_count': 1,
          'has_more': false,
          'total_count': 1,
          'total_pages': 1,
        },
        'execution_id': 99,
      });

      expect(result.rows.single['voucher_no'], 'S-001');
      expect(result.page.totalCount, 1);
      expect(result.executionId, 99);
    });
  });

  group('report configuration models', () {
    test('parses configuration children and creates a complete save payload', () {
      final draft = ReportConfigurationDraft.fromJson(<String, dynamic>{
        'report_id': 7,
        'report_name': 'Sales Register',
        'display_name': 'Sales Register',
        'report_code': 'sales.register',
        'report_type': 'TABLE',
        'report_subtype': 'Sales',
        'data_function': 'rpt.fn_sales_register',
        'is_default': false,
        'is_active': true,
        'default_page_size': 100,
        'max_page_size': 500,
        'timeout_seconds': 60,
        'definition_version': 4,
        'parameters': <Map<String, dynamic>>[
          <String, dynamic>{
            ..._parameterJson('fromDate', 'From Date', 'DATE'),
            'data_function': null,
          },
        ],
        'columns': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'voucher_date',
            'display_name': 'Voucher Date',
            'display_order': 1,
            'data_type': 'DATE',
            'format': 'DATE',
            'alignment': 'LEFT',
            'width': 120,
            'is_visible': true,
            'is_sortable': true,
            'is_filterable': false,
            'is_exportable': true,
            'is_total': false,
            'aggregate_type': '',
            'is_active': true,
          },
        ],
        'actions': <Map<String, dynamic>>[],
        'assignments': <Map<String, dynamic>>[
          <String, dynamic>{
            'r_id': 2,
            'o_id': 10,
            'u_id': null,
            'can_view': true,
            'can_export': true,
            'is_active': true,
          },
        ],
      });

      expect(draft.validate().isValid, isTrue);
      final payload = draft.toPayload();
      expect(payload['operation'], 'Save');
      expect((payload['parameters'] as List).length, 1);
      expect((payload['columns'] as List).length, 1);
      expect(
        ((payload['assignments'] as List).single as Map)['u_id'],
        isNull,
      );
    });

    test('requires an assignment for an active non-default report', () {
      final draft = ReportConfigurationDraft.empty()
        ..reportName = 'Example'
        ..displayName = 'Example'
        ..reportCode = 'example.report'
        ..dataFunction = 'rpt.fn_example_report'
        ..columns.add(ReportColumnDraft.empty(1));

      final validation = draft.validate();
      expect(validation.isValid, isFalse);
      expect(
        validation.errors,
        contains(
          'An active non-default report needs a view-enabled assignment.',
        ),
      );
    });

    test('accepts backend-compatible zero order and server-context RID', () {
      final draft = ReportConfigurationDraft.empty()
        ..reportName = 'Example'
        ..displayName = 'Example'
        ..reportCode = 'EXAMPLE.REPORT'
        ..dataFunction = 'RPT.FN_EXAMPLE_REPORT'
        ..columns.add(ReportColumnDraft.empty(0))
        ..assignments.add(ReportAssignmentDraft.empty()..oId = 10);

      expect(draft.validate().isValid, isTrue);
      final assignment = (draft.toPayload()['assignments'] as List).single as Map;
      expect(assignment['r_id'], 0);
      expect(assignment['o_id'], 10);
    });
  });

  group('report filter codec', () {
    test('creates accounting date defaults for required date fields', () {
      final definition = ReportDefinition.fromJson(<String, dynamic>{
        'report_id': 1,
        'report_name': 'Example',
        'display_name': 'Example',
        'report_code': 'example.report',
        'report_type': 'TABLE',
        'is_active': true,
        'default_page_size': 100,
        'max_page_size': 500,
        'timeout_seconds': 60,
        'parameters': <Map<String, dynamic>>[
          _parameterJson('fromDate', 'From Date', 'DATE'),
          _parameterJson('toDate', 'To Date', 'DATE', order: 2),
        ],
        'columns': <Map<String, dynamic>>[],
        'actions': <Map<String, dynamic>>[],
      });

      final values = ReportFilterCodec.initialValues(
        definition,
        now: DateTime(2026, 8, 26),
      );

      expect(values['fromDate'], '2026-04-01');
      expect(values['toDate'], '2026-08-26');
    });

    test('normalizes IDs, decimals and lookup selections', () {
      final parameters = <ReportParameter>[
        ReportParameter.fromJson(
          _parameterJson('partyIds', 'Parties', 'ID_LIST')
            ..['allow_multiple'] = true,
        ),
        ReportParameter.fromJson(
          _parameterJson('minimum', 'Minimum', 'DECIMAL', order: 2)
            ..['validation'] = <String, dynamic>{'min': 0},
        ),
      ];
      final result = ReportFilterCodec.build(
        parameters,
        <String, dynamic>{
          'partyIds': const <ReportLookupOption>[
            ReportLookupOption(value: '12', label: 'ABC Traders'),
            ReportLookupOption(value: 15, label: 'XYZ Traders'),
          ],
          'minimum': '125.50',
        },
      );

      expect(result.isValid, isTrue);
      expect(result.filters['partyIds'], <int>[12, 15]);
      expect(result.filters['minimum'], 125.5);
    });

    test('returns field errors for missing required values', () {
      final parameter = ReportParameter.fromJson(
        _parameterJson('party', 'Party', 'STRING'),
      );
      final result = ReportFilterCodec.build(
        <ReportParameter>[parameter],
        const <String, dynamic>{},
      );

      expect(result.isValid, isFalse);
      expect(result.errors['party'], 'Party is required.');
    });
  });

  test('formats report values and produces escaped CSV', () {
    const amountColumn = ReportColumn(
      name: 'amount',
      displayName: 'Amount',
      displayOrder: 1,
      dataType: 'DECIMAL',
      format: 'CURRENCY_2',
      alignment: 'RIGHT',
      width: 140,
      isVisible: true,
      isSortable: false,
      isFilterable: false,
      isExportable: true,
      isTotal: true,
      aggregateType: 'SUM',
      isActive: true,
    );

    expect(DynamicReportFormatter.format(1234.5, amountColumn), '₹ 1,234.50');
    expect(
      DynamicReportFormatter.toCsv(
        <Map<String, dynamic>>[
          <String, dynamic>{'amount': 1234.5},
        ],
        const <ReportColumn>[amountColumn],
      ),
      '"Amount"\r\n"₹ 1,234.50"',
    );
  });

  test('protects copied text columns from spreadsheet formulas', () {
    const textColumn = ReportColumn(
      name: 'party_name',
      displayName: 'Party',
      displayOrder: 1,
      dataType: 'STRING',
      format: 'TEXT',
      alignment: 'LEFT',
      width: 180,
      isVisible: true,
      isSortable: false,
      isFilterable: false,
      isExportable: true,
      isTotal: false,
      aggregateType: '',
      isActive: true,
    );

    expect(
      DynamicReportFormatter.toCsv(
        <Map<String, dynamic>>[
          <String, dynamic>{'party_name': '=HYPERLINK("bad")'},
        ],
        const <ReportColumn>[textColumn],
      ),
      '"Party"\r\n"\'=HYPERLINK(""bad"")"',
    );
  });
}

Map<String, dynamic> _parameterJson(
  String name,
  String displayName,
  String dataType, {
  int order = 1,
}) {
  return <String, dynamic>{
    'parameter_id': order,
    'name': name,
    'display_name': displayName,
    'data_type': dataType,
    'ui_element_type': dataType == 'DATE' ? 'DATE_PICKER' : 'TEXTBOX',
    'display_order': order,
    'is_required': true,
    'allow_multiple': false,
    'default_value': null,
    'validation': <String, dynamic>{},
    'dependencies': <String>[],
    'has_data_function': false,
    'is_active': true,
  };
}
