/// Fixed UTC+5:30 — India has no DST, so a constant offset is exact. Mirrors
/// backend/src/utils/dateRange.util.js so local-mode buckets and ranges land
/// on the same instants as the cloud's.
class Ist {
  Ist._();

  static const offsetMs = 19800000; // 5.5h
  static const dayMs = 86400000;

  /// Shifts an instant so its UTC fields read as IST wall-clock fields.
  static DateTime _shifted(DateTime instant) =>
      DateTime.fromMillisecondsSinceEpoch(instant.millisecondsSinceEpoch + offsetMs, isUtc: true);

  static DateTime _unshifted(DateTime shifted) =>
      DateTime.fromMillisecondsSinceEpoch(shifted.millisecondsSinceEpoch - offsetMs, isUtc: true);

  /// `yyyy-MM-dd` of the IST calendar date (UTC's date is wrong for anything
  /// between 00:00 and 05:30 IST).
  static String dateString(DateTime instant) {
    final s = _shifted(instant);
    return '${s.year.toString().padLeft(4, '0')}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
  }

  /// UTC instant of the IST midnight that starts IST day number [dayIndex]
  /// (days since the epoch, in IST).
  static DateTime instantOfDayIndex(int dayIndex) =>
      DateTime.fromMillisecondsSinceEpoch(dayIndex * dayMs - offsetMs, isUtc: true);

  /// `[start, end)` of the IST day/week(Mon-start)/month/year containing [anchor].
  static ({DateTime start, DateTime end}) range(String period, [DateTime? anchor]) {
    final s = _shifted(anchor ?? DateTime.now());
    final day = DateTime.utc(s.year, s.month, s.day);

    switch (period) {
      case 'day':
        return (start: _unshifted(day), end: _unshifted(day.add(const Duration(days: 1))));
      case 'week':
        final sinceMonday = (day.weekday - DateTime.monday) % 7; // Dart: Mon=1..Sun=7
        final start = day.subtract(Duration(days: sinceMonday));
        return (start: _unshifted(start), end: _unshifted(start.add(const Duration(days: 7))));
      case 'month':
        return (
          start: _unshifted(DateTime.utc(s.year, s.month, 1)),
          end: _unshifted(DateTime.utc(s.year, s.month + 1, 1)),
        );
      case 'year':
        return (start: _unshifted(DateTime.utc(s.year, 1, 1)), end: _unshifted(DateTime.utc(s.year + 1, 1, 1)));
      default:
        throw ArgumentError('Unknown period: $period');
    }
  }

  /// UTC instant of the IST midnight starting month [month] of [year].
  static DateTime monthStart(int year, int month) => _unshifted(DateTime.utc(year, month, 1));
}
