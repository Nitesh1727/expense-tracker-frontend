import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/category_avatar.dart';
import '../../../core/widgets/empty_state.dart';
import 'category_controller.dart';
import 'widgets/category_form_sheet.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('Any expenses in this category will move to "Other".'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(categoryControllerProvider.notifier).delete(id);
    } catch (e) {
      if (!context.mounted) return;
      final message = e is ApiException ? e.message : 'Could not delete category';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryControllerProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // No own Scaffold/AppBar/FAB — this is one page of RootShell's PageView,
    // which owns the shared AppBar (title swaps per page) and the FAB
    // (action swaps per page). See core/widgets/root_shell.dart.
    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load categories: $e')),
      data: (categories) {
        if (categories.isEmpty) {
          return const EmptyState(icon: Icons.category_outlined, title: 'No categories yet');
        }

        return RefreshIndicator(
          onRefresh: () => ref.read(categoryControllerProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: categories.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CategoryAvatar(icon: category.icon, colorHex: category.color),
                title: Text(category.name, style: textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                subtitle: category.isDeletable ? null : Text('Default fallback category', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                trailing: category.isDeletable
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(context, ref, category.id, category.name),
                      )
                    : null,
                onTap: () => showCategoryFormSheet(context, existing: category),
              );
            },
          ),
        );
      },
    );
  }
}
