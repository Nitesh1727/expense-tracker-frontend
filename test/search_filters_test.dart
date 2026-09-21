import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/local/local_database.dart';
import 'package:frontend/features/categories/data/local_category_api.dart';
import 'package:frontend/features/categories/presentation/category_controller.dart';
import 'package:frontend/features/expenses/data/local_expense_api.dart';
import 'package:frontend/features/expenses/presentation/expense_providers.dart';
import 'package:frontend/features/expenses/presentation/expense_search_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('Search filters: select, deselect, and deselect everything', (tester) async {
    final db = LocalDatabase.withOpener(() => databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, singleInstance: false, onCreate: LocalDatabase.createSchema),
        ));
    final expenses = LocalExpenseApi(db);
    final categories = LocalCategoryApi(db);

    await tester.runAsync(() async {
      final all = await categories.list();
      String id(String n) => all.firstWhere((c) => c.name == n).id;
      await expenses.create(amount: 100, description: 'Pizza night', categoryId: id('Food'));
      await expenses.create(amount: 40, description: 'Bus pass', categoryId: id('Transport'));
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        expenseApiProvider.overrideWithValue(expenses),
        categoryApiProvider.overrideWithValue(categories),
      ],
      child: const MaterialApp(home: ExpenseSearchScreen()),
    ));

    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await settle();
    // Nothing selected, nothing typed: a prompt, not a silent "everything".
    expect(find.text('Search your expenses'), findsOneWidget);
    expect(find.text('Clear all'), findsNothing);

    // Filters are on the screen itself and start with nothing highlighted.
    expect(find.widgetWithText(FilterChip, 'Food'), findsOneWidget);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Food')).selected, isFalse);
    expect(find.widgetWithText(ChoiceChip, 'This month'), findsOneWidget);

    // Select a category: applies instantly, no Apply button.
    await tester.tap(find.widgetWithText(FilterChip, 'Food'));
    await settle();
    expect(find.text('Pizza night'), findsOneWidget);
    expect(find.text('Bus pass'), findsNothing);

    // Add a second category and a period.
    await tester.tap(find.widgetWithText(FilterChip, 'Transport'));
    await settle();
    expect(find.text('Bus pass'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'This month'));
    await settle();
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'This month')).selected, isTrue);
    expect(find.text('Pizza night'), findsOneWidget);

    // Deselect one at a time, all the way to nothing; nothing snaps back.
    await tester.tap(find.widgetWithText(ChoiceChip, 'This month'));
    await settle();
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'This month')).selected, isFalse);
    await tester.tap(find.widgetWithText(FilterChip, 'Food'));
    await settle();
    await tester.tap(find.widgetWithText(FilterChip, 'Transport'));
    await settle();

    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Food')).selected, isFalse);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Transport')).selected, isFalse);
    expect(find.text('Search your expenses'), findsOneWidget);
    expect(find.text('Clear all'), findsNothing);

    // "Clear all" resets several selections at once.
    await tester.tap(find.widgetWithText(FilterChip, 'Food'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Today'));
    await settle();
    await tester.tap(find.text('Clear all'));
    await settle();
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Food')).selected, isFalse);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Today')).selected, isFalse);

    // Unmount so the debounce/animation timers from the screen don't outlive the test.
    await tester.pumpWidget(const SizedBox());
  });
}
