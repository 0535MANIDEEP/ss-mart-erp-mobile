import 'package:equatable/equatable.dart';
import 'loyalty_entity.dart';

/// Domain entity representing a customer's aggregated loyalty point summary.
///
/// LoyaltyBalance is a read-only snapshot computed from the customer's
/// transaction history. It provides a quick overview without requiring
/// the caller to aggregate individual [LoyaltyTransaction] records.
///
/// This entity is used by the dashboard and customer profile screens
/// to display point balances, pending points, and upcoming expirations.
class LoyaltyBalance extends Equatable {
  /// Foreign key to the [Customer] this balance belongs to.
  final String customerId;

  /// Denormalized customer name for display without JOIN queries.
  final String customerName;

  /// Lifetime total of points earned by this customer (never decreases).
  final int totalPointsEarned;

  /// Lifetime total of points redeemed by this customer (never decreases).
  final int totalPointsRedeemed;

  /// Current redeemable point balance: totalPointsEarned - totalPointsRedeemed.
  final int currentBalance;

  /// Points earned but not yet confirmed (e.g., pending bill finalization).
  final int pendingPoints;

  /// Points that will expire within the configured near-expiry window.
  final int expiringPoints;

  /// Date when the next batch of points will expire.
  /// Null if no points have an expiry date set.
  final DateTime? nextExpiryDate;

  /// Most recent transactions for display in the loyalty history view.
  final List<LoyaltyTransaction> recentTransactions;

  const LoyaltyBalance({
    required this.customerId,
    required this.customerName,
    required this.totalPointsEarned,
    required this.totalPointsRedeemed,
    required this.currentBalance,
    required this.pendingPoints,
    required this.expiringPoints,
    this.nextExpiryDate,
    required this.recentTransactions,
  });

  @override
  List<Object?> get props => [
        customerId, customerName, totalPointsEarned,
        totalPointsRedeemed, currentBalance, pendingPoints,
        expiringPoints, nextExpiryDate, recentTransactions,
      ];
}
