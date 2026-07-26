import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/loyalty_entity.dart';
import '../entities/loyalty_balance.dart';

/// Abstract repository contract for loyalty point management operations.
///
/// This interface defines the data access boundary for the loyalty feature.
/// Points are earned on purchases and redeemed as discounts on future bills.
/// The repository maintains point balances, transaction history, and
/// expiry tracking.
///
/// All methods return [Either<Failure, T>] to enable functional error handling
/// without exceptions, following the Clean Architecture data flow convention.
abstract class LoyaltyRepository {
  /// Retrieves the current loyalty balance summary for a customer.
  /// Aggregates all transactions to compute total earned, redeemed, and current balance.
  Future<Either<Failure, LoyaltyBalance>> getLoyaltyBalance(String customerId);

  /// Awards loyalty points to a customer for a qualifying transaction.
  ///
  /// [points] must be positive. [referenceType] and [referenceId] link
  /// the points to the source (e.g., a bill). Points may have an expiry date
  /// configured by the loyalty program rules.
  Future<Either<Failure, LoyaltyTransaction>> earnPoints({
    required String customerId,
    required int points,
    String? referenceType,
    String? referenceId,
    String? notes,
  });

  /// Redeems loyalty points as a discount on a purchase.
  ///
  /// [points] must be positive and not exceed the customer's available balance.
  /// Redemption is subject to the configured maximum redemption percentage.
  Future<Either<Failure, LoyaltyTransaction>> redeemPoints({
    required String customerId,
    required int points,
    String? referenceType,
    String? referenceId,
    String? notes,
  });

  /// Retrieves the paginated loyalty transaction history for a customer.
  /// Returns transactions in reverse chronological order (most recent first).
  Future<Either<Failure, List<LoyaltyTransaction>>> getLoyaltyHistory({
    required String customerId,
    int page = 1,
    int perPage = 20,
  });
}
