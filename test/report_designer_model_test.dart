import 'package:cmx_web_portal/features/report_designer/data/mock_report_data.dart';
import 'package:cmx_web_portal/features/report_designer/models/report_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default report templates contain detail fields', () {
    for (final template in MockReportData.templates) {
      expect(
        template.elements.any((element) => element.zone == ReportZone.detail),
        isTrue,
        reason: '${template.name} must contain at least one detail field',
      );
    }
  });

  test('all template bindings exist in backend field metadata', () {
    final keys = MockReportData.backendFields.map((field) => field.key).toSet();
    for (final template in MockReportData.templates) {
      for (final element in template.elements) {
        expect(keys.contains(element.fieldKey), isTrue);
      }
    }
  });
}
