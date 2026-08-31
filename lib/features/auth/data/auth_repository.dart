import '../../../core/config/app_config.dart';
import '../../../core/models/api_response.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/signup_draft.dart';

class AuthRepository {
  const AuthRepository({
    required ApiClient apiClient,
    required TokenStorage tokenStorage,
  })  : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<void> clearSession() => _tokenStorage.clear();

  Future<ApiResponse> login({
    required String loginId,
    required String password,
  }) async {
    final response = await _apiClient.post(
      AppConfig.accountPath('login'),
      body: <String, dynamic>{
        'RData': <String, dynamic>{
          'U_login_type': AppConfig.loginType,
          'U_login_sub_type': AppConfig.loginSubType,
          'U_login_key': 'MobileOrEmail',
          'U_DeviceID': '',
          'U_loginid': loginId.trim(),
          'U_pwd': password,
        },
      },
    );

    if (response.isSuccess) {
      final token = response.data['SvToken']?.toString() ?? '';
      if (token.isNotEmpty) {
        await _tokenStorage.saveToken(token);
      }
    }

    return response;
  }

  Future<ApiResponse> validateSignup(SignupDraft draft) {
    return _apiClient.post(
      AppConfig.accountPath('isvalidate'),
      body: _rrm(data: draft.toApiJson()),
    );
  }

  Future<RegistrationOtpSession> sendRegistrationOtp(
    SignupDraft draft,
  ) async {
    final validation = await validateSignup(draft);
    if (!validation.isSuccess) {
      throw ApiException(validation.displayMessage);
    }

    final response = await _apiClient.post(
      AppConfig.ausPath('sendregotptoverifyuser'),
      headers: _apiClient.ausHeaders,
      body: _rrm(
        data: <String, dynamic>{
          'Name': draft.name,
          'MobileNo': draft.mobile,
          'EmailID': draft.email,
        },
      ),
    );

    if (!response.isSuccess) {
      throw ApiException(response.displayMessage);
    }

    final verifyToken = response.data['OtpVerifyToken']?.toString() ?? '';
    if (verifyToken.isEmpty) {
      throw const ApiException(
        'OTP verification token was not returned by the API.',
      );
    }

    return RegistrationOtpSession(
      draft: draft,
      verifyToken: verifyToken,
    );
  }

  Future<ApiResponse> completeSignup({
    required RegistrationOtpSession session,
    required String otp,
  }) {
    return _apiClient.post(
      AppConfig.accountPath('signup'),
      body: _rrm(
        text: session.verifyToken,
        message: '${session.draft.mobile}|${otp.trim()}',
        data: session.draft.toApiJson(),
      ),
    );
  }

  Future<ResetOtpSession> sendResetPasswordOtp(
    String mobileOrEmail,
  ) async {
    final identifier = mobileOrEmail.trim();
    final response = await _apiClient.post(
      AppConfig.ausPath('sendregotptoresetpassword'),
      headers: _apiClient.ausHeaders,
      body: _rrm(
        data: <String, dynamic>{
          'MobileOrEmail': identifier,
        },
      ),
    );

    if (!response.isSuccess) {
      throw ApiException(response.displayMessage);
    }

    final token = response.data['OtpVerifyToken']?.toString() ?? '';
    if (token.isEmpty) {
      throw const ApiException(
        'OTP verification token was not returned by the API.',
      );
    }

    final mobile = _resolveResetMobile(
      identifier: identifier,
      apiMessage: response.message,
      apiData: response.data,
    );

    if (mobile == null) {
      throw const ApiException(
        'The reset API did not return the registered mobile number.',
      );
    }

    return ResetOtpSession(
      identifier: identifier,
      mobile: mobile,
      verifyToken: token,
      message: response.message,
    );
  }

  Future<ApiResponse> resetPassword({
    required ResetOtpSession session,
    required String otp,
    required String newPassword,
  }) {
    return _apiClient.post(
      AppConfig.ausPath('verifyotptoresetpassword'),
      headers: _apiClient.ausHeaders,
      body: _rrm(
        text: session.verifyToken,
        message: '${session.mobile}|${otp.trim()}',
        data: <String, dynamic>{
          'R_reg_mobile_no': session.mobile,
          'ConfirmPassword': newPassword,
        },
      ),
    );
  }

  Map<String, dynamic> _rrm({
    String org = '',
    String text = '',
    String message = '',
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    return <String, dynamic>{
      'Status': 'Failed',
      'Org': org,
      'Text': text,
      'ID': 0,
      'RefNo': '',
      'Message': message,
      'ErrorMsg': '',
      'RAction': '',
      'RData': data,
    };
  }

  String? _resolveResetMobile({
    required String identifier,
    required String apiMessage,
    required Map<String, dynamic> apiData,
  }) {
    if (RegExp(r'^\d{10}$').hasMatch(identifier)) {
      return identifier;
    }

    final explicitMobile = apiData['Mobile']?.toString().trim() ?? '';
    if (RegExp(r'^\d{10}$').hasMatch(explicitMobile)) {
      return explicitMobile;
    }

    final matches = RegExp(r'\d{10}').allMatches(apiMessage).toList();
    if (matches.isEmpty) return null;
    return matches.last.group(0);
  }
}
