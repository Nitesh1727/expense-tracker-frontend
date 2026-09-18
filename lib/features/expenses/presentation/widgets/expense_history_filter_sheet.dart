import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/friendly_date_range_picker.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/glass_bottom_sheet.dart';
import '../../../categories/presentation/category_controller.dart';
import '../../domain/expense_history_filter.dart';
import '../expense_providers.dart';

/// Category + time period filter for the full expense history — both
/// compose together (not either/or). Edits happen on a local draft; nothing
/// takes effect until "Apply" (or "Clear filters", which resets and applies
/// immediately) — see ExpenseHistoryFilter for why the draft isn't just
/// written straight to the provider on every tap.
Future<void> showExpenseHistoryFilterSheet(BuildContext context) {
  return showGlassBottomSheet(context, builder: (context) => const _ExpenseHistoryFilterSheet());
}

class _ExpenseHistoryFilterSheet extends ConsumerStatefulWidget {
  const _ExpenseHistoryFilterSheet();

  @override
  ConsumerState<_ExpenseHistoryFilterSheet> createState() => _ExpenseHistoryFilterSheetState();
}

class _ExpenseHistoryFilterSheetState extends ConsumerState<_ExpenseHistoryFilterSheet> {
  late Set<String> _categoryIds;
  late HistoryPeriodPreset _period;
  DateTime? _customFrom;
  DateTime? _customTo; // exclusive, but stored/shown as the inclusive last day minus a day — see _pickCustomRange

  @override
  void initState() {
    super.initState();
    final current = ref.read(expenseHistoryFilterProvider);
    _categoryIds = {...current.categoryIds};
    _period = current.period;
    if (current.period == HistoryPeriodPreset.custom) {
      _customFrom = current.from;
      _customTo = current.to;
    }
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initial = (_customFrom != null && _customTo != null)
        ? DateTimeRange(start: _customFrom!, end: _customTo!.subtract(const Duration(days: 1)))
        : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);

    final picked = await pickFriendlyDateRange(
      context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initial: initial,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _period = HistoryPeriodPreset.custom;
      _customFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
      // Picker gives an inclusive last day — the API's range is [from, to),
      // so add a day to cover all of it.
      _customTo = DateTime(picked.end.year, picked.end.month, picked.end.day).add(const Duration(days: 1));
    });
  }

  void _apply() {
    final (from, to) = switch (_period) {
      HistoryPeriodPreset.custom => (_customFrom, _customTo),
      HistoryPeriodPreset.all => (null, null),
      _ => ExpenseHistoryFilter.rangeFor(_period) ?? (null, null),
    };

    ref.read(expenseHistoryFilterProvider.notifier).set(
          ExpenseHistoryFilter(categoryIds: _categoryIds, period: _period, from: from, to: to),
        );
    Navigator.of(context).pop();
  }

  void _clear() {
    ref.read(expenseHistoryFilterProvider.notifier).set(const ExpenseHistoryFilter());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final categoriesAsync = ref.watch(categoryControllerProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filters', style: textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Category (pick any number)',
                style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              categoriesAsync.when(
                loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, _) => Text('Could not load categories', style: textTheme.bodySmall),
                data: (categories) => Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    // "All" clears the whole set rather than being one more
                    // toggle among many — selecting any specific category
                    // while "All" is also selected wouldn't mean anything.
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _categoryIds.isEmpty,
                      onSelected: (_) => setState(() => _categoryIds.clear()),
                    ),
                    for (final category in categories)
                      FilterChip(
                        avatar: CategoryAvatar(icon: category.icon, colorHex: category.color, size: 20),
                        label: Text(category.name),
                        selected: _categoryIds.contains(category.id),
                        onSelected: (selected) => setState(() {
                          if (selected) {
                            _categoryIds.add(category.id);
                          } else {
                            _categoryIds.remove(category.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Time period', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final preset in HistoryPeriodPreset.values)
                    ChoiceChip(
                      label: Text(preset.label),
                      selected: _period == preset,
                      onSelected: (_) {
                        if (preset == HistoryPeriodPreset.custom) {
                          _pickCustomRange();
                        } else {
                          setState(() => _period = preset);
                        }
                      },
                    ),
                ],
              ),
              if (_period == HistoryPeriodPreset.custom && _customFrom != null && _customTo != null) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    '${Formatters.dayMonthYear(_customFrom!)} – '
                    '${Formatters.dayMonthYear(_customTo!.subtract(const Duration(days: 1)))}',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  TextButton(onPressed: _clear, child: const Text('Clear filters')),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: AppButton(label: 'Apply', onPressed: _apply)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
