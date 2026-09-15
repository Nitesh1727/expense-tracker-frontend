import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/auth_api.dart';
import '../domain/user.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

/// null = logged out, non-null = logged in. AsyncLoading only during the
/// initial "is there a stored token that's still valid" check at app start.
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

  Future<void> verifyOtp(String phone, String code) async {
    final result = await ref.read(authApiProvider).verifyOtp(phone, code);
    await SecureStorage.saveToken(result.token);
    state = AsyncData(result.user);
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
