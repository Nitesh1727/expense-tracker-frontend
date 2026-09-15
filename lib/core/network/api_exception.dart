/// Thin wrapper around whatever the backend's `{ error: { message } }` shape
/// sends back, so UI code can show `e.message` without knowing about Dio's
/// response structure.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
