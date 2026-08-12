import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate/core/api/api_client.dart';
import 'package:healthmate/core/api/api_exception.dart';
import 'package:healthmate/core/storage/token_storage.dart';

/// In-memory [TokenStorage] — the real one talks to a platform channel that
/// doesn't exist in a unit-test host.
class _FakeTokenStorage extends TokenStorage {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async => _token = null;
}

/// Serves a scripted sequence of responses, one per request, so retry
/// behaviour can be tested without hitting the network.
class _ScriptedAdapter implements HttpClientAdapter {
  final List<ResponseBody Function()> responses = [];
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (responses.isEmpty) {
      throw StateError('_ScriptedAdapter: no more queued responses');
    }
    return responses.removeAt(0)();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

(ApiClient, _ScriptedAdapter, _FakeTokenStorage) _buildClient() {
  final adapter = _ScriptedAdapter();
  final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))..httpClientAdapter = adapter;
  final tokenStorage = _FakeTokenStorage();
  final client = ApiClient(tokenStorage: tokenStorage, dio: dio);
  return (client, adapter, tokenStorage);
}

void main() {
  group('ApiClient error mapping', () {
    test('flattens a Nest ValidationPipe string[] message', () async {
      final (client, adapter, _) = _buildClient();
      adapter.responses.add(
        () => _jsonResponse(400, {
          'message': ['username must be at least 3 characters', 'email must be a valid email'],
        }),
      );

      await expectLater(
        client.get<void>('/anything'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 400)
              .having(
                (e) => e.message,
                'message',
                'username must be at least 3 characters. email must be a valid email',
              ),
        ),
      );
    });

    test('passes through a plain string message', () async {
      final (client, adapter, _) = _buildClient();
      adapter.responses.add(() => _jsonResponse(409, {'message': 'That username is taken'}));

      await expectLater(
        client.get<void>('/anything'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 409)
              .having((e) => e.message, 'message', 'That username is taken'),
        ),
      );
    });

    test('falls back to a generic message when the body has no message field', () async {
      final (client, adapter, _) = _buildClient();
      adapter.responses.add(() => _jsonResponse(500, {'error': 'Internal Server Error'}));

      await expectLater(
        client.get<void>('/anything'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Request failed (500).')),
      );
    });

    test('maps a connection failure to a network error with status 0', () async {
      final adapter = _ScriptedAdapter();
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))..httpClientAdapter = adapter;
      // No queued response at all -> the adapter throws and Dio surfaces it
      // with no response attached. status==0 is treated as transient (same
      // as a 520), so this also exercises the retry loop before giving up.
      final client = ApiClient(tokenStorage: _FakeTokenStorage(), dio: dio);

      await expectLater(
        client.get<void>('/anything'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isNetworkError, 'isNetworkError', true)
              .having((e) => e.message, 'message', contains("Couldn't reach the server")),
        ),
      );
      expect(adapter.requests.length, 3);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('calls onUnauthorized only when a token was attached to the request', () async {
      final (client, adapter, tokenStorage) = _buildClient();
      var unauthorizedCalls = 0;
      client.onUnauthorized = () => unauthorizedCalls++;

      // No token stored yet — a 401 here is a failed login, not a revoked session.
      adapter.responses.add(() => _jsonResponse(401, {'message': 'Invalid credentials'}));
      await expectLater(client.get<void>('/anything'), throwsA(isA<ApiException>()));
      expect(unauthorizedCalls, 0);

      // Now simulate an authenticated request whose token the server rejects.
      await tokenStorage.saveToken('expired-token');
      adapter.responses.add(() => _jsonResponse(401, {'message': 'Unauthorized'}));
      await expectLater(client.get<void>('/anything'), throwsA(isA<ApiException>()));
      expect(unauthorizedCalls, 1);
    });

    test('retries a transient 520 and succeeds once the server recovers', () async {
      final (client, adapter, _) = _buildClient();
      adapter.responses.add(() => _jsonResponse(520, 'Web server is returning an unknown error'));
      adapter.responses.add(() => _jsonResponse(200, {'status': 'ok'}));

      final result = await client.get<Map<String, dynamic>>('/health');

      expect(result['status'], 'ok');
      expect(adapter.requests.length, 2);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('gives up after exhausting retries on a persistently failing endpoint', () async {
      final (client, adapter, _) = _buildClient();
      adapter.responses.addAll([
        () => _jsonResponse(503, 'Service Unavailable'),
        () => _jsonResponse(503, 'Service Unavailable'),
        () => _jsonResponse(503, 'Service Unavailable'),
      ]);

      await expectLater(
        client.get<void>('/anything'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 503)),
      );
      // maxAttempts is 3 — no further retry beyond that.
      expect(adapter.requests.length, 3);
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
