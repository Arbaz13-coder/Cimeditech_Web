class ApiResponse {
  const ApiResponse({
    required this.status,
    required this.message,
    this.org = '',
    this.text = '',
    this.id = 0,
    this.refNo = '',
    this.errorMsg = '',
    this.action = '',
    this.data = const <String, dynamic>{},
    this.httpStatusCode = 200,
  });

  final String status;
  final String message;
  final String org;
  final String text;
  final int id;
  final String refNo;
  final String errorMsg;
  final String action;
  final Map<String, dynamic> data;
  final int httpStatusCode;

  bool get isSuccess => status.trim().toLowerCase() == 'success';

  String get displayMessage {
    if (message.trim().isNotEmpty) return message.trim();
    if (errorMsg.trim().isNotEmpty) return errorMsg.trim();
    return isSuccess ? 'Success' : 'Request failed.';
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    int httpStatusCode = 200,
  }) {
    final rawData = json['RData'] ?? json['rData'] ?? json['rdata'];

    Object? read(String pascalName, String camelName) =>
        json[pascalName] ?? json[camelName];

    return ApiResponse(
      status: read('Status', 'status')?.toString() ?? 'Failed',
      message: read('Message', 'message')?.toString() ?? '',
      org: read('Org', 'org')?.toString() ?? '',
      text: read('Text', 'text')?.toString() ?? '',
      id: int.tryParse(read('ID', 'id')?.toString() ?? '') ?? 0,
      refNo: read('RefNo', 'refNo')?.toString() ?? '',
      errorMsg: read('ErrorMsg', 'errorMsg')?.toString() ??
          json['Error_Msg']?.toString() ??
          '',
      action: read('RAction', 'rAction')?.toString() ?? '',
      data: rawData is Map<String, dynamic>
          ? rawData
          : rawData is Map
              ? rawData.map(
                  (key, value) => MapEntry(key.toString(), value),
                )
              : const <String, dynamic>{},
      httpStatusCode: httpStatusCode,
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}
