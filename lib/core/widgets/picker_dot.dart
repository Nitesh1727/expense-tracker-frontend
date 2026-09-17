import 'package:flutter/material.dart';

/// A circular swatch with a selection ring — shared by every curated-choice
/// color grid (category color/icon pickers, Settings' accent color picker)
/// so the selected-state treatment stays identical everywhere.
class PickerDot extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const PickerDot({super.key, required this.selected, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
        ),
        child: child,
      ),
    );
  }
}
