import 'package:flutter/material.dart';
import '../constants/category_presets.dart';
import '../theme/app_colors.dart';

/// The colored circle + icon used everywhere a category needs a visual
/// identity: expense rows, category list, category pickers, chart legends.
class CategoryAvatar extends StatelessWidget {
  final String icon;
  final String colorHex;
  final double size;

  const CategoryAvatar({super.key, required this.icon, required this.colorHex, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHex(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Icon(CategoryPresets.iconFor(icon), color: color, size: size * 0.5),
    );
  }
}
