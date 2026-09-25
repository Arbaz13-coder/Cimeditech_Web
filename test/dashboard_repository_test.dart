import 'dart:convert';
import 'dart:io';

import 'package:cmx_web_portal/core/models/api_response.dart';
import 'package:cmx_web_portal/core/network/api_client.dart';
import 'package:cmx_web_portal/core/storage/token_storage.dart';
import 'package:cmx_web_portal/features/dashboard/data/dashboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoryToken extends TokenStorage {
  const MemoryToken(this.value);
  final String? value;
  @override
  Future<String?> readToken() async => value;
}

void main() {
  String response() => jsonEncode({
    'Status': 'Success',
    'RData': jsonDecode(
      File('test/fixtures/dashboard_response.json').readAsStringSync(),
    ),
  });
  test('API contract sends token without trusted identity fields', () async {
    late http.Request sent;
    final client = ApiClient(
      client: MockClient((r) async {
        sent = r;
        return http.Response(
          response(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(client.dispose);
    final repo = DashboardRepository(
      apiClient: client,
      tokenStorage: const MemoryToken('test-token'),
    );
    expect(
      (await repo.overview(
        companyId: 11,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      )).number('activity.current.sales'),
      300,
    );
    expect(sent.url.path, '/api/app/v1/dashboard/runtime');
    expect(sent.headers['xrut'], 'test-token');
    expect(jsonDecode(sent.body), {
      'RData': {
        'operation': 'Overview',
        'o_id': 11,
        'from_date': '2026-09-01',
        'to_date': '2026-09-30',
      },
    });
  });
  test('incomplete totals cannot be displayed as zero balances', () async {
    final broken = jsonDecode(response()) as Map<String, dynamic>;
    broken['RData']['activity'] = <String, dynamic>{};
    final client = ApiClient(
      client: MockClient(
        (r) async => http.Response(
          jsonEncode(broken),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(client.dispose);
    final repo = DashboardRepository(
      apiClient: client,
      tokenStorage: const MemoryToken('x'),
    );
    await expectLater(
      repo.overview(
        companyId: 11,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Incomplete dashboard totals'),
        ),
      ),
    );
  });
  test('wrong company response is rejected', () async {
    final client = ApiClient(
      client: MockClient(
        (r) async => http.Response(
          response(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(client.dispose);
    final repo = DashboardRepository(
      apiClient: client,
      tokenStorage: const MemoryToken('x'),
    );
    await expectLater(
      repo.overview(
        companyId: 12,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('different company or period'),
        ),
      ),
    );
  });
  test('missing token does not call API', () async {
    final client = ApiClient(
      client: MockClient((r) async {
        fail('HTTP should not run');
      }),
    );
    addTearDown(client.dispose);
    final repo = DashboardRepository(
      apiClient: client,
      tokenStorage: const MemoryToken(null),
    );
    await expectLater(
      repo.companies(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
  });
  test('HTTP and business errors cannot become empty data', () async {
    for (final code in [200, 403, 503]) {
      final client = ApiClient(
        client: MockClient(
          (r) async => http.Response(
            '{"Status":"Failed","Message":"Unavailable","RData":{}}',
            code,
          ),
        ),
      );
      final repo = DashboardRepository(
        apiClient: client,
        tokenStorage: const MemoryToken('x'),
      );
      await expectLater(repo.companies(), throwsA(isA<ApiException>()));
      client.dispose();
    }
  });
}
