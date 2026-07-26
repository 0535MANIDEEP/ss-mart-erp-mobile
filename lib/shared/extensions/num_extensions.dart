import 'package:intl/intl.dart';

/// Extension methods on [num] for currency and display formatting.
extension NumExtensions on num {
  /// Formats as an Indian Rupee currency string.
  ///
  /// Example: `1500` → `'₹1,500.00'`
  String get currencyDisplay {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    return fmt.format(this);
  }

  /// Converts paise to rupees and formats as Indian Rupee currency.
  ///
  /// Example: `150000` → `'₹1,500.00'`
  String get paiseToRupees {
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    return fmt.format(this / 100);
  }

  /// Formats as an Indian number with comma grouping.
  ///
  /// Example: `1234567` → `'12,34,567'`
  String get displayNumber {
    final fmt = NumberFormat('#,##,###', 'en_IN');
    return fmt.format(this);
  }

  /// Formats as a percentage string.
  ///
  /// [decimals] controls the number of decimal places (default: 1).
  /// Example: `18.5` → `'18.5%'`
  String percentDisplay([int decimals = 1]) => '${toStringAsFixed(decimals)}%';

  /// Converts a rupee amount to paise (integer).
  ///
  /// Example: `15.50` → `1550`
  int get paiseFromRupees => (this * 100).round();
}
