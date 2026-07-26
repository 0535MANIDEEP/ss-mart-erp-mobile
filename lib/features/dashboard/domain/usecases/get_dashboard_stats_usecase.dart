import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/dashboard_entity.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardStatsUseCase extends UseCase<DashboardStats, NoParams> {
  final DashboardRepository repository;

  GetDashboardStatsUseCase(this.repository);

  @override
  Future<Either<Failure, DashboardStats>> call(NoParams params) async {
    return await repository.getDashboardStats();
  }
}

class GetRecentSalesUseCase extends UseCase<List<RecentSale>, int> {
  final DashboardRepository repository;

  GetRecentSalesUseCase(this.repository);

  @override
  Future<Either<Failure, List<RecentSale>>> call(int limit) async {
    return await repository.getRecentSales(limit: limit);
  }
}

class GetTopProductsUseCase extends UseCase<List<TopProduct>, int> {
  final DashboardRepository repository;

  GetTopProductsUseCase(this.repository);

  @override
  Future<Either<Failure, List<TopProduct>>> call(int limit) async {
    return await repository.getTopProducts(limit: limit);
  }
}

class GetAlertsUseCase extends UseCase<List<AlertItem>, NoParams> {
  final DashboardRepository repository;

  GetAlertsUseCase(this.repository);

  @override
  Future<Either<Failure, List<AlertItem>>> call(NoParams params) async {
    return await repository.getAlerts();
  }
}
