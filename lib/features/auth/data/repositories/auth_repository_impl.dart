import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../../../../database/app_database.dart' as db;

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final db.DatabaseDao _dao;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required db.DatabaseDao dao,
  }) : _dao = dao;

  @override
  Future<Either<Failure, User>> login({
    required String username,
    required String password,
  }) async {
    try {
      final result = await remoteDataSource.login(
        username: username,
        password: password,
      );

      await localDataSource.saveTokens(
        accessToken: result['accessToken'],
        refreshToken: result['refreshToken'],
      );

      await localDataSource.saveUser(result['user']);

      final user = User(
        id: result['user']['id'],
        name: result['user']['name'],
        role: result['user']['role'],
        storeId: result['user']['storeId'],
      );

      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await remoteDataSource.logout();
      await localDataSource.clearTokens();
      await localDataSource.clearUser();
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final userData = await localDataSource.getUser();
      if (userData == null) return const Right(null);

      final user = User(
        id: userData['id'],
        name: userData['name'],
        role: userData['role'],
        storeId: userData['storeId'],
      );

      return Right(user);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> validatePin(String pin) async {
    try {
      final userData = await localDataSource.getUser();
      if (userData == null) {
        return Left(ServerFailure(message: 'No user logged in'));
      }
      final userId = userData['id'] as String? ?? 'current_user';

      final employee = await _dao.getEmployeeById(userId);
      if (employee == null) {
        return Left(ServerFailure(message: 'Employee not found'));
      }
      return Right(employee.pin == pin);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
