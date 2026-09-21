import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/local/local_database.dart';
import 'package:frontend/features/categories/data/local_category_api.dart';
import 'package:frontend/features/categories/presentation/category_controller.dart';
import 'package:frontend/features/expenses/presentation/expense_providers.dart';
import 'package:frontend/features/expenses/presentation/widgets/expense_history_filter_sheet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('Filters sheet: All / All time chips, and nothing-selected is allowed', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = LocalDatabase.withOpener(() => databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, singleInstance: false, onCreate: LocalDatabase.createSchema),
        ));
    final container = ProviderContainer(overrides: [categoryApiProvider.overrideWithValue(LocalCategoryApi(db))]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(onPressed: () => showExpenseHistoryFilterSheet(context), child: const Text('open')),
        ),
      ),
    ));

    Future<void> settle() async {
      // Route/sheet animations need a frame to finish and another to remove the route.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
    }

    bool sel(Type t, String label) {
      final f = find.widgetWithText(t == FilterChip ? FilterChip : ChoiceChip, label);
      return t == FilterChip ? tester.widget<FilterChip>(f).selected : tester.widget<ChoiceChip>(f).selected;
    }

    Future<void> openSheet() async {
      await tester.tap(find.text('open'));
      // Poll (in real time, for the SQLite fetch) until the categories render.
      for (var i = 0; i < 50 && find.widgetWithText(FilterChip, 'Food').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      }
      await settle();
    }

    await openSheet();

    // Both new options exist, and nothing at all is highlighted to begin with.
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All time'), findsOneWidget);
    expect(sel(FilterChip, 'All'), isFalse);
    expect(sel(ChoiceChip, 'All time'), isFalse);

    // "All" and a specific category are mutually exclusive.
    await tester.tap(find.widgetWithText(FilterChip, 'Food'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pump();
    expect(sel(FilterChip, 'All'), isTrue);
    expect(sel(FilterChip, 'Food'), isFalse);
    await tester.tap(find.widgetWithText(FilterChip, 'Bills'));
    await tester.pump();
    expect(sel(FilterChip, 'All'), isFalse);
    expect(sel(FilterChip, 'Bills'), isTrue);

    // Deselecting everything leaves nothing chosen: no fallback to All.
    await tester.tap(find.widgetWithText(FilterChip, 'Bills'));
    await tester.pump();
    expect(sel(FilterChip, 'All'), isFalse);
    expect(sel(FilterChip, 'Bills'), isFalse);

    // "All time" is a normal chip: selectable, and deselectable again.
    await tester.tap(find.widgetWithText(ChoiceChip, 'This month'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ChoiceChip, 'All time'));
    await tester.pump();
    expect(sel(ChoiceChip, 'All time'), isTrue);
    expect(sel(ChoiceChip, 'This month'), isFalse);
    await tester.tap(find.widgetWithText(ChoiceChip, 'All time'));
    await tester.pump();
    expect(sel(ChoiceChip, 'All time'), isFalse);

    // Apply "All" + "All time": no filtering, but the choice is remembered.
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'All time'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await settle();
    final applied = container.read(expenseHistoryFilterProvider);
    expect(applied.isActive, isFalse);
    expect((applied.allCategories, applied.allTime), (true, true));

    // Reopening shows exactly what was chosen (the Search screen marks the
    // filter as applied when the sheet returns true; do the same here).
    container.read(expenseFiltersEverAppliedProvider.notifier).set(true);
    await openSheet();
    expect(sel(FilterChip, 'All'), isTrue);
    expect(sel(ChoiceChip, 'All time'), isTrue);
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'All time'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await settle();
    container.read(expenseFiltersEverAppliedProvider.notifier).set(true);
    await openSheet();
    expect(sel(FilterChip, 'All'), isFalse);
    expect(sel(ChoiceChip, 'All time'), isFalse);
  });
}
