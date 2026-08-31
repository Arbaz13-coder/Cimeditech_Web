import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/reports/data/report_repository.dart';
import 'features/user_mapping/data/user_mapping_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CmxWebPortalApp());
}

class CmxWebPortalApp extends StatefulWidget {
  const CmxWebPortalApp({super.key});

  @override
  State<CmxWebPortalApp> createState() => _CmxWebPortalAppState();
}

class _CmxWebPortalAppState extends State<CmxWebPortalApp> {
  late final ApiClient _apiClient;
  late final TokenStorage _tokenStorage;
  late final AuthRepository _authRepository;
  late final UserMappingRepository _userMappingRepository;
  late final ReportRepository _reportRepository;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _tokenStorage = const TokenStorage();
    _authRepository = AuthRepository(
      apiClient: _apiClient,
      tokenStorage: _tokenStorage,
    );
    _userMappingRepository = UserMappingRepository(
      apiClient: _apiClient,
      tokenStorage: _tokenStorage,
    );
    _reportRepository = ReportRepository(
      apiClient: _apiClient,
      tokenStorage: _tokenStorage,
    );
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CMX Web Portal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: LoginPage(
        repository: _authRepository,
        userMappingRepository: _userMappingRepository,
        reportRepository: _reportRepository,
      ),
    );
  }
}
