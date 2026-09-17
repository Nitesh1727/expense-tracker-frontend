import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Shown wherever a list can legitimately be empty (no expenses yet, no
/// results for a filter) — an empty screen with no explanation reads as
/// broken, not minimal.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Center, not just crossAxisAlignment.center on the inner Column — that
    // only centers content *within the Column's own width*, and a Column
    // nested inside a parent with crossAxisAlignment.start (e.g. Analytics'
    // body) gets loose constraints and shrink-wraps to its widest child
    // instead of filling the row, so it visibly sat left-of-center there.
    // Center here makes this widget correct regardless of the parent's own
    // alignment, rather than relying on every call site to wrap it itself.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
