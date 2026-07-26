import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/delivery_challan.dart';
import '../../domain/entities/delivery_challan_item.dart';

/// Abstract repository contract for delivery challan data operations.
///
/// Defines the data access boundary for the challans feature, following
/// the same [Either<Failure, T>] return pattern used across the codebase.
abstract class ChallanRepository {
  /// Retrieves all delivery challans, optionally filtered by status.
  Future<Either<Failure, List<DeliveryChallan>>> getChallans({String? status});

  /// Retrieves a single challan by its unique identifier.
  Future<Either<Failure, DeliveryChallan>> getChallanById(String id);

  /// Creates a new delivery challan.
  Future<Either<Failure, DeliveryChallan>> createChallan(DeliveryChallan challan);

  /// Updates the status of an existing challan (pending → dispatched → delivered).
  Future<Either<Failure, DeliveryChallan>> updateChallanStatus(
    String challanId,
    String status,
  );

  /// Deletes a challan by its unique identifier.
  Future<Either<Failure, void>> deleteChallan(String challanId);
}
