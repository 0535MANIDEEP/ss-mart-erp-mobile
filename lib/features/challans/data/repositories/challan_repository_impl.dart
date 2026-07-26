import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/delivery_challan.dart';
import '../../domain/entities/delivery_challan_item.dart';
import '../../domain/repositories/challan_repository.dart';

/// In-memory implementation of [ChallanRepository].
///
/// Stores all challan data in a local list, mirroring the pattern used by
/// other in-memory repositories in this codebase. This implementation is
/// suitable for prototyping and will be replaced with a Drift-based local
/// data source backed by SQLite in a production release.
///
/// All mutations generate UUIDs and timestamps locally, following the
/// offline-first convention where the local database is the source of truth.
class ChallanRepositoryImpl implements ChallanRepository {
  final List<DeliveryChallan> _challans = [];
  final _uuid = const Uuid();
  int _counter = 1;

  /// In-memory store of all challans, sorted by creation date (newest first).
  List<DeliveryChallan> get _sortedChallans =>
      List<DeliveryChallan>.from(_challans)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Either<Failure, List<DeliveryChallan>>> getChallans({
    String? status,
  }) async {
    try {
      var result = _sortedChallans;
      if (status != null && status.isNotEmpty) {
        result = result.where((c) => c.status == status).toList();
      }
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DeliveryChallan>> getChallanById(String id) async {
    try {
      final challan = _challans.where((c) => c.id == id).firstOrNull;
      if (challan != null) {
        return Right(challan);
      }
      return Left(CacheFailure(message: 'Challan not found'));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DeliveryChallan>> createChallan(
    DeliveryChallan challan,
  ) async {
    try {
      final now = DateTime.now();
      final newChallan = challan.copyWith(
        id: challan.id.isEmpty ? _uuid.v4() : challan.id,
        challanNumber: 'CH-${_counter.toString().padLeft(6, '0')}',
        status: 'pending',
        createdAt: now,
        updatedAt: now,
        version: 1,
      );
      _counter++;
      _challans.add(newChallan);
      return Right(newChallan);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DeliveryChallan>> updateChallanStatus(
    String challanId,
    String status,
  ) async {
    try {
      final index = _challans.indexWhere((c) => c.id == challanId);
      if (index == -1) {
        return Left(CacheFailure(message: 'Challan not found'));
      }

      final updated = _challans[index].copyWith(
        status: status,
        updatedAt: DateTime.now(),
        version: _challans[index].version + 1,
      );
      _challans[index] = updated;
      return Right(updated);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteChallan(String challanId) async {
    try {
      final index = _challans.indexWhere((c) => c.id == challanId);
      if (index == -1) {
        return Left(CacheFailure(message: 'Challan not found'));
      }
      _challans.removeAt(index);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
