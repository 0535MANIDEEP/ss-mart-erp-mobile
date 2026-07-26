import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/customer_entity.dart';
import '../repositories/customer_repository.dart';

class GetCustomersUseCase extends UseCase<List<Customer>, GetCustomersParams> {
  final CustomerRepository repository;

  GetCustomersUseCase(this.repository);

  @override
  Future<Either<Failure, List<Customer>>> call(GetCustomersParams params) async {
    return await repository.getCustomers(
      search: params.search,
      type: params.type,
      page: params.page,
      perPage: params.perPage,
    );
  }
}

class GetCustomersParams {
  final String? search;
  final String? type;
  final int page;
  final int perPage;

  const GetCustomersParams({
    this.search,
    this.type,
    this.page = 1,
    this.perPage = 20,
  });
}
