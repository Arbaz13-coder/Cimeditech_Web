import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Example: https://api.example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // defaultValue: 'https://localhost:7052',
    defaultValue: 'https://hf7n7szw51.execute-api.ap-south-1.amazonaws.com/Prod',
  );

  /// Value used by the backend route: /api/{var}/...
  static const String apiVar = String.fromEnvironment(
    'API_VAR',
    defaultValue: 'v1',
  );

  /// Current AUS middleware requires xRCK.
  /// Pass this using --dart-define; do not commit a production secret.
  static const String ausClientKey = String.fromEnvironment(
    'AUS_CLIENT_KEY',
    defaultValue: '',
  );

  /// Current AUS middleware checks that xRCT exists.
  static const String ausClientType = String.fromEnvironment(
    'AUS_CLIENT_TYPE',
    defaultValue: 'Flutter',
  );

  static String get loginType => kIsWeb ? 'WebLogin' : 'ClientAppLogin';

  static String get loginSubType {
    if (kIsWeb) return 'Web';

    // Current SGxBrokerAPI accepts only Web/Desktop/Android here.
    // Until the API adds iOS/Mobile, iOS uses Android for compatibility.
    return 'Android';
  }

  static String get signupCreationType {
    if (kIsWeb) return 'Web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'MAA';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'MAI';
    return 'Web';
  }

  static String accountPath(String action) => '/api/$apiVar/account/$action';

  static String ausPath(String action) =>
      '/api/aus/$apiVar/sendalerts/$action';

  static String userMappingPath(String action) =>
      '/api/app/$apiVar/usermapping/$action';

  static String reportPath(String action) =>
      '/api/app/$apiVar/report/$action';

  static String get reportRuntimePath => reportPath('runtime');

  static String get reportConfigurePath => reportPath('configure');

  static String get companyWithUserPath =>
      '/api/app/$apiVar/admin/getregcompanywithuser';

  /// Preferred initial company for User Mapping. The page loads the logged-in
  /// user's companies from GetRegCompanyWithUser and falls back to the first
  /// returned company when this ID is not available.
  static const int defaultCompanyId = int.fromEnvironment(
    'DEFAULT_COMPANY_ID',
    defaultValue: 1,
  );
}
