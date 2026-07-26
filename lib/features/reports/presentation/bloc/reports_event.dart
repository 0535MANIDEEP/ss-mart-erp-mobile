import 'package:equatable/equatable.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/usecases/export_report_usecase.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();

  @override
  List<Object?> get props => [];
}

class LoadReport extends ReportsEvent {
  final ReportType type;
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadReport({
    required this.type,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [type, startDate, endDate];
}

class ExportReport extends ReportsEvent {
  final ReportType type;
  final ExportType exportType;

  const ExportReport({
    required this.type,
    required this.exportType,
  });

  @override
  List<Object?> get props => [type, exportType];
}
