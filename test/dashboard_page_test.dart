import 'package:cmx_web_portal/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDashboard(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the main business dashboard sections', (tester) async {
    await pumpDashboard(tester, const Size(1440, 1200));

    expect(find.text('Business Snapshot'), findsOneWidget);
    expect(find.text('Total Receivables'), findsOneWidget);
    expect(find.text('Total Payables'), findsOneWidget);
    expect(find.text('Inventory Value'), findsOneWidget);
    expect(find.text('Sales Performance'), findsOneWidget);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('Inventory Health'), findsOneWidget);
    expect(find.text('Top Outstanding Customers'), findsOneWidget);
  });

  testWidgets('remains usable on a narrow viewport', (tester) async {
    await pumpDashboard(tester, const Size(390, 900));

    expect(find.text('Business Snapshot'), findsOneWidget);
    expect(find.text('Demo Company Pvt Ltd'), findsOneWidget);
    expect(find.text('Total Receivables'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
