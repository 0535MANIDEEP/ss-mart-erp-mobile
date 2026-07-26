import 'package:flutter/material.dart';

/// A reusable confirmation dialog for the SS MART ERP application.
///
/// Displays a title, message, and confirm/cancel buttons.
/// Returns true if confirmed, false if cancelled.
///
/// Usage:
/// ```dart
/// final confirmed = await ConfirmDialog.show(
///   context: context,
///   title: 'Delete Product',
///   message: 'Are you sure you want to delete this product?',
///   confirmText: 'Delete',
///   confirmColor: Colors.red,
/// );
/// if (confirmed) deleteProduct();
/// ```
class ConfirmDialog extends StatelessWidget {
  /// The dialog title text.
  final String title;

  /// The dialog body message.
  final String message;

  /// Text for the confirm action button.
  final String confirmText;

  /// Text for the cancel action button.
  final String cancelText;

  /// Custom color for the confirm button. Defaults to [Colors.red].
  final Color? confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor,
  });

  /// Convenience method to show the dialog and return the user's choice.
  ///
  /// Returns `true` if the user tapped confirm, `false` otherwise.
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: confirmColor ?? Colors.red,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}
