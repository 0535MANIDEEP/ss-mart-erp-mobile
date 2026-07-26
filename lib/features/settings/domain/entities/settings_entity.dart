import 'package:equatable/equatable.dart';

class SettingsEntity extends Equatable {
  final String key;
  final String value;
  final String valueType;
  final String? description;
  final DateTime updatedAt;

  const SettingsEntity({
    required this.key,
    required this.value,
    this.valueType = 'string',
    this.description,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [key, value, valueType, description, updatedAt];

  SettingsEntity copyWith({
    String? key,
    String? value,
    String? valueType,
    String? description,
    DateTime? updatedAt,
  }) {
    return SettingsEntity(
      key: key ?? this.key,
      value: value ?? this.value,
      valueType: valueType ?? this.valueType,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BusinessProfileEntity extends Equatable {
  final String id;
  final String companyName;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phone;
  final String? email;
  final String? gstin;
  final String? pan;
  final String? logoUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BusinessProfileEntity({
    required this.id,
    required this.companyName,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.phone,
    this.email,
    this.gstin,
    this.pan,
    this.logoUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id, companyName, address, city, state, pincode,
        phone, email, gstin, pan, logoUrl, isActive,
        createdAt, updatedAt,
      ];

  BusinessProfileEntity copyWith({
    String? id,
    String? companyName,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? phone,
    String? email,
    String? gstin,
    String? pan,
    String? logoUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BusinessProfileEntity(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      logoUrl: logoUrl ?? this.logoUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SyncSettingsEntity extends Equatable {
  final bool autoSync;
  final bool syncOnWifiOnly;
  final int syncFrequencyMinutes;
  final String conflictResolution;
  final DateTime? lastSyncedAt;

  const SyncSettingsEntity({
    this.autoSync = true,
    this.syncOnWifiOnly = false,
    this.syncFrequencyMinutes = 15,
    this.conflictResolution = 'server',
    this.lastSyncedAt,
  });

  @override
  List<Object?> get props => [
        autoSync, syncOnWifiOnly, syncFrequencyMinutes,
        conflictResolution, lastSyncedAt,
      ];

  SyncSettingsEntity copyWith({
    bool? autoSync,
    bool? syncOnWifiOnly,
    int? syncFrequencyMinutes,
    String? conflictResolution,
    DateTime? lastSyncedAt,
  }) {
    return SyncSettingsEntity(
      autoSync: autoSync ?? this.autoSync,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      syncFrequencyMinutes: syncFrequencyMinutes ?? this.syncFrequencyMinutes,
      conflictResolution: conflictResolution ?? this.conflictResolution,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}
