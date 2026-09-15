import 'package:flutter/material.dart';

/// Mirrors backend/src/constants/categoryPresets.js exactly. The backend
/// only ever stores/sends the icon key string and hex color — this file is
/// the one place that maps those to actual Flutter icons/colors. Keep both
/// files in sync if the curated sets ever change.
class CategoryPresets {
  CategoryPresets._();

  static const Map<String, IconData> icons = {
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'movie': Icons.movie,
    'favorite': Icons.favorite,
    'category': Icons.category,
    'home': Icons.home,
    'flight': Icons.flight,
    'school': Icons.school,
    'fitness_center': Icons.fitness_center,
    'pets': Icons.pets,
    'local_grocery_store': Icons.local_grocery_store,
    'sports_esports': Icons.sports_esports,
    'local_hospital': Icons.local_hospital,
    'coffee': Icons.coffee,
  };

  static const List<String> colorHexes = [
    '#F59E0B', // amber
    '#3B82F6', // blue
    '#8B5CF6', // violet
    '#EF4444', // red-orange
    '#EC4899', // pink
    '#14B8A6', // teal
    '#6B7280', // gray
    '#22C55E', // green
    '#6366F1', // indigo
    '#92400E', // brown
  ];

  /// Falls back to a generic icon if the backend ever sends a key this
  /// build doesn't know about yet (e.g. app hasn't been updated) — never
  /// crash rendering a category.
  static IconData iconFor(String key) => icons[key] ?? Icons.category;
}
