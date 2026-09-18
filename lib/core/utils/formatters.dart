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
  static final _fullMonthYear = DateFormat('MMMM yyyy');
  static final _weekday = DateFormat('EEEE');
  static final _year = DateFormat('yyyy');

  static String currency(double amount) => _currency.format(amount);

  /// "14 Sep" for the current year, "14 Sep 2025" otherwise — every
  /// expense-date display in the app routes through this one formatter, so
  /// fixing it here is enough for dates from a previous year to stop
  /// silently reading as if they were from this year everywhere at once.
  static String dayMonth(DateTime date) =>
      date.year == DateTime.now().year ? _dayMonth.format(date) : _dayMonthYear.format(date);
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

  /// The "which month/year am I looking at" header on the Analytics screen.
  /// [end] is the exclusive upper bound the backend returns (start of the
  /// *next* period) — subtract a day to get the period's actual last day.
  static String periodLabel(String period, DateTime start, DateTime end) {
    final lastDay = end.subtract(const Duration(days: 1));
    switch (period) {
      case 'day':
        return dayMonthYear(start);
      case 'week':
        final sameMonth = start.month == lastDay.month && start.year == lastDay.year;
        final startStr = sameMonth ? DateFormat('d').format(start) : dayMonth(start);
        return '$startStr – ${dayMonthYear(lastDay)}';
      case 'month':
        return _fullMonthYear.format(start);
      case 'year':
        return _year.format(start);
      default:
        return dayMonthYear(start);
    }
  }
}
