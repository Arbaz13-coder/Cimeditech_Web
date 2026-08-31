import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/user_mapping_models.dart';

class UserMappingRepository {
  const UserMappingRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<List<PortalCompany>> getCompanies() async {
    final response = await _postPath(
      AppConfig.companyWithUserPath,
      action: 'L',
      data: const <String, dynamic>{},
    );
    _ensureSuccess(response);

    final rawCompanies = response.data['CompanyList'];
    if (rawCompanies is! List) return const <PortalCompany>[];

    return rawCompanies
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry(key.toString(), value)))
        .map(PortalCompany.fromJson)
        .where((company) => company.id > 0)
        .toList(growable: false);
  }

  Future<List<UserMappingMasterType>> getMasterTypes() async {
    final response = await _postUserMapping(
      'mastertypes',
      action: 'L',
      data: const <String, dynamic>{},
    );
    _ensureSuccess(response);

    return _rows(response.data)
        .map(UserMappingMasterType.fromJson)
        .where((item) => item.type.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<UserMappingUser>> getUsers({
    required int companyId,
    String search = '',
  }) async {
    final response = await _postUserMapping(
      'users',
      action: 'L',
      data: <String, dynamic>{
        'company_id': companyId,
        'Search': search.trim(),
      },
    );
    _ensureSuccess(response);

    return _rows(response.data)
        .map(UserMappingUser.fromJson)
        .where((item) => item.id > 0)
        .toList(growable: false);
  }

  Future<UserMappingPageData> getMapping({
    required int userId,
    required int companyId,
    required String masterType,
    String search = '',
    int pageNo = 1,
    int pageSize = 100,
  }) async {
    final response = await _postUserMapping(
      'get',
      action: 'L',
      data: <String, dynamic>{
        'user_id': userId,
        'company_id': companyId,
        'master_type': masterType,
        'Search': search.trim(),
        'RPageNo': pageNo,
        'RPageSize': pageSize.clamp(1, 500),
      },
    );
    _ensureSuccess(response);
    return UserMappingPageData.fromJson(response.data);
  }

  Future<ApiResponse> saveMapping({
    required int userId,
    required int companyId,
    required String masterType,
    required bool selectAll,
    required Set<int> selectedIds,
  }) async {
    final response = await _postUserMapping(
      'save',
      action: 'IUO',
      data: <String, dynamic>{
        'user_id': userId,
        'company_id': companyId,
        'master_type': masterType,
        'select_all': selectAll,
        'select_value': selectAll ? <int>[] : (selectedIds.toList()..sort()),
      },
    );
    _ensureSuccess(response);
    return response;
  }

  Future<ApiResponse> _postUserMapping(
    String actionName, {
    required String action,
    required Map<String, dynamic> data,
  }) {
    return _postPath(
      AppConfig.userMappingPath(actionName),
      action: action,
      data: data,
    );
  }

  Future<ApiResponse> _postPath(
    String path, {
    required String action,
    required Map<String, dynamic> data,
  }) async {
    final token = (await _tokenStorage.readToken())?.trim() ?? '';
    if (token.isEmpty) {
      throw const ApiException('Your login session is missing. Please login again.');
    }

    return _apiClient.post(
      path,
      headers: <String, String>{'xRUT': token},
      body: <String, dynamic>{
        'Status': 'Failed',
        'Org': '',
        'OrgId': 0,
        'Text': '',
        'ID': 0,
        'RefNo': '',
        'Message': '',
        'ErrorMsg': '',
        'RAction': action,
        'RData': data,
      },
    );
  }

  void _ensureSuccess(ApiResponse response) {
    if (!response.isSuccess) {
      throw ApiException(
        response.displayMessage,
        statusCode: response.httpStatusCode,
      );
    }
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> data) {
    final rawRows = data['vRows'];
    if (rawRows is! List) return const <Map<String, dynamic>>[];

    return rawRows
        .whereType<Map>()
        .map(
          (row) => row.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList(growable: false);
  }
}
