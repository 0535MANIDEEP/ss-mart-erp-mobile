/// Date-specific utility extensions for the SS MART ERP application.
///
/// Provides commonly used date range calculations for reports, financial
/// year calculations, and date comparison helpers.
class AppDateUtils {
  AppDateUtils._();

  /// Returns true if [a] and [b] represent the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Returns true if [date] is today.
  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  /// Returns true if [date] is yesterday.
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  /// Returns true if [date] falls within the current week (Monday–Sunday).
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        date.isBefore(now.add(const Duration(days: 1)));
  }

  /// Returns true if [date] is in the current month and year.
  static bool isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  /// Returns true if [date] is in the current year.
  static bool isThisYear(DateTime date) {
    return date.year == DateTime.now().year;
  }

  /// Returns the number of whole days between [start] and [end].
  ///
  /// The result is always non-negative regardless of argument order.
  static int daysBetween(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }

  /// Returns a list of 7 consecutive days starting from [start].
  ///
  /// Useful for rendering a weekly calendar view.
  static List<DateTime> getWeekdayRange(DateTime start) {
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }
}
