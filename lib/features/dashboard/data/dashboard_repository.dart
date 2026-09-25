import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../reports/models/report_models.dart';
import '../models/dashboard_snapshot.dart';

abstract interface class DashboardSource {
  Future<List<ReportCompany>> companies();
  Future<DashboardSnapshot> overview({
    required int companyId,
    required DateTime from,
    required DateTime to,
  });
}

class DashboardRepository implements DashboardSource {
  DashboardRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  }) : _client = apiClient,
       _storage = tokenStorage;
  final ApiClient _client;
  final TokenStorage _storage;
  @override
  Future<List<ReportCompany>> companies() async {
    final d = await _post({'operation': 'Companies'});
    if (d['companies'] is! List) {
      throw const ApiException('The API did not return a company list.');
    }
    return dashboardRows(
      d['companies'],
    ).map(ReportCompany.fromJson).where((c) => c.id > 0).toList();
  }

  @override
  Future<DashboardSnapshot> overview({
    required int companyId,
    required DateTime from,
    required DateTime to,
  }) async {
    final d = DashboardSnapshot(
      await _post({
        'operation': 'Overview',
        'o_id': companyId,
        'from_date': dashboardIsoDate(from),
        'to_date': dashboardIsoDate(to),
      }),
    );
    if (d.companyId != companyId ||
        d.text('from_date') != dashboardIsoDate(from) ||
        d.text('to_date') != dashboardIsoDate(to)) {
      throw const ApiException(
        'The API returned a different company or period. Please retry.',
      );
    }
    return d;
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> data) async {
    final token = await _storage.readToken();
    if (token == null || token.trim().isEmpty) {
      throw const ApiException(
        'Your session has expired. Please login again.',
        statusCode: 401,
      );
    }
    final r = await _client.post(
      '/api/app/${AppConfig.apiVar}/dashboard/runtime',
      body: {'RData': data},
      headers: {'xRUT': token},
      timeout: const Duration(seconds: 30),
    );
    if (!r.isSuccess) {
      throw ApiException(
        r.displayMessage,
        statusCode: r.data['error_code'] == 'AUTH_REQUIRED'
            ? 401
            : r.httpStatusCode,
      );
    }
    return r.data;
  }
}
