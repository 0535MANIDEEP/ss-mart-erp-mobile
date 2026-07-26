import 'package:uuid/uuid.dart';

/// General-purpose helper utilities for the SS MART ERP application.
///
/// Provides UUID generation, date helpers, and common business logic
/// calculations used across multiple feature modules.
class AppHelpers {
  AppHelpers._();

  static const _uuid = Uuid();

  /// Generates a new UUID v4 string suitable for use as a primary key.
  static String generateId() => _uuid.v4();

  /// Generates a bill/invoice number in the format `PREFIX-YYYYMMDD-NNNN`.
  ///
  /// [prefix] is the document type identifier (e.g., 'BILL', 'PUR').
  /// [sequence] is the auto-incrementing sequence number for the day.
  static String generateBillNumber(String prefix, int sequence) {
    final now = DateTime.now();
    final datePart = '${now.year}${_pad(now.month)}${_pad(now.day)}';
    final seqPart = sequence.toString().padLeft(4, '0');
    return '$prefix-$datePart-$seqPart';
  }

  /// Generates a purchase number in the format `PUR-YYYYMMDD-NNNN`.
  static String generatePurchaseNumber(int sequence) {
    return generateBillNumber('PUR', sequence);
  }

  /// Rounds off an amount to the nearest integer (banker's rounding).
  ///
  /// Returns the round-off adjustment in paise (typically -50 to +49).
  /// A positive return value means the total should be increased;
  /// a negative value means it should be decreased.
  static int calculateRoundOff(int amountPaise) {
    final remainder = amountPaise % 100;
    if (remainder == 0) return 0;
    if (remainder >= 50) return 100 - remainder;
    return -remainder;
  }

  /// Calculates GST amount for a given subtotal and tax rate.
  ///
  /// [subtotalPaise] is the pre-tax amount in paise.
  /// [taxRate] is a percentage (e.g., 18.0 for 18% GST).
  /// Returns the tax amount in paise.
  static int calculateGst(int subtotalPaise, double taxRate) {
    return ((subtotalPaise * taxRate) / 100).round();
  }

  /// Calculates the total with GST and round-off applied.
  ///
  /// [subtotalPaise] is the pre-tax amount in paise.
  /// [taxPaise] is the GST amount in paise.
  /// [discountPaise] is the discount amount in paise.
  /// Returns the final payable amount in paise.
  static int calculateTotal(int subtotalPaise, int taxPaise, int discountPaise) {
    final netAmount = subtotalPaise + taxPaise - discountPaise;
    final roundOff = calculateRoundOff(netAmount);
    return netAmount + roundOff;
  }

  /// Calculates loyalty points to earn for a given purchase amount.
  ///
  /// [amountPaise] is the bill amount in paise.
  /// [pointsPerRupee] is the loyalty points earned per rupee spent.
  /// Returns the total points to credit.
  static int calculateLoyaltyPoints(int amountPaise, int pointsPerRupee) {
    return (amountPaise ~/ 100) * pointsPerRupee;
  }

  /// Calculates maximum redeemable loyalty points for a bill.
  ///
  /// [billAmountPaise] is the total bill amount in paise.
  /// [currentBalancePoints] is the customer's available loyalty points.
  /// [maxRedemptionPercent] is the maximum percentage of bill payable
  ///   via points (e.g., 25.0 for 25%).
  /// Returns the maximum points the customer can redeem.
  static int calculateMaxRedeemable(int billAmountPaise, int currentBalancePoints, double maxRedemptionPercent) {
    final maxByPercent = (billAmountPaise * maxRedemptionPercent / 100).round() ~/ 100;
    return currentBalancePoints < maxByPercent ? currentBalancePoints : maxByPercent;
  }

  /// Returns the current date with time set to midnight (start of day).
  ///
  /// If [date] is provided, uses that date instead of now.
  static DateTime startOfDay([DateTime? date]) {
    final dt = date ?? DateTime.now();
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Returns the current date with time set to 23:59:59 (end of day).
  ///
  /// If [date] is provided, uses that date instead of now.
  static DateTime endOfDay([DateTime? date]) {
    final dt = date ?? DateTime.now();
    return DateTime(dt.year, dt.month, dt.day, 23, 59, 59);
  }

  /// Returns the first day of the current month at midnight.
  ///
  /// If [date] is provided, uses that date's month instead of now.
  static DateTime startOfMonth([DateTime? date]) {
    final dt = date ?? DateTime.now();
    return DateTime(dt.year, dt.month, 1);
  }

  /// Returns the last day of the current month at 23:59:59.
  ///
  /// If [date] is provided, uses that date's month instead of now.
  static DateTime endOfMonth([DateTime? date]) {
    final dt = date ?? DateTime.now();
    return DateTime(dt.year, dt.month + 1, 0, 23, 59, 59);
  }

  /// Returns the first day of the current Indian financial year (April 1st).
  ///
  /// If the current month is before April, returns April 1st of the
  /// previous year. If [date] is provided, uses that date instead of now.
  static DateTime startOfFinancialYear([DateTime? date]) {
    final dt = date ?? DateTime.now();
    if (dt.month >= 4) {
      return DateTime(dt.year, 4, 1);
    }
    return DateTime(dt.year - 1, 4, 1);
  }

  /// Returns the last day of the current Indian financial year (March 31st).
  ///
  /// If the current month is before April, returns March 31st of the
  /// current year. If [date] is provided, uses that date instead of now.
  static DateTime endOfFinancialYear([DateTime? date]) {
    final dt = date ?? DateTime.now();
    if (dt.month >= 4) {
      return DateTime(dt.year + 1, 3, 31, 23, 59, 59);
    }
    return DateTime(dt.year, 3, 31, 23, 59, 59);
  }

  /// Pads a number with a leading zero (1 → '01', 12 → '12').
  static String _pad(int value) => value.toString().padLeft(2, '0');

  /// Returns a list of HSN codes commonly used in Indian retail.
  static List<String> getHsnSuggestions() {
    return [
      '9964', '9965', '9966', '9961',
      '0401', '0402', '0403', '0404',
      '1006', '1001', '1101', '1104',
      '1901', '1905', '2106', '2201',
      '3004', '3003', '3304', '3305',
      '3401', '3808', '4818', '4819',
      '4901', '4911', '6109', '6203',
      '6302', '6403', '7013', '7323',
      '7615', '8471', '8528', '9403',
      '9503', '9619', '6211', '6110',
    ];
  }

  /// Returns a list of commonly used Indian payment methods.
  static List<String> getPaymentMethods() {
    return ['CASH', 'UPI', 'CARD', 'CREDIT', 'WALLET', 'SPLIT'];
  }

  /// Returns a list of standard Indian GST tax rates.
  static List<double> getGstRates() {
    return [0.0, 5.0, 12.0, 18.0, 28.0];
  }

  /// Returns a list of all Indian states and union territories.
  ///
  /// Suitable for dropdown selection in address forms.
  static List<String> getIndianStates() {
    return [
      'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
      'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand',
      'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
      'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab',
      'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
      'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
      'Andaman and Nicobar Islands', 'Chandigarh',
      'Dadra and Nagar Haveli and Daman and Diu', 'Delhi',
      'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
    ];
  }
}
