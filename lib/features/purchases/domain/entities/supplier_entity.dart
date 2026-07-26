/// Domain entity representing a Supplier/Vendor in the SS MART ERP system.
///
/// Suppliers are external vendors from whom the business purchases inventory.
/// Each supplier has contact details, tax identification (GSTIN/PAN),
/// and credit terms for accounts payable tracking.
class SupplierEntity {
  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? gstin;
  final String? pan;
  final int outstandingBalance;
  final int creditDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const SupplierEntity({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstin,
    this.pan,
    this.outstandingBalance = 0,
    this.creditDays = 30,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  factory SupplierEntity.fromDatabase(dynamic supplier) {
    return SupplierEntity(
      id: supplier.id,
      name: supplier.name,
      contactPerson: supplier.contactPerson,
      phone: supplier.phone,
      email: supplier.email,
      address: supplier.address,
      city: supplier.city,
      state: supplier.state,
      pincode: supplier.pincode,
      gstin: supplier.gstin,
      pan: supplier.pan,
      outstandingBalance: supplier.outstandingBalance,
      creditDays: supplier.creditDays,
      isActive: supplier.isActive,
      createdAt: supplier.createdAt,
      updatedAt: supplier.updatedAt,
      version: supplier.version,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'contactPerson': contactPerson,
    'phone': phone,
    'email': email,
    'address': address,
    'city': city,
    'state': state,
    'pincode': pincode,
    'gstin': gstin,
    'pan': pan,
    'outstandingBalance': outstandingBalance,
    'creditDays': creditDays,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
  };

  String get displayName => contactPerson != null ? '$name ($contactPerson)' : name;
  String get displayAddress => [address, city, state, pincode].where((e) => e != null && e.isNotEmpty).join(', ');
  bool get hasGstin => gstin != null && gstin!.isNotEmpty;
}
