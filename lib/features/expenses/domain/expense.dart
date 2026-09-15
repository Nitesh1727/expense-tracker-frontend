import '../../categories/domain/category.dart';

class Expense {
  final String id;
  final double amount;
  final String description;
  final Category category;
  final DateTime date;

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        category: Category.fromJson(json['category'] as Map<String, dynamic>),
        date: DateTime.parse(json['date'] as String).toLocal(),
      );
}
