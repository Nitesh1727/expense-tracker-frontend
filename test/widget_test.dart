import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/presentation/phone_entry_screen.dart';

void main() {
  // Deliberately pumps PhoneEntryScreen directly rather than the full
  // ExpenseTrackerApp: the real entry point starts by reading a token from
  // flutter_secure_storage, whose platform channel has no response in the
  // widget-test binding (no device/simulator behind it) and hangs rather
  // than erroring — a test-environment gap, not an app bug. Exercising the
  // full AuthController flow would need a mocked secure-storage channel,
  // which isn't worth the setup for what this test is checking.
  testWidgets('Phone entry screen shows the phone field and continue button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PhoneEntryScreen())),
    );
    // pumpAndSettle rides out the entrance animations (flutter_animate) on
    // this screen rather than leaving their tickers pending.
    await tester.pumpAndSettle();

    expect(find.text('Track your spending'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
  });
}
