import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../domain/expense.dart';

/// One row in any expense list (Home's expanded day-tiles, History).
/// [showDate] defaults on since most contexts (History's flat, mixed-date
/// list) need it to make sense of the item — DayTile turns it off since its
/// header already states the date and repeating it on every row would be
/// redundant clutter. Missing entirely from a flat list is what actually
/// prompted this — see frontend STATUS.md decisions log.
class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final bool showDate;

  const ExpenseTile({super.key, required this.expense, required this.onTap, this.showDate = true});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryLine = showDate ? '${expense.category.name} · ${Formatters.dayMonth(expense.date)}' : expense.category.name;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            CategoryAvatar(icon: expense.category.icon, colorHex: expense.category.color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.description, style: textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    secondaryLine,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(Formatters.currency(expense.amount), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
