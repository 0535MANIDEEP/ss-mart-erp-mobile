import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class GetReportUseCase extends UseCase<ReportData, GetReportParams> {
  final ReportRepository repository;

  GetReportUseCase(this.repository);

  @override
  Future<Either<Failure, ReportData>> call(GetReportParams params) async {
    return await repository.getReport(
      params.type,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}

class GetReportParams extends Equatable {
  final ReportType type;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetReportParams({
    required this.type,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [type, startDate, endDate];
}
