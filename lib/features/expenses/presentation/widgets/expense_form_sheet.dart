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

/// `toStringAsFixed(0)` alone would silently round a decimal amount (e.g.
/// 45.50) down to "46"/"45" when pre-filling this field to edit an existing
/// expense — caught live: saving without noticing the field had changed
/// would overwrite the original amount with the rounded whole number. Only
/// drops the decimal part when the amount actually is a whole number.
String _formatAmountForInput(double amount) {
  final fixed = amount.toStringAsFixed(2);
  return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
}

class _ExpenseFormSheet extends ConsumerStatefulWidget {
  final Expense? existing;

  const _ExpenseFormSheet({this.existing});

  @override
  ConsumerState<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<_ExpenseFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _categoryFieldKey = GlobalKey<FormFieldState<String>>();
  final _amountFocusNode = FocusNode();
  late final _amountController = TextEditingController(
    text: widget.existing != null ? _formatAmountForInput(widget.existing!.amount) : '',
  );
  late final _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
  Category? _selectedCategory;
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  bool _saving = false;
  bool _deleting = false;
  // Shown inline rather than via SnackBar — a SnackBar anchors to the
  // Scaffold *behind* this sheet, and since the sheet already covers the
  // bottom of the screen (the same place a SnackBar renders), it appeared
  // invisible behind the sheet. Rendering the error inside the sheet's own
  // widget tree guarantees it's visible while the sheet is open.
  String? _formError;

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
    if (category != null) {
      setState(() {
        _selectedCategory = category;
        _formError = null;
      });
      // Re-validates just this field so its error clears the instant a
      // category is picked, without waiting for the next full-form submit.
      _categoryFieldKey.currentState?.validate();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    // The category field is a FormField too (see build()), so this single
    // validate() call covers amount, description, and category together —
    // all three show their errors in the same pass, in the same inline
    // style, instead of category needing a separate manual check.
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
      setState(() => _formError = message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// No confirmation dialog — matches the existing swipe-to-delete on the
  /// full history list (expense_history_screen.dart), which also deletes
  /// immediately. `ExpenseMutationController.delete` already refreshes every
  /// dependent (Home feed, analytics, history), so closing this sheet leaves
  /// every screen already showing the deletion, not just this one.
  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await ref.read(expenseMutationControllerProvider.notifier).delete(widget.existing!.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException ? e.message : 'Could not delete expense';
      setState(() => _formError = message);
    } finally {
      if (mounted) setState(() => _deleting = false);
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
            // Sheets from showGlassBottomSheet (isScrollControlled: true)
            // don't auto-scroll their content — with the delete button, both
            // text fields, category/date row, and an error banner all
            // stacked up, a shorter viewport (landscape) or a larger text-
            // size setting could ask for more height than's available. This
            // wrap is a no-op in the common case (content already fits, so
            // nothing visibly scrolls) and just prevents an overflow crash
            // in the tighter ones.
            child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_isEditing ? 'Edit expense' : 'Add expense', style: textTheme.titleLarge),
                    if (_isEditing)
                      IconButton(
                        icon: _deleting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.error),
                              )
                            : Icon(Icons.delete_outline, color: colorScheme.error),
                        tooltip: 'Delete expense',
                        onPressed: (_saving || _deleting) ? null : _delete,
                      ),
                  ],
                ),
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
                  // Matches the backend's own cap (expense.validator.js) —
                  // enforced here too so a long description is caught while
                  // typing instead of only failing on submit.
                  maxLength: 30,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Pizza, Uber ride'),
                  validator: (value) => (value?.trim().isEmpty ?? true) ? 'Add a short description' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      // A FormField (not just a button) so "Choose a category"
                      // participates in the same Form.validate() pass as the
                      // amount/description TextFormFields above and renders
                      // with the exact same default error-text style, instead
                      // of a one-off look just for this field.
                      child: FormField<String>(
                        key: _categoryFieldKey,
                        validator: (_) => _selectedCategory == null ? 'Choose a category' : null,
                        builder: (field) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickCategory,
                              icon: _selectedCategory != null
                                  ? CategoryAvatar(icon: _selectedCategory!.icon, colorHex: _selectedCategory!.color, size: 24)
                                  : const Icon(Icons.category_outlined),
                              label: Text(_selectedCategory?.name ?? 'Category', overflow: TextOverflow.ellipsis),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                                side: BorderSide(color: field.hasError ? colorScheme.error : colorScheme.outline),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            if (field.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 8, left: 12),
                                child: Text(field.errorText!, style: textTheme.bodySmall?.copyWith(color: colorScheme.error)),
                              ),
                          ],
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
                if (_formError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 18, color: colorScheme.onErrorContainer),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(_formError!, style: textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: _isEditing ? 'Save changes' : 'Add expense',
                  onPressed: _deleting ? null : _submit,
                  loading: _saving,
                ),
              ],
            )),
          ),
        ),
      ),
    );
  }
}
