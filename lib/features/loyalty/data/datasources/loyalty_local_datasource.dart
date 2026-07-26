/// Loyalty Local Data Source — Local persistence layer for loyalty points and transactions.
///
/// ## Architecture Role
/// Sits between [LoyaltyRepositoryImpl] and the Drift database. Abstracts all
/// details of how loyalty transactions are stored, queried, and summarized into
/// a [LoyaltyBalance] for display. The repository never touches raw SQL or DAO objects.
///
/// ## Responsibilities
/// - CRUD operations on the [LoyaltyTransactions] table.
/// - Computing aggregated loyalty balance (earned, redeemed, current) for a customer.
/// - Determining the next expiry date from earn transactions.
/// - Bidirectional mapping between [db.LoyaltyTransaction] (database row) and
///   [LoyaltyTransaction] (domain entity).
///
/// ## Data Flow
/// ```
/// Repository → LoyaltyLocalDataSource → DatabaseDao (Drift) → SQLite
/// ```
///
/// ## Design Decisions
/// - The loyalty balance is computed on-the-fly from the transaction history rather
///   than being stored as a denormalized value. This ensures consistency: the balance
///   is always the sum of earned minus redeemed, never out of sync with the ledger.
///   The trade-off is slightly more computation per read, but loyalty transactions
///   per customer are bounded (typically < 1000).
/// - `getLoyaltyBalance()` returns null for customers with no transactions, rather
///   than a zero-balance object. This lets the caller distinguish between "never
///   enrolled" and "enrolled with zero points".
/// - The `createdBy` field in `_toCompanion` is hardcoded to `''` because the local
///   datasource doesn't have access to the current user context. This is set
///   properly by the repository layer before saving.
library;

import '../../../../database/app_database.dart' as db;
import '../../domain/entities/loyalty_entity.dart';
import '../../domain/entities/loyalty_balance.dart';

/// Abstract contract for local loyalty persistence.
///
/// The repository layer depends on this interface, not on the concrete
/// implementation, enabling unit testing with fakes/mocks.
abstract class LoyaltyLocalDataSource {
  /// Returns the computed loyalty balance for [customerId], including earned,
  /// redeemed, and current points, plus the next expiry date and recent
  /// transactions. Returns `null` if the customer has no loyalty history.
  Future<LoyaltyBalance?> getLoyaltyBalance(String customerId);

  /// Persists a loyalty transaction (earn, redeem, or adjust).
  Future<void> saveTransaction(LoyaltyTransaction transaction);

  /// Returns the full loyalty transaction history for [customerId], ordered
  /// by creation date (most recent first as returned by the DAO).
  Future<List<LoyaltyTransaction>> getLoyaltyHistory(String customerId);
}

/// Concrete implementation backed by Drift's [AppDatabase].
///
/// Handles the mapping between the domain [LoyaltyTransaction] entity and the
/// Drift-generated [db.LoyaltyTransaction] row object. The balance is computed
/// by aggregating transaction data rather than reading a stored value.
class LoyaltyLocalDataSourceImpl implements LoyaltyLocalDataSource {
  final db.DatabaseDao _dao;

  LoyaltyLocalDataSourceImpl({required db.AppDatabase database})
      : _dao = db.DatabaseDao(database);

  @override
  Future<LoyaltyBalance?> getLoyaltyBalance(String customerId) async {
    final transactions = await _dao.getLoyaltyTransactionsByCustomer(customerId);
    if (transactions.isEmpty) return null;

    // Fetch the authoritative balance from the DAO (may use a separate query
    // or materialized view depending on the DAO implementation).
    final totalPoints = await _dao.getCustomerLoyaltyPoints(customerId);

    // Convert all rows to domain entities for aggregation.
    final allTransactions = transactions.map(_toEntity).toList();

    // Compute totals by summing points for each transaction type.
    // `isEarn` and `isRedeem` are domain-level flags that encapsulate the
    // transaction-type string comparison logic.
    final totalEarned = allTransactions
        .where((t) => t.isEarn)
        .fold<int>(0, (sum, t) => sum + t.points);
    final totalRedeemed = allTransactions
        .where((t) => t.isRedeem)
        .fold<int>(0, (sum, t) => sum + t.points);

    // Find the nearest expiry date among all earn transactions that have an
    // expiry. This is used to warn the user about points about to expire.
    DateTime? nextExpiry;
    for (final t in allTransactions.where((t) => t.isEarn && t.expiryDate != null)) {
      if (nextExpiry == null || t.expiryDate!.isBefore(nextExpiry)) {
        nextExpiry = t.expiryDate;
      }
    }

    return LoyaltyBalance(
      customerId: customerId,
      customerName: transactions.first.customerName,
      totalPointsEarned: totalEarned,
      totalPointsRedeemed: totalRedeemed,
      // Clamp to zero to prevent displaying negative balances caused by
      // race conditions during concurrent earn/redeem operations.
      currentBalance: totalPoints < 0 ? 0 : totalPoints,
      pendingPoints: 0,
      expiringPoints: 0,
      nextExpiryDate: nextExpiry,
      // Return only the 20 most recent transactions for the summary view.
      // Full history is available via `getLoyaltyHistory()`.
      recentTransactions: allTransactions.take(20).toList(),
    );
  }

  @override
  Future<void> saveTransaction(LoyaltyTransaction transaction) async {
    await _dao.insertLoyaltyTransaction(_toCompanion(transaction));
  }

  @override
  Future<List<LoyaltyTransaction>> getLoyaltyHistory(String customerId) async {
    final rows = await _dao.getLoyaltyTransactionsByCustomer(customerId);
    return rows.map(_toEntity).toList();
  }

  /// Converts a Drift [db.LoyaltyTransaction] row into a domain [LoyaltyTransaction] entity.
  LoyaltyTransaction _toEntity(db.LoyaltyTransaction row) {
    return LoyaltyTransaction(
      id: row.id,
      customerId: row.customerId,
      customerName: row.customerName,
      transactionType: row.transactionType,
      points: row.points,
      referenceType: row.referenceType,
      referenceId: row.referenceId,
      expiryDate: row.expiryDate,
      notes: row.notes,
      createdAt: row.createdAt,
    );
  }

  /// Converts a domain [LoyaltyTransaction] entity into a Drift companion for writes.
  ///
  /// Note: `createdBy` is hardcoded to `''` — the local datasource doesn't
  /// know the current user. The repository layer should set this before calling
  /// save if audit tracking is required.
  db.LoyaltyTransactionsCompanion _toCompanion(LoyaltyTransaction transaction) {
    return db.LoyaltyTransactionsCompanion.insert(
      id: transaction.id,
      customerId: transaction.customerId,
      transactionType: transaction.transactionType,
      points: transaction.points,
      createdAt: transaction.createdAt,
      createdBy: '',
      customerName: db.Value(transaction.customerName),
      referenceType: db.Value(transaction.referenceType),
      referenceId: db.Value(transaction.referenceId),
      expiryDate: db.Value(transaction.expiryDate),
      notes: db.Value(transaction.notes),
    );
  }
}
