import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/category_presets.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/glass_bottom_sheet.dart';
import '../../domain/category.dart';
import '../category_controller.dart';

/// Create or edit a category. Icon and color are picked from the curated
/// sets, not freely chosen — see frontend/docs/DESIGN_SYSTEM.md "Category
/// colors & icons" for why (keeps every user's category list visually
/// consistent instead of accumulating clashing custom colors).
Future<void> showCategoryFormSheet(BuildContext context, {Category? existing}) {
  return showGlassBottomSheet(context, builder: (context) => _CategoryFormSheet(existing: existing));
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  final Category? existing;

  const _CategoryFormSheet({this.existing});

  @override
  ConsumerState<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late String _icon = widget.existing?.icon ?? CategoryPresets.icons.keys.first;
  late String _color = widget.existing?.color ?? CategoryPresets.colorHexes.first;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final controller = ref.read(categoryControllerProvider.notifier);
    final name = _nameController.text.trim();

    try {
      if (_isEditing) {
        await controller.updateCategory(widget.existing!.id, name: name, icon: _icon, color: _color);
      } else {
        await controller.create(name: name, icon: _icon, color: _color);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not save category';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEditing ? 'Edit category' : 'New category', style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Subscriptions'),
                  validator: (value) => (value?.trim().isEmpty ?? true) ? 'Name is required' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Icon', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in CategoryPresets.icons.entries)
                      _PickerDot(
                        selected: entry.key == _icon,
                        onTap: () => setState(() => _icon = entry.key),
                        child: Icon(entry.value, color: _icon == entry.key ? colorScheme.primary : colorScheme.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Color', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final hex in CategoryPresets.colorHexes)
                      _PickerDot(
                        selected: hex == _color,
                        onTap: () => setState(() => _color = hex),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.fromHex(hex)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: _isEditing ? 'Save changes' : 'Create category', onPressed: _submit, loading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerDot extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _PickerDot({required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: child,
      ),
    );
  }
}
