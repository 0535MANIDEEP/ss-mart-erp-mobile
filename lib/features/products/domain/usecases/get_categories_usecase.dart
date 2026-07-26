import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

/// Use case for retrieving all active product categories.
class GetCategoriesUseCase extends UseCase<List<CategoryEntity>, NoParams> {
  final CategoryRepository repository;
  GetCategoriesUseCase(this.repository);

  @override
  Future<Either<Failure, List<CategoryEntity>>> call(NoParams params) => repository.getActive();
}
