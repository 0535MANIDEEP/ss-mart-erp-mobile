import 'package:intl/intl.dart';

/// Display formatting utilities for the SS MART ERP application.
///
/// Provides consistent formatting for currency, dates, numbers, and other
/// display values across the entire application. All monetary values are
/// formatted in Indian Rupee (INR) notation with the ₹ symbol.
///
/// Note: Monetary values are stored as integer paise in the database.
/// All methods that accept [amountPaise] expect the value in paise
/// (divide rupees by 100 before passing).
class AppFormatters {
  AppFormatters._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _numberFormat = NumberFormat('#,##,###', 'en_IN');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _monthYearFormat = DateFormat('MMM yyyy');
  static final DateFormat _dayFormat = DateFormat('EEEE');
  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');

  /// Formats integer paise to Indian Rupee display string.
  ///
  /// Example: `150000` → `'₹1,500.00'`
  static String currency(int amountPaise) {
    return _currencyFormat.format(amountPaise / 100);
  }

  /// Formats a double rupee amount to display string.
  ///
  /// Example: `1500.50` → `'₹1,500.50'`
  static String currencyDouble(double amountRupees) {
    return _currencyFormat.format(amountRupees);
  }

  /// Formats an integer to Indian number notation with commas.
  ///
  /// Example: `1234567` → `'12,34,567'`
  static String number(int value) {
    return _numberFormat.format(value);
  }

  /// Formats a double to fixed decimal places.
  ///
  /// [decimals] defaults to 2.
  static String decimal(double value, [int decimals = 2]) {
    return value.toStringAsFixed(decimals);
  }

  /// Formats a DateTime to `dd/MM/yyyy`.
  static String date(DateTime dt) => _dateFormat.format(dt);

  /// Formats a DateTime to `dd/MM/yyyy HH:mm`.
  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt);

  /// Formats a DateTime to `HH:mm`.
  static String time(DateTime dt) => _timeFormat.format(dt);

  /// Formats a DateTime to `MMM yyyy`.
  static String monthYear(DateTime dt) => _monthYearFormat.format(dt);

  /// Formats a DateTime to full day name (e.g., 'Monday').
  static String dayName(DateTime dt) => _dayFormat.format(dt);

  /// Formats a DateTime to API-compatible `yyyy-MM-dd`.
  static String apiDate(DateTime dt) => _apiDateFormat.format(dt);

  /// Formats a percentage value with the `%` symbol.
  ///
  /// [decimals] defaults to 1.
  static String percent(double value, [int decimals = 1]) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Formats a phone number with a space after the first 5 digits.
  ///
  /// Example: `'9876543210'` → `'98765 43210'`
  static String phone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\+]'), '');
    if (cleaned.length == 10) {
      return '${cleaned.substring(0, 5)} ${cleaned.substring(5)}';
    }
    return phone;
  }

  /// Truncates text with ellipsis if it exceeds [maxLength].
  ///
  /// The resulting string (including ellipsis) will be at most [maxLength]
  /// characters long.
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  /// Formats a bill number for display by extracting the sequence part.
  ///
  /// Example: `'BILL-20260725-0001'` → `'Bill #0001'`
  static String billNumber(String billNumber) {
    final parts = billNumber.split('-');
    if (parts.length >= 3) {
      return 'Bill #${parts.last}';
    }
    return billNumber;
  }
}
