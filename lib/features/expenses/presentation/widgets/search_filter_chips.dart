import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/friendly_date_range_picker.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../categories/presentation/category_controller.dart';
import '../../domain/expense_history_filter.dart';
import '../expense_providers.dart';

/// Category + time-period filters shown directly on the Search screen, applied
/// the instant a chip is tapped (no Apply step). Every chip can be turned off
/// again, including down to nothing selected at all — nothing is ever
/// re-selected on the user's behalf, and there is deliberately no "All" chip:
/// an empty selection simply means that dimension isn't filtering.
class SearchFilterChips extends ConsumerWidget {
  /// Called after the filter provider changed, so the screen can re-run its search.
  final VoidCallback onChanged;

  const SearchFilterChips({super.key, required this.onChanged});

  static const _presets = [
    HistoryPeriodPreset.today,
    HistoryPeriodPreset.week,
    HistoryPeriodPreset.month,
    HistoryPeriodPreset.lastMonth,
  ];

  void _set(WidgetRef ref, ExpenseHistoryFilter filter) {
    ref.read(expenseHistoryFilterProvider.notifier).set(filter);
    onChanged();
  }

  void _toggleCategory(WidgetRef ref, ExpenseHistoryFilter filter, String id, bool selected) {
    final ids = {...filter.categoryIds};
    selected ? ids.add(id) : ids.remove(id);
    _set(ref, ExpenseHistoryFilter(categoryIds: ids, period: filter.period, from: filter.from, to: filter.to));
  }

  void _togglePreset(WidgetRef ref, ExpenseHistoryFilter filter, HistoryPeriodPreset preset) {
    if (filter.period == preset) {
      _set(ref, ExpenseHistoryFilter(categoryIds: filter.categoryIds)); // back to no period filter
      return;
    }
    final (from, to) = ExpenseHistoryFilter.rangeFor(preset)!;
    _set(ref, ExpenseHistoryFilter(categoryIds: filter.categoryIds, period: preset, from: from, to: to));
  }

  Future<void> _pickCustom(BuildContext context, WidgetRef ref, ExpenseHistoryFilter filter) async {
    if (filter.period == HistoryPeriodPreset.custom) {
      _set(ref, ExpenseHistoryFilter(categoryIds: filter.categoryIds));
      return;
    }
    final now = DateTime.now();
    final picked = await pickFriendlyDateRange(
      context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initial: DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );
    if (picked == null) return;
    _set(
      ref,
      ExpenseHistoryFilter(
        categoryIds: filter.categoryIds,
        period: HistoryPeriodPreset.custom,
        from: DateTime(picked.start.year, picked.start.month, picked.start.day),
        // The picker's end day is inclusive; the API range is [from, to).
        to: DateTime(picked.end.year, picked.end.month, picked.end.day).add(const Duration(days: 1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(expenseHistoryFilterProvider);
    final categories = ref.watch(categoryControllerProvider).value ?? const [];

    Widget row(List<Widget> chips, {Widget? trailing}) => SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: chips.length,
                  separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) => Center(child: chips[i]),
                ),
              ),
              ?trailing,
            ],
          ),
        );

    final customLabel = filter.period == HistoryPeriodPreset.custom && filter.from != null && filter.to != null
        ? '${Formatters.dayMonth(filter.from!)} – ${Formatters.dayMonth(filter.to!.subtract(const Duration(days: 1)))}'
        : 'Custom';

    return Column(
      children: [
        row([
          for (final category in categories)
            ConstrainedBox(
              // Names are capped at 30 characters; this keeps a long one from
              // stretching the chip arbitrarily wide.
              constraints: const BoxConstraints(maxWidth: 200),
              child: FilterChip(
                avatar: CategoryAvatar(icon: category.icon, colorHex: category.color, size: 20),
                label: Text(category.name, overflow: TextOverflow.ellipsis),
                selected: filter.categoryIds.contains(category.id),
                onSelected: (selected) => _toggleCategory(ref, filter, category.id, selected),
              ),
            ),
        ]),
        row([
          for (final preset in _presets)
            ChoiceChip(
              label: Text(preset.label),
              selected: filter.period == preset,
              onSelected: (_) => _togglePreset(ref, filter, preset),
            ),
          ChoiceChip(
            avatar: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(customLabel),
            selected: filter.period == HistoryPeriodPreset.custom,
            onSelected: (_) => _pickCustom(context, ref, filter),
          ),
        ], trailing: filter.isActive
            // Pinned outside the scrolling row so it never ends up off-screen.
            ? Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: TextButton(
                  onPressed: () => _set(ref, const ExpenseHistoryFilter()),
                  child: const Text('Clear all'),
                ),
              )
            : null),
      ],
    );
  }
}
