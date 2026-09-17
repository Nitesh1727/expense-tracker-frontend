import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/glass_bottom_sheet.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/widgets/category_picker_sheet.dart';
import '../../domain/expense.dart';
import '../expense_providers.dart';

/// Add or edit an expense, as a bottom sheet rather than a full-screen
/// route — one thumb-reachable tap to open, swipe down to dismiss. Matches
/// the "minimal fields, quick entry" goal (frontend/docs/DESIGN_SYSTEM.md).
Future<void> showExpenseFormSheet(BuildContext context, {Expense? existing}) {
  return showGlassBottomSheet(context, builder: (context) => _ExpenseFormSheet(existing: existing));
}

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  final Expense? existing;

  const _ExpenseFormSheet({this.existing});

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountFocusNode = FocusNode();
  late final _amountController = TextEditingController(
    text: widget.existing != null ? widget.existing!.amount.toStringAsFixed(0) : '',
  );
  late final _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
  Category? _selectedCategory;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.existing?.category;
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusAmountOnceSheetSettles());
    }
  }

  /// The amount field used to be `autofocus: true`, which requested the
  /// keyboard the instant this sheet built — at the same moment the sheet's
  /// own slide-up transition started. Two animations racing at once (each
  /// forcing a relayout of the whole form via `viewInsets.bottom` changing)
  /// was the actual cause of the perceptible lag opening this sheet, not the
  /// form itself being heavy. Waiting for the enclosing route's transition
  /// to finish before requesting focus lets the sheet finish sliding in
  /// first, so the keyboard's own animation runs on its own.
  void _focusAmountOnceSheetSettles() {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _amountFocusNode.requestFocus();
      return;
    }
    void listener(AnimationStatus status) {
      if (status != AnimationStatus.completed) return;
      animation.removeStatusListener(listener);
      if (mounted) _amountFocusNode.requestFocus();
    }

    animation.addStatusListener(listener);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickCategory() async {
    final category = await showCategoryPicker(context, selectedId: _selectedCategory?.id);
    if (category != null) setState(() => _selectedCategory = category);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a category')));
      return;
    }

    setState(() => _saving = true);
    final amount = double.parse(_amountController.text.trim());
    final description = _descriptionController.text.trim();
    final mutations = ref.read(expenseMutationControllerProvider.notifier);

    try {
      if (_isEditing) {
        await mutations.updateExpense(
          widget.existing!.id,
          amount: amount,
          description: description,
          categoryId: _selectedCategory!.id,
          date: _date,
        );
      } else {
        await mutations.create(amount: amount, description: description, categoryId: _selectedCategory!.id, date: _date);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not save expense';
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isEditing ? 'Edit expense' : 'Add expense', style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _amountController,
                  focusNode: _amountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  // headlineMedium's size, but forced back to the sans body font —
                  // this is the amount input, not a heading, and AppTheme applies a
                  // serif to headlineMedium for actual section headings.
                  style: textTheme.headlineMedium?.copyWith(fontFamily: textTheme.bodyLarge?.fontFamily),
                  decoration: const InputDecoration(prefixText: '₹  ', hintText: '0'),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (amount == null || amount <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Lunch with team'),
                  validator: (value) => (value?.trim().isEmpty ?? true) ? 'Add a short description' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickCategory,
                        icon: _selectedCategory != null
                            ? CategoryAvatar(icon: _selectedCategory!.icon, colorHex: _selectedCategory!.color, size: 24)
                            : const Icon(Icons.category_outlined),
                        label: Text(_selectedCategory?.name ?? 'Category', overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          side: BorderSide(color: colorScheme.outline),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined, size: 18),
                        label: Text(Formatters.dayMonth(_date)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          side: BorderSide(color: colorScheme.outline),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(label: _isEditing ? 'Save changes' : 'Add expense', onPressed: _submit, loading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
