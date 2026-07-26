import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

class CreateCategoryUseCase extends UseCase<CategoryEntity, CreateCategoryParams> {
  final CategoryRepository repository;
  CreateCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, CategoryEntity>> call(CreateCategoryParams params) => repository.create(params.category);
}

class CreateCategoryParams {
  final CategoryEntity category;
  const CreateCategoryParams({required this.category});
}
