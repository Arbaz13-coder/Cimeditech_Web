import 'package:cmx_web_portal/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('accepts valid Indian mobile number', () {
      expect(Validators.mobile('9876543210'), isNull);
    });

    test('rejects invalid mobile number', () {
      expect(Validators.mobile('12345'), isNotNull);
    });

    test('accepts valid email login', () {
      expect(Validators.mobileOrEmail('user@example.com'), isNull);
    });

    test('accepts valid PAN', () {
      expect(Validators.pan('ABCDE1234F'), isNull);
    });

    test('requires 5-digit OTP', () {
      expect(Validators.otp('12345'), isNull);
      expect(Validators.otp('1234'), isNotNull);
    });

    test('reset password follows backend 5-12 rule', () {
      expect(Validators.resetPassword('Abc12'), isNull);
      expect(Validators.resetPassword('1234'), isNotNull);
      expect(Validators.resetPassword('1234567890123'), isNotNull);
    });
  });
}
