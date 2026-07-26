import 'package:intl/intl.dart';

/// Extension methods on [DateTime] for common date display and comparison.
extension DateTimeExtensions on DateTime {
  /// Formats as `dd/MM/yyyy` for display.
  String get displayDate => DateFormat('dd/MM/yyyy').format(this);

  /// Formats as `dd/MM/yyyy HH:mm` for display.
  String get displayDateTime => DateFormat('dd/MM/yyyy HH:mm').format(this);

  /// Formats as `HH:mm` for display.
  String get displayTime => DateFormat('HH:mm').format(this);

  /// Formats as `MMM yyyy` for display (e.g., 'Jul 2026').
  String get displayMonthYear => DateFormat('MMM yyyy').format(this);

  /// Formats as full date for display (e.g., 'Saturday, 25 July 2026').
  String get displayFullDate => DateFormat('EEEE, dd MMMM yyyy').format(this);

  /// Formats as `yyyy-MM-dd` for API communication.
  String get apiDate => DateFormat('yyyy-MM-dd').format(this);

  /// Returns true if this date is today.
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Returns true if this date is yesterday.
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  /// Returns true if this date falls within the current week.
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(now.add(const Duration(days: 1)));
  }

  /// Returns a new [DateTime] with the time component set to midnight.
  DateTime get startOfDay => DateTime(year, month, day);

  /// Returns a new [DateTime] with the time component set to 23:59:59.
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);

  /// Returns the first day of this date's month at midnight.
  DateTime get startOfMonth => DateTime(year, month, 1);

  /// Returns the last day of this date's month at 23:59:59.
  DateTime get endOfMonth => DateTime(year, month + 1, 0, 23, 59, 59);

  /// Returns the number of whole days from this date to [other].
  ///
  /// The result is negative if [other] is before this date.
  int daysUntil(DateTime other) => other.difference(this).inDays;
}
