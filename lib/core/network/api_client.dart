import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/api_response.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<ApiResponse> post(
    String path, {
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final uri = Uri.parse('${_normalizedBaseUrl()}$path');

    try {
      final response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...?headers,
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      Map<String, dynamic> decoded;
      try {
        decoded = _decodeObject(response.body);
      } on FormatException {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiException(
            _httpFallbackMessage(response.statusCode),
            statusCode: response.statusCode,
          );
        }
        rethrow;
      }
      final result = ApiResponse.fromJson(
        decoded,
        httpStatusCode: response.statusCode,
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          result.message.trim().isNotEmpty || result.errorMsg.trim().isNotEmpty
              ? result.displayMessage
              : _httpFallbackMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }

      return result;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. You can retry the request.',
      );
    } on FormatException {
      throw const ApiException('The API returned an invalid JSON response.');
    } on http.ClientException {
      throw const ApiException(
        'The connection to the API was interrupted. Check your network and retry.',
      );
    } catch (_) {
      throw const ApiException(
        'Unable to reach the API. Check your internet connection and API address.',
      );
    }
  }

  Map<String, String> get ausHeaders {
    final key = AppConfig.ausClientKey.trim();
    if (key.isEmpty) {
      throw const ApiException(
        'AUS_CLIENT_KEY is missing. Start the app with --dart-define=AUS_CLIENT_KEY=...',
      );
    }

    return <String, String>{
      'xRCT': AppConfig.ausClientType,
      'xRCK': key,
    };
  }

  String _normalizedBaseUrl() {
    var value = AppConfig.baseUrl.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  String _httpFallbackMessage(int statusCode) {
    return switch (statusCode) {
      401 => 'Your session has expired. Please login again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested API endpoint was not found.',
      408 => 'The server timed out while processing the request. Please retry.',
      429 => 'Too many requests were sent. Please wait and retry.',
      >= 500 => 'The server could not process the request. Please try again.',
      _ => 'The request could not be completed.',
    };
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw const FormatException('Expected JSON object.');
    }

    return decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  void dispose() => _client.close();
}
