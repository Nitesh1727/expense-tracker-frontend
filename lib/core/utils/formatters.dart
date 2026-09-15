import 'package:intl/intl.dart';

/// Centralized so every screen formats money/dates the same way. Currency
/// is a flat ₹ symbol for v1 (see backend/docs/DATABASE.md — `users.currency`
/// exists per-user but there's no multi-currency conversion yet).
class Formatters {
  Formatters._();

  static final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _monthYear = DateFormat('MMM yyyy');
  static final _weekday = DateFormat('EEEE');

  static String currency(double amount) => _currency.format(amount);

  static String dayMonth(DateTime date) => _dayMonth.format(date);
  static String dayMonthYear(DateTime date) => _dayMonthYear.format(date);
  static String monthYear(DateTime date) => _monthYear.format(date);
  static String weekday(DateTime date) => _weekday.format(date);

  /// Groups a date as "Today" / "Yesterday" / weekday name / "d MMM" — used
  /// by the Home screen's recent-expenses sections.
  static String relativeDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff > 1 && diff < 7) return weekday(date);
    return dayMonth(date);
  }
}
