import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../entities/report_entity.dart';
import '../repositories/report_repository.dart';

class ExportReportUseCase extends UseCase<String, ExportReportParams> {
  final ReportRepository repository;

  ExportReportUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(ExportReportParams params) async {
    if (params.exportType == ExportType.pdf) {
      return await repository.exportToPdf(params.data);
    } else {
      return await repository.exportToExcel(params.data);
    }
  }
}

enum ExportType { pdf, excel }

class ExportReportParams extends Equatable {
  final ReportData data;
  final ExportType exportType;

  const ExportReportParams({
    required this.data,
    required this.exportType,
  });

  @override
  List<Object?> get props => [data, exportType];
}
