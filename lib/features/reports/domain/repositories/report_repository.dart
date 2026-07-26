import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/report_entity.dart';

abstract class ReportRepository {
  Future<Either<Failure, ReportData>> getReport(
    ReportType type, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<Either<Failure, String>> exportToPdf(ReportData data);

  Future<Either<Failure, String>> exportToExcel(ReportData data);
}
