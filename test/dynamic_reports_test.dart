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

    test('accepts comma-separated typed function array values', () {
      final parameters = <ReportParameter>[
        ReportParameter.fromJson(
          _parameterJson('ledgerIds', 'Ledgers', 'ID_LIST')
            ..['allow_multiple'] = true
            ..['database_type'] = 'bigint[]',
        ),
        ReportParameter.fromJson(
          _parameterJson('rates', 'Rates', 'DECIMAL_LIST', order: 2)
            ..['allow_multiple'] = true
            ..['database_type'] = 'numeric[]',
        ),
      ];

      final result = ReportFilterCodec.build(
        parameters,
        <String, dynamic>{
          'ledgerIds': '10, 20,30',
          'rates': '68.50, 72.25',
        },
      );

      expect(result.isValid, isTrue);
      expect(result.filters['ledgerIds'], <int>[10, 20, 30]);
      expect(result.filters['rates'], <num>[68.5, 72.25]);
    });
  });

  test('parses an auto-configured typed report definition', () {
    final definition = ReportDefinition.fromJson(<String, dynamic>{
      'report_id': 11,
      'report_name': 'Ledger Report',
      'display_name': 'Ledger Report',
      'report_code': 'accounts.ledger',
      'report_type': 'TABLE',
      'report_subtype': 'Accounts',
      'is_default': false,
      'is_active': true,
      'can_export': true,
      'default_page_size': 100,
      'max_page_size': 500,
      'timeout_seconds': 60,
      'definition_version': 2,
      'engine_version': 2,
      'parameters': <Map<String, dynamic>>[
        _parameterJson('ledgerIds', 'Ledgers', 'ID_LIST')
          ..['database_type'] = 'bigint[]'
          ..['ui_element_type'] = 'REMOTE_MULTISELECT'
          ..['allow_multiple'] = true,
      ],
      'columns': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'ledger_name',
          'display_name': 'Ledger Name',
          'display_order': 1,
          'data_type': 'STRING',
          'database_type': 'text',
          'format': 'TEXT',
          'alignment': 'LEFT',
          'width': 220,
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
    });

    expect(definition.engineVersion, 2);
    expect(definition.parameters.single.databaseType, 'bigint[]');
    expect(definition.parameters.single.usesRemoteLookup, isTrue);
    expect(definition.columns.single.databaseType, 'text');
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
