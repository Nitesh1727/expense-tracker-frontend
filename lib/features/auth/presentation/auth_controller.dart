import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/storage/secure_storage.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../categories/presentation/category_controller.dart';
import '../../expenses/presentation/expense_providers.dart';
import '../data/auth_api.dart';
import '../data/local_profile_store.dart';
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
    // Local mode has no login — there is always a (device-only) profile.
    if (AppConfig.isLocal) return LocalProfileStore.load();

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

  /// Doesn't log anyone in — the account only exists once [verifySignup]
  /// confirms the emailed code.
  Future<void> requestSignup({required String email, required String password, String? name}) =>
      ref.read(authApiProvider).requestSignup(email: email, password: password, name: name);

  Future<void> resendSignupCode(String email) => ref.read(authApiProvider).resendSignupCode(email);

  Future<void> verifySignup({required String email, required String code}) async {
    final result = await ref.read(authApiProvider).verifySignup(email: email, code: code);
    await SecureStorage.saveToken(result.token);
    state = AsyncData(result.user);
  }

  Future<void> loginEmail({required String email, required String password}) async {
    final result = await ref.read(authApiProvider).loginEmail(email: email, password: password);
    await SecureStorage.saveToken(result.token);
    state = AsyncData(result.user);
  }

  Future<void> updateProfile({String? name, String? avatar, bool? monthlyReportEnabled}) async {
    if (AppConfig.isLocal) {
      state = AsyncData(await LocalProfileStore.update(name: name, avatar: avatar));
      return;
    }
    final user =
        await ref.read(authApiProvider).updateProfile(name: name, avatar: avatar, monthlyReportEnabled: monthlyReportEnabled);
    state = AsyncData(user);
  }

  Future<void> changePassword({required String currentPassword, required String newPassword}) =>
      ref.read(authApiProvider).changePassword(currentPassword: currentPassword, newPassword: newPassword);

  Future<void> forgotPassword(String email) => ref.read(authApiProvider).forgotPassword(email);

  Future<void> resetPassword({required String email, required String code, required String newPassword}) =>
      ref.read(authApiProvider).resetPassword(email: email, code: code, newPassword: newPassword);

  Future<void> logout() async {
    await SecureStorage.clearToken();
    await _clearLocalCaches();
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    if (AppConfig.isLocal) {
      // "Erase all data": stay in the app (there is no login to return to)
      // with an empty, freshly seeded database and a blank profile.
      await ref.read(localDatabaseProvider).eraseAll();
      await _clearLocalCaches();
      ref.invalidate(analyticsSummaryProvider);
      ref.invalidate(homeSummaryProvider);
      state = AsyncData(await LocalProfileStore.clear());
      return;
    }
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
