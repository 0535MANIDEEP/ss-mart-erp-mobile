import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String role;
  final String? storeId;
  final bool isActive;

  const User({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    required this.role,
    this.storeId,
    this.isActive = true,
  });

  @override
  List<Object?> get props => [id, name, phone, email, role, storeId, isActive];

  User copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? role,
    String? storeId,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      isActive: isActive ?? this.isActive,
    );
  }
}
