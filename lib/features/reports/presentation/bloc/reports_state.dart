import 'package:equatable/equatable.dart';
import '../../domain/entities/report_entity.dart';

abstract class ReportsState extends Equatable {
  const ReportsState();

  @override
  List<Object?> get props => [];
}

class ReportsInitial extends ReportsState {
  const ReportsInitial();
}

class ReportsLoading extends ReportsState {
  const ReportsLoading();
}

class ReportLoaded extends ReportsState {
  final ReportData data;

  const ReportLoaded({required this.data});

  @override
  List<Object?> get props => [data];
}

class ReportExported extends ReportsState {
  final String filePath;

  const ReportExported({required this.filePath});

  @override
  List<Object?> get props => [filePath];
}

class ReportsError extends ReportsState {
  final String message;

  const ReportsError({required this.message});

  @override
  List<Object?> get props => [message];
}
