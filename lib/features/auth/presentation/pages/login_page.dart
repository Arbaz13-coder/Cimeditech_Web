import 'package:flutter/material.dart';

import '../../../../core/models/api_response.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_shell.dart';
import 'create_account_page.dart';
import 'reset_password_page.dart';
import '../../../shell/presentation/pages/portal_shell.dart';
import '../../../reports/data/report_repository.dart';
import '../../../user_mapping/data/user_mapping_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.repository,
    required this.userMappingRepository,
    required this.reportRepository,
  });

  final AuthRepository repository;
  final UserMappingRepository userMappingRepository;
  final ReportRepository reportRepository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final response = await widget.repository.login(
        loginId: _loginController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      if (!response.isSuccess) {
        _showMessage(response.displayMessage);
        return;
      }

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => PortalShell(
            authRepository: widget.repository,
            userMappingRepository: widget.userMappingRepository,
            reportRepository: widget.reportRepository,
            loginBuilder: (_) => LoginPage(
              repository: widget.repository,
              userMappingRepository: widget.userMappingRepository,
              reportRepository: widget.reportRepository,
            ),
          ),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: 'Welcome back',
      subtitle: 'Sign in using your registered mobile number or email address.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _loginController,
              label: 'Mobile number or email',
              prefixIcon: Icons.person_outline,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              validator: Validators.mobileOrEmail,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _passwordController,
              label: 'Password',
              prefixIcon: Icons.lock_outline,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: Validators.loginPassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ResetPasswordPage(
                              repository: widget.repository,
                            ),
                          ),
                        ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New to CMX?'),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CreateAccountPage(
                                repository: widget.repository,
                              ),
                            ),
                          ),
                  child: const Text('Create account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
