import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cmx_web_portal/core/models/api_response.dart';
import 'package:cmx_web_portal/features/dashboard/data/dashboard_repository.dart';
import 'package:cmx_web_portal/features/dashboard/models/dashboard_snapshot.dart';
import 'package:cmx_web_portal/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:cmx_web_portal/features/reports/models/report_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardSnapshot snapshot([int id = 11]) {
  final d =
      jsonDecode(
            File('test/fixtures/dashboard_response.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  d['o_id'] = id;
  if (id == 12) d['activity']['current']['sales'] = 777;
  return DashboardSnapshot(d);
}

class Source implements DashboardSource {
  List<int> ids = [11, 12, 15];
  Object? failure;
  final pending = <int, Completer<DashboardSnapshot>>{};
  final requests = <int>[];
  final dateRequests = <({int company, DateTime from, DateTime to})>[];
  @override
  Future<List<ReportCompany>> companies() async {
    if (failure != null) throw failure!;
    return ids
        .map(
          (id) => ReportCompany(
            id: id,
            name: 'Company $id',
            displayName: '',
            tradeName: '',
            lastSyncOn: null,
          ),
        )
        .toList();
  }

  @override
  Future<DashboardSnapshot> overview({
    required int companyId,
    required DateTime from,
    required DateTime to,
  }) async {
    requests.add(companyId);
    dateRequests.add((company: companyId, from: from, to: to));
    if (failure != null) throw failure!;
    if (pending[companyId] case final waiting?) return waiting.future;
    final result = snapshot(companyId);
    result.data['from_date'] = dashboardIsoDate(from);
    result.data['to_date'] = dashboardIsoDate(to);
    return result;
  }
}

void main() {
  Future<void> pump(
    WidgetTester t,
    Source s, {
    Size size = const Size(1440, 1000),
    VoidCallback? expired,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(repository: s, onSessionExpired: expired),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  testWidgets('live desktop values, no demo figures', (t) async {
    final s = Source();
    await pump(t, s);
    await t.pumpAndSettle();
    expect(s.requests, [11]);
    expect(find.text('Business Snapshot'), findsOneWidget);
    expect(find.text('₹300.00'), findsWidgets);
    expect(find.text('Demo Company Pvt Ltd'), findsNothing);
    expect(find.text('Inventory Health'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('narrow layout remains usable while scrolling all sections', (
    t,
  ) async {
    await pump(t, Source(), size: const Size(390, 900));
    await t.pumpAndSettle();
    for (var i = 0; i < 8; i++) {
      await t.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -650),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
    expect(find.text('Recent Transactions'), findsOneWidget);
  });
  testWidgets('dropdown includes the third company', (t) async {
    await pump(t, Source());
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pumpAndSettle();
    expect(find.text('Company 15'), findsOneWidget);
  });
  testWidgets('old response cannot replace a new company', (t) async {
    final s = Source();
    s.pending[11] = Completer();
    s.pending[12] = Completer();
    await pump(t, s);
    expect(find.text('Loading your dashboard'), findsOneWidget);
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Company 12').last);
    await t.pump(const Duration(milliseconds: 300));
    s.pending[12]!.complete(snapshot(12));
    await t.pumpAndSettle();
    expect(find.text('₹777.00'), findsWidgets);
    s.pending[11]!.complete(snapshot(11));
    await t.pumpAndSettle();
    expect(find.text('₹777.00'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('network error retry recovers', (t) async {
    final s = Source()..failure = const ApiException('Network unavailable');
    await pump(t, s);
    await t.pumpAndSettle();
    expect(find.text('Network unavailable'), findsOneWidget);
    expect(find.text('Total Receivables'), findsNothing);
    s.failure = null;
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(find.text('Total Receivables'), findsOneWidget);
  });
  testWidgets('empty companies do not show fabricated zero totals', (t) async {
    await pump(t, Source()..ids = []);
    await t.pumpAndSettle();
    expect(find.text('No companies assigned'), findsOneWidget);
    expect(find.text('Total Receivables'), findsNothing);
  });
  testWidgets('expired session triggers login once', (t) async {
    var calls = 0;
    await pump(
      t,
      Source()..failure = const ApiException('Login again', statusCode: 401),
      expired: () => calls++,
    );
    await t.pumpAndSettle();
    expect(calls, 1);
  });
  testWidgets('permission error clears old values', (t) async {
    final s = Source();
    await pump(t, s);
    await t.pumpAndSettle();
    s.failure = const ApiException('Access revoked', statusCode: 403);
    await t.tap(find.text('Refresh'));
    await t.pumpAndSettle();
    expect(find.text('Access revoked'), findsOneWidget);
    expect(find.text('Total Receivables'), findsNothing);
  });
  Future<void> enterDates(WidgetTester t, String from, String to) async {
    await t.enterText(find.byKey(const ValueKey('dashboard-from-date')), from);
    await t.enterText(find.byKey(const ValueKey('dashboard-to-date')), to);
    await t.pump();
  }

  Future<void> applyDates(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('apply-dashboard-dates')));
    await t.pumpAndSettle();
  }

  testWidgets(
    'custom dates apply exactly and survive refresh and company change',
    (t) async {
      final s = Source();
      await pump(t, s);
      await t.pumpAndSettle();
      await enterDates(t, '01/04/2024', '30/06/2024');
      expect(find.text('Custom'), findsOneWidget);
      expect(s.requests.length, 1);
      expect(
        find.text('Dates changed. Click Apply to update the dashboard.'),
        findsOneWidget,
      );
      final download = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Download summary'),
      );
      expect(download.onPressed, isNull);
      await applyDates(t);
      expect(s.dateRequests.last, (
        company: 11,
        from: DateTime.utc(2024, 4, 1),
        to: DateTime.utc(2024, 6, 30),
      ));
      expect(
        find.textContaining('Period: 01/04/2024 – 30/06/2024'),
        findsOneWidget,
      );
      await t.tap(find.text('Refresh'));
      await t.pumpAndSettle();
      expect(s.dateRequests.last.from, DateTime.utc(2024, 4, 1));
      expect(s.dateRequests.last.to, DateTime.utc(2024, 6, 30));
      await t.tap(find.byType(DropdownButtonFormField<int>));
      await t.pumpAndSettle();
      await t.tap(find.text('Company 12').last);
      await t.pumpAndSettle();
      expect(s.dateRequests.last, (
        company: 12,
        from: DateTime.utc(2024, 4, 1),
        to: DateTime.utc(2024, 6, 30),
      ));
    },
  );

  testWidgets(
    'period preset fills both dates and reloads after custom editing',
    (t) async {
      final s = Source();
      await pump(t, s);
      await t.pumpAndSettle();
      await enterDates(t, '01/04/2024', '30/06/2024');
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Last Month').last);
      await t.pumpAndSettle();
      final range = dashboardPeriod('Last Month', DateTime.now().toUtc());
      expect(s.dateRequests.last.from, range.from);
      expect(s.dateRequests.last.to, range.to);
      expect(
        t
            .widget<TextField>(
              find.byKey(const ValueKey('dashboard-from-date')),
            )
            .controller!
            .text,
        dashboardDate(range.from.toIso8601String()),
      );
      expect(
        t
            .widget<TextField>(find.byKey(const ValueKey('dashboard-to-date')))
            .controller!
            .text,
        dashboardDate(range.to.toIso8601String()),
      );
      expect(
        find.text('Dates changed. Click Apply to update the dashboard.'),
        findsNothing,
      );
      expect(s.requests.length, 2);
    },
  );

  testWidgets(
    'invalid date ranges do not call API; 366 inclusive days are allowed',
    (t) async {
      final s = Source();
      await pump(t, s);
      await t.pumpAndSettle();
      final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
      for (final example in [
        (
          '31/02/2024',
          '01/03/2024',
          'Enter valid From Date and To Date in DD/MM/YYYY format.',
        ),
        (
          '',
          '01/03/2024',
          'Enter valid From Date and To Date in DD/MM/YYYY format.',
        ),
        ('02/04/2024', '01/04/2024', 'From Date must be on or before To Date.'),
        (
          '01/01/2024',
          '01/01/2025',
          'Select a date range of at most 366 days.',
        ),
        (
          '01/01/2024',
          dashboardDate(tomorrow.toIso8601String()),
          'To Date cannot be later than today (UTC).',
        ),
      ]) {
        await enterDates(t, example.$1, example.$2);
        await applyDates(t);
        expect(find.text(example.$3), findsOneWidget);
        expect(s.requests.length, 1);
      }
      await enterDates(t, '01/01/2024', '31/12/2024');
      await applyDates(t);
      expect(s.requests.length, 2);
      expect(
        s.dateRequests.last.to.difference(s.dateRequests.last.from).inDays,
        365,
      );
    },
  );

  testWidgets('calendar selection updates custom dates and waits for Apply', (
    t,
  ) async {
    final s = Source();
    await pump(t, s);
    await t.pumpAndSettle();
    await enterDates(t, '01/01/2024', '31/01/2024');
    await t.tap(find.byTooltip('Choose From Date'));
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await t.tap(find.text('15').last);
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(find.byKey(const ValueKey('dashboard-from-date')))
          .controller!
          .text,
      '15/01/2024',
    );
    expect(s.requests.length, 1);
    await applyDates(t);
    expect(s.dateRequests.last.from, DateTime.utc(2024, 1, 15));
    expect(s.dateRequests.last.to, DateTime.utc(2024, 1, 31));
    expect(t.takeException(), isNull);
  });
  test('financial year, previous month, rolling dates', () {
    expect(
      dashboardIsoDate(
        dashboardPeriod('Current FY', DateTime.utc(2026, 3, 31)).from,
      ),
      '2025-04-01',
    );
    expect(
      dashboardIsoDate(
        dashboardPeriod('Current FY', DateTime.utc(2026, 4, 1)).from,
      ),
      '2026-04-01',
    );
    final p = dashboardPeriod('Last Month', DateTime.utc(2026, 1, 15));
    expect(dashboardIsoDate(p.from), '2025-12-01');
    expect(dashboardIsoDate(p.to), '2025-12-31');
    final days = dashboardPeriod('Last 90 Days', DateTime.utc(2026, 9, 30));
    expect(days.to.difference(days.from).inDays, 89);
  });
  test('invalid response and zero baseline', () {
    expect(() => DashboardSnapshot({}), throwsA(isA<ApiException>()));
    expect(snapshot().change('sales'), 500);
    expect(snapshot().change('payments'), isNull);
  });
}
