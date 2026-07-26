import 'package:equatable/equatable.dart';

/// Domain entity representing a single loyalty point transaction.
///
/// Loyalty transactions record the earning and redemption of points by
/// customers. Points are earned on purchases (linked via [referenceType]
/// and [referenceId] to a Bill) and redeemed as discounts on future purchases.
///
/// Points have an optional expiry date. Expired points cannot be redeemed
/// but remain in the transaction history for audit purposes.
///
/// The [netPoints] getter returns positive for earn transactions and
/// negative for redeem transactions, enabling simple balance calculations.
class LoyaltyTransaction extends Equatable {
  /// Unique identifier for this transaction (UUID format).
  final String id;

  /// Foreign key to the [Customer] who earned or redeemed points.
  final String customerId;

  /// Denormalized customer name for display without JOIN queries.
  final String customerName;

  /// Transaction type: 'earn' (points added) or 'redeem' (points deducted).
  final String transactionType;

  /// Absolute number of points involved in this transaction.
  final int points;

  /// Type of the referenced entity (e.g., 'bill' for purchase-linked earning).
  final String? referenceType;

  /// ID of the referenced entity (e.g., the Bill ID for a purchase transaction).
  final String? referenceId;

  /// Date when these points expire and become unredeemable.
  /// Null if points do not expire.
  final DateTime? expiryDate;

  /// Optional description or reason for the transaction.
  final String? notes;

  /// Timestamp when this transaction was recorded.
  final DateTime createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.transactionType,
    required this.points,
    this.referenceType,
    this.referenceId,
    this.expiryDate,
    this.notes,
    required this.createdAt,
  });

  /// Returns true if this transaction added points to the customer's balance.
  bool get isEarn => transactionType == 'earn';

  /// Returns true if this transaction deducted points from the customer's balance.
  bool get isRedeem => transactionType == 'redeem';

  /// Returns true if the points in this transaction have expired.
  bool get isExpired => expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Returns the signed point value: positive for earn, negative for redeem.
  int get netPoints => isEarn ? points : -points;

  @override
  List<Object?> get props => [
        id, customerId, customerName, transactionType,
        points, referenceType, referenceId, expiryDate,
        notes, createdAt,
      ];
}
