import 'package:flutter/material.dart';

/// A reusable styled button for the SS MART ERP application.
///
/// Supports primary, secondary, danger, and outline variants with
/// optional loading state and icon.
///
/// Usage:
/// ```dart
/// AppButton(
///   text: 'Save',
///   onPressed: () => save(),
///   icon: Icons.save,
/// )
/// ```
class AppButton extends StatelessWidget {
  /// The button label text.
  final String text;

  /// Callback when the button is pressed. Null disables the button.
  final VoidCallback? onPressed;

  /// Optional icon displayed before the label text.
  final IconData? icon;

  /// Whether to show a loading spinner instead of the label.
  final bool isLoading;

  /// Whether the button should expand to fill available width.
  final bool isExpanded;

  /// Custom background color. Defaults to theme primary color.
  final Color? backgroundColor;

  /// Custom foreground (text/icon) color. Defaults to white.
  final Color? foregroundColor;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  /// Creates an outline-styled variant of the button.
  const AppButton.outline({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(text),
            ],
          );

    final button = icon != null
        ? ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            icon: Icon(icon, size: 20),
            label: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(text),
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
            ),
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            child: child,
          );

    if (isExpanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
