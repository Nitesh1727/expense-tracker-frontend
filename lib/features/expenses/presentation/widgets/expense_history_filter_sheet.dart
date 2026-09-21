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

/// Category + time period filter, opened from the Search screen's Filters
/// button — both compose together (not either/or), and both compose with
/// Search's own text query too. Used to be its own separate "History"
/// screen with its own Filter entry point from Home; merged into Search
/// per explicit user feedback that the two screens did almost the same
/// thing. Edits happen on a local draft; nothing takes effect until "Apply"
/// (or "Clear filters", which resets and applies immediately) — see
/// ExpenseHistoryFilter for why the draft isn't just written straight to
/// the provider on every tap.
///
/// Returns `true` if "Apply" was pressed, `false` if "Clear filters" was, or
/// `null` if the sheet was dismissed without either (back gesture, tap
/// outside). The caller needs this distinction, not just "did the provider
/// change" — pressing Apply while "All categories"/"All time" are still the
/// selected defaults is a real, explicit choice to browse everything, which
/// reads differently from the sheet never having been touched at all (see
/// ExpenseSearchScreen, which shows a "search your expenses" prompt in the
/// untouched case but actual results — everything, unfiltered — once Apply
/// has genuinely been pressed).
Future<bool?> showExpenseHistoryFilterSheet(BuildContext context) {
  return showGlassBottomSheet<bool>(context, builder: (context) => const _ExpenseHistoryFilterSheet());
}

class _ExpenseHistoryFilterSheet extends ConsumerStatefulWidget {
  const _ExpenseHistoryFilterSheet();

  @override
  ConsumerState<_ExpenseHistoryFilterSheet> createState() => _ExpenseHistoryFilterSheetState();
}

class _ExpenseHistoryFilterSheetState extends ConsumerState<_ExpenseHistoryFilterSheet> {
  // Both nullable — `null` means "the user hasn't tapped anything in this
  // group yet", rendered with *no* chip highlighted (not even "All"/
  // "All time"), per explicit user feedback that pre-selecting those by
  // default looked like a choice had already been made. Only populated
  // from the current filter if it was actually applied before (re-opening
  // Filters after a previous Apply correctly shows what you picked, rather
  // than blanking out every time).
  Set<String>? _categoryIds;
  bool _allCategories = false; // the explicit "All" chip; mutually exclusive with specific categories
  HistoryPeriodPreset? _period; // HistoryPeriodPreset.all is the explicit "All time" chip
  DateTime? _customFrom;
  DateTime? _customTo; // exclusive, but stored/shown as the inclusive last day minus a day — see _pickCustomRange

  @override
  void initState() {
    super.initState();
    if (ref.read(expenseFiltersEverAppliedProvider)) {
      final current = ref.read(expenseHistoryFilterProvider);
      _categoryIds = {...current.categoryIds};
      _allCategories = current.allCategories;
      // `all` is also what "nothing chosen" is stored as, so only show the
      // "All time" chip highlighted if it was actually picked.
      _period = (current.period == HistoryPeriodPreset.all && !current.allTime) ? null : current.period;
      if (current.period == HistoryPeriodPreset.custom) {
        _customFrom = current.from;
        _customTo = current.to;
      }
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
    // Nothing tapped in a group defaults to "All"/"All time" — pressing
    // Apply at all is the explicit choice, even if every individual chip
    // is still at its untouched default.
    final period = _period ?? HistoryPeriodPreset.all;
    final categoryIds = _categoryIds ?? const <String>{};

    final (from, to) = switch (period) {
      HistoryPeriodPreset.custom => (_customFrom, _customTo),
      HistoryPeriodPreset.all => (null, null),
      _ => ExpenseHistoryFilter.rangeFor(period) ?? (null, null),
    };

    ref.read(expenseHistoryFilterProvider.notifier).set(
          ExpenseHistoryFilter(
            categoryIds: categoryIds,
            period: period,
            from: from,
            to: to,
            allCategories: _allCategories,
            allTime: _period == HistoryPeriodPreset.all,
          ),
        );
    Navigator.of(context).pop(true);
  }

  void _clear() {
    ref.read(expenseHistoryFilterProvider.notifier).set(const ExpenseHistoryFilter());
    Navigator.of(context).pop(false);
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
                'Category / Categories',
                style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              categoriesAsync.when(
                loading: () => const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                error: (e, _) => Text('Could not load categories', style: textTheme.bodySmall),
                // "All" is an explicit choice like any other chip: it can be
                // switched off again, and deselecting everything leaves nothing
                // highlighted rather than snapping back to it. Bounded +
                // independently scrollable since there's no cap on how many
                // categories a user can add.
                data: (categories) => ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _allCategories,
                          onSelected: (selected) => setState(() {
                            // Picking "All" replaces any specific categories;
                            // tapping it again leaves nothing chosen.
                            _allCategories = selected;
                            if (selected) _categoryIds = {};
                          }),
                        ),
                        for (final category in categories)
                          ConstrainedBox(
                            // Category names are already capped at 30 chars
                            // server-side, but this guards the layout too in
                            // case that ever changes or data arrives from
                            // elsewhere — ellipsizes instead of stretching
                            // the chip arbitrarily wide.
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: FilterChip(
                              avatar: CategoryAvatar(icon: category.icon, colorHex: category.color, size: 20),
                              label: Text(category.name, overflow: TextOverflow.ellipsis),
                              selected: _categoryIds?.contains(category.id) ?? false,
                              onSelected: (selected) => setState(() {
                                _allCategories = false;
                                _categoryIds ??= {};
                                if (selected) {
                                  _categoryIds!.add(category.id);
                                } else {
                                  _categoryIds!.remove(category.id);
                                }
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Time period', style: textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              // No chip highlighted until one is explicitly tapped —
              // `_period == null` means nothing chosen. Tapping an
              // already-selected chip again clears it back to null.
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
                          setState(() => _period = _period == preset ? null : preset);
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
