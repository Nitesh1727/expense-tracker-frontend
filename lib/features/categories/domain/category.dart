class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
  final bool isDeletable;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.isDeletable,
  });

  /// The full category resource uses `_id` (like every other Mongoose doc);
  /// the analytics endpoints embed a smaller `{id, name, icon, color}`
  /// projection (see backend/docs/API.md) — this handles both shapes so
  /// there's one Category model instead of two near-identical ones.
  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: (json['_id'] ?? json['id']) as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        color: json['color'] as String,
        isDeletable: json['isDeletable'] as bool? ?? true,
      );
}
