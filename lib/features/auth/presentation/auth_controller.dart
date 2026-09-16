import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_api.dart';
import '../domain/user.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

/// null = logged out, non-null = logged in. AsyncLoading only during the
/// initial "is there a stored token that's still valid" check at app start.
///
/// Signup methods below save the token immediately (so an authenticated call
/// like updateProfile works right away) but deliberately don't flip `state`
/// to logged-in for a *new* phone signup — the OTP screen shows an optional
/// "what should we call you?" prompt first and calls [completeOnboarding]
/// once that's done (skipped or saved), so AuthGate doesn't drop the user
/// straight onto Home mid-onboarding. Email signup collects the name in the
/// signup form itself, so it has no such gap — it logs straight in.
class AuthController extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final token = await SecureStorage.readToken();
    if (token == null) return null;

    try {
      return await ref.read(authApiProvider).getMe();
    } catch (_) {
      // Stored token is invalid/expired (or the account was deleted) — treat as logged out.
      await SecureStorage.clearToken();
      return null;
    }
  }

  Future<String?> requestOtp(String phone) => ref.read(authApiProvider).requestOtp(phone);

  Future<({User user, bool isNewUser})> verifyOtp(String phone, String code) async {
    final result = await ref.read(authApiProvider).verifyOtp(phone, code);
    await SecureStorage.saveToken(result.token);
    if (!result.isNewUser) {
      state = AsyncData(result.user);
    }
    return (user: result.user, isNewUser: result.isNewUser);
  }

  /// Called by OtpVerifyScreen after a new user skips or saves the optional
  /// name prompt — the point where they actually enter the app.
  void completeOnboarding(User user) {
    state = AsyncData(user);
  }

  Future<void> signupEmail({required String email, required String password, String? name}) async {
    final result = await ref.read(authApiProvider).signupEmail(email: email, password: password, name: name);
    await SecureStorage.saveToken(result.token);
    state = AsyncData(result.user);
  }

  Future<void> loginEmail({required String email, required String password}) async {
    final result = await ref.read(authApiProvider).loginEmail(email: email, password: password);
    await SecureStorage.saveToken(result.token);
    state = AsyncData(result.user);
  }

  Future<void> updateProfile({String? name, String? email}) async {
    final user = await ref.read(authApiProvider).updateProfile(name: name, email: email);
    state = AsyncData(user);
  }

  Future<void> logout() async {
    await SecureStorage.clearToken();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    await ref.read(authApiProvider).deleteAccount();
    await SecureStorage.clearToken();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);
