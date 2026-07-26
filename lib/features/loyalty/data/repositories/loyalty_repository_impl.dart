import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/loyalty_entity.dart';
import '../../domain/entities/loyalty_balance.dart';
import '../../domain/repositories/loyalty_repository.dart';
import '../datasources/loyalty_remote_datasource.dart';
import '../datasources/loyalty_local_datasource.dart';

/// Implementation of [LoyaltyRepository] for managing customer loyalty
/// points (earn, redeem, balance) in the SS MART ERP Mobile App.
///
/// ## Architecture & Sync Strategy
///
/// This repository follows a **local-first write** pattern with remote
/// balance verification:
///
/// ### Balance Reads
/// - **getLoyaltyBalance**: Local-first — checks the local DB first.
///   If not found and online, fetches from remote. If neither source
///   has data, returns a zero-balance placeholder (never fails for
///   missing balance, since loyalty may not be configured for all customers).
///
/// ### Earn / Redeem (Write Pattern)
/// - **earnPoints** and **redeemPoints**: Generate a [LoyaltyTransaction]
///   locally with a UUID, persist to the local database, and return.
///   The transaction is later synced to the remote server by the
///   [SyncRepository] sync worker.
/// - Points expiry is set to 365 days from the transaction date for earn
///   transactions.
///
/// ### Loyalty History
/// - Served entirely from the local database with manual pagination.
///   The local history is populated by sync-down from the remote API.
///
/// ### Error Handling
/// - All methods return `Either<Failure, T>`.
/// - Balance lookup failures return a zero-balance [Right] rather than
///   [Left] — this is a deliberate design choice to prevent loyalty
///   issues from blocking the billing flow.
///
/// ### Relationship Between Local and Remote
/// - Remote is authoritative for loyalty balances and transaction history.
/// - Local serves as a write-through cache for offline earn/redeem.
/// - The sync worker reconciles local transactions with the server.
///
/// ### Integration with Billing
/// - [BillRepositoryImpl] calls [earnPoints] when a bill is created for
///   a customer (1 point per ₹10 spent).
/// - [BillRepositoryImpl] calls [redeemPoints] when a return is processed
///   to reverse previously earned points.
class LoyaltyRepositoryImpl implements LoyaltyRepository {
  final LoyaltyRemoteDataSource remoteDataSource;
  final LoyaltyLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final _uuid = const Uuid();

  LoyaltyRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Retrieves the loyalty point balance for a customer.
  ///
  /// **Strategy**: Local-first with remote fallback and zero-balance default.
  /// 1. Check local DB — if found, return immediately.
  /// 2. If online, fetch from remote API.
  /// 3. If neither source has data, return a zero-balance [LoyaltyBalance].
  ///    This ensures the billing flow is never blocked by missing loyalty data.
  @override
  Future<Either<Failure, LoyaltyBalance>> getLoyaltyBalance(String customerId) async {
    try {
      final localBalance = await localDataSource.getLoyaltyBalance(customerId);
      if (localBalance != null) {
        return Right(localBalance);
      }

      if (await networkInfo.isConnected) {
        try {
          final remoteBalance = await remoteDataSource.getLoyaltyBalance(customerId);
          return Right(remoteBalance);
        } catch (_) {
          return Right(LoyaltyBalance(
            customerId: customerId,
            customerName: '',
            totalPointsEarned: 0,
            totalPointsRedeemed: 0,
            currentBalance: 0,
            pendingPoints: 0,
            expiringPoints: 0,
            recentTransactions: const [],
          ));
        }
      }

      return Right(LoyaltyBalance(
        customerId: customerId,
        customerName: '',
        totalPointsEarned: 0,
        totalPointsRedeemed: 0,
        currentBalance: 0,
        pendingPoints: 0,
        expiringPoints: 0,
        recentTransactions: const [],
      ));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Awards loyalty points to a customer for a qualifying transaction.
  ///
  /// Generates a new [LoyaltyTransaction] with type 'earn', assigns a UUID,
  /// sets a 365-day expiry, and persists locally. The [referenceType] and
  /// [referenceId] link the points to the originating entity (e.g., a bill).
  ///
  /// Called by [BillRepositoryImpl.createBill] with points calculated as
  /// `floor(totalAmount / 10)` (1 point per ₹10 spent).
  @override
  Future<Either<Failure, LoyaltyTransaction>> earnPoints({
    required String customerId,
    required int points,
    String? referenceType,
    String? referenceId,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final transaction = LoyaltyTransaction(
        id: _uuid.v4(),
        customerId: customerId,
        customerName: '',
        transactionType: 'earn',
        points: points,
        referenceType: referenceType,
        referenceId: referenceId,
        expiryDate: now.add(const Duration(days: 365)),
        notes: notes,
        createdAt: now,
      );

      await localDataSource.saveTransaction(transaction);

      return Right(transaction);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Redeems (deducts) loyalty points from a customer's balance.
  ///
  /// Generates a [LoyaltyTransaction] with type 'redeem' and persists locally.
  /// Called by [BillRepositoryImpl.processReturn] to reverse previously
  /// earned points when items are returned.
  @override
  Future<Either<Failure, LoyaltyTransaction>> redeemPoints({
    required String customerId,
    required int points,
    String? referenceType,
    String? referenceId,
    String? notes,
  }) async {
    try {
      final transaction = LoyaltyTransaction(
        id: _uuid.v4(),
        customerId: customerId,
        customerName: '',
        transactionType: 'redeem',
        points: points,
        referenceType: referenceType,
        referenceId: referenceId,
        notes: notes,
        createdAt: DateTime.now(),
      );

      await localDataSource.saveTransaction(transaction);

      return Right(transaction);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Retrieves paginated loyalty transaction history for a customer.
  ///
  /// Served entirely from the local database with manual in-memory
  /// pagination. The local history is populated by the sync worker
  /// pulling data from the remote API.
  @override
  Future<Either<Failure, List<LoyaltyTransaction>>> getLoyaltyHistory({
    required String customerId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final history = await localDataSource.getLoyaltyHistory(customerId);

      final start = (page - 1) * perPage;
      if (start >= history.length) return const Right([]);
      final end = start + perPage;
      return Right(history.sublist(start, end > history.length ? history.length : end));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
