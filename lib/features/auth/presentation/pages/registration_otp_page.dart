import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/api_response.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import '../../models/signup_draft.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_shell.dart';

class RegistrationOtpPage extends StatefulWidget {
  const RegistrationOtpPage({
    super.key,
    required this.repository,
    required this.session,
  });

  final AuthRepository repository;
  final RegistrationOtpSession session;

  @override
  State<RegistrationOtpPage> createState() => _RegistrationOtpPageState();
}

class _RegistrationOtpPageState extends State<RegistrationOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otp = TextEditingController();
  late RegistrationOtpSession _session;
  bool _loading = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final response = await widget.repository.completeSignup(
        session: _session,
        otp: _otp.text,
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
          icon: const Icon(Icons.verified_outlined, size: 48),
          title: const Text('Account created'),
          content: const Text(
            'Registration completed successfully. The current backend sends the generated login credentials through its configured WhatsApp/email channel.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: const Text('Go to login'),
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

  Future<void> _resend() async {
    if (_loading || _resending) return;

    setState(() => _resending = true);
    try {
      _session = await widget.repository.sendRegistrationOtp(_session.draft);
      _otp.clear();
      if (mounted) _message('A new verification OTP has been sent.');
    } on ApiException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _session.draft.mobile;
    final masked = mobile.length == 10
        ? '******${mobile.substring(6)}'
        : mobile;

    return AuthShell(
      title: 'Verify your account',
      subtitle: 'Enter the 5-digit OTP sent for $masked. The current registration OTP expires after 5 minutes.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _otp,
              label: 'Verification OTP',
              hint: '00000',
              prefixIcon: Icons.password_outlined,
              keyboardType: TextInputType.number,
              maxLength: 5,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofillHints: const [AutofillHints.oneTimeCode],
              validator: Validators.otp,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify & create account'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: (_loading || _resending) ? null : _resend,
              child: Text(_resending ? 'Resending...' : 'Resend OTP'),
            ),
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: const Text('Edit account details'),
            ),
          ],
        ),
      ),
    );
  }
}
