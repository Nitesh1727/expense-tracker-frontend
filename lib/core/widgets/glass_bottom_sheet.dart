import 'dart:ui';
import 'package:flutter/material.dart';

/// The "liquid glass" bottom sheet treatment used everywhere a sheet is
/// shown (add/edit expense, category form/picker, edit profile) — a real
/// frosted-glass blur over whatever's behind it, not just a solid surface
/// color, via BackdropFilter. Centralized here so every sheet in the app
/// gets it the same way instead of each call site reimplementing it
/// slightly differently.
Future<T?> showGlassBottomSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  final colorScheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (context) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.82),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.25), width: 1)),
          ),
          child: Column(
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
        ),
      ),
    ),
  );
}
