import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../storage/secure_storage.dart';
import 'api_exception.dart';

export 'api_exception.dart';

/// Single Dio instance for the whole app. A request interceptor attaches
/// the JWT; a response interceptor normalizes every failure into an
/// [ApiException] and calls [onUnauthorized] on a 401 (token missing/
/// expired/account deleted — see backend/docs/ARCHITECTURE.md auth flow)
/// so the app can route back to the phone-entry screen from one place
/// instead of every screen handling it individually.
class ApiClient {
  final Dio dio;

  /// Set once at app startup by the auth layer (avoids a circular
  /// dependency between the network layer and auth state).
  void Function()? onUnauthorized;

  ApiClient() : dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, connectTimeout: const Duration(seconds: 10))) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.readToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) {
          if (error.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  /// Extracts the backend's `{ error: { message } }` shape, or falls back
  /// to something readable for network-level failures (timeout, offline).
  static ApiException toApiException(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      final message = (data is Map && data['error'] is Map) ? data['error']['message'] as String? : null;
      return ApiException(message ?? _fallbackMessage(error), statusCode: error.response?.statusCode);
    }
    return ApiException(error.toString());
  }

  static String _fallbackMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Request timed out. Check your connection.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
