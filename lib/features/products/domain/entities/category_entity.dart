/// Domain entity representing a Product Category in the SS MART ERP system.
///
/// Categories organize the product catalog into logical groups for
/// filtering, reporting, and potentially group-based pricing.
class CategoryEntity {
  final String id;
  final String name;
  final String? description;
  final String colorCode;
  final String iconName;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;

  const CategoryEntity({
    required this.id,
    required this.name,
    this.description,
    this.colorCode = '#4CAF50',
    this.iconName = 'category',
    this.sortOrder = 0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  factory CategoryEntity.fromDatabase(dynamic category) {
    return CategoryEntity(
      id: category.id,
      name: category.name,
      description: category.description,
      colorCode: category.colorCode,
      iconName: category.iconName,
      sortOrder: category.sortOrder,
      isActive: category.isActive,
      createdAt: category.createdAt,
      updatedAt: category.updatedAt,
      version: category.version,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'colorCode': colorCode,
    'iconName': iconName,
    'sortOrder': sortOrder,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'version': version,
  };
}
