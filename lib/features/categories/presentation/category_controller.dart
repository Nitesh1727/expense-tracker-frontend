import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../expenses/presentation/expense_providers.dart';
import '../data/category_api.dart';
import '../domain/category.dart';

final categoryApiProvider = Provider<CategoryApi>((ref) => CategoryApi(ref.watch(apiClientProvider)));

class CategoryController extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() => ref.read(categoryApiProvider).list();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(categoryApiProvider).list());
  }

  Future<void> create({required String name, required String icon, required String color}) async {
    await ref.read(categoryApiProvider).create(name: name, icon: icon, color: color);
    await refresh();
  }

  /// Named updateCategory, not update — collides with Notifier's own
  /// `update` method otherwise (see expense_providers.dart for the same note).
  Future<void> updateCategory(String id, {String? name, String? icon, String? color}) async {
    await ref.read(categoryApiProvider).update(id, name: name, icon: icon, color: color);
    await refresh();
  }

  /// Deleting a category reassigns its expenses to "Other" server-side (see
  /// backend/docs/DATABASE.md) — refresh expense/analytics views too, not
  /// just the category list, or they'd show stale category references.
  Future<void> delete(String id) async {
    await ref.read(categoryApiProvider).delete(id);
    // Awaited, not just invalidated — see expense_providers.dart's
    // _refreshDependents for why (invalidate() alone doesn't wait for the
    // refetch, so a caller navigating away right after would see stale data).
    await Future.wait([
      refresh(),
      ref.read(homeFeedControllerProvider.notifier).refresh(),
      ref.refresh(homeSummaryProvider.future),
      ref.refresh(analyticsSummaryProvider.future),
      ref.refresh(analyticsTrendProvider.future),
    ]);
    ref.invalidate(expenseHistoryControllerProvider);
  }
}

final categoryControllerProvider = AsyncNotifierProvider<CategoryController, List<Category>>(CategoryController.new);
