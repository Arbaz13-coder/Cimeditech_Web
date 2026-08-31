import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/api_response.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import '../../models/signup_draft.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_shell.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  ResetOtpSession? _session;
  bool _loading = false;
  bool _resending = false;

  @override
  void dispose() {
    _identifier.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool resend = false}) async {
    if (_loading || _resending) return;
    if (!resend && !_requestFormKey.currentState!.validate()) return;

    setState(() {
      if (resend) {
        _resending = true;
      } else {
        _loading = true;
      }
    });

    try {
      final session = await widget.repository.sendResetPasswordOtp(
        _identifier.text,
      );
      if (!mounted) return;

      setState(() => _session = session);
      if (resend) _otp.clear();
      _message(resend ? 'A new OTP has been sent.' : 'Reset OTP sent.');
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _resending = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_loading || _session == null) return;
    if (!_resetFormKey.currentState!.validate()) return;

    if (_password.text != _confirmPassword.text) {
      _message('Password and confirm password do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await widget.repository.resetPassword(
        session: _session!,
        otp: _otp.text,
        newPassword: _confirmPassword.text,
      );

      if (!mounted) return;
      if (!response.isSuccess) {
        _message(response.displayMessage);
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.lock_reset, size: 48),
          title: const Text('Password updated'),
          content: Text(response.displayMessage),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Back to login'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      title: _session == null ? 'Reset password' : 'Verify & reset',
      subtitle: _session == null
          ? 'Enter your registered mobile number or email address to receive a reset OTP.'
          : 'Enter the 5-digit OTP and choose a new password.',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _session == null ? _requestForm() : _resetForm(),
      ),
    );
  }

  Widget _requestForm() {
    return Form(
      key: _requestFormKey,
      child: Column(
        key: const ValueKey('request-reset-otp'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            controller: _identifier,
            label: 'Registered mobile or email',
            prefixIcon: Icons.person_search_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.mobileOrEmail,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendOtp(),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _sendOtp,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send reset OTP'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _loading ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to login'),
          ),
        ],
      ),
    );
  }

  Widget _resetForm() {
    final mobile = _session!.mobile;
    final masked = mobile.length == 10
        ? '******${mobile.substring(6)}'
        : mobile;

    return Form(
      key: _resetFormKey,
      child: Column(
        key: const ValueKey('complete-reset'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'OTP sent to registered mobile $masked',
              style: const TextStyle(
                color: Color(0xFF1849A9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: _otp,
            label: 'Reset OTP',
            prefixIcon: Icons.password_outlined,
            keyboardType: TextInputType.number,
            maxLength: 5,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            validator: Validators.otp,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: _password,
            label: 'New password',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.resetPassword,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AuthField(
            controller: _confirmPassword,
            label: 'Confirm new password',
            prefixIcon: Icons.lock_reset_outlined,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            validator: Validators.resetPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _resetPassword,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reset password'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: (_loading || _resending)
                ? null
                : () => _sendOtp(resend: true),
            child: Text(_resending ? 'Resending...' : 'Resend OTP'),
          ),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _session = null;
                      _otp.clear();
                      _password.clear();
                      _confirmPassword.clear();
                    }),
            child: const Text('Use a different mobile/email'),
          ),
        ],
      ),
    );
  }
}
