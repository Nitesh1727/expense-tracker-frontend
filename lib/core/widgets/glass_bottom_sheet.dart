import 'package:flutter/material.dart';

/// The bottom sheet treatment used everywhere a sheet is shown (add/edit
/// expense, category form/picker, edit profile) — a flat solid surface with
/// a drag handle, no blur. Matches the calm, minimal sheet style of the
/// Claude app rather than an iOS-style frosted glass effect. Centralized
/// here so every sheet in the app gets it the same way instead of each call
/// site reimplementing it slightly differently.
Future<T?> showGlassBottomSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surface,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Builder(builder: builder),
      ],
    ),
  );
}
