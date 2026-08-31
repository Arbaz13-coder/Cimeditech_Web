import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/report_configuration_models.dart';
import '../models/report_models.dart';

class ReportRepository {
  const ReportRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<List<ReportCompany>> getCompanies() async {
    final response = await _postRuntime(
      const <String, dynamic>{'operation': 'Companies'},
    );
    final companies = _objectList(response.data['companies'])
        .map(ReportCompany.fromJson)
        .where((item) => item.id > 0)
        .toList(growable: false);
    return companies;
  }

  Future<List<ReportCatalogItem>> getCatalog({
    required int companyId,
  }) async {
    final response = await _postRuntime(<String, dynamic>{
      'operation': 'Catalog',
      'o_id': companyId,
    });
    return _objectList(response.data['reports'])
        .map(ReportCatalogItem.fromJson)
        .where((item) => item.id > 0 && item.code.isNotEmpty)
        .toList(growable: false);
  }

  Future<ReportDefinition> getDefinition({
    required int companyId,
    required String reportCode,
  }) async {
    final response = await _postRuntime(<String, dynamic>{
      'operation': 'Definition',
      'o_id': companyId,
      'report_code': reportCode,
    });
    final report = _asMap(response.data['report']);
    if (report.isEmpty) {
      throw const ApiException(
        'The API returned an empty report definition.',
      );
    }
    return ReportDefinition.fromJson(report);
  }

  Future<List<ReportLookupOption>> lookup({
    required int companyId,
    required String reportCode,
    required String parameterName,
    required String search,
    required Map<String, dynamic> dependencies,
    int limit = 50,
  }) async {
    final response = await _postRuntime(
      <String, dynamic>{
        'operation': 'Lookup',
        'o_id': companyId,
        'report_code': reportCode,
        'parameter_name': parameterName,
        'search': search.trim(),
        'dependencies': dependencies,
        'lookup_limit': limit.clamp(1, 100).toInt(),
      },
      timeout: const Duration(seconds: 45),
    );

    return _objectList(response.data['rows'])
        .map(ReportLookupOption.fromJson)
        .where((item) => item.label.isNotEmpty)
        .toList(growable: false);
  }

  Future<ReportResult> execute({
    required int companyId,
    required String reportCode,
    required Map<String, dynamic> filters,
    required int pageNo,
    required int pageSize,
    required List<ReportSort> sort,
    required int timeoutSeconds,
  }) async {
    final response = await _postRuntime(
      <String, dynamic>{
        'operation': 'Execute',
        'o_id': companyId,
        'report_code': reportCode,
        'filters': filters,
        'page_no': pageNo < 1 ? 1 : pageNo,
        'page_size': pageSize,
        'sort': sort.map((item) => item.toJson()).toList(growable: false),
      },
      timeout: Duration(
        seconds: timeoutSeconds.clamp(10, 900).toInt() + 10,
      ),
    );

    if (response.data['page'] is! Map || response.data['rows'] is! List) {
      throw const ApiException(
        'The API returned an incomplete report result.',
      );
    }
    return ReportResult.fromJson(response.data);
  }

  Future<List<ReportConfigurationSummary>> getConfigurationList() async {
    final response = await _postConfigure(
      const <String, dynamic>{'operation': 'List'},
    );
    return _objectList(response.data['reports'])
        .map(ReportConfigurationSummary.fromJson)
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  Future<ReportConfigurationDraft> getConfiguration({
    required int reportId,
  }) async {
    final response = await _postConfigure(<String, dynamic>{
      'operation': 'Get',
      'report_id': reportId,
    });
    final report = _asMap(response.data['report']);
    if (report.isEmpty) {
      throw const ApiException(
        'The API returned an empty report configuration.',
      );
    }
    return ReportConfigurationDraft.fromJson(report);
  }

  Future<ReportConfigurationSaveResult> saveConfiguration(
    ReportConfigurationDraft configuration,
  ) async {
    final response = await _postConfigure(
      configuration.toPayload(),
      timeout: Duration(
        seconds: configuration.timeoutSeconds.clamp(10, 900).toInt() + 20,
      ),
    );
    return ReportConfigurationSaveResult.fromJson(response.data);
  }

  Future<ApiResponse> _postRuntime(
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _postReport(
      AppConfig.reportRuntimePath,
      data,
      timeout: timeout,
    );
  }

  Future<ApiResponse> _postConfigure(
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 45),
  }) {
    return _postReport(
      AppConfig.reportConfigurePath,
      data,
      timeout: timeout,
    );
  }

  Future<ApiResponse> _postReport(
    String path,
    Map<String, dynamic> data, {
    required Duration timeout,
  }) async {
    final token = (await _tokenStorage.readToken())?.trim() ?? '';
    if (token.isEmpty) {
      throw const ApiException(
        'Your login session is missing. Please login again.',
        statusCode: 401,
      );
    }

    final response = await _apiClient.post(
      path,
      headers: <String, String>{'xRUT': token},
      timeout: timeout,
      body: <String, dynamic>{'RData': data},
    );

    if (!response.isSuccess) {
      final message = response.displayMessage;
      throw ApiException(
        message,
        statusCode: _failureStatusCode(response, message),
      );
    }
    return response;
  }

  int? _failureStatusCode(ApiResponse response, String message) {
    if (response.httpStatusCode == 401 || response.httpStatusCode == 403) {
      return response.httpStatusCode;
    }

    // SGxBrokerAPI can return an RRM failure with HTTP 200 when the token
    // context is no longer valid. Promote only clear authentication failures
    // so the page can return to Login without treating permission errors as an
    // expired session.
    final normalized = message.trim().toLowerCase();
    if (normalized.contains('session has expired') ||
        normalized.contains('login session') ||
        normalized.contains('please login again') ||
        normalized.contains('authentication is required') ||
        normalized.contains('not authenticated')) {
      return 401;
    }
    return response.httpStatusCode == 200 ? null : response.httpStatusCode;
  }

  List<Map<String, dynamic>> _objectList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ))
        .toList(growable: false);
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) return const <String, dynamic>{};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
}
