import 'package:flutter/material.dart';

/// A reusable empty state widget for the SS MART ERP application.
///
/// Displays an icon, title, and optional subtitle when a list or screen
/// has no data to show. Includes an optional action button.
///
/// Usage:
/// ```dart
/// EmptyStateWidget(
///   icon: Icons.inventory_2_outlined,
///   title: 'No products found',
///   subtitle: 'Tap + to add your first product',
///   actionText: 'Add Product',
///   onAction: () => navigateToAdd(),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  /// The icon displayed prominently in the center.
  final IconData icon;

  /// The primary title text.
  final String title;

  /// Optional secondary description text.
  final String? subtitle;

  /// Optional text for the action button.
  final String? actionText;

  /// Callback when the action button is pressed.
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
