import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/models/api_response.dart';
import '../../../../core/utils/validators.dart';
import '../../data/auth_repository.dart';
import '../../models/signup_draft.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_shell.dart';
import 'registration_otp_page.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _pan = TextEditingController();
  final _tradeName = TextEditingController();
  final _gstin = TextEditingController();

  String _type = 'Broker';
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _pan.dispose();
    _tradeName.dispose();
    _gstin.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_loading || !_formKey.currentState!.validate()) return;

    final draft = SignupDraft.fromForm(
      type: _type,
      fullName: _name.text,
      mobile: _mobile.text,
      email: _email.text,
      pan: _pan.text,
      tradeName: _tradeName.text,
      gstin: _gstin.text,
      creationType: AppConfig.signupCreationType,
    );

    setState(() => _loading = true);
    try {
      final session = await widget.repository.sendRegistrationOtp(draft);
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RegistrationOtpPage(
            repository: widget.repository,
            session: session,
          ),
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
      title: 'Create account',
      subtitle: 'Enter your account details. We will validate them first, then send a 5-digit verification OTP.',
      maxFormWidth: 560,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Account type',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Broker', child: Text('Broker')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
              ],
              onChanged: _loading
                  ? null
                  : (value) => setState(() {
                        _type = value ?? 'Broker';
                        if (_type == 'Admin') _pan.clear();
                      }),
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _name,
              label: 'Full name',
              prefixIcon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              validator: (value) => Validators.requiredField(value, 'Name'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _mobile,
              label: 'Mobile number',
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.mobile,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _email,
              label: 'Email address',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: Validators.emailRequired,
              textInputAction: TextInputAction.next,
            ),
            if (_type == 'Broker') ...[
              const SizedBox(height: 16),
              AuthField(
                controller: _pan,
                label: 'PAN',
                prefixIcon: Icons.credit_card_outlined,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                validator: Validators.pan,
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 16),
            AuthField(
              controller: _tradeName,
              label: 'Trade / company name (optional)',
              prefixIcon: Icons.business_outlined,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            AuthField(
              controller: _gstin,
              label: 'GSTIN (optional)',
              prefixIcon: Icons.receipt_long_outlined,
              textCapitalization: TextCapitalization.characters,
              maxLength: 15,
              validator: Validators.gstinOptional,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendOtp(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loading ? null : _sendOtp,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sms_outlined),
              label: Text(
                _loading ? 'Sending OTP...' : 'Send verification OTP',
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _loading ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
