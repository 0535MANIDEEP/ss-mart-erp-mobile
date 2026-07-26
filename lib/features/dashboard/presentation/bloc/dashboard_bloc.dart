import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/dashboard_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../../../core/usecases/base_usecase.dart';
import '../../domain/usecases/get_dashboard_stats_usecase.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetDashboardStatsUseCase getDashboardStatsUseCase;
  final DashboardRepository repository;

  DashboardBloc({
    required this.getDashboardStatsUseCase,
    required this.repository,
  }) : super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<RefreshDashboard>(_onRefreshDashboard);
  }

  Future<void> _onLoadDashboard(
    LoadDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());
    final result = await getDashboardStatsUseCase(const NoParams());
    result.fold(
      (failure) => emit(DashboardError(message: failure.message)),
      (stats) => emit(DashboardLoaded(stats: stats)),
    );
  }

  Future<void> _onRefreshDashboard(
    RefreshDashboard event,
    Emitter<DashboardState> emit,
  ) async {
    final result = await getDashboardStatsUseCase(const NoParams());
    result.fold(
      (failure) => emit(DashboardError(message: failure.message)),
      (stats) => emit(DashboardLoaded(stats: stats)),
    );
  }
}
