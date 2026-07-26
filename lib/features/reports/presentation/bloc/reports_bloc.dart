import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/report_entity.dart';
import '../../domain/usecases/get_report_usecase.dart';
import '../../domain/usecases/export_report_usecase.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  final GetReportUseCase getReportUseCase;
  final ExportReportUseCase exportReportUseCase;

  ReportData? _currentReport;

  ReportsBloc({
    required this.getReportUseCase,
    required this.exportReportUseCase,
  }) : super(const ReportsInitial()) {
    on<LoadReport>(_onLoadReport);
    on<ExportReport>(_onExportReport);
  }

  Future<void> _onLoadReport(
    LoadReport event,
    Emitter<ReportsState> emit,
  ) async {
    emit(const ReportsLoading());
    final result = await getReportUseCase(GetReportParams(
      type: event.type,
      startDate: event.startDate,
      endDate: event.endDate,
    ));
    result.fold(
      (failure) => emit(ReportsError(message: failure.message)),
      (data) {
        _currentReport = data;
        emit(ReportLoaded(data: data));
      },
    );
  }

  Future<void> _onExportReport(
    ExportReport event,
    Emitter<ReportsState> emit,
  ) async {
    if (_currentReport == null || _currentReport!.type != event.type) {
      emit(const ReportsError(message: 'Load a report first before exporting'));
      return;
    }

    emit(const ReportsLoading());
    final result = await exportReportUseCase(ExportReportParams(
      data: _currentReport!,
      exportType: event.exportType,
    ));
    result.fold(
      (failure) => emit(ReportsError(message: failure.message)),
      (filePath) => emit(ReportExported(filePath: filePath)),
    );
  }
}
