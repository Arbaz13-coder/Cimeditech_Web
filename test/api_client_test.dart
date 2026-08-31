import 'package:cmx_web_portal/core/models/api_response.dart';
import 'package:cmx_web_portal/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('distinguishes expired sessions from forbidden operations', () {
    expect(const ApiException('Expired', statusCode: 401).isUnauthorized, isTrue);
    expect(const ApiException('Forbidden', statusCode: 403).isUnauthorized, isFalse);
    expect(const ApiException('Forbidden', statusCode: 403).isForbidden, isTrue);
  });

  test('uses a friendly server message for non-JSON HTTP failures', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response('<html>Unavailable</html>', 503),
      ),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.post('/test', body: const <String, dynamic>{}),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having(
              (error) => error.message,
              'message',
              'The server could not process the request. Please try again.',
            ),
      ),
    );
  });

  test('identifies invalid JSON returned with a successful status', () async {
    final client = ApiClient(
      client: MockClient((_) async => http.Response('not-json', 200)),
    );
    addTearDown(client.dispose);

    await expectLater(
      client.post('/test', body: const <String, dynamic>{}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'The API returned an invalid JSON response.',
        ),
      ),
    );
  });
}
