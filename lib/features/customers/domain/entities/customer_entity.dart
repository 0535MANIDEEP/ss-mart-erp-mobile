import 'package:equatable/equatable.dart';

/// Domain entity representing a customer of the SS MART ERP system.
///
/// Customers are categorized as either B2B (business-to-business) or
/// B2C (business-to-consumer) based on the [type] field. B2B customers
/// typically have credit accounts with configurable credit limits,
/// while B2C customers are primarily cash/walk-in retail consumers.
///
/// The loyalty integration provides a denormalized [loyaltyPoints] cache
/// and links to a loyalty card number. Credit and loyalty fields are
/// maintained independently and synchronized via the sync queue.
///
/// All monetary values are stored in paise (smallest currency unit).
class Customer extends Equatable {
  /// Unique identifier for the customer (UUID format).
  final String id;

  /// Full legal name or business name of the customer.
  final String name;

  /// Primary contact phone number — used for quick lookup and WhatsApp integration.
  final String? phone;

  /// Email address — optional, used for digital receipts.
  final String? email;

  /// Full street address for delivery or billing reference.
  final String? address;

  /// City component of the address — used for regional filtering.
  final String? city;

  /// State component of the address — determines intra/inter-state tax (GST vs IGST).
  final String? state;

  /// Postal PIN code — useful for delivery zone mapping.
  final String? pincode;

  /// Goods and Services Tax Identification Number — required for B2B invoicing.
  /// Null for B2C customers who don't need GST compliance.
  final String? gstin;

  /// Customer classification: 'B2B' for business accounts, 'B2C' for retail consumers.
  final String type;

  /// Maximum credit limit in paise for this customer.
  /// Zero means no credit facility is extended.
  final int creditLimit;

  /// Current outstanding balance in paise owed by this customer.
  /// Positive means customer owes money; negative means prepaid credit.
  final int currentBalance;

  /// Denormalized loyalty point balance — kept in sync with the loyalty module.
  final int loyaltyPoints;

  /// Loyalty card number string for scan-based point accrual at POS.
  final String? loyaltyCardNumber;

  /// Whether the customer is actively accepting new transactions.
  /// Inactive customers are hidden but retain historical data.
  final bool isActive;

  /// Timestamp when the customer record was first created.
  final DateTime createdAt;

  /// Timestamp of the most recent modification to this customer record.
  final DateTime updatedAt;

  /// Optimistic concurrency version counter for sync conflict resolution.
  final int version;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.gstin,
    this.type = 'B2C',
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.loyaltyPoints = 0,
    this.loyaltyCardNumber,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  /// Returns true if this customer is a B2B (business) account.
  bool get isB2B => type == 'B2B';

  /// Returns true if a non-zero credit limit has been configured.
  bool get hasCreditLimit => creditLimit > 0;

  /// Returns true if the customer has any outstanding balance owed.
  bool get hasOutstanding => currentBalance > 0;

  /// Returns true if the customer can still make purchases on credit
  /// (has a credit limit and hasn't exhausted it).
  bool get canPurchaseOnCredit => hasCreditLimit && currentBalance < creditLimit;

  /// Credit utilization as a percentage (0-100+).
  /// Values above 100 indicate the customer has exceeded their credit limit.
  double get creditUtilization =>
      hasCreditLimit ? (currentBalance / creditLimit * 100) : 0.0;

  @override
  List<Object?> get props => [
        id, name, phone, email, address, city, state, pincode,
        gstin, type, creditLimit, currentBalance, loyaltyPoints,
        loyaltyCardNumber, isActive, createdAt, updatedAt, version,
      ];

  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? gstin,
    String? type,
    int? creditLimit,
    int? currentBalance,
    int? loyaltyPoints,
    String? loyaltyCardNumber,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      gstin: gstin ?? this.gstin,
      type: type ?? this.type,
      creditLimit: creditLimit ?? this.creditLimit,
      currentBalance: currentBalance ?? this.currentBalance,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      loyaltyCardNumber: loyaltyCardNumber ?? this.loyaltyCardNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}
