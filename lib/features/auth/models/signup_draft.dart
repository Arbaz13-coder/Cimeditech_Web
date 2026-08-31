class SignupDraft {
  const SignupDraft({
    required this.type,
    required this.name,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.mobile,
    required this.email,
    required this.pan,
    required this.tradeName,
    required this.gstin,
    required this.creationType,
  });

  final String type;
  final String name;
  final String firstName;
  final String middleName;
  final String lastName;
  final String mobile;
  final String email;
  final String pan;
  final String tradeName;
  final String gstin;
  final String creationType;

  factory SignupDraft.fromForm({
    required String type,
    required String fullName,
    required String mobile,
    required String email,
    required String pan,
    required String tradeName,
    required String gstin,
    required String creationType,
  }) {
    final cleanedName = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final parts = cleanedName.isEmpty
        ? const <String>[]
        : cleanedName.split(' ');

    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    final middle = parts.length > 2
        ? parts.sublist(1, parts.length - 1).join(' ')
        : '';

    return SignupDraft(
      type: type.trim(),
      name: cleanedName,
      firstName: first,
      middleName: middle,
      lastName: last,
      mobile: mobile.trim(),
      email: email.trim().toLowerCase(),
      pan: pan.trim().toUpperCase(),
      tradeName: tradeName.trim(),
      gstin: gstin.trim().toUpperCase(),
      creationType: creationType,
    );
  }

  Map<String, dynamic> toApiJson() {
    return <String, dynamic>{
      'R_dcreation_type': creationType,
      'R_type': type,
      'R_name': name,
      'R_fname': firstName,
      'R_mname': middleName,
      'R_lname': lastName,
      'R_reg_mobile_no_country_code': '91',
      'R_reg_mobile_no': mobile,
      'R_reg_email_id': email,
      'R_panno': type == 'Broker' ? pan : '',
      'R_trade_name': tradeName,
      'R_gstno': gstin,
      'R_add1': '',
      'R_add2': '',
      'R_pincode': '',
      'R_area': '',
      'R_city': '',
      'R_state': '',
      'R_country': 'India',
    };
  }
}

class RegistrationOtpSession {
  const RegistrationOtpSession({
    required this.draft,
    required this.verifyToken,
  });

  final SignupDraft draft;
  final String verifyToken;
}

class ResetOtpSession {
  const ResetOtpSession({
    required this.identifier,
    required this.mobile,
    required this.verifyToken,
    required this.message,
  });

  final String identifier;
  final String mobile;
  final String verifyToken;
  final String message;
}
