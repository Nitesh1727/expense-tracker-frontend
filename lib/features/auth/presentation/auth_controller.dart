import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/secure_storage.dart';
import '../../categories/presentation/category_controller.dart';
import '../../expenses/presentation/expense_providers.dart';
import '../data/auth_api.dart';
import '../domain/user.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(apiClientProvider)));

/// null = logged out, non-null = logged in. AsyncLoading only during the
/// initial "is there a stored token that's still valid" check at app start.
///
/// Phone+OTP sign-in used to also live here (requestOtp/verifyOtp/
/// completeOnboarding) — dropped from the UI "for now" per explicit user
/// request (see WelcomeScreen's doc comment). AuthApi.requestOtp/verifyOtp
/// are left in place since the backend routes they call are still running;
/// only this controller's now-unreachable wrappers were removed.
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

  Future<void> updateProfile({String? name, String? avatar, bool? monthlyReportEnabled}) async {
    final user =
        await ref.read(authApiProvider).updateProfile(name: name, avatar: avatar, monthlyReportEnabled: monthlyReportEnabled);
    state = AsyncData(user);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      ref.read(authApiProvider).changePassword(currentPassword: currentPassword, newPassword: newPassword);

  Future<void> resendVerificationEmail() => ref.read(authApiProvider).resendVerificationEmail();

  Future<void> verifyEmail(String code) async {
    final user = await ref.read(authApiProvider).verifyEmail(code);
    state = AsyncData(user);
  }

  Future<void> forgotPassword(String email) => ref.read(authApiProvider).forgotPassword(email);

  Future<void> resetPassword({required String email, required String code, required String newPassword}) =>
      ref.read(authApiProvider).resetPassword(email: email, code: code, newPassword: newPassword);

  Future<void> logout() async {
    await SecureStorage.clearToken();
    await _clearLocalCaches();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    await ref.read(authApiProvider).deleteAccount();
    await SecureStorage.clearToken();
    await _clearLocalCaches();
    state = const AsyncData(null);
  }

  /// So a different account logging in next on this device never briefly
  /// shows the previous user's data — the autoDispose analytics/home-summary
  /// providers already clear themselves once RootShell unmounts, but these
  /// (plain, non-autoDispose) providers would otherwise keep their last
  /// fetched value in memory across the swap back to WelcomeScreen. Also
  /// wipes the temp directory, which is where exported `.xlsx` files land
  /// (see ExportController) — nothing else this app writes lives there, so
  /// clearing all of it is safe.
  Future<void> _clearLocalCaches() async {
    ref.invalidate(homeFeedControllerProvider);
    ref.invalidate(categoryControllerProvider);
    ref.invalidate(expenseHistoryFilterProvider);
    ref.invalidate(expenseFiltersEverAppliedProvider);

    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          await entity.delete(recursive: true);
        }
      }
    } catch (_) {
      // Best-effort — a failure here shouldn't block logging out.
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);
