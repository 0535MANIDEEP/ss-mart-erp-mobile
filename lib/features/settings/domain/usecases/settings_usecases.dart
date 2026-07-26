import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/settings_entity.dart';
import '../repositories/settings_repository.dart';

class GetSettingUseCase {
  final SettingsRepository repository;

  GetSettingUseCase(this.repository);

  Future<Either<Failure, String?>> call(String key) async {
    return await repository.getSetting(key);
  }
}

class SetSettingUseCase {
  final SettingsRepository repository;

  SetSettingUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String key,
    required String value,
    String? description,
  }) async {
    return await repository.setSetting(key, value, description: description);
  }
}

class GetAllSettingsUseCase {
  final SettingsRepository repository;

  GetAllSettingsUseCase(this.repository);

  Future<Either<Failure, Map<String, String>>> call() async {
    return await repository.getAllSettings();
  }
}

class DeleteSettingUseCase {
  final SettingsRepository repository;

  DeleteSettingUseCase(this.repository);

  Future<Either<Failure, void>> call(String key) async {
    return await repository.deleteSetting(key);
  }
}

class GetBusinessProfileUseCase {
  final SettingsRepository repository;

  GetBusinessProfileUseCase(this.repository);

  Future<Either<Failure, BusinessProfileEntity?>> call() async {
    return await repository.getBusinessProfile();
  }
}

class SaveBusinessProfileUseCase {
  final SettingsRepository repository;

  SaveBusinessProfileUseCase(this.repository);

  Future<Either<Failure, void>> call(BusinessProfileEntity profile) async {
    return await repository.saveBusinessProfile(profile);
  }
}

class GetAllBusinessProfilesUseCase {
  final SettingsRepository repository;

  GetAllBusinessProfilesUseCase(this.repository);

  Future<Either<Failure, List<BusinessProfileEntity>>> call() async {
    return await repository.getAllBusinessProfiles();
  }
}

class GetSyncSettingsUseCase {
  final SettingsRepository repository;

  GetSyncSettingsUseCase(this.repository);

  Future<Either<Failure, SyncSettingsEntity>> call() async {
    return await repository.getSyncSettings();
  }
}

class SaveSyncSettingsUseCase {
  final SettingsRepository repository;

  SaveSyncSettingsUseCase(this.repository);

  Future<Either<Failure, void>> call(SyncSettingsEntity settings) async {
    return await repository.saveSyncSettings(settings);
  }
}
