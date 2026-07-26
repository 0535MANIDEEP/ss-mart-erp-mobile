import 'package:flutter/material.dart';

/// A reusable styled text field for the SS MART ERP application.
///
/// Wraps [TextFormField] with consistent styling, label, prefix/suffix icons,
/// and optional helper text. Supports all standard [TextFormField] features.
///
/// Usage:
/// ```dart
/// AppTextField(
///   label: 'Phone Number',
///   prefixIcon: Icons.phone,
///   validator: Validators.required('Phone is required'),
///   keyboardType: TextInputType.phone,
/// )
/// ```
class AppTextField extends StatelessWidget {
  /// The controller for the text field.
  final TextEditingController? controller;

  /// The label text displayed as floating hint.
  final String label;

  /// Optional placeholder text when the field is empty.
  final String? hint;

  /// Optional icon displayed before the input text.
  final IconData? prefixIcon;

  /// Optional widget displayed after the input text (e.g., clear button).
  final Widget? suffixIcon;

  /// Validation function returning null on success or error message on failure.
  final String? Function(String?)? validator;

  /// Whether to obscure the text (for passwords).
  final bool obscureText;

  /// The keyboard type to display.
  final TextInputType keyboardType;

  /// The number of visible lines for multi-line input.
  final int maxLines;

  /// Whether the field is enabled for interaction.
  final bool enabled;

  /// Maximum character count (shows counter in the field).
  final int? maxLength;

  /// Callback when the field is tapped (useful for date/time pickers).
  final VoidCallback? onTap;

  /// Whether the field is read-only (non-editable but focusable).
  final bool readOnly;

  /// Callback when the text changes.
  final void Function(String)? onChanged;

  /// Text capitalization behavior.
  final TextCapitalization textCapitalization;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.enabled = true,
    this.maxLength,
    this.onTap,
    this.readOnly = false,
    this.onChanged,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
      ),
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      maxLength: maxLength,
      onTap: onTap,
      readOnly: readOnly,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
    );
  }
}
