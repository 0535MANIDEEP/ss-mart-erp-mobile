import 'package:equatable/equatable.dart';

/// Domain entity representing an expense classification category.
///
/// Groups related expenses (rent, utilities, salary, etc.) for reporting
/// and P&L analysis. Categories are user-defined with optional color
/// coding and icon for visual identification in the UI.
class ExpenseCategory extends Equatable {
  /// Unique identifier for this category (UUID format).
  final String id;

  /// Display name (e.g., 'Rent', 'Utilities', 'Salary').
  final String name;

  /// Optional description for clarification.
  final String? description;

  /// Hex color code for visual identification (e.g., '#F44336').
  final String? color;

  /// Material icon name for display (e.g., 'home', 'bolt').
  final String? icon;

  /// Display sort order in lists.
  final int sortOrder;

  /// Whether this category is active and available for selection.
  final bool isActive;

  const ExpenseCategory({
    required this.id,
    required this.name,
    this.description,
    this.color,
    this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  ExpenseCategory copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    String? icon,
    int? sortOrder,
    bool? isActive,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, name, description, color, icon, sortOrder, isActive];
}
