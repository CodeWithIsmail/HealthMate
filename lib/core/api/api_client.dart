import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Thin wrapper around Dio for the HealthMate API.
///
/// - Injects `Authorization: Bearer <token>` from [TokenStorage] on every
///   request (the API also accepts an httpOnly cookie, but that's for the
///   web client only).
/// - Flattens Nest's `ValidationPipe` error shape (`message` as a string or
///   `string[]`) into a single readable [ApiException].
/// - Retries transient failures (connection drops, 502/503/504/520) with
///   backoff. Render's free tier cold-starts, so a lone request is also
///   given a long timeout rather than being retried into a pile of requests.
/// - Calls [onUnauthorized] when an authenticated request comes back 401,
///   i.e. the token itself is no longer valid — callers use this to force a
///   logout rather than checking `isUnauthorized` after every call.
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, Dio? dio})
    // ignore: prefer_initializing_formals
    : _tokenStorage = tokenStorage,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 40),
              sendTimeout: const Duration(seconds: 40),
            ),
          );

  static const baseUrl = 'https://healthmate-web-7ufp.onrender.com/api';

  static const _maxAttempts = 3;
  static const _retryDelays = [Duration(seconds: 2), Duration(seconds: 5)];
  static const _retryableStatuses = {502, 503, 504, 520};

  final Dio _dio;
  final TokenStorage _tokenStorage;

  void Function()? onUnauthorized;

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => _send<T>('GET', path, query: query);

  Future<T> post<T>(String path, {dynamic data}) => _send<T>('POST', path, data: data);

  Future<T> patch<T>(String path, {dynamic data}) => _send<T>('PATCH', path, data: data);

  Future<T> delete<T>(String path) => _send<T>('DELETE', path);

  /// Uploads a single file under `fieldName`, plus any extra scalar [fields].
  /// Used by `/reports/extract`, `/reports/analyze` and `/users/me/avatar`.
  Future<T> postMultipart<T>(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, String>? fields,
  }) {
    final data = FormData.fromMap({
      ...?fields,
      fieldName: MultipartFile.fromFileSync(filePath),
    });
    return _send<T>('POST', path, data: data);
  }

  Future<T> _send<T>(String method, String path, {dynamic data, Map<String, dynamic>? query}) async {
    final token = await _tokenStorage.readToken();
    final headers = token == null ? null : {'Authorization': 'Bearer $token'};

    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final response = await _dio.request<T>(
          path,
          data: data,
          queryParameters: query,
          options: Options(method: method, headers: headers),
        );
        return response.data as T;
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;

        if (status == 401 && token != null) {
          onUnauthorized?.call();
        }

        final transient = status == 0 || _retryableStatuses.contains(status);
        if (transient && attempt < _maxAttempts) {
          await Future.delayed(_retryDelays[attempt - 1]);
          continue;
        }

        throw _mapError(e, status);
      }
    }
  }

  ApiException _mapError(DioException e, int status) {
    final body = e.response?.data;
    if (body is Map && body['message'] != null) {
      final message = body['message'];
      if (message is List) return ApiException(status, message.join('. '));
      if (message is String) return ApiException(status, message);
    }
    if (status == 0) {
      return ApiException(0, "Couldn't reach the server. Check your connection and try again.");
    }
    return ApiException(status, 'Request failed ($status).');
  }
}
