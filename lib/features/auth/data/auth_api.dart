import '../../../core/network/api_client.dart';
import '../domain/user.dart';

class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  /// Returns the dev-mode OTP code when the backend is running with
  /// SMS_PROVIDER=dev, so the UI can pre-fill it during local testing.
  /// Always null against a real SMS provider.
  Future<String?> requestOtp(String phone) async {
    try {
      final res = await _client.dio.post('/auth/otp/request', data: {'phone': phone});
      return res.data['devCode'] as String?;
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<({User user, String token, bool isNewUser})> verifyOtp(String phone, String code) async {
    try {
      final res = await _client.dio.post('/auth/otp/verify', data: {'phone': phone, 'code': code});
      return (
        user: User.fromJson(res.data['user']),
        token: res.data['token'] as String,
        isNewUser: res.data['isNewUser'] as bool? ?? false,
      );
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<({User user, String token})> signupEmail({required String email, required String password, String? name}) async {
    try {
      final res = await _client.dio.post('/auth/signup/email', data: {
        'email': email,
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name,
      });
      return (user: User.fromJson(res.data['user']), token: res.data['token'] as String);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<({User user, String token})> loginEmail({required String email, required String password}) async {
    try {
      final res = await _client.dio.post('/auth/login/email', data: {'email': email, 'password': password});
      return (user: User.fromJson(res.data['user']), token: res.data['token'] as String);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<User> getMe() async {
    try {
      final res = await _client.dio.get('/auth/me');
      return User.fromJson(res.data['user']);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Used both for the optional post-signup "add your name" prompt and for
  /// editing profile fields later from the Profile screen — same call.
  Future<User> updateProfile({String? name, String? email}) async {
    try {
      final res = await _client.dio.patch('/auth/me', data: {
        if (name != null) 'name': name,
        if (email != null) 'email': email,
      });
      return User.fromJson(res.data['user']);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteAccount() async {
    try {
      await _client.dio.delete('/auth/me');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
