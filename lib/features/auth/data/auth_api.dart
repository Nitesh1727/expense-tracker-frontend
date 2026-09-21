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

  /// Step 1 of email signup — the backend stores a short-lived *pending*
  /// signup and emails a code; no account (and no token) exists yet, so
  /// this returns nothing. Throws if the email couldn't be sent, in which
  /// case nothing was left behind server-side either.
  Future<void> requestSignup({required String email, required String password, String? name}) async {
    try {
      await _client.dio.post('/auth/signup/email', data: {
        'email': email,
        'password': password,
        if (name != null && name.isNotEmpty) 'name': name,
      });
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> resendSignupCode(String email) async {
    try {
      await _client.dio.post('/auth/signup/email/resend', data: {'email': email});
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Step 2 — the correct code is what actually creates the account.
  Future<({User user, String token})> verifySignup({required String email, required String code}) async {
    try {
      final res = await _client.dio.post('/auth/signup/email/verify', data: {'email': email, 'code': code});
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

  /// Used for editing profile fields (name, avatar) from the Profile
  /// screen and the Settings screen's monthly-report toggle — same
  /// partial-update call for both. No `email` param — an account's email
  /// is fixed once set (it's the verified login identity), not something
  /// this can change.
  Future<User> updateProfile({String? name, String? avatar, bool? monthlyReportEnabled}) async {
    try {
      final res = await _client.dio.patch('/auth/me', data: {
        if (name != null) 'name': name,
        if (avatar != null) 'avatar': avatar,
        if (monthlyReportEnabled != null) 'monthlyReportEnabled': monthlyReportEnabled,
      });
      return User.fromJson(res.data['user']);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      await _client.dio.post('/auth/password/change', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Always succeeds from the caller's point of view (backend returns the
  /// same generic response whether or not the email has an account — see
  /// backend/docs/API.md) so this can't be used to check which emails are
  /// registered.
  Future<void> forgotPassword(String email) async {
    try {
      await _client.dio.post('/auth/password/forgot', data: {'email': email});
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> resetPassword({required String email, required String code, required String newPassword}) async {
    try {
      await _client.dio.post('/auth/password/reset', data: {'email': email, 'code': code, 'newPassword': newPassword});
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
