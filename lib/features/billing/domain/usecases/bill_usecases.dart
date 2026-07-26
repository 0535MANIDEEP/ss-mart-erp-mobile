import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/bill_entity.dart';
import '../repositories/bill_repository.dart';

class CreateBillUseCase extends UseCase<Bill, CreateBillParams> {
  final BillRepository repository;

  CreateBillUseCase(this.repository);

  @override
  Future<Either<Failure, Bill>> call(CreateBillParams params) async {
    if (params.items.isEmpty) {
      return const Left(ValidationFailure(message: 'Bill must have at least one item'));
    }
    if (params.totalAmount <= 0) {
      return const Left(ValidationFailure(message: 'Bill total must be greater than zero'));
    }

    final bill = Bill(
      id: '',
      billNumber: '',
      customerId: params.customerId,
      customerName: params.customerName,
      billDate: DateTime.now(),
      subtotal: params.subtotal,
      taxAmount: params.taxAmount,
      discountAmount: params.discountAmount,
      roundOff: params.roundOff,
      totalAmount: params.totalAmount,
      paidAmount: params.paidAmount,
      dueAmount: params.dueAmount,
      paymentMode: params.paymentMode,
      createdBy: params.createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: params.items,
    );

    return await repository.createBill(bill);
  }
}

class CreateBillParams {
  final String? customerId;
  final String? customerName;
  final int subtotal;
  final int taxAmount;
  final int discountAmount;
  final int roundOff;
  final int totalAmount;
  final int paidAmount;
  final int dueAmount;
  final String paymentMode;
  final String createdBy;
  final List<BillItem> items;

  const CreateBillParams({
    this.customerId,
    this.customerName,
    required this.subtotal,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.roundOff = 0,
    required this.totalAmount,
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.paymentMode = 'CASH',
    this.createdBy = 'system',
    required this.items,
  });
}

class GetBillByIdUseCase extends UseCase<Bill, String> {
  final BillRepository repository;

  GetBillByIdUseCase(this.repository);

  @override
  Future<Either<Failure, Bill>> call(String id) async {
    return await repository.getBillById(id);
  }
}

class GetBillsUseCase extends UseCase<List<Bill>, GetBillsParams> {
  final BillRepository repository;

  GetBillsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Bill>>> call(GetBillsParams params) async {
    return await repository.getBills(
      customerId: params.customerId,
      startDate: params.startDate,
      endDate: params.endDate,
      status: params.status,
      page: params.page,
      perPage: params.perPage,
    );
  }
}

class GetBillsParams {
  final String? customerId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final int page;
  final int perPage;

  const GetBillsParams({
    this.customerId,
    this.startDate,
    this.endDate,
    this.status,
    this.page = 1,
    this.perPage = 20,
  });
}

class GetDaySalesTotalUseCase extends UseCase<int, DateTime> {
  final BillRepository repository;

  GetDaySalesTotalUseCase(this.repository);

  @override
  Future<Either<Failure, int>> call(DateTime date) async {
    return await repository.getDaySalesTotal(date);
  }
}

class GetRecentBillsUseCase extends UseCase<List<Bill>, int> {
  final BillRepository repository;

  GetRecentBillsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Bill>>> call(int limit) async {
    return await repository.getRecentBills(limit: limit);
  }
}

class ProcessReturnUseCase extends UseCase<Bill, ProcessReturnParams> {
  final BillRepository repository;

  ProcessReturnUseCase(this.repository);

  @override
  Future<Either<Failure, Bill>> call(ProcessReturnParams params) async {
    if (params.returnItems.isEmpty) {
      return const Left(ValidationFailure(message: 'Return must have at least one item'));
    }

    return await repository.processReturn(
      originalBillId: params.originalBillId,
      returnItems: params.returnItems,
      reason: params.reason,
    );
  }
}

class ProcessReturnParams {
  final String originalBillId;
  final List<BillItem> returnItems;
  final String reason;

  const ProcessReturnParams({
    required this.originalBillId,
    required this.returnItems,
    required this.reason,
  });
}

class GetTodayBillCountUseCase extends UseCase<int, NoParams> {
  final BillRepository repository;

  GetTodayBillCountUseCase(this.repository);

  @override
  Future<Either<Failure, int>> call(NoParams params) async {
    return await repository.getTodayBillCount();
  }
}
