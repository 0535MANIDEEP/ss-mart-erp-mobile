import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../repositories/category_repository.dart';

class DeleteCategoryUseCase extends UseCase<void, DeleteCategoryParams> {
  final CategoryRepository repository;
  DeleteCategoryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(DeleteCategoryParams params) => repository.delete(params.id);
}

class DeleteCategoryParams {
  final String id;
  const DeleteCategoryParams({required this.id});
}
