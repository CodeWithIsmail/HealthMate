/// Typed error surfaced by [ApiClient]. `status == 0` means the request never
/// reached the server (timeout, no connectivity, DNS failure, etc.).
class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  bool get isUnauthorized => status == 401;
  bool get isNetworkError => status == 0;

  @override
  String toString() => message;
}
