class Validators {
  Validators._();

  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }
    return null;
  }

  static String? mobile(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{10}$').hasMatch(text)) {
      return 'Enter a valid 10-digit mobile number.';
    }
    return null;
  }

  static String? mobileOrEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Mobile number or email is required.';

    final isMobile = RegExp(r'^\d{10}$').hasMatch(text);
    final isEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text);
    if (!isMobile && !isEmail) {
      return 'Enter a valid mobile number or email address.';
    }
    return null;
  }

  static String? emailRequired(String? value) {
    final required = requiredField(value, 'Email');
    if (required != null) return required;

    final text = value!.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required.';
    if (text.length > 15) return 'Password cannot exceed 15 characters.';
    return null;
  }

  static String? resetPassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required.';
    if (text.length < 5 || text.length > 12) {
      return 'Password must be 5-12 characters.';
    }
    return null;
  }

  static String? otp(String? value) {
    final text = value?.trim() ?? '';
    if (!RegExp(r'^\d{5}$').hasMatch(text)) {
      return 'Enter the 5-digit OTP.';
    }
    return null;
  }

  static String? pan(String? value) {
    final required = requiredField(value, 'PAN');
    if (required != null) return required;

    final text = value!.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(text)) {
      return 'Enter a valid PAN number.';
    }
    return null;
  }

  static String? gstinOptional(String? value) {
    final text = value?.trim().toUpperCase() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
        .hasMatch(text)) {
      return 'Enter a valid 15-character GSTIN.';
    }
    return null;
  }
}
