import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../domain/category.dart';
import '../category_controller.dart';

/// Grid picker for choosing a category when adding/editing an expense.
/// Not the same as the Categories tab's CRUD screen — this only selects.
Future<Category?> showCategoryPicker(BuildContext context, {String? selectedId}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _CategoryPickerSheet(selectedId: selectedId),
  );
}

class _CategoryPickerSheet extends ConsumerWidget {
  final String? selectedId;

  const _CategoryPickerSheet({this.selectedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryControllerProvider);
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a category', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            categoriesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Could not load categories: $e'),
              ),
              data: (categories) => ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = category.id == selectedId;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).pop(category),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: isSelected
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                                  )
                                : null,
                            padding: const EdgeInsets.all(2),
                            child: CategoryAvatar(icon: category.icon, colorHex: category.color),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            category.name,
                            style: textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
