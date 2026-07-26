import 'package:equatable/equatable.dart';

/// Domain entity representing an employee of the SS MART retail store.
///
/// Employees are assigned roles that determine their access level and
/// operational capabilities within the POS system. The role-based access
/// model supports four tiers: admin, manager, cashier, and inventory.
///
/// Employee records are used for attendance tracking, sales attribution,
/// and authorization of privileged operations (returns, discounts, etc.).
class Employee extends Equatable {
  /// Unique identifier for the employee (UUID format).
  final String id;

  /// Full name of the employee as displayed on receipts and reports.
  final String name;

  /// Contact phone number — used for shift notifications and emergencies.
  final String? phone;

  /// Work email address — optional, used for system notifications.
  final String? email;

  /// Role assignment: 'admin', 'manager', 'cashier', or 'inventory'.
  /// Determines access level and available POS operations.
  final String role;

  /// Whether the employee is currently active and able to log in.
  /// Inactive employees cannot access the POS system.
  final bool isActive;

  /// Timestamp when the employee record was first created.
  final DateTime createdAt;

  /// Timestamp of the most recent modification to this employee record.
  final DateTime updatedAt;

  /// Optimistic concurrency version counter for sync conflict resolution.
  final int version;

  const Employee({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.role = 'cashier',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// Returns true if this employee has full administrative privileges.
  bool get isAdmin => role == 'admin';

  /// Returns true if this employee has management-level access (reports, overrides).
  bool get isManager => role == 'manager';

  /// Returns true if this employee operates the POS terminal for billing.
  bool get isCashier => role == 'cashier';

  /// Returns true if this employee manages inventory and stock operations.
  bool get isInventory => role == 'inventory';

  @override
  List<Object?> get props => [
        id, name, phone, email, role,
        isActive, createdAt, updatedAt, version,
      ];

  Employee copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? role,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}
