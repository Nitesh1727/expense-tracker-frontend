import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../domain/expense.dart';

/// One row in any expense list (Home recents, History). Deliberately just
/// icon + description + amount + date — resist adding a second metadata
/// line unless asked (see frontend/docs/DESIGN_SYSTEM.md "Component notes").
class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;

  const ExpenseTile({super.key, required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

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
                    expense.category.name,
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
