import 'package:cmx_web_portal/features/user_mapping/models/user_mapping_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses company returned by GetRegCompanyWithUser', () {
    final company = PortalCompany.fromJson({
      'O_id': 3,
      'O_name': 'CMX Industries',
      'O_acc_books_start_xdt': '2026-04-01T00:00:00',
    });

    expect(company.id, 3);
    expect(company.name, 'CMX Industries');
  });

  test('parses complete mapping selection and rows', () {
    final mapping = UserMappingPageData.fromJson({
      'user_id': 15,
      'company_id': 3,
      'master_type': 'Item',
      'select_all': false,
      'select_value': [101, 102, 105],
      'RCount': 6,
      'RPageNo': 1,
      'RPageSize': 100,
      'RTotalPages': 1,
      'vRows': [
        {
          'Id': 101,
          'Name': 'MS PIPE',
          'Group': 'PIPE',
          'IsSelected': true,
        },
      ],
    });

    expect(mapping.selectedIds, {101, 102, 105});
    expect(mapping.rows.single.name, 'MS PIPE');
    expect(mapping.rows.single.isSelected, isTrue);
  });
}
