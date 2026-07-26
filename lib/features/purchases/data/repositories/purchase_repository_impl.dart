import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/purchase_entity.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../datasources/purchase_remote_datasource.dart';
import '../datasources/purchase_local_datasource.dart';

/// Implementation of [PurchaseRepository] for managing purchase orders
/// and goods reception in the SS MART ERP Mobile App.
///
/// ## Architecture & Sync Strategy
///
/// This repository follows a **remote-first write** pattern — purchase
/// orders are created and managed on the server, then cached locally:
///
/// ### Read Pattern
/// - **getPurchases (list)**: Remote-first when online — fetches from the
///   API, caches each purchase locally, then returns. Falls back to local
///   cache when offline.
/// - **getPurchaseById**: Remote-first when online (with local cache),
///   local-only when offline. Returns [CacheFailure] if not found locally
///   while disconnected.
///
/// ### Write Pattern (Remote-First)
/// - **createPurchase / updatePurchase**: Remote-first — the server
///   validates the purchase (supplier exists, product IDs valid, price
///   consistency) and returns the canonical record, which is then cached
///   locally.
/// - **receivePurchase**: Remote-first — the server processes goods
///   reception (may trigger stock adjustments server-side), and the
///   updated purchase is cached locally.
///
/// ### Error Handling
/// - Distinguishes between [ServerException] (remote-specific errors) and
///   general exceptions. [ServerException] messages are forwarded directly
///   as [ServerFailure] messages.
/// - [CacheFailure] is used for local-only lookup misses.
///
/// ### Relationship Between Local and Remote
/// - Remote is the authoritative source for purchase orders.
/// - Local serves as a read cache for offline browsing and reporting.
/// - Stock adjustments resulting from purchases are handled server-side
///   (see [StockRepositoryImpl] for local stock management).
class PurchaseRepositoryImpl implements PurchaseRepository {
  final PurchaseRemoteDataSource remoteDataSource;
  final PurchaseLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  PurchaseRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Fetches a paginated list of purchases, optionally filtered by supplier,
  /// date range, and pagination parameters.
  ///
  /// **Strategy**: Remote-first when online (caches locally), local fallback
  /// when offline. Ensures the freshest purchase data when connected while
  /// maintaining offline availability for historical reference.
  @override
  Future<Either<Failure, List<Purchase>>> getPurchases({
    String? supplierId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      if (await networkInfo.isConnected) {
        final purchases = await remoteDataSource.getPurchases(
          supplierId: supplierId,
          startDate: startDate,
          endDate: endDate,
          page: page,
          perPage: perPage,
        );
        for (var purchase in purchases) {
          await localDataSource.savePurchase(purchase);
        }
        return Right(purchases);
      } else {
        final localPurchases = await localDataSource.getPurchases(
          supplierId: supplierId,
          startDate: startDate,
          endDate: endDate,
        );
        return Right(localPurchases);
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Retrieves a single purchase order by ID.
  ///
  /// **Strategy**: Remote-first when online (caches locally), local-only
  /// when offline. Returns [CacheFailure] if not found in the local DB
  /// while disconnected.
  @override
  Future<Either<Failure, Purchase>> getPurchaseById(String id) async {
    try {
      if (await networkInfo.isConnected) {
        final purchase = await remoteDataSource.getPurchaseById(id);
        await localDataSource.savePurchase(purchase);
        return Right(purchase);
      } else {
        final localPurchase = await localDataSource.getPurchaseById(id);
        if (localPurchase != null) {
          return Right(localPurchase);
        }
        return const Left(CacheFailure(message: 'Purchase not found locally'));
      }
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Creates a new purchase order on the remote server, then caches locally.
  ///
  /// Remote-first ensures server-side validation (supplier, products, pricing)
  /// before the purchase is persisted. The server-assigned purchase record
  /// (with generated IDs, timestamps, and computed totals) is cached locally.
  @override
  Future<Either<Failure, Purchase>> createPurchase(Purchase purchase) async {
    try {
      final createdPurchase = await remoteDataSource.createPurchase(purchase);
      await localDataSource.savePurchase(createdPurchase);
      return Right(createdPurchase);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Updates an existing purchase order on the remote server, then updates
  /// the local cache with the server's response.
  @override
  Future<Either<Failure, Purchase>> updatePurchase(Purchase purchase) async {
    try {
      final updatedPurchase = await remoteDataSource.updatePurchase(purchase);
      await localDataSource.savePurchase(updatedPurchase);
      return Right(updatedPurchase);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Processes goods reception for a purchase order.
  ///
  /// Remote-first: the server validates received quantities against the
  /// ordered quantities, updates the purchase status, and may trigger
  /// server-side stock adjustments. The updated purchase record is then
  /// cached locally.
  @override
  Future<Either<Failure, Purchase>> receivePurchase({
    required String purchaseId,
    required List<PurchaseItem> receivedItems,
  }) async {
    try {
      final purchase = await remoteDataSource.receivePurchase(
        purchaseId: purchaseId,
        receivedItems: receivedItems,
      );
      await localDataSource.savePurchase(purchase);
      return Right(purchase);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
